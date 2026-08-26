-- =====================================================================
-- Invoices raised for goods not yet held, and fulfilled when they arrive
-- ---------------------------------------------------------------------
-- msg_price_edit_settings.invoice_no_stock_* names who may raise an invoice
-- for stock the shop does not have (20260820-01). Raising it was only ever
-- half the rule. The other half is what happens when such an invoice is
-- PAID: it must not become a sale there and then, because there is nothing
-- to sell. It waits, and the stock moves when the goods are sourced.
--
-- Two columns, because intent and state are different questions:
--
--   no_stock_allowed    Was the person who raised this invoice covered by
--                       the rule? Settled once, at creation, so a later
--                       change to the settings cannot strand an invoice
--                       that was legitimate when it was raised.
--
--   fulfilment_status   Where it has got to. NULL for every ordinary
--                       invoice - the overwhelming majority - so this reads
--                       as "not part of that flow" rather than as a state
--                       every invoice has to be given.
--                         AWAITING   paid, nothing sold, no stock moved
--                         FULFILLED  stock arrived, sale created, stock moved
--
-- An invoice only reaches AWAITING when payment finds the stock short AND
-- no_stock_allowed is true. Stock arriving before payment therefore takes
-- the ordinary path and never enters this flow at all, which is the common
-- case and should stay uncomplicated.
--
-- Idempotent; safe to re-run on every deploy.
-- =====================================================================

SET search_path TO mystoreguard;

ALTER TABLE mystoreguard.msg_invoices
    ADD COLUMN IF NOT EXISTS no_stock_allowed  boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS fulfilment_status text,
    ADD COLUMN IF NOT EXISTS fulfilled_at      timestamptz,
    ADD COLUMN IF NOT EXISTS fulfilled_by      text;

-- Only the two states are writable; NULL stays the ordinary case.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'msg_invoices_fulfilment_status_check'
    ) THEN
        ALTER TABLE mystoreguard.msg_invoices
            ADD CONSTRAINT msg_invoices_fulfilment_status_check
            CHECK (fulfilment_status IS NULL
                   OR fulfilment_status IN ('AWAITING', 'FULFILLED'));
    END IF;
END $$;

-- The only query this adds is "what is still waiting", per location, and it
-- is a small slice of a big table - so the index carries just those rows.
CREATE INDEX IF NOT EXISTS idx_msg_invoices_awaiting_fulfilment
    ON mystoreguard.msg_invoices (tenant_id, org_id, bus_id, loc_id)
    WHERE fulfilment_status = 'AWAITING';

COMMENT ON COLUMN mystoreguard.msg_invoices.no_stock_allowed IS
    'True when whoever raised this invoice was covered by invoice_no_stock. Settled at creation.';
COMMENT ON COLUMN mystoreguard.msg_invoices.fulfilment_status IS
    'NULL for ordinary invoices. AWAITING = paid but nothing sold yet. FULFILLED = sale created, stock moved.';
