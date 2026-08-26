-- =====================================================================
-- Who may override pricing and stock rules, per location
-- ---------------------------------------------------------------------
-- Sales and invoices both store whatever unit price the client sends
-- them. create_sale takes "verified prices directly from item (no
-- recalculation)" and invoice creation does the same, so today any caller
-- can put any price on a line and the server records it. There is no
-- screen offering that, but there is also nothing stopping it.
--
-- This table names the people allowed to do it deliberately, per location,
-- with sales and invoices held apart: a shop may well let a supervisor
-- discount a walk-in sale while keeping invoice pricing with whoever
-- negotiates the contract, and the two lists should not have to agree.
--
-- Permission is the union of two things, so neither has to be complete:
--
--   group_ids   every member of these groups, resolved through
--               cp_user_groups at the time of the sale, so adding someone
--               to the group is enough and nobody edits this row
--   user_ids    named individuals, for the one person who is not in any
--               suitable group
--
-- An absent row means nobody may edit a price there, which is the same
-- behaviour as today for every location that never opens the setting. The
-- enabled flags exist so a rule can be switched off for a while without
-- losing the lists that took effort to assemble; with them false the lists
-- are ignored entirely.
--
-- Runs after the EF migrations on every deploy. Idempotent; safe to re-run.
-- =====================================================================

CREATE TABLE IF NOT EXISTS mystoreguard.msg_price_edit_settings (
    id         text PRIMARY KEY,
    tenant_id  text NOT NULL,
    org_id     text NOT NULL,
    bus_id     text NOT NULL,
    -- Per location, not per business. One branch trusting its manager
    -- should not decide the rule for a branch that does not.
    loc_id     text NOT NULL,

    -- Sales -------------------------------------------------------------
    sales_price_edit_enabled  boolean NOT NULL DEFAULT false,
    sales_price_edit_groups   text[]  NOT NULL DEFAULT '{}',
    sales_price_edit_users    text[]  NOT NULL DEFAULT '{}',

    -- Invoices ----------------------------------------------------------
    invoice_price_edit_enabled boolean NOT NULL DEFAULT false,
    invoice_price_edit_groups  text[]  NOT NULL DEFAULT '{}',
    invoice_price_edit_users   text[]  NOT NULL DEFAULT '{}',

    -- Invoicing stock that is not there yet --------------------------------
    -- Invoice creation currently refuses a line it cannot cover from stock.
    -- That is right for a till and wrong for an invoice, where the point is
    -- often to agree the order first and source the goods after. Same shape
    -- of rule as the two above, and the same default of nobody.
    --
    -- An invoice carrying such a line does not become a sale when it is paid,
    -- because there is no stock to move. It waits to be fulfilled, and the
    -- sale is created then — so the stock leaves and the revenue lands on the
    -- day the customer actually got the goods, rather than the money being
    -- taken against something the system has no record of delivering.
    invoice_no_stock_enabled boolean NOT NULL DEFAULT false,
    invoice_no_stock_groups  text[]  NOT NULL DEFAULT '{}',
    invoice_no_stock_users   text[]  NOT NULL DEFAULT '{}',

    -- Audit -------------------------------------------------------------
    cdate      date,
    ctime      time,
    cdatetime  timestamptz NOT NULL DEFAULT now(),
    created_by text,
    updated_by text,
    deleted_by text
);

-- Columns added separately as well as in the CREATE, so a database that
-- already has an earlier version of this table picks them up too.
ALTER TABLE mystoreguard.msg_price_edit_settings
    ADD COLUMN IF NOT EXISTS sales_price_edit_enabled   boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS sales_price_edit_groups    text[]  NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS sales_price_edit_users     text[]  NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS invoice_price_edit_enabled boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS invoice_price_edit_groups  text[]  NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS invoice_price_edit_users   text[]  NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS invoice_no_stock_enabled   boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS invoice_no_stock_groups    text[]  NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS invoice_no_stock_users     text[]  NOT NULL DEFAULT '{}';

-- One row per location. Partial on deleted_by so a soft-deleted row does
-- not block the location being configured again.
CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_price_edit_settings_location
    ON mystoreguard.msg_price_edit_settings (tenant_id, org_id, bus_id, loc_id)
    WHERE deleted_by IS NULL;

-- Read on every price-edited line, so the lookup key is indexed.
CREATE INDEX IF NOT EXISTS ix_msg_price_edit_settings_lookup
    ON mystoreguard.msg_price_edit_settings (tenant_id, org_id, bus_id, loc_id)
    WHERE deleted_by IS NULL;
