-- =====================================================================================
-- The two live silo routes, stated as TENANT addresses.
--
-- WHY THIS FILE EXISTS RATHER THAN AN EDIT TO 20261002-09
-- 20261002-09 is the seed that registered itech and accesspoint. route_kind arrived
-- later, in 20261003-07, together with the check that a customer's address may never
-- resolve to the pooled database. Because every migration re-runs on every deploy, that
-- left the seed unable to be right:
--
--   * name route_kind, and the FIRST run fails -- the column does not exist yet;
--   * omit it, and any later run that has to INSERT (rather than update) fails, because
--     the column's default is 'PLATFORM' and a PLATFORM row may not carry a silo tier.
--
-- The second case took the saas deploy down. Both clients had been cleared and set up
-- again through the console, so the rows were not there to be updated, and the seed fell
-- into the INSERT path one release after the constraint was added.
--
-- A later migration wins, so the rows are owned here from now on and the seed stands
-- aside once the column exists. The alternative -- a conditional copy of the seed inside
-- the old file -- is two seeds to keep in step, which is the thing that caused this.
--
-- WHY route_kind IS NOT DERIVED FROM tier
-- It would make this whole problem disappear, and it would also make the check
-- meaningless. Deriving the kind from the tier means every row satisfies the constraint
-- by construction, including the one it was written to catch: a tenant's address
-- registered as POOLED. ddt.dev.trovesuite.com and bidtl.dev.trovesuite.com signed
-- people into the shared database for two days precisely because nothing made anybody
-- state whose address they were. The column's value is that a human says TENANT, and the
-- database then refuses the combination that cannot be true.
-- =====================================================================================

INSERT INTO control_plane.ctl_tenant_routes
    (host, tenant_id, tier, cell_key,
     db_server_fqdn, db_name, silo_key, db_secret_uri,
     storage_account, container_prefix, storage_secret_uri,
     status, is_wildcard, route_kind, cdate, ctime, cdatetime, created_by)
VALUES
    ('itech.dev.trovesuite.com',
     'tnt_itech', 'SILO_SHARED', 'uksouth-dev',
     'tvs-shared-sql.postgres.database.azure.com', 'silo-itech-dev', 'itech', NULL,
     -- A shared silo names NO storage account: storage is per app, so it keeps each
     -- app's own and prefixes its containers inside them. The prefix is the silo key,
     -- which is why it is this tenant's and nobody else's.
     NULL, 'itech', NULL,
     'ACTIVE', false, 'TENANT',
     CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261004-02'),

    ('accesspoint.dev.trovesuite.com',
     'tnt_accesspoint', 'SILO_DEDICATED', 'uksouth-dev',
     'tvs-dev-silo-accesspoint-sql.postgres.database.azure.com', 'silo-accesspoint-dev',
     'accesspoint', NULL,
     -- Its own account, so its containers need no prefix to stay apart.
     'tvsdevaccesspointsa', NULL, NULL,
     'ACTIVE', false, 'TENANT',
     CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261004-02')
ON CONFLICT (host) DO UPDATE
   -- tenant_id is NOT in this list.
   --
   -- Both of these clients have been cleared and set up again through the console, which
   -- writes the real tenant id through control_plane.reconcile_route_tenant. Restating
   -- 'tnt_itech' here on every deploy would point a live address back at a placeholder
   -- tenant that no longer exists -- signing a customer out of their own system until
   -- somebody noticed. The seed's job is the infrastructure columns; who is behind the
   -- address is the console's.
   SET tier             = EXCLUDED.tier,
       route_kind       = EXCLUDED.route_kind,
       db_server_fqdn   = EXCLUDED.db_server_fqdn,
       db_name          = EXCLUDED.db_name,
       silo_key         = EXCLUDED.silo_key,
       storage_account  = EXCLUDED.storage_account,
       container_prefix = EXCLUDED.container_prefix,
       status           = EXCLUDED.status,
       udatetime        = now(),
       updated_by       = 'migration 20261004-02';

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer; k text;
BEGIN
    -- Both addresses exist and both say they belong to a customer.
    FOR k IN SELECT unnest(ARRAY['itech.dev.trovesuite.com',
                                 'accesspoint.dev.trovesuite.com'])
    LOOP
        SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
         WHERE host = k AND route_kind = 'TENANT' AND tier <> 'POOLED';
        IF n <> 1 THEN
            RAISE EXCEPTION '% is not registered as a tenant address', k;
        END IF;
    END LOOP;

    -- No silo route anywhere may still be claiming to be ours. This is the check that
    -- would have caught the deploy failure a release earlier, because it fails on the
    -- state rather than on the statement that produced it.
    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE tier IN ('SILO_SHARED', 'SILO_DEDICATED', 'SELF_MANAGED')
       AND route_kind <> 'TENANT';
    IF n > 0 THEN
        RAISE EXCEPTION '% silo route(s) are not marked TENANT', n;
    END IF;

    -- A tenant that was set up through the console must not have been dragged back to
    -- its placeholder by this seed.
    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE silo_key IS NOT NULL
       AND tenant_id = 'tnt_' || silo_key
       AND udatetime > cdatetime;
    IF n > 0 THEN
        RAISE WARNING
            '% silo route(s) hold a placeholder tenant id after an update. If that '
            'client was set up, their address now points at a tenant that does not '
            'exist.', n;
    END IF;

    RAISE NOTICE 'the silo routes say they are tenant addresses';
END $$;
