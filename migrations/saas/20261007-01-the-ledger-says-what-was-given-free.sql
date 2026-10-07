-- =====================================================================================
-- A month given free is a fact, and the ledger could not state it.
--
-- WAIVED lines are excluded from amount_due, which is correct -- nothing is owed on a
-- free month, and counting it as owed invented a debt the client had already been
-- forgiven. But excluding it was all the ledger did, so a free month arrived at the
-- console as
--
--     2026-09-01 | amount_due 0.00 | amount_paid 0.00
--
-- which is the same row a month with no bill at all produces. "We gave them September"
-- and "September was never billed" are different facts about a client, and an operator
-- reading the second when the first is true has no way to find out.
--
-- So the amount is carried beside the other two rather than folded into either. Not
-- into amount_due, which would undo the fix that stopped it reading as a debt, and not
-- into amount_paid, which would make a gift look like money collected and lift the
-- collection rate on the dashboard for revenue nobody received.
--
-- APPENDED AT THE END of the view, like local_currency and rate before it. CREATE OR
-- REPLACE VIEW may only add columns at the end: slotting it beside amount_paid where it
-- belongs makes PostgreSQL read it as RENAMING the following column and refuse. Ugly
-- column order is the cheaper price, and 20261004-07 already writes out why DROP and
-- recreate is not the alternative -- the GRANTs on this view are issued by files that
-- run earlier in filename order, so a drop would re-grant against a view that no longer
-- exists and the console would lose its billing screens.
-- =====================================================================================

-- ------------------------------------------------------------------------- the column
-- NOT NULL DEFAULT 0, so every row already in the ledger reads as "nothing was given
-- away in this period" rather than as unknown. That is true of all of them: before this
-- column existed, a waived amount was not recorded anywhere, so there is nothing to
-- backfill and no month whose figure is merely missing. The next report restates the
-- recent window anyway and fills in what is current.
ALTER TABLE control_plane.ctl_billing_facts
    ADD COLUMN IF NOT EXISTS amount_waived numeric NOT NULL DEFAULT 0;

COMMENT ON COLUMN control_plane.ctl_billing_facts.amount_waived IS
    'What was billed for this period and then given away -- a trial, or a month an '
    'operator forgave. Beside amount_due and amount_paid, never inside either: it is '
    'not owed, and it was not collected.';

-- --------------------------------------------------------------------------- the view
CREATE OR REPLACE VIEW control_plane.ctl_billing_facts_current AS
SELECT DISTINCT ON (source_db, tenant_id, app_id, period, line_type)
       id, report_id, source_db, host, tier, silo_key, tenant_id, app_id,
       period, period_label, line_type, currency,
       amount_due, amount_paid, line_count, paid_line_count, billable_units,
       observed_at,
       local_currency, rate,
       amount_waived
  FROM control_plane.ctl_billing_facts
 ORDER BY source_db, tenant_id, app_id, period, line_type, observed_at DESC, id DESC;

-- ------------------------------------------------------------------------------ checks
DO $$
DECLARE n integer;
BEGIN
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'control_plane'
       AND table_name = 'ctl_billing_facts'
       AND column_name = 'amount_waived';
    IF n <> 1 THEN
        RAISE EXCEPTION 'ctl_billing_facts has no amount_waived column';
    END IF;

    -- The whole point of the file: the view must expose it, or the console still
    -- cannot tell a free month from one that was never billed.
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'control_plane'
       AND table_name = 'ctl_billing_facts_current'
       AND column_name = 'amount_waived';
    IF n <> 1 THEN
        RAISE EXCEPTION
            'ctl_billing_facts_current does not expose amount_waived -- an earlier '
            'migration has re-asserted the old column list over this one';
    END IF;

    -- And the view still answers, which a broken DISTINCT ON would not.
    PERFORM count(*) FROM control_plane.ctl_billing_facts_current;

    RAISE NOTICE 'the ledger can now say what was given away';
END $$;
