-- A place set on a delivery is a bin, and is now recorded as one.
--
-- Two screens answered "where is this delivery" from two different records.
-- "Set place" wrote msg_batch_locations.place_id — where it lives, no numbers.
-- The bins editor wrote msg_batch_place_stock — how many in each bin. A shop
-- was shown both and they disagreed: the sale said "kept at Self B" while the
-- bins screen for the same delivery sat empty, and neither was lying.
--
-- A bin with no quantity already means exactly what a place-setting means —
-- "they are in here, nobody has counted" — so the older record is converted
-- into the newer one and there is nothing left to drift.
--
-- Deliveries that HAVE a counted breakdown are not touched: their place_id is
-- already derived from that breakdown, so there is nothing to reconcile.
--
-- Moves no stock. msg_batch_place_stock is detail about stock and never a
-- source of it; not one quantity anything counts is read or written here.

INSERT INTO mystoreguard.msg_batch_place_stock
    (id, tenant_id, org_id, bus_id, batch_location_id, place_id, qty,
     counted_at, created_by, cdatetime)
SELECT
    'bps_' || replace(gen_random_uuid()::text, '-', ''),
    bl.tenant_id, bl.org_id, bl.bus_id, bl.id, bl.place_id,
    NULL,                     -- in here, nobody has counted
    NULL,
    bl.placed_by,
    COALESCE(bl.placed_at, NOW())
  FROM mystoreguard.msg_batch_locations bl
  JOIN mystoreguard.msg_storage_places sp
    ON sp.id = bl.place_id AND sp.tenant_id = bl.tenant_id
   AND sp.delete_status = 'NOT_DELETED'
 WHERE bl.place_id IS NOT NULL
   AND NOT EXISTS (
        SELECT 1 FROM mystoreguard.msg_batch_place_stock bps
         WHERE bps.batch_location_id = bl.id
           AND bps.tenant_id = bl.tenant_id);

-- The history says where it came from, so "why does this bin exist" has an
-- answer a person can read.
INSERT INTO mystoreguard.msg_place_movements
    (id, tenant_id, org_id, bus_id, batch_location_id, to_place_id,
     movement_type, qty, note, created_by, cdatetime)
SELECT
    'plmv_' || replace(gen_random_uuid()::text, '-', ''),
    bps.tenant_id, bps.org_id, bps.bus_id, bps.batch_location_id, bps.place_id,
    'PLACED', NULL,
    'Place already set on this delivery, recorded as a bin',
    bps.created_by, bps.cdatetime
  FROM mystoreguard.msg_batch_place_stock bps
 WHERE bps.qty IS NULL
   AND NOT EXISTS (
        SELECT 1 FROM mystoreguard.msg_place_movements m
         WHERE m.batch_location_id = bps.batch_location_id
           AND m.tenant_id = bps.tenant_id);
