-- =====================================================================================
-- The dev silos are two named tenants: itech and accesspoint.
--
-- They were called `shared`, `dedicated` and `tenantb` -- the first two after their
-- KIND, which read as though every shared-silo tenant shared one set of `shared-*`
-- containers. They never did: a silo holds exactly one tenant, so the silo key IS the
-- tenant and everything derived from it is that tenant's alone. But a name that has to
-- be explained is the wrong name, and `tenantb` existed only to prove the point.
--
--   itech        SILO_SHARED     own DATABASE on the shared server, and its own
--                                itech-* containers inside each app's own account
--   accesspoint  SILO_DEDICATED  own SERVER and own STORAGE ACCOUNT
--
-- The three old hosts are removed rather than left as aliases. They named databases,
-- roles and containers that are being deleted, and a route row pointing at infrastructure
-- that no longer exists fails closed at best and reaches the wrong database at worst.
--
-- Still dev test tenants -- the ids are invented and own no real data -- but named the
-- way a real one would be, which is the point.
-- =====================================================================================

DELETE FROM control_plane.ctl_tenant_routes
 WHERE host IN (
   'siloshared.dev.trovesuite.com',
   'silodedicated.dev.trovesuite.com',
   'tenantb.dev.trovesuite.com'
 );

-- WHY THIS SEED IS GUARDED
--
-- route_kind is added by the LATER 20261003-07, with a default of 'PLATFORM' and a check
-- that refuses a customer's address resolving to the pooled database. Migrations re-run
-- on every deploy, which puts this statement in an impossible position:
--
--   * naming route_kind breaks the FIRST run, where the column does not exist yet;
--   * omitting it breaks every LATER run in which these rows are absent, because the
--     default 'PLATFORM' against a SILO tier is exactly what the check refuses.
--
-- The second case is not hypothetical. Both clients were cleared and set up again
-- through the console, and the next deploy died here -- one release after the constraint
-- was added, which is the worst possible delay for finding it.
--
-- So this file keeps its original form for a fresh database and stands aside once the
-- column exists; 20261004-02 owns these two rows from then on. That is the repo's own
-- rule -- a later migration wins -- rather than a second copy of the seed kept in step
-- by hand.
DO $seed$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'control_plane'
           AND table_name   = 'ctl_tenant_routes'
           AND column_name  = 'route_kind'
    ) THEN
        RAISE NOTICE
            'itech/accesspoint routes: skipped here; 20261004-02 owns them now that '
            'route_kind exists';
    ELSE
    INSERT INTO control_plane.ctl_tenant_routes
        (host, tenant_id, tier, cell_key,
         db_server_fqdn, db_name, silo_key, db_secret_uri,
         storage_account, container_prefix, storage_secret_uri,
         status, is_wildcard, cdate, ctime, cdatetime, created_by)
    VALUES
        ('itech.dev.trovesuite.com',
         'tnt_itech', 'SILO_SHARED', 'uksouth-dev',
         'tvs-shared-sql.postgres.database.azure.com', 'silo-itech-dev', 'itech', NULL,
         -- A shared silo names NO account: storage is per app, so it keeps each
         -- app's own and prefixes its containers inside them. The prefix is the
         -- silo key, which is why it is this tenant's and nobody else's.
         NULL, 'itech', NULL,
         'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261002-09'),

        ('accesspoint.dev.trovesuite.com',
         'tnt_accesspoint', 'SILO_DEDICATED', 'uksouth-dev',
         'tvs-dev-silo-accesspoint-sql.postgres.database.azure.com', 'silo-accesspoint-dev',
         'accesspoint', NULL,
         -- Its own account, so its containers need no prefix to stay apart.
         'tvsdevaccesspointsa', NULL, NULL,
         'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261002-09')
    ON CONFLICT (host) DO UPDATE
       SET tenant_id        = EXCLUDED.tenant_id,
           tier             = EXCLUDED.tier,
           db_server_fqdn   = EXCLUDED.db_server_fqdn,
           db_name          = EXCLUDED.db_name,
           silo_key         = EXCLUDED.silo_key,
           db_secret_uri    = EXCLUDED.db_secret_uri,
           storage_account  = EXCLUDED.storage_account,
           container_prefix = EXCLUDED.container_prefix,
           status           = EXCLUDED.status,
           udatetime        = now(),
           updated_by       = 'migration 20261002-09';
    END IF;
END $seed$;

-- ----------------------------------------------------------------------------- checks
-- Safe where there are no route rows: migrations/shared reaches every silo's own
-- database, where control_plane exists and is empty.
DO $$
DECLARE n integer;
BEGIN
    -- The retired hosts must be gone, not lingering as rows pointing at deleted
    -- databases.
    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE host IN ('siloshared.dev.trovesuite.com',
                    'silodedicated.dev.trovesuite.com',
                    'tenantb.dev.trovesuite.com');
    IF n > 0 THEN
        RAISE EXCEPTION '% retired silo host(s) still have a route row', n;
    END IF;

    -- No two tenants share a database, and no two share a container prefix.
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

    -- The prefix is the silo key, so it cannot drift from the IaC that creates
    -- the containers.
    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE tier = 'SILO_SHARED' AND container_prefix IS DISTINCT FROM silo_key;
    IF n > 0 THEN
        RAISE EXCEPTION '% shared silo(s) have a container_prefix that is not their silo_key', n;
    END IF;

    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host = 'itech.dev.trovesuite.com') THEN
        RAISE NOTICE 'itech and accesspoint registered; the kind-named test hosts are retired';
    END IF;
END $$;
