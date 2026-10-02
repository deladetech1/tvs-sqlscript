-- =====================================================================================
-- A SILO_SHARED row must NOT name a storage account.
--
-- 20261002-04 gave the shared silo storage_account = 'tvsdevmsgsa' on the assumption
-- that there is one shared storage account split by container name. There is not:
-- storage is PER APP -- tvsdevcpsa, tvsdevldsa, tvsdevmsgsa, tvsdevzhrasa,
-- tvsdevzhresa -- and tvsdevmsgsa is mystoreguard's.
--
-- Now that the apps actually READ this column (trovesuite 1.0.57,
-- Trovesuite.Package 1.0.10), leaving it set would redirect EVERY app to
-- mystoreguard's account: core-platform would write its user-profiles there, and
-- ZelosHR its employee documents.
--
-- The two columns are the whole contract, and each tier sets exactly one:
--
--   SILO_SHARED     container_prefix, NO storage_account
--                   -> each app keeps its own account, the tenant gets its own
--                      containers inside each one: <silo>-<container>
--   SILO_DEDICATED  storage_account, NO container_prefix
--                   -> one account for the tenant, every app writes to it with its
--                      usual container names; nothing else is in there
--
-- A row with both set, or neither, is refused below rather than left to be
-- discovered by a tenant's files appearing in another tenant's account.
-- =====================================================================================

UPDATE control_plane.ctl_tenant_routes
   SET storage_account = NULL,
       udatetime       = now(),
       updated_by      = 'migration 20261002-07'
 WHERE tier = 'SILO_SHARED'
   AND storage_account IS NOT NULL;

-- Exactly one of the two, for a silo. Not a NOT NULL on either column, because
-- which one is set is what distinguishes the tiers.
ALTER TABLE control_plane.ctl_tenant_routes
    DROP CONSTRAINT IF EXISTS ck_ctl_routes_silo_storage;

ALTER TABLE control_plane.ctl_tenant_routes
    ADD CONSTRAINT ck_ctl_routes_silo_storage CHECK (
        tier <> 'SILO_SHARED'
        OR (storage_account IS NULL AND container_prefix IS NOT NULL)
    );

ALTER TABLE control_plane.ctl_tenant_routes
    DROP CONSTRAINT IF EXISTS ck_ctl_routes_dedicated_storage;

ALTER TABLE control_plane.ctl_tenant_routes
    ADD CONSTRAINT ck_ctl_routes_dedicated_storage CHECK (
        tier <> 'SILO_DEDICATED'
        OR (storage_account IS NOT NULL AND container_prefix IS NULL)
    );

-- ----------------------------------------------------------------------------- checks
-- Safe in a database with no route rows: migrations/shared runs against every class,
-- so this file also reaches each silo's own database, where control_plane is empty.
DO $$
DECLARE n integer;
BEGIN
    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE tier = 'SILO_SHARED'
       AND (storage_account IS NOT NULL OR container_prefix IS NULL);
    IF n > 0 THEN
        RAISE EXCEPTION '% SILO_SHARED route(s) still name a storage account or lack a prefix', n;
    END IF;

    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE tier = 'SILO_DEDICATED'
       AND (storage_account IS NULL OR container_prefix IS NOT NULL);
    IF n > 0 THEN
        RAISE EXCEPTION '% SILO_DEDICATED route(s) lack their own account or carry a prefix', n;
    END IF;

    RAISE NOTICE 'silo storage: shared prefixes inside each app''s account, dedicated owns one';
END $$;
