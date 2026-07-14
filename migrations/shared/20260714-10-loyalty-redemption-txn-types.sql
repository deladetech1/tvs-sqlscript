-- Loyalty points at checkout: allow the ledger to record points returned when a
-- sale is cancelled (REFUND) and points clawed back when a sale is returned
-- (REVERSAL), alongside the existing EARN / REDEEM / ADJUST / EXPIRE types.
-- Idempotent.

ALTER TABLE mystoreguard.msg_loyalty_transactions
    DROP CONSTRAINT IF EXISTS ck_msg_loyalty_transactions_txn_type;
ALTER TABLE mystoreguard.msg_loyalty_transactions
    ADD CONSTRAINT ck_msg_loyalty_transactions_txn_type
    CHECK (txn_type IN ('EARN', 'REDEEM', 'ADJUST', 'EXPIRE', 'REFUND', 'REVERSAL'));
