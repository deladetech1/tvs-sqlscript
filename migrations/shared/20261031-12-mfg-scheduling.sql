-- Manufacturing: the finite schedule (design: docs/mfg/03-database-model.md §3.5 Scheduling;
-- 02-domain-model.md §4; contract R3.md D9, D10).
--
--   mfg_schedules              one live schedule per plant (scenario_id NULL; R4's scenarios add
--                              their own rows). version moves on every saved move or auto run, so
--                              a stale schedule_version is a 409 (D10)
--   mfg_scheduled_operations   where and when each production-order operation runs: resource, work
--                              center, setup start, start, end, sequence on the resource, locked
--                              (the planner pinned it), source auto | manual. One row per order
--                              operation. Finished or cancelled operations drop out by join
--   mfg_settings               gains material_horizon_days (default 2): an operation starting
--                              within it whose order's material is not green is a `material`
--                              conflict
--
-- Capacity buckets and conflicts are computed on read (D9), not stored: 03's mfg_capacity_buckets,
-- mfg_conflicts and mfg_setup_matrix are not made. The CHECK list (source) lives in 20261031-19.
-- No grants. Idempotent; safe to re-run.

BEGIN;

-- ========================================================================= settings
ALTER TABLE mfg.mfg_settings ADD COLUMN IF NOT EXISTS material_horizon_days integer NOT NULL DEFAULT 2;
ALTER TABLE mfg.mfg_settings DROP CONSTRAINT IF EXISTS mfg_settings_scheduling_rules_check;
ALTER TABLE mfg.mfg_settings ADD CONSTRAINT mfg_settings_scheduling_rules_check
    CHECK (material_horizon_days BETWEEN 0 AND 365);

-- ======================================================================== schedules
CREATE TABLE IF NOT EXISTS mfg.mfg_schedules (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    plant_id          text NOT NULL REFERENCES mfg.mfg_plants (id),
    scenario_id       text,                       -- NULL = the live schedule (R4 adds scenarios)
    version           integer NOT NULL DEFAULT 1, -- the API's schedule_version
    generated_at      timestamptz,                -- the last auto run
    published_at      timestamptz,                -- the last saved move or auto run
    published_by      text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text
);
-- One live schedule per plant.
CREATE UNIQUE INDEX IF NOT EXISTS mfg_schedules_live_uq ON mfg.mfg_schedules (bus_id, plant_id) WHERE scenario_id IS NULL;
CREATE INDEX IF NOT EXISTS mfg_schedules_scenario_idx ON mfg.mfg_schedules (scenario_id) WHERE scenario_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS mfg.mfg_scheduled_operations (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    org_id              text,
    bus_id              text NOT NULL,
    schedule_id         text NOT NULL REFERENCES mfg.mfg_schedules (id) ON DELETE CASCADE,
    order_operation_id  text NOT NULL REFERENCES mfg.mfg_order_operations (id) ON DELETE CASCADE,
    order_id            text NOT NULL REFERENCES mfg.mfg_production_orders (id) ON DELETE CASCADE,
    resource_id         text REFERENCES mfg.mfg_resources (id),     -- NULL: placed on the work center only
    work_center_id      text NOT NULL REFERENCES mfg.mfg_work_centers (id),
    setup_start         timestamptz NOT NULL,
    start_at            timestamptz NOT NULL,     -- run start (after setup)
    end_at              timestamptz NOT NULL,
    seq_on_resource     integer NOT NULL DEFAULT 0,
    locked              boolean NOT NULL DEFAULT false,
    source              text NOT NULL DEFAULT 'auto',   -- auto | manual
    moved_at            timestamptz NOT NULL DEFAULT now(),
    moved_by            text,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    created_by          text,
    updated_at          timestamptz NOT NULL DEFAULT now(),
    updated_by          text
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_scheduled_operations_operation_uq ON mfg.mfg_scheduled_operations (order_operation_id);
CREATE INDEX IF NOT EXISTS mfg_scheduled_operations_resource_idx
    ON mfg.mfg_scheduled_operations (schedule_id, resource_id, start_at);
CREATE INDEX IF NOT EXISTS mfg_scheduled_operations_work_center_idx
    ON mfg.mfg_scheduled_operations (schedule_id, work_center_id, start_at);
CREATE INDEX IF NOT EXISTS mfg_scheduled_operations_order_idx ON mfg.mfg_scheduled_operations (order_id);
ALTER TABLE mfg.mfg_scheduled_operations DROP CONSTRAINT IF EXISTS mfg_scheduled_operations_rules_check;
ALTER TABLE mfg.mfg_scheduled_operations ADD CONSTRAINT mfg_scheduled_operations_rules_check
    CHECK (setup_start <= start_at AND start_at <= end_at AND seq_on_resource >= 0);

-- ===================================================================== invariants
DO $$
BEGIN
    -- One live schedule per plant (also the unique index; asserted so it can't be dropped quietly).
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'mfg' AND indexname = 'mfg_schedules_live_uq') THEN
        RAISE EXCEPTION 'mfg.mfg_schedules has no unique live schedule per plant';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'mfg' AND indexname = 'mfg_scheduled_operations_operation_uq') THEN
        RAISE EXCEPTION 'mfg.mfg_scheduled_operations has no unique order operation';
    END IF;
END $$;

COMMIT;
