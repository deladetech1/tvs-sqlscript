-- HMS: invoices, and paying online wherever money is owed.
--
--   hms_online_payments   whether the business takes payment online, and at which properties, as
--                         LoanDrift switches it on per branch. The gateway itself (Paystack,
--                         Hubtel, expressPay, Stripe) is the tenant's, set up in Core Platform.
--   hms_invoices,
--   hms_invoice_lines,
--   hms_invoice_payments  invoices to a guest, a company, a tenant or anyone: numbered, sent by
--                         email or SMS with a link to pay online, paid in part or in full.
--   hms_payment_attempts  now for invoices and activity bookings too, and the channel paid by.

BEGIN;

CREATE TABLE IF NOT EXISTS hms.hms_online_payments (
    bus_id        text PRIMARY KEY,
    tenant_id     text NOT NULL,
    enabled       boolean NOT NULL DEFAULT true,
    property_ids  text[] NOT NULL DEFAULT '{}',   -- empty: every property
    updated_by    text,
    updated_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hms.hms_payment_attempts DROP CONSTRAINT IF EXISTS hms_payment_attempts_subject_check;
ALTER TABLE hms.hms_payment_attempts ADD CONSTRAINT hms_payment_attempts_subject_check
    CHECK (subject_type IN ('lease', 'folio', 'reservation', 'order', 'voucher', 'invoice', 'activity_booking'));
ALTER TABLE hms.hms_payment_attempts ADD COLUMN IF NOT EXISTS channel text;
ALTER TABLE hms.hms_payment_attempts ADD COLUMN IF NOT EXISTS provider_code text;

-- ================================================================== invoices
CREATE TABLE IF NOT EXISTS hms.hms_invoices (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    org_id          text,
    bus_id          text NOT NULL,
    property_id     text REFERENCES hms.hms_properties (id),
    number          text NOT NULL,
    seq             int NOT NULL,
    bill_to_type    text NOT NULL DEFAULT 'other',
    guest_id        text REFERENCES hms.hms_guests (id),
    company_id      text,
    renter_id       text REFERENCES hms.hms_renters (id),
    bill_to_name    text NOT NULL,
    bill_to_email   text,
    bill_to_phone   text,
    bill_to_address text,
    issue_date      date NOT NULL DEFAULT CURRENT_DATE,
    due_date        date,
    currency        text NOT NULL,
    status          text NOT NULL DEFAULT 'draft',
    discount        numeric(14,2) NOT NULL DEFAULT 0 CHECK (discount >= 0),
    notes           text,
    terms           text,
    public_token    text NOT NULL,
    folio_id        text REFERENCES hms.hms_folios (id),
    reservation_id  text REFERENCES hms.hms_reservations (id),
    lease_id        text REFERENCES hms.hms_leases (id),
    event_id        text REFERENCES hms.hms_events (id),
    sent_at         timestamptz,
    voided_at       timestamptz,
    void_reason     text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
ALTER TABLE hms.hms_invoices DROP CONSTRAINT IF EXISTS hms_invoices_status_check;
ALTER TABLE hms.hms_invoices ADD CONSTRAINT hms_invoices_status_check CHECK (status IN ('draft', 'sent', 'part_paid', 'paid', 'void'));
ALTER TABLE hms.hms_invoices DROP CONSTRAINT IF EXISTS hms_invoices_bill_to_check;
ALTER TABLE hms.hms_invoices ADD CONSTRAINT hms_invoices_bill_to_check CHECK (bill_to_type IN ('guest', 'company', 'renter', 'other'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_invoices_number_uq ON hms.hms_invoices (bus_id, number);
CREATE UNIQUE INDEX IF NOT EXISTS hms_invoices_token_uq ON hms.hms_invoices (public_token);
CREATE INDEX IF NOT EXISTS hms_invoices_bus_idx ON hms.hms_invoices (bus_id, issue_date DESC);

CREATE TABLE IF NOT EXISTS hms.hms_invoice_lines (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    invoice_id  text NOT NULL REFERENCES hms.hms_invoices (id) ON DELETE CASCADE,
    description text NOT NULL,
    quantity    numeric(12,3) NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_price  numeric(14,2) NOT NULL CHECK (unit_price >= 0),
    tax_rate    numeric(6,3) NOT NULL DEFAULT 0 CHECK (tax_rate >= 0 AND tax_rate <= 100),
    sort_order  int NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS hms_invoice_lines_invoice_idx ON hms.hms_invoice_lines (invoice_id, sort_order);

CREATE TABLE IF NOT EXISTS hms.hms_invoice_payments (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    invoice_id      text NOT NULL REFERENCES hms.hms_invoices (id),
    amount          numeric(14,2) NOT NULL CHECK (amount > 0),
    method          text NOT NULL,
    reference       text,
    paid_on         date NOT NULL DEFAULT CURRENT_DATE,
    folio_line_id   text REFERENCES hms.hms_folio_lines (id),
    online_reference text,
    voided_at       timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
ALTER TABLE hms.hms_invoice_payments DROP CONSTRAINT IF EXISTS hms_invoice_payments_method_check;
ALTER TABLE hms.hms_invoice_payments ADD CONSTRAINT hms_invoice_payments_method_check
    CHECK (method IN ('cash', 'card', 'momo', 'bank', 'cheque', 'online', 'voucher', 'other'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_invoice_payments_online_uq ON hms.hms_invoice_payments (online_reference) WHERE online_reference IS NOT NULL;

-- Files on an invoice (a signed copy, a purchase order from the client).
ALTER TABLE hms.hms_files DROP CONSTRAINT IF EXISTS hms_files_entity_check;
ALTER TABLE hms.hms_files ADD CONSTRAINT hms_files_entity_check CHECK (entity_type IS NULL OR entity_type IN
    ('property', 'unit_type', 'unit', 'guest', 'reservation', 'lease', 'renter', 'ticket', 'lost_item', 'asset', 'event', 'expense', 'staff',
     'menu_item', 'menu_category', 'addon', 'activity', 'table', 'stock_item', 'voucher', 'owner', 'site', 'invoice'));

-- ================================================================ plan feature
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('hms.invoices', 'app-hms', 'Invoices', 1, 'Numbered invoices to guests, companies and tenants, sent with a link to pay online')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

COMMIT;
