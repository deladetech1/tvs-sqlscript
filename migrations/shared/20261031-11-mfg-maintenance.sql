-- Manufacturing: maintenance (design: docs/mfg/03-database-model.md §3.5 Maintenance;
-- 02-domain-model.md §8; contract R3.md D1-D6).
--
--   mfg_assets               the asset register, a tree (parent_id) per plant. An asset may be a
--                            production resource (resource_id, one asset per resource per business;
--                            the API sets mfg_resources.asset_id to match). in_service | down |
--                            under_maintenance | retired; criticality A | B | C (02 §8)
--   mfg_asset_meters         meter readings (runtime_h | cycles | custom:<name>), append-only
--                            (mfg_refuse_change); manual in R3, IoT in R4
--   mfg_failure_codes        problem | cause | remedy codes, code unique per business and kind
--   mfg_pm_plans             preventive maintenance plans: calendar (interval_days) or meter
--                            (meter + interval_meter), basis due | completion, tasks and parts as
--                            JSON; draft -> active <-> paused
--   mfg_maintenance_orders   MWO-00012 (mfg_number_series kind maintenance_order): preventive |
--                            corrective | inspection; requested -> approved -> scheduled ->
--                            in_progress -> completed -> closed, cancelled from the first three. A
--                            PM plan makes at most one order per due date: UNIQUE (pm_plan_id, due_on)
--   mfg_maintenance_tasks    the order's task list (copied from the plan) and each result
--   mfg_maintenance_labour   minutes worked on an order, per person
--   mfg_maintenance_parts    spare parts issued to and returned from an order; each line is a
--                            ledger movement (platform/stock, RefType mfg_maintenance_order, D5)
--
-- mfg_resources.asset_id (R1, 20261029-41) now refers to mfg_assets: the foreign key is added NOT
-- VALID (every new or changed row is checked at once) and validated only when no existing resource
-- names a missing asset, so a database that holds such a row still deploys; the notice says so.
--
-- downtime_id names the open mfg_downtime_events row (partitioned, so no foreign key). Product ids
-- are cp_products ids, registered for merges in 20261031-21; warehouse and lot ids are the shared
-- ledger's (no foreign key, as R1/R2). The CHECK lists live in 20261031-18. No grants.
-- Idempotent; safe to re-run.

BEGIN;

-- ========================================================================== assets
CREATE TABLE IF NOT EXISTS mfg.mfg_assets (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    plant_id          text NOT NULL REFERENCES mfg.mfg_plants (id),
    parent_id         text REFERENCES mfg.mfg_assets (id),
    resource_id       text REFERENCES mfg.mfg_resources (id),   -- NULL for a non-production asset
    code              text NOT NULL,
    name              text NOT NULL,
    description       text,
    status            text NOT NULL DEFAULT 'in_service',
    status_since      timestamptz,
    criticality       text NOT NULL DEFAULT 'B',
    manufacturer      text,
    model             text,
    serial_no         text,
    installed_on      date,
    warranty_until    date,
    location          text,                       -- where it stands, as text
    custom            jsonb NOT NULL DEFAULT '{}',
    archived_at       timestamptz,
    version           integer NOT NULL DEFAULT 1,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_assets_code_uq ON mfg.mfg_assets (bus_id, code);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_assets_resource_uq ON mfg.mfg_assets (bus_id, resource_id) WHERE resource_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS mfg_assets_list_idx ON mfg.mfg_assets (bus_id, plant_id, status) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS mfg_assets_parent_idx ON mfg.mfg_assets (parent_id) WHERE parent_id IS NOT NULL;
ALTER TABLE mfg.mfg_assets DROP CONSTRAINT IF EXISTS mfg_assets_rules_check;
ALTER TABLE mfg.mfg_assets ADD CONSTRAINT mfg_assets_rules_check
    CHECK (parent_id IS DISTINCT FROM id
           AND (warranty_until IS NULL OR installed_on IS NULL OR warranty_until >= installed_on));

-- R1's mfg_resources.asset_id now refers to an asset.
DO $$
DECLARE bad int;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'mfg_resources_asset_fk'
                      AND conrelid = 'mfg.mfg_resources'::regclass) THEN
        ALTER TABLE mfg.mfg_resources ADD CONSTRAINT mfg_resources_asset_fk
            FOREIGN KEY (asset_id) REFERENCES mfg.mfg_assets (id) NOT VALID;
    END IF;
    IF NOT (SELECT convalidated FROM pg_constraint WHERE conname = 'mfg_resources_asset_fk'
             AND conrelid = 'mfg.mfg_resources'::regclass) THEN
        SELECT count(*) INTO bad FROM mfg.mfg_resources r
         WHERE r.asset_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM mfg.mfg_assets a WHERE a.id = r.asset_id);
        IF bad = 0 THEN
            ALTER TABLE mfg.mfg_resources VALIDATE CONSTRAINT mfg_resources_asset_fk;
        ELSE
            RAISE NOTICE 'mfg_resources_asset_fk: % resource(s) name an asset that does not exist; checked for new rows only', bad;
        END IF;
    END IF;
END $$;
CREATE INDEX IF NOT EXISTS mfg_resources_asset_idx ON mfg.mfg_resources (asset_id) WHERE asset_id IS NOT NULL;

-- ==================================================================== meter readings
CREATE TABLE IF NOT EXISTS mfg.mfg_asset_meters (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    asset_id          text NOT NULL REFERENCES mfg.mfg_assets (id),
    meter             text NOT NULL,              -- runtime_h | cycles | custom:<name>
    reading           numeric(18,3) NOT NULL,     -- cumulative: never below the last reading (the API)
    read_at           timestamptz NOT NULL,
    note              text,
    idempotency_key   text,
    recorded_by       text,
    cdatetime         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS mfg_asset_meters_asset_idx ON mfg.mfg_asset_meters (asset_id, meter, read_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_asset_meters_idempotency_uq
    ON mfg.mfg_asset_meters (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
ALTER TABLE mfg.mfg_asset_meters DROP CONSTRAINT IF EXISTS mfg_asset_meters_rules_check;
ALTER TABLE mfg.mfg_asset_meters ADD CONSTRAINT mfg_asset_meters_rules_check CHECK (reading >= 0);

DROP TRIGGER IF EXISTS mfg_asset_meters_append_only ON mfg.mfg_asset_meters;
CREATE TRIGGER mfg_asset_meters_append_only BEFORE UPDATE OR DELETE ON mfg.mfg_asset_meters
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_refuse_change();

-- ===================================================================== failure codes
CREATE TABLE IF NOT EXISTS mfg.mfg_failure_codes (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    kind              text NOT NULL,              -- problem | cause | remedy
    code              text NOT NULL,
    name              text NOT NULL,
    description       text,
    archived_at       timestamptz,                -- the API's archived
    version           integer NOT NULL DEFAULT 1,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_failure_codes_code_uq ON mfg.mfg_failure_codes (bus_id, kind, code);

-- ========================================================================== PM plans
CREATE TABLE IF NOT EXISTS mfg.mfg_pm_plans (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    plant_id          text NOT NULL REFERENCES mfg.mfg_plants (id),   -- the asset's
    asset_id          text NOT NULL REFERENCES mfg.mfg_assets (id),
    name              text NOT NULL,
    description       text,
    trigger           text NOT NULL,              -- calendar | meter (condition is R4)
    interval_days     integer,                    -- calendar
    meter             text,                       -- meter: runtime_h | cycles | custom:<name>
    interval_meter    numeric(18,3),              -- meter
    basis             text NOT NULL DEFAULT 'due', -- due | completion: the next due counts from either
    lead_days         integer NOT NULL DEFAULT 0, -- the order is made this many days before it is due
    tasks             jsonb NOT NULL DEFAULT '[]', -- [{"seq", "text", "kind": check|value|photo, "required"}]
    parts             jsonb NOT NULL DEFAULT '[]', -- [{"product_id", "qty"}] (cp_products ids)
    est_min           integer,
    requires_down     boolean NOT NULL DEFAULT false,
    next_due_on       date,
    next_due_meter    numeric(18,3),
    last_done_on      date,
    last_done_meter   numeric(18,3),
    status            text NOT NULL DEFAULT 'draft',
    activated_at      timestamptz,
    activated_by      text,
    paused_at         timestamptz,
    paused_by         text,
    version           integer NOT NULL DEFAULT 1,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text
);
CREATE INDEX IF NOT EXISTS mfg_pm_plans_asset_idx ON mfg.mfg_pm_plans (asset_id, status);
CREATE INDEX IF NOT EXISTS mfg_pm_plans_due_idx ON mfg.mfg_pm_plans (bus_id, next_due_on) WHERE status = 'active';
ALTER TABLE mfg.mfg_pm_plans DROP CONSTRAINT IF EXISTS mfg_pm_plans_rules_check;
ALTER TABLE mfg.mfg_pm_plans ADD CONSTRAINT mfg_pm_plans_rules_check
    CHECK ((trigger <> 'calendar' OR (interval_days IS NOT NULL AND interval_days > 0))
           AND (trigger <> 'meter' OR (meter IS NOT NULL AND interval_meter IS NOT NULL AND interval_meter > 0))
           AND lead_days >= 0 AND (est_min IS NULL OR est_min >= 0)
           AND jsonb_typeof(tasks) = 'array' AND jsonb_typeof(parts) = 'array');

-- ================================================================ maintenance orders
CREATE TABLE IF NOT EXISTS mfg.mfg_maintenance_orders (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    plant_id          text NOT NULL REFERENCES mfg.mfg_plants (id),
    number            text NOT NULL,              -- MWO-00012
    type              text NOT NULL,              -- preventive | corrective | inspection
    status            text NOT NULL DEFAULT 'requested',
    priority          text NOT NULL DEFAULT 'medium',
    asset_id          text NOT NULL REFERENCES mfg.mfg_assets (id),
    resource_id       text REFERENCES mfg.mfg_resources (id),     -- the asset's resource, if any
    pm_plan_id        text REFERENCES mfg.mfg_pm_plans (id),
    due_on            date,                       -- a preventive order's due date
    due_meter         numeric(18,3),
    title             text NOT NULL,
    description       text,
    source_type       text,                       -- floor_request | downtime | asset_down | pm_plan | rule
    source_id         text,
    assigned_to       text,                       -- user id
    problem_code_id   text REFERENCES mfg.mfg_failure_codes (id),
    cause_code_id     text REFERENCES mfg.mfg_failure_codes (id),
    remedy_code_id    text REFERENCES mfg.mfg_failure_codes (id),
    window_start      timestamptz,                -- the planned window (scheduled)
    window_end        timestamptz,
    requires_down     boolean NOT NULL DEFAULT false,
    est_min           integer,
    downtime_id       text,                       -- the mfg_downtime_events row this order opened or answers
    labour_min        numeric(14,3) NOT NULL DEFAULT 0,   -- sum of mfg_maintenance_labour
    parts_cost        numeric(14,2) NOT NULL DEFAULT 0,   -- issues minus returns
    currency          text,
    completion_notes  text,
    back_in_service   boolean,
    requested_at      timestamptz NOT NULL DEFAULT now(),
    requested_by      text,
    approved_at       timestamptz,
    approved_by       text,
    scheduled_at      timestamptz,
    scheduled_by      text,
    started_at        timestamptz,
    started_by        text,
    completed_at      timestamptz,
    completed_by      text,
    closed_at         timestamptz,
    closed_by         text,
    cancelled_at      timestamptz,
    cancelled_by      text,
    cancelled_reason  text,
    idempotency_key   text,
    custom            jsonb NOT NULL DEFAULT '{}',
    version           integer NOT NULL DEFAULT 1,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_maintenance_orders_number_uq ON mfg.mfg_maintenance_orders (bus_id, number);
-- One preventive order per plan and due date (D3: pmDueRefresh is idempotent on it).
CREATE UNIQUE INDEX IF NOT EXISTS mfg_maintenance_orders_pm_due_uq
    ON mfg.mfg_maintenance_orders (pm_plan_id, due_on) WHERE pm_plan_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS mfg_maintenance_orders_idempotency_uq
    ON mfg.mfg_maintenance_orders (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS mfg_maintenance_orders_list_idx ON mfg.mfg_maintenance_orders (bus_id, plant_id, status, priority);
CREATE INDEX IF NOT EXISTS mfg_maintenance_orders_asset_idx ON mfg.mfg_maintenance_orders (asset_id, status);
CREATE INDEX IF NOT EXISTS mfg_maintenance_orders_window_idx
    ON mfg.mfg_maintenance_orders (resource_id, window_start, window_end)
    WHERE requires_down AND status IN ('scheduled', 'in_progress');
CREATE INDEX IF NOT EXISTS mfg_maintenance_orders_due_idx
    ON mfg.mfg_maintenance_orders (bus_id, due_on) WHERE type = 'preventive' AND status NOT IN ('completed', 'closed', 'cancelled');
ALTER TABLE mfg.mfg_maintenance_orders DROP CONSTRAINT IF EXISTS mfg_maintenance_orders_rules_check;
ALTER TABLE mfg.mfg_maintenance_orders ADD CONSTRAINT mfg_maintenance_orders_rules_check
    CHECK ((window_start IS NULL OR window_end IS NULL OR window_end >= window_start)
           AND (pm_plan_id IS NULL OR due_on IS NOT NULL)
           AND (status <> 'cancelled' OR cancelled_at IS NOT NULL)
           AND (status NOT IN ('completed', 'closed') OR completed_at IS NOT NULL)
           AND (status <> 'closed' OR closed_at IS NOT NULL)
           AND labour_min >= 0 AND (est_min IS NULL OR est_min >= 0));

CREATE TABLE IF NOT EXISTS mfg.mfg_maintenance_tasks (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    order_id          text NOT NULL REFERENCES mfg.mfg_maintenance_orders (id) ON DELETE CASCADE,
    seq               integer NOT NULL,
    text              text NOT NULL,
    kind              text NOT NULL DEFAULT 'check',   -- check | value | photo
    required          boolean NOT NULL DEFAULT true,
    result            text,                            -- pass | fail | na; NULL until recorded
    value             text,
    note              text,
    photo_path        text,                            -- private blob path, served through signed links
    done_at           timestamptz,
    done_by           text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    UNIQUE (order_id, seq)
);
ALTER TABLE mfg.mfg_maintenance_tasks DROP CONSTRAINT IF EXISTS mfg_maintenance_tasks_rules_check;
ALTER TABLE mfg.mfg_maintenance_tasks ADD CONSTRAINT mfg_maintenance_tasks_rules_check
    CHECK ((result IS NULL) = (done_at IS NULL));

CREATE TABLE IF NOT EXISTS mfg.mfg_maintenance_labour (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    order_id          text NOT NULL REFERENCES mfg.mfg_maintenance_orders (id) ON DELETE CASCADE,
    user_id           text NOT NULL,              -- who did the work
    minutes           numeric(14,3) NOT NULL,
    note              text,
    worked_on         date,
    idempotency_key   text,
    recorded_by       text,
    cdatetime         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS mfg_maintenance_labour_order_idx ON mfg.mfg_maintenance_labour (order_id);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_maintenance_labour_idempotency_uq
    ON mfg.mfg_maintenance_labour (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
ALTER TABLE mfg.mfg_maintenance_labour DROP CONSTRAINT IF EXISTS mfg_maintenance_labour_rules_check;
ALTER TABLE mfg.mfg_maintenance_labour ADD CONSTRAINT mfg_maintenance_labour_rules_check CHECK (minutes > 0);

CREATE TABLE IF NOT EXISTS mfg.mfg_maintenance_parts (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    order_id          text NOT NULL REFERENCES mfg.mfg_maintenance_orders (id),
    kind              text NOT NULL,              -- issue | return
    product_id        text NOT NULL,              -- cp_products.id
    qty               numeric(18,6) NOT NULL,
    unit              text,
    warehouse_id      text NOT NULL,              -- the shared ledger's warehouse
    lot_id            text,
    movement_id       text,                       -- the ledger movement it posted
    unit_cost         numeric(18,4),              -- C10's purchased-item cost
    cost              numeric(14,2),              -- qty x unit cost; a return is positive too
    currency          text,
    idempotency_key   text,                       -- the request's key; one request may post several lines
    actor             text,
    cdatetime         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS mfg_maintenance_parts_order_idx ON mfg.mfg_maintenance_parts (order_id);
CREATE INDEX IF NOT EXISTS mfg_maintenance_parts_product_idx ON mfg.mfg_maintenance_parts (bus_id, product_id);
ALTER TABLE mfg.mfg_maintenance_parts DROP CONSTRAINT IF EXISTS mfg_maintenance_parts_rules_check;
ALTER TABLE mfg.mfg_maintenance_parts ADD CONSTRAINT mfg_maintenance_parts_rules_check
    CHECK (qty > 0 AND (unit_cost IS NULL OR unit_cost >= 0) AND (cost IS NULL OR cost >= 0));

-- ===================================================================== invariants
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                    WHERE g.tgrelid = 'mfg.mfg_asset_meters'::regclass AND p.proname = 'mfg_refuse_change' AND NOT g.tgisinternal) THEN
        RAISE EXCEPTION 'mfg.mfg_asset_meters is not append-only: its mfg_refuse_change trigger is missing';
    END IF;
    -- A PM plan makes at most one order per due date (also the unique index; asserted so it can't be dropped quietly).
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'mfg' AND indexname = 'mfg_maintenance_orders_pm_due_uq') THEN
        RAISE EXCEPTION 'mfg.mfg_maintenance_orders has no unique (pm_plan_id, due_on)';
    END IF;
    -- A resource and the asset that is it agree on each other (the API sets both in one transaction).
    IF EXISTS (SELECT 1 FROM mfg.mfg_assets a JOIN mfg.mfg_resources r ON r.id = a.resource_id
                WHERE r.asset_id IS DISTINCT FROM a.id AND r.asset_id IS NOT NULL) THEN
        RAISE NOTICE 'some Manufacturing resources name a different asset than the asset that names them';
    END IF;
END $$;

COMMIT;
