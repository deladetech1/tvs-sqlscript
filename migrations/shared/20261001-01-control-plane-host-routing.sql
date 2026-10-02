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
-- how core_platform is already shared. Discovered by pattern rather than named,
-- because the group's name carries the environment (tvs_app_dev,
-- tvs_app_bgclt_prod) while this file is identical in all of them.
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
    FOR grp IN
        SELECT rolname
          FROM pg_roles
         WHERE rolname LIKE 'tvs\_app\_%'
           AND NOT rolcanlogin
    LOOP
        EXECUTE format('GRANT USAGE ON SCHEMA control_plane TO %I', grp);
        EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA control_plane TO %I', grp);
        EXECUTE format(
            'ALTER DEFAULT PRIVILEGES IN SCHEMA control_plane GRANT SELECT ON TABLES TO %I',
            grp);
        RAISE NOTICE 'control_plane: granted read-only access to %', grp;
    END LOOP;
END $$;
