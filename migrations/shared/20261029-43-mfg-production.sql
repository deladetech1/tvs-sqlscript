-- Manufacturing: production orders and the shop floor (design: docs/mfg/03-database-model.md §3.4,
-- §5, §6, §7, §8; 02-domain-model.md §5; contract R1.md §2 A3, A7, A10 and §3).
--
--   mfg_production_orders   one order table for every mode (R-1): discrete | batch | repetitive |
--                           kanban (R1's API accepts discrete and batch only, A3). Carries the
--                           order's progress (qty_good/scrap/rework, kept in the confirmation's
--                           transaction) and its READINESS READ MODEL (R-3): ready_material,
--                           ready_capacity, ready_maintenance, ready_quality (green | amber | red |
--                           unknown), readiness_evidence and readiness_at, kept by the readiness
--                           reader. Holds are flags, not states
--   mfg_order_components    the BOM lines frozen at release, with required, reserved, staged,
--                           issued and returned quantities. Co- and by-products of a batch order
--                           are rows with line_type co_product / by_product and negative quantity
--   mfg_order_operations    the routing frozen at release, with status, actual times and
--                           quantities, and the same readiness columns per operation
--   mfg_confirmations       append-only; what the floor reported (start, pause, resume, report,
--                           finish, reversal). Partitioned by month of occurred_at (A10)
--   mfg_downtime_events     append-only; a stop is opened and closed by two rows (and reclassified
--                           by a third). Partitioned by month of starts_at (A10)
--   mfg_downtime_current    read model: the one open stop per resource, kept in the same
--                           transaction as the downtime row
--   mfg_genealogy_links     append-only; lot/serial parent -> child, so a lot can be traced either
--                           way. Partitioned by month of cdatetime (03 §6)
--   mfg_floor_requests      a quality alert or maintenance request raised at a station, with its
--                           context (A7); later it links to the NCR or work order it became
--   mfg_order_timeline      append-only; what happened to an order, newest first, for the order
--                           page (state changes, issues, confirmations, downtime, holds)
--
-- The partitions of this month and the next three are made here by mfg.mfg_ensure_partitions
-- (20261029-40); the upkeep job adds later months. Primary keys of partitioned tables include the
-- partition column, so id alone is unique by the API (UUIDs) and the idempotency key is the real
-- duplicate guard. The append-only trigger is on each parent and every partition inherits it.
--
-- Product ids are registered for merges in 20261029-47. The CHECK lists live in 20261029-46.
-- Idempotent; safe to re-run.

BEGIN;

-- ============================================================ production orders
CREATE TABLE IF NOT EXISTS mfg.mfg_production_orders (
    id                      text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id               text NOT NULL,
    org_id                  text,
    bus_id                  text NOT NULL,
    plant_id                text NOT NULL REFERENCES mfg.mfg_plants (id),
    number                  text NOT NULL,                  -- MO-00042
    mode                    text NOT NULL DEFAULT 'discrete',
    -- batch mode (R-1); NULL for the other modes
    batch_size_basis        numeric(18,6),
    potency_target_pct      numeric(8,4),
    potency_actual_pct      numeric(8,4),
    recipe_scale_factor     numeric(18,6),
    -- repetitive / kanban (R-1): a rate over a period, and the card that triggered it
    rate_per_hour           numeric(18,6),
    period_start            timestamptz,
    period_end              timestamptz,
    kanban_card_id          text,
    -- readiness read model (R-3): each signal with its evidence
    ready_material          text NOT NULL DEFAULT 'red',
    ready_capacity          text NOT NULL DEFAULT 'amber',
    ready_maintenance       text NOT NULL DEFAULT 'green',
    ready_quality           text NOT NULL DEFAULT 'green',
    readiness_evidence      jsonb NOT NULL DEFAULT '{}',    -- {"material": {"status", "reason", "links": [...]}, ...}
    readiness_at            timestamptz,
    product_id              text NOT NULL,
    item_revision_id        text REFERENCES mfg.mfg_item_revisions (id),
    bom_id                  text REFERENCES mfg.mfg_boms (id),        -- the revisions frozen at release
    routing_id              text REFERENCES mfg.mfg_routings (id),
    config_id               text,
    qty                     numeric(18,6) NOT NULL CHECK (qty > 0),
    unit                    text NOT NULL,
    qty_good                numeric(18,6) NOT NULL DEFAULT 0,
    qty_scrap               numeric(18,6) NOT NULL DEFAULT 0,
    qty_rework              numeric(18,6) NOT NULL DEFAULT 0,
    status                  text NOT NULL DEFAULT 'planned',
    hold_material           boolean NOT NULL DEFAULT false,
    hold_quality            boolean NOT NULL DEFAULT false,
    hold_maintenance        boolean NOT NULL DEFAULT false,
    priority                integer NOT NULL DEFAULT 50,
    due_at                  timestamptz NOT NULL,
    planned_start           timestamptz,
    planned_end             timestamptz,
    actual_start            timestamptz,
    actual_end              timestamptz,
    estimated_end           timestamptz,
    demand_type             text,                           -- the top demand: sales_order_line | forecast | stock | parent_order
    demand_id               text,
    demands                 jsonb NOT NULL DEFAULT '[]',    -- every demand [{type, id, label}]
    component_warehouse_id  text,                           -- scm.scm_warehouses ids
    output_warehouse_id     text,
    output_bin_id           text,
    lot_number              text,                           -- the output lot to make; generated if empty
    planned_order_id        text,
    parent_order_id         text REFERENCES mfg.mfg_production_orders (id),
    cost_center             text,
    currency                text,
    notes                   text,
    custom                  jsonb NOT NULL DEFAULT '{}',
    idempotency_key         text,
    released_at             timestamptz,
    released_by             text,
    closed_at               timestamptz,
    closed_by               text,
    cancelled_at            timestamptz,
    cancelled_by            text,
    cancelled_reason        text,
    version                 integer NOT NULL DEFAULT 1,
    cdatetime               timestamptz NOT NULL DEFAULT now(),
    created_by              text,
    updated_at              timestamptz NOT NULL DEFAULT now(),
    updated_by              text,
    UNIQUE (bus_id, number)
);
CREATE INDEX IF NOT EXISTS mfg_production_orders_list_idx ON mfg.mfg_production_orders (bus_id, plant_id, status, due_at);
CREATE INDEX IF NOT EXISTS mfg_production_orders_product_idx ON mfg.mfg_production_orders (bus_id, product_id, status);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_production_orders_idempotency_uq
    ON mfg.mfg_production_orders (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
ALTER TABLE mfg.mfg_production_orders DROP CONSTRAINT IF EXISTS mfg_production_orders_quantities_check;
ALTER TABLE mfg.mfg_production_orders ADD CONSTRAINT mfg_production_orders_quantities_check
    CHECK (qty_good >= 0 AND qty_scrap >= 0 AND qty_rework >= 0
           AND (period_end IS NULL OR period_start IS NULL OR period_end > period_start));

CREATE TABLE IF NOT EXISTS mfg.mfg_order_components (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    org_id              text,
    bus_id              text NOT NULL,
    order_id            text NOT NULL REFERENCES mfg.mfg_production_orders (id) ON DELETE CASCADE,
    bom_line_id         text,
    position            integer,
    component_id        text NOT NULL,                    -- cp_products.id
    qty_required        numeric(18,6) NOT NULL,           -- negative for co/by-products
    unit                text NOT NULL,
    qty_reserved        numeric(18,6) NOT NULL DEFAULT 0,
    qty_staged          numeric(18,6) NOT NULL DEFAULT 0,
    qty_issued          numeric(18,6) NOT NULL DEFAULT 0, -- ledger issues minus returns, kept in the posting tx
    qty_returned        numeric(18,6) NOT NULL DEFAULT 0,
    operation_seq       integer,
    issue_method        text NOT NULL,
    line_type           text NOT NULL,
    scrap_pct           numeric(6,3) NOT NULL DEFAULT 0,
    cost_share_pct      numeric(6,3),                     -- co/by-products of a batch order
    substitute_for_id   text REFERENCES mfg.mfg_order_components (id),
    rounding_diff       numeric(18,6) NOT NULL DEFAULT 0,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    created_by          text,
    updated_at          timestamptz NOT NULL DEFAULT now(),
    updated_by          text
);
CREATE INDEX IF NOT EXISTS mfg_order_components_order_idx ON mfg.mfg_order_components (order_id, position);
CREATE INDEX IF NOT EXISTS mfg_order_components_component_idx ON mfg.mfg_order_components (bus_id, component_id);
ALTER TABLE mfg.mfg_order_components DROP CONSTRAINT IF EXISTS mfg_order_components_quantities_check;
ALTER TABLE mfg.mfg_order_components ADD CONSTRAINT mfg_order_components_quantities_check
    CHECK (qty_reserved >= 0 AND qty_staged >= 0 AND qty_returned >= 0);

CREATE TABLE IF NOT EXISTS mfg.mfg_order_operations (
    id                    text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id             text NOT NULL,
    org_id                text,
    bus_id                text NOT NULL,
    order_id              text NOT NULL REFERENCES mfg.mfg_production_orders (id) ON DELETE CASCADE,
    routing_operation_id  text,                         -- the mfg_operations row it was frozen from
    seq                   integer NOT NULL,
    name                  text,
    description           text,
    work_center_id        text NOT NULL REFERENCES mfg.mfg_work_centers (id),
    resource_id           text REFERENCES mfg.mfg_resources (id),
    status                text NOT NULL DEFAULT 'waiting',
    setup_min_planned     numeric(12,3),
    run_min_planned       numeric(14,3),
    setup_min_actual      numeric(12,3) NOT NULL DEFAULT 0,
    run_min_actual        numeric(14,3) NOT NULL DEFAULT 0,
    labour_min_actual     numeric(14,3) NOT NULL DEFAULT 0,
    qty_good              numeric(18,6) NOT NULL DEFAULT 0,
    qty_scrap             numeric(18,6) NOT NULL DEFAULT 0,
    qty_rework            numeric(18,6) NOT NULL DEFAULT 0,
    send_ahead_qty        numeric(18,6),
    after_seqs            integer[] NOT NULL DEFAULT '{}',   -- predecessors; empty = the previous seq
    control_key           text NOT NULL,
    work_instruction_id   text REFERENCES mfg.mfg_work_instructions (id),
    inspection_plan_id    text,
    operators             text[] NOT NULL DEFAULT '{}',      -- user ids clocked on
    -- readiness read model (R-3), the operator's view
    ready_material        text NOT NULL DEFAULT 'red',
    ready_capacity        text NOT NULL DEFAULT 'amber',
    ready_maintenance     text NOT NULL DEFAULT 'green',
    ready_quality         text NOT NULL DEFAULT 'green',
    readiness_evidence    jsonb NOT NULL DEFAULT '{}',
    readiness_at          timestamptz,
    started_at            timestamptz,
    finished_at           timestamptz,
    version               integer NOT NULL DEFAULT 1,
    cdatetime             timestamptz NOT NULL DEFAULT now(),
    created_by            text,
    updated_at            timestamptz NOT NULL DEFAULT now(),
    updated_by            text,
    UNIQUE (order_id, seq)
);
CREATE INDEX IF NOT EXISTS mfg_order_operations_dispatch_idx ON mfg.mfg_order_operations (work_center_id, status);
CREATE INDEX IF NOT EXISTS mfg_order_operations_resource_idx ON mfg.mfg_order_operations (resource_id, status) WHERE resource_id IS NOT NULL;
ALTER TABLE mfg.mfg_order_operations DROP CONSTRAINT IF EXISTS mfg_order_operations_quantities_check;
ALTER TABLE mfg.mfg_order_operations ADD CONSTRAINT mfg_order_operations_quantities_check
    CHECK (qty_good >= 0 AND qty_scrap >= 0 AND qty_rework >= 0);

-- ================================================================ confirmations
CREATE TABLE IF NOT EXISTS mfg.mfg_confirmations (
    id                text NOT NULL DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    plant_id          text NOT NULL,
    order_id          text NOT NULL,
    operation_id      text NOT NULL,                  -- mfg_order_operations.id
    resource_id       text,
    kind              text NOT NULL,                  -- start | pause | resume | report | finish | reversal
    qty_good          numeric(18,6) NOT NULL DEFAULT 0,
    qty_scrap         numeric(18,6) NOT NULL DEFAULT 0,
    qty_rework        numeric(18,6) NOT NULL DEFAULT 0,
    scrap_reason_id   text,
    rework_reason_id  text,
    pause_reason_id   text,
    setup_min         numeric(12,3) NOT NULL DEFAULT 0,
    run_min           numeric(14,3) NOT NULL DEFAULT 0,
    labour_min        numeric(14,3) NOT NULL DEFAULT 0,
    operators         text[] NOT NULL DEFAULT '{}',
    lots              jsonb NOT NULL DEFAULT '[]',    -- produced lot/serial ids (also in genealogy)
    checkpoints       jsonb NOT NULL DEFAULT '[]',    -- [{key, value}] recorded with it
    is_final          boolean NOT NULL DEFAULT false, -- the operation is done
    reverses_id       text,                           -- kind reversal: the confirmation undone; quantities negated
    reason            text,                           -- why it was reversed
    flags             text[] NOT NULL DEFAULT '{}',   -- late | offline | over_delivery | override | out_of_sequence
    occurred_at       timestamptz NOT NULL,           -- when it happened on the floor (offline-safe)
    recorded_at       timestamptz NOT NULL DEFAULT now(),
    is_late           boolean NOT NULL DEFAULT false, -- arrived after a later state change, or past the window
    is_offline        boolean NOT NULL DEFAULT false,
    device_id         text,
    session_id        text,
    idempotency_key   text NOT NULL,
    actor             text NOT NULL,
    PRIMARY KEY (id, occurred_at)
) PARTITION BY RANGE (occurred_at);
SELECT mfg.mfg_ensure_partitions('mfg_confirmations', 3);
CREATE INDEX IF NOT EXISTS mfg_confirmations_order_idx ON mfg.mfg_confirmations (bus_id, order_id, occurred_at);
CREATE INDEX IF NOT EXISTS mfg_confirmations_resource_idx ON mfg.mfg_confirmations (bus_id, resource_id, occurred_at);
CREATE INDEX IF NOT EXISTS mfg_confirmations_operation_idx ON mfg.mfg_confirmations (operation_id, occurred_at);
CREATE INDEX IF NOT EXISTS mfg_confirmations_key_idx ON mfg.mfg_confirmations (bus_id, idempotency_key);
CREATE INDEX IF NOT EXISTS mfg_confirmations_reverses_idx ON mfg.mfg_confirmations (reverses_id) WHERE reverses_id IS NOT NULL;

DROP TRIGGER IF EXISTS mfg_confirmations_append_only ON mfg.mfg_confirmations;
CREATE TRIGGER mfg_confirmations_append_only BEFORE UPDATE OR DELETE ON mfg.mfg_confirmations
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_refuse_change();

-- ===================================================================== downtime
-- open: starts_at, no ends_at. close: a new row naming the open one (refers_to_id) with the same
-- starts_at and its ends_at. reclassify: a new row naming the open one, with the new reason.
CREATE TABLE IF NOT EXISTS mfg.mfg_downtime_events (
    id               text NOT NULL DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    plant_id         text NOT NULL,
    resource_id      text NOT NULL,
    starts_at        timestamptz NOT NULL,
    ends_at          timestamptz,
    kind             text NOT NULL,                 -- open | close | reclassify
    reason_id        text,                          -- mfg_reason_codes.id
    source           text NOT NULL,                 -- operator | iot | maintenance
    order_id         text,
    operation_id     text,
    comment          text,
    refers_to_id     text,                          -- close / reclassify: the open row
    maintenance_requested boolean NOT NULL DEFAULT false,
    idempotency_key  text,
    actor            text,
    device_id        text,
    recorded_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id, starts_at),
    CHECK (ends_at IS NULL OR ends_at >= starts_at)
) PARTITION BY RANGE (starts_at);
SELECT mfg.mfg_ensure_partitions('mfg_downtime_events', 3);
CREATE INDEX IF NOT EXISTS mfg_downtime_events_resource_idx ON mfg.mfg_downtime_events (bus_id, resource_id, starts_at);
CREATE INDEX IF NOT EXISTS mfg_downtime_events_plant_idx ON mfg.mfg_downtime_events (bus_id, plant_id, starts_at);
CREATE INDEX IF NOT EXISTS mfg_downtime_events_refers_idx ON mfg.mfg_downtime_events (refers_to_id) WHERE refers_to_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS mfg_downtime_events_order_idx ON mfg.mfg_downtime_events (order_id) WHERE order_id IS NOT NULL;

DROP TRIGGER IF EXISTS mfg_downtime_events_append_only ON mfg.mfg_downtime_events;
CREATE TRIGGER mfg_downtime_events_append_only BEFORE UPDATE OR DELETE ON mfg.mfg_downtime_events
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_refuse_change();

-- The open stop of each resource; deleted when it closes. version for PATCH (reclassify).
CREATE TABLE IF NOT EXISTS mfg.mfg_downtime_current (
    resource_id    text PRIMARY KEY REFERENCES mfg.mfg_resources (id) ON DELETE CASCADE,
    tenant_id      text NOT NULL,
    org_id         text,
    bus_id         text NOT NULL,
    plant_id       text NOT NULL,
    downtime_id    text NOT NULL,                 -- the open mfg_downtime_events row
    starts_at      timestamptz NOT NULL,
    reason_id      text,
    source         text NOT NULL,
    order_id       text,
    operation_id   text,
    comment        text,
    version        integer NOT NULL DEFAULT 1,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text,
    updated_at     timestamptz NOT NULL DEFAULT now(),
    updated_by     text
);
CREATE INDEX IF NOT EXISTS mfg_downtime_current_plant_idx ON mfg.mfg_downtime_current (bus_id, plant_id);

-- ==================================================================== genealogy
-- Backward (what went into this lot): from parent_id = lot, follow parent -> child.
-- Forward (recall): from child_id = lot, follow child -> parent.
CREATE TABLE IF NOT EXISTS mfg.mfg_genealogy_links (
    id               text NOT NULL DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    parent_kind      text NOT NULL,                 -- lot | serial
    parent_id        text NOT NULL,                 -- scm.scm_lots / scm.scm_serials id: what was made
    child_kind       text NOT NULL,
    child_id         text NOT NULL,                 -- what went into it
    qty              numeric(18,6),
    unit             text,
    link_type        text NOT NULL,                 -- consume | split | merge | rework
    order_id         text,
    operation_id     text,
    confirmation_id  text,
    movement_id      text,                          -- the ledger movement that consumed the child
    created_by       text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id, cdatetime)
) PARTITION BY RANGE (cdatetime);
SELECT mfg.mfg_ensure_partitions('mfg_genealogy_links', 3);
CREATE INDEX IF NOT EXISTS mfg_genealogy_links_forward_idx ON mfg.mfg_genealogy_links (bus_id, child_id) INCLUDE (parent_id, parent_kind, qty);
CREATE INDEX IF NOT EXISTS mfg_genealogy_links_backward_idx ON mfg.mfg_genealogy_links (bus_id, parent_id) INCLUDE (child_id, child_kind, qty);
CREATE INDEX IF NOT EXISTS mfg_genealogy_links_order_idx ON mfg.mfg_genealogy_links (order_id) WHERE order_id IS NOT NULL;

DROP TRIGGER IF EXISTS mfg_genealogy_links_append_only ON mfg.mfg_genealogy_links;
CREATE TRIGGER mfg_genealogy_links_append_only BEFORE UPDATE OR DELETE ON mfg.mfg_genealogy_links
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_refuse_change();

-- =============================================================== floor requests
CREATE TABLE IF NOT EXISTS mfg.mfg_floor_requests (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    org_id             text,
    bus_id             text NOT NULL,
    plant_id           text REFERENCES mfg.mfg_plants (id),
    kind               text NOT NULL,                -- quality_alert | maintenance_request
    status             text NOT NULL DEFAULT 'open', -- open | acknowledged | closed
    order_id           text REFERENCES mfg.mfg_production_orders (id),
    operation_id       text REFERENCES mfg.mfg_order_operations (id),
    resource_id        text REFERENCES mfg.mfg_resources (id),
    product_id         text,                         -- the order's product, copied for lists
    lot_id             text,                         -- scm.scm_lots id
    note               text NOT NULL,                -- what the operator wrote (the API's description)
    defect_code        text,                         -- quality alert
    qty_suspect        numeric(18,6),
    stop_operation     boolean NOT NULL DEFAULT false,
    machine_stopped    boolean NOT NULL DEFAULT false,   -- maintenance request; also opens downtime
    downtime_id        text,
    photos             jsonb NOT NULL DEFAULT '[]',  -- document ids
    became_type        text,                         -- ncr (R2) | maintenance_order (R3)
    became_id          text,
    acknowledged_at    timestamptz,
    acknowledged_by    text,
    closed_at          timestamptz,
    closed_by          text,
    close_note         text,
    device_id          text,
    idempotency_key    text,
    version            integer NOT NULL DEFAULT 1,
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    created_by         text,
    updated_at         timestamptz NOT NULL DEFAULT now(),
    updated_by         text
);
CREATE INDEX IF NOT EXISTS mfg_floor_requests_list_idx ON mfg.mfg_floor_requests (bus_id, plant_id, status, cdatetime DESC);
CREATE INDEX IF NOT EXISTS mfg_floor_requests_order_idx ON mfg.mfg_floor_requests (order_id) WHERE order_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS mfg_floor_requests_idempotency_uq
    ON mfg.mfg_floor_requests (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;

-- ================================================================ order timeline
CREATE TABLE IF NOT EXISTS mfg.mfg_order_timeline (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    org_id       text,
    bus_id       text NOT NULL,
    order_id     text NOT NULL,
    at           timestamptz NOT NULL DEFAULT now(),
    kind         text NOT NULL,               -- the event kind, e.g. production_order.released, confirmation.posted
    summary      text NOT NULL,               -- one sentence for the order page
    ref_type     text,                        -- confirmation | downtime | movement | floor_request | ...
    ref_id       text,
    actor        text,
    data         jsonb NOT NULL DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS mfg_order_timeline_order_idx ON mfg.mfg_order_timeline (bus_id, order_id, at DESC);

DROP TRIGGER IF EXISTS mfg_order_timeline_append_only ON mfg.mfg_order_timeline;
CREATE TRIGGER mfg_order_timeline_append_only BEFORE UPDATE OR DELETE ON mfg.mfg_order_timeline
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_refuse_change();

-- ===================================================================== invariants
DO $$
DECLARE
    t     text;
    m     date;
    n     integer;
BEGIN
    -- Every partitioned table has this month's and next month's partitions (UTC).
    FOREACH t IN ARRAY ARRAY['mfg_confirmations', 'mfg_downtime_events', 'mfg_genealogy_links'] LOOP
        IF (SELECT relkind FROM pg_class WHERE oid = ('mfg.' || t)::regclass) <> 'p' THEN
            RAISE EXCEPTION 'mfg.% is not partitioned', t;
        END IF;
        FOREACH m IN ARRAY ARRAY[date_trunc('month', now() AT TIME ZONE 'UTC')::date,
                                 (date_trunc('month', now() AT TIME ZONE 'UTC') + interval '1 month')::date] LOOP
            IF to_regclass(format('mfg.%s_y%sm%s', t, to_char(m, 'YYYY'), to_char(m, 'MM'))) IS NULL THEN
                RAISE EXCEPTION 'mfg.% has no partition for %', t, to_char(m, 'YYYY-MM');
            END IF;
        END LOOP;
    END LOOP;

    -- Every append-only table has its refuse trigger on the parent.
    FOREACH t IN ARRAY ARRAY['mfg_confirmations', 'mfg_downtime_events', 'mfg_genealogy_links', 'mfg_order_timeline'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                        WHERE g.tgrelid = ('mfg.' || t)::regclass AND p.proname = 'mfg_refuse_change' AND NOT g.tgisinternal) THEN
            RAISE EXCEPTION 'mfg.% is not append-only: its mfg_refuse_change trigger is missing', t;
        END IF;
    END LOOP;

    -- Reported, never blocking: orders over their over-production tolerance with no audit row.
    SELECT count(*) INTO n
      FROM mfg.mfg_production_orders o
      LEFT JOIN mfg.mfg_settings s ON s.bus_id = o.bus_id
     WHERE o.qty_good + o.qty_scrap > o.qty * (1 + coalesce(s.allow_over_production_pct, 0) / 100)
       AND NOT EXISTS (SELECT 1 FROM mfg.mfg_audit_logs a
                        WHERE a.tenant_id = o.tenant_id AND a.entity_type = 'production_order' AND a.entity_id = o.id
                          AND a.reason IS NOT NULL);
    IF n > 0 THEN
        RAISE NOTICE '% Manufacturing order(s) reported beyond their over-production tolerance without an audited reason', n;
    END IF;

    -- A cancelled order consumed nothing.
    IF to_regclass('scm.scm_inventory_movements') IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM mfg.mfg_production_orders o
                     JOIN scm.scm_inventory_movements mv
                       ON mv.bus_id = o.bus_id AND mv.reference_type = 'mfg_production_order' AND mv.reference_id = o.id
                    WHERE o.status = 'cancelled' AND mv.kind = 'issue') THEN
            RAISE EXCEPTION 'a cancelled Manufacturing production order has material issued to it';
        END IF;
    END IF;
END $$;

COMMIT;
