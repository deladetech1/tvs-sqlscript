-- Manufacturing: the OEE day cache (design: docs/mfg/02-domain-model.md §12; contract R3.md D11).
--
--   mfg_oee_days   one row per business, resource, day (the plant's), shift, product and operator,
--                  for CLOSED days only: planned, run, down, planned-down and ideal minutes; good,
--                  scrap and rework counts (confirmations net of reversals on that resource); when
--                  it was computed. A row is recomputed when a confirmation or downtime row of its
--                  resource and day was recorded after computed_at. Open days are computed on read.
--                  Filled by the API and the nightly mfg-oee-rollup job; a cache, never a record
--
-- shift_id, item_id and operator_id are '' when the minutes or counts belong to no shift, product
-- or operator (downtime with no order, time outside every shift), so the key is one plain unique
-- index. The product is kept in item_id, deliberately NOT registered in cp_product_references, as
-- R2's derived planning state (20261030-11): a merge of two products would clash on the key, and a
-- deleted product's rows are dropped by the next recompute. The API returns item_id as product_id.
-- No CHECK list. No grants. Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS mfg.mfg_oee_days (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    plant_id          text NOT NULL,
    line_id           text,
    work_center_id    text NOT NULL,
    resource_id       text NOT NULL,
    day               date NOT NULL,              -- in the plant's timezone
    shift_id          text NOT NULL DEFAULT '',
    item_id           text NOT NULL DEFAULT '',   -- the product (cp_products.id); NOT registered, see above
    operator_id       text NOT NULL DEFAULT '',
    planned_min       numeric(14,3) NOT NULL DEFAULT 0,   -- shift minutes - calendar exceptions - planned downtime
    run_min           numeric(14,3) NOT NULL DEFAULT 0,   -- planned - other downtime
    down_min          numeric(14,3) NOT NULL DEFAULT 0,   -- downtime other than loss category planned
    planned_down_min  numeric(14,3) NOT NULL DEFAULT 0,
    ideal_min         numeric(14,3),                      -- ideal_cycle_sec x count; NULL without ideal_cycle_sec
    good_qty          numeric(18,6) NOT NULL DEFAULT 0,
    scrap_qty         numeric(18,6) NOT NULL DEFAULT 0,
    rework_qty        numeric(18,6) NOT NULL DEFAULT 0,
    computed_at       timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_oee_days_key_uq
    ON mfg.mfg_oee_days (bus_id, resource_id, day, shift_id, item_id, operator_id);
CREATE INDEX IF NOT EXISTS mfg_oee_days_plant_idx ON mfg.mfg_oee_days (bus_id, plant_id, day);
CREATE INDEX IF NOT EXISTS mfg_oee_days_work_center_idx ON mfg.mfg_oee_days (bus_id, work_center_id, day);
CREATE INDEX IF NOT EXISTS mfg_oee_days_line_idx ON mfg.mfg_oee_days (bus_id, line_id, day) WHERE line_id IS NOT NULL;
ALTER TABLE mfg.mfg_oee_days DROP CONSTRAINT IF EXISTS mfg_oee_days_rules_check;
ALTER TABLE mfg.mfg_oee_days ADD CONSTRAINT mfg_oee_days_rules_check
    CHECK (planned_min >= 0 AND run_min >= 0 AND down_min >= 0 AND planned_down_min >= 0
           AND (ideal_min IS NULL OR ideal_min >= 0));

-- ===================================================================== invariants
DO $$
BEGIN
    -- The cache keeps its product in item_id, unregistered (see above).
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'mfg' AND table_name = 'mfg_oee_days' AND column_name = 'product_id') THEN
        RAISE EXCEPTION 'mfg_oee_days must hold the product in item_id (20261031-14)';
    END IF;
END $$;

COMMIT;
