-- CloudHams: an invoice's tax is one of the business's taxes in Core Platform.
--
-- Taxes are defined in Core Platform only (core_platform.cp_tax_rates, owner's decision
-- 2026-10-19); apps pick from them. A hospital invoice now names the tax it charges (tax_id) and
-- keeps a copy of its rate as it was then (tax_percent, as before), so a later change in Core
-- never rewrites an invoice already sent. Invoices drafted before this keep their typed
-- percentage and no tax_id.
--
-- No foreign key: Core's taxes live in another schema and are archived, never deleted.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE hospital.hospital_invoices ADD COLUMN IF NOT EXISTS tax_id text;

COMMIT;
