-- MyStoreGuard: an invoice can be raised without taking items from store stock
-- (services, goods supplied from elsewhere, a pro-forma style bill).
--
--   msg_invoices.takes_stock   true (default, every existing invoice) = today's behaviour: lines
--                              reserve and deduct batches and the sale behind its payments moves
--                              them. false = nothing ever touches stock for it - no reservation,
--                              batch_location, store_products qty, movement or serialised unit, on
--                              create, edit, delete, payment, release or return - and the sale
--                              lines it creates carry a zero cost, so Accounting posts revenue and
--                              receivables but no cost of goods.
--
-- The choice is made at creation and never changes. tvs-mystoreguard-bk reads the column when it
-- exists and treats its absence as true. Idempotent; safe to re-run.

ALTER TABLE mystoreguard.msg_invoices
    ADD COLUMN IF NOT EXISTS takes_stock boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN mystoreguard.msg_invoices.takes_stock IS
    'false = raised with "take items from store stock" off: no stock is reserved, deducted or moved for it, ever';
