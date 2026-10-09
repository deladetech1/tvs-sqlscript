-- =====================================================================================
-- A client who brings their own infrastructure is a hosting model, not a footnote.
--
-- BYOD was being inferred: a route with storage_secret_uri set meant the storage
-- belonged to the client. That was enough to make storage work and wrong as a model:
--
--   * it cannot describe a client who brings their own DATABASE and uses our storage;
--   * nothing on screen says which clients are BYOD -- an operator had to notice a
--     Key Vault URI in a column and know what it implied;
--   * every rule that keys off tier -- plan eligibility, which pool to open, what the
--     console may do -- saw a dedicated silo and treated it as one of ours.
--
-- So SILO_BYOD is a tier.
--
-- THE DANGEROUS PART, AND WHY THIS MIGRATION IS NOT ENOUGH ON ITS OWN. The package
-- decides whether to open a silo's connection pool from a FIXED SET of tiers:
--
--     _OWN_DATABASE_TIERS = {SILO_SHARED, SILO_DEDICATED}
--
-- A tier missing from that set does not fail. has_own_database returns false,
-- pool_for_route returns None, and the request quietly uses the POOLED database --
-- a client's data served from the shared one, with nothing raised. That is the
-- Unknown Origin incident again, and it is why the tier is added to the package in the
-- same change as here. Adding the value to this CHECK without that is the dangerous
-- half on its own.
--
-- WHAT A BYOD ROUTE LOOKS LIKE
--
--     tier               SILO_BYOD
--     db_name            theirs
--     db_secret_uri      ours, pointing at their connection string
--     storage_account    theirs
--     storage_secret_uri ours, pointing at the token they issued
--     container_prefix   NULL -- they own the account, nothing else is in it
-- =====================================================================================

ALTER TABLE control_plane.ctl_tenant_routes
    DROP CONSTRAINT IF EXISTS ck_ctl_tenant_routes_tier;
ALTER TABLE control_plane.ctl_tenant_routes
    ADD CONSTRAINT ck_ctl_tenant_routes_tier CHECK (
        tier = ANY (ARRAY['POOLED', 'SILO_SHARED', 'SILO_DEDICATED',
                          'SILO_BYOD', 'SELF_MANAGED'])
    );

-- A BYOD route has its own database like any other silo. db_secret_uri rather than a
-- composed name: there is no db-url-<app>-<silo> in our vault for a database we did
-- not create, so the route has to carry the reference.
ALTER TABLE control_plane.ctl_tenant_routes
    DROP CONSTRAINT IF EXISTS ck_ctl_routes_silo_has_db;
ALTER TABLE control_plane.ctl_tenant_routes
    ADD CONSTRAINT ck_ctl_routes_silo_has_db CHECK (
        tier <> ALL (ARRAY['SILO_SHARED', 'SILO_DEDICATED', 'SILO_BYOD'])
        OR (db_name IS NOT NULL
            AND (db_secret_uri IS NOT NULL OR silo_key IS NOT NULL))
    );

-- Storage: they own the account, so no prefix, and we hold a credential for it. The
-- credential is what makes it BYOD rather than a dedicated silo of ours, so it is
-- required here -- otherwise the tier would say one thing and the columns another.
ALTER TABLE control_plane.ctl_tenant_routes
    DROP CONSTRAINT IF EXISTS ck_ctl_routes_byod_storage;
ALTER TABLE control_plane.ctl_tenant_routes
    ADD CONSTRAINT ck_ctl_routes_byod_storage CHECK (
        tier <> 'SILO_BYOD'
        OR (storage_account IS NOT NULL
            AND storage_secret_uri IS NOT NULL
            AND container_prefix IS NULL)
    );

COMMENT ON COLUMN control_plane.ctl_tenant_routes.tier IS
    'POOLED, SILO_SHARED, SILO_DEDICATED, SILO_BYOD or SELF_MANAGED. SILO_BYOD is a '
    'silo on the client''s own infrastructure: we hold credentials for it and build '
    'none of it. Anything that decides behaviour from this column must handle all '
    'five -- an unhandled silo tier falls back to the POOLED database in silence.';

-- ------------------------------------------------------------------------------ checks
DO $$
DECLARE n integer;
BEGIN
    -- The value is accepted.
    BEGIN
        INSERT INTO control_plane.ctl_tenant_routes
            (host, tenant_id, tier, cell_key, status, route_kind,
             db_name, db_secret_uri, storage_account, storage_secret_uri)
        VALUES ('__byod_check__.invalid', '__byod_check__', 'SILO_BYOD',
                'uksouth-dev', 'ACTIVE', 'TENANT', 'theirdb',
                'https://v.vault.azure.net/secrets/db',
                'theirsa', 'https://v.vault.azure.net/secrets/storage');
        RAISE EXCEPTION 'rollback the probe';
    EXCEPTION
        WHEN raise_exception THEN
            IF SQLERRM <> 'rollback the probe' THEN RAISE; END IF;
        WHEN foreign_key_violation THEN
            -- No such tenant, which is fine: the TIER was accepted, and that
            -- is what this is checking.
            NULL;
    END;

    -- And a BYOD row with no client credential is refused, or the tier would
    -- claim something the columns do not support.
    BEGIN
        INSERT INTO control_plane.ctl_tenant_routes
            (host, tenant_id, tier, cell_key, status, route_kind,
             db_name, db_secret_uri, storage_account)
        VALUES ('__byod_bad__.invalid', '__byod_check__', 'SILO_BYOD',
                'uksouth-dev', 'ACTIVE', 'TENANT', 'theirdb',
                'https://v.vault.azure.net/secrets/db', 'theirsa');
        RAISE EXCEPTION
            'a SILO_BYOD route was accepted with no storage credential';
    EXCEPTION
        WHEN check_violation THEN NULL;          -- refused, as intended
        WHEN foreign_key_violation THEN NULL;    -- refused earlier, also fine
    END;

    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE host LIKE '\_\_byod%';
    IF n > 0 THEN
        DELETE FROM control_plane.ctl_tenant_routes WHERE host LIKE '\_\_byod%';
        RAISE NOTICE 'cleaned up % probe row(s)', n;
    END IF;

    RAISE NOTICE 'SILO_BYOD is a tier; every tier switch must now handle five';
END $$;
