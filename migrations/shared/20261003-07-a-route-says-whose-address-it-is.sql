-- =====================================================================================
-- A route says whether it is OUR address or a CUSTOMER'S, and a customer's can never
-- be pooled.
--
-- WHY
-- ddt.dev.trovesuite.com and bidtl.dev.trovesuite.com signed people in. Neither is a
-- silo and neither names a tenant -- they are dev test hosts, registered POOLED by
-- 20261001-02 and 20261002-03 so that enforcement would stop refusing them. The route
-- table is the allow-list, so a row is permission, and those rows granted it.
--
-- That is the opposite of the rule this platform actually wants:
-- <anything>.dev.trovesuite.com belongs to ONE customer -- a silo, or an enterprise --
-- and an address that belongs to one customer must never resolve to the database
-- shared by all of them. An enterprise that is not self-hosted may instead be reached
-- at its own domain (king.com); that is still a customer's address and still not
-- pooled.
--
-- WHY A COLUMN AND NOT A CHECK ON THE HOST
-- Because the host cannot be read to find out. Counting labels says
-- api.dev.trovesuite.com (4), cp.dev.backend.trovesuite.com (5) and
-- loandrift.dev.trovesuite.com (4) are the same shape as ddt.dev.trovesuite.com (4),
-- and the first three are legitimately pooled: they are an API, an API and a product
-- front door. What separates them from a tenant address is intent, and intent was
-- written nowhere -- so every row looked equally correct, which is exactly how two
-- test hosts sat in production-shaped config for two days.
--
-- route_kind makes that intent a value the database checks. It does not deduce the
-- answer; it refuses to let one be left unstated, and refuses the combination that
-- matters: a customer's address resolving to the pooled database.
-- =====================================================================================

ALTER TABLE control_plane.ctl_tenant_routes
    ADD COLUMN IF NOT EXISTS route_kind text;

COMMENT ON COLUMN control_plane.ctl_tenant_routes.route_kind IS
    'PLATFORM = ours (a product front door, an API, the hub). TENANT = one '
    'customer''s address, which must be a silo or self-managed and never POOLED.';

-- Backfill from what is already true: only a silo or a self-managed route belongs to
-- a customer. Everything else in this table today is a product or API address.
UPDATE control_plane.ctl_tenant_routes
   SET route_kind = CASE
         WHEN tier IN ('SILO_SHARED', 'SILO_DEDICATED', 'SELF_MANAGED') THEN 'TENANT'
         ELSE 'PLATFORM'
       END
 WHERE route_kind IS NULL;

-- ------------------------------------------------------- the test hosts come out
-- Deleted rather than relabelled. A TENANT row needs a tenant and a database, which
-- is the point -- neither host has either, because neither is a customer. If ddt is
-- to become the first internal silo, the infrastructure is built and the row is
-- written with it, which is how itech and accesspoint got theirs.
--
-- Guarded: only ever the rows that are still unclaimed test hosts. If somebody has
-- since made one of them a real silo, this leaves it alone.
DELETE FROM control_plane.ctl_tenant_routes
 WHERE host IN ('ddt.dev.trovesuite.com', 'bidtl.dev.trovesuite.com')
   AND tier = 'POOLED'
   AND tenant_id IS NULL
   AND silo_key IS NULL;

ALTER TABLE control_plane.ctl_tenant_routes
    ALTER COLUMN route_kind SET DEFAULT 'PLATFORM';

ALTER TABLE control_plane.ctl_tenant_routes
    ALTER COLUMN route_kind SET NOT NULL;

ALTER TABLE control_plane.ctl_tenant_routes
    DROP CONSTRAINT IF EXISTS ck_ctl_routes_kind;
ALTER TABLE control_plane.ctl_tenant_routes
    ADD CONSTRAINT ck_ctl_routes_kind CHECK (route_kind IN ('PLATFORM', 'TENANT'));

-- The rule itself.
--
-- A customer's address is never pooled, and a pooled address never belongs to one
-- customer. Both directions, because either one alone leaves the other open.
ALTER TABLE control_plane.ctl_tenant_routes
    DROP CONSTRAINT IF EXISTS ck_ctl_routes_tenant_kind_not_pooled;
ALTER TABLE control_plane.ctl_tenant_routes
    ADD CONSTRAINT ck_ctl_routes_tenant_kind_not_pooled CHECK (
        (route_kind = 'TENANT' AND tier <> 'POOLED')
        OR
        (route_kind = 'PLATFORM' AND tier = 'POOLED')
    );

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer;
BEGIN
    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE host IN ('ddt.dev.trovesuite.com', 'bidtl.dev.trovesuite.com');
    IF n > 0 THEN
        RAISE EXCEPTION 'the unclaimed test hosts are still routable';
    END IF;

    -- The silos must have survived as TENANT rows; deleting a customer's route
    -- would take them off the air.
    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE silo_key IS NOT NULL AND route_kind <> 'TENANT';
    IF n > 0 THEN
        RAISE EXCEPTION '% silo route(s) are not marked TENANT', n;
    END IF;

    -- A customer's address resolving to the shared database is the thing this
    -- exists to stop, so prove the constraint refuses it rather than trusting it.
    BEGIN
        INSERT INTO control_plane.ctl_tenant_routes
            (host, tier, cell_key, status, is_wildcard, route_kind)
        VALUES ('probe-kind.example.invalid', 'POOLED', 'uksouth-dev', 'ACTIVE', false,
                'TENANT');
        RAISE EXCEPTION 'a TENANT route was accepted as POOLED';
    EXCEPTION WHEN check_violation THEN
        NULL;  -- refused, as it should be
    END;

    -- ...and the reverse: a platform address claiming a silo tier.
    BEGIN
        INSERT INTO control_plane.ctl_tenant_routes
            (host, tier, cell_key, status, is_wildcard, route_kind,
             tenant_id, db_name, db_secret_uri, container_prefix)
        VALUES ('probe-kind2.example.invalid', 'SILO_SHARED', 'uksouth-dev', 'ACTIVE',
                false, 'PLATFORM', 'tnt_probe', 'probe-db', 'x', 'probe');
        RAISE EXCEPTION 'a PLATFORM route was accepted as a silo';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    -- A real silo row must still go in, or the next tenant cannot be created.
    BEGIN
        INSERT INTO control_plane.ctl_tenant_routes
            (host, tier, cell_key, status, is_wildcard, route_kind,
             tenant_id, db_name, db_secret_uri, container_prefix)
        VALUES ('probe-kind3.example.invalid', 'SILO_SHARED', 'uksouth-dev', 'ACTIVE',
                false, 'TENANT', 'tnt_probe3', 'probe-db', 'x', 'probe3');
        RAISE EXCEPTION 'probe_ok';
    EXCEPTION
        WHEN check_violation THEN
            RAISE EXCEPTION 'a legitimate silo route was refused';
        WHEN raise_exception THEN
            IF SQLERRM <> 'probe_ok' THEN RAISE; END IF;
    END;

    RAISE NOTICE 'routes now say whose address they are';
END $$;
