-- Invoicing: exports for the business's accountant.
--
-- inv_settings.accounting: how the business's own books name things, for the exports (Xero,
-- QuickBooks, Sage and a double-entry journal): the receivable account, sales accounts (by
-- item category), tax accounts and each accounting package's tax code per tax rate, the bank
-- account each payment method lands in, withholding tax receivable, and late fees. Anything
-- left out falls back to a sensible default code.
--
-- inv_customers.account_ref: the customer's account code in the books (Sage's account
-- reference, QuickBooks' customer). Derived from the name when empty.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE invoicing.inv_settings ADD COLUMN IF NOT EXISTS accounting jsonb NOT NULL DEFAULT '{}';
ALTER TABLE invoicing.inv_customers ADD COLUMN IF NOT EXISTS account_ref text NOT NULL DEFAULT '';

COMMIT;
