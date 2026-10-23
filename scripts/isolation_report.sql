-- =====================================================================================
-- Isolation report -- READ-ONLY. Which roles of OTHER databases on this server hold a
-- privilege in, or can CONNECT to, the database this runs in.
--
-- Run by apply.yml after every command (as the migrator), and by hand with psql. It
-- writes nothing except pg_temp copies of the tenancy role helpers, so it gives the
-- same answer before the migration that creates them (20261001-01) has been deployed.
-- The block between the markers below is generated from that migration's block --
-- scripts/test_role_isolation.py checks the two are identical.
-- =====================================================================================
\set ON_ERROR_STOP 1
\pset pager off
\set QUIET on
SET client_min_messages = warning;
-- >>> tenancy role helpers (scripts/isolation_report.sql carries a pg_temp copy; keep them identical)
-- ---------------------------------------------------------------------
-- WHO BELONGS TO THIS DATABASE -- derived from current_database(), never from a
-- role-name pattern alone.
--
-- PostgreSQL roles are per CLUSTER, and one server holds several of our databases
-- (tvs-shared-sql: dev-db and every SILO_SHARED client). A migration that grants to
-- "every tvs_app_% group" or "every ^mystoreguard role" therefore hands each silo's
-- roles rights inside every OTHER database on that server -- found 2026-10-22 when
-- offboarding regtest had to revoke mystoreguard_regtest_dev and tvs_app_regtest_dev
-- privileges inside silo-itech-dev and dev-db. These functions answer "whose
-- database is this" once, and every grant asks them.
--
--   silo    a shared or dedicated silo: its route row names this database
--           (db_name + silo_key), or the database is named silo-<key>-<env>.
--           Its group is tvs_app_<key>_<env>; its logins <app>_<key>_<env>.
--   pooled  <env>-db (dev-db, prod-db, staging-db). Its groups are the pooled
--           tvs_app_<env> ones; its logins <app>_<env>.
--   single  anything else -- an enterprise or BYOD database on the CLIENT's own
--           server, or a local test database. One client per server, so every
--           group on the server is this database's (the behaviour before
--           2026-10-23, which was harmless there).
--
-- Plain SECURITY INVOKER functions reading only pg_roles / the route table.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pg_temp.this_database_unit(
    OUT unit text, OUT silo_key text, OUT env text, OUT app_groups text[])
LANGUAGE plpgsql STABLE AS $fn$
DECLARE
    db text := current_database();
    m  text[];
    k  text;
BEGIN
    -- The route table first: it is what the platform itself routes by. Only SHARED
    -- and DEDICATED silos -- a BYOD database is on the client's own server.
    IF to_regclass('control_plane.ctl_tenant_routes') IS NOT NULL
       AND EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'control_plane'
                      AND table_name   = 'ctl_tenant_routes'
                      AND column_name  = 'silo_key') THEN
        EXECUTE 'SELECT min(silo_key) FROM control_plane.ctl_tenant_routes
                  WHERE db_name = current_database() AND silo_key IS NOT NULL
                    AND tier IN (''SILO_SHARED'', ''SILO_DEDICATED'')'
           INTO k;
    END IF;
    m := regexp_match(db, '^silo-([a-z0-9-]+)-([a-z0-9]+)$');
    IF k IS NULL AND m IS NOT NULL THEN
        k := m[1];
    END IF;

    IF k IS NOT NULL THEN
        unit     := 'silo';
        silo_key := replace(lower(k), '-', '_');
        env      := m[2];   -- NULL when only the route row named it
        SELECT coalesce(array_agg(rolname::text ORDER BY rolname), '{}') INTO app_groups
          FROM pg_roles
         WHERE NOT rolcanlogin AND rolname = 'tvs_app_' || silo_key || '_' || env;
        IF cardinality(app_groups) = 0 THEN
            -- The name did not say the environment (or said one with no group):
            -- take the silo's group whatever its environment suffix.
            env := NULL;
            SELECT coalesce(array_agg(rolname::text ORDER BY rolname), '{}') INTO app_groups
              FROM pg_roles
             WHERE NOT rolcanlogin AND rolname ~ ('^tvs_app_' || silo_key || '_[a-z0-9]+$');
        END IF;
        IF env IS NULL AND cardinality(app_groups) = 1 THEN
            env := substring(app_groups[1] from '_([a-z0-9]+)$');
        END IF;
    ELSIF db ~ '^[a-z0-9]+-db$' THEN
        unit := 'pooled';
        env  := substring(db from '^([a-z0-9]+)-db$');
        SELECT coalesce(array_agg(rolname::text ORDER BY rolname), '{}') INTO app_groups
          FROM pg_roles
         WHERE NOT rolcanlogin AND rolname ~ '^tvs_app_[a-z0-9]+$';
    ELSE
        unit := 'single';
        SELECT coalesce(array_agg(rolname::text ORDER BY rolname), '{}') INTO app_groups
          FROM pg_roles
         WHERE NOT rolcanlogin AND rolname ~ '^tvs_app_[a-z0-9_]+$';
    END IF;
END
$fn$;

-- This database's application group(s). pooled_shape_only keeps just the
-- tvs_app_<env> shape: for privileges that belong to the POOL alone (claiming or
-- releasing a pooled address, the hosting-request console), so a silo -- whose
-- group is tvs_app_<key>_<env> -- gets none, exactly as before.
CREATE OR REPLACE FUNCTION pg_temp.app_groups_here(pooled_shape_only boolean DEFAULT false)
RETURNS SETOF text
LANGUAGE sql STABLE AS $fn$
    SELECT g
      FROM unnest((pg_temp.this_database_unit()).app_groups) AS g
     WHERE NOT pooled_shape_only OR g ~ '^tvs_app_[a-z0-9]+$'
     ORDER BY g
$fn$;

-- This database's login(s) for one application, e.g. app_logins_here('mystoreguard'):
--   silo    mystoreguard_<key>_<env>
--   pooled  mystoreguard_<env> (one per pooled environment sharing the database)
--   single  ^mystoreguard(_|$) -- the old behaviour, on a one-client server
CREATE OR REPLACE FUNCTION pg_temp.app_logins_here(app text)
RETURNS SETOF text
LANGUAGE sql STABLE AS $fn$
    WITH u AS (SELECT * FROM pg_temp.this_database_unit())
    SELECT r.rolname::text
      FROM pg_roles r, u
     WHERE app ~ '^[a-z0-9]+$'
       AND CASE u.unit
             WHEN 'silo'   THEN r.rolcanlogin
                                AND (r.rolname = app || '_' || u.silo_key || '_' || u.env
                                     OR (u.env IS NULL AND r.rolname ~ ('^' || app || '_' || u.silo_key || '_[a-z0-9]+$')))
             WHEN 'pooled' THEN r.rolcanlogin AND r.rolname ~ ('^' || app || '_[a-z0-9]+$')
             ELSE               r.rolname ~ ('^' || app || '(_|$)')
           END
     ORDER BY 1
$fn$;

-- Does this role belong to ANOTHER database on this server? The question the
-- cleanup (20261023-01) and its invariant ask. Never true for infrastructure
-- (superusers, the admin, the migrator, the database's owner, pg_*/azure_*), never
-- true on a one-client server, and never true for a role of this database.
CREATE OR REPLACE FUNCTION pg_temp.role_is_foreign_here(r oid)
RETURNS boolean
LANGUAGE plpgsql STABLE AS $fn$
DECLARE
    u  record;
    rr record;
BEGIN
    SELECT * INTO u FROM pg_temp.this_database_unit();
    IF u.unit = 'single' THEN
        RETURN false;
    END IF;
    SELECT * INTO rr FROM pg_roles WHERE oid = r;
    IF NOT FOUND
       OR rr.rolsuper OR rr.rolcreaterole OR rr.rolreplication OR rr.rolbypassrls
       OR rr.rolname ~ '^(pg_|azure)'
       OR rr.rolname = current_user
       OR r = (SELECT datdba FROM pg_database WHERE datname = current_database()) THEN
        RETURN false;
    END IF;

    -- This database's own: its group(s), their members, a silo's tenant read-only
    -- login, and a silo login whose group membership has not been applied yet.
    IF rr.rolname = ANY (u.app_groups)
       OR EXISTS (SELECT 1 FROM unnest(u.app_groups) g WHERE pg_has_role(r, g::name, 'MEMBER'))
       OR (u.unit = 'silo' AND u.env IS NOT NULL
           AND (rr.rolname = u.silo_key || '_readonly_' || u.env
                OR right(rr.rolname, length(u.silo_key || '_' || u.env) + 1) = '_' || u.silo_key || '_' || u.env)) THEN
        RETURN false;
    END IF;

    -- Another unit's: another app group, a member of one, another silo's tenant
    -- read-only login, or a login carrying another silo group's suffix.
    RETURN (NOT rr.rolcanlogin AND rr.rolname ~ '^tvs_app_[a-z0-9_]+$')
        OR EXISTS (SELECT 1 FROM pg_roles g
                    WHERE NOT g.rolcanlogin AND g.rolname ~ '^tvs_app_[a-z0-9_]+$'
                      AND pg_has_role(r, g.oid, 'MEMBER'))
        OR rr.rolname ~ '^[a-z0-9_]+_readonly_[a-z0-9]+$'
        OR EXISTS (SELECT 1 FROM pg_roles g
                    WHERE NOT g.rolcanlogin AND g.rolname ~ '^tvs_app_[a-z0-9]+_[a-z0-9]+$'
                      AND right(rr.rolname, length(g.rolname) - 7) = '_' || substr(g.rolname, 9));
END
$fn$;

-- Nobody but the migrator needs these, and a new function is executable by PUBLIC.
REVOKE ALL ON FUNCTION pg_temp.this_database_unit() FROM PUBLIC;
REVOKE ALL ON FUNCTION pg_temp.app_groups_here(boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION pg_temp.app_logins_here(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION pg_temp.role_is_foreign_here(oid) FROM PUBLIC;
-- <<< tenancy role helpers

\echo '== this database'
SELECT current_database() AS database, u.unit, u.silo_key, u.env,
       array_to_string(u.app_groups, ', ') AS app_groups,
       (SELECT rolname FROM pg_roles WHERE oid = d.datdba) AS owner,
       (d.datacl IS NULL OR EXISTS (SELECT 1 FROM aclexplode(d.datacl) a
                                     WHERE a.grantee = 0 AND a.privilege_type = 'CONNECT')) AS public_can_connect
  FROM pg_temp.this_database_unit() u, pg_database d
 WHERE d.datname = current_database();

\echo '== explicit database grants (datacl)'
SELECT CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END AS grantee,
       string_agg(a.privilege_type, ',' ORDER BY a.privilege_type) AS privileges
  FROM pg_database d, aclexplode(d.datacl) a
 WHERE d.datname = current_database()
 GROUP BY 1 ORDER BY 1;

\echo '== roles of OTHER databases that can CONNECT here'
SELECT r.rolname AS foreign_login
  FROM pg_roles r
 WHERE r.rolcanlogin
   AND pg_temp.role_is_foreign_here(r.oid)
   AND has_database_privilege(r.oid, current_database(), 'CONNECT')
 ORDER BY 1;

\echo '== privileges held HERE by roles of other databases (pg_shdepend: a = acl, o = owner)'
SELECT r.rolname AS foreign_role,
       count(*) FILTER (WHERE s.deptype = 'a') AS acl_entries,
       count(*) FILTER (WHERE s.deptype = 'o') AS owns,
       left(string_agg(DISTINCT pg_describe_object(s.classid, s.objid, 0), '; '), 400) AS objects
  FROM pg_shdepend s
  JOIN pg_roles r ON r.oid = s.refobjid
 WHERE s.dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
   AND s.deptype IN ('a', 'o')
   AND pg_temp.role_is_foreign_here(r.oid)
 GROUP BY r.rolname
 ORDER BY 1;

\echo '== every role on the server and what it is to THIS database'
SELECT r.rolname,
       r.rolcanlogin AS login,
       CASE WHEN r.rolsuper OR r.rolcreaterole OR r.rolname ~ '^(pg_|azure)' OR r.rolname = current_user THEN 'infra'
            WHEN pg_temp.role_is_foreign_here(r.oid) THEN 'FOREIGN'
            ELSE 'ok' END AS here,
       has_database_privilege(r.oid, current_database(), 'CONNECT') AS can_connect,
       (SELECT count(*) FROM pg_shdepend s
         WHERE s.refobjid = r.oid AND s.deptype = 'a'
           AND s.dbid = (SELECT oid FROM pg_database WHERE datname = current_database())) AS acl_entries_here,
       (SELECT string_agg(g.rolname, ',' ORDER BY g.rolname) FROM pg_auth_members m
          JOIN pg_roles g ON g.oid = m.roleid WHERE m.member = r.oid) AS member_of
  FROM pg_roles r
 WHERE r.rolname !~ '^pg_'
 ORDER BY 3, 1;

\echo '== summary'
SELECT format('ISOLATION %s: unit=%s foreign_roles_with_privileges=%s foreign_logins_can_connect=%s public_can_connect=%s',
              current_database(), (pg_temp.this_database_unit()).unit,
              (SELECT count(DISTINCT s.refobjid) FROM pg_shdepend s
                WHERE s.dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
                  AND s.deptype IN ('a', 'o') AND pg_temp.role_is_foreign_here(s.refobjid)),
              (SELECT count(*) FROM pg_roles r WHERE r.rolcanlogin AND pg_temp.role_is_foreign_here(r.oid)
                  AND has_database_privilege(r.oid, current_database(), 'CONNECT')),
              (SELECT d.datacl IS NULL OR EXISTS (SELECT 1 FROM aclexplode(d.datacl) a
                                                   WHERE a.grantee = 0 AND a.privilege_type = 'CONNECT')
                 FROM pg_database d WHERE d.datname = current_database())) AS summary;
