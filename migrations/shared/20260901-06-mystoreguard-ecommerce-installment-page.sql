-- 20260901-06-mystoreguard-ecommerce-installment-page.sql
-- A fifth page: things you can buy on a plan.
--
-- The storefront settings have promised `allow_installment_purchase` since the
-- module was built, and nothing on the site has ever acted on it — a shopper had
-- no way to find out which items could be had on a plan. This is that page.
--
-- Each item names the policy it is sold under. Policies already target products
-- themselves, so resolving the page from those targets was the tempting design
-- and is not the one taken: it would mean a second implementation of the
-- policy's targeting rules living in ecommerce, and the two would drift. It is
-- also an editorial choice worth making by hand — a shop may well offer twelve
-- months on a phone and nothing at all on a charger.
--
-- The page list now appears in TEN CHECK constraints. That was worth noting at
-- three pages and is worth acting on at five: a domain would let a sixth page be
-- one ALTER instead of ten. Not done here, because converting ten live columns
-- to a domain is its own migration and this one should stay about the feature.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================================
-- 1. Everywhere the page list is written down.
-- =====================================================================================
ALTER TABLE mystoreguard.msg_ecommerce_versions
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_versions_enums;
ALTER TABLE mystoreguard.msg_ecommerce_versions
    ADD CONSTRAINT ck_msg_ecommerce_versions_enums CHECK (
        page_key IN ('HOME', 'BIDDING', 'PRE_USED', 'MARKET', 'DAILY_OFFER', 'INSTALLMENT')
        AND status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED')
        AND layout IN ('GRID', 'CAROUSEL', 'HERO', 'LIST')
    );

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_enums;
ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    ADD CONSTRAINT ck_msg_ecommerce_home_sections_enums CHECK (
        section_key IN (
            'HERO', 'BIDDING', 'PRE_USED', 'MARKET', 'CUSTOM',
            'HOW_IT_WORKS', 'PROMO', 'CATEGORY_TILES', 'RICH_TEXT',
            'DAILY_OFFER', 'INSTALLMENT'
        )
    );

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_page;
ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    ADD CONSTRAINT ck_msg_ecommerce_home_sections_page CHECK (
        page_key IN ('HOME', 'BIDDING', 'PRE_USED', 'MARKET', 'DAILY_OFFER', 'INSTALLMENT')
    );

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_source;
ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    ADD CONSTRAINT ck_msg_ecommerce_home_sections_source CHECK (
        source_page_key IS NULL
        OR source_page_key IN ('BIDDING', 'PRE_USED', 'MARKET', 'DAILY_OFFER', 'INSTALLMENT')
    );

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_cta_page;
ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    ADD CONSTRAINT ck_msg_ecommerce_home_sections_cta_page CHECK (
        cta_page_key IS NULL
        OR cta_page_key IN ('BIDDING', 'PRE_USED', 'MARKET', 'DAILY_OFFER', 'INSTALLMENT')
    );

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_cta_secondary;
ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    ADD CONSTRAINT ck_msg_ecommerce_home_sections_cta_secondary CHECK (
        cta_secondary_page_key IS NULL
        OR cta_secondary_page_key IN ('BIDDING', 'PRE_USED', 'MARKET', 'DAILY_OFFER', 'INSTALLMENT')
    );

ALTER TABLE mystoreguard.msg_ecommerce_banner_slides
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_banner_slides_cta;
ALTER TABLE mystoreguard.msg_ecommerce_banner_slides
    ADD CONSTRAINT ck_msg_ecommerce_banner_slides_cta CHECK (
        (cta_page_key IS NULL
         OR cta_page_key IN ('BIDDING', 'PRE_USED', 'MARKET', 'DAILY_OFFER', 'INSTALLMENT'))
        AND (cta_secondary_page_key IS NULL
             OR cta_secondary_page_key IN ('BIDDING', 'PRE_USED', 'MARKET', 'DAILY_OFFER', 'INSTALLMENT'))
    );

ALTER TABLE mystoreguard.msg_ecommerce_section_cards
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_section_cards_link;
ALTER TABLE mystoreguard.msg_ecommerce_section_cards
    ADD CONSTRAINT ck_msg_ecommerce_section_cards_link CHECK (
        link_page_key IS NULL
        OR link_page_key IN ('BIDDING', 'PRE_USED', 'MARKET', 'DAILY_OFFER', 'INSTALLMENT')
    );

ALTER TABLE mystoreguard.msg_ecommerce_footer_links
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_footer_links_link;
ALTER TABLE mystoreguard.msg_ecommerce_footer_links
    ADD CONSTRAINT ck_msg_ecommerce_footer_links_link CHECK (
        link_page_key IS NULL
        OR link_page_key IN ('BIDDING', 'PRE_USED', 'MARKET', 'DAILY_OFFER', 'INSTALLMENT')
    );

ALTER TABLE mystoreguard.msg_ecommerce_pages
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_pages_keys;
ALTER TABLE mystoreguard.msg_ecommerce_pages
    ADD CONSTRAINT ck_msg_ecommerce_pages_keys CHECK (
        page_key IN ('BIDDING', 'PRE_USED', 'MARKET', 'DAILY_OFFER', 'INSTALLMENT')
        AND (page_key <> 'MARKET' OR is_enabled)
    );


-- =====================================================================================
-- 2. What a listing is sold under.
--
--    No FK: a policy retired after a version was built should leave the listing
--    readable and flagged, not refuse the delete. The service resolves the name
--    and reports a policy that has gone.
-- =====================================================================================
ALTER TABLE mystoreguard.msg_ecommerce_version_items
    ADD COLUMN IF NOT EXISTS installment_policy_id text;

CREATE INDEX IF NOT EXISTS ix_msg_ecommerce_version_items_policy
    ON mystoreguard.msg_ecommerce_version_items (installment_policy_id)
    WHERE deleted_by IS NULL AND installment_policy_id IS NOT NULL;


-- =====================================================================================
-- 3. The page itself. Off to begin with, like every page a shop opts into.
-- =====================================================================================
INSERT INTO mystoreguard.msg_ecommerce_pages (
    id, tenant_id, org_id, bus_id, page_key, is_enabled, nav_sort_order,
    cdate, ctime, cdatetime, created_by
)
SELECT
    'epg-' || md5(s.tenant_id || s.org_id || s.bus_id || 'INSTALLMENT'),
    s.tenant_id, s.org_id, s.bus_id, 'INSTALLMENT',
    EXISTS (
        SELECT 1 FROM mystoreguard.msg_ecommerce_versions v
        WHERE v.tenant_id = s.tenant_id AND v.org_id = s.org_id
          AND v.bus_id = s.bus_id AND v.page_key = 'INSTALLMENT'
          AND v.deleted_by IS NULL
    ),
    4,
    now()::date, now()::time, now(), 'migration-20260901-06'
FROM mystoreguard.msg_ecommerce_settings s
WHERE s.deleted_by IS NULL
ON CONFLICT (id) DO NOTHING;
