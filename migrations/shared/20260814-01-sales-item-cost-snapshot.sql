-- =====================================================================
-- Cost of goods on the sale line
-- ---------------------------------------------------------------------
-- A sale records five selling prices per line and nothing about what the
-- goods cost, so margin cannot be reported without going back to the
-- batches. cost_price on msg_purchase_batches is live and editable, so
-- reading it after the fact prices old sales at today's cost — the same
-- reason estimates freeze their template and sale lines freeze their
-- taxes.
--
-- These columns freeze it on the line instead:
--
--   cost_price        weighted unit cost across the batches the line drew
--                     from. Display figure.
--   line_cost         total cost for the line. AUTHORITATIVE for COGS —
--                     summed from the unrounded per-batch costs, so it is
--                     not always cost_price * quantity.
--   cost_currency_id  the batch's currency, which need not be the sale's.
--   cost_source       SNAPSHOT — written at sale time from the allocation
--                     actually deducted. Exact.
--                     BACKFILL — reconstructed below from stock movements.
--                     Uses today's batch cost, so it is an estimate.
--                     NULL   — no cost is known for this line.
--
-- Reports MUST read cost_source rather than treating every non-null cost
-- as measured; mixing an exact quarter with an estimated one silently is
-- worse than showing nothing for the estimated one.
--
-- Runs after the EF migrations on every deploy. Idempotent; safe to re-run.
-- =====================================================================

ALTER TABLE mystoreguard.msg_sales_items
    ADD COLUMN IF NOT EXISTS cost_price       numeric(18,2),
    ADD COLUMN IF NOT EXISTS line_cost        numeric(18,2),
    ADD COLUMN IF NOT EXISTS cost_currency_id text,
    ADD COLUMN IF NOT EXISTS cost_source      text;

ALTER TABLE mystoreguard.msg_sales_items
    DROP CONSTRAINT IF EXISTS ck_msg_sales_items_cost_source;

ALTER TABLE mystoreguard.msg_sales_items
    ADD CONSTRAINT ck_msg_sales_items_cost_source
    CHECK (cost_source IS NULL OR cost_source IN ('SNAPSHOT', 'BACKFILL'));


-- ---------------------------------------------------------------------
-- Backfill for sales taken before the snapshot existed.
--
-- The cost cannot come from msg_sales_items.batch_id: that column holds
-- only the FIRST batch a line drew from, so a line filled from three
-- batches at different costs would be priced entirely at the first one.
-- msg_product_movements carries the real per-batch split — one row per
-- allocation, reference_id = sale_id — so the weighted cost is
-- recoverable from there.
--
-- movement_type = 'OUT' AND reason LIKE 'SALE%' is the same predicate the
-- cancel path uses to find a sale's outbound movements. It covers both
-- 'SALE' (create) and 'SALE_UPDATE' (items added on an edit), and the
-- OUT filter excludes the 'SALE_CANCELLED' reversals, which are IN.
-- A cancelled sale still gets its cost: it did cost that at the time, and
-- the reports already leave cancelled sales out of takings.
--
-- Uses the (tenant_id, org_id, bus_id, reference_id, product_id) index on
-- msg_product_movements added by 20260811-01.
--
-- Three lines are deliberately left NULL rather than guessed at:
--   * no movements        — a parked or part-paid sale never allocated a
--                           batch, so no cost exists to recover
--   * a null batch cost   — nothing to weight
--   * mixed cost currency — one line, two currencies, no single figure
--
-- And one is left NULL because it cannot be attributed: movements key on
-- (sale_id, product_id), not on the sale-item id, so where one product
-- appears on two lines of the same sale there is no way to say which line
-- took which batch.
--
-- Re-runnable: only ever fills rows where cost_price IS NULL, so a
-- SNAPSHOT written by the app is never overwritten by an estimate.
-- ---------------------------------------------------------------------

WITH line_cost AS (
    SELECT m.tenant_id,
           m.org_id,
           m.bus_id,
           m.reference_id AS sale_id,
           m.product_id,
           SUM(m.qty * pb.cost_price) / NULLIF(SUM(m.qty), 0) AS unit_cost,
           SUM(m.qty * pb.cost_price)                         AS total_cost,
           MIN(pb.currency_id)                                AS currency_id,
           COUNT(DISTINCT pb.currency_id)                     AS currencies,
           COUNT(*) FILTER (WHERE pb.cost_price IS NULL)      AS missing_cost
    FROM mystoreguard.msg_product_movements m
    JOIN mystoreguard.msg_purchase_batches pb
      ON pb.id        = m.batch_id
     AND pb.tenant_id = m.tenant_id
     AND pb.org_id    = m.org_id
     AND pb.bus_id    = m.bus_id
    WHERE m.movement_type = 'OUT'
      AND m.reason LIKE 'SALE%'
    GROUP BY 1, 2, 3, 4, 5
)
UPDATE mystoreguard.msg_sales_items si
SET cost_price       = ROUND(lc.unit_cost, 2),
    line_cost        = ROUND(lc.total_cost, 2),
    cost_currency_id = lc.currency_id,
    cost_source      = 'BACKFILL'
FROM line_cost lc
WHERE lc.tenant_id    = si.tenant_id
  AND lc.org_id       = si.org_id
  AND lc.bus_id       = si.bus_id
  AND lc.sale_id      = si.sale_id
  AND lc.product_id   = si.product_id
  AND si.cost_price   IS NULL
  AND lc.missing_cost = 0
  AND lc.currencies   = 1
  AND (SELECT COUNT(*)
       FROM mystoreguard.msg_sales_items d
       WHERE d.tenant_id  = si.tenant_id
         AND d.org_id     = si.org_id
         AND d.bus_id     = si.bus_id
         AND d.sale_id    = si.sale_id
         AND d.product_id = si.product_id) = 1;
