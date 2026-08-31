-- 20260831-02-mystoreguard-ecommerce-banner.sql
-- Makes a HERO band an actual banner.
--
-- It was a heading, a subheading and a link — no picture, because the sections
-- table had no image column at all. That is not a banner, and there was no way
-- to put one on the front page.
--
-- These columns are only ever read for a HERO. They live on the sections table
-- rather than in one of their own because a banner IS a band: it sits in the
-- same stack, in the same order, with the same visibility switch, and a separate
-- table would mean two things to order against each other. The cost is a handful
-- of columns that are null on every other row, which is the cheaper mistake.
--
-- Idempotent; safe to re-run on every deploy.

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    -- The small line above the heading: "24hr Deals", "New in".
    ADD COLUMN IF NOT EXISTS eyebrow                 text,

    -- The picture. Uploaded through the file manager, or a URL already hosted
    -- somewhere the storefront can reach — the same pair as a storefront product
    -- picture, so the uploader and the presigning are the ones already in use.
    ADD COLUMN IF NOT EXISTS image_document_id       text,
    ADD COLUMN IF NOT EXISTS image_external_url      text,

    -- What the banner counts down to. A deadline is the whole point of a "24hr
    -- deal", and a banner that says "23:44:34" while standing still is worse than
    -- one that says nothing. Null means no clock.
    ADD COLUMN IF NOT EXISTS countdown_at            timestamptz,

    -- A second, quieter link. The mockup has "Claim Deal" beside "View all
    -- deals", and one button cannot express both.
    ADD COLUMN IF NOT EXISTS cta_secondary_label     text,
    ADD COLUMN IF NOT EXISTS cta_secondary_page_key  text,

    -- Optionally, the product the banner is about. It gives the banner a picture
    -- and a price without anybody typing either, which is what stops a banner
    -- still advertising last month's price. An uploaded image overrides the
    -- product's own picture; the price always comes from the product, because a
    -- typed price is a promise the till will not keep.
    ADD COLUMN IF NOT EXISTS featured_product_id     text;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_msg_ecommerce_home_sections_cta_secondary'
    ) THEN
        ALTER TABLE mystoreguard.msg_ecommerce_home_sections
            ADD CONSTRAINT ck_msg_ecommerce_home_sections_cta_secondary
            CHECK (cta_secondary_page_key IS NULL
                   OR cta_secondary_page_key IN ('BIDDING', 'PRE_USED', 'MARKET'));
    END IF;
END $$;

COMMENT ON COLUMN mystoreguard.msg_ecommerce_home_sections.countdown_at IS
    'What a HERO banner counts down to. The storefront ticks it; a passed '
    'deadline should read as finished rather than as a negative number.';

COMMENT ON COLUMN mystoreguard.msg_ecommerce_home_sections.featured_product_id IS
    'The product a HERO banner is about, if any. Supplies the picture and the '
    'price so neither is typed and neither goes stale. No FK on purpose: a '
    'deleted product should blank the banner''s product, not refuse the delete '
    'or cascade a whole band away.';
