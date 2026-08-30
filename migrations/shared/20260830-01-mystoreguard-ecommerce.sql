-- 20260830-01-mystoreguard-ecommerce.sql
-- Pushing MyStoreGuard stock onto the ecommerce storefront.
--
-- Everything here is BUSINESS-wide, with no loc_id. A storefront is one shop
-- window: a shopper does not pick a branch before browsing, and the same item
-- listed twice because two branches both stock it is a bug, not a feature.
-- Locations appear only as a *filter* — which branches' stock feeds the window
-- — which is what msg_ecommerce_settings.location_ids is. That is also why the
-- old per-location switch (msg_store_configs.is_visible_on_ecommerce) is
-- retired below: a boolean sitting on one branch's configuration screen could
-- never answer "what is on the site", and nothing ever read it.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================================
-- 1. The configuration itself. One row per business.
--
--    Absent means the storefront is off, which is how every business behaved before
--    this existed — so the service returns defaults for a missing row rather than a
--    404, and nothing starts selling because a table was created.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_ecommerce_settings (
    id                          text        PRIMARY KEY,
    tenant_id                   text        NOT NULL,
    org_id                      text        NOT NULL,
    bus_id                      text        NOT NULL,

    is_enabled                  boolean     NOT NULL DEFAULT false,

    -- Which branches' stock feeds the window. 'ALL' ignores location_ids entirely
    -- rather than snapshotting today's list, so a branch opened next month is
    -- included without anyone remembering to come back here.
    location_scope              text        NOT NULL DEFAULT 'SELECTED',
    location_ids                text[]      NOT NULL DEFAULT '{}',

    -- Which of those branches' products get listed.
    --   ALL       — everything in stock at an included location
    --   METADATA  — everything carrying the named tags/categories/brands/labels
    --   SELECTED  — only the products named in product_ids
    -- METADATA is the one worth having: it is a standing rule, so a product
    -- tagged "Online" tomorrow appears without a second visit to this screen.
    product_scope               text        NOT NULL DEFAULT 'ALL',
    product_ids                 text[]      NOT NULL DEFAULT '{}',
    -- msg_product_metadata ids. Mixed types (a brand and two tags) are allowed;
    -- metadata_match decides whether a product needs one of them or all of them.
    metadata_ids                text[]      NOT NULL DEFAULT '{}',
    metadata_match              text        NOT NULL DEFAULT 'ANY',

    -- Whose pictures the storefront shows.
    --   STORE      — whatever is already on the product in MyStoreGuard
    --   ECOMMERCE  — only the pictures uploaded for the storefront
    --   BOTH       — storefront pictures first, then the store's
    -- Set per product too (msg_ecommerce_products.image_source); this is the
    -- default for products that say nothing.
    image_source                text        NOT NULL DEFAULT 'STORE',

    -- What several pictures of one product MEAN.
    --   SINGLE   — one listing with a gallery. Ten photos of the same phone from
    --              ten angles is one phone.
    --   MULTIPLE — one listing per picture. Ten photos of ten different phones is
    --              ten phones.
    -- This is the whole point of the images work: without it the only way to show
    -- a red one and a blue one is to create two products carrying identical data.
    -- With SINGLE plus variant_key on the images, one product covers both.
    image_grouping              text        NOT NULL DEFAULT 'SINGLE',

    -- Where the storefront's prices come from.
    --   STORE                — the same prices the tills use
    --   ECOMMERCE            — only prices/rules recorded on the ECOMMERCE channel;
    --                          a product with none is not priced and is not listed
    --   ECOMMERCE_THEN_STORE — the ecommerce price when there is one, else the store's
    -- The last is the useful default for a shop that wants to override a handful of
    -- items rather than re-price its whole catalogue.
    price_source                text        NOT NULL DEFAULT 'ECOMMERCE_THEN_STORE',

    -- Buying on installment, and paying an existing plan, are separate switches on
    -- purpose. A shop may well want customers to settle a plan online without
    -- letting anyone open a new one unattended.
    allow_installment_purchase  boolean     NOT NULL DEFAULT false,
    allow_installment_payment   boolean     NOT NULL DEFAULT false,

    -- Selling something the shop does not have is the one failure a storefront
    -- cannot apologise its way out of, so this defaults to hiding.
    hide_out_of_stock           boolean     NOT NULL DEFAULT true,
    -- Stock at or below this counts as out. 0 means "only actually zero".
    out_of_stock_threshold      integer     NOT NULL DEFAULT 0,

    -- What the storefront calls this business. Empty falls back to the business
    -- name from core_platform, which is right for the single-business tenant.
    storefront_name             text,
    storefront_slug             text,

    cdate                       date,
    ctime                       time,
    cdatetime                   timestamptz NOT NULL DEFAULT now(),
    udatetime                   timestamptz,
    created_by                  text,
    updated_by                  text,
    deleted_by                  text
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_ecommerce_settings_business
    ON mystoreguard.msg_ecommerce_settings (tenant_id, org_id, bus_id);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_ecommerce_settings_scopes') THEN
        ALTER TABLE mystoreguard.msg_ecommerce_settings
            ADD CONSTRAINT ck_msg_ecommerce_settings_scopes CHECK (
                location_scope IN ('ALL', 'SELECTED')
                AND product_scope  IN ('ALL', 'METADATA', 'SELECTED')
                AND metadata_match IN ('ANY', 'ALL')
                AND image_source   IN ('STORE', 'ECOMMERCE', 'BOTH')
                AND image_grouping IN ('SINGLE', 'MULTIPLE')
                AND price_source   IN ('STORE', 'ECOMMERCE', 'ECOMMERCE_THEN_STORE')
                AND out_of_stock_threshold >= 0
            );
    END IF;
END $$;

-- A slug is what a storefront URL is built from, so two businesses cannot share
-- one. Partial, because most businesses will leave it empty and NULLs must not
-- collide with each other.
CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_ecommerce_settings_slug
    ON mystoreguard.msg_ecommerce_settings (storefront_slug)
    WHERE storefront_slug IS NOT NULL AND deleted_by IS NULL;


-- =====================================================================================
-- 2. Per-product exceptions.
--
--    A row here exists only for a product that DEVIATES from the settings above —
--    pulled off the site, given its own picture policy, described differently. The
--    catalogue is resolved from the rule plus these exceptions, never enumerated
--    into a table, so a shop with four thousand products and two exceptions stores
--    two rows.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_ecommerce_products (
    id              text        PRIMARY KEY,
    tenant_id       text        NOT NULL,
    org_id          text        NOT NULL,
    bus_id          text        NOT NULL,
    product_id      text        NOT NULL,

    --   DEFAULT  — follow the rule in msg_ecommerce_settings
    --   INCLUDED — list it even if the rule would not have
    --   EXCLUDED — never list it, whatever the rule says
    listing_status  text        NOT NULL DEFAULT 'DEFAULT',

    -- NULL means "use the business default". Only a product that genuinely wants
    -- different treatment overrides them.
    image_source    text,
    image_grouping  text,

    -- Which storefront page this product belongs on by nature. Pre-used items are
    -- a different thing to sell, not a different way of selling the same thing —
    -- the Pre-used page reads this, and a version can still place anything anywhere.
    condition       text        NOT NULL DEFAULT 'NEW',
    condition_note  text,

    -- What the shopper reads. Falls back to the product's own name/description.
    headline        text,
    description     text,

    cdate           date,
    ctime           time,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    udatetime       timestamptz,
    created_by      text,
    updated_by      text,
    deleted_by      text
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_ecommerce_products_product
    ON mystoreguard.msg_ecommerce_products (tenant_id, org_id, bus_id, product_id);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_ecommerce_products_enums') THEN
        ALTER TABLE mystoreguard.msg_ecommerce_products
            ADD CONSTRAINT ck_msg_ecommerce_products_enums CHECK (
                listing_status IN ('DEFAULT', 'INCLUDED', 'EXCLUDED')
                AND (image_source   IS NULL OR image_source   IN ('STORE', 'ECOMMERCE', 'BOTH'))
                AND (image_grouping IS NULL OR image_grouping IN ('SINGLE', 'MULTIPLE'))
                AND condition IN ('NEW', 'PRE_USED', 'REFURBISHED')
            );
    END IF;
END $$;


-- =====================================================================================
-- 3. Storefront pictures.
--
--    Kept apart from msg_product_document_ids rather than added to it. Those are the
--    shop's own record of a product — a photo of the box, a warranty scan — and a
--    storefront picture is merchandising: cropped, ordered, captioned, and safe to
--    replace without touching what the shop filed.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_ecommerce_product_images (
    id            text        PRIMARY KEY,
    tenant_id     text        NOT NULL,
    org_id        text        NOT NULL,
    bus_id        text        NOT NULL,
    product_id    text        NOT NULL,

    -- One of the two. document_id points at msg_document_paths (uploaded through the
    -- file manager, served as a presigned URL); external_url is for a picture already
    -- hosted somewhere the storefront can reach.
    document_id   text,
    external_url  text,

    alt_text      text,
    sort_order    integer     NOT NULL DEFAULT 0,
    is_primary    boolean     NOT NULL DEFAULT false,

    -- What makes several pictures one listing or several.
    --
    -- Under image_grouping = 'SINGLE' the whole set is one listing and variant_key
    -- splits it into pickable options — "Red", "Blue" — sharing the product's price
    -- and stock. Under 'MULTIPLE' each distinct variant_key becomes its own listing.
    -- Images with no key are the plain gallery either way.
    variant_key   text,
    variant_label text,

    is_active     boolean     NOT NULL DEFAULT true,

    cdate         date,
    ctime         time,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    udatetime     timestamptz,
    created_by    text,
    updated_by    text,
    deleted_by    text
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_ecommerce_product_images_source') THEN
        ALTER TABLE mystoreguard.msg_ecommerce_product_images
            ADD CONSTRAINT ck_msg_ecommerce_product_images_source
            CHECK (document_id IS NOT NULL OR external_url IS NOT NULL);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_msg_ecommerce_product_images_product
    ON mystoreguard.msg_ecommerce_product_images (tenant_id, org_id, bus_id, product_id)
    WHERE deleted_by IS NULL;

-- One primary per product: the picture the grid shows. Partial so retired images
-- and the many non-primary ones never collide.
CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_ecommerce_product_images_primary
    ON mystoreguard.msg_ecommerce_product_images (tenant_id, org_id, bus_id, product_id)
    WHERE is_primary AND deleted_by IS NULL;


-- =====================================================================================
-- 4. Versions — the merchandising unit.
--
--    A version is a named, orderable set of items aimed at one storefront page. The
--    site shows the PROMOTED versions for a page and nothing else, so a version is
--    both the thing you build and the switch that publishes it: several may be
--    promoted at once and they stack by priority.
--
--    Drafting next month's Market alongside this month's is the point. Neither the
--    unpromoted draft nor an expired one is visible, and promoting is one column.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_ecommerce_versions (
    id            text        PRIMARY KEY,
    tenant_id     text        NOT NULL,
    org_id        text        NOT NULL,
    bus_id        text        NOT NULL,

    -- HOME is listed for completeness but a HOME version is unusual: the home page
    -- is normally composed of sections pointing at the other pages' versions
    -- (table 6). It exists so a shop can hand-build a home selection if it wants one.
    page_key      text        NOT NULL,

    name          text        NOT NULL,
    description   text,

    -- Promoted decides visibility; priority orders the promoted ones against each
    -- other, highest first. Two promoted Market versions show as two blocks, not a
    -- fight over which wins.
    is_promoted   boolean     NOT NULL DEFAULT false,
    priority      integer     NOT NULL DEFAULT 0,

    -- The window in which promotion actually counts. NULL/NULL means "while
    -- promoted, indefinitely" — the ordinary case. A dated window is how a
    -- weekend sale takes itself down without anyone being at a desk on Sunday.
    starts_at     timestamptz,
    ends_at       timestamptz,

    status        text        NOT NULL DEFAULT 'DRAFT',
    layout        text        NOT NULL DEFAULT 'GRID',
    -- How many of its items the storefront shows. NULL = all of them.
    item_limit    integer,

    cdate         date,
    ctime         time,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    udatetime     timestamptz,
    created_by    text,
    updated_by    text,
    deleted_by    text
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_ecommerce_versions_enums') THEN
        ALTER TABLE mystoreguard.msg_ecommerce_versions
            ADD CONSTRAINT ck_msg_ecommerce_versions_enums CHECK (
                page_key IN ('HOME', 'BIDDING', 'PRE_USED', 'MARKET')
                AND status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED')
                AND layout IN ('GRID', 'CAROUSEL', 'HERO', 'LIST')
                AND (item_limit IS NULL OR item_limit > 0)
                AND (starts_at IS NULL OR ends_at IS NULL OR ends_at > starts_at)
            );
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_msg_ecommerce_versions_page
    ON mystoreguard.msg_ecommerce_versions (tenant_id, org_id, bus_id, page_key)
    WHERE deleted_by IS NULL;

-- Two versions of the same page called the same thing is a naming accident, not a
-- use case, and the promote/preview screens address them by name.
CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_ecommerce_versions_name
    ON mystoreguard.msg_ecommerce_versions (tenant_id, org_id, bus_id, page_key, lower(name))
    WHERE deleted_by IS NULL;


-- =====================================================================================
-- 5. What is in a version.
--
--    A row is one tile on the site. It names a product, and optionally the exact
--    picture — which is what lets the blue one and the red one appear as two tiles of
--    one product rather than as two products.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_ecommerce_version_items (
    id             text        PRIMARY KEY,
    tenant_id      text        NOT NULL,
    org_id         text        NOT NULL,
    bus_id         text        NOT NULL,
    version_id     text        NOT NULL
        REFERENCES mystoreguard.msg_ecommerce_versions (id) ON DELETE CASCADE,

    product_id     text        NOT NULL,
    -- msg_ecommerce_product_images.id. NULL means the product's primary picture.
    image_id       text,

    sort_order     integer     NOT NULL DEFAULT 0,
    headline       text,
    badge          text,

    -- Set only when this tile is priced differently from everywhere else — a
    -- doorbuster. Empty means the storefront prices it the ordinary way, through
    -- price_source, so a version does not quietly freeze prices at the moment it
    -- was built.
    price_override numeric(18, 2),
    currency       text,

    -- Bidding. Required by the service for items in a BIDDING version and ignored
    -- elsewhere; a CHECK here cannot see the parent's page_key, which is why it is
    -- validated in the service rather than pretended at in the schema.
    bid_starts_at  timestamptz,
    bid_ends_at    timestamptz,
    starting_bid   numeric(18, 2),
    bid_increment  numeric(18, 2),
    -- Below this the shop is not obliged to sell. Never shown to bidders.
    reserve_price  numeric(18, 2),

    is_active      boolean     NOT NULL DEFAULT true,

    cdate          date,
    ctime          time,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    udatetime      timestamptz,
    created_by     text,
    updated_by     text,
    deleted_by     text
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_ecommerce_version_items_bidding') THEN
        ALTER TABLE mystoreguard.msg_ecommerce_version_items
            ADD CONSTRAINT ck_msg_ecommerce_version_items_bidding CHECK (
                (bid_starts_at IS NULL OR bid_ends_at IS NULL OR bid_ends_at > bid_starts_at)
                AND (price_override  IS NULL OR price_override  >= 0)
                AND (starting_bid    IS NULL OR starting_bid    >= 0)
                AND (bid_increment   IS NULL OR bid_increment   >  0)
                AND (reserve_price   IS NULL OR reserve_price   >= 0)
            );
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_msg_ecommerce_version_items_version
    ON mystoreguard.msg_ecommerce_version_items (version_id)
    WHERE deleted_by IS NULL;

-- The same product may appear twice in one version only as two different pictures
-- (the red and the blue). Twice as the same picture is a double-click.
CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_ecommerce_version_items_slot
    ON mystoreguard.msg_ecommerce_version_items (version_id, product_id, COALESCE(image_id, ''))
    WHERE deleted_by IS NULL;


-- =====================================================================================
-- 6. The home page's composition.
--
--    The home page is a stack of sections, each borrowing a version from one of the
--    other pages — which is exactly how it reads on the site: a bidding strip, a
--    pre-used block, the market grid. Storing it as rows rather than as code is what
--    lets two tenants have different home pages.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_ecommerce_home_sections (
    id               text        PRIMARY KEY,
    tenant_id        text        NOT NULL,
    org_id           text        NOT NULL,
    bus_id           text        NOT NULL,

    --   HERO     — the banner at the top
    --   BIDDING / PRE_USED / MARKET — a strip of that page's items
    --   CUSTOM   — a strip of whatever version is named
    section_key      text        NOT NULL,

    title            text,
    subtitle         text,
    cta_label        text,
    cta_href         text,

    -- Which page's items fill it, and optionally exactly which version. With
    -- version_id empty the section follows whatever is promoted for that page —
    -- so promoting next month's Market updates the home page too, with nobody
    -- having to remember this screen exists.
    source_page_key  text,
    version_id       text
        REFERENCES mystoreguard.msg_ecommerce_versions (id) ON DELETE SET NULL,

    item_limit       integer     NOT NULL DEFAULT 8,
    layout           text        NOT NULL DEFAULT 'GRID',
    sort_order       integer     NOT NULL DEFAULT 0,
    is_visible       boolean     NOT NULL DEFAULT true,

    cdate            date,
    ctime            time,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    udatetime        timestamptz,
    created_by       text,
    updated_by       text,
    deleted_by       text
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_ecommerce_home_sections_enums') THEN
        ALTER TABLE mystoreguard.msg_ecommerce_home_sections
            ADD CONSTRAINT ck_msg_ecommerce_home_sections_enums CHECK (
                section_key IN ('HERO', 'BIDDING', 'PRE_USED', 'MARKET', 'CUSTOM')
                AND (source_page_key IS NULL OR source_page_key IN ('BIDDING', 'PRE_USED', 'MARKET'))
                AND layout IN ('GRID', 'CAROUSEL', 'HERO', 'LIST')
                AND item_limit > 0
            );
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_msg_ecommerce_home_sections_business
    ON mystoreguard.msg_ecommerce_home_sections (tenant_id, org_id, bus_id, sort_order)
    WHERE deleted_by IS NULL;


-- =====================================================================================
-- 7. Prices and pricing rules get a channel.
--
--    "Full price control for ecommerce only" could have been a second pair of tables.
--    It is a column instead: a price is a price, and the rules for choosing between
--    them — specificity, priority, stops_other_prices — are the same rules whichever
--    window the shopper is standing at. Two tables would mean two copies of that
--    resolution logic, and the second copy is the one that drifts.
--
--    Default 'STORE' on every existing row, and every existing query filters to
--    'STORE', so the tills carry on seeing exactly what they saw yesterday.
-- =====================================================================================
ALTER TABLE mystoreguard.msg_product_prices
    ADD COLUMN IF NOT EXISTS channel text NOT NULL DEFAULT 'STORE';

ALTER TABLE mystoreguard.msg_pricing_rule
    ADD COLUMN IF NOT EXISTS channel text NOT NULL DEFAULT 'STORE';

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_product_prices_channel') THEN
        ALTER TABLE mystoreguard.msg_product_prices
            ADD CONSTRAINT ck_msg_product_prices_channel CHECK (channel IN ('STORE', 'ECOMMERCE'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_pricing_rule_channel') THEN
        ALTER TABLE mystoreguard.msg_pricing_rule
            ADD CONSTRAINT ck_msg_pricing_rule_channel CHECK (channel IN ('STORE', 'ECOMMERCE'));
    END IF;
END $$;

-- The uniqueness of a price is now per channel — the same product may carry a GLOBAL
-- price for the tills and a different GLOBAL price for the site, and that is the
-- entire feature. Replaces idx_msg_product_prices_unique from
-- MyStoreGuard/Sql/Triggers/01_product_prices_unique_index.sql, which that file now
-- skips creating once this column exists.
CREATE UNIQUE INDEX IF NOT EXISTS idx_msg_product_prices_unique_channel
    ON mystoreguard.msg_product_prices
       (tenant_id, org_id, bus_id, channel, product_id, of_type, COALESCE(target_id, ''));

DROP INDEX IF EXISTS mystoreguard.idx_msg_product_prices_unique;

CREATE INDEX IF NOT EXISTS ix_msg_pricing_rule_channel
    ON mystoreguard.msg_pricing_rule (tenant_id, org_id, bus_id, channel);


-- =====================================================================================
-- 8. Retiring msg_store_configs.is_visible_on_ecommerce.
--
--    The column is left in place rather than dropped: dropping it breaks any
--    already-running API pod mid-deploy, and it costs a boolean per store to keep.
--    Nothing reads or writes it after this release.
--
--    Its values are not thrown away. A business that had ticked the box on some of
--    its branches gets exactly those branches as its starting location list, so the
--    intent someone recorded on the old screen is what the new one opens with. Only
--    for businesses with no settings row yet — re-running this must never overwrite
--    a list somebody has since edited.
-- =====================================================================================
COMMENT ON COLUMN mystoreguard.msg_store_configs.is_visible_on_ecommerce IS
    'DEPRECATED 20260830. Superseded by mystoreguard.msg_ecommerce_settings.location_ids, '
    'which is business-wide. Retained only so the backfill below stays re-runnable and '
    'so a rollback has something to read; no code reads or writes it.';

INSERT INTO mystoreguard.msg_ecommerce_settings (
    id, tenant_id, org_id, bus_id,
    is_enabled, location_scope, location_ids,
    cdate, ctime, cdatetime, created_by
)
SELECT
    'ecs-migrated-' || md5(sc.tenant_id || ':' || sc.org_id || ':' || sc.bus_id),
    sc.tenant_id, sc.org_id, sc.bus_id,
    -- Ticked boxes recorded an intention, not a live storefront — nothing served
    -- from them. Switching the site on for a business that has configured nothing
    -- else would be this migration deciding to start trading on their behalf.
    false,
    'SELECTED',
    array_agg(DISTINCT sc.loc_id),
    now()::date, now()::time, now(), 'migration-20260830-01'
FROM mystoreguard.msg_store_configs sc
WHERE sc.is_visible_on_ecommerce = true
  AND sc.deleted_by IS NULL
GROUP BY sc.tenant_id, sc.org_id, sc.bus_id
ON CONFLICT (tenant_id, org_id, bus_id) DO NOTHING;


-- =====================================================================================
-- 9. Plan gating.
--
--    PREMIUM. A storefront is not a cheaper way to do what BASIC already does — it is
--    a second place to sell — and it sits alongside loyalty and offers, which is the
--    tier a shop reaches when it has started merchandising rather than just recording.
--
--    ecommerce.pricing is separate so a tenant can be sold the storefront without the
--    per-channel price control, and gates nothing else: the ordinary Settings pricing
--    screens keep their own settings.product-prices / settings.pricing-rules keys.
-- =====================================================================================
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('ecommerce',            'app-mystoreguard', 'Ecommerce',            3, 'The storefront module itself: overview, setup, products and images'),
('ecommerce.storefront', 'app-mystoreguard', 'Storefront Pages',     3, 'Versions and promotion for Home, Pre-used and Market'),
('ecommerce.bidding',    'app-mystoreguard', 'Bidding',              3, 'Timed auctions on the storefront'),
('ecommerce.pricing',    'app-mystoreguard', 'Ecommerce Pricing',    3, 'Prices and pricing rules recorded against the ECOMMERCE channel')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description;
