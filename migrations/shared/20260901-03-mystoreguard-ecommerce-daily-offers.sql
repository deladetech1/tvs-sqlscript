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
-- The page list USED to appear in nine CHECK constraints across four migrations,
-- and this file was written as the template for adding a tenth. That was the
-- wrong shape and it is gone: a page is a row a shop creates, so no list in the
-- schema can know the keys. Do not add a page here — there is nothing to add it
-- to. See 20260918-02.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================================
-- 1. Versions may target it.
-- =====================================================================================
ALTER TABLE mystoreguard.msg_ecommerce_versions
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_versions_enums;

ALTER TABLE mystoreguard.msg_ecommerce_versions
    ADD CONSTRAINT ck_msg_ecommerce_versions_enums CHECK (
    -- A page key is the shop's own, so it is no longer a list here. The names
    -- are kept because the migrations that created these constraints guard on
    -- the NAME — dropping one un-guards its creator, which adds the old list
    -- straight back over rows that now carry a shop's page keys, and the
    -- deploy stops on this statement. Same rules as 20260918-02 settles on.
        page_key IS NOT NULL
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
    -- Opened with the rest; see the note on the versions constraint above.
        page_key IS NOT NULL
    );

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_source;

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    ADD CONSTRAINT ck_msg_ecommerce_home_sections_source CHECK (
    -- Opened with the rest; see the note on the versions constraint above.
        true
    );

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_cta_page;

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    ADD CONSTRAINT ck_msg_ecommerce_home_sections_cta_page CHECK (
    -- Opened with the rest; see the note on the versions constraint above.
        true
    );

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_cta_secondary;

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    ADD CONSTRAINT ck_msg_ecommerce_home_sections_cta_secondary CHECK (
    -- Opened with the rest; see the note on the versions constraint above.
        true
    );


-- =====================================================================================
-- 3. Slides, cards and footer links may point at it.
-- =====================================================================================
ALTER TABLE mystoreguard.msg_ecommerce_banner_slides
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_banner_slides_cta;

ALTER TABLE mystoreguard.msg_ecommerce_banner_slides
    ADD CONSTRAINT ck_msg_ecommerce_banner_slides_cta CHECK (
    -- Opened with the rest; see the note on the versions constraint above.
        true
    );

ALTER TABLE mystoreguard.msg_ecommerce_section_cards
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_section_cards_link;

ALTER TABLE mystoreguard.msg_ecommerce_section_cards
    ADD CONSTRAINT ck_msg_ecommerce_section_cards_link CHECK (
    -- Opened with the rest; see the note on the versions constraint above.
        true
    );

ALTER TABLE mystoreguard.msg_ecommerce_footer_links
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_footer_links_link;

ALTER TABLE mystoreguard.msg_ecommerce_footer_links
    ADD CONSTRAINT ck_msg_ecommerce_footer_links_link CHECK (
    -- Opened with the rest; see the note on the versions constraint above.
        true
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
    -- Pages are rows a business creates now, so their keys are the shop's
    -- rather than a list here, and the Market is an ordinary page that may be
    -- switched off or removed like any other. Left as it was, replaying this
    -- file re-pinned both rules over rows that break them and the deploy
    -- stopped here. The home page is the one that must stay on, and its own
    -- row says so.
        page_key IS NOT NULL
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
