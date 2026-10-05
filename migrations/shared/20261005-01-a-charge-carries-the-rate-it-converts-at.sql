-- =====================================================================================
-- A platform charge carries the rate it converts at.
--
-- The column has existed since 20261004-11 and nothing ever filled it. The console's
-- charges dialog has no rate field, so every charge was created with rate NULL, and
-- three separate places quietly supplied a 12 instead:
--
--   * the console's read query, as COALESCE(c.rate, 12)
--   * its create handler, as `rate := 12.0`
--   * billSiloLine, as a literal 12.0 in the INSERT
--
-- So the figure shown beside a charge was not the charge's rate. It was a constant
-- repeated in three files, and the day the platform rate moves off 12 the three would
-- have to be found and changed together -- while every charge already raised keeps being
-- displayed at the new one, retroactively restating invoices that were settled at the old.
--
-- The amount was always right; only the conversion was invented. That is the same shape
-- as the currency bug in 20261004-07, where USD amounts were labelled GHS: a wrong number
-- invites a second look and a quietly assumed one does not.
--
-- WHY NOT NULL WITH A DEFAULT
-- A charge is priced in USD and billed to a client who reads their own currency, so there
-- is no such thing as a charge with no rate -- "unknown" is not an answer any screen can
-- render, and leaving it nullable is what let the three constants grow in the first place.
-- The default means the console does not have to send one for the old behaviour, and the
-- backfill means rows that predate this keep the 12 they were being shown at rather than
-- changing value on deploy.
--
-- WHY shared/
-- cp_platform_charges is per-tenant state in core_platform, so a silo's charges live in
-- the silo's own database. Same reasoning as 20261004-11, which created the table.
-- =====================================================================================

ALTER TABLE core_platform.cp_platform_charges
    ALTER COLUMN rate SET DEFAULT 12;

-- The rows that were created before the column was ever filled. 12 and not NULL, because
-- 12 is exactly what every screen was already showing them at -- this records the rate
-- they have been converted at all along rather than deciding a new one for them.
--
-- Idempotent on purpose: every migration re-runs on every deploy, and this only ever
-- fills a NULL. A charge whose rate is deliberately set to something else is never
-- touched, on this deploy or any later one.
UPDATE core_platform.cp_platform_charges
   SET rate = 12
 WHERE rate IS NULL;

ALTER TABLE core_platform.cp_platform_charges
    ALTER COLUMN rate SET NOT NULL;

COMMENT ON COLUMN core_platform.cp_platform_charges.rate IS
    'Local currency per USD for THIS charge -- the rate its invoice lines convert at. '
    'amount is USD; amount * rate is what the client is asked for in their own currency. '
    'Held per charge, not read from cp_app_tier_configs, so that changing the platform '
    'rate does not retroactively restate charges already raised and settled.';

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer; d text;
BEGIN
    -- NOT NULL, or the three constants can come back.
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'core_platform' AND table_name = 'cp_platform_charges'
       AND column_name = 'rate' AND is_nullable = 'NO';
    IF n <> 1 THEN
        RAISE EXCEPTION 'cp_platform_charges.rate is still nullable, so a charge can '
                        'exist with no rate and a screen has to invent one';
    END IF;

    -- A default, so a caller that does not send one gets the platform rate rather than
    -- a failed insert.
    SELECT column_default INTO d FROM information_schema.columns
     WHERE table_schema = 'core_platform' AND table_name = 'cp_platform_charges'
       AND column_name = 'rate';
    IF d IS NULL THEN
        RAISE EXCEPTION 'cp_platform_charges.rate has no default';
    END IF;

    -- And the insert really works without naming rate. Asserted by DOING it, because
    -- "there is a default" and "an insert that omits it succeeds" are different claims
    -- once a NOT NULL is involved.
    BEGIN
        INSERT INTO core_platform.cp_platform_charges
            (id, tenant_id, name, occurrence, amount, created_by)
        VALUES ('pcharge_probe_rate', 'tnt_probe_rate', 'Probe', 'MONTHLY', 1, 'migration');
        SELECT rate INTO n FROM core_platform.cp_platform_charges
         WHERE id = 'pcharge_probe_rate';
        IF n <> 12 THEN
            RAISE EXCEPTION 'a charge created without a rate got %, not the platform 12', n;
        END IF;
        DELETE FROM core_platform.cp_platform_charges WHERE id = 'pcharge_probe_rate';
    END;

    -- Nothing left behind. A probe charge that survived would be billed to a tenant
    -- that does not exist.
    SELECT count(*) INTO n FROM core_platform.cp_platform_charges
     WHERE id = 'pcharge_probe_rate';
    IF n > 0 THEN
        RAISE EXCEPTION 'the probe charge survived';
    END IF;

    RAISE NOTICE 'a platform charge carries its own rate';
END $$;
