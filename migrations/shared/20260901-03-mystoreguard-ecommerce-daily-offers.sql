-- 20260901-03-mystoreguard-ecommerce-daily-offers.sql
-- A fourth page: Daily offers.
--
-- The thing a shop discounts this morning and stops discounting tonight does not
-- belong in the Market — it is not the general catalogue, it is a window that
-- closes. Shops run it as its own page, and until now the only way to express it
-- was a Market version somebody had to remember to promote and unpromote.
--
-- Switchable like Bidding and Pre-used, and off to begin with, because a shop
-- that has never run a daily offer should not acquire an empty page for it.
--
-- The page list appears in nine CHECK constraints across four migrations, so a
-- fifth page means nine more edits. That repetition is the cost of the database
-- knowing the rule rather than only the service; it is worth it, but it is worth
-- knowing about — everything that has to change is in this one file, which is
-- the template for whatever comes next.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================================
-- 1. Versions may target it.
-- =====================================================================================
ALTER TABLE mystoreguard.msg_ecommerce_versions
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_versions_enums;

ALTER TABLE mystoreguard.msg_ecommerce_versions
    ADD CONSTRAINT ck_msg_ecommerce_versions_enums CHECK (
        page_key IN (
            'BIDDING', 'DAILY_OFFER', 'HOME', 'INSTALLMENT', 'MARKET',
            'PRE_USED'
        )
        AND status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED')
        AND layout IN ('GRID', 'CAROUSEL', 'HERO', 'LIST')
    );


-- =====================================================================================
-- 2. Bands: a strip of daily offers, a band living on that page, and links to it.
-- =====================================================================================
ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_enums;

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    ADD CONSTRAINT ck_msg_ecommerce_home_sections_enums CHECK (
        section_key IN (
            'BIDDING', 'CATEGORY_TILES', 'CUSTOM', 'DAILY_OFFER', 'HERO',
            'HOW_IT_WORKS', 'INSTALLMENT', 'MARKET', 'PRE_USED', 'PROMO',
            'RICH_TEXT'
        )
    );

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_page;

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    ADD CONSTRAINT ck_msg_ecommerce_home_sections_page CHECK (
        page_key IN (
            'BIDDING', 'DAILY_OFFER', 'HOME', 'INSTALLMENT', 'MARKET',
            'PRE_USED'
        )
    );

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_source;

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    ADD CONSTRAINT ck_msg_ecommerce_home_sections_source CHECK (
        source_page_key IS NULL
        OR source_page_key IN (
            'BIDDING', 'DAILY_OFFER', 'INSTALLMENT', 'MARKET', 'PRE_USED'
        )
    );

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_cta_page;

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    ADD CONSTRAINT ck_msg_ecommerce_home_sections_cta_page CHECK (
        cta_page_key IS NULL
        OR cta_page_key IN (
            'BIDDING', 'DAILY_OFFER', 'INSTALLMENT', 'MARKET', 'PRE_USED'
        )
    );

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_cta_secondary;

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    ADD CONSTRAINT ck_msg_ecommerce_home_sections_cta_secondary CHECK (
        cta_secondary_page_key IS NULL
        OR cta_secondary_page_key IN (
            'BIDDING', 'DAILY_OFFER', 'INSTALLMENT', 'MARKET', 'PRE_USED'
        )
    );


-- =====================================================================================
-- 3. Slides, cards and footer links may point at it.
-- =====================================================================================
ALTER TABLE mystoreguard.msg_ecommerce_banner_slides
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_banner_slides_cta;

ALTER TABLE mystoreguard.msg_ecommerce_banner_slides
    ADD CONSTRAINT ck_msg_ecommerce_banner_slides_cta CHECK (
        (cta_page_key IS NULL
         OR cta_page_key IN (
            'BIDDING', 'DAILY_OFFER', 'INSTALLMENT', 'MARKET', 'PRE_USED'
        ))
        AND (cta_secondary_page_key IS NULL
             OR cta_secondary_page_key IN (
            'BIDDING', 'DAILY_OFFER', 'INSTALLMENT', 'MARKET', 'PRE_USED'
        ))
    );

ALTER TABLE mystoreguard.msg_ecommerce_section_cards
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_section_cards_link;

ALTER TABLE mystoreguard.msg_ecommerce_section_cards
    ADD CONSTRAINT ck_msg_ecommerce_section_cards_link CHECK (
        link_page_key IS NULL
        OR link_page_key IN (
            'BIDDING', 'DAILY_OFFER', 'INSTALLMENT', 'MARKET', 'PRE_USED'
        )
    );

ALTER TABLE mystoreguard.msg_ecommerce_footer_links
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_footer_links_link;

ALTER TABLE mystoreguard.msg_ecommerce_footer_links
    ADD CONSTRAINT ck_msg_ecommerce_footer_links_link CHECK (
        link_page_key IS NULL
        OR link_page_key IN (
            'BIDDING', 'DAILY_OFFER', 'INSTALLMENT', 'MARKET', 'PRE_USED'
        )
    );


-- =====================================================================================
-- 4. The page itself.
--
--    MARKET stays the one that cannot be switched off. Daily offers is a thing a
--    shop chooses to run, like auctions.
-- =====================================================================================
ALTER TABLE mystoreguard.msg_ecommerce_pages
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_pages_keys;

ALTER TABLE mystoreguard.msg_ecommerce_pages
    ADD CONSTRAINT ck_msg_ecommerce_pages_keys CHECK (
        page_key IN (
            'BIDDING', 'DAILY_OFFER', 'INSTALLMENT', 'MARKET', 'PRE_USED'
        )
        AND (page_key <> 'MARKET' OR is_enabled)
    );

-- A row for every business that has a storefront. Off unless the shop somehow
-- already has versions aimed at it, which it will not — the same shape as the
-- 20260901-01 backfill so the two agree about what "already using it" means.
INSERT INTO mystoreguard.msg_ecommerce_pages (
    id, tenant_id, org_id, bus_id, page_key, is_enabled, nav_sort_order,
    cdate, ctime, cdatetime, created_by
)
SELECT
    'epg-' || md5(s.tenant_id || s.org_id || s.bus_id || 'DAILY_OFFER'),
    s.tenant_id, s.org_id, s.bus_id, 'DAILY_OFFER',
    EXISTS (
        SELECT 1 FROM mystoreguard.msg_ecommerce_versions v
        WHERE v.tenant_id = s.tenant_id AND v.org_id = s.org_id
          AND v.bus_id = s.bus_id AND v.page_key = 'DAILY_OFFER'
          AND v.deleted_by IS NULL
    ),
    -- Last in the nav by default. A shop that wants it first can move it.
    3,
    now()::date, now()::time, now(), 'migration-20260901-03'
FROM mystoreguard.msg_ecommerce_settings s
WHERE s.deleted_by IS NULL
ON CONFLICT (id) DO NOTHING;
