-- =====================================================================================
-- A silo row names the SILO; each app resolves its own credential from that.
--
-- The two silo rows were written when a silo had ONE credential, so they carried one
-- db_secret_uri and ck_ctl_routes_silo_has_db required it. Provisioning the silos for
-- real ended that: a silo has a login role PER APP, because sharing one credential
-- across five apps means one leak reaches all of them, and sharing it across tenants
-- is the thing a silo exists to prevent. There are now five db-url-<app>-<silo>
-- secrets per silo plus a read-only one for the tenant, and no single URI can stand
-- for them.
--
-- So the row says WHICH SILO and the app says WHO IT IS:
--
--     secret name = db-url-<app-slug>-<silo_key>
--
-- which is the pooled db-url-<app-slug> plus a suffix. The row still never carries a
-- credential, and now it does not even carry a secret's address -- it carries a name
-- that an app combines with its own identity. Key Vault RBAC decides the rest.
--
-- db_secret_uri is kept, not dropped: a silo whose apps DO share one credential is
-- still expressible, and SELF_MANAGED rows may want it. The constraint now accepts
-- either form, and refuses a silo that offers neither -- which is the case that would
-- quietly fall back to the pooled database.
--
-- The rows are also repointed at infrastructure that exists. They were written against
-- hand-made resources that have since been deleted and replaced by Terraform:
--
--   silo-shared-test        -> silo-shared-dev
--   tvs-dev-silotest-sql    -> tvs-dev-silo-dedicated-sql   (the old server is deleted)
--   tvsdevsilotestsa        -> tvsdevsilodedicatedsa        (deleted with its RG)
--   silosharedtest          -> shared                       (container prefix)
--   tvsdevmsgsa             -> NULL                         (storage is per app)
--   silo-*-test-db-url      -> NULL                         (both secrets deleted)
--
-- Leaving them would have pointed two tiers at a server that no longer resolves.
-- =====================================================================================

ALTER TABLE control_plane.ctl_tenant_routes
    ADD COLUMN IF NOT EXISTS silo_key text;

COMMENT ON COLUMN control_plane.ctl_tenant_routes.silo_key IS
    'Which silo this row addresses, as the IaC roster keys it (platform/<env>/silos/<key>). '
    'An app composes its own credential name as db-url-<app-slug>-<silo_key>, so the row '
    'never holds a secret or even a secret address. NULL for POOLED.';

-- Either form is acceptable; neither is not.
ALTER TABLE control_plane.ctl_tenant_routes
    DROP CONSTRAINT IF EXISTS ck_ctl_routes_silo_has_db;

ALTER TABLE control_plane.ctl_tenant_routes
    ADD CONSTRAINT ck_ctl_routes_silo_has_db CHECK (
        tier NOT IN ('SILO_SHARED', 'SILO_DEDICATED')
        OR (db_name IS NOT NULL
            AND (db_secret_uri IS NOT NULL OR silo_key IS NOT NULL))
    );

-- ------------------------------------------------------------------ the two dev rows
UPDATE control_plane.ctl_tenant_routes
   SET silo_key         = 'shared',
       db_name          = 'silo-shared-dev',
       db_server_fqdn   = 'tvs-shared-sql.postgres.database.azure.com',
       -- Own containers inside each APP's own account, prefixed with the silo
       -- key. storage_account stays NULL on purpose: storage is per app, so
       -- naming one would send every app to that app's account. 20261002-07
       -- adds the constraint that enforces it, and this statement has to agree
       -- with that constraint because every migration re-runs on each deploy.
       storage_account  = NULL,
       container_prefix = 'shared',
       db_secret_uri    = NULL,
       udatetime        = now(),
       updated_by       = 'migration 20261002-06'
 WHERE host = 'siloshared.dev.trovesuite.com';

UPDATE control_plane.ctl_tenant_routes
   SET silo_key         = 'dedicated',
       db_name          = 'silo-dedicated-dev',
       db_server_fqdn   = 'tvs-dev-silo-dedicated-sql.postgres.database.azure.com',
       -- its own storage ACCOUNT, so the containers need no prefix to stay apart
       storage_account  = 'tvsdevsilodedicatedsa',
       container_prefix = NULL,
       db_secret_uri    = NULL,
       udatetime        = now(),
       updated_by       = 'migration 20261002-06'
 WHERE host = 'silodedicated.dev.trovesuite.com';

-- ----------------------------------------------------------------------------- checks
--
-- Everything here must hold in a database that has NO route rows as well as in the
-- one that has them all. migrations/shared/ runs against every class, so this same
-- file is applied to each silo's own database, where control_plane exists and is
-- empty. A `SELECT * INTO rec` that matches nothing leaves the record with no field
-- structure at all, so `rec.silo_key` there does not read as NULL -- it raises
-- `record "r" has no field "silo_key"` and fails the deploy. Hence EXISTS guards
-- and per-column scalar selects rather than SELECT INTO on a record.
DO $$
DECLARE
    n integer;
    v_silo_key         text;
    v_db_name          text;
    v_server           text;
    v_storage          text;
    v_prefix           text;
BEGIN
    -- Every silo row present can be acted on: it names a database and a way to
    -- resolve a credential. Vacuously true where there are none.
    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE tier IN ('SILO_SHARED','SILO_DEDICATED')
       AND (db_name IS NULL OR (silo_key IS NULL AND db_secret_uri IS NULL));
    IF n > 0 THEN
        RAISE EXCEPTION '% silo route(s) name no database or no way to resolve a credential', n;
    END IF;

    -- A POOLED row must not claim a silo: it would make an app compose a secret
    -- name for a database it has no business reaching.
    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE tier = 'POOLED' AND silo_key IS NOT NULL;
    IF n > 0 THEN
        RAISE EXCEPTION '% pooled route(s) carry a silo_key', n;
    END IF;

    -- The dev rows, only where they live. The two tiers must still differ in the
    -- way the tier model says they do, now against resources Terraform created.
    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host = 'siloshared.dev.trovesuite.com') THEN
        SELECT silo_key, db_name, storage_account, container_prefix
          INTO v_silo_key, v_db_name, v_storage, v_prefix
          FROM control_plane.ctl_tenant_routes
         WHERE host = 'siloshared.dev.trovesuite.com';

        IF v_silo_key IS DISTINCT FROM 'shared' OR v_db_name IS DISTINCT FROM 'silo-shared-dev' THEN
            RAISE EXCEPTION 'the shared silo row was not repointed: silo_key=% db=%',
                v_silo_key, v_db_name;
        END IF;
        IF v_storage IS NOT NULL OR v_prefix IS NULL THEN
            RAISE EXCEPTION 'SILO_SHARED names no storage account and prefixes its containers';
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host = 'silodedicated.dev.trovesuite.com') THEN
        SELECT silo_key, db_name, db_server_fqdn, storage_account, container_prefix
          INTO v_silo_key, v_db_name, v_server, v_storage, v_prefix
          FROM control_plane.ctl_tenant_routes
         WHERE host = 'silodedicated.dev.trovesuite.com';

        IF v_silo_key IS DISTINCT FROM 'dedicated' OR v_db_name IS DISTINCT FROM 'silo-dedicated-dev' THEN
            RAISE EXCEPTION 'the dedicated silo row was not repointed: silo_key=% db=%',
                v_silo_key, v_db_name;
        END IF;
        IF v_storage = 'tvsdevmsgsa' OR v_prefix IS NOT NULL THEN
            RAISE EXCEPTION 'SILO_DEDICATED owns its storage account, so it needs no prefix';
        END IF;
        IF v_server LIKE 'tvs-dev-silotest%' OR v_server LIKE 'tvs-shared-sql%' THEN
            RAISE EXCEPTION 'SILO_DEDICATED must be on its own server, not %', v_server;
        END IF;
    END IF;

    RAISE NOTICE 'silo routes name their silo; credentials are resolved per app';
END $$;
