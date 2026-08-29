-- 20260828-05-mystoreguard-auto-send-receipt.sql
-- Whether a receipt is sent to the customer when a payment is recorded.
--
-- Lives with the rest of the receipt configuration rather than in its own
-- table: this is a decision about receipts, and Settings → Receipt is where
-- somebody looks for it.
--
-- Off by default, deliberately. Turning it on starts sending to customers, and
-- on the SMS channel starts spending credits — neither should begin because a
-- column was added.
--
-- Idempotent; safe to re-run on every deploy.

ALTER TABLE mystoreguard.msg_receipt_settings
    ADD COLUMN IF NOT EXISTS auto_send_on_payment boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS auto_send_channel    text    NOT NULL DEFAULT 'EMAIL';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_msg_receipt_settings_auto_send_channel'
    ) THEN
        ALTER TABLE mystoreguard.msg_receipt_settings
            ADD CONSTRAINT ck_msg_receipt_settings_auto_send_channel
            CHECK (auto_send_channel IN ('EMAIL', 'SMS'));
    END IF;
END $$;
