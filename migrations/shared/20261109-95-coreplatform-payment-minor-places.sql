-- Core Platform: a gateway payment or payout keeps the decimal places its amount is counted in.
--
--   cp_payment_collections.minor_places  amount_minor is the amount x 10^minor_places.
--   cp_payouts.minor_places              Until now every caller sent x100 and every gateway
--                                        client assumed it; from now the amount is counted in
--                                        the currency's own places (Core Platform's
--                                        decimal_places, else ISO 4217: 0 for JPY/UGX/XOF,
--                                        3 for KWD/BHD/OMR/JOD/TND) and the clients convert to
--                                        each gateway's own unit. Rows already stored were all
--                                        written as x100, so they get 2 and read as before.
--
-- No amount is changed. Idempotent; safe to re-run. Same shape as 20261109-11 (School).

BEGIN;

ALTER TABLE core_platform.cp_payment_collections ADD COLUMN IF NOT EXISTS minor_places smallint NOT NULL DEFAULT 2;
ALTER TABLE core_platform.cp_payouts             ADD COLUMN IF NOT EXISTS minor_places smallint NOT NULL DEFAULT 2;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                    WHERE conrelid = 'core_platform.cp_payment_collections'::regclass
                      AND conname = 'cp_payment_collections_minor_places_check') THEN
        ALTER TABLE core_platform.cp_payment_collections
            ADD CONSTRAINT cp_payment_collections_minor_places_check CHECK (minor_places BETWEEN 0 AND 4);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                    WHERE conrelid = 'core_platform.cp_payouts'::regclass
                      AND conname = 'cp_payouts_minor_places_check') THEN
        ALTER TABLE core_platform.cp_payouts
            ADD CONSTRAINT cp_payouts_minor_places_check CHECK (minor_places BETWEEN 0 AND 4);
    END IF;
END $$;

DO $$
BEGIN
    IF (SELECT count(*) FROM information_schema.columns
         WHERE table_schema = 'core_platform' AND column_name = 'minor_places'
           AND table_name IN ('cp_payment_collections', 'cp_payouts')) <> 2 THEN
        RAISE EXCEPTION 'cp_payment_collections / cp_payouts have no minor_places';
    END IF;
END $$;

COMMIT;
