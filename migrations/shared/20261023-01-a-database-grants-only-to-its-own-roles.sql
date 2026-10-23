-- =====================================================================================
-- A database grants only to its OWN roles. Take back what other databases' roles hold.
--
-- Found 2026-10-22 (silo-cross-tenant-pattern-grants): offboarding regtest could not
-- drop mystoreguard_regtest_dev, because it still held privileges inside silo-itech-dev
-- and dev-db. PostgreSQL roles are per SERVER, one server holds several of our
-- databases (tvs-shared-sql: dev-db and every SILO_SHARED client), and shared
-- migrations granted to every role matching a NAME PATTERN in whatever database they
-- ran in -- so each silo's roles held rights in every other database on that server:
--
--   20261019-22  ^mystoreguard(_|$)  EXECUTE invoicing.msg_queue_claim / msg_queue_done
--   20261001-01  tvs\_app\_%         USAGE + SELECT on all of control_plane + DEFAULT PRIVILEGES
--   20261003-05, 20261007-05, 20261008-01, 20261008-02
--                tvs_app_%           EXECUTE reconcile_route_tenant, tenant_host_refusal,
--                                    label_for_name, move_tenant_host; SELECT on the tenant
--                                    route view; the console logins DML on it
--   20261006-02, 20261006-03
--                ^tvs_app_[a-z0-9]+$ the POOLED group inside every silo database
--   20260922-01  fixed pooled names  DML on a silo's attendance data to the pooled ZelosHR
--   saas/20261004-01, -03, 20261007-03
--                tvs_app_[a-z0-9_]   every silo group INSERT on the pooled billing ledger
--                                    and DML on ctl_storage_credentials
--
-- Those files now grant through control_plane.app_groups_here() / app_logins_here()
-- (20261001-01), which derive the roles from current_database(). This file:
--
--   1. makes the attendance grants on a database's FIRST deploy (20260922-01 sorts
--      before control_plane exists and skips then);
--   2. revokes, every deploy, every privilege a role of ANOTHER database holds here
--      (control_plane.role_is_foreign_here) -- table, column, sequence, schema,
--      function, type and default privileges;
--   3. checks the invariant. A leftover the migrator could have revoked (it is the
--      grantor) fails the deploy: that is this file's own bug. A leftover it cannot
--      revoke (somebody else granted it, or a foreign role OWNS something here) is
--      reported with the exact SQL for the server admin and does NOT fail the deploy --
--      a blocking assert on something the pipeline cannot fix would stop every later
--      migration on every database (sqlscript-shared-file-cannot-require-a-module-seed).
--
-- CONNECT is not here: a database belongs to the server admin, so revoking it from
-- PUBLIC is the IaC's (postgresql-app-group revoke_public). Reported, never fixed here.
--
-- Nothing happens on a one-client server (unit 'single': enterprise, BYOD) or where the
-- database's own group cannot be found -- the revoke needs to know whose database it is.
--
-- Idempotent; safe to re-run.
-- =====================================================================================

-- ------------------------------------------------------------------ 1. attendance
DO $$
DECLARE
    r text;
    u text;
BEGIN
    IF to_regnamespace('attendance') IS NULL THEN
        RAISE NOTICE 'attendance: no schema here, nothing to grant';
        RETURN;
    END IF;
    u := (control_plane.this_database_unit()).unit;
    FOR r IN
        SELECT control_plane.app_groups_here()
        UNION
        SELECT x FROM unnest(ARRAY['zeloshradmin', 'zeloshremployee', 'tvs_app']) AS x
         WHERE u = 'single' AND EXISTS (SELECT 1 FROM pg_roles WHERE rolname = x)
    LOOP
        EXECUTE format('GRANT USAGE ON SCHEMA attendance TO %I', r);
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA attendance TO %I', r);
        EXECUTE format('GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA attendance TO %I', r);
        EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA attendance '
                       'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO %I', r);
        EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA attendance '
                       'GRANT USAGE, SELECT ON SEQUENCES TO %I', r);
    END LOOP;
END $$;

-- ------------------------------------------------- every foreign ACL entry, one row each
-- A view would be an object other roles could be granted on; a function in
-- control_plane owned by the migrator and executable by nobody else is the same query
-- in one place for the revoke, the check and the report.
CREATE OR REPLACE FUNCTION control_plane.foreign_privileges_here()
RETURNS TABLE (grantee text, grantor text, owner text, kind text, object text, revoke_sql text)
LANGUAGE sql STABLE AS $fn$
    WITH acl AS (
        -- tables, views, sequences
        SELECT c.relowner AS owner_oid, a.grantee AS g, a.grantor AS gr,
               CASE c.relkind WHEN 'S' THEN 'sequence' ELSE 'table' END AS kind,
               c.oid::regclass::text AS object,
               format('REVOKE ALL ON %s %s FROM %%I',
                      CASE c.relkind WHEN 'S' THEN 'SEQUENCE' ELSE 'TABLE' END,
                      c.oid::regclass::text) AS tmpl
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          CROSS JOIN LATERAL aclexplode(c.relacl) a
         WHERE n.nspname NOT IN ('pg_catalog', 'information_schema') AND n.nspname !~ '^pg_toast'
        UNION ALL
        -- columns
        SELECT c.relowner, a.grantee, a.grantor, 'column',
               c.oid::regclass::text || '.' || quote_ident(att.attname),
               format('REVOKE ALL (%I) ON TABLE %s FROM %%I', att.attname, c.oid::regclass::text)
          FROM pg_attribute att
          JOIN pg_class c ON c.oid = att.attrelid
          JOIN pg_namespace n ON n.oid = c.relnamespace
          CROSS JOIN LATERAL aclexplode(att.attacl) a
         WHERE n.nspname NOT IN ('pg_catalog', 'information_schema') AND att.attacl IS NOT NULL
        UNION ALL
        -- schemas
        SELECT n.nspowner, a.grantee, a.grantor, 'schema', quote_ident(n.nspname),
               format('REVOKE ALL ON SCHEMA %I FROM %%I', n.nspname)
          FROM pg_namespace n
          CROSS JOIN LATERAL aclexplode(n.nspacl) a
         WHERE n.nspname NOT IN ('pg_catalog', 'information_schema') AND n.nspname !~ '^pg_'
        UNION ALL
        -- functions and procedures
        SELECT p.proowner, a.grantee, a.grantor,
               CASE p.prokind WHEN 'p' THEN 'procedure' ELSE 'function' END,
               p.oid::regprocedure::text,
               format('REVOKE ALL ON %s %s FROM %%I',
                      CASE p.prokind WHEN 'p' THEN 'PROCEDURE' ELSE 'FUNCTION' END,
                      p.oid::regprocedure::text)
          FROM pg_proc p
          JOIN pg_namespace n ON n.oid = p.pronamespace
          CROSS JOIN LATERAL aclexplode(p.proacl) a
         WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
        UNION ALL
        -- types and domains
        SELECT t.typowner, a.grantee, a.grantor, 'type', t.oid::regtype::text,
               format('REVOKE ALL ON TYPE %s FROM %%I', t.oid::regtype::text)
          FROM pg_type t
          JOIN pg_namespace n ON n.oid = t.typnamespace
          CROSS JOIN LATERAL aclexplode(t.typacl) a
         WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
        UNION ALL
        -- default privileges (whoever creates the object next hands it out)
        SELECT d.defaclrole, a.grantee, d.defaclrole, 'default privileges',
               format('for role %s%s on %s', pg_get_userbyid(d.defaclrole),
                      CASE WHEN d.defaclnamespace = 0 THEN ''
                           ELSE ' in schema ' || quote_ident(nn.nspname) END,
                      CASE d.defaclobjtype WHEN 'r' THEN 'tables' WHEN 'S' THEN 'sequences'
                           WHEN 'f' THEN 'functions' WHEN 'T' THEN 'types' WHEN 'n' THEN 'schemas' END),
               format('ALTER DEFAULT PRIVILEGES FOR ROLE %I%s REVOKE ALL ON %s FROM %%I',
                      pg_get_userbyid(d.defaclrole),
                      CASE WHEN d.defaclnamespace = 0 THEN ''
                           ELSE format(' IN SCHEMA %I', nn.nspname) END,
                      CASE d.defaclobjtype WHEN 'r' THEN 'TABLES' WHEN 'S' THEN 'SEQUENCES'
                           WHEN 'f' THEN 'FUNCTIONS' WHEN 'T' THEN 'TYPES' WHEN 'n' THEN 'SCHEMAS' END)
          FROM pg_default_acl d
          LEFT JOIN pg_namespace nn ON nn.oid = d.defaclnamespace
          CROSS JOIN LATERAL aclexplode(d.defaclacl) a
    )
    , foreign_roles AS MATERIALIZED (
        -- decided once per role, not once per privilege
        SELECT r.oid FROM pg_roles r WHERE control_plane.role_is_foreign_here(r.oid)
    )
    SELECT pg_get_userbyid(acl.g)::text, pg_get_userbyid(acl.gr)::text,
           pg_get_userbyid(acl.owner_oid)::text, acl.kind, acl.object,
           format(acl.tmpl, pg_get_userbyid(acl.g))
      FROM acl
     WHERE acl.g IN (SELECT oid FROM foreign_roles)    -- PUBLIC (0) is never in it
     ORDER BY 1, 4, 5
$fn$;
REVOKE ALL ON FUNCTION control_plane.foreign_privileges_here() FROM PUBLIC;

-- ------------------------------------------- 2. take it back, 3. check the invariant
-- One block, so the check knows which revokes the server refused: those are reported
-- for the admin like any other leftover, never a reason to stop the deploy.
DO $$
DECLARE
    u        record;
    p        record;
    done     integer := 0;
    refused  text[]  := '{}';
    ours     integer := 0;
    theirs   integer := 0;
    owned    text;
    conn     text;
BEGIN
    SELECT * INTO u FROM control_plane.this_database_unit();
    IF u.unit = 'single' THEN
        RAISE NOTICE 'isolation: % is the only client database on its server (unit single); nothing to take back',
            current_database();
        RETURN;
    END IF;
    IF cardinality(u.app_groups) = 0 THEN
        RAISE WARNING 'isolation: % looks like a % database but its own app group does not exist, '
                      'so whose roles are foreign cannot be decided; nothing revoked',
            current_database(), u.unit;
        RETURN;
    END IF;

    -- 2. every privilege a role of another database holds here
    FOR p IN SELECT DISTINCT f.revoke_sql FROM control_plane.foreign_privileges_here() f LOOP
        BEGIN
            EXECUTE p.revoke_sql;
            done := done + 1;
        EXCEPTION WHEN OTHERS THEN
            refused := refused || p.revoke_sql;
            RAISE NOTICE 'isolation: the server refused "%": %', p.revoke_sql, SQLERRM;
        END;
    END LOOP;
    RAISE NOTICE 'isolation: % (unit %, own group(s) %): % revoke(s) run, % refused',
        current_database(), u.unit, array_to_string(u.app_groups, ', '), done, cardinality(refused);

    -- 3. what is left
    FOR p IN SELECT * FROM control_plane.foreign_privileges_here() LOOP
        IF p.grantor = current_user AND NOT p.revoke_sql = ANY (refused) THEN
            ours := ours + 1;
            RAISE WARNING 'isolation: % still holds % % (granted by %) -- %',
                p.grantee, p.kind, p.object, p.grantor, p.revoke_sql;
        ELSE
            theirs := theirs + 1;
            RAISE WARNING 'isolation: NEEDS THE SERVER ADMIN in %: % holds a privilege on % % granted by %; run as % (or the admin): %;',
                current_database(), p.grantee, p.kind, p.object, p.grantor, p.grantor, p.revoke_sql;
        END IF;
    END LOOP;

    -- A foreign role that OWNS something here cannot be fixed by a revoke at all.
    SELECT string_agg(DISTINCT format('%s owns %s (REASSIGN OWNED BY %I TO %I)', r.rolname,
                                      pg_describe_object(s.classid, s.objid, 0), r.rolname, current_user), '; ')
      INTO owned
      FROM pg_shdepend s JOIN pg_roles r ON r.oid = s.refobjid
     WHERE s.dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
       AND s.deptype = 'o' AND control_plane.role_is_foreign_here(r.oid);
    IF owned IS NOT NULL THEN
        RAISE WARNING 'isolation: NEEDS THE SERVER ADMIN in %: %', current_database(), owned;
    END IF;

    -- CONNECT belongs to the IaC (postgresql-app-group revoke_public). Said, not fixed.
    SELECT string_agg(r.rolname, ', ' ORDER BY r.rolname) INTO conn
      FROM pg_roles r
     WHERE r.rolcanlogin AND control_plane.role_is_foreign_here(r.oid)
       AND has_database_privilege(r.oid, current_database(), 'CONNECT');
    IF conn IS NOT NULL THEN
        RAISE WARNING 'isolation: logins of other databases can CONNECT to %: % -- the database''s '
                      'app-group unit must revoke CONNECT from PUBLIC (revoke_public = true) and '
                      'grant it only to its own roles',
            current_database(), conn;
    END IF;

    -- The invariant. Only what this file could have removed and did not.
    IF ours > 0 THEN
        RAISE EXCEPTION 'isolation: % privilege(s) granted by % to roles of other databases survived '
                        'the revoke in this file -- a bug here, not a permission problem',
            ours, current_user;
    END IF;
    RAISE NOTICE 'isolation: % holds no privilege for another database''s roles that the migrator '
                 'could remove (% left for the server admin)', current_database(), theirs;
END $$;
