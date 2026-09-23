-- A refunded payment says when it was given back, and why.
--
-- msg_sales_payments records when a payment was taken and who took it, and
-- nothing about it ever changing after that: there is no update timestamp on
-- the table. So a payment marked REFUNDED could say that it had been given
-- back but not when, and a statement listing it had to date the refund to the
-- day the money came IN — which is the one date it certainly was not.
--
-- The reason goes in its own column rather than being appended to the
-- payment's description. A description that grows a second sentence is two
-- records of one fact, and the next person to read it cannot tell which part
-- the till wrote and which part the refund did.
--
-- Replayable.

BEGIN;

ALTER TABLE mystoreguard.msg_sales_payments
    ADD COLUMN IF NOT EXISTS refunded_at    TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS refunded_by    TEXT,
    ADD COLUMN IF NOT EXISTS refund_reason  TEXT;

COMMENT ON COLUMN mystoreguard.msg_sales_payments.refunded_at IS
    'When this payment was given back. NULL unless payment_status is REFUNDED.';
COMMENT ON COLUMN mystoreguard.msg_sales_payments.refunded_by IS
    'Who gave it back.';
COMMENT ON COLUMN mystoreguard.msg_sales_payments.refund_reason IS
    'Why it was given back, in the words of whoever did it.';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conrelid = 'mystoreguard.msg_sales_payments'::regclass
           AND conname  = 'fk_msg_sales_payments_refunded_by'
    ) THEN
        ALTER TABLE mystoreguard.msg_sales_payments
            ADD CONSTRAINT fk_msg_sales_payments_refunded_by
            FOREIGN KEY (refunded_by, tenant_id)
            REFERENCES core_platform.cp_users (id, tenant_id)
            ON DELETE RESTRICT;
    END IF;
END $$;

COMMIT;
