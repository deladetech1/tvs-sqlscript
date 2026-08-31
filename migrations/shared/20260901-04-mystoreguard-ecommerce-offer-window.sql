-- 20260901-04-mystoreguard-ecommerce-offer-window.sql
-- A daily offer is a price with a closing time.
--
-- Without one it is just a cheap product, and the shop has to remember to take
-- it down — which is the job the page exists to do for them. So an item on the
-- Daily offers page carries a window, the same way an auction item does.
--
-- Its own pair of columns rather than reusing bid_starts_at/bid_ends_at. Those
-- are named for what they are, an auction opening and closing, and a row that
-- means "the discount ends" while the column says "bidding ends" is a lie that
-- reads fine right up until somebody writes a report against it.
--
-- Idempotent; safe to re-run on every deploy.


ALTER TABLE mystoreguard.msg_ecommerce_version_items
    -- When the discount starts. Empty means it is already running.
    ADD COLUMN IF NOT EXISTS offer_starts_at timestamptz,
    -- When it stops. Required on a DAILY_OFFER item — enforced in the service,
    -- which is the only place that can see the parent version's page_key.
    ADD COLUMN IF NOT EXISTS offer_ends_at   timestamptz,
    -- What the thing cost before. Shown struck through beside the offer price,
    -- and never computed from it: a "was" price the shop did not actually charge
    -- is the one number here that can get somebody into trouble.
    ADD COLUMN IF NOT EXISTS was_price       numeric(18, 2);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_msg_ecommerce_version_items_offer'
    ) THEN
        ALTER TABLE mystoreguard.msg_ecommerce_version_items
            ADD CONSTRAINT ck_msg_ecommerce_version_items_offer CHECK (
                -- Ordering only. Whether the window is REQUIRED depends on the
                -- parent's page_key, which a row-level CHECK cannot see — the
                -- same division of labour as the bidding constraint above it.
                (offer_starts_at IS NULL OR offer_ends_at IS NULL
                 OR offer_ends_at > offer_starts_at)
                AND (was_price IS NULL OR was_price >= 0)
            );
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_msg_ecommerce_version_items_offer_window
    ON mystoreguard.msg_ecommerce_version_items (version_id, offer_ends_at)
    WHERE deleted_by IS NULL AND offer_ends_at IS NOT NULL;
