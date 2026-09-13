-- What a purchase order line really costs, and what it was ordered in.
--
-- A purchase order line held a quantity and a unit cost and nothing else. Two
-- things a supplier invoice always has were therefore impossible to record:
--
--   DISCOUNT   the trade terms a shop negotiates. Ten percent off the case is
--              the whole reason for ordering by the case, and there was
--              nowhere to say it.
--
--   TAX        VAT and the levies on a Ghanaian invoice. The system has a full
--              tax engine, but it computes tax on what a shop SELLS. Nothing
--              recorded tax on what it BUYS, so an order's total never matched
--              the invoice that arrived with the goods.
--
-- Deliberately plain numbers rather than a link to msg_taxes. That table is
-- the shop's own selling tax; the rate on a supplier's invoice is the
-- supplier's, and pinning one to the other would make a change to the shop's
-- VAT setting silently rewrite what it once paid. A rate and an amount,
-- snapshotted, keep old orders true.
--
-- Note what this does NOT do: it does not touch the unit cost that reaches a
-- batch. Whether input tax belongs in the cost of stock depends on whether the
-- shop can reclaim it, and that is the shop's answer, not a schema's. The
-- receipt now carries its own cost_price for exactly this reason — see
-- PurchaseReceiptItemBase — so the person taking the goods in decides what the
-- stock actually cost, and this records what the supplier actually charged.

ALTER TABLE mystoreguard.msg_purchase_order_items
    ADD COLUMN IF NOT EXISTS discount_amount numeric(18,4);

COMMENT ON COLUMN mystoreguard.msg_purchase_order_items.discount_amount IS
    'Money off this LINE, in the order currency — not a percentage and not per '
    'unit, because that is how a supplier writes it. Null where none was given.';

ALTER TABLE mystoreguard.msg_purchase_order_items
    ADD COLUMN IF NOT EXISTS tax_rate numeric(9,4);

COMMENT ON COLUMN mystoreguard.msg_purchase_order_items.tax_rate IS
    'The percentage on the supplier''s invoice for this line — 15 means 15%. '
    'The supplier''s rate, snapshotted, not a link to the shop''s own tax '
    'settings: changing what a shop charges must not rewrite what it once paid.';

ALTER TABLE mystoreguard.msg_purchase_order_items
    ADD COLUMN IF NOT EXISTS tax_amount numeric(18,4);

COMMENT ON COLUMN mystoreguard.msg_purchase_order_items.tax_amount IS
    'The money that rate came to, worked out when the line was saved and kept. '
    'Stored rather than recomputed so an old order still adds up to what was '
    'actually agreed, whatever anybody edits afterwards.';

-- ---------------------------------------------------------------------------
-- Ordering in the words the shop buys in.
-- ---------------------------------------------------------------------------
-- A shop that buys water by the pallet had to order 1,500 bottles. The receipt
-- learned to take a packaging level; the order never did, so the two ends of
-- the same transaction spoke different languages.
--
-- Display only, exactly as on a batch: qty_ordered stays in base units and is
-- the only number anything calculates with.
ALTER TABLE mystoreguard.msg_purchase_order_items
    ADD COLUMN IF NOT EXISTS entered_unit text;

COMMENT ON COLUMN mystoreguard.msg_purchase_order_items.entered_unit IS
    'Which packaging level qty_ordered was typed in, so the order can be read '
    'back as the "2 Pallets" somebody actually ordered. Never calculated with: '
    'qty_ordered is already in base units. Null means base units.';

-- A discount cannot be negative and a rate cannot be either; both would turn a
-- typo into money the shop never owed.
ALTER TABLE mystoreguard.msg_purchase_order_items
    DROP CONSTRAINT IF EXISTS ck_msg_po_items_charges_not_negative;
ALTER TABLE mystoreguard.msg_purchase_order_items
    ADD CONSTRAINT ck_msg_po_items_charges_not_negative
    CHECK (
        (discount_amount IS NULL OR discount_amount >= 0)
    AND (tax_rate        IS NULL OR tax_rate        >= 0)
    AND (tax_amount      IS NULL OR tax_amount      >= 0)
    );
