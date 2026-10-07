-- =====================================================================================
-- Uniqueness matches how sign-in compares.
--
-- 20261005-09 scoped cp_users.email to the tenant but kept it CASE-SENSITIVE, because
-- dev held two rows in one client differing only by a capital I and a migration does not
-- get to decide which of somebody's accounts to remove. Both were removed on 2026-10-06
-- -- the HR-only row physically, the core-platform row soft-deleted -- so the compromise
-- can now come out.
--
-- WHY IT WAS A COMPROMISE AND NOT A PREFERENCE
-- The sign-in path compares folded:
--
--     WHERE (LOWER(u.email) = %s OR u.contact = %s)
--
-- so uniqueness on the raw column allows two rows that this query cannot tell apart.
-- 'Isaac.k.kumi29@…' and 'isaac.k.kumi29@…' were one person to every lookup and two
-- people to the index, and login resolved the pair with user_records[0] -- no ORDER BY.
-- An index that disagrees with the query reading it is not a weaker guarantee, it is a
-- guarantee of the wrong thing.
--
-- So: unique on (tenant_id, lower(email)). One account per address per client, where
-- "same address" means what the login means by it.
--
-- CONTACT IS LEFT ALONE, deliberately. Phone numbers have no case to fold, and the real
-- equivalence there is formatting -- '+233548769251' versus '0548769251' versus
-- '+233 54 876 9251' are one number and three index entries. Folding that needs a
-- normalisation decision (which country code to assume for a local number) that belongs
-- in the application, on the way in, not in an index. Writing lower(contact) here would
-- look like the matching fix and would protect against nothing.
--
-- IF THIS MIGRATION FAILS it is because a client holds two live rows whose addresses
-- differ only by case. That is the state it exists to forbid, and the pre-check below
-- names them -- resolve the data, do not relax the index. The old case-sensitive index
-- stays in place until the new one is proven, so a failure changes nothing.
-- =====================================================================================

-- A better error than the one CREATE UNIQUE INDEX gives, which names a value but not
-- which rows, in which client, or that case is the reason.
DO $$
-- The variable is NOT called `detail`: the subquery below has a column of that name,
-- and plpgsql resolves the ambiguity by refusing the statement -- "column reference
-- \"detail\" is ambiguous" -- so the pre-check died with a message about its own
-- internals instead of the one it exists to print.
DECLARE n integer; pairs text;
BEGIN
    SELECT count(*), COALESCE(string_agg(d.pair, '; '), '') INTO n, pairs
      FROM (SELECT tenant_id || ' -> ' || string_agg(id || ' (' || email || ')', ', ')
                   AS pair
              FROM core_platform.cp_users
             WHERE delete_status = 'NOT_DELETED'
               AND email IS NOT NULL AND btrim(email) <> ''
             GROUP BY tenant_id, lower(email)
            HAVING count(*) > 1) d;
    IF n > 0 THEN
        RAISE EXCEPTION
            '% client(s) hold two live accounts whose addresses differ only by case: %. '
            'The sign-in compares LOWER(email), so these are one person to every lookup '
            'and two to the index. Resolve the rows -- do not drop this index',
            n, pairs;
    END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS ix_cp_users_tenant_email_lower
    ON core_platform.cp_users (tenant_id, lower(email))
 WHERE delete_status = 'NOT_DELETED';

COMMENT ON INDEX core_platform.ix_cp_users_tenant_email_lower IS
    'One account per address per client, folded -- because the sign-in compares '
    'LOWER(email) and an index on the raw column admits two rows that query cannot '
    'tell apart. Partial, so a deleted user releases their address.';

-- Only now. Replacing a case-sensitive index with a case-insensitive one is strictly
-- tightening, so there is no window in which less is enforced than before.
DROP INDEX IF EXISTS core_platform.ix_cp_users_tenant_email;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer;
BEGIN
    SELECT count(*) INTO n FROM pg_indexes
     WHERE schemaname = 'core_platform' AND tablename = 'cp_users'
       AND indexname = 'ix_cp_users_tenant_email_lower';
    IF n <> 1 THEN
        RAISE EXCEPTION 'the folded index does not exist';
    END IF;

    SELECT count(*) INTO n FROM pg_indexes
     WHERE schemaname = 'core_platform' AND tablename = 'cp_users'
       AND indexname = 'ix_cp_users_tenant_email';
    IF n > 0 THEN
        RAISE EXCEPTION 'the case-sensitive index survives, so a client can still hold '
                        'two accounts the sign-in cannot tell apart';
    END IF;

    -- The contact index is NOT replaced. Asserted, because "make it match email" is the
    -- obvious tidy-up and it would be the wrong fix -- see the header.
    SELECT count(*) INTO n FROM pg_indexes
     WHERE schemaname = 'core_platform' AND tablename = 'cp_users'
       AND indexname = 'ix_cp_users_tenant_contact';
    IF n <> 1 THEN
        RAISE EXCEPTION 'ix_cp_users_tenant_contact is missing; this migration does not '
                        'touch it and must not have';
    END IF;

    -- PROVED BY DOING IT. A probe tenant, because the rule is per client and a
    -- single-tenant check cannot tell the two apart.
    INSERT INTO core_platform.cp_tenants (id, tenant_name, delete_status)
    VALUES ('tnt_probe_case', 'Probe Case Ltd', 'NOT_DELETED')
        ON CONFLICT (id) DO NOTHING;

    INSERT INTO core_platform.cp_users (id, tenant_id, fullname, email, contact,
                                        delete_status)
    VALUES ('uid_probe_case1', 'tnt_probe_case', 'One', 'Case.Probe@example.test',
            '+000000000011', 'NOT_DELETED');

    BEGIN
        INSERT INTO core_platform.cp_users (id, tenant_id, fullname, email, contact,
                                            delete_status)
        VALUES ('uid_probe_case2', 'tnt_probe_case', 'Two', 'case.probe@example.test',
                '+000000000012', 'NOT_DELETED');
        RAISE EXCEPTION 'one client accepted the same address twice, differing only by '
                        'case -- which is exactly the pair this migration removes';
    EXCEPTION WHEN unique_violation THEN
        NULL;
    END;

    -- ...and a DIFFERENT client may still have that address, which 20261005-09 opened up
    -- and this must not close again.
    INSERT INTO core_platform.cp_tenants (id, tenant_name, delete_status)
    VALUES ('tnt_probe_case2', 'Probe Case Two Ltd', 'NOT_DELETED')
        ON CONFLICT (id) DO NOTHING;
    BEGIN
        INSERT INTO core_platform.cp_users (id, tenant_id, fullname, email, contact,
                                            delete_status)
        VALUES ('uid_probe_case3', 'tnt_probe_case2', 'Three',
                'case.probe@example.test', '+000000000013', 'NOT_DELETED');
    EXCEPTION WHEN unique_violation THEN
        RAISE EXCEPTION 'folding the address also made it global again, so a second '
                        'client can no longer grant access to the same person';
    END;

    DELETE FROM core_platform.cp_users WHERE id LIKE 'uid_probe_case%';
    DELETE FROM core_platform.cp_tenants WHERE id IN ('tnt_probe_case', 'tnt_probe_case2');

    SELECT count(*) INTO n FROM core_platform.cp_users WHERE id LIKE 'uid_probe_case%';
    IF n > 0 THEN
        RAISE EXCEPTION '% probe user(s) survived', n;
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_tenants
     WHERE id IN ('tnt_probe_case', 'tnt_probe_case2');
    IF n > 0 THEN
        RAISE EXCEPTION '% probe tenant(s) survived', n;
    END IF;

    RAISE NOTICE 'uniqueness matches how sign-in compares: one address per client, '
                 'folded; % live user(s)',
        (SELECT count(*) FROM core_platform.cp_users WHERE delete_status = 'NOT_DELETED');
END $$;
