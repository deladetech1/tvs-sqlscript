-- Reconcile msg_store_products / msg_warehouse_products.current_qty with the shelf.
--
-- Until tvs-mystoreguard-bk 8a379b8 the shared transfer mover debited the STORE
-- table for every source, so a warehouse-to-store transfer within one branch
-- (they share loc_id) left the store total unchanged and the warehouse total
-- too high. The deliveries on the shelf (msg_batch_locations) are the authority;
-- this sets each stored total to their sum.
--
-- Re-runs on every deploy, so it only ever corrects a total that HAS shelf rows
-- behind it: a product whose stock was never recorded per delivery (older data)
-- keeps its stored total rather than being zeroed on each deploy. A database
-- without MyStoreGuard's tables skips it. Idempotent: a second run changes nothing.

DO $$
BEGIN
  IF to_regclass('mystoreguard.msg_batch_locations') IS NULL
     OR to_regclass('mystoreguard.msg_purchase_batches') IS NULL THEN
    RETURN;
  END IF;

  IF to_regclass('mystoreguard.msg_store_products') IS NOT NULL THEN
    UPDATE mystoreguard.msg_store_products sp
       SET current_qty = shelf.qty
      FROM (
            SELECT bl.tenant_id, bl.org_id, bl.bus_id, bl.loc_id, pb.product_id, SUM(bl.qty) AS qty
              FROM mystoreguard.msg_batch_locations bl
              JOIN mystoreguard.msg_purchase_batches pb
                ON pb.id = bl.purchase_batche_id AND pb.tenant_id = bl.tenant_id
             WHERE bl.location_type = 'STORE'
               AND pb.delete_status = 'NOT_DELETED' AND pb.status NOT IN ('VOID', 'CANCELLED')
             GROUP BY bl.tenant_id, bl.org_id, bl.bus_id, bl.loc_id, pb.product_id
           ) shelf
     WHERE shelf.tenant_id = sp.tenant_id AND shelf.org_id = sp.org_id AND shelf.bus_id = sp.bus_id
       AND shelf.loc_id = sp.loc_id AND shelf.product_id = sp.product_id
       AND sp.current_qty IS DISTINCT FROM shelf.qty;
  END IF;

  IF to_regclass('mystoreguard.msg_warehouse_products') IS NOT NULL THEN
    UPDATE mystoreguard.msg_warehouse_products wp
       SET current_qty = shelf.qty
      FROM (
            SELECT bl.tenant_id, bl.org_id, bl.bus_id, bl.loc_id, pb.product_id, SUM(bl.qty) AS qty
              FROM mystoreguard.msg_batch_locations bl
              JOIN mystoreguard.msg_purchase_batches pb
                ON pb.id = bl.purchase_batche_id AND pb.tenant_id = bl.tenant_id
             WHERE bl.location_type = 'WAREHOUSE'
               AND pb.delete_status = 'NOT_DELETED' AND pb.status NOT IN ('VOID', 'CANCELLED')
             GROUP BY bl.tenant_id, bl.org_id, bl.bus_id, bl.loc_id, pb.product_id
           ) shelf
     WHERE shelf.tenant_id = wp.tenant_id AND shelf.org_id = wp.org_id AND shelf.bus_id = wp.bus_id
       AND shelf.loc_id = wp.loc_id AND shelf.product_id = wp.product_id
       AND wp.current_qty IS DISTINCT FROM shelf.qty;
  END IF;
END $$;
