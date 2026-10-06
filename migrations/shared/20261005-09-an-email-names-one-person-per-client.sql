-- =====================================================================================
-- An email names one person PER CLIENT, not per database.
--
-- cp_users.email and cp_users.contact were UNIQUE with no tenant_id:
--
--     CREATE UNIQUE INDEX ix_cp_users_email   ON cp_users (email)
--     CREATE UNIQUE INDEX ix_cp_users_contact ON cp_users (contact)
--
-- So a consultant engaged by two clients could not be given a second account. The
-- second client's INSERT was refused by the index -- and the code that would have done
-- it was already right: user_service asks
--
--     WHERE email = %s AND tenant_id = %s
--
-- i.e. "does this address already exist IN MY TENANT". It never wanted global
-- uniqueness. The index was the only thing in the way.
--
-- WHY THIS COULD NOT SHIP FIRST
-- Sixteen lookups in the sign-in path asked the tenant-blind question "who has this
-- email", and login did
--
--     WHERE (LOWER(u.email) = %s OR u.contact = %s)  ->  user_records[0]
--
-- with no ORDER BY. One row, correct by luck. Two rows, a coin toss between two
-- clients' accounts. Relaxing the index while that was true would have turned a refused
-- INSERT into a cross-tenant sign-in, so the lookups were scoped first -- they now take
-- the tenant from the ADDRESS (every client has one since 20261005-07) and refuse rather
-- than resolve anything still ambiguous. This file is the second half, and is worth
-- nothing without the first.
--
-- CASE-SENSITIVE, LIKE THE INDEXES IT REPLACES
-- These are on the raw columns, not lower(email) -- deliberately, and it is the one
-- compromise here. A per-tenant index on lower(email) cannot be built on dev: one person
-- holds a core-platform account and an HR-only row whose addresses differ only by a
-- capital I, in the same tenant. Forcing it would mean deleting or merging somebody's
-- user row inside a migration, which is not a decision a migration gets to make.
--
-- So uniqueness keeps exactly the semantics it has today and only the SCOPE changes.
-- The case hazard is reported below rather than enforced, and the sign-in path handles
-- it the right way round: login_verify now joins cp_members as login always did, which
-- is what makes that pair resolve to one row instead of an arbitrary one.
--
-- PARTIAL, which the old indexes were not. A deleted user held their address hostage
-- forever: delete somebody and nobody -- not even the same person -- could be added with
-- that email again. Nobody asked for that and it reads as a bug every time it is hit.
-- =====================================================================================

-- Built BEFORE the old ones are dropped, so there is no window in which two rows in one
-- tenant could share an address. A failure here leaves the old global indexes in place
-- and changes nothing.
CREATE UNIQUE INDEX IF NOT EXISTS ix_cp_users_tenant_email
    ON core_platform.cp_users (tenant_id, email)
 WHERE delete_status = 'NOT_DELETED';

CREATE UNIQUE INDEX IF NOT EXISTS ix_cp_users_tenant_contact
    ON core_platform.cp_users (tenant_id, contact)
 WHERE delete_status = 'NOT_DELETED'
   AND contact IS NOT NULL AND btrim(contact) <> '';

COMMENT ON INDEX core_platform.ix_cp_users_tenant_email IS
    'One account per address PER TENANT. Replaces a global unique index, which is what '
    'stopped a client granting access to somebody who already had an account with '
    'another client. Partial, so a deleted user does not hold an address forever.';

COMMENT ON INDEX core_platform.ix_cp_users_tenant_contact IS
    'One account per phone number per tenant. Blank is not a value, so several rows may '
    'carry an empty contact.';

-- ----------------------------------------------------------------- the old rule goes
-- Only once the replacements exist. ix_cp_users_email is also the index the login
-- lookup used, and (tenant_id, email) serves that query too -- the leading column is
-- not email, but the sign-in is now scoped by tenant, so it is the right order.
DROP INDEX IF EXISTS core_platform.ix_cp_users_email;
DROP INDEX IF EXISTS core_platform.ix_cp_users_contact;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer; detail text;
BEGIN
    -- The replacements are there...
    SELECT count(*) INTO n FROM pg_indexes
     WHERE schemaname = 'core_platform' AND tablename = 'cp_users'
       AND indexname IN ('ix_cp_users_tenant_email', 'ix_cp_users_tenant_contact');
    IF n <> 2 THEN
        RAISE EXCEPTION 'only % of the 2 per-tenant unique indexes exist', n;
    END IF;

    -- ...and the global ones are gone. Both halves asserted, because leaving a global
    -- index behind means this migration appears to have worked while a second client
    -- still cannot grant access to the same person.
    SELECT count(*) INTO n FROM pg_indexes
     WHERE schemaname = 'core_platform' AND tablename = 'cp_users'
       AND indexname IN ('ix_cp_users_email', 'ix_cp_users_contact');
    IF n > 0 THEN
        RAISE EXCEPTION '% global unique index(es) on cp_users survive, so an email is '
                        'still one person per DATABASE', n;
    END IF;

    -- PROVED BY DOING IT, both ways round. "The index was dropped" and "a second client
    -- can now grant access to this person" are different claims, and it is the second
    -- one that was asked for.
    INSERT INTO core_platform.cp_tenants (id, tenant_name, delete_status)
    VALUES ('tnt_probe_a', 'Probe A Ltd', 'NOT_DELETED'),
           ('tnt_probe_b', 'Probe B Ltd', 'NOT_DELETED')
        ON CONFLICT (id) DO NOTHING;

    INSERT INTO core_platform.cp_users
        (id, tenant_id, fullname, email, contact, delete_status)
    VALUES ('uid_probe_a', 'tnt_probe_a', 'A Consultant',
            'probe.consultant@example.test', '+000000000001', 'NOT_DELETED');

    -- The same person, engaged by a second client. THIS is the line that used to fail.
    BEGIN
        INSERT INTO core_platform.cp_users
            (id, tenant_id, fullname, email, contact, delete_status)
        VALUES ('uid_probe_b', 'tnt_probe_b', 'A Consultant',
                'probe.consultant@example.test', '+000000000001', 'NOT_DELETED');
    EXCEPTION WHEN unique_violation THEN
        RAISE EXCEPTION 'a second client still cannot grant access to the same person, '
                        'which is the entire purpose of this migration';
    END;

    -- ...while twice in ONE client is still refused, which is the rule user_service
    -- reports as "User with email ... already exists".
    BEGIN
        INSERT INTO core_platform.cp_users
            (id, tenant_id, fullname, email, contact, delete_status)
        VALUES ('uid_probe_a2', 'tnt_probe_a', 'A Consultant Again',
                'probe.consultant@example.test', '+000000000002', 'NOT_DELETED');
        RAISE EXCEPTION 'one client accepted the same email twice';
    EXCEPTION WHEN unique_violation THEN
        NULL;
    END;

    -- The same number, likewise: per client, not per database.
    BEGIN
        INSERT INTO core_platform.cp_users
            (id, tenant_id, fullname, email, contact, delete_status)
        VALUES ('uid_probe_a3', 'tnt_probe_a', 'Third', 'third@example.test',
                '+000000000001', 'NOT_DELETED');
        RAISE EXCEPTION 'one client accepted the same contact twice';
    EXCEPTION WHEN unique_violation THEN
        NULL;
    END;

    -- A DELETED user releases their address. The old global indexes did not, so
    -- removing somebody meant their email could never be used again.
    UPDATE core_platform.cp_users SET delete_status = 'DELETED' WHERE id = 'uid_probe_a';
    BEGIN
        INSERT INTO core_platform.cp_users
            (id, tenant_id, fullname, email, contact, delete_status)
        VALUES ('uid_probe_a4', 'tnt_probe_a', 'Replacement',
                'probe.consultant@example.test', '+000000000001', 'NOT_DELETED');
    EXCEPTION WHEN unique_violation THEN
        RAISE EXCEPTION 'a deleted user still holds their email, so the address cannot '
                        'be reused by the person who replaces them';
    END;

    DELETE FROM core_platform.cp_users WHERE id LIKE 'uid_probe_%';
    DELETE FROM core_platform.cp_tenants WHERE id IN ('tnt_probe_a', 'tnt_probe_b');

    SELECT count(*) INTO n FROM core_platform.cp_users WHERE id LIKE 'uid_probe_%';
    IF n > 0 THEN
        RAISE EXCEPTION '% probe user(s) survived and would be real accounts', n;
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_tenants
     WHERE id IN ('tnt_probe_a', 'tnt_probe_b');
    IF n > 0 THEN
        RAISE EXCEPTION '% probe tenant(s) survived and would be read as real clients', n;
    END IF;

    -- ------------------------------------------------------------ reported, not fixed
    -- Two rows in one tenant whose addresses differ only by case. The sign-in path
    -- handles these (login and login_verify both gate on cp_members, and anything still
    -- ambiguous is refused rather than guessed), but they are data somebody should look
    -- at -- and they are the reason the index above is not on lower(email).
    SELECT count(*), COALESCE(string_agg(DISTINCT e, ', '), '') INTO n, detail
      FROM (SELECT lower(email) AS e FROM core_platform.cp_users
             WHERE delete_status = 'NOT_DELETED'
               AND email IS NOT NULL AND btrim(email) <> ''
             GROUP BY tenant_id, lower(email) HAVING count(*) > 1) d;
    IF n > 0 THEN
        RAISE WARNING 'CASE-DUPLICATE ADDRESS: % address(es) exist twice in one client, '
                      'differing only by case (%). Uniqueness here is case-sensitive, '
                      'so these are allowed; resolve them if you want an index on '
                      'lower(email)', n, detail;
    END IF;

    RAISE NOTICE 'an email names one person per client: % user(s) across % client(s)',
        (SELECT count(*) FROM core_platform.cp_users WHERE delete_status = 'NOT_DELETED'),
        (SELECT count(DISTINCT tenant_id) FROM core_platform.cp_users
          WHERE delete_status = 'NOT_DELETED');
END $$;
