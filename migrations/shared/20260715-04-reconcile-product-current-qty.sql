-- 20260715-04-reconcile-product-current-qty.sql
-- One-time (idempotent) reconciliation of the denormalized current_qty caches.
--
-- msg_store_products.current_qty and msg_warehouse_products.current_qty are caches of the
-- true on-hand stock, which lives in msg_batch_locations (per batch, per location). Sales
-- and other flows decrement the cache separately from the batch truth, so it can drift --
-- in one case a store product ended up at current_qty = -1, which crashes the read API
-- (the DTO enforces current_qty >= 0).
--
-- This migration resets each product's current_qty to the SUM of its backing
-- msg_batch_locations.qty (the source of truth). batch_locations has no product_id, so we
-- map back to the product via purchase_batche_id -> msg_purchase_batches.product_id.
-- Products with no backing batch-locations are forced to 0.
--
-- Idempotent by nature (re-running lands on the same computed sum). Safe to re-run on every deploy.

-- ============================================================================
-- STORE products
-- ============================================================================
UPDATE mystoreguard.msg_store_products sp
SET current_qty = COALESCE(t.total, 0)
FROM (
    SELECT bl.tenant_id, bl.org_id, bl.bus_id, bl.loc_id,
           pb.product_id, SUM(bl.qty) AS total
    FROM mystoreguard.msg_batch_locations bl
    JOIN mystoreguard.msg_purchase_batches pb
      ON pb.id = bl.purchase_batche_id
     AND pb.tenant_id = bl.tenant_id
     AND pb.org_id = bl.org_id
     AND pb.bus_id = bl.bus_id
    WHERE bl.location_type = 'STORE'
    GROUP BY bl.tenant_id, bl.org_id, bl.bus_id, bl.loc_id, pb.product_id
) t
WHERE sp.tenant_id   = t.tenant_id
  AND sp.org_id      = t.org_id
  AND sp.bus_id      = t.bus_id
  AND sp.loc_id      = t.loc_id
  AND sp.product_id  = t.product_id
  AND sp.delete_status = 'NOT_DELETED'
  AND sp.current_qty IS DISTINCT FROM COALESCE(t.total, 0);

-- Store products with NO backing STORE batch-locations at all -> force to 0
UPDATE mystoreguard.msg_store_products sp
SET current_qty = 0
WHERE sp.delete_status = 'NOT_DELETED'
  AND sp.current_qty <> 0
  AND NOT EXISTS (
      SELECT 1
      FROM mystoreguard.msg_batch_locations bl
      JOIN mystoreguard.msg_purchase_batches pb
        ON pb.id = bl.purchase_batche_id
       AND pb.tenant_id = bl.tenant_id
       AND pb.org_id = bl.org_id
       AND pb.bus_id = bl.bus_id
      WHERE bl.location_type = 'STORE'
        AND bl.tenant_id = sp.tenant_id
        AND bl.org_id = sp.org_id
        AND bl.bus_id = sp.bus_id
        AND bl.loc_id = sp.loc_id
        AND pb.product_id = sp.product_id
  );

-- ============================================================================
-- WAREHOUSE products
-- ============================================================================
UPDATE mystoreguard.msg_warehouse_products wp
SET current_qty = COALESCE(t.total, 0)
FROM (
    SELECT bl.tenant_id, bl.org_id, bl.bus_id, bl.loc_id,
           pb.product_id, SUM(bl.qty) AS total
    FROM mystoreguard.msg_batch_locations bl
    JOIN mystoreguard.msg_purchase_batches pb
      ON pb.id = bl.purchase_batche_id
     AND pb.tenant_id = bl.tenant_id
     AND pb.org_id = bl.org_id
     AND pb.bus_id = bl.bus_id
    WHERE bl.location_type = 'WAREHOUSE'
    GROUP BY bl.tenant_id, bl.org_id, bl.bus_id, bl.loc_id, pb.product_id
) t
WHERE wp.tenant_id   = t.tenant_id
  AND wp.org_id      = t.org_id
  AND wp.bus_id      = t.bus_id
  AND wp.loc_id      = t.loc_id
  AND wp.product_id  = t.product_id
  AND wp.delete_status = 'NOT_DELETED'
  AND wp.current_qty IS DISTINCT FROM COALESCE(t.total, 0);

-- Warehouse products with NO backing WAREHOUSE batch-locations at all -> force to 0
UPDATE mystoreguard.msg_warehouse_products wp
SET current_qty = 0
WHERE wp.delete_status = 'NOT_DELETED'
  AND wp.current_qty <> 0
  AND NOT EXISTS (
      SELECT 1
      FROM mystoreguard.msg_batch_locations bl
      JOIN mystoreguard.msg_purchase_batches pb
        ON pb.id = bl.purchase_batche_id
       AND pb.tenant_id = bl.tenant_id
       AND pb.org_id = bl.org_id
       AND pb.bus_id = bl.bus_id
      WHERE bl.location_type = 'WAREHOUSE'
        AND bl.tenant_id = wp.tenant_id
        AND bl.org_id = wp.org_id
        AND bl.bus_id = wp.bus_id
        AND bl.loc_id = wp.loc_id
        AND pb.product_id = wp.product_id
  );
