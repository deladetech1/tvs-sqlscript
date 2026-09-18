-- A listing can be one delivery, sold by the pack.
--
-- A tile on the storefront was always a PRODUCT. But a product arrives in
-- lines — one delivery of curtains at one price, another at another, a third
-- second-hand — and a shop that wants those seen separately had no way to say
-- so. A shopper had to open the product to find out there was more than one.
--
-- And stock is counted in base units while shops sell in packs. A shop selling
-- curtains in pairs with eleven singles on the shelf is selling five pairs, not
-- eleven of anything, and the price of a pair is two singles. Doing that in the
-- shopper's head is how a shop ends up taking payment for half a pair.
--
-- So a version item may now name:
--
--   batch_id   one delivery, becoming its own tile with its own stock and price
--   unit_id    one individual item, for stock tracked one at a time
--   pack_name  the level of that delivery's own packaging to sell by
--   pack_size  how many base units that is — FROZEN, like the chain itself
--
-- pack_size is stored rather than looked up for the same reason a batch freezes
-- its packaging when the goods arrive: a shop that re-packs its next delivery in
-- threes has not changed what is on the shelf in twos, and a listing that
-- silently re-priced itself because somebody edited a product would be worse
-- than one that goes stale.
--
-- All four are null for a listing that means "this product, as it always did",
-- which is every listing that exists today.

ALTER TABLE mystoreguard.msg_ecommerce_version_items
    ADD COLUMN IF NOT EXISTS batch_id text,
    ADD COLUMN IF NOT EXISTS unit_id text,
    ADD COLUMN IF NOT EXISTS pack_name text,
    ADD COLUMN IF NOT EXISTS pack_size integer;

ALTER TABLE mystoreguard.msg_ecommerce_version_items
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_version_items_pack;

ALTER TABLE mystoreguard.msg_ecommerce_version_items
    ADD CONSTRAINT ck_msg_ecommerce_version_items_pack CHECK (
        -- A pack has to hold at least one of something.
        (pack_size IS NULL OR pack_size >= 1)
        -- A size without a name is a number nobody can read, and a name without
        -- a size is a word the arithmetic cannot use. They arrive together.
        AND ((pack_name IS NULL) = (pack_size IS NULL))
        -- One individual item belongs to the delivery it came in on. Naming the
        -- item without the line leaves the price and the stock with nothing to
        -- resolve against.
        AND (unit_id IS NULL OR batch_id IS NOT NULL)
    );

-- One tile per slot, and a slot just got wider.
--
-- uq_msg_ecommerce_version_items_slot has been (version_id, product_id, image)
-- since the day versions existed: one tile per product, or one per picture
-- where a shop split the blue from the red. Three deliveries of one product
-- share one picture, so under that rule the second one is a duplicate and the
-- shop gets a database error for doing exactly what this migration is for.
--
-- The name stays. 20260830-01 creates it with IF NOT EXISTS, so once the name
-- is present that statement skips and this definition is the one that stands,
-- through every replay. Widening can never fail on existing rows: everything
-- unique under the old key is still unique under this one.
DROP INDEX IF EXISTS mystoreguard.uq_msg_ecommerce_version_items_slot;

CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_ecommerce_version_items_slot
    ON mystoreguard.msg_ecommerce_version_items (
        version_id, product_id, COALESCE(image_id, ''),
        COALESCE(batch_id, ''), COALESCE(unit_id, ''), COALESCE(pack_name, ''))
    WHERE deleted_by IS NULL;

-- Not unique, and that is on purpose. Two tiles of one product are a supported
-- thing — the blue one and the red one, which is what image_id is for — so
-- "already listed" cannot be decided by these columns alone. The service
-- decides it, where it can say which tile it clashed with; this index is here
-- so it can ask quickly, and so a page rendering forty line tiles does not scan
-- the table forty times.
CREATE INDEX IF NOT EXISTS ix_msg_ecommerce_version_items_line
    ON mystoreguard.msg_ecommerce_version_items (version_id, product_id, batch_id)
    WHERE deleted_by IS NULL;

COMMENT ON COLUMN mystoreguard.msg_ecommerce_version_items.pack_size IS
    'Base units in one pack, frozen when the listing was made. Stock divides by it; price multiplies by it.';
