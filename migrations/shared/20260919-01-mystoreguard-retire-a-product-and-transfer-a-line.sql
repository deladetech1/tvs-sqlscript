-- Retiring a product, and transferring one delivery of it.
--
-- Two things a shop asked for, both about the same gap: the app knows what a
-- product IS but not what the shop still sells, and it knows a transfer moves
-- a quantity but not WHICH delivery moved.
--
-- 1. RETIRED
--
-- A shop stops selling something. It cannot be deleted — it is all over last
-- year's sales, and deleting it would take the history with it — so it stays,
-- and goes on demanding attention: it sits in the store list, in the warehouse
-- list, in inventory, and its reorder level keeps raising low-stock alerts for
-- something nobody intends to buy again.
--
-- So a product can be retired. Retired is not deleted and not inactive: it is
-- "we have stopped selling this". It hides from the store, the warehouse and
-- inventory, and stops alerting. It stays in every sale, return and report it
-- was ever part of, and it can be brought back.
--
-- Recorded as a moment rather than a flag, with who and why, because "when did
-- we stop selling this" is the question asked afterwards and a boolean cannot
-- answer it. retired_at IS NULL means it is still sold.
--
-- 2. WHICH DELIVERY MOVED
--
-- A transfer line already knows its product, its quantity, the individual units
-- where they are tracked, and the bin it goes into at the far end. It does not
-- know which delivery the quantity came out of — so a shop moving stock could
-- not say "these four, from the consignment that arrived in March", and the
-- receiving branch could not tell one from another on arrival.
--
-- Null means what it has always meant: the shop did not say, and the stock
-- comes off whichever deliveries the branch's own rule picks.
--
-- Idempotent; safe to re-run on every deploy.


ALTER TABLE mystoreguard.msg_products
    ADD COLUMN IF NOT EXISTS retired_at    timestamptz,
    ADD COLUMN IF NOT EXISTS retired_by    text,
    ADD COLUMN IF NOT EXISTS retire_reason text;

COMMENT ON COLUMN mystoreguard.msg_products.retired_at IS
    'When the shop stopped selling this. Null means it still does. Hidden from '
    'store, warehouse, inventory and low-stock alerts; kept everywhere it has '
    'already been sold.';

-- The listings all ask the same question — "what does this shop still sell" —
-- and every one of them will now ask it with this predicate.
CREATE INDEX IF NOT EXISTS ix_msg_products_still_sold
    ON mystoreguard.msg_products (bus_id, name)
    WHERE retired_at IS NULL AND delete_status = 'NOT_DELETED';

CREATE INDEX IF NOT EXISTS ix_msg_products_retired
    ON mystoreguard.msg_products (bus_id, retired_at DESC)
    WHERE retired_at IS NOT NULL;


ALTER TABLE mystoreguard.msg_product_transfer_items
    ADD COLUMN IF NOT EXISTS batch_id text;

COMMENT ON COLUMN mystoreguard.msg_product_transfer_items.batch_id IS
    'The delivery this line moves out of. Null means the shop did not say, and '
    'the branch rule chooses — which is how every transfer worked before.';

CREATE INDEX IF NOT EXISTS ix_msg_product_transfer_items_batch
    ON mystoreguard.msg_product_transfer_items (batch_id)
    WHERE batch_id IS NOT NULL;
