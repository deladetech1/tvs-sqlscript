-- Invoicing bills a project's time and expenses (from Projects).
--
-- A business that has both apps can put a project's unbilled billable time (grouped by person
-- at their bill rate, or by work item) and billable expenses on an Invoicing invoice. Each such
-- line keeps where it came from (inv_invoice_lines.source_*), and the time and expenses it
-- bills point at the invoice (prj_worklogs / prj_expenses.inv_invoice_id), so neither app bills
-- them again: Projects counts them as billed, as it does its own invoices' (invoice_id). Saving
-- the draft claims them; taking the line off, deleting the draft or voiding the invoice frees
-- them. A project remembers the Invoicing customer it was billed to (inv_customer_id).
--
-- No foreign keys across the two apps' schemas: each app's tables stay its own.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE projects.prj_worklogs ADD COLUMN IF NOT EXISTS inv_invoice_id text;
ALTER TABLE projects.prj_expenses ADD COLUMN IF NOT EXISTS inv_invoice_id text;
CREATE INDEX IF NOT EXISTS prj_worklogs_inv_invoice_idx ON projects.prj_worklogs (inv_invoice_id) WHERE inv_invoice_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS prj_expenses_inv_invoice_idx ON projects.prj_expenses (inv_invoice_id) WHERE inv_invoice_id IS NOT NULL;
ALTER TABLE projects.prj_projects ADD COLUMN IF NOT EXISTS inv_customer_id text;

ALTER TABLE invoicing.inv_invoice_lines
    ADD COLUMN IF NOT EXISTS source_kind       text,
    ADD COLUMN IF NOT EXISTS source_project_id text,
    ADD COLUMN IF NOT EXISTS source_ids        text[] NOT NULL DEFAULT '{}';

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inv_invoice_lines_source_check') THEN
        ALTER TABLE invoicing.inv_invoice_lines ADD CONSTRAINT inv_invoice_lines_source_check
            CHECK (source_kind IS NULL OR source_kind IN ('time', 'expense'));
    END IF;
END $$;

COMMIT;
