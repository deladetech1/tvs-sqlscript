-- Reconcile msg_store_products / msg_warehouse_products.current_qty with the shelf.
--
-- Until tvs-mystoreguard-bk 8a379b8 the shared transfer mover debited the STORE
-- table for every source, so a warehouse-to-store transfer within one branch
-- (they share loc_id) left the store total unchanged and the warehouse total
-- too high. The deliveries on the shelf (msg_batch_locations) are the authority;
-- this sets each stored total to their sum. Idempotent: a second run changes
-- nothing. Rows with no shelf stock go to 0.

UPDATE mystoreguard.msg_store_products sp
   SET current_qty = COALESCE(shelf.qty, 0)
  FROM (
        SELECT sp2.id, (
            SELECT SUM(bl.qty)
              FROM mystoreguard.msg_batch_locations bl
              JOIN mystoreguard.msg_purchase_batches pb
                ON pb.id = bl.purchase_batche_id AND pb.tenant_id = bl.tenant_id
             WHERE bl.tenant_id = sp2.tenant_id AND bl.org_id = sp2.org_id AND bl.bus_id = sp2.bus_id
               AND bl.loc_id = sp2.loc_id AND pb.product_id = sp2.product_id
               AND bl.location_type = 'STORE'
               AND pb.delete_status = 'NOT_DELETED' AND pb.status NOT IN ('VOID', 'CANCELLED')
        ) AS qty
          FROM mystoreguard.msg_store_products sp2
       ) shelf
 WHERE shelf.id = sp.id
   AND sp.current_qty IS DISTINCT FROM COALESCE(shelf.qty, 0);

UPDATE mystoreguard.msg_warehouse_products wp
   SET current_qty = COALESCE(shelf.qty, 0)
  FROM (
        SELECT wp2.id, (
            SELECT SUM(bl.qty)
              FROM mystoreguard.msg_batch_locations bl
              JOIN mystoreguard.msg_purchase_batches pb
                ON pb.id = bl.purchase_batche_id AND pb.tenant_id = bl.tenant_id
             WHERE bl.tenant_id = wp2.tenant_id AND bl.org_id = wp2.org_id AND bl.bus_id = wp2.bus_id
               AND bl.loc_id = wp2.loc_id AND pb.product_id = wp2.product_id
               AND bl.location_type = 'WAREHOUSE'
               AND pb.delete_status = 'NOT_DELETED' AND pb.status NOT IN ('VOID', 'CANCELLED')
        ) AS qty
          FROM mystoreguard.msg_warehouse_products wp2
       ) shelf
 WHERE shelf.id = wp.id
   AND wp.current_qty IS DISTINCT FROM COALESCE(shelf.qty, 0);
