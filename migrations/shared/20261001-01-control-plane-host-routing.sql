-- =====================================================================
-- Which database a request belongs to, decided by the address it arrived at
-- ---------------------------------------------------------------------
-- Today every pod knows its database before any request arrives: DATABASE_URL
-- is in the environment, the pool is built at startup, and `get_db_cursor()`
-- takes no argument because there is only ever one answer. That holds exactly
-- as long as one deployment serves one database.
--
-- It stops holding the moment a tenant has a database of its own. The pod
-- cannot know which one from its environment, because the environment is the
-- same for every request it serves. The only thing that differs per request,
-- before any authentication has happened, is the address the browser asked
-- for. So that is what decides.
--
-- This migration adds the table that decision reads. It changes no behaviour:
-- nothing in any application reads it yet, every row it seeds is POOLED, and
-- POOLED means "the database this pod was already configured with". It is the
-- vocabulary, shipped ahead of the thing that speaks it.
--
-- Why a schema of its own
-- -----------------------
-- These rows are not tenant data and must never move with it. When a tenant's
-- data goes to a database of its own, this table stays where it is -- it is
-- the thing that knows WHERE that database is, so it cannot live inside it.
-- A separate schema says so, and leaves room to move the whole thing to its
-- own server later without renaming anything.
--
-- `ctl_` rather than `cp_`: core_platform already owns the `cp_` prefix, and
-- two tables called cp_cells in two schemas is a mistake waiting to be made
-- in an f-string.
--
-- Why tenant_id is nullable
-- -------------------------
-- The apex serves EVERY pooled tenant. trovesuite.com does not name one
-- tenant and never will, so a route row for it cannot carry a tenant_id. The
-- rule that falls out is the one the application will enforce:
--
--     route names a tenant   ->  the JWT's tenant_id MUST equal it
--     route names no tenant  ->  the JWT alone decides, as it does today
--
-- That is what keeps the apex behaving exactly as it behaves now, while a
-- tenant on its own address is pinned to itself.
--
-- Why POOLED leaves the database columns empty
-- --------------------------------------------
-- The pooled database is the cell's own, configured into the pod by
-- terragrunt. Copying its hostname in here would create a second source of
-- truth for a value that already exists, and a second place for it to go
-- stale after a failover. NULL means "whatever this pod was configured with".
--
-- The hazard in that is obvious: if NULL ever reaches a SILO row, that
-- tenant silently gets the SHARED database, which is a cross-tenant data
-- leak wearing the costume of a config default. ck_ctl_routes_silo_has_db
-- makes that row impossible to insert. The constraint is the safety, not the
-- application code -- application code gets refactored.
--
-- No delete_status, deliberately
-- ------------------------------
-- A soft-deleted route row is a row that still answers. Routing must not have
-- a state that means "ignore me, but I am still here": either a host resolves
-- or it does not. Lifecycle lives in `status`, and a host that should stop
-- working gets its row removed.
--
-- Idempotent; safe to re-run on every deploy.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS control_plane;

-- ---------------------------------------------------------------------
-- A cell: one regional deployment. Compute, databases and storage in one
-- region, serving every tier that lives there. A tenant belongs to exactly
-- one, and "move this tenant to another region" is a migration, not an edit.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS control_plane.ctl_cells (
    cell_key    text        NOT NULL,
    region      text        NOT NULL,
    -- Where this cell answers. Only read when a host belongs to a cell other
    -- than the one serving the request -- otherwise the request is already here.
    api_base    text,
    status      text        NOT NULL DEFAULT 'ACTIVE',

    cdate       text,
    ctime       text,
    cdatetime   timestamptz,
    created_by  text,
    udatetime   timestamptz,
    updated_by  text,

    CONSTRAINT pk_ctl_cells PRIMARY KEY (cell_key),
    CONSTRAINT ck_ctl_cells_status CHECK (status IN ('ACTIVE', 'DRAINING'))
);

-- ---------------------------------------------------------------------
-- A host, and everything a request arriving at it needs before it has been
-- authenticated.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS control_plane.ctl_tenant_routes (
    -- Normalised by the resolver before it ever gets here: lower-cased, no
    -- port, no trailing dot. Stored the same way, or a lookup misses on a
    -- capital letter.
    host                text        NOT NULL,

    -- NULL at the apex, which serves every pooled tenant. See the header.
    tenant_id           text,

    tier                text        NOT NULL,
    cell_key            text        NOT NULL,

    -- NULL for POOLED: use the database this pod was configured with.
    db_server_fqdn      text,
    db_name             text,
    -- A Key Vault secret URI, never a credential. The pod's managed identity
    -- resolves it at run time; this column leaking tells an attacker only
    -- where a secret lives, not what it is.
    db_secret_uri       text,

    storage_account     text,
    container_prefix    text,
    storage_secret_uri  text,

    -- For a host answered by another cell, or by a customer's own deployment.
    api_base            text,

    status              text        NOT NULL DEFAULT 'ACTIVE',
    -- What schema version this database is known to be at. Only meaningful
    -- once databases can lag each other, which is the moment there is more
    -- than one of them.
    schema_version      text,

    cdate               text,
    ctime               text,
    cdatetime           timestamptz,
    created_by          text,
    udatetime           timestamptz,
    updated_by          text,

    CONSTRAINT pk_ctl_tenant_routes PRIMARY KEY (host),
    CONSTRAINT fk_ctl_tenant_routes_cell
        FOREIGN KEY (cell_key) REFERENCES control_plane.ctl_cells (cell_key),
    CONSTRAINT ck_ctl_tenant_routes_tier CHECK (
        tier IN ('POOLED', 'SILO_SHARED', 'SILO_DEDICATED', 'SELF_MANAGED')
    ),
    CONSTRAINT ck_ctl_tenant_routes_status CHECK (
        status IN ('PROVISIONING', 'ACTIVE', 'MIGRATING', 'SUSPENDED')
    ),
    -- The one that matters: a silo row without its own database would fall
    -- back to the shared one.
    CONSTRAINT ck_ctl_routes_silo_has_db CHECK (
        tier NOT IN ('SILO_SHARED', 'SILO_DEDICATED')
        OR (db_name IS NOT NULL AND db_secret_uri IS NOT NULL)
    ),
    -- A host that is pinned to one tenant must say which. Only the apex may
    -- decline to name one, and only because it serves all of them.
    CONSTRAINT ck_ctl_routes_nonpooled_has_tenant CHECK (
        tier = 'POOLED' OR tenant_id IS NOT NULL
    )
);

-- "Where does this tenant live?" -- asked by provisioning, by support, and by
-- any flow that has a tenant and needs its address.
CREATE INDEX IF NOT EXISTS ix_ctl_tenant_routes_tenant
    ON control_plane.ctl_tenant_routes (tenant_id)
    WHERE tenant_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- Seed: the cells and hosts that exist today. Every one is POOLED, because
-- every one is served by a deployment that already has exactly one database.
--
-- All environments' rows are seeded into all databases. A row for a host that
-- never arrives here is inert, and the alternative -- per-environment seed
-- files -- means dev has no data to test the resolver against.
--
-- bgclt needs no special case, which is worth noticing: from inside its own
-- cell, bgclt's database IS the pooled database. Its pods are configured with
-- it, so POOLED is not a simplification there, it is the truth.
-- ---------------------------------------------------------------------
INSERT INTO control_plane.ctl_cells
    (cell_key, region, api_base, status, cdate, ctime, cdatetime, created_by)
VALUES
    ('uksouth-dev',     'uksouth', NULL, 'ACTIVE', CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration'),
    ('uksouth-staging', 'uksouth', NULL, 'ACTIVE', CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration'),
    ('uksouth-prod',    'uksouth', NULL, 'ACTIVE', CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration'),
    ('bgclt-prod',      'uksouth', NULL, 'ACTIVE', CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration')
ON CONFLICT (cell_key) DO NOTHING;

INSERT INTO control_plane.ctl_tenant_routes
    (host, tenant_id, tier, cell_key, status, cdate, ctime, cdatetime, created_by)
VALUES
    -- prod
    ('trovesuite.com',                  NULL, 'POOLED', 'uksouth-prod',    'ACTIVE', CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration'),
    ('www.trovesuite.com',              NULL, 'POOLED', 'uksouth-prod',    'ACTIVE', CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration'),
    ('mystoreguard.trovesuite.com',     NULL, 'POOLED', 'uksouth-prod',    'ACTIVE', CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration'),
    ('loandrift.trovesuite.com',        NULL, 'POOLED', 'uksouth-prod',    'ACTIVE', CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration'),
    ('zeloshr-admin.trovesuite.com',    NULL, 'POOLED', 'uksouth-prod',    'ACTIVE', CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration'),
    -- staging
    ('staging.trovesuite.com',               NULL, 'POOLED', 'uksouth-staging', 'ACTIVE', CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration'),
    ('mystoreguard.stage.trovesuite.com',    NULL, 'POOLED', 'uksouth-staging', 'ACTIVE', CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration'),
    ('loandrift.stage.trovesuite.com',       NULL, 'POOLED', 'uksouth-staging', 'ACTIVE', CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration'),
    ('zeloshr-admin.stage.trovesuite.com',   NULL, 'POOLED', 'uksouth-staging', 'ACTIVE', CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration'),
    -- dev
    ('dev.trovesuite.com',                   NULL, 'POOLED', 'uksouth-dev', 'ACTIVE', CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration'),
    ('mystoreguard.dev.trovesuite.com',      NULL, 'POOLED', 'uksouth-dev', 'ACTIVE', CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration'),
    ('loandrift.dev.trovesuite.com',         NULL, 'POOLED', 'uksouth-dev', 'ACTIVE', CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration'),
    ('zeloshr-admin.dev.trovesuite.com',     NULL, 'POOLED', 'uksouth-dev', 'ACTIVE', CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration'),
    ('zeloshr.dev.trovesuite.com',           NULL, 'POOLED', 'uksouth-dev', 'ACTIVE', CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration'),
    ('localhost',                            NULL, 'POOLED', 'uksouth-dev', 'ACTIVE', CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration'),
    -- bgclt: its own cell, and its own database is that cell's pooled one
    ('bgclt.trovesuite.com',                 NULL, 'POOLED', 'bgclt-prod',  'ACTIVE', CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration')
ON CONFLICT (host) DO NOTHING;

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
CREATE OR REPLACE FUNCTION control_plane.this_database_unit(
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
CREATE OR REPLACE FUNCTION control_plane.app_groups_here(pooled_shape_only boolean DEFAULT false)
RETURNS SETOF text
LANGUAGE sql STABLE AS $fn$
    SELECT g
      FROM unnest((control_plane.this_database_unit()).app_groups) AS g
     WHERE NOT pooled_shape_only OR g ~ '^tvs_app_[a-z0-9]+$'
     ORDER BY g
$fn$;

-- This database's login(s) for one application, e.g. app_logins_here('mystoreguard'):
--   silo    mystoreguard_<key>_<env>
--   pooled  mystoreguard_<env> (one per pooled environment sharing the database)
--   single  ^mystoreguard(_|$) -- the old behaviour, on a one-client server
CREATE OR REPLACE FUNCTION control_plane.app_logins_here(app text)
RETURNS SETOF text
LANGUAGE sql STABLE AS $fn$
    WITH u AS (SELECT * FROM control_plane.this_database_unit())
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
CREATE OR REPLACE FUNCTION control_plane.role_is_foreign_here(r oid)
RETURNS boolean
LANGUAGE plpgsql STABLE AS $fn$
DECLARE
    u  record;
    rr record;
BEGIN
    SELECT * INTO u FROM control_plane.this_database_unit();
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
REVOKE ALL ON FUNCTION control_plane.this_database_unit() FROM PUBLIC;
REVOKE ALL ON FUNCTION control_plane.app_groups_here(boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION control_plane.app_logins_here(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION control_plane.role_is_foreign_here(oid) FROM PUBLIC;
-- <<< tenancy role helpers

-- ---------------------------------------------------------------------
-- Let the applications READ this, and only read it.
--
-- The schema is created by the migrator and so owned by it, which leaves every
-- app role unable to see it at all. A resolver running as mystoreguard_dev gets
-- "permission denied for schema control_plane" and -- because it treats any
-- failure as "no route rather than a wrong one" -- quietly decides every host is
-- unknown. That is exactly the silent nothing this table exists to prevent, and
-- it is the failure this block was added in response to: the first deploy
-- created the tables and no application could see them.
--
-- Granted to the tvs_app_<env> group rather than to each login role, which is
-- how core_platform is already shared. Discovered rather than named, because the
-- group's name carries the environment (tvs_app_dev, tvs_app_bgclt_prod) while
-- this file is identical in all of them -- but discovered from THIS DATABASE
-- (control_plane.app_groups_here(), above), never by pattern alone. Until
-- 2026-10-23 it was every `tvs\_app\_%` group in the cluster, so on the shared
-- server each silo's group could read every other silo's control_plane, and the
-- default privilege below kept handing them each new table.
--
-- SELECT only, deliberately. An application resolves a route. It must never
-- write one. If an app role could UPDATE ctl_tenant_routes it could point a
-- host at another tenant's database, which is the worst thing anything in this
-- design can do -- so the privilege that would allow it is withheld rather than
-- merely left unused. Provisioning writes these rows as the migrator.
--
-- That is also why this is here rather than in the db-app-group terraform unit:
-- that module grants its group full CRUD on the schemas it manages, which is
-- right for application data and wrong for the table that decides which
-- database application data lives in.
--
-- Idempotent: re-granting an existing privilege is a no-op.
-- ---------------------------------------------------------------------
DO $$
DECLARE
    grp text;
BEGIN
    FOR grp IN SELECT control_plane.app_groups_here()
    LOOP
        EXECUTE format('GRANT USAGE ON SCHEMA control_plane TO %I', grp);
        EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA control_plane TO %I', grp);
        EXECUTE format(
            'ALTER DEFAULT PRIVILEGES IN SCHEMA control_plane GRANT SELECT ON TABLES TO %I',
            grp);
        RAISE NOTICE 'control_plane: granted read-only access to %', grp;
    END LOOP;
END $$;
