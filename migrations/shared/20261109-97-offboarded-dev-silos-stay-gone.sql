-- =====================================================================================
-- The two offboarded dev silos stay gone.
--
-- itech (SILO_SHARED) and accesspoint (SILO_DEDICATED) were offboarded on 2026-10-23 by
-- tvs-iac offboard-silo-client: their databases were dropped, accesspoint's server and
-- storage destroyed, their secrets purged and their route rows deleted. The very next
-- saas-dev deploy put both rows back -- 20261004-02 was an INSERT ... ON CONFLICT seed --
-- ACTIVE, naming the placeholder tenants tnt_itech / tnt_accesspoint. Since then:
--
--   * every push to tvs-sqlscript `silo` failed (run 42715439143): the two "silos" have
--     no migrator-db-url-<silo> any more, because they have no database;
--   * every dev fan-out job saw two scopes it can never reach (SiloUnavailable);
--   * an Origin of itech.dev.trovesuite.com was routed to a database that does not exist.
--
-- 20261004-02 no longer inserts. This removes what it resurrected, and only that: a row
--   - in dev's control plane (dev-db) -- nowhere else holds them (20261006-04);
--   - for exactly these two hosts;
--   - written by that seed (created_by), never by a registration (tvs-iac
--     register-silo-client writes its own created_by);
--   - still naming its placeholder tenant, which is not a tenant that exists.
-- A client registered again under either address is a different row and is untouched.
--
-- Re-runs every deploy (as every shared migration does); after the first it finds
-- nothing.
-- =====================================================================================
DO $$
DECLARE n integer;
BEGIN
    IF current_database() <> 'dev-db' THEN
        RAISE NOTICE 'offboarded dev silos: % is not the dev control plane, nothing to do',
                     current_database();
        RETURN;
    END IF;

    DELETE FROM control_plane.ctl_tenant_routes r
     WHERE r.host IN ('itech.dev.trovesuite.com', 'accesspoint.dev.trovesuite.com')
       AND r.created_by = 'migration 20261004-02'
       AND r.tenant_id = 'tnt_' || r.silo_key
       AND NOT EXISTS (SELECT 1 FROM core_platform.cp_tenants t WHERE t.id = r.tenant_id);
    GET DIAGNOSTICS n = ROW_COUNT;
    RAISE NOTICE 'offboarded dev silos: % resurrected route row(s) removed', n;
END $$;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer;
BEGIN
    -- The invariant, not a count: no route in this database names a placeholder tenant
    -- that does not exist while claiming to be ACTIVE -- the state that made the dead
    -- silos look alive.
    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes r
     WHERE current_database() = 'dev-db'
       AND r.host IN ('itech.dev.trovesuite.com', 'accesspoint.dev.trovesuite.com')
       AND r.created_by = 'migration 20261004-02'
       AND r.tenant_id = 'tnt_' || r.silo_key
       AND NOT EXISTS (SELECT 1 FROM core_platform.cp_tenants t WHERE t.id = r.tenant_id);
    IF n > 0 THEN
        RAISE EXCEPTION '% resurrected dev silo route(s) are still registered', n;
    END IF;
END $$;
