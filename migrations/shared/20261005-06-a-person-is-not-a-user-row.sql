-- =====================================================================================
-- A person is not a user row.
--
-- Phase 1 of letting one person work for several pooled clients with one login. This
-- migration changes NO behaviour: it creates the identity, backfills one per person, and
-- links each user row to it. Nothing reads identity_id yet.
--
-- WHY A SEPARATE TABLE RATHER THAN RELAXING THE EMAIL INDEX
-- Relaxing UNIQUE (email) to (email, tenant_id) would give a consultant two accounts
-- that merely share an address: two passwords that drift apart, two MFA enrolments, and
-- a password reset with no way to know which was meant. The credential has to belong to
-- the PERSON. What they may DO stays on cp_users, per tenant, exactly as now.
--
-- WHY cp_users KEEPS ITS PRIMARY KEY
-- 399 foreign keys from 154 tables reference cp_users(id, tenant_id). Dropping tenant_id
-- from that key is the textbook model and is not affordable. Splitting the identity out
-- instead leaves every one of those constraints untouched.
--
-- WHY shared/ WHEN THE FEATURE IS POOLED-ONLY
-- The feature is pooled-only. The TABLE cannot be: phase 2 moves authentication onto
-- cp_identities, and authentication runs in every database -- a silo client signs in to
-- their own. A table that existed only in the pooled database would break silo login the
-- day phase 2 ships. The membership behaviour stays pooled-only because that is where
-- cp_members will be read, not because of where the table lives.
--
-- NO tenant_id, DELIBERATELY. An identity spans tenants; that is its whole purpose. Two
-- consequences to carry forward:
--   * the console's clear discovers tables to purge by their tenant_id column, so an
--     identity is NOT deleted when a tenant is cleared -- correct while another
--     membership remains, and a leak when none does. Phase 4 owns that cleanup.
--   * the activity-log purge convention (tenant_id + cdatetime) does not apply here.
--
-- CASE. The unique index is on lower(email), because the login already compares
-- LOWER(u.email) -- see lp_service.login. The column keeps what the person typed.
-- =====================================================================================

CREATE TABLE IF NOT EXISTS core_platform.cp_identities (
    id             text        NOT NULL
                   DEFAULT ('idn_' || replace(gen_random_uuid()::text, '-', '')),
    email          text        NOT NULL,
    contact        text,
    -- The hash. Populated here so phase 2 has something to authenticate against, and
    -- read by nothing until then.
    login_password text,
    is_active      boolean     NOT NULL DEFAULT true,
    delete_status  text        NOT NULL DEFAULT 'NOT_DELETED',
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text,
    udatetime      timestamptz,
    updated_by     text,
    CONSTRAINT pk_cp_identities PRIMARY KEY (id)
);

COMMENT ON TABLE core_platform.cp_identities IS
    'One row per PERSON: the credential, and nothing about what they may do. Spans '
    'tenants on purpose -- a consultant engaged by two clients is one row here and one '
    'cp_users row per client. Has no tenant_id, so a tenant clear does not reach it.';

-- Case-insensitive, because that is how the login compares. Partial, so a deleted
-- identity does not hold an address hostage.
CREATE UNIQUE INDEX IF NOT EXISTS ix_cp_identities_email
    ON core_platform.cp_identities (lower(email))
 WHERE delete_status = 'NOT_DELETED';

-- The login also matches on contact, so the same reasoning applies: two identities
-- sharing one number would make that lookup arbitrary too. Blank is not a value.
CREATE UNIQUE INDEX IF NOT EXISTS ix_cp_identities_contact
    ON core_platform.cp_identities (lower(contact))
 WHERE delete_status = 'NOT_DELETED' AND contact IS NOT NULL AND btrim(contact) <> '';

ALTER TABLE core_platform.cp_users
    ADD COLUMN IF NOT EXISTS identity_id text;

COMMENT ON COLUMN core_platform.cp_users.identity_id IS
    'The person this row belongs to. Nullable through phases 1-3; several rows may '
    'share one identity once a person works for more than one client.';

CREATE INDEX IF NOT EXISTS ix_cp_users_identity_id
    ON core_platform.cp_users (identity_id) WHERE identity_id IS NOT NULL;

-- ------------------------------------------------------------------------- backfill
-- One identity per distinct lower(email).
--
-- DISTINCT ON picks which row's details the identity takes. Ordered so a row that
-- actually HAS a password wins: dev already holds two accounts for one person differing
-- only by a capital letter, and one of them has an empty login_password. Taking the
-- blank one would hand phase 2 an identity nobody can sign in as.
--
-- NOT EXISTS rather than ON CONFLICT: every migration re-runs on every deploy, and this
-- must add only what is missing. A person whose email changed later is not re-created.
INSERT INTO core_platform.cp_identities (email, contact, login_password, created_by)
SELECT DISTINCT ON (lower(u.email))
       u.email,
       NULLIF(btrim(u.contact), ''),
       NULLIF(u.login_password, ''),
       'migration:20261005-06'
  FROM core_platform.cp_users u
 WHERE u.delete_status = 'NOT_DELETED'
   AND u.email IS NOT NULL
   AND btrim(u.email) <> ''
   AND NOT EXISTS (
       SELECT 1 FROM core_platform.cp_identities i
        WHERE lower(i.email) = lower(u.email)
          AND i.delete_status = 'NOT_DELETED')
 ORDER BY lower(u.email),
          (NULLIF(u.login_password, '') IS NOT NULL) DESC,
          u.cdatetime DESC NULLS LAST,
          u.id;

UPDATE core_platform.cp_users u
   SET identity_id = i.id
  FROM core_platform.cp_identities i
 WHERE lower(i.email) = lower(u.email)
   AND i.delete_status = 'NOT_DELETED'
   AND u.delete_status = 'NOT_DELETED'
   AND u.identity_id IS DISTINCT FROM i.id;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer; m integer; detail text;
BEGIN
    -- Every live user with an email has one.
    SELECT count(*) INTO n FROM core_platform.cp_users
     WHERE delete_status = 'NOT_DELETED'
       AND email IS NOT NULL AND btrim(email) <> ''
       AND identity_id IS NULL;
    IF n > 0 THEN
        RAISE EXCEPTION '% live user(s) have no identity, so phase 2 would lock them '
                        'out when authentication moves', n;
    END IF;

    -- ...and it points at one that exists.
    SELECT count(*) INTO n FROM core_platform.cp_users u
     WHERE u.identity_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM core_platform.cp_identities i WHERE i.id = u.identity_id);
    IF n > 0 THEN
        RAISE EXCEPTION '% user(s) point at an identity that does not exist', n;
    END IF;

    -- Exactly one identity per address, which is the point of the table.
    SELECT count(*) INTO n FROM core_platform.cp_identities
     WHERE delete_status = 'NOT_DELETED';
    SELECT count(DISTINCT lower(email)) INTO m FROM core_platform.cp_users
     WHERE delete_status = 'NOT_DELETED' AND email IS NOT NULL AND btrim(email) <> '';
    IF n <> m THEN
        RAISE EXCEPTION '% identities for % distinct addresses', n, m;
    END IF;

    -- An identity with no password cannot be signed in as once phase 2 lands. Reported
    -- rather than raised: a user row created without one is a real state today.
    SELECT count(*) INTO n FROM core_platform.cp_identities
     WHERE delete_status = 'NOT_DELETED'
       AND (login_password IS NULL OR btrim(login_password) = '');
    IF n > 0 THEN
        RAISE NOTICE '% identity(ies) have no password -- they cannot sign in once '
                     'phase 2 moves authentication here', n;
    END IF;

    -- TWO USER ROWS, ONE TENANT, ONE PERSON. This is a duplicate account, not the
    -- feature: dev has a pair differing only by a capital letter, with different
    -- passwords, and the login picks between them with no ORDER BY. Phase 2 must refuse
    -- to run while any remain, because moving authentication to the identity silently
    -- retires whichever password was not chosen above.
    SELECT count(*), COALESCE(string_agg(DISTINCT lower(email), ', '), '')
      INTO n, detail
      FROM (SELECT u.identity_id, u.tenant_id, min(u.email) AS email
              FROM core_platform.cp_users u
             WHERE u.delete_status = 'NOT_DELETED' AND u.identity_id IS NOT NULL
             GROUP BY u.identity_id, u.tenant_id
            HAVING count(*) > 1) dup;
    IF n > 0 THEN
        RAISE WARNING 'DUPLICATE ACCOUNTS: % person(s) have more than one user row in '
                      'one tenant (%). Resolve before phase 2, or the password not '
                      'chosen by the backfill stops working', n, detail;
    END IF;

    RAISE NOTICE 'a person is not a user row: % identit(ies) for % user row(s)',
        (SELECT count(*) FROM core_platform.cp_identities WHERE delete_status = 'NOT_DELETED'),
        (SELECT count(*) FROM core_platform.cp_users WHERE delete_status = 'NOT_DELETED');
END $$;
