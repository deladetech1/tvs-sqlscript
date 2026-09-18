-- A shop builds its own storefront pages, of four kinds.
--
-- Until now a storefront had exactly five pages, named in a CHECK constraint:
-- Bidding, Market, Pre-used, Daily offers, Instalments. A shop could rename one
-- and switch it off, and that was the whole of it. Two shops selling different
-- things got the same five headings, and a shop wanting a sixth — a clearance
-- run, a seasonal page, a second auction night — had nowhere to put it.
--
-- Pages become rows a shop creates. What a page IS comes from its type:
--
--   NORMAL     a catalogue page, and what most pages are
--   BIDDING    items go to auction, within a window, with bid rules
--   PRE_USED   second-hand and refurbished goods, filtered by condition
--   QUICK_BUY  a time-boxed offer, with a limit on what one shopper can take
--
-- page_key stays the stable identifier and stays unique per business, because
-- versions, bands and footer links all point at pages through it. A page a shop
-- makes gets a key of its own rather than a new kind of reference, so nothing
-- that already works has to learn a second way to name a page.
--
-- Moves no stock and touches no order.

-- ---------------------------------------------------------------- the pages --
ALTER TABLE mystoreguard.msg_ecommerce_pages
    -- The address. Separate from page_key because a key is forever and an
    -- address is a shop's to change; and because "PRE_USED" is not something to
    -- put in front of a customer.
    ADD COLUMN IF NOT EXISTS slug text,
    -- What kind of page this is, and therefore what it does.
    ADD COLUMN IF NOT EXISTS page_type text NOT NULL DEFAULT 'NORMAL',
    -- The one page that is always there. A storefront with no home page is a
    -- domain that answers nothing.
    ADD COLUMN IF NOT EXISTS is_home boolean NOT NULL DEFAULT false,
    -- Whether it appears in the shop's own navigation. Off is useful: a page
    -- reached only from a campaign link is still a page.
    ADD COLUMN IF NOT EXISTS show_in_nav boolean NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS subtitle text,

    -- When the page is live, for the kinds that are an event rather than a
    -- shelf. Null at either end means open-ended, which is the ordinary case.
    ADD COLUMN IF NOT EXISTS starts_at timestamptz,
    ADD COLUMN IF NOT EXISTS ends_at timestamptz,

    -- BIDDING. Defaults are null on purpose: a page that says nothing falls
    -- back to the shop's own bidding settings, so a shop running one auction
    -- night a week does not restate its rules on every page.
    ADD COLUMN IF NOT EXISTS bid_coins_per_bid integer,
    ADD COLUMN IF NOT EXISTS bid_min_increment numeric(18,2),
    -- Seconds added when a bid lands near the end. Without it the last second
    -- decides the auction, and the shopper with the better connection wins.
    ADD COLUMN IF NOT EXISTS bid_anti_snipe_seconds integer,

    -- QUICK_BUY. A limit per shopper is what stops one person taking the lot
    -- the moment the window opens.
    ADD COLUMN IF NOT EXISTS quick_buy_limit_per_customer integer,
    ADD COLUMN IF NOT EXISTS quick_buy_max_qty integer,

    -- PRE_USED. Which conditions belong on the page. Null means the page's own
    -- type decides: pre-used and refurbished.
    ADD COLUMN IF NOT EXISTS conditions text[],

    -- The filter a shop actually thinks in: its own product metadata. Empty
    -- means the page carries whatever the storefront lists.
    ADD COLUMN IF NOT EXISTS metadata_ids text[],
    ADD COLUMN IF NOT EXISTS metadata_match text NOT NULL DEFAULT 'ANY';

-- The old CHECK named the five pages that were allowed to exist. That is the
-- constraint this whole change is about removing.
ALTER TABLE mystoreguard.msg_ecommerce_pages
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_pages_keys,
    -- Dropped before being added because ADD CONSTRAINT has no IF NOT EXISTS,
    -- and a migration that cannot be run twice is one that fails the day the
    -- pipeline replays it.
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_pages_type,
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_pages_match,
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_pages_home_on,
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_pages_window;

ALTER TABLE mystoreguard.msg_ecommerce_pages
    ADD CONSTRAINT ck_msg_ecommerce_pages_type
        CHECK (page_type = ANY (ARRAY['NORMAL','BIDDING','PRE_USED','QUICK_BUY'])),
    ADD CONSTRAINT ck_msg_ecommerce_pages_match
        CHECK (metadata_match = ANY (ARRAY['ANY','ALL'])),
    -- The home page is always on. Switching it off is not a state a storefront
    -- can be in, and a nullable "is it on" on the one required page is a bug
    -- waiting for a quiet afternoon.
    ADD CONSTRAINT ck_msg_ecommerce_pages_home_on
        CHECK (NOT is_home OR is_enabled),
    -- A window that ends before it starts is not a window.
    ADD CONSTRAINT ck_msg_ecommerce_pages_window
        CHECK (starts_at IS NULL OR ends_at IS NULL OR ends_at > starts_at);

-- Addresses have to be unique per shop, or two pages answer to one URL and
-- which one a customer gets is down to row order.
CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_ecommerce_pages_slug
    ON mystoreguard.msg_ecommerce_pages (tenant_id, org_id, bus_id, lower(slug))
    WHERE deleted_by IS NULL AND slug IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_ecommerce_pages_key
    ON mystoreguard.msg_ecommerce_pages (tenant_id, org_id, bus_id, page_key)
    WHERE deleted_by IS NULL;

-- One home page per shop.
CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_ecommerce_pages_home
    ON mystoreguard.msg_ecommerce_pages (tenant_id, org_id, bus_id)
    WHERE is_home AND deleted_by IS NULL;

-- ------------------------------------------------------- what shops have now --
-- The five built-ins become ordinary rows of the right type, so from here there
-- is one kind of page and no special cases in the code that reads them.
UPDATE mystoreguard.msg_ecommerce_pages SET
    slug = CASE page_key
        WHEN 'MARKET' THEN 'market'
        WHEN 'BIDDING' THEN 'bidding'
        WHEN 'PRE_USED' THEN 'pre-used'
        WHEN 'DAILY_OFFER' THEN 'daily-offers'
        WHEN 'INSTALLMENT' THEN 'instalments'
        ELSE lower(replace(page_key, '_', '-')) END,
    page_type = CASE page_key
        WHEN 'BIDDING' THEN 'BIDDING'
        WHEN 'PRE_USED' THEN 'PRE_USED'
        WHEN 'DAILY_OFFER' THEN 'QUICK_BUY'
        ELSE 'NORMAL' END
 WHERE slug IS NULL;

-- Every shop with a storefront gets the home page it has always had in effect
-- but never had a row for.
INSERT INTO mystoreguard.msg_ecommerce_pages
    (id, tenant_id, org_id, bus_id, page_key, slug, page_type, is_home,
     is_enabled, show_in_nav, label, nav_sort_order, cdate, ctime, cdatetime,
     created_by)
SELECT 'ecp_' || replace(gen_random_uuid()::text, '-', ''),
       s.tenant_id, s.org_id, s.bus_id, 'HOME', 'home', 'NORMAL', true,
       true, true, 'Home', 0, CURRENT_DATE, CURRENT_TIME, NOW(), s.created_by
       -- Order 0 rather than -1: the home page sorts first because it IS the
       -- home page, not because of a number, and a position below zero is a
       -- value every reader of this column then has to allow for.
  FROM mystoreguard.msg_ecommerce_settings s
 WHERE NOT EXISTS (
        SELECT 1 FROM mystoreguard.msg_ecommerce_pages p
         WHERE p.tenant_id = s.tenant_id AND p.org_id = s.org_id
           AND p.bus_id = s.bus_id AND p.page_key = 'HOME'
           AND p.deleted_by IS NULL);

-- ------------------------------------------------------------ custom domain --
-- A shop already gets a subdomain from its slug. This is the other half: its
-- own name over the door.
--
-- Verified separately from stored, because DNS is somebody else's system and
-- pointing at us is not the same as having pointed at us. The token is what a
-- shop puts in a TXT record to prove the name is theirs.
ALTER TABLE mystoreguard.msg_ecommerce_settings
    ADD COLUMN IF NOT EXISTS custom_domain text,
    ADD COLUMN IF NOT EXISTS custom_domain_verified boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS custom_domain_token text,
    ADD COLUMN IF NOT EXISTS custom_domain_checked_at timestamptz;

-- One domain, one shop. Without this two shops can claim one name and the
-- storefront serves whichever row comes back first.
CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_ecommerce_settings_domain
    ON mystoreguard.msg_ecommerce_settings (lower(custom_domain))
    WHERE custom_domain IS NOT NULL AND deleted_by IS NULL;

-- ------------------------------------------------- instalments, per product --
-- An item can be part of an instalment plan. Being part of one does not take
-- away paying for it outright: both routes stay open, and the policy decides
-- the terms of the slower one.
ALTER TABLE mystoreguard.msg_ecommerce_products
    ADD COLUMN IF NOT EXISTS installment_enabled boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS installment_policy_id text;

COMMENT ON COLUMN mystoreguard.msg_ecommerce_products.installment_enabled IS
    'This item can be taken on an instalment plan. Buying it outright stays available either way.';
