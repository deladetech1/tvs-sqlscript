-- Invoicing Release 3: recurring invoices and payment reminders, run by Invoicing's own
-- background jobs (its function app).
--
-- inv_recurring: an invoice made again on a schedule -- weekly to yearly, from a start date,
-- until an end date or a number of invoices, or for ever. template is what each invoice says
-- (customer, lines, currency, notes...), copied from the invoice it was made from. Each run makes
-- the invoice dated next_date, issues it when auto_issue, emails it when send_by_email, and moves
-- next_date on. Paused profiles wait; ended ones are kept for their history. Invoices made
-- point back with inv_invoices.recurring_id.
--
-- Reminders: when inv_settings.reminders_enabled, an open invoice's customer is emailed on the
-- days in reminder_days relative to its due date (-3: three days before, 0: on the day, 7: a
-- week late), each once (inv_reminders_sent), in working hours of the business's time zone. A
-- customer can be left out (inv_customers.no_reminders).
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS invoicing.inv_recurring (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    org_id          text,
    bus_id          text NOT NULL,
    customer_id     text NOT NULL REFERENCES invoicing.inv_customers (id) ON DELETE RESTRICT,
    name            text NOT NULL CHECK (btrim(name) <> ''),
    template        jsonb NOT NULL,
    frequency       text NOT NULL CHECK (frequency IN ('weekly', 'fortnightly', 'monthly', 'quarterly', 'half_yearly', 'yearly')),
    start_date      date NOT NULL,
    next_date       date NOT NULL,
    end_date        date,
    remaining       integer CHECK (remaining IS NULL OR remaining >= 0),
    auto_issue      boolean NOT NULL DEFAULT true,
    send_by_email   boolean NOT NULL DEFAULT false,
    status          text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'ended')),
    invoices_made   integer NOT NULL DEFAULT 0,
    last_invoice_id text,
    last_run_at     timestamptz,
    last_error      text NOT NULL DEFAULT '',
    created_by      text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS inv_recurring_due_idx ON invoicing.inv_recurring (next_date) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS inv_recurring_bus_idx ON invoicing.inv_recurring (bus_id);

ALTER TABLE invoicing.inv_settings
    ADD COLUMN IF NOT EXISTS reminders_enabled  boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS reminder_days      integer[] NOT NULL DEFAULT '{-3,0,7,14}';

-- Only while it is a table (a view of Core Platform's customers since 20261019-30).
DO $guard$
BEGIN
    IF (SELECT relkind FROM pg_class WHERE oid = to_regclass('invoicing.inv_customers')) = 'r' THEN
        ALTER TABLE invoicing.inv_customers ADD COLUMN IF NOT EXISTS no_reminders boolean NOT NULL DEFAULT false;
    END IF;
END $guard$;

CREATE TABLE IF NOT EXISTS invoicing.inv_reminders_sent (
    invoice_id   text NOT NULL REFERENCES invoicing.inv_invoices (id) ON DELETE CASCADE,
    offset_days  integer NOT NULL,
    tenant_id    text NOT NULL,
    sent_at      timestamptz NOT NULL DEFAULT now(),
    message_id   text,
    PRIMARY KEY (invoice_id, offset_days)
);

COMMIT;
