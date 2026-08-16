-- =====================================================================
-- Receipt customisation
-- ---------------------------------------------------------------------
-- What a printed sale receipt shows is currently fixed in the frontend:
-- 80mm paper, the business name, and a set of money lines that appear
-- whether or not the business uses them. A shop that never issues gift
-- cards still gets the gift card row reserved, and one printing on 58mm
-- paper gets a receipt that does not fit.
--
-- This table holds one template per business, and optionally one per
-- location that overrides it:
--
--   loc_id IS NULL   the business default. Every location prints this
--                    unless it has its own row.
--   loc_id = '...'   that location's override. Read instead of the
--                    default, never merged with it — a half-inherited
--                    receipt is impossible to reason about when a branch
--                    wants a shorter footer but the same everything else.
--
-- Resolution is therefore: the location's row if one exists, else the
-- business row, else the column defaults below. The defaults reproduce
-- what the receipt printed before this table existed, so a business that
-- never opens the settings page sees no change.
--
-- Every show_* column defaults to the current behaviour rather than to
-- true. show_affiliate and show_loyalty default false because neither has
-- ever appeared on a receipt, and turning them on for everyone at once
-- would surprise businesses that treat affiliate attribution as internal.
--
-- Runs after the EF migrations on every deploy. Idempotent; safe to re-run.
-- =====================================================================

CREATE TABLE IF NOT EXISTS mystoreguard.msg_receipt_settings (
    id         text PRIMARY KEY,
    tenant_id  text NOT NULL,
    org_id     text NOT NULL,
    bus_id     text NOT NULL,
    -- NULL means the business default. See the note above.
    loc_id     text,

    -- Paper -----------------------------------------------------------
    paper_size text NOT NULL DEFAULT '80MM',
    font_scale text NOT NULL DEFAULT 'NORMAL',

    -- Header ----------------------------------------------------------
    show_logo             boolean NOT NULL DEFAULT false,
    logo_document_id      text,
    show_business_name    boolean NOT NULL DEFAULT true,
    show_location_name    boolean NOT NULL DEFAULT true,
    show_location_address boolean NOT NULL DEFAULT false,
    show_location_contact boolean NOT NULL DEFAULT false,
    header_text           text,

    -- The sale ---------------------------------------------------------
    show_sale_number      boolean NOT NULL DEFAULT true,
    show_date             boolean NOT NULL DEFAULT true,
    show_time             boolean NOT NULL DEFAULT true,
    show_cashier          boolean NOT NULL DEFAULT false,
    show_customer         boolean NOT NULL DEFAULT true,
    show_customer_contact boolean NOT NULL DEFAULT false,
    show_sale_mode        boolean NOT NULL DEFAULT true,
    show_payment_status   boolean NOT NULL DEFAULT false,

    -- The lines --------------------------------------------------------
    show_item_sku         boolean NOT NULL DEFAULT false,
    show_item_quantity    boolean NOT NULL DEFAULT true,
    show_item_unit_price  boolean NOT NULL DEFAULT true,
    show_item_tax         boolean NOT NULL DEFAULT true,

    -- The money --------------------------------------------------------
    show_subtotal         boolean NOT NULL DEFAULT true,
    -- Every tax named on its own line, rather than one combined figure.
    -- Off by default: the receipt has always shown a single tax total.
    show_tax_breakdown    boolean NOT NULL DEFAULT false,
    show_tax_total        boolean NOT NULL DEFAULT true,
    show_discount         boolean NOT NULL DEFAULT true,
    show_promo_code       boolean NOT NULL DEFAULT true,
    show_gift_card        boolean NOT NULL DEFAULT true,
    show_store_credit     boolean NOT NULL DEFAULT true,
    show_loyalty          boolean NOT NULL DEFAULT false,
    show_affiliate        boolean NOT NULL DEFAULT false,
    show_amount_paid      boolean NOT NULL DEFAULT true,
    show_balance          boolean NOT NULL DEFAULT true,
    show_change           boolean NOT NULL DEFAULT true,

    -- Footer -----------------------------------------------------------
    footer_text           text,
    show_return_policy    boolean NOT NULL DEFAULT false,
    return_policy_text    text,
    show_sale_barcode     boolean NOT NULL DEFAULT false,
    show_powered_by       boolean NOT NULL DEFAULT true,

    -- Audit ------------------------------------------------------------
    cdate      date,
    ctime      time,
    cdatetime  timestamptz NOT NULL DEFAULT now(),
    created_by text,
    updated_by text,
    deleted_by text
);

-- Whitelists, so a bad value cannot reach the renderer and print nothing.
ALTER TABLE mystoreguard.msg_receipt_settings
    DROP CONSTRAINT IF EXISTS ck_msg_receipt_settings_paper_size;
ALTER TABLE mystoreguard.msg_receipt_settings
    ADD CONSTRAINT ck_msg_receipt_settings_paper_size
    CHECK (paper_size IN ('58MM', '80MM', 'A4', 'A5'));

ALTER TABLE mystoreguard.msg_receipt_settings
    DROP CONSTRAINT IF EXISTS ck_msg_receipt_settings_font_scale;
ALTER TABLE mystoreguard.msg_receipt_settings
    ADD CONSTRAINT ck_msg_receipt_settings_font_scale
    CHECK (font_scale IN ('SMALL', 'NORMAL', 'LARGE'));

-- One template per business and at most one per location. Two partial
-- indexes rather than one constraint, because NULL never equals NULL and a
-- plain unique key would happily allow a second business default.
CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_receipt_settings_business
    ON mystoreguard.msg_receipt_settings (tenant_id, org_id, bus_id)
    WHERE loc_id IS NULL AND deleted_by IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_receipt_settings_location
    ON mystoreguard.msg_receipt_settings (tenant_id, org_id, bus_id, loc_id)
    WHERE loc_id IS NOT NULL AND deleted_by IS NULL;

-- Resolution reads by business and then picks the location row, so the
-- lookup is on the business key.
CREATE INDEX IF NOT EXISTS ix_msg_receipt_settings_lookup
    ON mystoreguard.msg_receipt_settings (tenant_id, org_id, bus_id)
    WHERE deleted_by IS NULL;
