-- Manufacturing: the plant model -- where things are made (design: docs/mfg/03-database-model.md
-- §3.2, 02-domain-model.md §1; contract R1.md §3).
--
--   mfg_plants                a Core location where this business manufactures: timezone,
--                             default warehouses (raw, WIP, finished, quarantine) and calendar
--   mfg_areas                 a hall or department of a plant ("Moulding hall")
--   mfg_lines                 a line in an area; OEE and schedules roll up here
--   mfg_line_work_centers     the work centers of a line, in order
--   mfg_work_centers          where an operation runs: capacity, efficiency, cost rates
--   mfg_resources             a machine, tool, fixture or labour pool of a work center; the
--                             thing that is busy or down. status is written only by the API,
--                             in the transaction of the downtime or confirmation that changes it
--   mfg_calendars             a working pattern of a plant (or of work centers that name it)
--   mfg_shifts                a calendar's shifts. One that ends before it starts crosses
--                             midnight; its time belongs to the day it starts
--   mfg_calendar_exceptions   holidays, shutdowns and extra shifts
--   mfg_reason_codes          one list per business of scrap, rework and downtime reasons, each
--                             mapped to a loss category of the OEE loss tree. The default set
--                             is seeded per business by the API at first use (R1 A8), not here
--
-- Warehouse ids on plants and the line-side bin on work centers are the shared ledger's
-- (scm.scm_warehouses / scm.scm_bins); no foreign key crosses the schema. Every row belongs to
-- a business (bus_id) of a tenant. The CHECK lists live in 20261029-44. Idempotent; safe to re-run.

BEGIN;

-- ========================================================================== plants
CREATE TABLE IF NOT EXISTS mfg.mfg_plants (
    id                        text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id                 text NOT NULL,
    org_id                    text,
    bus_id                    text NOT NULL,
    loc_id                    text,                  -- the Core location
    code                      text NOT NULL,
    name                      text NOT NULL,
    timezone                  text NOT NULL,         -- the business's unless set
    raw_warehouse_id          text,
    wip_warehouse_id          text,
    fg_warehouse_id           text,
    quarantine_warehouse_id   text,
    calendar_id               text,
    custom                    jsonb NOT NULL DEFAULT '{}',
    archived_at               timestamptz,
    version                   integer NOT NULL DEFAULT 1,
    cdatetime                 timestamptz NOT NULL DEFAULT now(),
    created_by                text,
    updated_at                timestamptz NOT NULL DEFAULT now(),
    updated_by                text,
    UNIQUE (bus_id, code)
);
CREATE INDEX IF NOT EXISTS mfg_plants_business_idx ON mfg.mfg_plants (tenant_id, bus_id) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS mfg.mfg_areas (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    org_id       text,
    bus_id       text NOT NULL,
    plant_id     text NOT NULL REFERENCES mfg.mfg_plants (id),
    code         text NOT NULL,
    name         text NOT NULL,
    archived_at  timestamptz,
    version      integer NOT NULL DEFAULT 1,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text,
    updated_at   timestamptz NOT NULL DEFAULT now(),
    updated_by   text,
    UNIQUE (plant_id, code)
);

CREATE TABLE IF NOT EXISTS mfg.mfg_lines (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    org_id       text,
    bus_id       text NOT NULL,
    plant_id     text NOT NULL REFERENCES mfg.mfg_plants (id),
    area_id      text REFERENCES mfg.mfg_areas (id),
    code         text NOT NULL,
    name         text NOT NULL,
    sequence     integer NOT NULL DEFAULT 0,
    archived_at  timestamptz,
    version      integer NOT NULL DEFAULT 1,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text,
    updated_at   timestamptz NOT NULL DEFAULT now(),
    updated_by   text,
    UNIQUE (plant_id, code)
);

-- ===================================================================== calendars
CREATE TABLE IF NOT EXISTS mfg.mfg_calendars (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    org_id       text,
    bus_id       text NOT NULL,
    plant_id     text REFERENCES mfg.mfg_plants (id),
    name         text NOT NULL,
    archived_at  timestamptz,
    version      integer NOT NULL DEFAULT 1,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text,
    updated_at   timestamptz NOT NULL DEFAULT now(),
    updated_by   text
);
CREATE INDEX IF NOT EXISTS mfg_calendars_plant_idx ON mfg.mfg_calendars (bus_id, plant_id);

CREATE TABLE IF NOT EXISTS mfg.mfg_shifts (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    org_id       text,
    bus_id       text NOT NULL,
    calendar_id  text NOT NULL REFERENCES mfg.mfg_calendars (id) ON DELETE CASCADE,
    name         text NOT NULL,
    start_time   time NOT NULL,
    end_time     time NOT NULL,
    days         smallint[] NOT NULL DEFAULT '{1,2,3,4,5}',   -- ISO weekdays, 1 = Monday
    break_min    integer NOT NULL DEFAULT 0,
    valid_from   date,
    valid_to     date,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text,
    updated_at   timestamptz NOT NULL DEFAULT now(),
    updated_by   text
);
CREATE INDEX IF NOT EXISTS mfg_shifts_calendar_idx ON mfg.mfg_shifts (calendar_id);
ALTER TABLE mfg.mfg_shifts DROP CONSTRAINT IF EXISTS mfg_shifts_shape_check;
ALTER TABLE mfg.mfg_shifts ADD CONSTRAINT mfg_shifts_shape_check
    CHECK (days <@ '{1,2,3,4,5,6,7}'::smallint[] AND cardinality(days) > 0 AND break_min >= 0
           AND start_time <> end_time AND (valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from));

CREATE TABLE IF NOT EXISTS mfg.mfg_calendar_exceptions (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    org_id       text,
    bus_id       text NOT NULL,
    calendar_id  text NOT NULL REFERENCES mfg.mfg_calendars (id) ON DELETE CASCADE,
    scope_type   text,                   -- NULL = the whole calendar; work_center | resource
    scope_id     text,
    starts_at    timestamptz NOT NULL,
    ends_at      timestamptz NOT NULL,
    kind         text NOT NULL,          -- holiday | shutdown | extra_shift (20261029-44)
    reason       text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text,
    updated_at   timestamptz NOT NULL DEFAULT now(),
    updated_by   text
);
CREATE INDEX IF NOT EXISTS mfg_calendar_exceptions_when_idx ON mfg.mfg_calendar_exceptions (calendar_id, starts_at);
ALTER TABLE mfg.mfg_calendar_exceptions DROP CONSTRAINT IF EXISTS mfg_calendar_exceptions_range_check;
ALTER TABLE mfg.mfg_calendar_exceptions ADD CONSTRAINT mfg_calendar_exceptions_range_check
    CHECK (ends_at > starts_at AND (scope_type IS NULL) = (scope_id IS NULL));

-- ================================================================== work centers
CREATE TABLE IF NOT EXISTS mfg.mfg_work_centers (
    id                   text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id            text NOT NULL,
    org_id               text,
    bus_id               text NOT NULL,
    plant_id             text NOT NULL REFERENCES mfg.mfg_plants (id),
    line_id              text REFERENCES mfg.mfg_lines (id),
    code                 text NOT NULL,
    name                 text NOT NULL,
    kind                 text NOT NULL,                     -- machine | labour | mixed | subcontract
    capacity_per_hour    numeric(18,6),
    parallel_units       integer NOT NULL DEFAULT 1,
    efficiency_pct       numeric(6,2) NOT NULL DEFAULT 100,
    utilisation_pct      numeric(6,2) NOT NULL DEFAULT 100,
    rate_setup           numeric(18,4),                     -- money per hour, business currency
    rate_run             numeric(18,4),
    rate_labour          numeric(18,4),
    rate_machine         numeric(18,4),
    rate_overhead        numeric(18,4),
    energy_kwh_per_hour  numeric(18,4),
    currency             text,
    default_queue_min    integer,
    default_move_min     integer,
    cost_center          text,
    calendar_id          text REFERENCES mfg.mfg_calendars (id),
    line_side_bin_id     text,                              -- scm.scm_bins id
    custom               jsonb NOT NULL DEFAULT '{}',
    archived_at          timestamptz,
    version              integer NOT NULL DEFAULT 1,
    cdatetime            timestamptz NOT NULL DEFAULT now(),
    created_by           text,
    updated_at           timestamptz NOT NULL DEFAULT now(),
    updated_by           text,
    UNIQUE (plant_id, code)
);
CREATE INDEX IF NOT EXISTS mfg_work_centers_plant_idx ON mfg.mfg_work_centers (bus_id, plant_id) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS mfg_work_centers_line_idx ON mfg.mfg_work_centers (line_id) WHERE line_id IS NOT NULL;
ALTER TABLE mfg.mfg_work_centers DROP CONSTRAINT IF EXISTS mfg_work_centers_numbers_check;
ALTER TABLE mfg.mfg_work_centers ADD CONSTRAINT mfg_work_centers_numbers_check
    CHECK (parallel_units >= 1 AND efficiency_pct > 0 AND efficiency_pct <= 1000
           AND utilisation_pct > 0 AND utilisation_pct <= 100
           AND (capacity_per_hour IS NULL OR capacity_per_hour >= 0));

CREATE TABLE IF NOT EXISTS mfg.mfg_line_work_centers (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    org_id          text,
    bus_id          text NOT NULL,
    line_id         text NOT NULL REFERENCES mfg.mfg_lines (id) ON DELETE CASCADE,
    work_center_id  text NOT NULL REFERENCES mfg.mfg_work_centers (id) ON DELETE CASCADE,
    position        integer NOT NULL,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text,
    UNIQUE (line_id, work_center_id)
);
CREATE INDEX IF NOT EXISTS mfg_line_work_centers_order_idx ON mfg.mfg_line_work_centers (line_id, position);

-- ===================================================================== resources
CREATE TABLE IF NOT EXISTS mfg.mfg_resources (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    plant_id          text NOT NULL REFERENCES mfg.mfg_plants (id),
    work_center_id    text NOT NULL REFERENCES mfg.mfg_work_centers (id),
    code              text NOT NULL,
    name              text NOT NULL,
    kind              text NOT NULL,                     -- machine | tool | fixture | labour_pool
    status            text NOT NULL DEFAULT 'available', -- derived from events (20261029-44)
    status_since      timestamptz,
    ideal_cycle_sec   numeric(18,6),                     -- OEE performance basis
    asset_tag         text,
    asset_id          text,                              -- maintenance asset (R3)
    device_id         text,                              -- IoT device (R4)
    custom            jsonb NOT NULL DEFAULT '{}',
    archived_at       timestamptz,
    version           integer NOT NULL DEFAULT 1,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text,
    UNIQUE (plant_id, code)
);
CREATE INDEX IF NOT EXISTS mfg_resources_work_center_idx ON mfg.mfg_resources (work_center_id) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS mfg_resources_status_idx ON mfg.mfg_resources (bus_id, plant_id, status);

-- ================================================================== reason codes
CREATE TABLE IF NOT EXISTS mfg.mfg_reason_codes (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    org_id         text,
    bus_id         text NOT NULL,
    kind           text NOT NULL,         -- downtime | scrap | rework (20261029-44)
    code           text NOT NULL,
    name           text NOT NULL,
    loss_category  text,                  -- the OEE loss tree (20261029-44)
    parent_id      text REFERENCES mfg.mfg_reason_codes (id),
    position       integer NOT NULL DEFAULT 0,
    archived_at    timestamptz,
    version        integer NOT NULL DEFAULT 1,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text,
    updated_at     timestamptz NOT NULL DEFAULT now(),
    updated_by     text,
    UNIQUE (bus_id, kind, code)
);

-- ===================================================================== invariants
DO $$
BEGIN
    -- A resource sits in its work center's plant; a line in its area's plant.
    IF EXISTS (SELECT 1 FROM mfg.mfg_resources r JOIN mfg.mfg_work_centers w ON w.id = r.work_center_id
                WHERE r.plant_id <> w.plant_id OR r.bus_id <> w.bus_id) THEN
        RAISE EXCEPTION 'a Manufacturing resource is in a different plant or business from its work center';
    END IF;
    IF EXISTS (SELECT 1 FROM mfg.mfg_lines l JOIN mfg.mfg_areas a ON a.id = l.area_id
                WHERE l.plant_id <> a.plant_id) THEN
        RAISE EXCEPTION 'a Manufacturing line is in a different plant from its area';
    END IF;
    IF EXISTS (SELECT 1 FROM mfg.mfg_work_centers w JOIN mfg.mfg_lines l ON l.id = w.line_id
                WHERE w.plant_id <> l.plant_id) THEN
        RAISE EXCEPTION 'a Manufacturing work center is in a different plant from its line';
    END IF;
END $$;

COMMIT;
