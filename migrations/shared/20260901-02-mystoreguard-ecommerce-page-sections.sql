-- 20260901-02-mystoreguard-ecommerce-page-sections.sql
-- A band belongs to a page, and the home page is only one of them.
--
-- msg_ecommerce_home_sections was built for the home page alone, so the other
-- three pages could only ever be a stack of promoted versions — no hero above
-- them, no promo strip under them, nothing to say what the page is before the
-- products start. Every shop wants a carousel at the top of its Market.
--
-- The table already knows how to hold every kind of band. The only thing it was
-- missing is which page the band is for, so that is the whole change: one
-- column, defaulted to HOME, which is what every existing row already is.
--
-- The name stays msg_ecommerce_home_sections. Renaming a table costs a
-- coordinated deploy across every reader for a word, and the column says plainly
-- enough what the rows now are.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================================
-- 1. Which page a band is for.
--
--    DEFAULT 'HOME' is not a guess: every row that exists was created by the
--    home page editor, so the default is the backfill.
-- =====================================================================================
ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    ADD COLUMN IF NOT EXISTS page_key text NOT NULL DEFAULT 'HOME';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_msg_ecommerce_home_sections_page'
    ) THEN
        ALTER TABLE mystoreguard.msg_ecommerce_home_sections
            ADD CONSTRAINT ck_msg_ecommerce_home_sections_page
            -- HOME is included and the other three are the switchable pages.
            -- A band on a page a shop has switched off is skipped rather than
            -- refused, the same way a band sourcing that page already is —
            -- switching the page back on should bring its hero back with it.
            CHECK (page_key IN ('HOME', 'BIDDING', 'PRE_USED', 'MARKET'));
    END IF;
END $$;


-- =====================================================================================
-- 2. Reading one page's bands in order.
--
--    Replaces nothing: the existing lookups are by business, and this is the
--    one every read now does.
-- =====================================================================================
CREATE INDEX IF NOT EXISTS ix_msg_ecommerce_home_sections_page
    ON mystoreguard.msg_ecommerce_home_sections
       (tenant_id, org_id, bus_id, page_key, sort_order)
    WHERE deleted_by IS NULL;
