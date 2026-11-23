-- Storefront templates: a whole shop, ready-made, for 60-odd industries.
--
-- The templates themselves are DATA in MSG's files container
-- (mystoreguard/storefront-templates/<id>/template.json plus its art), not rows and
-- not code: adding or improving one is an upload, never a migration or a deploy.
-- What the database needs is only what a template is applied INTO:
--
--   1. the shop's own colours, because a bakery and a phone shop should not both
--      be orange;
--   2. bands that list products by their METADATA (every listed product tagged
--      "New arrival", every one in "Dresses"), so a template fills itself as soon
--      as products are tagged, with no hand-picking;
--   3. pages that fill themselves the same way;
--   4. a draft: applying a template must not change a live shop. The draft holds
--      the template as it was when chosen, and publishing turns it into the
--      ordinary page, band, slide, card and footer rows in one go.
--
-- Pictures a template brings are referenced as "template:<id>/<file>" in the
-- existing image_external_url columns, and signed from the files container like
-- every other picture. No new column for that.
--
-- Moves no stock and touches no order. Safe to run again.

-- ------------------------------------------------------- 1. the shop's colours --
ALTER TABLE mystoreguard.msg_ecommerce_settings
    -- #RRGGBB. Null means the storefront's own default.
    ADD COLUMN IF NOT EXISTS brand_primary text,
    ADD COLUMN IF NOT EXISTS brand_accent text,
    -- Which template the live storefront came from, and when. Informational: the
    -- shop owns every row after publishing and can change any of them.
    ADD COLUMN IF NOT EXISTS template_id text,
    ADD COLUMN IF NOT EXISTS template_applied_at timestamptz;

ALTER TABLE mystoreguard.msg_ecommerce_settings
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_settings_brand;
ALTER TABLE mystoreguard.msg_ecommerce_settings
    ADD CONSTRAINT ck_msg_ecommerce_settings_brand CHECK (
        (brand_primary IS NULL OR brand_primary ~ '^#[0-9A-Fa-f]{6}$')
        AND (brand_accent IS NULL OR brand_accent ~ '^#[0-9A-Fa-f]{6}$')
    );

-- ------------------------------------------------ 2. bands that read metadata --
ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    ADD COLUMN IF NOT EXISTS metadata_ids text[],
    ADD COLUMN IF NOT EXISTS metadata_match text NOT NULL DEFAULT 'ANY';

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_enums,
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_match;
ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    ADD CONSTRAINT ck_msg_ecommerce_home_sections_enums CHECK (
        section_key = ANY (ARRAY['HERO','BIDDING','PRE_USED','MARKET','CUSTOM',
                                 'HOW_IT_WORKS','PROMO','CATEGORY_TILES',
                                 'RICH_TEXT','DAILY_OFFER','INSTALLMENT',
                                 -- Every listed product carrying the band's metadata.
                                 'METADATA_SHELF'])
        AND layout = ANY (ARRAY['GRID','CAROUSEL','HERO','LIST'])
        AND item_limit > 0
    ),
    ADD CONSTRAINT ck_msg_ecommerce_home_sections_match CHECK (
        metadata_match = ANY (ARRAY['ANY','ALL'])
        -- A metadata shelf with nothing to match is an empty band waiting to
        -- confuse somebody; the other kinds ignore the column.
        AND (section_key <> 'METADATA_SHELF' OR coalesce(cardinality(metadata_ids), 0) > 0)
    );

-- ------------------------------------------------- 3. pages that fill themselves --
ALTER TABLE mystoreguard.msg_ecommerce_pages
    -- CURATED: the page shows what its versions hold (as before).
    -- AUTO:    it also shows every listed product its own filters let through
    --          (metadata, and for PRE_USED the condition), when no live version
    --          says otherwise.
    ADD COLUMN IF NOT EXISTS fill_mode text NOT NULL DEFAULT 'CURATED';

ALTER TABLE mystoreguard.msg_ecommerce_pages
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_pages_fill;
ALTER TABLE mystoreguard.msg_ecommerce_pages
    ADD CONSTRAINT ck_msg_ecommerce_pages_fill CHECK (fill_mode = ANY (ARRAY['CURATED','AUTO']));

-- --------------------------------------------------------------- 4. the draft --
CREATE TABLE IF NOT EXISTS mystoreguard.msg_ecommerce_template_drafts (
    id              text        PRIMARY KEY,
    tenant_id       text        NOT NULL,
    org_id          text        NOT NULL,
    bus_id          text        NOT NULL,

    template_id     text        NOT NULL,
    -- The template as it was when chosen. Publishing reads this, not storage, so
    -- a template improved in the meantime cannot change what the shop reviewed.
    template        jsonb       NOT NULL,
    -- What applying it decided: pages left out and why (bidding switched off, no
    -- instalment policy, no MyStoreGuard), metadata reused vs created, colours.
    plan            jsonb       NOT NULL DEFAULT '{}'::jsonb,

    -- DRAFT until published or discarded. Only one DRAFT per shop.
    status          text        NOT NULL DEFAULT 'DRAFT',
    -- REPLACE: publishing retires the shop's current pages and bands.
    -- (The only mode for now; the column is so a later "add pages" mode does not
    -- need a migration.)
    mode            text        NOT NULL DEFAULT 'REPLACE',
    published_at    timestamptz,
    published_by    text,

    cdate           date,
    ctime           time,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    udatetime       timestamptz,
    created_by      text,
    updated_by      text,
    deleted_by      text,

    CONSTRAINT ck_msg_ecommerce_template_drafts_status
        CHECK (status = ANY (ARRAY['DRAFT','PUBLISHED','DISCARDED'])),
    CONSTRAINT ck_msg_ecommerce_template_drafts_mode
        CHECK (mode = ANY (ARRAY['REPLACE']))
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_ecommerce_template_drafts_open
    ON mystoreguard.msg_ecommerce_template_drafts (tenant_id, org_id, bus_id)
    WHERE status = 'DRAFT' AND deleted_by IS NULL;

CREATE INDEX IF NOT EXISTS ix_msg_ecommerce_template_drafts_shop
    ON mystoreguard.msg_ecommerce_template_drafts (tenant_id, org_id, bus_id, cdatetime DESC);

COMMENT ON TABLE mystoreguard.msg_ecommerce_template_drafts IS
    'A storefront template a shop chose and has not published yet (or has, as history). The template JSON is a snapshot.';

-- ---------------------------------------------------------------- self-check --
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'mystoreguard' AND table_name = 'msg_ecommerce_home_sections'
                      AND column_name = 'metadata_ids') THEN
        RAISE EXCEPTION 'metadata_ids missing on msg_ecommerce_home_sections';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'mystoreguard' AND table_name = 'msg_ecommerce_pages'
                      AND column_name = 'fill_mode') THEN
        RAISE EXCEPTION 'fill_mode missing on msg_ecommerce_pages';
    END IF;
END $$;
