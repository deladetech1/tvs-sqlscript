-- Manufacturing: demand forecasts (design: docs/mfg/02-domain-model.md §3; contract R3.md D7, D8;
-- 05's R4 forecasts row, pulled forward).
--
--   mfg_forecast_versions   a forecast per plant: name, bucket week | month, start_on, buckets
--                           (1..52), method manual | moving_average | exp_smoothing with params
--                           {"window", "alpha"}; draft -> published -> archived. One published
--                           version per plant: publishing archives the previous one (partial
--                           unique index)
--   mfg_forecast_lines      per product and bucket: statistical_qty (generate), override_qty with
--                           its override_reason (required with an override), and qty = the
--                           override, else the statistical quantity (a stored generated column).
--                           MRP consumes published lines (D8; pegging top type mfg_forecast)
--
-- Product ids are cp_products ids, registered for merges in 20261031-21. The CHECK lists live in
-- 20261031-19. No grants. Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS mfg.mfg_forecast_versions (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    plant_id          text NOT NULL REFERENCES mfg.mfg_plants (id),
    name              text NOT NULL,
    bucket            text NOT NULL DEFAULT 'week',     -- week | month
    start_on          date NOT NULL,                    -- the first bucket's start
    buckets           integer NOT NULL DEFAULT 12,
    method            text NOT NULL DEFAULT 'manual',   -- manual | moving_average | exp_smoothing
    params            jsonb NOT NULL DEFAULT '{}',      -- {"window", "alpha", "history_buckets"}
    status            text NOT NULL DEFAULT 'draft',
    copied_from_id    text REFERENCES mfg.mfg_forecast_versions (id),
    generated_at      timestamptz,
    generated_by      text,
    published_at      timestamptz,
    published_by      text,
    archived_at       timestamptz,
    notes             text,
    version           integer NOT NULL DEFAULT 1,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text
);
-- One published forecast per plant.
CREATE UNIQUE INDEX IF NOT EXISTS mfg_forecast_versions_published_uq
    ON mfg.mfg_forecast_versions (bus_id, plant_id) WHERE status = 'published';
CREATE INDEX IF NOT EXISTS mfg_forecast_versions_list_idx ON mfg.mfg_forecast_versions (bus_id, plant_id, status);
ALTER TABLE mfg.mfg_forecast_versions DROP CONSTRAINT IF EXISTS mfg_forecast_versions_rules_check;
ALTER TABLE mfg.mfg_forecast_versions ADD CONSTRAINT mfg_forecast_versions_rules_check
    CHECK (buckets BETWEEN 1 AND 52 AND jsonb_typeof(params) = 'object'
           AND (status <> 'published' OR published_at IS NOT NULL)
           AND (status <> 'archived' OR archived_at IS NOT NULL));

CREATE TABLE IF NOT EXISTS mfg.mfg_forecast_lines (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    forecast_id       text NOT NULL REFERENCES mfg.mfg_forecast_versions (id) ON DELETE CASCADE,
    plant_id          text NOT NULL,              -- the version's, for MRP's reads
    product_id        text NOT NULL,              -- cp_products.id
    bucket_start      date NOT NULL,
    bucket_end        date NOT NULL,              -- the last day of the bucket
    statistical_qty   numeric(18,6),
    override_qty      numeric(18,6),
    override_reason   text,
    qty               numeric(18,6) GENERATED ALWAYS AS (coalesce(override_qty, statistical_qty, 0)) STORED,
    unit              text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_forecast_lines_bucket_uq ON mfg.mfg_forecast_lines (forecast_id, product_id, bucket_start);
CREATE INDEX IF NOT EXISTS mfg_forecast_lines_product_idx ON mfg.mfg_forecast_lines (bus_id, plant_id, product_id, bucket_start);
ALTER TABLE mfg.mfg_forecast_lines DROP CONSTRAINT IF EXISTS mfg_forecast_lines_rules_check;
ALTER TABLE mfg.mfg_forecast_lines ADD CONSTRAINT mfg_forecast_lines_rules_check
    CHECK (bucket_end >= bucket_start
           AND (statistical_qty IS NULL OR statistical_qty >= 0)
           AND (override_qty IS NULL OR (override_qty >= 0 AND nullif(btrim(override_reason), '') IS NOT NULL)));

-- ===================================================================== invariants
DO $$
BEGIN
    -- One published forecast per plant (also the unique index; asserted so it can't be dropped quietly).
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'mfg' AND indexname = 'mfg_forecast_versions_published_uq') THEN
        RAISE EXCEPTION 'mfg.mfg_forecast_versions has no unique published version per plant';
    END IF;
END $$;

COMMIT;
