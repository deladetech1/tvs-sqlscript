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

-- ONLY IN DEV'S OWN DATABASES (2026-10-20).
-- These two rows are dev test fixtures naming dev databases, but shared/ runs in every
-- database -- production included. They used to be inserted everywhere and then removed
-- by 20261006-04 further down the same deploy. The runner commits file by file, so for
-- the minutes in between production's route table listed two silos it can never reach,
-- and every fan-out job that ran in that window (MyStoreGuard's invoicing payment queue,
-- Accounting's postings, Core Platform's sweeps) logged SiloUnavailable for them --
-- after every single deploy. Now they are written only where they are true: the dev
-- control plane and the two silo databases they name. 20261006-04 stays as the cleanup
-- for any database that already holds them.
--
-- UPDATE ONLY, NEVER INSERT (2026-11-09).
-- Both clients were OFFBOARDED on 2026-10-23 (tvs-iac offboard-silo-client: databases
-- dropped, server destroyed, secrets purged, route rows deleted). This seed then put the
-- two rows back, ACTIVE and naming placeholder tenants, on the very next saas-dev deploy
-- (cdatetime 2026-10-23 02:32 and 16:30) -- an INSERT ... ON CONFLICT cannot tell "never
-- registered" from "deliberately removed". From then on every dev fan-out job, every
-- request from those Origins and every push to the `silo` branch reached for databases
-- that no longer exist (silos run 42715439143: migrator-db-url-itech /
-- migrator-db-url-accesspoint not found). Registering a silo is tvs-iac
-- register-silo-client's job now, which writes the row itself. So this seed only keeps
-- the infrastructure columns of rows that already exist, and leaves `status` alone too:
-- restating ACTIVE undid an offboarding LOCK (SUSPENDED) on every deploy.
-- 20261109-97 removes the two rows this seed resurrected.
DO $seed$
BEGIN
    IF current_database() NOT IN ('dev-db', 'silo-itech-dev', 'silo-accesspoint-dev') THEN
        RAISE NOTICE 'dev silo routes: % is not a dev database, not seeding them',
                     current_database();
        RETURN;
    END IF;

    -- tenant_id is NOT set here: the console writes the real tenant id through
    -- control_plane.reconcile_route_tenant, and restating 'tnt_itech' on every deploy
    -- would point a live address back at a placeholder tenant. Nor is status.
    UPDATE control_plane.ctl_tenant_routes AS r
       SET tier             = v.tier,
           route_kind       = 'TENANT',
           db_server_fqdn   = v.db_server_fqdn,
           db_name          = v.db_name,
           silo_key         = v.silo_key,
           -- A shared silo names NO storage account: storage is per app, so it keeps
           -- each app's own and prefixes its containers with the silo key. A dedicated
           -- one has its own account, so its containers need no prefix.
           storage_account  = v.storage_account,
           container_prefix = v.container_prefix,
           udatetime        = now(),
           updated_by       = 'migration 20261004-02'
      FROM (VALUES
            ('itech.dev.trovesuite.com', 'SILO_SHARED',
             'tvs-shared-sql.postgres.database.azure.com', 'silo-itech-dev', 'itech',
             NULL::text, 'itech'),
            ('accesspoint.dev.trovesuite.com', 'SILO_DEDICATED',
             'tvs-dev-silo-accesspoint-sql.postgres.database.azure.com', 'silo-accesspoint-dev',
             'accesspoint', 'tvsdevaccesspointsa', NULL::text)
           ) AS v (host, tier, db_server_fqdn, db_name, silo_key, storage_account, container_prefix)
     WHERE r.host = v.host
       AND (r.tier, r.route_kind, r.db_server_fqdn, r.db_name, r.silo_key,
            r.storage_account, r.container_prefix)
           IS DISTINCT FROM
           (v.tier, 'TENANT', v.db_server_fqdn, v.db_name, v.silo_key,
            v.storage_account, v.container_prefix);
END $seed$;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer; k text;
BEGIN
    -- Where either address is still registered, it says it belongs to a customer. Its
    -- ABSENCE is not an error any more: an offboarded client has no row.
    FOR k IN SELECT unnest(ARRAY['itech.dev.trovesuite.com',
                                 'accesspoint.dev.trovesuite.com'])
    LOOP
        SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
         WHERE host = k AND (route_kind <> 'TENANT' OR tier = 'POOLED');
        IF n > 0 THEN
            RAISE EXCEPTION '% is registered but not as a tenant address', k;
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
