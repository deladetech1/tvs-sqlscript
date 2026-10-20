-- Invoicing Release 1, part five: payments.
--
-- inv_payments: money received against an invoice (kind 'payment'), or given back (kind
-- 'refund'), in the invoice's currency. Recorded by hand -- cash, bank transfer, mobile money,
-- card, cheque -- or online, when the customer pays from their link. A payment recorded in
-- error is voided with a reason, never deleted. Each received payment has a receipt number
-- from the business's 'receipt' series.
--
-- inv_payment_attempts: an online payment started from the customer's link, by its gateway
-- reference. Nothing is marked paid on the customer's word: only asking the gateway (through
-- core-platform) settles an attempt, and an attempt settles once (settled_payment_id).
--
-- The invoice keeps amount_paid and balance as sums of its payments, and is 'paid' while
-- nothing is owed; recorded by the app in the same transaction as the payment.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

-- Receipts get a number series of their own.
DO $$
DECLARE c text;
BEGIN
    SELECT conname INTO c FROM pg_constraint
     WHERE conrelid = 'invoicing.inv_number_series'::regclass AND contype = 'c' AND pg_get_constraintdef(oid) LIKE '%credit_note%'
       AND pg_get_constraintdef(oid) NOT LIKE '%receipt%';
    IF c IS NOT NULL THEN
        EXECUTE format('ALTER TABLE invoicing.inv_number_series DROP CONSTRAINT %I', c);
        ALTER TABLE invoicing.inv_number_series ADD CONSTRAINT inv_number_series_kind_check
            CHECK (kind IN ('invoice', 'quote', 'credit_note', 'receipt'));
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS invoicing.inv_payments (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    org_id             text,
    bus_id             text NOT NULL,
    invoice_id         text NOT NULL REFERENCES invoicing.inv_invoices (id) ON DELETE RESTRICT,
    customer_id        text NOT NULL,
    kind               text NOT NULL DEFAULT 'payment' CHECK (kind IN ('payment', 'refund')),
    amount             numeric(20, 4) NOT NULL CHECK (amount > 0),
    currency           char(3) NOT NULL,
    method             text NOT NULL CHECK (method IN ('cash', 'bank_transfer', 'mobile_money', 'card', 'cheque', 'online', 'other')),
    paid_on            date NOT NULL,
    reference          text NOT NULL DEFAULT '',
    note               text NOT NULL DEFAULT '',
    receipt_number     text,
    gateway_reference  text,
    channel            text NOT NULL DEFAULT '',
    status             text NOT NULL DEFAULT 'received' CHECK (status IN ('received', 'voided')),
    voided_at          timestamptz,
    voided_by          text,
    void_reason        text NOT NULL DEFAULT '',
    created_by         text,
    cdatetime          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS inv_payments_invoice_idx ON invoicing.inv_payments (invoice_id);
CREATE INDEX IF NOT EXISTS inv_payments_bus_idx ON invoicing.inv_payments (bus_id, paid_on DESC);
CREATE UNIQUE INDEX IF NOT EXISTS inv_payments_gateway_uq ON invoicing.inv_payments (gateway_reference) WHERE gateway_reference IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS inv_payments_receipt_uq ON invoicing.inv_payments (bus_id, receipt_number) WHERE receipt_number IS NOT NULL;

CREATE TABLE IF NOT EXISTS invoicing.inv_payment_attempts (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    bus_id              text NOT NULL,
    invoice_id          text NOT NULL REFERENCES invoicing.inv_invoices (id) ON DELETE CASCADE,
    reference           text NOT NULL UNIQUE,
    amount_minor        bigint NOT NULL CHECK (amount_minor > 0),
    currency            char(3) NOT NULL,
    status              text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'failed')),
    channel             text NOT NULL DEFAULT '',
    settled_payment_id  text,
    checked_at          timestamptz,
    cdatetime           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS inv_payment_attempts_open_idx ON invoicing.inv_payment_attempts (invoice_id) WHERE status = 'pending';

COMMIT;
