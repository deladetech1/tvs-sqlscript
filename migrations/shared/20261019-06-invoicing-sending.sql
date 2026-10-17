-- Invoicing Release 1, part four: sending an invoice by email and SMS.
--
-- inv_messages: every email and text sent about an invoice, one row per recipient. The row is
-- written as 'sending' before core-platform is asked to send it, then marked sent or failed;
-- one left at 'sending' (the server stopped mid-send) may or may not have arrived and is never
-- sent again by itself. Email and SMS go through core-platform's service routes, as the
-- tenant's own mailbox and SMS provider.
--
-- inv_settings.email_subject / email_body / sms_body: the business's own wording, with
-- {customer}, {contact}, {number}, {amount_due}, {total}, {due_date}, {issue_date}, {business}
-- and {link}. Empty: the default, in the customer's language where there is one.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS invoicing.inv_messages (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    invoice_id  text NOT NULL REFERENCES invoicing.inv_invoices (id) ON DELETE CASCADE,
    channel     text NOT NULL CHECK (channel IN ('email', 'sms')),
    recipient   text NOT NULL,
    copy        boolean NOT NULL DEFAULT false,
    subject     text NOT NULL DEFAULT '',
    body        text NOT NULL DEFAULT '',
    status      text NOT NULL DEFAULT 'sending' CHECK (status IN ('sending', 'sent', 'failed')),
    error       text NOT NULL DEFAULT '',
    reference   text NOT NULL DEFAULT '',
    sent_by     text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    sent_at     timestamptz
);
CREATE INDEX IF NOT EXISTS inv_messages_invoice_idx ON invoicing.inv_messages (invoice_id, cdatetime DESC);

ALTER TABLE invoicing.inv_settings
    ADD COLUMN IF NOT EXISTS email_subject  text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS email_body     text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS sms_body       text NOT NULL DEFAULT '';

COMMIT;
