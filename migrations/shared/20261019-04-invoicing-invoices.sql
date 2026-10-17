-- Invoicing Release 1, part two: invoices.
--
-- Invoices (inv_invoices): a draft until issued. Issuing gives the invoice its number from the
-- business's number series and freezes what it says; a draft has no number, so numbers have no
-- gaps -- many countries' tax offices require that. An issued invoice is open until paid, and
-- is never deleted: it is voided, with a reason, and keeps its number.
--
-- What an invoice says is kept on it, not looked up: the customer as they were (name, address,
-- tax number -- customer_snapshot), each line's name, price and tax, the exchange rate to the
-- business's currency on the day, and the tax engine's whole result (calc). A later change to
-- the customer, an item, a tax rate or an exchange rate never changes an invoice already made.
-- The amounts (subtotal ... balance) are copies of calc for listing and sums.
--
-- Overdue is not stored: an open invoice past its due date with something still owed.
--
-- Number series (inv_number_series): one per business and kind ('invoice' now; quotes and
-- credit notes later). The pattern's {NUMBER} is the counter padded to `padding` digits;
-- {YYYY}, {YY} and {MM} are the issue date's. reset_every restarts the counter each year or
-- month; `period` remembers which one the counter belongs to.
--
-- Lines (inv_invoice_lines): replaced whole on every save of the invoice. item_id has no
-- foreign key on purpose: an item may be deleted, and the line keeps its own copy.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS invoicing.inv_number_series (
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    kind          text NOT NULL CHECK (kind IN ('invoice', 'quote', 'credit_note')),
    pattern       text NOT NULL CHECK (position('{NUMBER}' IN pattern) > 0 AND length(pattern) <= 60),
    padding       integer NOT NULL DEFAULT 4 CHECK (padding BETWEEN 1 AND 12),
    next_number   bigint NOT NULL DEFAULT 1 CHECK (next_number >= 1),
    reset_every   text NOT NULL DEFAULT 'never' CHECK (reset_every IN ('never', 'year', 'month')),
    period        text NOT NULL DEFAULT '',
    updated_at    timestamptz NOT NULL DEFAULT now(),
    updated_by    text,
    PRIMARY KEY (bus_id, kind)
);

CREATE TABLE IF NOT EXISTS invoicing.inv_invoices (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    org_id              text,
    bus_id              text NOT NULL,
    number              text,
    status              text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'open', 'paid', 'void')),
    customer_id         text NOT NULL REFERENCES invoicing.inv_customers (id) ON DELETE RESTRICT,
    customer_snapshot   jsonb NOT NULL DEFAULT '{}',
    title               text NOT NULL DEFAULT '',
    reference           text NOT NULL DEFAULT '',
    issue_date          date NOT NULL,
    due_date            date NOT NULL,
    currency            char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
    base_currency       char(3) NOT NULL CHECK (base_currency ~ '^[A-Z]{3}$'),
    -- How many of `currency` one unit of base_currency bought on the day (1 when the same).
    exchange_rate       numeric(24, 10) NOT NULL DEFAULT 1 CHECK (exchange_rate > 0),
    prices_include_tax  boolean NOT NULL DEFAULT false,
    tax_rounding        text NOT NULL DEFAULT 'document' CHECK (tax_rounding IN ('line', 'document')),
    rounding_mode       text NOT NULL DEFAULT 'half_up' CHECK (rounding_mode IN ('half_up', 'half_even', 'up', 'down')),
    -- A percentage off every line, on top of each line's own.
    discount_percent    numeric(9, 4) NOT NULL DEFAULT 0 CHECK (discount_percent >= 0 AND discount_percent <= 100),
    subtotal            numeric(20, 4) NOT NULL DEFAULT 0,
    tax_total           numeric(20, 4) NOT NULL DEFAULT 0,
    withheld            numeric(20, 4) NOT NULL DEFAULT 0,
    total               numeric(20, 4) NOT NULL DEFAULT 0,
    amount_due          numeric(20, 4) NOT NULL DEFAULT 0,
    amount_paid         numeric(20, 4) NOT NULL DEFAULT 0,
    balance             numeric(20, 4) NOT NULL DEFAULT 0,
    calc                jsonb NOT NULL DEFAULT '{}',
    notes               text NOT NULL DEFAULT '',
    terms               text NOT NULL DEFAULT '',
    footer              text NOT NULL DEFAULT '',
    issued_at           timestamptz,
    issued_by           text,
    sent_at             timestamptz,
    viewed_at           timestamptz,
    paid_at             timestamptz,
    voided_at           timestamptz,
    voided_by           text,
    void_reason         text NOT NULL DEFAULT '',
    duplicated_from     text,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    created_by          text,
    updated_by          text,
    CHECK (due_date >= issue_date),
    CHECK ((status = 'draft') = (number IS NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS inv_invoices_number_uq ON invoicing.inv_invoices (bus_id, number) WHERE number IS NOT NULL;
CREATE INDEX IF NOT EXISTS inv_invoices_bus_idx ON invoicing.inv_invoices (bus_id, issue_date DESC);
CREATE INDEX IF NOT EXISTS inv_invoices_customer_idx ON invoicing.inv_invoices (customer_id);
CREATE INDEX IF NOT EXISTS inv_invoices_open_idx ON invoicing.inv_invoices (bus_id, due_date) WHERE status = 'open';

CREATE TABLE IF NOT EXISTS invoicing.inv_invoice_lines (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    invoice_id        text NOT NULL REFERENCES invoicing.inv_invoices (id) ON DELETE CASCADE,
    position          integer NOT NULL,
    item_id           text,
    name              text NOT NULL DEFAULT '',
    description       text NOT NULL DEFAULT '',
    category          text NOT NULL DEFAULT '',
    quantity          numeric(20, 6) NOT NULL DEFAULT 1,
    unit              text NOT NULL DEFAULT '',
    unit_price        numeric(20, 6) NOT NULL DEFAULT 0,
    discount_percent  numeric(9, 4) NOT NULL DEFAULT 0 CHECK (discount_percent >= 0 AND discount_percent <= 100),
    tax_mode          text NOT NULL DEFAULT 'rules' CHECK (tax_mode IN ('rules', 'rate', 'group', 'none')),
    tax_rate_id       text,
    tax_group_id      text,
    net               numeric(20, 4) NOT NULL DEFAULT 0,
    tax               numeric(20, 4) NOT NULL DEFAULT 0,
    gross             numeric(20, 4) NOT NULL DEFAULT 0,
    taxes             jsonb NOT NULL DEFAULT '[]'
);
CREATE INDEX IF NOT EXISTS inv_invoice_lines_invoice_idx ON invoicing.inv_invoice_lines (invoice_id, position);

COMMIT;
