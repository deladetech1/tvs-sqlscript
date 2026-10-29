-- Manufacturing: costing (design: docs/mfg/03-database-model.md §3.5 Costing; 02-domain-model.md
-- §10; contract R2.md C10).
--
--   mfg_cost_sets            a set of item costs: current (the latest roll-up, one per business),
--                            standard (frozen for a period; one frozen standard per business, the
--                            previous one superseded) and simulated. open -> frozen -> superseded.
--                            A frozen or superseded set is FROZEN: its item costs never change
--   mfg_item_costs           the cost of one product in one set, ONE ROW PER ELEMENT (material,
--                            labour, machine, energy, overhead, subcontract, scrap): this level,
--                            the levels below, and the total. The item's cost is the sum of its rows
--   mfg_cost_rollups         one roll-up: the set it wrote, its scope and when
--   mfg_cost_rollup_lines    APPEND-ONLY; every input a roll-up used (a component x qty x (1 +
--                            scrap) at its unit cost, an operation's minutes x a work center rate,
--                            a receipt's unit_cost, a standard_cost), so any roll-up can be
--                            reproduced. input_type is the FC screens' input kind (R1 B17)
--   mfg_order_costs          per production order and element: planned (the standard set x the
--                            order's quantity), actual (ledger issues at cost, confirmed minutes x
--                            rates) and the standard set used
--   mfg_order_variances      per order and kind, computed at close against the standard set;
--                            posted_event_id is the order.variance_posted event (C12: Accounting's
--                            posting rules are not R2's)
--
-- A purchased item's material cost is its latest receipt unit_cost (a Manufacturing receipt or, with
-- SCM, an SCM receipt: both are ledger movements), else mfg_item_settings.standard_cost, added here.
-- Work center rates are R1's mfg_work_centers.rate_* columns.
--
-- The frozen-set rule is mfg.mfg_cost_set_frozen() below: it refuses changes to a frozen set's
-- item costs, and to the set itself beyond its lifecycle. As mfg_freeze_released, it lets through
-- a product merge (cp_product_merge re-points product_id / component_id) and the unsubscribe purge.
--
-- Product ids are registered for merges in 20261030-20. The CHECK lists live in 20261030-19. No
-- grants. Idempotent; safe to re-run.

BEGIN;

-- ==================================================================== item settings
ALTER TABLE mfg.mfg_item_settings ADD COLUMN IF NOT EXISTS standard_cost numeric(18,4);
ALTER TABLE mfg.mfg_item_settings DROP CONSTRAINT IF EXISTS mfg_item_settings_standard_cost_check;
ALTER TABLE mfg.mfg_item_settings ADD CONSTRAINT mfg_item_settings_standard_cost_check
    CHECK (standard_cost IS NULL OR standard_cost >= 0);

-- ======================================================================= cost sets
CREATE TABLE IF NOT EXISTS mfg.mfg_cost_sets (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    kind             text NOT NULL,
    name             text NOT NULL,
    period           text,                         -- a standard set's period: '2026' or '2026-11'
    status           text NOT NULL DEFAULT 'open',
    currency         text,
    scenario_id      text,                         -- simulated (R4 scenarios)
    based_on_id      text REFERENCES mfg.mfg_cost_sets (id),   -- the set it was copied from (freeze copies current)
    frozen_at        timestamptz,
    frozen_by        text,
    superseded_at    timestamptz,
    notes            text,
    archived_at      timestamptz,
    idempotency_key  text,
    version          integer NOT NULL DEFAULT 1,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz NOT NULL DEFAULT now(),
    updated_by       text,
    CHECK (period IS NULL OR period ~ '^[0-9]{4}(-[0-9]{2})?$')
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_cost_sets_current_uq ON mfg.mfg_cost_sets (bus_id) WHERE kind = 'current';
CREATE UNIQUE INDEX IF NOT EXISTS mfg_cost_sets_standard_uq ON mfg.mfg_cost_sets (bus_id) WHERE kind = 'standard' AND status = 'frozen';
CREATE UNIQUE INDEX IF NOT EXISTS mfg_cost_sets_idempotency_uq
    ON mfg.mfg_cost_sets (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS mfg_cost_sets_list_idx ON mfg.mfg_cost_sets (bus_id, kind, status);
ALTER TABLE mfg.mfg_cost_sets DROP CONSTRAINT IF EXISTS mfg_cost_sets_frozen_check;
ALTER TABLE mfg.mfg_cost_sets ADD CONSTRAINT mfg_cost_sets_frozen_check
    CHECK ((status = 'open') = (frozen_at IS NULL)
           AND (status = 'open' OR kind = 'standard'));        -- only a standard set is frozen

CREATE TABLE IF NOT EXISTS mfg.mfg_item_costs (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    org_id             text,
    bus_id             text NOT NULL,
    cost_set_id        text NOT NULL REFERENCES mfg.mfg_cost_sets (id) ON DELETE CASCADE,
    rollup_id          text,                          -- the roll-up that wrote it; NULL when entered by hand
    product_id         text NOT NULL,
    item_revision_id   text,
    bom_id             text,                          -- the BOM and routing it was rolled up from
    routing_id         text,
    low_level_code     integer NOT NULL DEFAULT 0,
    lot_size           numeric(18,6),
    element            text NOT NULL,
    this_level         numeric(18,4) NOT NULL DEFAULT 0,   -- added at this item's own level
    lower_level        numeric(18,4) NOT NULL DEFAULT 0,   -- rolled up from its components
    total              numeric(18,4) NOT NULL DEFAULT 0,
    currency           text,
    source             text NOT NULL DEFAULT 'rollup',     -- rollup | receipt | standard_cost | manual
    inputs_hash        text,                          -- a hash of the inputs; equal hash = nothing changed
    computed_at        timestamptz NOT NULL DEFAULT now(),
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    created_by         text,
    updated_at         timestamptz NOT NULL DEFAULT now(),
    updated_by         text,
    UNIQUE (cost_set_id, product_id, element),
    CHECK (total = this_level + lower_level)
);
CREATE INDEX IF NOT EXISTS mfg_item_costs_product_idx ON mfg.mfg_item_costs (bus_id, product_id, cost_set_id);

-- =================================================================== roll-ups
CREATE TABLE IF NOT EXISTS mfg.mfg_cost_rollups (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    cost_set_id      text NOT NULL REFERENCES mfg.mfg_cost_sets (id),
    scope            jsonb NOT NULL DEFAULT '{}',   -- {"product_ids": [...]}; {} = every made item
    status           text NOT NULL DEFAULT 'running',
    started_at       timestamptz NOT NULL DEFAULT now(),
    finished_at      timestamptz,
    counts           jsonb NOT NULL DEFAULT '{}',
    error            text,
    idempotency_key  text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz NOT NULL DEFAULT now(),
    updated_by       text,
    CHECK ((status = 'running') = (finished_at IS NULL))
);
CREATE INDEX IF NOT EXISTS mfg_cost_rollups_list_idx ON mfg.mfg_cost_rollups (bus_id, started_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_cost_rollups_idempotency_uq
    ON mfg.mfg_cost_rollups (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;

CREATE TABLE IF NOT EXISTS mfg.mfg_cost_rollup_lines (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    org_id          text,
    bus_id          text NOT NULL,
    rollup_id       text NOT NULL REFERENCES mfg.mfg_cost_rollups (id),
    cost_set_id     text NOT NULL,
    product_id      text NOT NULL,                 -- the item being costed
    low_level_code  integer NOT NULL DEFAULT 0,
    element         text NOT NULL,
    input_type      text NOT NULL,                 -- receipt_cost | standard_cost | component | routing | subcontract | overhead (the API's kind)
    input_id        text,                          -- the BOM line, routing operation or ledger movement (the API's source_id)
    label           text,                          -- what it is, e.g. 'Op 20 Mould on L1 (run)'
    component_id    text,                          -- component: its product (cp_products.id)
    work_center_id  text,                          -- operation
    qty             numeric(18,6),
    scrap_pct       numeric(6,3),
    minutes         numeric(14,3),
    rate            numeric(18,4),                 -- per hour (routing) or per unit
    rate_kind       text,                          -- routing: setup | run | labour | machine | overhead | energy
    unit_cost       numeric(18,4),
    amount          numeric(18,4) NOT NULL,
    currency        text,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS mfg_cost_rollup_lines_item_idx ON mfg.mfg_cost_rollup_lines (rollup_id, product_id);

DROP TRIGGER IF EXISTS mfg_cost_rollup_lines_append_only ON mfg.mfg_cost_rollup_lines;
CREATE TRIGGER mfg_cost_rollup_lines_append_only BEFORE UPDATE OR DELETE ON mfg.mfg_cost_rollup_lines
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_refuse_change();

-- ===================================================================== order costs
CREATE TABLE IF NOT EXISTS mfg.mfg_order_costs (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    org_id             text,
    bus_id             text NOT NULL,
    order_id           text NOT NULL REFERENCES mfg.mfg_production_orders (id) ON DELETE CASCADE,
    element            text NOT NULL,
    planned            numeric(18,4) NOT NULL DEFAULT 0,
    actual             numeric(18,4) NOT NULL DEFAULT 0,
    currency           text,
    cost_set_id        text REFERENCES mfg.mfg_cost_sets (id),   -- the standard set planned is from
    computed_at        timestamptz NOT NULL DEFAULT now(),
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now(),
    UNIQUE (order_id, element)
);

CREATE TABLE IF NOT EXISTS mfg.mfg_order_variances (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    org_id             text,
    bus_id             text NOT NULL,
    order_id           text NOT NULL REFERENCES mfg.mfg_production_orders (id) ON DELETE CASCADE,
    kind               text NOT NULL,
    amount             numeric(18,4) NOT NULL,       -- positive = unfavourable (cost more than standard)
    currency           text,
    cost_set_id        text REFERENCES mfg.mfg_cost_sets (id),
    detail             jsonb NOT NULL DEFAULT '{}',  -- standard and actual quantities and prices behind it
    posted_event_id    text,
    computed_at        timestamptz NOT NULL DEFAULT now(),
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    UNIQUE (order_id, kind)
);
CREATE INDEX IF NOT EXISTS mfg_order_variances_business_idx ON mfg.mfg_order_variances (bus_id, computed_at DESC);

-- ================================================================== frozen sets
-- A frozen or superseded set: its item costs are not inserted, changed or deleted; the set itself
-- changes only status frozen -> superseded (with superseded_at), archived_at, notes, version,
-- updated_at and updated_by. A product merge and the unsubscribe purge go through.
CREATE OR REPLACE FUNCTION mfg.mfg_cost_set_frozen() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE
    lifecycle constant text[] := ARRAY['status', 'superseded_at', 'archived_at', 'notes', 'version', 'updated_at', 'updated_by'];
    refs      constant text[] := ARRAY['product_id', 'component_id'];
    o   jsonb;
    n   jsonb;
    sid text;
    st  text;
BEGIN
    IF TG_OP <> 'INSERT' THEN o := to_jsonb(OLD); END IF;
    IF TG_OP <> 'DELETE' THEN n := to_jsonb(NEW); END IF;

    IF TG_TABLE_NAME = 'mfg_cost_sets' THEN
        IF TG_OP = 'INSERT' OR (o ->> 'status') = 'open' THEN
            RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
        END IF;
        IF TG_OP = 'DELETE' THEN
            IF mfg.mfg_purge_allowed(OLD.tenant_id, OLD.bus_id) THEN
                RETURN OLD;
            END IF;
        ELSIF (n - lifecycle) = (o - lifecycle)
              AND ((n ->> 'status') = (o ->> 'status')
                   OR ((o ->> 'status') = 'frozen' AND (n ->> 'status') = 'superseded')) THEN
            RETURN NEW;
        END IF;
        RAISE EXCEPTION 'mfg.mfg_cost_sets %: a % cost set is frozen; roll up into the current set instead',
            o ->> 'id', o ->> 'status'
            USING ERRCODE = 'integrity_constraint_violation';
    END IF;

    -- an item cost row: look up its set
    FOREACH sid IN ARRAY ARRAY[o ->> 'cost_set_id', n ->> 'cost_set_id'] LOOP
        CONTINUE WHEN sid IS NULL;
        SELECT status INTO st FROM mfg.mfg_cost_sets WHERE id = sid;
        CONTINUE WHEN st IS NULL OR st = 'open';
        IF TG_OP = 'UPDATE' AND (n - refs) = (o - refs) THEN
            RETURN NEW;                                        -- a product merge
        END IF;
        IF TG_OP = 'DELETE' AND mfg.mfg_purge_allowed(OLD.tenant_id, OLD.bus_id) THEN
            RETURN OLD;
        END IF;
        RAISE EXCEPTION 'mfg.%: % of a cost of a % cost set is not allowed', TG_TABLE_NAME, TG_OP, st
            USING ERRCODE = 'integrity_constraint_violation';
    END LOOP;
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END
$f$;

DROP TRIGGER IF EXISTS mfg_cost_sets_freeze ON mfg.mfg_cost_sets;
CREATE TRIGGER mfg_cost_sets_freeze BEFORE UPDATE OR DELETE ON mfg.mfg_cost_sets
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_cost_set_frozen();
DROP TRIGGER IF EXISTS mfg_item_costs_freeze ON mfg.mfg_item_costs;
CREATE TRIGGER mfg_item_costs_freeze BEFORE INSERT OR UPDATE OR DELETE ON mfg.mfg_item_costs
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_cost_set_frozen();

-- ===================================================================== invariants
DO $$
DECLARE t text;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                    WHERE g.tgrelid = 'mfg.mfg_cost_rollup_lines'::regclass AND p.proname = 'mfg_refuse_change' AND NOT g.tgisinternal) THEN
        RAISE EXCEPTION 'mfg.mfg_cost_rollup_lines is not append-only: its mfg_refuse_change trigger is missing';
    END IF;
    FOREACH t IN ARRAY ARRAY['mfg_cost_sets', 'mfg_item_costs'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = ('mfg.' || t)::regclass AND tgname = t || '_freeze' AND NOT tgisinternal) THEN
            RAISE EXCEPTION 'mfg.% does not keep frozen cost sets frozen: trigger %_freeze is missing', t, t;
        END IF;
    END LOOP;
END $$;

COMMIT;
