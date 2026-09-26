-- =====================================================================
-- When a bill was paid, by whom, and how much in the currency people use
-- ---------------------------------------------------------------------
-- cp_billings_logs records that a bill was paid. It does not usefully record
-- when, who, or how much, and each of those fails differently.
--
--   WHEN   paid_date is `text`, holding a sentence: "Friday 14th August,
--          2026". There is no time in it at all, and no way to order two
--          payments made on the same day. A payments screen cannot show a
--          clock it was never given.
--
--   WHO    paid_by holds either a user id or the literal string 'PAYSTACK'.
--          Two different kinds of thing in one column, so it cannot be joined
--          to cp_users without special-casing sentinels, and no amount of
--          reading it tells you whether a person was involved.
--
--   HOW    paid_amount is set to `price`, which is USD. A bill of GH₵2,280
--   MUCH   records paid_amount = 190. Anything printing that column as the
--          amount paid is out by the exchange rate — the same twelvefold
--          error already found and fixed in four other places.
--
-- Three new columns rather than repairs to the old ones. Nothing here
-- rewrites or drops an existing column: paid_date, paid_by and paid_amount
-- keep their values and their meanings, and every query that reads them today
-- goes on working unchanged. The cost is three columns that overlap with
-- three others; the alternative is a destructive migration against the table
-- that records what customers have paid, which is not a trade worth making
-- for tidiness.
--
-- paid_at is deliberately NOT backfilled
-- --------------------------------------
-- There is no time to backfill it WITH. Filling it from paid_date would put
-- every historical payment at midnight, and a screen would then show
-- "12:00 AM" — a fact, stated precisely, that is not true. NULL means "no
-- timestamp was recorded", the screen falls back to the date string it does
-- have, and it shows no clock. An honest gap beats a confident fabrication.
--
-- Idempotent; safe to re-run on every deploy.
-- =====================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'core_platform'
           AND table_name = 'cp_billings_logs'
           AND column_name = 'paid_at'
    ) THEN
        ALTER TABLE core_platform.cp_billings_logs
            ADD COLUMN paid_at timestamptz;
        COMMENT ON COLUMN core_platform.cp_billings_logs.paid_at IS
            'When the payment settled. NULL on rows written before this '
            'existed — paid_date is the only record for those, and it has no '
            'time in it.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'core_platform'
           AND table_name = 'cp_billings_logs'
           AND column_name = 'paid_source'
    ) THEN
        ALTER TABLE core_platform.cp_billings_logs
            ADD COLUMN paid_source text;
        COMMENT ON COLUMN core_platform.cp_billings_logs.paid_source IS
            'USER (a person paid), SYSTEM (the nightly auto-charge), or '
            'GATEWAY (settled by a provider webhook). Says whether paid_by '
            'names a person, which paid_by alone cannot.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'core_platform'
           AND table_name = 'cp_billings_logs'
           AND column_name = 'paid_amount_ghs'
    ) THEN
        ALTER TABLE core_platform.cp_billings_logs
            ADD COLUMN paid_amount_ghs numeric;
        COMMENT ON COLUMN core_platform.cp_billings_logs.paid_amount_ghs IS
            'What was actually collected, in the charging currency. '
            'paid_amount is USD (it is set to price); this is price * rate, '
            'the figure the customer was quoted and charged.';
    END IF;
END $$;


-- Nothing is backfilled, on purpose
-- -------------------------------
-- An earlier version of this file rewrote every PAID row to fill
-- paid_source and paid_amount_ghs. It ran in a quarter of a second against
-- dev's seventy-three bills, which told me nothing useful: the runner sends
-- each file as ONE implicit transaction under a 600-second statement
-- timeout, so on a database with real volume that UPDATE holds a row lock on
-- every paid bill — against the very statements that settle payments — and
-- if it overruns the timeout the whole file rolls back and the columns never
-- arrive at all.
--
-- It was also unnecessary, which is the part that settles it. Neither value
-- has to be stored to be shown:
--
--   paid_amount_ghs  the reader already falls back to price * rate, which is
--                    the same arithmetic this backfill would have frozen in.
--   paid_source      inferred at read time from the shape of paid_by — the
--                    two machine sentinels and the uid_ prefix — which is
--                    exactly what the backfill was going to infer anyway.
--
-- So this migration is now three instant metadata changes and an index. It
-- costs O(1) instead of O(rows), and there is no version of a busy
-- production table where it is the slow part of a deploy.
--
-- New payments fill all three columns as they settle. Historical rows keep
-- their NULLs and read correctly regardless.


-- The payments screen reads the paid rows for one tenant, newest first.
-- Partial, so it indexes only what that screen looks at and not the pending
-- majority.
CREATE INDEX IF NOT EXISTS idx_cp_billings_logs_paid_history
    ON core_platform.cp_billings_logs (tenant_id, paid_at DESC NULLS LAST)
    WHERE paid_status = 'PAID';
