-- A delivery that never named a single item was never tracked.
--
-- 20260910-03 moved tracking onto the delivery and backfilled it with one
-- assumption:
--
--     "Every delivery of a product that was serialised was, by definition,
--      tracked."
--
-- That is not true, and the case it misses is the ordinary one. A product
-- becomes SERIALISED the moment ONE of its deliveries names its items — that is
-- what the product's flag means, a summary reading "some of this is named". Its
-- EARLIER deliveries, taken in as plain counts, were never tracked and have no
-- item rows at all. The backfill marked them tracked anyway.
--
-- The result is stock that cannot be sold. The shelf says seven phones; the
-- delivery claims each is individually recorded; there is not one item behind
-- them. Every screen that counts shows seven, and the till, which asks for
-- items, offers none. On dev this accounted for eighteen phones across three
-- deliveries — half of every tracked delivery in the database.
--
-- It also leaves the invariant in 20260910-03 already violated before anything
-- touches it: that check fires on writes, so nothing complained until somebody
-- tried to move or sell the stock, and then it refused.
--
-- The repair is to believe the items rather than the flag. A delivery with no
-- item rows is a count, whatever the backfill decided, and saying so makes the
-- shelf honest and the stock sellable again.
--
-- Nothing is invented here. A delivery whose items were all SOLD still HAS its
-- rows — that is the point of keeping them — so it is untouched. Only
-- deliveries that never had one are corrected.

UPDATE mystoreguard.msg_purchase_batches pb
   SET tracks_items = false
 WHERE pb.tracks_items
   AND NOT EXISTS (
       SELECT 1
         FROM mystoreguard.msg_product_units u
        WHERE u.batch_id = pb.id
          AND u.tenant_id = pb.tenant_id
   );

-- Idempotent by construction: run again and it matches nothing, because every
-- remaining tracked delivery now has at least one item to its name.
--
-- Deliberately NOT the other repair. Creating placeholder items to match the
-- shelf would invent serial numbers nobody ever wrote down, and a phone sold
-- against an invented IMEI is worse than a phone counted plainly.
