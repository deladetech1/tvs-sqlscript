-- Which arrival a batch came in on.
--
-- A delivery is one arrival: one supplier, one currency, one set of papers. What
-- was in it can disagree about everything else — thirty sealed 128GB at 100 and
-- two ex-display 1TB at 900 are one lorry and two prices — and a price is what a
-- batch carries, so each of those is its own batch.
--
-- That is right for money and wrong for the eye: the screens then showed two
-- rows for something the shop experienced as one delivery. This column is the
-- thread back, so a list can show the arrival and open it into what was in it,
-- while the till, FIFO and every profit figure carry on reading batches exactly
-- as they do today. Nothing is moved and nothing is merged; a grouping is added.
--
-- Deliberately NOT a table of its own. A delivery has no attribute that is not
-- already on its batches — supplier, currency, date and paperwork are identical
-- across them by construction — so a parent row would hold nothing but its own
-- id, and every read would pay a join to learn what it already had.

ALTER TABLE mystoreguard.msg_purchase_batches
    ADD COLUMN IF NOT EXISTS delivery_id text;

COMMENT ON COLUMN mystoreguard.msg_purchase_batches.delivery_id IS
    'The arrival this batch came in on. Batches sharing one are one delivery — '
    'same supplier, same currency, same paperwork — differing in cost, price, '
    'size or how their units are recorded. Null on batches taken in before the '
    'grouping existed, which are read as a delivery of one.';

-- Asked one way only: "everything that came in on this arrival", always within
-- a business.
CREATE INDEX IF NOT EXISTS ix_msg_purchase_batches_delivery
    ON mystoreguard.msg_purchase_batches (tenant_id, org_id, bus_id, delivery_id)
    WHERE delivery_id IS NOT NULL;

-- Every batch that already exists was its own arrival as far as anyone knows,
-- and saying so beats leaving a null the screens have to special-case. Batches
-- created together by one call cannot be recovered after the fact — the id is
-- assigned when the call runs — so this claims no grouping it cannot prove.
UPDATE mystoreguard.msg_purchase_batches
   SET delivery_id = 'del_' || id
 WHERE delivery_id IS NULL;
