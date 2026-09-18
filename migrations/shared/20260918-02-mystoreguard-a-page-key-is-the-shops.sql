-- A page key belongs to the shop, not to a list in the schema.
--
-- Pages became rows a shop creates, but the constraints still named the five
-- the app used to ship with. So a shop could build a page, see it on the
-- storefront, and then be unable to do anything with it: a version for it was
-- refused by the database, and so was a band on it, a link to it in the footer,
-- or a card pointing at it. The page existed and could not be used, which is
-- most of the way to not having it.
--
-- What keeps a typo out is no longer a list of allowed words. It is that the
-- page has to exist: the API checks every key against that business's own pages
-- before it writes, and a key naming no page is refused there with a sentence
-- rather than here with a constraint violation.
--
-- REDEFINED RATHER THAN DROPPED, KEEPING EVERY NAME.
--
-- The migrations that created these run again on every deploy, each guarded by
-- "IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = ...)". Dropping a
-- constraint therefore un-guards its creator, which then tries to add the old
-- rule back over rows that now break it — which is exactly what happened:
--
--   Running 20260830-01-mystoreguard-ecommerce.sql...
--   23514: check constraint "ck_msg_ecommerce_versions_enums" is violated by some row
--
-- Keeping the names means those guards still find them and skip, and the rules
-- they carry are the ones written here. The parts that are genuinely closed
-- sets the app owns — status, layout, section_key, limits, date order — are
-- kept exactly as they were.

-- ------------------------------------------------------------- versions --
ALTER TABLE mystoreguard.msg_ecommerce_versions
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_versions_enums;

ALTER TABLE mystoreguard.msg_ecommerce_versions
    ADD CONSTRAINT ck_msg_ecommerce_versions_enums CHECK (
        status = ANY (ARRAY['DRAFT','PUBLISHED','ARCHIVED'])
        AND layout = ANY (ARRAY['GRID','CAROUSEL','HERO','LIST'])
        AND (item_limit IS NULL OR item_limit > 0)
        AND (starts_at IS NULL OR ends_at IS NULL OR ends_at > starts_at)
    );

-- ---------------------------------------------------------------- bands --
-- The page a band sits on, and the page whose items fill it.
ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_page,
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_source,
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_cta_page,
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_cta_secondary,
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_enums;

-- Re-added under the same names so their creators keep skipping them, carrying
-- only the parts that are still true.
ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    ADD CONSTRAINT ck_msg_ecommerce_home_sections_page CHECK (page_key IS NOT NULL),
    ADD CONSTRAINT ck_msg_ecommerce_home_sections_source CHECK (true),
    ADD CONSTRAINT ck_msg_ecommerce_home_sections_cta_page CHECK (true),
    ADD CONSTRAINT ck_msg_ecommerce_home_sections_cta_secondary CHECK (true),
    ADD CONSTRAINT ck_msg_ecommerce_home_sections_enums CHECK (
        section_key = ANY (ARRAY['HERO','BIDDING','PRE_USED','MARKET','CUSTOM',
                                 'HOW_IT_WORKS','PROMO','CATEGORY_TILES',
                                 'RICH_TEXT','DAILY_OFFER','INSTALLMENT'])
        AND layout = ANY (ARRAY['GRID','CAROUSEL','HERO','LIST'])
        AND item_limit > 0
    );

-- ------------------------------------------------- slides, cards, footer --
ALTER TABLE mystoreguard.msg_ecommerce_banner_slides
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_banner_slides_cta;
ALTER TABLE mystoreguard.msg_ecommerce_banner_slides
    ADD CONSTRAINT ck_msg_ecommerce_banner_slides_cta CHECK (true);

ALTER TABLE mystoreguard.msg_ecommerce_section_cards
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_section_cards_link;
ALTER TABLE mystoreguard.msg_ecommerce_section_cards
    ADD CONSTRAINT ck_msg_ecommerce_section_cards_link CHECK (true);

ALTER TABLE mystoreguard.msg_ecommerce_footer_links
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_footer_links_link;
ALTER TABLE mystoreguard.msg_ecommerce_footer_links
    ADD CONSTRAINT ck_msg_ecommerce_footer_links_link CHECK (true);

-- The pages table's own key list, from the storefront-shell migration. Its
-- creator guards on the name too, so the name is kept and the rule replaced:
-- a page key is whatever the shop's row says, and the Market is no longer
-- compulsory.
ALTER TABLE mystoreguard.msg_ecommerce_pages
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_pages_keys;
ALTER TABLE mystoreguard.msg_ecommerce_pages
    ADD CONSTRAINT ck_msg_ecommerce_pages_keys CHECK (page_key IS NOT NULL);
