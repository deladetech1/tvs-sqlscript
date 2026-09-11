-- Items on a delivery that straddles both shelves of one branch.
--
-- 20260911-03 gave an item a shelf and backfilled it only where a delivery sat
-- on exactly ONE kind of shelf at a branch, because that is the only case where
-- the answer is not a guess.
--
-- That left the straddling case untouched, and it is the one a shop actually
-- hits: seven phones in the shop and one in the stockroom, all eight items
-- saying nothing about where they are. Reads treat "not recorded" as matching
-- either shelf — deliberately, so older stock keeps working — so BOTH screens
-- list all eight. The warehouse says one and shows eight.
--
-- This assigns as many items to each shelf as that shelf's quantity claims, so
-- the counts reconcile and each screen lists its own.
--
-- WHICH handset lands on which shelf is arbitrary here, and it has to be: the
-- transfer that split them predates the column, so nothing recorded it and
-- there is nothing to recover. The quantities are now right on both screens,
-- and a shop that knows a particular handset is really in the stockroom can say
-- so by transferring it — the transfer form can name individual items now, and
-- from here on every transfer records the shelf itself.
--
-- Only ever fills in a blank. An item that already says where it is keeps its
-- answer, so running this twice changes nothing the second time.

WITH straddling AS (
    -- Deliveries sitting on both shelves of one branch, and how many each holds.
    SELECT bl.purchase_batche_id, bl.loc_id, bl.location_type, bl.qty,
           bl.tenant_id
      FROM mystoreguard.msg_batch_locations bl
      JOIN mystoreguard.msg_purchase_batches pb
        ON pb.id = bl.purchase_batche_id AND pb.tenant_id = bl.tenant_id
     WHERE pb.tracks_items
       AND bl.qty > 0
       AND EXISTS (
           SELECT 1 FROM mystoreguard.msg_batch_locations other
            WHERE other.purchase_batche_id = bl.purchase_batche_id
              AND other.tenant_id = bl.tenant_id
              AND other.loc_id = bl.loc_id
              AND other.location_type <> bl.location_type
              AND other.qty > 0
       )
), shelves AS (
    -- Each shelf numbered, with a running total, so the Nth item can be told
    -- which shelf it falls on.
    SELECT s.*,
           COALESCE(SUM(s.qty) OVER (
               PARTITION BY s.tenant_id, s.purchase_batche_id, s.loc_id
               ORDER BY s.location_type
               ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0) AS starts_after
      FROM straddling s
), numbered AS (
    -- The items with no shelf recorded, in a stable order.
    SELECT u.id, u.batch_id, u.loc_id, u.tenant_id,
           ROW_NUMBER() OVER (
               PARTITION BY u.tenant_id, u.batch_id, u.loc_id
               ORDER BY u.cdatetime, u.id) AS n
      FROM mystoreguard.msg_product_units u
     WHERE u.location_type IS NULL
       AND u.loc_id IS NOT NULL
       AND u.status IN ('IN_STOCK', 'RETURNED', 'RESERVED')
)
UPDATE mystoreguard.msg_product_units u
   SET location_type = pick.location_type
  FROM (
      SELECT n.id, sh.location_type
        FROM numbered n
        JOIN shelves sh
          ON sh.purchase_batche_id = n.batch_id
         AND sh.loc_id = n.loc_id
         AND sh.tenant_id = n.tenant_id
         AND n.n > sh.starts_after
         AND n.n <= sh.starts_after + sh.qty
  ) pick
 WHERE u.id = pick.id
   AND u.location_type IS NULL;
