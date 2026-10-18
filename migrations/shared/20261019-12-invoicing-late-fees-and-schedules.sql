-- Invoicing: late fees, deposits and instalments.
--
-- Late fees are charged on their own invoice, never added to the one that is late: an issued
-- invoice is never changed (tax authorities that take invoices electronically refuse a changed
-- one). Invoicing's background job charges them when inv_settings.late_fee_kind is not 'none':
-- a percentage of what is still owed, or a fixed amount, once the invoice is grace days late,
-- and again every repeat days (0: only once), at most max times. Each charge is a row of
-- inv_late_fees naming the invoice it made (inv_invoices.late_fee_for_id points back). An
-- invoice can be spared (inv_invoices.late_fees = false), and so can a customer
-- (inv_customers.no_late_fees).
--
-- A payment schedule splits what an invoice asks for into instalments, each due on its own date:
-- a deposit is the first, due at once. Each row is a fixed amount or a percentage of the amount
-- due; the last row with neither is "the rest". Payments are taken off the instalments in date
-- order. The invoice's own due date is its last instalment's.
--
-- Reminders follow the instalments: inv_reminders_sent gains the instalment it was about
-- (0 = the invoice's own due date).
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE invoicing.inv_settings
    ADD COLUMN IF NOT EXISTS late_fee_kind        text NOT NULL DEFAULT 'none',
    ADD COLUMN IF NOT EXISTS late_fee_value       numeric(20, 4) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS late_fee_grace_days  integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS late_fee_repeat_days integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS late_fee_max_times   integer NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS late_fee_email       boolean NOT NULL DEFAULT true;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inv_settings_late_fee_check') THEN
        ALTER TABLE invoicing.inv_settings ADD CONSTRAINT inv_settings_late_fee_check CHECK (
            late_fee_kind IN ('none', 'percent', 'fixed') AND late_fee_value >= 0
            AND late_fee_grace_days BETWEEN 0 AND 365 AND late_fee_repeat_days BETWEEN 0 AND 365
            AND late_fee_max_times BETWEEN 1 AND 120);
    END IF;
END $$;

ALTER TABLE invoicing.inv_invoices
    ADD COLUMN IF NOT EXISTS late_fees       boolean NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS late_fee_for_id text;
CREATE INDEX IF NOT EXISTS inv_invoices_late_fee_for_idx ON invoicing.inv_invoices (late_fee_for_id) WHERE late_fee_for_id IS NOT NULL;

-- Only while it is a table (a view of Core Platform's customers since 20261019-30).
DO $guard$
BEGIN
    IF (SELECT relkind FROM pg_class WHERE oid = to_regclass('invoicing.inv_customers')) = 'r' THEN
        ALTER TABLE invoicing.inv_customers ADD COLUMN IF NOT EXISTS no_late_fees boolean NOT NULL DEFAULT false;
    END IF;
END $guard$;

CREATE TABLE IF NOT EXISTS invoicing.inv_late_fees (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    invoice_id      text NOT NULL REFERENCES invoicing.inv_invoices (id) ON DELETE CASCADE,
    charged_on      date NOT NULL,
    amount          numeric(20, 4) NOT NULL CHECK (amount > 0),
    fee_invoice_id  text NOT NULL REFERENCES invoicing.inv_invoices (id) ON DELETE CASCADE,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (invoice_id, charged_on)
);

CREATE TABLE IF NOT EXISTS invoicing.inv_invoice_schedule (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    invoice_id  text NOT NULL REFERENCES invoicing.inv_invoices (id) ON DELETE CASCADE,
    position    integer NOT NULL,
    due_date    date NOT NULL,
    percent     numeric(9, 4) CHECK (percent IS NULL OR (percent > 0 AND percent <= 100)),
    amount      numeric(20, 4) CHECK (amount IS NULL OR amount > 0),
    label       text NOT NULL DEFAULT '',
    CHECK (percent IS NULL OR amount IS NULL),
    UNIQUE (invoice_id, position)
);

ALTER TABLE invoicing.inv_reminders_sent ADD COLUMN IF NOT EXISTS instalment integer NOT NULL DEFAULT 0;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)
         WHERE c.conrelid = 'invoicing.inv_reminders_sent'::regclass AND c.contype = 'p' AND a.attname = 'instalment') THEN
        ALTER TABLE invoicing.inv_reminders_sent DROP CONSTRAINT IF EXISTS inv_reminders_sent_pkey;
        ALTER TABLE invoicing.inv_reminders_sent ADD PRIMARY KEY (invoice_id, instalment, offset_days);
    END IF;
END $$;

COMMIT;
