-- =====================================================================================
-- The dev silo fixtures are dev's. Every other database should forget them.
--
-- itech and accesspoint are DEV test silos. They are seeded by 20261004-02, which lives
-- in migrations/shared/ -- and shared/ is applied to every database we own: the dev
-- control plane, the silo databases, staging, bgclt-prod and production. So production
-- carries two route rows naming databases that exist only in dev:
--
--   itech        silo-itech-dev        on tvs-shared-sql...
--   accesspoint  silo-accesspoint-dev  on tvs-dev-silo-accesspoint-sql...
--
-- FOR A POOLED ROW THAT WOULD BE HARMLESS, and this is why the rest of the registry is
-- left alone. Production's table also lists dev and staging POOLED hosts -- 26 and 16 of
-- them -- and that is deliberate: the table is the address registry, and every POOLED row
-- resolves to "the database this pod was configured with", so they all collapse to the
-- one local database and cost nothing.
--
-- A SILO ROW IS NOT LIKE THAT. It names a specific server and database, so anything that
-- fans out over the route table reads it as "a database you must service". Production
-- cannot reach a dev silo -- it has no credential for one, by design, because serving it
-- from the pooled database would be a cross-tenant read -- so the work can never succeed
-- and never stops being retried. Measured in production before this file:
--
--   * 13,920 errors in three hours from the webhook and SMS sweeps, ~4,300/hour, every
--     one of them SiloUnavailable for itech or accesspoint
--   * report_billing_facts failing the same way on its nightly pass
--   * control_plane.ctl_billing_coverage showing two silos that have "never reported"
--     and never will, which makes the console say every billing figure is incomplete --
--     a warning that can never be cleared is a warning nobody reads
--
-- DELETED RATHER THAN RETIRED. Setting status would not survive: 20261004-02 ends with
-- ON CONFLICT (host) DO UPDATE SET ... status = EXCLUDED.status, so the next deploy puts
-- it straight back to ACTIVE. The seed runs first and this runs after it -- filenames
-- order the run -- so each deploy inserts and then removes them, and the database is
-- correct whenever a deploy finishes. That is the repo's own rule: a later migration
-- wins.
--
-- WHY A GUARD AND NOT A PLAIN DELETE, which is the dangerous direction here. This file
-- also runs INSIDE silo-itech-dev and silo-accesspoint-dev, because silos.yml applies
-- migrations/shared/ to them as well. An unguarded delete would strip itech's own route
-- from itech's own database and take dev's silo routing down -- breaking the thing this
-- file is protecting, in the one place the rows are correct.
--
-- So the dev cell identifies itself, and does it from the data rather than from a list:
-- a database is dev's if it is the dev control plane, or if the table names it as a dev
-- silo's own database. A new dev silo therefore protects itself the moment it is seeded,
-- with no edit here. 'dev-db' is the one name that cannot be derived -- a POOLED row
-- carries no db_name, by design -- so it is stated once, here.
-- =====================================================================================

DO $$
DECLARE
    -- The dev control plane. The only hard-coded name in this file; see above.
    dev_control_plane CONSTANT text := 'dev-db';
    me       text := current_database();
    is_dev   boolean;
    removed  integer;
BEGIN
    SELECT me = dev_control_plane
           OR EXISTS (
                SELECT 1 FROM control_plane.ctl_tenant_routes
                 WHERE cell_key = 'uksouth-dev'
                   AND db_name  = me)
      INTO is_dev;

    IF is_dev THEN
        RAISE NOTICE 'dev silos: % is part of the dev cell, keeping its silo routes', me;
        RETURN;
    END IF;

    WITH gone AS (
        DELETE FROM control_plane.ctl_tenant_routes
         WHERE cell_key = 'uksouth-dev'
           -- SILO rows only. The dev POOLED hosts are the address registry and are
           -- deliberately left where they are.
           AND tier <> 'POOLED'
        RETURNING 1
    )
    SELECT count(*) INTO removed FROM gone;

    IF removed > 0 THEN
        RAISE NOTICE 'dev silos: removed % dev silo route(s) from %', removed, me;
    END IF;
END $$;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer; me text := current_database();
BEGIN
    SELECT count(*) INTO n
      FROM control_plane.ctl_tenant_routes
     WHERE cell_key = 'uksouth-dev' AND tier <> 'POOLED';

    IF me = 'dev-db' OR EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                                 WHERE cell_key = 'uksouth-dev' AND db_name = me) THEN
        -- Dev keeps them, and must: 20261004-02 asserts both rows exist there.
        IF n = 0 THEN
            RAISE EXCEPTION 'dev silos: % is a dev database but has no silo routes left', me;
        END IF;
        RAISE NOTICE 'dev silos: % keeps % silo route(s)', me, n;
    ELSE
        IF n <> 0 THEN
            RAISE EXCEPTION 'dev silos: % still carries % dev silo route(s)', me, n;
        END IF;
        -- And nothing else was taken with them.
        SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes WHERE tier <> 'POOLED';
        RAISE NOTICE 'dev silos: % carries no dev silo routes; % non-pooled route(s) remain',
                     me, n;
    END IF;
END $$;
