-- Manufacturing: demand and supply planning, MRP (design: docs/mfg/03-database-model.md §3.5
-- Planning, §5; 02-domain-model.md §3; contract R2.md C1-C5, R-4).
--
--   mfg_demands            demand entered in Manufacturing (C1): a customer order line or a plain
--                          demand line, for a business with or without SCM. open | fulfilled |
--                          cancelled. With SCM, MRP also reads open sales-order lines through
--                          mfg.src_scm_open_so_lines (20261030-16)
--   mfg_mrp_runs           one full regeneration (POST /mrp/runs, or the nightly job): scope,
--                          horizon, parameters, counts. One is_current run per business and plant
--   mfg_mrp_dirty          the net-change queue (C3, R-4; 03's mfg_mrp_dirty_items): an item whose
--                          supply or demand changed, marked by an upsert in the SAME transaction as
--                          the write (order create/release/complete/cancel, stock in or out through
--                          Manufacturing, demand change, BOM or routing release) that appends the
--                          reason. A re-net claims rows (DELETE ... RETURNING, lowest low-level code
--                          first) and deletes them; it is a queue, not a log
--   mfg_item_plan_state    per item and plant: when it was last netted, by which mode, and whether
--                          its plan is fresh | pending | failed (the freshness the UI shows)
--   mfg_planned_orders     what MRP proposes: make | buy | transfer | subcontract, planned ->
--                          firmed -> converted | deleted. rule_trace (C4) is how the order was made:
--                          gross requirement, available, net, lot-size rule, lead time, scrap and
--                          yield, safety stock. Full and net-change runs use one engine
--   mfg_pegging            each supply linked to the demand it serves, up to the top demand
--                          ("why is this here?"). Replaced per item on each re-net
--   mfg_mrp_messages       expedite | delay | cancel | increase | decrease | shortage | past_due |
--                          below_safety | lead_time_violated, on the order they concern
--
-- Item settings gain what MRP needs that R1 did not hold: lead_time_days (the purchase or transfer
-- lead time; for a make, the routing's own lead time is added to make_lead_time_days by the engine)
-- and safety_stock (C4). Both are added here as ADD COLUMN IF NOT EXISTS.
--
-- Plant ids are mfg_plants ids; product ids cp_products ids and supplier/customer ids cp_parties
-- ids, registered for merges in 20261030-20. The CHECK lists live in 20261030-17. No grants.
-- Idempotent; safe to re-run.

BEGIN;

-- ==================================================================== item settings
ALTER TABLE mfg.mfg_item_settings ADD COLUMN IF NOT EXISTS lead_time_days integer;
ALTER TABLE mfg.mfg_item_settings ADD COLUMN IF NOT EXISTS safety_stock numeric(18,6) NOT NULL DEFAULT 0;
ALTER TABLE mfg.mfg_item_settings DROP CONSTRAINT IF EXISTS mfg_item_settings_planning_check;
ALTER TABLE mfg.mfg_item_settings ADD CONSTRAINT mfg_item_settings_planning_check
    CHECK ((lead_time_days IS NULL OR lead_time_days >= 0) AND safety_stock >= 0);

-- ========================================================================== demands
CREATE TABLE IF NOT EXISTS mfg.mfg_demands (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    plant_id          text NOT NULL REFERENCES mfg.mfg_plants (id),
    number            text,                           -- DM-00012 (mfg_number_series kind demand); NULL if none kept
    party_id          text,                           -- the customer (cp_parties.id), optional
    customer_name     text,                           -- the customer as shown: the party's name, or the text typed
    product_id        text NOT NULL,                  -- cp_products.id
    qty               numeric(18,6) NOT NULL CHECK (qty > 0),
    unit              text NOT NULL,
    due_on            date NOT NULL,                  -- the API's due_date
    status            text NOT NULL DEFAULT 'open',
    reference         text,                           -- the customer's order number, or any text
    notes             text,
    idempotency_key   text,
    cancelled_at      timestamptz,
    cancelled_by      text,
    cancelled_reason  text,
    version           integer NOT NULL DEFAULT 1,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_demands_number_uq ON mfg.mfg_demands (bus_id, number) WHERE number IS NOT NULL;
CREATE INDEX IF NOT EXISTS mfg_demands_list_idx ON mfg.mfg_demands (bus_id, plant_id, status, due_on);
CREATE INDEX IF NOT EXISTS mfg_demands_open_idx ON mfg.mfg_demands (bus_id, product_id, due_on) WHERE status = 'open';
CREATE UNIQUE INDEX IF NOT EXISTS mfg_demands_idempotency_uq
    ON mfg.mfg_demands (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;

-- ========================================================================= MRP runs
CREATE TABLE IF NOT EXISTS mfg.mfg_mrp_runs (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    plant_id          text REFERENCES mfg.mfg_plants (id),   -- NULL = every plant of the business
    scope             jsonb NOT NULL DEFAULT '{}',           -- {"product_ids": [...]}; {} = everything
    horizon_days      integer NOT NULL DEFAULT 90 CHECK (horizon_days BETWEEN 1 AND 1095),
    params            jsonb NOT NULL DEFAULT '{}',
    mode              text NOT NULL DEFAULT 'regenerative',
    triggered_by      text NOT NULL DEFAULT 'user',          -- user | job
    status            text NOT NULL DEFAULT 'running',
    started_at        timestamptz NOT NULL DEFAULT now(),
    finished_at       timestamptz,
    counts            jsonb NOT NULL DEFAULT '{}',           -- {"items", "planned_orders", "messages", ...}
    error             text,
    is_current        boolean NOT NULL DEFAULT false,
    idempotency_key   text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text,
    CHECK (finished_at IS NULL OR finished_at >= started_at)
);
-- A finished run has an end time; a running one has none.
ALTER TABLE mfg.mfg_mrp_runs DROP CONSTRAINT IF EXISTS mfg_mrp_runs_finished_check;
ALTER TABLE mfg.mfg_mrp_runs ADD CONSTRAINT mfg_mrp_runs_finished_check CHECK ((status = 'running') = (finished_at IS NULL));
CREATE INDEX IF NOT EXISTS mfg_mrp_runs_list_idx ON mfg.mfg_mrp_runs (bus_id, started_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_mrp_runs_current_uq
    ON mfg.mfg_mrp_runs (bus_id, coalesce(plant_id, '')) WHERE is_current;
CREATE UNIQUE INDEX IF NOT EXISTS mfg_mrp_runs_idempotency_uq
    ON mfg.mfg_mrp_runs (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;

-- ================================================================ net-change queue
CREATE TABLE IF NOT EXISTS mfg.mfg_mrp_dirty (
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    plant_id          text NOT NULL,
    product_id        text NOT NULL,
    low_level_code    integer NOT NULL DEFAULT 0,
    reasons           text[] NOT NULL DEFAULT '{}',   -- e.g. production_order.released, demand.changed, bom.released
    first_marked_at   timestamptz NOT NULL DEFAULT now(),
    last_marked_at    timestamptz NOT NULL DEFAULT now(),
    marked_by         text,
    PRIMARY KEY (bus_id, plant_id, product_id)
);
CREATE INDEX IF NOT EXISTS mfg_mrp_dirty_claim_idx ON mfg.mfg_mrp_dirty (bus_id, low_level_code, first_marked_at);
COMMENT ON TABLE mfg.mfg_mrp_dirty IS
    'Net-change MRP queue (R2 C3). Mark: INSERT ... ON CONFLICT (bus_id, plant_id, product_id) DO UPDATE SET reasons = array_append, last_marked_at = now(). Claim: DELETE ... RETURNING under FOR UPDATE SKIP LOCKED, lowest low_level_code first.';

CREATE TABLE IF NOT EXISTS mfg.mfg_item_plan_state (
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    plant_id          text NOT NULL,
    product_id        text NOT NULL,
    low_level_code    integer NOT NULL DEFAULT 0,
    last_netted_at    timestamptz,                    -- the API's planned_at
    last_run_id       text,                           -- the run that netted it last; NULL for a lazy re-net
    netted_by         text,                           -- net_change | regenerative
    status            text NOT NULL DEFAULT 'pending',
    error             text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (bus_id, plant_id, product_id)
);
CREATE INDEX IF NOT EXISTS mfg_item_plan_state_status_idx ON mfg.mfg_item_plan_state (bus_id, status) WHERE status <> 'fresh';

-- ================================================================= planned orders
CREATE TABLE IF NOT EXISTS mfg.mfg_planned_orders (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    org_id              text,
    bus_id              text NOT NULL,
    plant_id            text NOT NULL REFERENCES mfg.mfg_plants (id),
    number              text,                           -- PLN-00031 (mfg_number_series kind planned_order); NULL if none kept
    run_id              text REFERENCES mfg.mfg_mrp_runs (id),   -- NULL when a net-change re-net made it
    netted_by           text NOT NULL DEFAULT 'regenerative',    -- net_change | regenerative
    product_id          text NOT NULL,
    type                text NOT NULL,
    qty                 numeric(18,6) NOT NULL CHECK (qty > 0),
    unit                text NOT NULL,
    due_on              date NOT NULL,                  -- the API's due_date
    release_on          date NOT NULL,                  -- due minus lead time; the API's release_date
    bom_id              text REFERENCES mfg.mfg_boms (id),
    routing_id          text REFERENCES mfg.mfg_routings (id),
    supplier_party_id   text,                           -- a buy's preferred supplier (cp_parties.id)
    from_warehouse_id   text,                           -- a transfer's source (scm.scm_warehouses id)
    warehouse_id        text,                           -- where the supply lands
    low_level_code      integer NOT NULL DEFAULT 0,
    status              text NOT NULL DEFAULT 'planned',
    rule_trace          jsonb NOT NULL DEFAULT '{}',    -- C4: {"gross", "available", "net", "lot_size_rule", "lot_size", "lead_time_days", "scrap_pct", "yield_pct", "safety_stock", "steps": [...]}
    firmed_at           timestamptz,
    firmed_by           text,
    converted_to_type   text,                           -- production_order | scm_requisition | scm_transfer
    converted_to_id     text,
    converted_at        timestamptz,
    converted_by        text,
    notes               text,
    version             integer NOT NULL DEFAULT 1,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    created_by          text,
    updated_at          timestamptz NOT NULL DEFAULT now(),
    updated_by          text
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_planned_orders_number_uq ON mfg.mfg_planned_orders (bus_id, number) WHERE number IS NOT NULL;
CREATE INDEX IF NOT EXISTS mfg_planned_orders_worklist_idx
    ON mfg.mfg_planned_orders (bus_id, plant_id, run_id, status, release_on);
CREATE INDEX IF NOT EXISTS mfg_planned_orders_product_idx ON mfg.mfg_planned_orders (bus_id, product_id, status, due_on);
CREATE INDEX IF NOT EXISTS mfg_planned_orders_converted_idx
    ON mfg.mfg_planned_orders (converted_to_type, converted_to_id) WHERE converted_to_id IS NOT NULL;
ALTER TABLE mfg.mfg_planned_orders DROP CONSTRAINT IF EXISTS mfg_planned_orders_dates_check;
ALTER TABLE mfg.mfg_planned_orders ADD CONSTRAINT mfg_planned_orders_dates_check CHECK (release_on <= due_on);
ALTER TABLE mfg.mfg_planned_orders DROP CONSTRAINT IF EXISTS mfg_planned_orders_converted_check;
ALTER TABLE mfg.mfg_planned_orders ADD CONSTRAINT mfg_planned_orders_converted_check
    CHECK ((status = 'converted') = (converted_to_id IS NOT NULL AND converted_to_type IS NOT NULL));

-- ======================================================================== pegging
CREATE TABLE IF NOT EXISTS mfg.mfg_pegging (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    plant_id          text NOT NULL,
    run_id            text,
    product_id        text NOT NULL,                  -- the item of the supply
    supply_type       text NOT NULL,
    supply_id         text NOT NULL,                  -- for on_hand: the lot id, or '' when untracked
    demand_type       text NOT NULL,
    demand_id         text NOT NULL,                  -- for safety_stock: the product id
    qty               numeric(18,6) NOT NULL CHECK (qty > 0),
    need_on           date,
    level             integer NOT NULL DEFAULT 0,     -- 0 = the top demand's own item
    top_demand_type   text NOT NULL,
    top_demand_id     text NOT NULL,
    cdatetime         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS mfg_pegging_supply_idx ON mfg.mfg_pegging (bus_id, supply_type, supply_id);
CREATE INDEX IF NOT EXISTS mfg_pegging_demand_idx ON mfg.mfg_pegging (bus_id, demand_type, demand_id);
CREATE INDEX IF NOT EXISTS mfg_pegging_top_idx ON mfg.mfg_pegging (bus_id, top_demand_type, top_demand_id);
CREATE INDEX IF NOT EXISTS mfg_pegging_item_idx ON mfg.mfg_pegging (bus_id, plant_id, product_id);

-- ==================================================================== MRP messages
CREATE TABLE IF NOT EXISTS mfg.mfg_mrp_messages (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    plant_id          text NOT NULL,
    run_id            text,
    product_id        text NOT NULL,
    kind              text NOT NULL,
    subject_type      text NOT NULL,                  -- planned_order | production_order | scm_po_line | demand | item
    subject_id        text NOT NULL,
    current_on        date,                           -- the subject's date now; the API's current_date
    suggested_on      date,                           -- the API's suggested_date
    current_qty       numeric(18,6),
    suggested_qty     numeric(18,6),
    message           text,                           -- the engine's sentence; the API's text
    detail            jsonb NOT NULL DEFAULT '{}',
    status            text NOT NULL DEFAULT 'open',
    acted_at          timestamptz,
    acted_by          text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS mfg_mrp_messages_list_idx ON mfg.mfg_mrp_messages (bus_id, plant_id, status, kind);
CREATE INDEX IF NOT EXISTS mfg_mrp_messages_item_idx ON mfg.mfg_mrp_messages (bus_id, product_id);
CREATE INDEX IF NOT EXISTS mfg_mrp_messages_subject_idx ON mfg.mfg_mrp_messages (subject_type, subject_id);

-- ===================================================================== invariants
DO $$
BEGIN
    -- A converted planned order names what it became (also a CHECK; asserted for older rows).
    IF EXISTS (SELECT 1 FROM mfg.mfg_planned_orders
                WHERE status = 'converted' AND (converted_to_id IS NULL OR converted_to_type IS NULL)) THEN
        RAISE EXCEPTION 'a converted Manufacturing planned order does not name what it became';
    END IF;
    -- At most one current run per business and plant (also the unique index).
    IF EXISTS (SELECT 1 FROM mfg.mfg_mrp_runs WHERE is_current
                GROUP BY bus_id, coalesce(plant_id, '') HAVING count(*) > 1) THEN
        RAISE EXCEPTION 'a business has more than one current Manufacturing MRP run for a plant';
    END IF;
END $$;

COMMIT;
