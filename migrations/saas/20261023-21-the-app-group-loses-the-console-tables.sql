-- =====================================================================================
-- The application group loses the console's tables.
--
-- Step 3 of CONSOLE-GAPS gap 1 (see 20261023-20). LAND THIS ONLY ONCE THE CONSOLE RUNS
-- ON ITS OWN LOGIN (deladetech_<env>, db-url-deladetech-console): until then the
-- console connects as coreplatform_<env>, which reaches these tables only through the
-- group this file takes them from, and every console sign-in would fail.
--
-- What every application login keeps: SELECT and INSERT on dlt_hosting_requests,
-- because core-platform's public signup page records a hosting request and reads it
-- back (lp_service.py, the RETURNING-style re-read). Nothing else in deladetech:
--
--   dlt_operators          staff password hashes and roles
--   dlt_operator_sessions  console sessions -- inserting one was a console OWNER
--   dlt_client_setups      setup records
--   dlt_client_clears      the audit of every purge
--   anything added later   (default privileges give a new table the base set of
--                          tvs-iac's common.hcl, so it is taken back here, every
--                          deploy, unless it is listed as the apps')
--
-- The same narrowing is in tvs-iac common.hcl app_group_restricted_schemas.deladetech,
-- so neither re-grants what the other revokes. The earlier console files
-- (20261003-01/-04/-06, 20261005-05) no longer grant the group anything but the
-- hosting-request pair; this file is what enforces it, and asserts it.
--
-- Pooled only (app_groups_here(true)): the console's tables exist only in the pool.
-- Idempotent; safe on every deploy.
-- =====================================================================================

DO $$
DECLARE
    grp text;
    t   text;
BEGIN
    FOR grp IN SELECT control_plane.app_groups_here(true) LOOP
        FOR t IN
            SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE n.nspname = 'deladetech' AND c.relkind IN ('r', 'p', 'v', 'm')
        LOOP
            IF t = 'dlt_hosting_requests' THEN
                EXECUTE format('REVOKE UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER '
                               'ON deladetech.%I FROM %I', t, grp);
                EXECUTE format('GRANT SELECT, INSERT ON deladetech.%I TO %I', t, grp);
            ELSE
                EXECUTE format('REVOKE ALL ON deladetech.%I FROM %I', t, grp);
            END IF;
        END LOOP;

        -- Future tables the migrator creates here: the base set only (tvs-iac's
        -- default privilege says the same), and this file revokes it from anything
        -- that is not dlt_hosting_requests on the next deploy.
        EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA deladetech '
                       'REVOKE UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLES FROM %I', grp);
        RAISE NOTICE 'deladetech: % keeps only SELECT, INSERT on dlt_hosting_requests', grp;
    END LOOP;
END $$;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE
    grp  text;
    m    record;
    bad  text;
BEGIN
    -- The group itself: an EXCEPTION, because these are the migrator's own grants and
    -- the file just revoked them -- one surviving means the revoke did not work.
    FOR grp IN SELECT control_plane.app_groups_here(true) LOOP
        SELECT string_agg(format('%s %s', p.privilege_type, p.table_name), ', ') INTO bad
          FROM information_schema.role_table_grants p
         WHERE p.table_schema = 'deladetech' AND p.grantee = grp
           AND NOT (p.table_name = 'dlt_hosting_requests'
                    AND p.privilege_type IN ('SELECT', 'INSERT'));
        IF bad IS NOT NULL THEN
            RAISE EXCEPTION 'app group % still holds % in deladetech', grp, bad;
        END IF;
        -- Column grants do not show in role_table_grants.
        SELECT string_agg(DISTINCT format('%s %s(%s)', p.privilege_type, p.table_name,
                                          p.column_name), ', ') INTO bad
          FROM information_schema.role_column_grants p
         WHERE p.table_schema = 'deladetech' AND p.grantee = grp
           AND p.table_name <> 'dlt_hosting_requests';
        IF bad IS NOT NULL THEN
            RAISE EXCEPTION 'app group % still holds column grants in deladetech: %', grp, bad;
        END IF;
    END LOOP;

    -- What each application LOGIN can actually do, however it got it (a direct grant by
    -- somebody else, another group). A WARNING with the exact table, not an exception:
    -- a grant another role made is not this file's to revoke, and failing every deploy
    -- of the platform over it would stop unrelated work.
    FOR m IN
        SELECT DISTINCT r.rolname
          FROM pg_roles r
          JOIN pg_auth_members am ON am.member = r.oid
          JOIN pg_roles g ON g.oid = am.roleid
         WHERE r.rolcanlogin
           AND g.rolname IN (SELECT control_plane.app_groups_here(true))
    LOOP
        IF has_table_privilege(m.rolname, 'deladetech.dlt_operators', 'SELECT')
           OR has_table_privilege(m.rolname, 'deladetech.dlt_operators', 'UPDATE')
           OR has_table_privilege(m.rolname, 'deladetech.dlt_operator_sessions', 'INSERT')
           OR has_table_privilege(m.rolname, 'deladetech.dlt_operator_sessions', 'SELECT') THEN
            RAISE WARNING 'application login % can still reach the console''s operators or '
                          'sessions (not through the app group) -- find the grant with '
                          '\dp deladetech.* and revoke it', m.rolname;
        END IF;
    END LOOP;

    RAISE NOTICE 'deladetech: the application group reaches only the hosting requests';
END $$;
