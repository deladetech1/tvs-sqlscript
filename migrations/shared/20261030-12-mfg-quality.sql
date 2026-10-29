-- Manufacturing: quality and recall (design: docs/mfg/03-database-model.md §3.5 Quality and
-- Traceability, §6; 02-domain-model.md §6, §7; contract R2.md C6-C9, R-8).
--
--   mfg_inspection_plans            what to inspect for a product (and revision) at a point:
--                                   receipt | in_process (at an operation) | final | periodic, with
--                                   its sampling. Revisioned: draft -> in_review -> released ->
--                                   superseded | obsolete; a released plan is FROZEN
--   mfg_inspection_characteristics  what is measured: variable (nominal, limits, unit) | attribute
--                                   (pass/fail) | count (defects). Frozen with the plan
--   mfg_inspections                 one inspection of a lot, serial, order or receipt line against a
--                                   plan revision: open -> in_progress -> passed | failed | waived.
--                                   C7's triggers create them: a Manufacturing receipt of an item
--                                   with a receipt plan, an operation's final confirmation at an
--                                   inspection point, the last operation's output lot (final plan),
--                                   and SCM receipts read by the mfg-quality-intake reader
--                                   (source_event_id keeps that reader idempotent)
--   mfg_inspection_results          APPEND-ONLY; every measured value, by whom, when, with which
--                                   gauge. A correction is a new row naming the one it supersedes.
--                                   Partitioned by month of measured_at (03 §6)
--   mfg_holds                       a hold on a lot, serial, order or supplier: active -> released.
--                                   The lot's scm_lots.quality_status is set only through
--                                   platform/stock SetLotQualityStatus (C6); releasing a hold sets
--                                   it back to available only when no other active hold covers it
--   mfg_ncrs / mfg_ncr_lines        ONE non-conformance record (R-8): open -> contained ->
--                                   dispositioned -> closed. Each line is a quantity of a lot or
--                                   serial with its disposition; executing it posts the stock itself
--                                   (C8) and keeps the movement ids, the rework order or the ECO
--   mfg_capas / mfg_capa_steps /    CAPA or 8D with its current D1-D8 discipline and root cause; one
--   mfg_capa_actions                step row per discipline (owner, due date, notes, open | done)
--                                   and its actions; NCRs link to it by mfg_ncrs.capa_id
--   mfg_recall_runs                 APPEND-ONLY; a recall snapshot (C9, 03 §3.5 Traceability): the
--                                   root, the direction, the lots, orders, receipts, shipments and
--                                   customers found, and the holds placed, so a recall is
--                                   reproducible; mfg_recall_lots (append-only) are the lots the
--                                   person confirmed and the hold placed on each. Traceability itself needs no other table: it
--                                   reads mfg_genealogy_links, Manufacturing receipts (ledger
--                                   movements with reference_type mfg_stock_receipt) and, with SCM,
--                                   mfg.src_scm_receipt_lines / src_scm_shipment_lines (20261030-16)
--
-- Released plans use mfg.mfg_freeze_released() (20261029-40), header and characteristics; results
-- and recall runs use mfg.mfg_refuse_change(). The partitions of this month and the next three are
-- made by mfg.mfg_ensure_partitions.
--
-- Product and party ids are registered for merges in 20261030-20. The CHECK lists live in
-- 20261030-18. No grants. Idempotent; safe to re-run.

BEGIN;

-- ================================================================ inspection plans
CREATE TABLE IF NOT EXISTS mfg.mfg_inspection_plans (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    org_id             text,
    bus_id             text NOT NULL,
    plant_id           text REFERENCES mfg.mfg_plants (id),   -- NULL = every plant
    product_id         text NOT NULL,
    item_revision_id   text REFERENCES mfg.mfg_item_revisions (id),
    name               text,
    point              text NOT NULL,
    operation_seq      integer,                     -- in_process: the routing operation it applies at
    revision           text NOT NULL,
    status             text NOT NULL DEFAULT 'draft',
    sampling           text NOT NULL DEFAULT 'full',
    sample_n           integer,                     -- fixed_n
    sample_pct         numeric(6,3),                -- percent
    aql_level          text,                        -- aql: inspection level, e.g. II
    aql_value          numeric(8,4),                -- aql: the acceptable quality limit, e.g. 1.0
    skip_after         integer,                     -- skip_lot: skip after this many passes in a row
    period_days        integer,                     -- periodic
    effective_from     date,
    effective_to       date,
    eco_id             text,
    notes              text,
    idempotency_key    text,
    released_at        timestamptz,
    released_by        text,
    archived_at        timestamptz,
    version            integer NOT NULL DEFAULT 1,
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    created_by         text,
    updated_at         timestamptz NOT NULL DEFAULT now(),
    updated_by         text
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_inspection_plans_revision_uq
    ON mfg.mfg_inspection_plans (bus_id, product_id, point, coalesce(operation_seq, 0), coalesce(plant_id, ''), revision);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_inspection_plans_idempotency_uq
    ON mfg.mfg_inspection_plans (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS mfg_inspection_plans_lookup_idx ON mfg.mfg_inspection_plans (bus_id, product_id, point, status);
ALTER TABLE mfg.mfg_inspection_plans DROP CONSTRAINT IF EXISTS mfg_inspection_plans_numbers_check;
ALTER TABLE mfg.mfg_inspection_plans ADD CONSTRAINT mfg_inspection_plans_numbers_check
    CHECK ((sample_n IS NULL OR sample_n > 0) AND (sample_pct IS NULL OR (sample_pct > 0 AND sample_pct <= 100))
           AND (skip_after IS NULL OR skip_after > 0) AND (period_days IS NULL OR period_days > 0)
           AND (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from)
           -- an in-process plan names its operation; the other points do not
           AND (point = 'in_process') = (operation_seq IS NOT NULL));

CREATE TABLE IF NOT EXISTS mfg.mfg_inspection_characteristics (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    org_id        text,
    bus_id        text NOT NULL,
    plan_id       text NOT NULL REFERENCES mfg.mfg_inspection_plans (id) ON DELETE CASCADE,
    position      integer NOT NULL,
    name          text NOT NULL,
    type          text NOT NULL,
    nominal       numeric(18,6),                -- variable
    lower_limit   numeric(18,6),                -- variable (03's "lower")
    upper_limit   numeric(18,6),                -- variable (03's "upper")
    unit          text,
    max_defects   integer,                      -- count: the most defects that still pass
    method        text,
    gauge         text,
    critical      boolean NOT NULL DEFAULT false,   -- a failure fails the whole inspection
    notes         text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text,
    updated_at    timestamptz NOT NULL DEFAULT now(),
    updated_by    text,
    UNIQUE (plan_id, position)
);
ALTER TABLE mfg.mfg_inspection_characteristics DROP CONSTRAINT IF EXISTS mfg_inspection_characteristics_limits_check;
ALTER TABLE mfg.mfg_inspection_characteristics ADD CONSTRAINT mfg_inspection_characteristics_limits_check
    CHECK ((lower_limit IS NULL OR upper_limit IS NULL OR lower_limit <= upper_limit) AND (max_defects IS NULL OR max_defects >= 0));

DROP TRIGGER IF EXISTS mfg_inspection_plans_freeze ON mfg.mfg_inspection_plans;
CREATE TRIGGER mfg_inspection_plans_freeze BEFORE UPDATE OR DELETE ON mfg.mfg_inspection_plans
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_freeze_released();
DROP TRIGGER IF EXISTS mfg_inspection_characteristics_freeze ON mfg.mfg_inspection_characteristics;
CREATE TRIGGER mfg_inspection_characteristics_freeze BEFORE INSERT OR UPDATE OR DELETE ON mfg.mfg_inspection_characteristics
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_freeze_released('mfg.mfg_inspection_plans', 'plan_id');

-- ===================================================================== inspections
CREATE TABLE IF NOT EXISTS mfg.mfg_inspections (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    plant_id          text REFERENCES mfg.mfg_plants (id),
    number            text NOT NULL,                 -- QI-00042 (mfg_number_series kind inspection)
    plan_id           text NOT NULL REFERENCES mfg.mfg_inspection_plans (id),
    point             text NOT NULL,                 -- the plan's point, copied for lists
    trigger           text NOT NULL,
    product_id        text NOT NULL,
    lot_id            text,                          -- scm.scm_lots id
    serial_id         text,                          -- scm.scm_serials id
    order_id          text REFERENCES mfg.mfg_production_orders (id),
    operation_id      text REFERENCES mfg.mfg_order_operations (id),
    receipt_type      text,                          -- mfg_stock_receipt | scm_receipt
    receipt_id        text,                          -- the Manufacturing receipt id, or scm.scm_receipts id
    receipt_line_id   text,                          -- scm.scm_receipt_lines id, or the ledger movement id of a Manufacturing receipt
    qty               numeric(18,6),                 -- the quantity the inspection covers
    unit              text,
    sample_size       integer CHECK (sample_size IS NULL OR sample_size > 0),
    status            text NOT NULL DEFAULT 'open',
    decided_at        timestamptz,
    decided_by        text,
    decision_note     text,
    waive_reason      text,
    hold_id           text,                          -- the hold its failure placed
    ncr_id            text,                          -- the NCR raised from it
    source_event_id   text,                          -- the event the mfg-quality-intake reader made it from
    idempotency_key   text,
    version           integer NOT NULL DEFAULT 1,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text,
    UNIQUE (bus_id, number)
);
CREATE INDEX IF NOT EXISTS mfg_inspections_list_idx ON mfg.mfg_inspections (bus_id, plant_id, status, cdatetime DESC);
CREATE INDEX IF NOT EXISTS mfg_inspections_lot_idx ON mfg.mfg_inspections (bus_id, lot_id) WHERE lot_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS mfg_inspections_order_idx ON mfg.mfg_inspections (order_id) WHERE order_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS mfg_inspections_source_event_uq
    ON mfg.mfg_inspections (bus_id, source_event_id) WHERE source_event_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS mfg_inspections_idempotency_uq
    ON mfg.mfg_inspections (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
ALTER TABLE mfg.mfg_inspections DROP CONSTRAINT IF EXISTS mfg_inspections_decided_check;
ALTER TABLE mfg.mfg_inspections ADD CONSTRAINT mfg_inspections_decided_check
    CHECK ((status IN ('passed', 'failed', 'waived')) = (decided_at IS NOT NULL)
           AND (status <> 'waived' OR waive_reason IS NOT NULL));

CREATE TABLE IF NOT EXISTS mfg.mfg_inspection_results (
    id                 text NOT NULL DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    org_id             text,
    bus_id             text NOT NULL,
    inspection_id      text NOT NULL,
    characteristic_id  text NOT NULL,
    sample_no          integer NOT NULL DEFAULT 1 CHECK (sample_no > 0),
    value_num          numeric(18,6),                -- variable
    value_bool         boolean,                      -- attribute: true = pass
    defects            integer CHECK (defects IS NULL OR defects >= 0),   -- count
    result             text NOT NULL,                -- pass | fail, judged by the API against the characteristic
    note               text,
    gauge              text,
    supersedes_id      text,                         -- a correction names the result it replaces
    measured_at        timestamptz NOT NULL,         -- when it was measured (offline-safe)
    recorded_at        timestamptz NOT NULL DEFAULT now(),
    actor              text NOT NULL,
    device_id          text,
    idempotency_key    text,
    PRIMARY KEY (id, measured_at)
) PARTITION BY RANGE (measured_at);
SELECT mfg.mfg_ensure_partitions('mfg_inspection_results', 3);
CREATE INDEX IF NOT EXISTS mfg_inspection_results_inspection_idx
    ON mfg.mfg_inspection_results (inspection_id, characteristic_id, sample_no, measured_at);
CREATE INDEX IF NOT EXISTS mfg_inspection_results_key_idx
    ON mfg.mfg_inspection_results (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;

DROP TRIGGER IF EXISTS mfg_inspection_results_append_only ON mfg.mfg_inspection_results;
CREATE TRIGGER mfg_inspection_results_append_only BEFORE UPDATE OR DELETE ON mfg.mfg_inspection_results
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_refuse_change();

-- =========================================================================== holds
CREATE TABLE IF NOT EXISTS mfg.mfg_holds (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    org_id             text,
    bus_id             text NOT NULL,
    plant_id           text REFERENCES mfg.mfg_plants (id),
    subject_type       text NOT NULL,                -- lot | serial | order | supplier
    subject_id         text NOT NULL,                -- scm_lots / scm_serials / mfg_production_orders / cp_parties id
    product_id         text,                         -- the lot's, serial's or order's product, for lists
    reason             text NOT NULL,
    source             text NOT NULL DEFAULT 'manual',   -- manual | inspection | ncr | recall
    inspection_id      text,
    ncr_id             text,
    recall_id          text,                         -- mfg_recall_runs id
    status             text NOT NULL DEFAULT 'active',
    placed_at          timestamptz NOT NULL DEFAULT now(),
    placed_by          text,
    released_at        timestamptz,
    released_by        text,
    release_decision   text,                         -- why it was released (the API's decision)
    idempotency_key    text,
    version            integer NOT NULL DEFAULT 1,
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    created_by         text,
    updated_at         timestamptz NOT NULL DEFAULT now(),
    updated_by         text
);
CREATE INDEX IF NOT EXISTS mfg_holds_subject_idx ON mfg.mfg_holds (bus_id, subject_type, subject_id) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS mfg_holds_list_idx ON mfg.mfg_holds (bus_id, status, placed_at DESC);
-- One active hold per subject per cause, so a repeated recall or inspection failure adds nothing.
CREATE UNIQUE INDEX IF NOT EXISTS mfg_holds_active_uq
    ON mfg.mfg_holds (bus_id, subject_type, subject_id, source, coalesce(inspection_id, ncr_id, recall_id, ''))
    WHERE status = 'active';
CREATE UNIQUE INDEX IF NOT EXISTS mfg_holds_idempotency_uq
    ON mfg.mfg_holds (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
ALTER TABLE mfg.mfg_holds DROP CONSTRAINT IF EXISTS mfg_holds_released_check;
ALTER TABLE mfg.mfg_holds ADD CONSTRAINT mfg_holds_released_check
    CHECK ((status = 'released') = (released_at IS NOT NULL));

-- ============================================================================ NCRs
CREATE TABLE IF NOT EXISTS mfg.mfg_ncrs (
    id                     text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text NOT NULL,
    org_id                 text,
    bus_id                 text NOT NULL,
    plant_id               text REFERENCES mfg.mfg_plants (id),
    number                 text NOT NULL,             -- NCR-00042 (mfg_number_series kind ncr)
    source                 text NOT NULL,
    source_type            text,                      -- inspection | floor_request | ...
    source_id              text,
    title                  text NOT NULL,
    description            text,
    product_id             text NOT NULL,
    party_id               text,                      -- the supplier or customer concerned (cp_parties.id)
    order_id               text REFERENCES mfg.mfg_production_orders (id),
    severity               text NOT NULL DEFAULT 'minor',
    status                 text NOT NULL DEFAULT 'open',
    defect_codes           text[] NOT NULL DEFAULT '{}',
    qty_affected           numeric(18,6),
    unit                   text,
    containment            text,
    cost_of_poor_quality   numeric(14,2) NOT NULL DEFAULT 0,
    currency               text,
    capa_id                text,
    eco_id                 text,                      -- the draft ECO a needs_engineering_change line opened
    contained_at           timestamptz,
    contained_by           text,
    closed_at              timestamptz,
    closed_by              text,
    close_note             text,
    idempotency_key        text,
    version                integer NOT NULL DEFAULT 1,
    cdatetime              timestamptz NOT NULL DEFAULT now(),
    created_by             text,
    updated_at             timestamptz NOT NULL DEFAULT now(),
    updated_by             text,
    UNIQUE (bus_id, number)
);
CREATE INDEX IF NOT EXISTS mfg_ncrs_list_idx ON mfg.mfg_ncrs (bus_id, plant_id, status, cdatetime DESC);
CREATE INDEX IF NOT EXISTS mfg_ncrs_open_age_idx ON mfg.mfg_ncrs (bus_id, cdatetime) WHERE status <> 'closed';
CREATE INDEX IF NOT EXISTS mfg_ncrs_capa_idx ON mfg.mfg_ncrs (capa_id) WHERE capa_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS mfg_ncrs_idempotency_uq
    ON mfg.mfg_ncrs (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
ALTER TABLE mfg.mfg_ncrs DROP CONSTRAINT IF EXISTS mfg_ncrs_numbers_check;
ALTER TABLE mfg.mfg_ncrs ADD CONSTRAINT mfg_ncrs_numbers_check
    CHECK (cost_of_poor_quality >= 0 AND (qty_affected IS NULL OR qty_affected > 0)
           AND (status <> 'closed' OR closed_at IS NOT NULL));

CREATE TABLE IF NOT EXISTS mfg.mfg_ncr_lines (
    id                   text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id            text NOT NULL,
    org_id               text,
    bus_id               text NOT NULL,
    ncr_id               text NOT NULL REFERENCES mfg.mfg_ncrs (id) ON DELETE CASCADE,
    position             integer NOT NULL,
    lot_id               text,                       -- scm.scm_lots id
    serial_id            text,
    qty                  numeric(18,6) NOT NULL CHECK (qty > 0),
    unit                 text NOT NULL,
    defect_code          text,
    disposition          text,                       -- NULL until dispositioned
    disposition_qty      numeric(18,6),
    regrade_product_id   text,                       -- regrade: the product the stock moves into (cp_products.id)
    warehouse_id         text,                       -- where the stock is, for the movements
    rework_order_id      text REFERENCES mfg.mfg_production_orders (id),
    movement_ids         text[] NOT NULL DEFAULT '{}',   -- the ledger movements it posted
    return_ref           text,                       -- return_to_supplier: the SCM return id, or the note
    eco_id               text,                       -- needs_engineering_change: the draft ECO
    note                 text,
    done_at              timestamptz,
    done_by              text,
    idempotency_key      text,
    cdatetime            timestamptz NOT NULL DEFAULT now(),
    created_by           text,
    updated_at           timestamptz NOT NULL DEFAULT now(),
    updated_by           text,
    UNIQUE (ncr_id, position)
);
CREATE INDEX IF NOT EXISTS mfg_ncr_lines_lot_idx ON mfg.mfg_ncr_lines (bus_id, lot_id) WHERE lot_id IS NOT NULL;
ALTER TABLE mfg.mfg_ncr_lines DROP CONSTRAINT IF EXISTS mfg_ncr_lines_disposition_check;
ALTER TABLE mfg.mfg_ncr_lines ADD CONSTRAINT mfg_ncr_lines_disposition_check
    CHECK ((disposition_qty IS NULL OR (disposition_qty > 0 AND disposition_qty <= qty))
           AND (done_at IS NULL OR disposition IS NOT NULL)
           AND (disposition IS DISTINCT FROM 'regrade' OR regrade_product_id IS NOT NULL));

-- =========================================================================== CAPAs
CREATE TABLE IF NOT EXISTS mfg.mfg_capas (
    id                          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id                   text NOT NULL,
    org_id                      text,
    bus_id                      text NOT NULL,
    plant_id                    text REFERENCES mfg.mfg_plants (id),
    number                      text NOT NULL,         -- CAPA-00042 (mfg_number_series kind capa)
    kind                        text NOT NULL DEFAULT 'capa',
    title                       text NOT NULL,
    problem                     text,                  -- D2
    team                        jsonb NOT NULL DEFAULT '[]',   -- D1: [{user_id, role}]
    containment                 text,                  -- D3
    root_cause                  jsonb NOT NULL DEFAULT '{}',   -- D4: {"five_why": [...], "fishbone": {...}}
    discipline                  text NOT NULL DEFAULT 'D1',
    status                      text NOT NULL DEFAULT 'open',
    owner                       text,
    due_on                      date,
    effectiveness_verified_at   timestamptz,           -- D7
    effectiveness_verified_by   text,
    effectiveness_note          text,
    closed_at                   timestamptz,           -- D8
    closed_by                   text,
    close_note                  text,
    idempotency_key             text,
    version                     integer NOT NULL DEFAULT 1,
    cdatetime                   timestamptz NOT NULL DEFAULT now(),
    created_by                  text,
    updated_at                  timestamptz NOT NULL DEFAULT now(),
    updated_by                  text,
    UNIQUE (bus_id, number)
);
CREATE INDEX IF NOT EXISTS mfg_capas_list_idx ON mfg.mfg_capas (bus_id, status, cdatetime DESC);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_capas_idempotency_uq
    ON mfg.mfg_capas (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
ALTER TABLE mfg.mfg_capas DROP CONSTRAINT IF EXISTS mfg_capas_closed_check;
ALTER TABLE mfg.mfg_capas ADD CONSTRAINT mfg_capas_closed_check
    CHECK (status <> 'closed' OR (closed_at IS NOT NULL AND effectiveness_verified_at IS NOT NULL));

CREATE TABLE IF NOT EXISTS mfg.mfg_capa_steps (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    org_id        text,
    bus_id        text NOT NULL,
    capa_id       text NOT NULL REFERENCES mfg.mfg_capas (id) ON DELETE CASCADE,
    discipline    text NOT NULL,                  -- D1 .. D8
    owner         text,
    due_on        date,
    notes         text,
    status        text NOT NULL DEFAULT 'open',   -- open | done (the API's done flag)
    done_at       timestamptz,
    done_by       text,
    version       integer NOT NULL DEFAULT 1,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text,
    updated_at    timestamptz NOT NULL DEFAULT now(),
    updated_by    text,
    UNIQUE (capa_id, discipline),
    CHECK ((status = 'done') = (done_at IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS mfg.mfg_capa_actions (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    org_id        text,
    bus_id        text NOT NULL,
    capa_id       text NOT NULL REFERENCES mfg.mfg_capas (id) ON DELETE CASCADE,
    position      integer NOT NULL,
    kind          text NOT NULL,                  -- containment (D3) | corrective (D5-D6) | preventive (D7)
    description   text NOT NULL,
    owner         text,
    due_on        date,
    status        text NOT NULL DEFAULT 'open',
    done_at       timestamptz,
    done_by       text,
    note          text,
    version       integer NOT NULL DEFAULT 1,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text,
    updated_at    timestamptz NOT NULL DEFAULT now(),
    updated_by    text,
    UNIQUE (capa_id, position)
);
CREATE INDEX IF NOT EXISTS mfg_capa_actions_due_idx ON mfg.mfg_capa_actions (bus_id, status, due_on);

-- ===================================================================== recall runs
CREATE TABLE IF NOT EXISTS mfg.mfg_recall_runs (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    number           text NOT NULL,               -- RC-00042 (mfg_number_series kind recall)
    root_kind        text NOT NULL,               -- lot | serial
    root_id          text NOT NULL,
    direction        text NOT NULL,               -- forward | backward
    reason           text,
    query            jsonb NOT NULL DEFAULT '{}', -- the request as asked (depth, filters)
    result           jsonb NOT NULL DEFAULT '{}', -- {"lots", "serials", "orders", "receipts", "shipments", "customers", "suppliers"}
    counts           jsonb NOT NULL DEFAULT '{}',
    holds_placed     integer NOT NULL DEFAULT 0 CHECK (holds_placed >= 0),
    already_held     integer NOT NULL DEFAULT 0 CHECK (already_held >= 0),
    idempotency_key  text,
    actor            text NOT NULL,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_recall_runs_number_uq ON mfg.mfg_recall_runs (bus_id, number);
CREATE INDEX IF NOT EXISTS mfg_recall_runs_list_idx ON mfg.mfg_recall_runs (bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS mfg_recall_runs_root_idx ON mfg.mfg_recall_runs (bus_id, root_id);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_recall_runs_idempotency_uq
    ON mfg.mfg_recall_runs (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;

DROP TRIGGER IF EXISTS mfg_recall_runs_append_only ON mfg.mfg_recall_runs;
CREATE TRIGGER mfg_recall_runs_append_only BEFORE UPDATE OR DELETE ON mfg.mfg_recall_runs
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_refuse_change();

-- The lots a recall covered (exactly the confirmed snapshot) and the hold placed on each.
CREATE TABLE IF NOT EXISTS mfg.mfg_recall_lots (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    org_id         text,
    bus_id         text NOT NULL,
    recall_id      text NOT NULL REFERENCES mfg.mfg_recall_runs (id),
    lot_id         text NOT NULL,                -- scm.scm_lots id
    lot_number     text,
    product_id     text,
    qty_on_hand    numeric(18,6),                -- stock on hand when it was recalled
    hold_id        text,                         -- the hold placed; NULL when it was already held
    already_held   boolean NOT NULL DEFAULT false,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (recall_id, lot_id)
);
CREATE INDEX IF NOT EXISTS mfg_recall_lots_lot_idx ON mfg.mfg_recall_lots (bus_id, lot_id);

DROP TRIGGER IF EXISTS mfg_recall_lots_append_only ON mfg.mfg_recall_lots;
CREATE TRIGGER mfg_recall_lots_append_only BEFORE UPDATE OR DELETE ON mfg.mfg_recall_lots
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_refuse_change();

-- ===================================================================== invariants
DO $$
DECLARE
    t  text;
    m  date;
BEGIN
    -- The results table is partitioned and has this month's and next month's partitions (UTC).
    IF (SELECT relkind FROM pg_class WHERE oid = 'mfg.mfg_inspection_results'::regclass) <> 'p' THEN
        RAISE EXCEPTION 'mfg.mfg_inspection_results is not partitioned';
    END IF;
    FOREACH m IN ARRAY ARRAY[date_trunc('month', now() AT TIME ZONE 'UTC')::date,
                             (date_trunc('month', now() AT TIME ZONE 'UTC') + interval '1 month')::date] LOOP
        IF to_regclass(format('mfg.mfg_inspection_results_y%sm%s', to_char(m, 'YYYY'), to_char(m, 'MM'))) IS NULL THEN
            RAISE EXCEPTION 'mfg.mfg_inspection_results has no partition for %', to_char(m, 'YYYY-MM');
        END IF;
    END LOOP;

    -- Every append-only table has its refuse trigger on the parent.
    FOREACH t IN ARRAY ARRAY['mfg_inspection_results', 'mfg_recall_runs', 'mfg_recall_lots'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                        WHERE g.tgrelid = ('mfg.' || t)::regclass AND p.proname = 'mfg_refuse_change' AND NOT g.tgisinternal) THEN
            RAISE EXCEPTION 'mfg.% is not append-only: its mfg_refuse_change trigger is missing', t;
        END IF;
    END LOOP;

    -- A released inspection plan is frozen, and so are its characteristics.
    FOREACH t IN ARRAY ARRAY['mfg_inspection_plans', 'mfg_inspection_characteristics'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = ('mfg.' || t)::regclass AND tgname = t || '_freeze' AND NOT tgisinternal) THEN
            RAISE EXCEPTION 'mfg.% is not frozen on release: trigger %_freeze is missing', t, t;
        END IF;
    END LOOP;

    -- A released inspection plan has characteristics.
    IF EXISTS (SELECT 1 FROM mfg.mfg_inspection_plans ip WHERE ip.status = 'released'
                  AND NOT EXISTS (SELECT 1 FROM mfg.mfg_inspection_characteristics c WHERE c.plan_id = ip.id)) THEN
        RAISE EXCEPTION 'a released Manufacturing inspection plan has no characteristics';
    END IF;
END $$;

COMMIT;
