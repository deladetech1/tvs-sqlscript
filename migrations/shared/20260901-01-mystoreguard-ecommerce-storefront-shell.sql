-- 20260901-01-mystoreguard-ecommerce-storefront-shell.sql
-- The storefront is a site, not three catalogue pages.
--
-- What was here before assumed the home page was one band per page: a hero, a
-- Bidding strip, a Pre-used strip, a Market strip. A shop that runs neither
-- auctions nor second-hand goods — which is most shops — got a home page of two
-- bands, and there was nothing it could do about it.
--
-- Three changes, and they only make sense together:
--
--   1. Pages become rows, so Bidding and Pre-used can be switched off. Market
--      cannot be: it is not a page a shop enables, it is the shop. A CHECK says
--      so, because a rule this load-bearing should not live only in a service.
--
--   2. Bands that are not catalogue at all — how-it-works cards, a promo strip,
--      category tiles, a block of words. These are what a market-only home page
--      is actually made of, and none of them care which pages exist.
--
--   3. The footer and the nav stop being the frontend's opinion and become the
--      shop's: its tagline, its columns, its links, its socials. A footer link
--      resolves to a PAGE rather than a path, so switching Bidding off cannot
--      leave a link pointing at a page that is no longer there.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================================
-- 1. The pages a storefront has.
--
--    A row per page per business rather than three booleans on settings: pages
--    carry a label and a position in the nav as well as a switch, and the nav is
--    ordered, which columns cannot express.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_ecommerce_pages (
    id              text        PRIMARY KEY,
    tenant_id       text        NOT NULL,
    org_id          text        NOT NULL,
    bus_id          text        NOT NULL,

    page_key        text        NOT NULL,

    -- Never false for MARKET. See the CHECK below.
    is_enabled      boolean     NOT NULL DEFAULT false,

    -- What the shop calls it. QuickPick calls Market "Direct Buy" and Bidding
    -- "Live Bid"; neither is wrong, and neither should be baked into a renderer.
    -- Empty falls back to the app's own name for the page.
    label           text,

    -- Position in the header nav, lowest first.
    nav_sort_order  integer     NOT NULL DEFAULT 0,

    cdate           date,
    ctime           time,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    udatetime       timestamptz,
    created_by      text,
    updated_by      text,
    deleted_by      text
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_msg_ecommerce_pages_unique
    ON mystoreguard.msg_ecommerce_pages (tenant_id, org_id, bus_id, page_key)
    WHERE deleted_by IS NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_ecommerce_pages_keys'
    ) THEN
        ALTER TABLE mystoreguard.msg_ecommerce_pages
            ADD CONSTRAINT ck_msg_ecommerce_pages_keys CHECK (
                page_key IN (
                    'BIDDING', 'DAILY_OFFER', 'INSTALLMENT', 'MARKET', 'PRE_USED'
                )
                -- Market is the shop. A storefront with it switched off is a
                -- storefront that sells nothing, which is not a state anybody
                -- means to reach — so it is not reachable.
                AND (page_key <> 'MARKET' OR is_enabled)
            );
    END IF;
END $$;

-- Every business that has a storefront gets its three rows. Bidding and Pre-used
-- start on only where the shop is already using them — judged by whether a
-- version or a home band exists for that page. Anything else would either switch
-- off a page somebody is running, or switch on two pages nobody asked for.
INSERT INTO mystoreguard.msg_ecommerce_pages (
    id, tenant_id, org_id, bus_id, page_key, is_enabled, nav_sort_order,
    cdate, ctime, cdatetime, created_by
)
SELECT
    'epg-' || md5(s.tenant_id || s.org_id || s.bus_id || p.page_key),
    s.tenant_id, s.org_id, s.bus_id, p.page_key,
    p.page_key = 'MARKET'
        OR EXISTS (
            SELECT 1 FROM mystoreguard.msg_ecommerce_versions v
            WHERE v.tenant_id = s.tenant_id AND v.org_id = s.org_id
              AND v.bus_id = s.bus_id AND v.page_key = p.page_key
              AND v.deleted_by IS NULL
        )
        OR EXISTS (
            SELECT 1 FROM mystoreguard.msg_ecommerce_home_sections h
            WHERE h.tenant_id = s.tenant_id AND h.org_id = s.org_id
              AND h.bus_id = s.bus_id AND h.source_page_key = p.page_key
              AND h.deleted_by IS NULL
        ),
    p.nav_sort_order,
    now()::date, now()::time, now(), 'migration-20260901-01'
FROM mystoreguard.msg_ecommerce_settings s
CROSS JOIN (VALUES ('BIDDING', 0), ('MARKET', 1), ('PRE_USED', 2))
    AS p(page_key, nav_sort_order)
WHERE s.deleted_by IS NULL
ON CONFLICT (id) DO NOTHING;


-- =====================================================================================
-- 2. The new kinds of band.
--
--    HOW_IT_WORKS   a row of icon + heading + sentence cards
--    PROMO          one full-width coloured strip with a link
--    CATEGORY_TILES pictures that lead into Market filtered by metadata
--    RICH_TEXT      a block of words — delivery terms, warranty, who the shop is
--
--    None of them read source_page_key, which is the point: they render the same
--    whether a shop runs auctions or only sells things.
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
    -- The words of a RICH_TEXT band. Plain text; the storefront decides how big.
    ADD COLUMN IF NOT EXISTS body text,
    -- How the band is painted. The same three the reference storefront uses for
    -- its hero, so a promo strip can be the loud one on an otherwise white page.
    ADD COLUMN IF NOT EXISTS background_style text NOT NULL DEFAULT 'LIGHT';

-- A slide is painted the same way, and for the same reason: three slides that
-- are all white is a carousel you cannot tell is turning.
ALTER TABLE mystoreguard.msg_ecommerce_banner_slides
    ADD COLUMN IF NOT EXISTS theme text NOT NULL DEFAULT 'LIGHT';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_msg_ecommerce_home_sections_background'
    ) THEN
        ALTER TABLE mystoreguard.msg_ecommerce_home_sections
            ADD CONSTRAINT ck_msg_ecommerce_home_sections_background
            CHECK (background_style IN ('LIGHT', 'DARK', 'BRAND'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_ecommerce_banner_slides_theme'
    ) THEN
        ALTER TABLE mystoreguard.msg_ecommerce_banner_slides
            ADD CONSTRAINT ck_msg_ecommerce_banner_slides_theme
            CHECK (theme IN ('LIGHT', 'DARK', 'BRAND'));
    END IF;
END $$;


-- =====================================================================================
-- 3. The little things inside those bands.
--
--    A how-it-works card and a category tile are the same row wearing different
--    clothes — an optional icon, some words, a picture, and somewhere to go. One
--    table rather than two, because splitting them would duplicate the whole
--    read/write path to save four nullable columns.
--
--    Not folded into msg_ecommerce_banner_slides: a slide carries a countdown, a
--    second link and a featured product, none of which a card has, and a hero is
--    the one band where the order is a rotation rather than a layout.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_ecommerce_section_cards (
    id                  text        PRIMARY KEY,
    tenant_id           text        NOT NULL,
    org_id              text        NOT NULL,
    bus_id              text        NOT NULL,
    section_id          text        NOT NULL
        REFERENCES mystoreguard.msg_ecommerce_home_sections (id) ON DELETE CASCADE,

    sort_order          integer     NOT NULL DEFAULT 0,

    -- A name from the storefront's own icon set, e.g. 'gavel', 'box', 'tag'.
    -- Free text rather than an enum: the set lives in the frontend, and a CHECK
    -- here would mean a database migration every time somebody wants a new
    -- picture next to "Free delivery".
    icon                text,
    title               text,
    body                text,

    image_document_id   text,
    image_external_url  text,

    -- Where the card leads. A page, a specific version of one, or a typed URL —
    -- in that order of preference. A page link cannot rot, which is why it is
    -- the one the admin offers first.
    link_page_key       text,
    link_version_id     text,
    link_url            text,

    -- For a CATEGORY_TILES card: the tag/category/brand it filters Market by.
    metadata_id         text,

    is_visible          boolean     NOT NULL DEFAULT true,

    cdate               date,
    ctime               time,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    udatetime           timestamptz,
    created_by          text,
    updated_by          text,
    deleted_by          text
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_ecommerce_section_cards_link'
    ) THEN
        ALTER TABLE mystoreguard.msg_ecommerce_section_cards
            ADD CONSTRAINT ck_msg_ecommerce_section_cards_link CHECK (
                link_page_key IS NULL
                OR link_page_key IN (
                    'BIDDING', 'DAILY_OFFER', 'INSTALLMENT', 'MARKET', 'PRE_USED'
                )
            );
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_msg_ecommerce_section_cards_section
    ON mystoreguard.msg_ecommerce_section_cards (section_id, sort_order)
    WHERE deleted_by IS NULL;


-- =====================================================================================
-- 4. Who the shop says it is — the parts that sit outside any one page.
-- =====================================================================================
ALTER TABLE mystoreguard.msg_ecommerce_settings
    -- The line under the logo in the footer.
    ADD COLUMN IF NOT EXISTS tagline text,
    -- The line along the bottom. Empty gets "© <year> <storefront name>".
    ADD COLUMN IF NOT EXISTS copyright_text text,
    ADD COLUMN IF NOT EXISTS logo_document_id text,
    -- Full profile URLs rather than handles: a handle needs the storefront to
    -- know each network's URL shape, and that is one more thing to get wrong for
    -- whichever network comes next.
    ADD COLUMN IF NOT EXISTS social_facebook text,
    ADD COLUMN IF NOT EXISTS social_instagram text,
    ADD COLUMN IF NOT EXISTS social_x text,
    ADD COLUMN IF NOT EXISTS social_youtube text,
    ADD COLUMN IF NOT EXISTS social_tiktok text,
    ADD COLUMN IF NOT EXISTS contact_email text,
    ADD COLUMN IF NOT EXISTS contact_phone text;


-- =====================================================================================
-- 5. The footer, as columns of links.
--
--    Two tables rather than a column_title repeated on every link: renaming a
--    column is then one write instead of four, and a column with no links left
--    in it still exists to put one back into.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_ecommerce_footer_columns (
    id          text        PRIMARY KEY,
    tenant_id   text        NOT NULL,
    org_id      text        NOT NULL,
    bus_id      text        NOT NULL,

    title       text        NOT NULL,
    sort_order  integer     NOT NULL DEFAULT 0,

    cdate       date,
    ctime       time,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    udatetime   timestamptz,
    created_by  text,
    updated_by  text,
    deleted_by  text
);

CREATE INDEX IF NOT EXISTS ix_msg_ecommerce_footer_columns_bus
    ON mystoreguard.msg_ecommerce_footer_columns (tenant_id, org_id, bus_id, sort_order)
    WHERE deleted_by IS NULL;

CREATE TABLE IF NOT EXISTS mystoreguard.msg_ecommerce_footer_links (
    id              text        PRIMARY KEY,
    tenant_id       text        NOT NULL,
    org_id          text        NOT NULL,
    bus_id          text        NOT NULL,
    column_id       text        NOT NULL
        REFERENCES mystoreguard.msg_ecommerce_footer_columns (id) ON DELETE CASCADE,

    label           text        NOT NULL,

    -- Same three ways to point somewhere as a section card, and the same order of
    -- preference. A link to a page disappears from the footer when that page is
    -- switched off; a typed URL is the shop's own business and is left alone.
    link_page_key   text,
    link_version_id text,
    link_url        text,

    sort_order      integer     NOT NULL DEFAULT 0,
    is_visible      boolean     NOT NULL DEFAULT true,

    cdate           date,
    ctime           time,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    udatetime       timestamptz,
    created_by      text,
    updated_by      text,
    deleted_by      text
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_ecommerce_footer_links_link'
    ) THEN
        ALTER TABLE mystoreguard.msg_ecommerce_footer_links
            ADD CONSTRAINT ck_msg_ecommerce_footer_links_link CHECK (
                link_page_key IS NULL
                OR link_page_key IN (
                    'BIDDING', 'DAILY_OFFER', 'INSTALLMENT', 'MARKET', 'PRE_USED'
                )
            );
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_msg_ecommerce_footer_links_column
    ON mystoreguard.msg_ecommerce_footer_links (column_id, sort_order)
    WHERE deleted_by IS NULL;
