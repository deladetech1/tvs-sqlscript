-- HMS tax receipts: every receipt and invoice numbered and kept as issued.
--
--   hms_fiscal_profiles   a business's (or one property's) settings: on or off, the number
--                         prefix, what gets a tax receipt, the Core Platform taxes in ticket,
--                         appointment and dues prices, a line for the foot of each receipt.
--                         The taxes and the seller's details are Core Platform's; reporting
--                         to a tax authority is Core Platform's too, so the connection columns
--                         (api_url, api_key...) are unused and provider is always 'local'.
--   hms_fiscal_documents  every receipt, invoice and credit note issued: its own number
--                         (gapless, per profile and kind), what it said (lines, taxes, totals,
--                         the buyer's tax number), the hash chained to the one before, and the
--                         QR code that checks it against the register.
--   hms_fiscal_counters   the last number issued, per profile and kind.
--   hms_orders.buyer_tin, hms_invoices.buyer_tin   a business customer's tax number.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS hms.hms_fiscal_profiles (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    property_id      text REFERENCES hms.hms_properties (id),
    provider         text NOT NULL DEFAULT 'local',
    country          text NOT NULL DEFAULT 'GH',
    legal_name       text,
    tin              text,
    vat_number       text,
    branch_code      text,
    device_id        text,
    api_url          text,
    api_key          text,
    api_secret       text,
    environment      text NOT NULL DEFAULT 'sandbox',
    prefix           text,
    covers           text[] NOT NULL DEFAULT '{order,invoice,folio,ticket,appointment,membership}',
    service_tax_ids  text[] NOT NULL DEFAULT '{}',
    prices_include_tax boolean NOT NULL DEFAULT false,
    footer           text,
    enabled          boolean NOT NULL DEFAULT false,
    last_ok_at       timestamptz,
    last_error       text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    updated_by       text
);
ALTER TABLE hms.hms_fiscal_profiles DROP CONSTRAINT IF EXISTS hms_fiscal_profiles_provider_check;
UPDATE hms.hms_fiscal_profiles SET provider = 'local', api_key = NULL, api_secret = NULL WHERE provider <> 'local' OR api_key IS NOT NULL OR api_secret IS NOT NULL;
UPDATE hms.hms_fiscal_documents SET provider = 'local', status = 'accepted' WHERE provider <> 'local' OR status <> 'accepted';
ALTER TABLE hms.hms_fiscal_profiles ADD CONSTRAINT hms_fiscal_profiles_provider_check CHECK (provider = 'local');
ALTER TABLE hms.hms_fiscal_profiles DROP CONSTRAINT IF EXISTS hms_fiscal_profiles_environment_check;
ALTER TABLE hms.hms_fiscal_profiles ADD CONSTRAINT hms_fiscal_profiles_environment_check CHECK (environment IN ('sandbox', 'live'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_fiscal_profiles_scope_uq ON hms.hms_fiscal_profiles (bus_id, coalesce(property_id, ''));

CREATE TABLE IF NOT EXISTS hms.hms_fiscal_counters (
    profile_id       text NOT NULL REFERENCES hms.hms_fiscal_profiles (id),
    kind             text NOT NULL,
    last_seq         bigint NOT NULL DEFAULT 0,
    last_hash        text NOT NULL DEFAULT '',
    PRIMARY KEY (profile_id, kind)
);

CREATE TABLE IF NOT EXISTS hms.hms_fiscal_documents (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    property_id      text REFERENCES hms.hms_properties (id),
    profile_id       text NOT NULL REFERENCES hms.hms_fiscal_profiles (id),
    provider         text NOT NULL,
    source_type      text NOT NULL,
    source_id        text NOT NULL,
    kind             text NOT NULL DEFAULT 'receipt',
    credit_of        text REFERENCES hms.hms_fiscal_documents (id),
    seq              bigint NOT NULL,
    number           text NOT NULL,
    issued_at        timestamptz NOT NULL DEFAULT now(),
    currency         text NOT NULL,
    buyer_name       text,
    buyer_tin        text,
    payment_method   text,
    net              numeric(14,2) NOT NULL DEFAULT 0,
    tax              numeric(14,2) NOT NULL DEFAULT 0,
    gross            numeric(14,2) NOT NULL DEFAULT 0,
    lines            jsonb NOT NULL DEFAULT '[]',
    taxes            jsonb NOT NULL DEFAULT '[]',
    prev_hash        text NOT NULL DEFAULT '',
    hash             text NOT NULL,
    status           text NOT NULL DEFAULT 'pending',
    fiscal_number    text,
    signature        text,
    qr               text,
    response         jsonb,
    attempts         int NOT NULL DEFAULT 0,
    next_attempt_at  timestamptz NOT NULL DEFAULT now(),
    error            text,
    submitted_at     timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hms.hms_fiscal_documents DROP CONSTRAINT IF EXISTS hms_fiscal_documents_status_check;
ALTER TABLE hms.hms_fiscal_documents ADD CONSTRAINT hms_fiscal_documents_status_check CHECK (status IN ('pending', 'accepted', 'failed'));
ALTER TABLE hms.hms_fiscal_documents DROP CONSTRAINT IF EXISTS hms_fiscal_documents_kind_check;
ALTER TABLE hms.hms_fiscal_documents ADD CONSTRAINT hms_fiscal_documents_kind_check CHECK (kind IN ('receipt', 'invoice', 'credit_note'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_fiscal_documents_source_uq ON hms.hms_fiscal_documents (source_type, source_id, kind);
CREATE UNIQUE INDEX IF NOT EXISTS hms_fiscal_documents_number_uq ON hms.hms_fiscal_documents (profile_id, kind, seq);
CREATE INDEX IF NOT EXISTS hms_fiscal_documents_queue_idx ON hms.hms_fiscal_documents (next_attempt_at) WHERE status <> 'accepted';
CREATE INDEX IF NOT EXISTS hms_fiscal_documents_bus_idx ON hms.hms_fiscal_documents (bus_id, issued_at);

ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS buyer_tin text;
ALTER TABLE hms.hms_invoices ADD COLUMN IF NOT EXISTS buyer_tin text;

INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('hms.fiscal', 'app-hms', 'Tax Receipts', 1, 'Every receipt and invoice numbered, chained and checkable by QR, with the taxes from Core Platform')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

COMMIT;
