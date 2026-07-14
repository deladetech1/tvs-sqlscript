-- Loyalty points at checkout. Two constraint changes for the redemption feature:
--   1. The ledger records points returned when a sale is cancelled (REFUND) and
--      clawed back when a sale is returned (REVERSAL), alongside the existing
--      EARN / REDEEM / ADJUST / EXPIRE types.
--   2. LOYALTY_POINTS becomes a valid tender on sale payments.
-- The EF configs are the source of truth (SalesConfigurations.cs); these ALTERs
-- land the same change on already-deployed databases. Idempotent.

ALTER TABLE mystoreguard.msg_loyalty_transactions
    DROP CONSTRAINT IF EXISTS ck_msg_loyalty_transactions_txn_type;
ALTER TABLE mystoreguard.msg_loyalty_transactions
    ADD CONSTRAINT ck_msg_loyalty_transactions_txn_type
    CHECK (txn_type IN ('EARN', 'REDEEM', 'ADJUST', 'EXPIRE', 'REFUND', 'REVERSAL'));

ALTER TABLE mystoreguard.msg_sales_payments
    DROP CONSTRAINT IF EXISTS ck_msg_sales_payments_payment_method;
ALTER TABLE mystoreguard.msg_sales_payments
    ADD CONSTRAINT ck_msg_sales_payments_payment_method
    CHECK (payment_method IN ('CASH', 'CARD', 'BANK_TRANSFER', 'MOBILE_MONEY',
        'CHEQUE', 'BITCOIN', 'GIFT_CARD', 'LOYALTY_POINTS', 'OTHERS'));

-- Track the loyalty redemption on the sale itself (mirrors gift_card_amount_used),
-- so a sale shows how many points were burned and their currency value.
ALTER TABLE mystoreguard.msg_sales
    ADD COLUMN IF NOT EXISTS loyalty_points_used numeric(18, 2) NOT NULL DEFAULT 0;
ALTER TABLE mystoreguard.msg_sales
    ADD COLUMN IF NOT EXISTS loyalty_amount_used numeric(18, 2) NOT NULL DEFAULT 0;
