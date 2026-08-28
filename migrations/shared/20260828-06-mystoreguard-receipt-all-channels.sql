-- 20260828-06-mystoreguard-receipt-all-channels.sql
-- A receipt goes wherever the customer can be reached.
--
-- The channel was one of EMAIL or SMS, which meant a business had to pick a
-- side and every customer missing that one detail got nothing — a customer who
-- gave only a phone number is invisible to an email-only shop, and vice versa.
--
-- ALL is now the default: send by every route the customer gave us, and by both
-- when they gave both. EMAIL and SMS remain choosable for a business that wants
-- to hold SMS spend down or send nothing but email.
--
-- Existing rows keep whatever they were set to. Only the default for new rows
-- changes, so a business that deliberately chose SMS is not quietly widened.
--
-- Idempotent; safe to re-run on every deploy.

ALTER TABLE mystoreguard.msg_receipt_settings
    ALTER COLUMN auto_send_channel SET DEFAULT 'ALL';

DO $$
BEGIN
    -- The old CHECK allowed only EMAIL and SMS, so ALL has to replace it rather
    -- than sit beside it.
    IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_msg_receipt_settings_auto_send_channel'
    ) THEN
        ALTER TABLE mystoreguard.msg_receipt_settings
            DROP CONSTRAINT ck_msg_receipt_settings_auto_send_channel;
    END IF;

    ALTER TABLE mystoreguard.msg_receipt_settings
        ADD CONSTRAINT ck_msg_receipt_settings_auto_send_channel
        CHECK (auto_send_channel IN ('ALL', 'EMAIL', 'SMS'));
END $$;
