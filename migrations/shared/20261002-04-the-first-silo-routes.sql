-- =====================================================================================
-- The first two rows in this table that are not POOLED.
--
-- Everything until now has been POOLED with a NULL tenant_id, because a pooled address
-- serves every tenant and the token says which. These two name a tenant and a database,
-- which is what the whole control plane was built to express -- and until trovesuite
-- 1.0.55 nothing could act on them, because a connection went to the pod's own database
-- whatever the row said.
--
--   siloshared.dev.trovesuite.com     SILO_SHARED
--       own DATABASE on the shared server, own CONTAINERS in the shared storage account
--
--   silodedicated.dev.trovesuite.com  SILO_DEDICATED
--       own SERVER, own STORAGE ACCOUNT
--
-- Own database means own containers; own server means its own storage account. The two
-- always move together, which is why storage_account and container_prefix sit beside the
-- db columns rather than in a table of their own. Each tier sets exactly ONE of them:
-- a shared silo prefixes containers inside each APP's own account, a dedicated silo owns
-- an account outright.
--
-- DEV TEST ROWS. Both point at databases created on 2026-10-02 and tagged
-- disposable=true; the tenant ids are invented and own no real data. They exist so the
-- tier can be exercised against real infrastructure rather than asserted.
--
-- db_secret_uri is a Key Vault URI, never a credential. The pod's managed identity is
-- what may read it -- which is why this table can be readable to every app without being
-- worth stealing. A leaked row says where a secret lives, not what it is.
-- =====================================================================================

INSERT INTO control_plane.ctl_tenant_routes
    (host, tenant_id, tier, cell_key,
     db_server_fqdn, db_name, db_secret_uri,
     storage_account, container_prefix, storage_secret_uri,
     status, is_wildcard, cdate, ctime, cdatetime, created_by)
VALUES
    ('siloshared.dev.trovesuite.com',
     'tnt_siloshared_test', 'SILO_SHARED', 'uksouth-dev',
     'tvs-shared-sql.postgres.database.azure.com', 'silo-shared-test',
     'https://tvs-dev-kv.vault.azure.net/secrets/silo-shared-test-db-url',
     -- NO storage account, and the prefix is the silo key.
     --
     -- This said 'tvsdevmsgsa' originally, on the assumption of one shared
     -- account split by container name. Storage is PER APP, so a shared silo
     -- keeps each app's own account and takes its own <silo>-<container> inside
     -- each. 20261002-07 made that a constraint, and because every migration
     -- re-runs on each deploy this INSERT has to satisfy it -- a CHECK is
     -- evaluated before ON CONFLICT arbitration, so it failed the deploy even
     -- though the row already existed.
     NULL, 'shared', NULL,
     'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261002-04'),

    ('silodedicated.dev.trovesuite.com',
     'tnt_silodedicated_test', 'SILO_DEDICATED', 'uksouth-dev',
     'tvs-dev-silotest-sql.postgres.database.azure.com', 'silo-dedicated-test',
     'https://tvs-dev-kv.vault.azure.net/secrets/silo-dedicated-test-db-url',
     -- its own storage ACCOUNT, so no prefix is needed to keep it apart
     'tvsdevsilotestsa', NULL, NULL,
     'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261002-04')
ON CONFLICT (host) DO NOTHING;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE
    r record;
    n_silo integer;
BEGIN
    -- The TWO THIS FILE CREATES, not a count of every silo route.
    --
    -- This asserted exactly 2 and broke the moment a third tenant was onboarded
    -- (tenantb, 20261002-08): every migration re-runs on each deploy, so a
    -- global count here is an assertion that the platform will never gain a
    -- customer. A migration should only assert what it is responsible for.
    SELECT count(*) INTO n_silo FROM control_plane.ctl_tenant_routes
     WHERE host IN ('siloshared.dev.trovesuite.com', 'silodedicated.dev.trovesuite.com');
    IF n_silo <> 2 THEN
        RAISE EXCEPTION 'expected this file''s 2 silo routes, found %', n_silo;
    END IF;

    -- The constraints already refuse a silo without a database or a non-pooled row
    -- without a tenant, so this asserts what they cannot: that the two tiers differ in
    -- the way the tier model says they do.
    SELECT * INTO r FROM control_plane.ctl_tenant_routes
     WHERE host = 'siloshared.dev.trovesuite.com';
    IF r.storage_account IS NOT NULL OR r.container_prefix IS NULL THEN
        RAISE EXCEPTION 'SILO_SHARED names no storage account and prefixes its containers';
    END IF;

    SELECT * INTO r FROM control_plane.ctl_tenant_routes
     WHERE host = 'silodedicated.dev.trovesuite.com';
    IF r.storage_account IS NULL THEN
        RAISE EXCEPTION 'SILO_DEDICATED must have its own storage account';
    END IF;
    IF r.db_server_fqdn = 'tvs-shared-sql.postgres.database.azure.com' THEN
        RAISE EXCEPTION 'SILO_DEDICATED must be on its own server';
    END IF;

    RAISE NOTICE 'two silo routes registered: own-database and own-server';
END $$;
