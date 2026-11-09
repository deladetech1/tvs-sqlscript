-- Manufacturing: restores the NCR line rules under a name of their own.
--
-- 20261030-12 created mfg_ncr_lines_disposition_check holding the rules below, and 20261030-18 (the
-- values file) re-creates a constraint of the SAME name holding only the list of dispositions. Both
-- files re-run on every deploy, so -18 always wins and these rules were lost. They live here now as
-- mfg_ncr_lines_rules_check: a disposed quantity is positive and no more than the line's quantity,
-- a done line names its disposition, and a regrade names the product it becomes. The list of
-- dispositions stays -18's.
--
-- Added NOT VALID (every new or changed row is checked at once) and validated only when no existing
-- row breaks it, so a database that already holds such a row still deploys; the notice says so.
-- Idempotent; safe to re-run.

BEGIN;

ALTER TABLE mfg.mfg_ncr_lines DROP CONSTRAINT IF EXISTS mfg_ncr_lines_rules_check;
ALTER TABLE mfg.mfg_ncr_lines ADD CONSTRAINT mfg_ncr_lines_rules_check
    CHECK ((disposition_qty IS NULL OR (disposition_qty > 0 AND disposition_qty <= qty))
           AND (done_at IS NULL OR disposition IS NOT NULL)
           AND (disposition IS DISTINCT FROM 'regrade' OR regrade_product_id IS NOT NULL)) NOT VALID;

DO $$
DECLARE bad int;
BEGIN
    SELECT count(*) INTO bad FROM mfg.mfg_ncr_lines
     WHERE NOT ((disposition_qty IS NULL OR (disposition_qty > 0 AND disposition_qty <= qty))
                AND (done_at IS NULL OR disposition IS NOT NULL)
                AND (disposition IS DISTINCT FROM 'regrade' OR regrade_product_id IS NOT NULL));
    IF bad = 0 THEN
        ALTER TABLE mfg.mfg_ncr_lines VALIDATE CONSTRAINT mfg_ncr_lines_rules_check;
    ELSE
        RAISE NOTICE 'mfg_ncr_lines_rules_check: % existing line(s) break the rules; checked for new rows only', bad;
    END IF;
END $$;

COMMIT;
