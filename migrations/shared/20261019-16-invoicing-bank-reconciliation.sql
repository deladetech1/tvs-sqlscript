-- Invoicing: bank and mobile money reconciliation.
--
-- The business imports a statement from its bank or mobile money wallet (CSV in the bank's own
-- layout, or OFX). Each line is money in or out on a day. Money in is matched to a customer
-- payment already recorded (reconciling it), or recorded as a payment on the invoice it pays,
-- or set aside as not a customer's (ignored). A payment matched to a statement line is
-- reconciled: inv_payments.bank_line_id.
--
--   * inv_bank_accounts: where statements come from (a bank account or a wallet), with the
--     payment method money received there is recorded as.
--   * inv_bank_statements: one imported file.
--   * inv_bank_lines: its lines; fingerprint stops the same line coming in twice from
--     overlapping statements.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS invoicing.inv_bank_accounts (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    name        text NOT NULL CHECK (btrim(name) <> ''),
    currency    text NOT NULL,
    method      text NOT NULL DEFAULT 'bank_transfer' CHECK (method IN ('bank_transfer', 'mobile_money', 'card', 'cash', 'cheque', 'other')),
    -- How the bank's CSV is read, remembered from the last import.
    csv_mapping jsonb NOT NULL DEFAULT '{}',
    archived_at timestamptz,
    created_by  text,
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS inv_bank_accounts_bus_idx ON invoicing.inv_bank_accounts (tenant_id, bus_id);

CREATE TABLE IF NOT EXISTS invoicing.inv_bank_statements (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    account_id  text NOT NULL REFERENCES invoicing.inv_bank_accounts (id) ON DELETE CASCADE,
    file_name   text NOT NULL DEFAULT '',
    format      text NOT NULL CHECK (format IN ('csv', 'ofx')),
    lines       integer NOT NULL DEFAULT 0,
    duplicates  integer NOT NULL DEFAULT 0,
    first_date  date,
    last_date   date,
    created_by  text,
    cdatetime   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS invoicing.inv_bank_lines (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    account_id    text NOT NULL REFERENCES invoicing.inv_bank_accounts (id) ON DELETE CASCADE,
    statement_id  text NOT NULL REFERENCES invoicing.inv_bank_statements (id) ON DELETE CASCADE,
    posted_on     date NOT NULL,
    description   text NOT NULL DEFAULT '',
    reference     text NOT NULL DEFAULT '',
    amount        numeric(20, 4) NOT NULL,
    fingerprint   text NOT NULL,
    status        text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'matched', 'ignored')),
    payment_ids   text[] NOT NULL DEFAULT '{}',
    note          text NOT NULL DEFAULT '',
    done_by       text,
    done_at       timestamptz,
    UNIQUE (account_id, fingerprint)
);
CREATE INDEX IF NOT EXISTS inv_bank_lines_open_idx ON invoicing.inv_bank_lines (account_id, posted_on) WHERE status = 'open';

ALTER TABLE invoicing.inv_payments ADD COLUMN IF NOT EXISTS bank_line_id text;
CREATE INDEX IF NOT EXISTS inv_payments_bank_line_idx ON invoicing.inv_payments (bank_line_id) WHERE bank_line_id IS NOT NULL;

COMMIT;
