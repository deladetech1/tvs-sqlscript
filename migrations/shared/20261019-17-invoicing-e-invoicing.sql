-- Invoicing: e-invoicing.
--
-- Where a country takes invoices electronically, Invoicing makes the document it wants:
--   * Peppol BIS Billing 3.0 (EU, Norway, Australia, New Zealand, Singapore, Japan...): UBL XML,
--     addressed by Peppol IDs (scheme:id) -- the business's in inv_settings.einvoicing, the
--     customer's in inv_customers.einvoice_id.
--   * Saudi Arabia (ZATCA phase 1): the QR code every invoice must carry (seller, VAT number,
--     time, total, VAT), printed on it.
--   * India (GST e-invoice): the INV-01 JSON for the Invoice Registration Portal; the IRN and
--     signed QR the portal returns are kept on the invoice (inv_einvoices) and printed on it.
--
-- inv_items.code / inv_invoice_lines.code: a product's code -- HSN/SAC in India, a commodity or
-- the seller's own code elsewhere. inv_customers.state_code: the customer's state where the
-- country's e-invoice wants it (India's two-digit state codes).
-- inv_einvoices: per document and scheme, what was made and what came back (status, the
-- authority's reference such as India's IRN, its signed QR, when).
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE invoicing.inv_items ADD COLUMN IF NOT EXISTS code text NOT NULL DEFAULT '';
ALTER TABLE invoicing.inv_invoice_lines ADD COLUMN IF NOT EXISTS code text NOT NULL DEFAULT '';
-- Only while it is a table (a view of Core Platform's customers since 20261019-30).
DO $guard$
BEGIN
    IF (SELECT relkind FROM pg_class WHERE oid = to_regclass('invoicing.inv_customers')) = 'r' THEN
        ALTER TABLE invoicing.inv_customers
            ADD COLUMN IF NOT EXISTS einvoice_id text NOT NULL DEFAULT '',
            ADD COLUMN IF NOT EXISTS state_code  text NOT NULL DEFAULT '';
    END IF;
END $guard$;
ALTER TABLE invoicing.inv_settings ADD COLUMN IF NOT EXISTS einvoicing jsonb NOT NULL DEFAULT '{}';

CREATE TABLE IF NOT EXISTS invoicing.inv_einvoices (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    invoice_id   text NOT NULL REFERENCES invoicing.inv_invoices (id) ON DELETE CASCADE,
    scheme       text NOT NULL CHECK (scheme IN ('peppol', 'zatca', 'india')),
    status       text NOT NULL DEFAULT 'made' CHECK (status IN ('made', 'registered', 'cancelled')),
    reference    text NOT NULL DEFAULT '',
    ack_number   text NOT NULL DEFAULT '',
    ack_date     text NOT NULL DEFAULT '',
    signed_qr    text NOT NULL DEFAULT '',
    created_by   text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (invoice_id, scheme)
);

COMMIT;
