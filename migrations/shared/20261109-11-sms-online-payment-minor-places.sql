-- School: an online payment keeps the decimal places its amount was sent to the gateway with.
--
--   sms_online_payments.minor_places  amount_minor is the amount x 10^minor_places. Until now
--                                     every amount was sent as x100; from now the app uses the
--                                     currency's own places (Core Platform's decimal_places, else
--                                     ISO), so each row says which it used. Rows already stored
--                                     were all written as x100, so they get 2 and read as before.
--
-- No amount is changed. Idempotent; safe to re-run.

BEGIN;

ALTER TABLE sms.sms_online_payments ADD COLUMN IF NOT EXISTS minor_places smallint NOT NULL DEFAULT 2;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                    WHERE conrelid = 'sms.sms_online_payments'::regclass AND conname = 'sms_online_payments_minor_places_check') THEN
        ALTER TABLE sms.sms_online_payments ADD CONSTRAINT sms_online_payments_minor_places_check CHECK (minor_places BETWEEN 0 AND 4);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'sms' AND table_name = 'sms_online_payments' AND column_name = 'minor_places') THEN
        RAISE EXCEPTION 'sms_online_payments has no minor_places';
    END IF;
END $$;

COMMIT;
