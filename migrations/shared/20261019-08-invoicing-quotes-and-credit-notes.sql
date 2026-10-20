-- Invoicing Release 2: quotes and credit notes.
--
-- Both are documents like an invoice -- a customer, lines, the tax engine's result, a design, a
-- customer link, sending -- so they live in inv_invoices with a kind:
--   * 'invoice'      what is owed;
--   * 'quote'        what would be owed. due_date is the date it is valid until. Open until the
--                    customer accepts it (with their name, as a signature) or declines it, or it
--                    is turned into an invoice ('converted', converted_invoice_id);
--   * 'credit_note'  money given back against an invoice (credit_for_id): open while it has
--                    credit left, 'applied' once all of it is used -- against invoices of the
--                    customer, as payments of method 'credit_note', or paid back as refunds.
-- Each kind has its own number series.
--
-- inv_payments gains credit_note_id: a payment made with credit, naming the credit note it
-- came from. A refund (kind 'refund') is recorded against the credit note itself.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE invoicing.inv_invoices
    ADD COLUMN IF NOT EXISTS kind                  text NOT NULL DEFAULT 'invoice',
    ADD COLUMN IF NOT EXISTS accepted_at           timestamptz,
    ADD COLUMN IF NOT EXISTS accepted_by_name      text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS declined_at           timestamptz,
    ADD COLUMN IF NOT EXISTS decline_reason        text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS converted_invoice_id  text,
    ADD COLUMN IF NOT EXISTS from_quote_id         text,
    ADD COLUMN IF NOT EXISTS credit_for_id         text,
    ADD COLUMN IF NOT EXISTS recurring_id          text;

DO $$
DECLARE c text;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inv_invoices_kind_ck') THEN
        ALTER TABLE invoicing.inv_invoices ADD CONSTRAINT inv_invoices_kind_ck CHECK (kind IN ('invoice', 'quote', 'credit_note'));
    END IF;
    -- The statuses quotes and credit notes add.
    SELECT conname INTO c FROM pg_constraint
     WHERE conrelid = 'invoicing.inv_invoices'::regclass AND contype = 'c'
       AND pg_get_constraintdef(oid) LIKE '%''draft''%''void''%' AND pg_get_constraintdef(oid) NOT LIKE '%accepted%';
    IF c IS NOT NULL THEN
        EXECUTE format('ALTER TABLE invoicing.inv_invoices DROP CONSTRAINT %I', c);
        ALTER TABLE invoicing.inv_invoices ADD CONSTRAINT inv_invoices_status_ck
            CHECK (status IN ('draft', 'open', 'paid', 'void', 'accepted', 'declined', 'converted', 'applied'));
    END IF;
END $$;
CREATE INDEX IF NOT EXISTS inv_invoices_kind_idx ON invoicing.inv_invoices (bus_id, kind, issue_date DESC);
CREATE INDEX IF NOT EXISTS inv_invoices_credit_for_idx ON invoicing.inv_invoices (credit_for_id) WHERE credit_for_id IS NOT NULL;

ALTER TABLE invoicing.inv_payments ADD COLUMN IF NOT EXISTS credit_note_id text;
DO $$
DECLARE c text;
BEGIN
    SELECT conname INTO c FROM pg_constraint
     WHERE conrelid = 'invoicing.inv_payments'::regclass AND contype = 'c'
       AND pg_get_constraintdef(oid) LIKE '%bank_transfer%' AND pg_get_constraintdef(oid) NOT LIKE '%credit_note%';
    IF c IS NOT NULL THEN
        EXECUTE format('ALTER TABLE invoicing.inv_payments DROP CONSTRAINT %I', c);
        ALTER TABLE invoicing.inv_payments ADD CONSTRAINT inv_payments_method_ck
            CHECK (method IN ('cash', 'bank_transfer', 'mobile_money', 'card', 'cheque', 'online', 'other', 'credit_note'));
    END IF;
END $$;
CREATE INDEX IF NOT EXISTS inv_payments_credit_idx ON invoicing.inv_payments (credit_note_id) WHERE credit_note_id IS NOT NULL;

-- How long a quote is valid, and what a new one starts with.
ALTER TABLE invoicing.inv_settings
    ADD COLUMN IF NOT EXISTS quote_valid_days  integer NOT NULL DEFAULT 30,
    ADD COLUMN IF NOT EXISTS quote_terms       text NOT NULL DEFAULT '';

COMMIT;
