-- =====================================================================================
-- Is the stock where it was meant to go?
--
-- Run against any environment. Every row this prints with a non-zero count is a breach;
-- all zeroes means the ledger agrees with itself.
--
--     psql "$DATABASE_URL" -f scripts/check_stock_placement.sql
--
-- What is deliberately NOT checked, and why:
--
--   msg_product_movements cannot be summed into a batch balance. It records both sides of
--   an internal move -- OUT of inventory and IN to the store are two rows for the same
--   units -- so a batch that has been moved around shows IN and OUT far exceeding what it
--   ever received. A check written that way reported 76 phantom breaches before the shape
--   of that table was understood. It is a per-location journal, not a balance.
--
--   A batch having been consumed (received > unplaced + placed) is NOT a breach either.
--   That is what a sale looks like: a sale reduces what a location holds and never touches
--   qty_remaining. Only the opposite direction is wrong, and it has its own check below.
-- =====================================================================================

\pset pager off
\echo === stock placement checks: every count should be 0 ===

-- Stock accounted for in more places than it was ever received into. This is the one that
-- means units exist that nobody bought, and the only direction of imbalance that is wrong.
SELECT 'stock from nowhere (placed + unplaced > received)' AS check, count(*) AS breaches
FROM (
    SELECT coalesce(pb.qty_received, 0)
         - (coalesce(pb.qty_remaining, 0) + coalesce(p.q, 0)) AS d
    FROM mystoreguard.msg_purchase_batches pb
    LEFT JOIN (SELECT purchase_batche_id, sum(qty) q
                 FROM mystoreguard.msg_batch_locations GROUP BY 1) p
           ON p.purchase_batche_id = pb.id
) x WHERE d < 0;

-- A store's headline quantity must equal the batches actually sitting in it. These are
-- written by different statements, so they can drift apart; when they do, the store screen
-- and the batch screen disagree and neither says which is right.
SELECT 'store quantity <> sum of its batch locations', count(*)
FROM mystoreguard.msg_store_products sp
FULL JOIN (
    SELECT bl.loc_id, pb.product_id, sum(bl.qty) q
    FROM mystoreguard.msg_batch_locations bl
    JOIN mystoreguard.msg_purchase_batches pb ON pb.id = bl.purchase_batche_id
    WHERE bl.location_type = 'STORE' GROUP BY 1, 2
) pl ON pl.loc_id = sp.loc_id AND pl.product_id = sp.product_id
WHERE coalesce(sp.current_qty, 0) <> coalesce(pl.q, 0);

SELECT 'warehouse quantity <> sum of its batch locations', count(*)
FROM mystoreguard.msg_warehouse_products wp
FULL JOIN (
    SELECT bl.loc_id, pb.product_id, sum(bl.qty) q
    FROM mystoreguard.msg_batch_locations bl
    JOIN mystoreguard.msg_purchase_batches pb ON pb.id = bl.purchase_batche_id
    WHERE bl.location_type = 'WAREHOUSE' GROUP BY 1, 2
) pl ON pl.loc_id = wp.loc_id AND pl.product_id = wp.product_id
WHERE coalesce(wp.current_qty, 0) <> coalesce(pl.q, 0);

-- Receiving a purchase order into INVENTORY must not place it anywhere. This is the one a
-- purchase order's destination actually promises, and the reason this file exists.
SELECT 'purchase stock placed although its order said INVENTORY', count(*)
FROM mystoreguard.msg_purchase_orders po
JOIN mystoreguard.msg_purchase_batches pb
  ON pb.delivery_id LIKE 'del_rec_%' AND pb.product_id IN (
       SELECT product_id FROM mystoreguard.msg_purchase_order_items
        WHERE purchase_order_id = po.id)
JOIN mystoreguard.msg_batch_locations bl ON bl.purchase_batche_id = pb.id
WHERE coalesce(po.destination, 'INVENTORY') = 'INVENTORY'
  AND pb.batch_type = 'PURCHASE';

SELECT 'negative quantity in a batch location', count(*)
  FROM mystoreguard.msg_batch_locations WHERE qty < 0;
SELECT 'negative unplaced quantity on a batch', count(*)
  FROM mystoreguard.msg_purchase_batches WHERE qty_remaining < 0;
SELECT 'negative quantity in a store', count(*)
  FROM mystoreguard.msg_store_products WHERE current_qty < 0;
SELECT 'negative quantity in a warehouse', count(*)
  FROM mystoreguard.msg_warehouse_products WHERE current_qty < 0;

-- Stock placed at a location that no longer exists is stock nobody can find.
SELECT 'batch location pointing at a location that does not exist', count(*)
FROM mystoreguard.msg_batch_locations bl
LEFT JOIN core_platform.cp_locations l
       ON l.id = bl.loc_id AND l.tenant_id = bl.tenant_id
WHERE l.id IS NULL;
