-- Invoicing: a business's settings (built for every country) and its tax engine.
--
-- Settings (inv_settings, one row per business): the currency it bills in, how numbers and
-- dates are written (locale), its time zone, fiscal year, payment terms, whether prices are
-- entered with tax included, how tax is rounded, and its tax registration numbers.
-- Exchange rates (inv_exchange_rates): what one unit of the business's currency is worth in
-- another, from a date -- set by hand for now.
--
-- Taxes are the business's own, for any country:
--   * inv_tax_rates: a percentage or a fixed amount (per unit, per line or per document),
--     and what it is -- standard, zero-rated, exempt, reverse charge or withholding. Its
--     value lives in inv_tax_rate_versions, each from a date, so a change can be scheduled
--     and an old invoice keeps the rate of its own date.
--   * inv_tax_groups + members: several taxes charged together, in order; a compound member
--     is charged on the price plus the taxes before it.
--   * inv_tax_rules: which rate or group applies, by item, item category, customer, customer
--     group, country, region, postcode and amount, between dates. A rule either competes
--     ("most specific wins": the matching rule naming the most conditions, then the highest
--     priority) or always adds.
--   * inv_tax_exemptions: a customer exempt from one tax, one group or every tax, with the
--     reason and certificate.
-- The calculation itself is the backend's (invoicing/taxengine.go); nothing here computes.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS invoicing.inv_settings (
    bus_id              text PRIMARY KEY,
    tenant_id           text NOT NULL,
    org_id              text,
    base_currency       char(3) NOT NULL DEFAULT 'USD' CHECK (base_currency ~ '^[A-Z]{3}$'),
    locale              text NOT NULL DEFAULT 'en-US',
    time_zone           text NOT NULL DEFAULT 'UTC',
    fiscal_year_start   smallint NOT NULL DEFAULT 1 CHECK (fiscal_year_start BETWEEN 1 AND 12),
    payment_terms_days  integer NOT NULL DEFAULT 14 CHECK (payment_terms_days BETWEEN 0 AND 3650),
    prices_include_tax  boolean NOT NULL DEFAULT false,
    tax_rounding        text NOT NULL DEFAULT 'document' CHECK (tax_rounding IN ('line', 'document')),
    rounding_mode       text NOT NULL DEFAULT 'half_up' CHECK (rounding_mode IN ('half_up', 'half_even', 'up', 'down')),
    -- [{label, number, country}]: "VAT reg. no.", "GSTIN", "TIN" -- printed on invoices.
    tax_registrations   jsonb NOT NULL DEFAULT '[]',
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    updated_by          text
);

CREATE TABLE IF NOT EXISTS invoicing.inv_exchange_rates (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    currency        char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
    -- How many of `currency` one unit of the business's currency buys.
    rate            numeric(24, 10) NOT NULL CHECK (rate > 0),
    effective_date  date NOT NULL,
    source          text NOT NULL DEFAULT 'manual',
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
CREATE UNIQUE INDEX IF NOT EXISTS inv_exchange_rates_uq ON invoicing.inv_exchange_rates (bus_id, currency, effective_date);

CREATE TABLE IF NOT EXISTS invoicing.inv_tax_rates (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    org_id        text,
    bus_id        text NOT NULL,
    name          text NOT NULL CHECK (btrim(name) <> ''),
    -- What the invoice prints beside the amount: "VAT", "GST", "NHIL".
    short_name    text NOT NULL DEFAULT '',
    kind          text NOT NULL DEFAULT 'percent' CHECK (kind IN ('percent', 'fixed')),
    treatment     text NOT NULL DEFAULT 'standard'
                  CHECK (treatment IN ('standard', 'zero_rated', 'exempt', 'reverse_charge', 'withholding')),
    -- A fixed amount is charged per unit, per line or once per document, in this currency.
    fixed_basis   text CHECK (fixed_basis IS NULL OR fixed_basis IN ('unit', 'line', 'document')),
    fixed_currency char(3) CHECK (fixed_currency IS NULL OR fixed_currency ~ '^[A-Z]{3}$'),
    country       char(2) CHECK (country IS NULL OR country ~ '^[A-Z]{2}$'),
    region        text,
    -- Who it is paid to, and the code an accountant files it under.
    authority     text NOT NULL DEFAULT '',
    report_code   text NOT NULL DEFAULT '',
    description   text NOT NULL DEFAULT '',
    archived_at   timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text,
    CHECK ((kind = 'fixed') = (fixed_basis IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS inv_tax_rates_bus_idx ON invoicing.inv_tax_rates (bus_id);
CREATE UNIQUE INDEX IF NOT EXISTS inv_tax_rates_name_uq ON invoicing.inv_tax_rates (bus_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS invoicing.inv_tax_rate_versions (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    rate_id     text NOT NULL REFERENCES invoicing.inv_tax_rates (id) ON DELETE CASCADE,
    tenant_id   text NOT NULL,
    valid_from  date NOT NULL,
    -- A percentage (17.5 = 17.5 %) or, for a fixed rate, the amount.
    value       numeric(18, 6) NOT NULL CHECK (value >= 0),
    note        text NOT NULL DEFAULT '',
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text
);
CREATE UNIQUE INDEX IF NOT EXISTS inv_tax_rate_versions_uq ON invoicing.inv_tax_rate_versions (rate_id, valid_from);

CREATE TABLE IF NOT EXISTS invoicing.inv_tax_groups (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    org_id       text,
    bus_id       text NOT NULL,
    name         text NOT NULL CHECK (btrim(name) <> ''),
    description  text NOT NULL DEFAULT '',
    archived_at  timestamptz,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text
);
CREATE UNIQUE INDEX IF NOT EXISTS inv_tax_groups_name_uq ON invoicing.inv_tax_groups (bus_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS invoicing.inv_tax_group_members (
    group_id   text NOT NULL REFERENCES invoicing.inv_tax_groups (id) ON DELETE CASCADE,
    rate_id    text NOT NULL REFERENCES invoicing.inv_tax_rates (id) ON DELETE RESTRICT,
    tenant_id  text NOT NULL,
    position   integer NOT NULL DEFAULT 0,
    -- Charged on the price plus the taxes before it in the group.
    compound   boolean NOT NULL DEFAULT false,
    PRIMARY KEY (group_id, rate_id)
);

CREATE TABLE IF NOT EXISTS invoicing.inv_tax_rules (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    name             text NOT NULL CHECK (btrim(name) <> ''),
    -- 'specific': the most specific matching rule wins; 'add': always added.
    mode             text NOT NULL DEFAULT 'specific' CHECK (mode IN ('specific', 'add')),
    priority         integer NOT NULL DEFAULT 0,
    rate_id          text REFERENCES invoicing.inv_tax_rates (id) ON DELETE RESTRICT,
    group_id         text REFERENCES invoicing.inv_tax_groups (id) ON DELETE RESTRICT,
    item_ids         text[] NOT NULL DEFAULT '{}',
    item_categories  text[] NOT NULL DEFAULT '{}',
    customer_ids     text[] NOT NULL DEFAULT '{}',
    customer_groups  text[] NOT NULL DEFAULT '{}',
    countries        text[] NOT NULL DEFAULT '{}',
    regions          text[] NOT NULL DEFAULT '{}',
    postal_prefixes  text[] NOT NULL DEFAULT '{}',
    min_amount       numeric(18, 6),
    max_amount       numeric(18, 6),
    valid_from       date,
    valid_to         date,
    is_active        boolean NOT NULL DEFAULT true,
    position         integer NOT NULL DEFAULT 0,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    CHECK ((rate_id IS NULL) <> (group_id IS NULL)),
    CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from)
);
CREATE INDEX IF NOT EXISTS inv_tax_rules_bus_idx ON invoicing.inv_tax_rules (bus_id, position);

CREATE TABLE IF NOT EXISTS invoicing.inv_tax_exemptions (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    org_id              text,
    bus_id              text NOT NULL,
    customer_id         text NOT NULL,
    -- Neither: exempt from every tax.
    rate_id             text REFERENCES invoicing.inv_tax_rates (id) ON DELETE CASCADE,
    group_id            text REFERENCES invoicing.inv_tax_groups (id) ON DELETE CASCADE,
    reason              text NOT NULL DEFAULT '',
    certificate_number  text NOT NULL DEFAULT '',
    valid_from          date,
    valid_to            date,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    created_by          text,
    CHECK (rate_id IS NULL OR group_id IS NULL)
);
CREATE INDEX IF NOT EXISTS inv_tax_exemptions_customer_idx ON invoicing.inv_tax_exemptions (bus_id, customer_id);

COMMIT;
