-- Invoicing: files attached to an invoice, quote or credit note -- a timesheet, a delivery note,
-- signed terms. The bytes are in Invoicing's own private storage container (path); a file the
-- business marks show_customer can be downloaded from the customer's link too.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS invoicing.inv_attachments (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    invoice_id     text NOT NULL REFERENCES invoicing.inv_invoices (id) ON DELETE CASCADE,
    file_name      text NOT NULL,
    content_type   text NOT NULL DEFAULT 'application/octet-stream',
    size_bytes     bigint NOT NULL DEFAULT 0,
    path           text NOT NULL,
    show_customer  boolean NOT NULL DEFAULT true,
    uploaded_by    text,
    cdatetime      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS inv_attachments_invoice_idx ON invoicing.inv_attachments (invoice_id, cdatetime);

COMMIT;
