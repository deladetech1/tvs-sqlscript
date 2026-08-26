-- =====================================================================
-- Where a purchase order's stock is going
-- ---------------------------------------------------------------------
-- Receiving a purchase order has always created a purchase batch and left
-- the goods unallocated, under Inventory > Products, for someone to push
-- out to a shop or a warehouse afterwards. That is the right default - you
-- do not always know where stock is headed when you order it - but it is a
-- second job every time, and for a shop that orders straight to its floor
-- it is the same second job forever.
--
-- The destination is therefore recorded on the ORDER, and honoured when it
-- is received:
--
--   INVENTORY  (default)  the batch stays unallocated, exactly as today
--   STORE                 allocated to destination_loc_id's store shelf
--   WAREHOUSE             allocated to destination_loc_id's warehouse
--
-- A location is not itself a store or a warehouse - core_platform locations
-- carry only a name - so which of the two a location is acting as is the
-- destination's job to say, and the pair is only meaningful together. Hence
-- one column for the kind and one for the place, with a constraint tying
-- them: a location is required for STORE and WAREHOUSE, and meaningless for
-- INVENTORY.
--
-- Existing rows get INVENTORY, which is what they already did.
--
-- Idempotent; safe to re-run on every deploy.
-- =====================================================================

SET search_path TO mystoreguard;

ALTER TABLE mystoreguard.msg_purchase_orders
    ADD COLUMN IF NOT EXISTS destination        text NOT NULL DEFAULT 'INVENTORY',
    ADD COLUMN IF NOT EXISTS destination_loc_id text;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'msg_purchase_orders_destination_check'
    ) THEN
        ALTER TABLE mystoreguard.msg_purchase_orders
            ADD CONSTRAINT msg_purchase_orders_destination_check
            CHECK (
                (destination = 'INVENTORY' AND destination_loc_id IS NULL)
                OR (destination IN ('STORE', 'WAREHOUSE')
                    AND destination_loc_id IS NOT NULL)
            );
    END IF;
END $$;

COMMENT ON COLUMN mystoreguard.msg_purchase_orders.destination IS
    'INVENTORY (unallocated, the default) | STORE | WAREHOUSE - honoured when the order is received.';
COMMENT ON COLUMN mystoreguard.msg_purchase_orders.destination_loc_id IS
    'Which location the stock goes to. Required for STORE and WAREHOUSE, null for INVENTORY.';
