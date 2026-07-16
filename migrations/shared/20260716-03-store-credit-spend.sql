-- 20260716-03-store-credit-spend.sql
-- Store credit at point-of-sale: redeem as a tender and route overpayment/change
-- into store credit. Links ledger rows to their source sale, and records the
-- amounts on the sale header. Idempotent.

-- Ledger can be sourced from a sale (redeem / change), not just a return.
ALTER TABLE mystoreguard.msg_store_credit_transactions
    ADD COLUMN IF NOT EXISTS source_sale_id text;

CREATE INDEX IF NOT EXISTS ix_msg_store_credit_transactions_sale
    ON mystoreguard.msg_store_credit_transactions (tenant_id, org_id, bus_id, source_sale_id);

-- Record store credit used / change issued on the sale.
ALTER TABLE mystoreguard.msg_sales
    ADD COLUMN IF NOT EXISTS store_credit_amount_used   numeric(18,2) DEFAULT 0,  -- credit redeemed toward the sale
    ADD COLUMN IF NOT EXISTS store_credit_change_issued numeric(18,2) DEFAULT 0;  -- overpayment routed to store credit

-- Allow STORE_CREDIT as a sale payment tender (extends the existing check).
ALTER TABLE mystoreguard.msg_sales_payments
    DROP CONSTRAINT IF EXISTS ck_msg_sales_payments_payment_method;
ALTER TABLE mystoreguard.msg_sales_payments
    ADD CONSTRAINT ck_msg_sales_payments_payment_method
    CHECK (payment_method IN
        ('CASH','CARD','BANK_TRANSFER','MOBILE_MONEY','CHEQUE','BITCOIN','GIFT_CARD','LOYALTY_POINTS','STORE_CREDIT','OTHERS'));
