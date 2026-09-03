-- Unique index for product prices to ensure one price per product/type/target combination.
-- Uses COALESCE so NULL target_id collapses to the empty string for the uniqueness check.
-- EF Core Fluent API cannot express a functional index on COALESCE — applied as raw SQL.
--
-- Superseded once msg_product_prices carries a `channel`: a product may then hold one
-- GLOBAL price for the tills and another for the storefront, which this index forbids.
-- The replacement (idx_msg_product_prices_unique_channel) is created by
-- migrations/shared/20260830-01-mystoreguard-ecommerce.sql, which runs AFTER this file
-- on every deploy. Guarded on the column rather than dropped outright so a database that
-- has not reached that migration yet — a fresh one, mid-deploy — still gets the
-- uniqueness it has always had, and so an already-migrated one is not left dropping and
-- rebuilding the same index on every deploy.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'mystoreguard'
          AND table_name   = 'msg_product_prices'
          AND column_name  = 'channel'
    ) THEN
        CREATE UNIQUE INDEX IF NOT EXISTS idx_msg_product_prices_unique
        ON mystoreguard.msg_product_prices (tenant_id, org_id, bus_id, product_id, of_type, COALESCE(target_id, ''));
    END IF;
END $$;
