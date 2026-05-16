-- Unique index for product prices to ensure one price per product/type/target combination.
-- Uses COALESCE so NULL target_id collapses to the empty string for the uniqueness check.
-- EF Core Fluent API cannot express a functional index on COALESCE — applied as raw SQL.
CREATE UNIQUE INDEX IF NOT EXISTS idx_msg_product_prices_unique
ON mystoreguard.msg_product_prices (tenant_id, org_id, bus_id, product_id, of_type, COALESCE(target_id, ''));
