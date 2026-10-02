-- =====================================================================================
-- A SECOND shared-silo tenant, so per-tenant separation is checkable.
--
-- The first two silos were named after their KIND -- `shared` and `dedicated` -- which
-- reads as though every shared-silo tenant shares one set of `shared-*` containers.
-- They do not. A silo holds exactly one tenant (see migrations/silo/...), so the silo
-- key IS the tenant, and everything derived from it is that tenant's alone:
--
--   database          silo-<key>-dev
--   roles             <app>_<key>_dev
--   secrets           db-url-<app>-<key>
--   containers        <key>-<container>, inside each app's own account
--
-- tenantb is a second tenant of the SAME kind, on the same server and in the same app
-- storage accounts as `shared`. Its containers sit beside shared-*, not inside them.
-- That is the thing to test: two shared-silo tenants, one set of infrastructure, no
-- overlap anywhere.
-- =====================================================================================

INSERT INTO control_plane.ctl_tenant_routes
    (host, tenant_id, tier, cell_key,
     db_server_fqdn, db_name, silo_key, db_secret_uri,
     storage_account, container_prefix, storage_secret_uri,
     status, is_wildcard, cdate, ctime, cdatetime, created_by)
VALUES
    ('tenantb.dev.trovesuite.com',
     'tnt_tenantb_test', 'SILO_SHARED', 'uksouth-dev',
     'tvs-shared-sql.postgres.database.azure.com', 'silo-tenantb-dev', 'tenantb', NULL,
     -- No storage account: a shared silo keeps each app's own, and prefixes its
     -- containers inside them. The prefix is the silo key, so it is this tenant's.
     NULL, 'tenantb', NULL,
     'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261002-08')
ON CONFLICT (host) DO UPDATE
   SET tenant_id        = EXCLUDED.tenant_id,
       tier             = EXCLUDED.tier,
       db_server_fqdn   = EXCLUDED.db_server_fqdn,
       db_name          = EXCLUDED.db_name,
       silo_key         = EXCLUDED.silo_key,
       storage_account  = EXCLUDED.storage_account,
       container_prefix = EXCLUDED.container_prefix,
       udatetime        = now(),
       updated_by       = 'migration 20261002-08';

-- ----------------------------------------------------------------------------- checks
-- Safe where there are no route rows: migrations/shared reaches every silo's own
-- database, where control_plane exists and is empty.
DO $$
DECLARE n integer;
BEGIN
    -- The property the second tenant exists to prove: among silo rows, no two
    -- tenants share a database, and no two share a container prefix.
    SELECT count(*) INTO n FROM (
        SELECT db_name FROM control_plane.ctl_tenant_routes
         WHERE tier IN ('SILO_SHARED','SILO_DEDICATED')
         GROUP BY db_name HAVING count(DISTINCT tenant_id) > 1) x;
    IF n > 0 THEN
        RAISE EXCEPTION '% silo database(s) are claimed by more than one tenant', n;
    END IF;

    SELECT count(*) INTO n FROM (
        SELECT container_prefix FROM control_plane.ctl_tenant_routes
         WHERE tier = 'SILO_SHARED' AND container_prefix IS NOT NULL
         GROUP BY container_prefix HAVING count(DISTINCT tenant_id) > 1) x;
    IF n > 0 THEN
        RAISE EXCEPTION '% container prefix(es) are claimed by more than one tenant', n;
    END IF;

    -- And the prefix is the silo key, so it cannot drift from the IaC that
    -- creates the containers.
    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE tier = 'SILO_SHARED' AND container_prefix IS DISTINCT FROM silo_key;
    IF n > 0 THEN
        RAISE EXCEPTION '% shared silo(s) have a container_prefix that is not their silo_key', n;
    END IF;

    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host = 'tenantb.dev.trovesuite.com') THEN
        RAISE NOTICE 'tenantb registered: its own database and its own tenantb-* containers';
    END IF;
END $$;
