-- SCM: the reports hub (eighteen reports across inventory, purchasing and fulfilment).
--
--   indexes              for the reports that read documents by their own dates: purchase orders and
--                        sales orders by order date (spend, supplier performance, fill rate, sales by
--                        item), stock takes by the day they were posted (variances), returns by the
--                        day they were raised, and lots by expiry date (expiring lots).
--   features             scm.reports keeps its tier (ADVANCE) and its title; its description, which
--                        Core Platform's plan comparison shows customers, now names what the hub
--                        holds. 20261026-09 wrote the first one; this file runs after it on every
--                        deploy, so this text is the one that stays.
--
-- No table or column changes: every report reads what SCM already records. Idempotent; safe to
-- re-run on every deploy.

BEGIN;

CREATE INDEX IF NOT EXISTS scm_purchase_orders_order_date_idx ON scm.scm_purchase_orders (bus_id, order_date);
CREATE INDEX IF NOT EXISTS scm_sales_orders_order_date_idx ON scm.scm_sales_orders (bus_id, order_date);
CREATE INDEX IF NOT EXISTS scm_stock_counts_posted_idx ON scm.scm_stock_counts (bus_id, posted_at) WHERE status = 'posted';
CREATE INDEX IF NOT EXISTS scm_returns_raised_idx ON scm.scm_returns (bus_id, cdatetime);
CREATE INDEX IF NOT EXISTS scm_lots_expiry_idx ON scm.scm_lots (bus_id, expiry_date) WHERE expiry_date IS NOT NULL;

INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('scm.reports', 'app-scm', 'Reports', 2,
 'Eighteen reports with charts, print and filters: stock value, ageing, slow and dead stock, reorder, movements, stock-take variances, expiring lots and ABC; purchase spend, open orders, supplier on-time and in-full, and price variance; fill rate, sales by item, shipping on time, backorders and returns by reason')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

DO $$
BEGIN
    IF (SELECT min_tier_rank FROM core_platform.cp_app_feature_catalog WHERE feature_key = 'scm.reports') <> 2 THEN
        RAISE EXCEPTION 'scm.reports is not an ADVANCE feature';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_app_feature_catalog WHERE feature_key = 'scm.reports' AND btrim(coalesce(description, '')) = '') THEN
        RAISE EXCEPTION 'scm.reports has no customer-facing description';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'scm' AND indexname = 'scm_stock_counts_posted_idx') THEN
        RAISE EXCEPTION 'scm_stock_counts_posted_idx is missing';
    END IF;
END $$;

COMMIT;
