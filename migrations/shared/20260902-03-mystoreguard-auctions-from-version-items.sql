-- 20260902-03-mystoreguard-auctions-from-version-items.sql
-- Give the storefront's bid windows a real auction behind them.
--
-- msg_ecommerce_version_items has carried bid_starts_at, bid_ends_at,
-- starting_bid, bid_increment and reserve_price since the storefront was built.
-- A shop filling those in has described an auction completely — and until now
-- nothing was listening. The storefront drew a "Live bid" badge and a
-- countdown, and clicking it took the shopper to an add-to-cart page, because
-- there was no bidding engine on the other side of the label.
--
-- Rather than ask a shop to describe the same auction twice, on two screens,
-- this links the two: a version item with a complete bid window gets an
-- msg_auctions row created from its own figures, once, and every tile and badge
-- then reads from the auction. One definition, one source of truth, and the
-- shop's existing setup keeps working.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================================
-- 1. Which version item an auction came from, if any.
--
--    Null for one created by hand on the Bidding screen. The unique index is
--    what makes "make sure this item has an auction" safe to call on every page
--    render from every replica at once — the second writer loses and reads what
--    the first wrote.
-- =====================================================================================
ALTER TABLE mystoreguard.msg_auctions
    ADD COLUMN IF NOT EXISTS version_item_id text,
    ADD COLUMN IF NOT EXISTS source          text NOT NULL DEFAULT 'MANUAL';

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'ck_msg_auctions_source') THEN
        ALTER TABLE mystoreguard.msg_auctions
            ADD CONSTRAINT ck_msg_auctions_source CHECK (
                source IN ('MANUAL', 'VERSION_ITEM')
            );
    END IF;
END $$;

-- One auction per version item, ever. A shop that reopens the same bid window
-- is continuing the same auction, not starting a second one alongside it —
-- which would split the bids in two and give the item two winners.
CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_auctions_version_item
    ON mystoreguard.msg_auctions (tenant_id, version_item_id)
    WHERE version_item_id IS NOT NULL;
