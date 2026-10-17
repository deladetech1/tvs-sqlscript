-- Invoicing Release 5: customer statements and the customer portal.
--
-- inv_customers.portal_token: 48 hex characters, the key to a customer's own page -- no
-- sign-in -- listing what they owe, their invoices, quotes and credit notes (each opening on its
-- own link, to pay or accept), and their statement. Made when first asked for; a new one ends
-- the old.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE invoicing.inv_customers ADD COLUMN IF NOT EXISTS portal_token text;
CREATE UNIQUE INDEX IF NOT EXISTS inv_customers_portal_uq ON invoicing.inv_customers (portal_token) WHERE portal_token IS NOT NULL;

COMMIT;
