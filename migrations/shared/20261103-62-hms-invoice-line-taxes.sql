-- HMS invoices take their taxes from Core Platform, the one place taxes are defined: a line names
-- the tax (core_platform.cp_tax_rates) and keeps a copy of its rate as it was, so a later change
-- in Core never rewrites an invoice already sent. Lines from before keep the rate typed in.
-- Idempotent.

BEGIN;

ALTER TABLE hms.hms_invoice_lines ADD COLUMN IF NOT EXISTS tax_id text;

COMMIT;
