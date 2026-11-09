-- HMS assumes no currency. Its currencies are the tenant's own, set up in Core Platform
-- (Settings > General > Currencies; core_platform.cp_currencies), and the app always writes the
-- code it was given: the settings' currency is chosen from those, and every reservation, bill and
-- lease is made in the business's currency at the time. Four columns still defaulted to 'GHS'
-- (from 20261022-62 and 20261022-63), which would quietly make a record in cedis for a business
-- that never chose them. The defaults go; the columns stay NOT NULL, so a write that forgets the
-- currency fails instead of guessing.
--
-- Records keep the code they were made in: no existing row is changed.
--
-- Idempotent; safe to re-run on every deploy (DROP DEFAULT on a column with none is a no-op).

BEGIN;

ALTER TABLE IF EXISTS hms.hms_settings     ALTER COLUMN currency DROP DEFAULT;
ALTER TABLE IF EXISTS hms.hms_reservations ALTER COLUMN currency DROP DEFAULT;
ALTER TABLE IF EXISTS hms.hms_folios       ALTER COLUMN currency DROP DEFAULT;
ALTER TABLE IF EXISTS hms.hms_leases       ALTER COLUMN currency DROP DEFAULT;

DO $$
DECLARE
    bad text;
BEGIN
    SELECT string_agg(table_name, ', ') INTO bad
      FROM information_schema.columns
     WHERE table_schema IN ('hms', 'hospital') AND column_name = 'currency'
       AND column_default ~* '''(GHS|USD)''';
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'a hospital or HMS currency column still defaults to a made-up currency: %', bad;
    END IF;
END $$;

COMMIT;
