-- =====================================================================================
-- The billing ledger was labelling USD amounts with the customer's local currency.
--
-- WHAT WENT WRONG
-- cp_app_tier_configs.price is in USD -- 190.00 means $190 per location per month -- and
-- cp_app_tier_configs.rate says how many units of local currency one USD buys, 12.0 for
-- Ghana Cedis. Every cp_billings_logs row snapshots both.
--
-- 20261004-01 carried the amounts faithfully and then took `currency` from
-- cp_currencies.is_default, which is the tenant's DISPLAY currency. So a customer billed
-- $5,250 a month was reported as "GHS 5,250" and the console printed it with a cedi
-- sign. Off by the rate -- a factor of twelve -- in the direction that understates what
-- the business earns, on every screen that shows money.
--
-- The amounts were never wrong. Only the label was, which is worse: a wrong number
-- invites a second look and a wrong unit does not.
--
-- WHY BOTH, AND NOT A CONVERSION
-- The honest fix is not to convert the stored amounts. USD is the currency the price is
-- SET in and the only one comparable across customers -- an MRR summed over tenants on
-- different local currencies is meaningless otherwise. So `currency` now says USD
-- because that is what the figures are, and the local currency and the rate ride
-- alongside so a screen can also say what the customer actually pays.
--
-- The rate is carried, not looked up. A rate looked up at read time would silently
-- restate last June's bill at today's rate, and the whole reason cp_billings_logs
-- snapshots it is that an invoice must not move.
-- =====================================================================================

ALTER TABLE control_plane.ctl_billing_facts
    ADD COLUMN IF NOT EXISTS local_currency text,
    ADD COLUMN IF NOT EXISTS rate           numeric(12,4);

ALTER TABLE control_plane.ctl_billing_customers
    ADD COLUMN IF NOT EXISTS local_currency text,
    ADD COLUMN IF NOT EXISTS rate           numeric(12,4);

ALTER TABLE control_plane.ctl_billing_reports
    ADD COLUMN IF NOT EXISTS local_currency text,
    ADD COLUMN IF NOT EXISTS rate           numeric(12,4);

COMMENT ON COLUMN control_plane.ctl_billing_facts.local_currency IS
    'What the customer is invoiced in, e.g. GHS. The amounts on this row are NOT in it '
    '-- they are in `currency`, which is USD. Multiply by `rate` for the local figure.';
COMMENT ON COLUMN control_plane.ctl_billing_facts.rate IS
    'Units of local_currency per 1 of `currency`, as snapshotted on the billing rows '
    'this fact aggregates. Carried rather than looked up, so a past month is never '
    'restated at today''s rate. NULL where a period''s rows disagreed.';

COMMENT ON COLUMN control_plane.ctl_billing_customers.local_currency IS
    'What this customer is invoiced in. mrr, lifetime_paid and outstanding are in '
    '`currency` (USD), not in this.';
COMMENT ON COLUMN control_plane.ctl_billing_customers.rate IS
    'Units of local_currency per 1 USD for this customer now. The CURRENT rate, unlike '
    'the one on a fact -- this row describes today, and a fact describes a month.';

-- The latest-wins views must expose the new columns, or every reader keeps seeing the
-- old shape and the console cannot tell USD from cedis.
--
-- APPENDED AT THE END, not slotted in beside `currency` where they belong. CREATE OR
-- REPLACE VIEW may only ADD columns to the end -- putting local_currency after
-- `currency` makes PostgreSQL read it as renaming `amount_due`, and it refuses:
--
--     cannot change name of view column "amount_due" to "local_currency"
--
-- The alternative is DROP and recreate, which would silently take the grants with it.
-- 20261004-01 and -03 grant SELECT on these views to the console's logins, and they
-- run BEFORE this file in filename order -- so on the very deploy that dropped them,
-- the grants would be re-applied to a view that no longer existed and the console
-- would lose the billing screens. Ugly column order is the cheaper price.
-- STANDS ASIDE ONCE 20261007-01 HAS EXTENDED THIS VIEW, for exactly the reason
-- written out below for ctl_billing_customers_current: re-asserting this column
-- list after a later file appended to it gives 42P16 and stops the deploy before
-- the file that owns the final shape is reached.
--
-- Guarded on `amount_waived`, which 20261007-01 adds. A fresh database has to
-- get this definition first so that file has something to extend, which is why
-- the test is for the COLUMN and not for the view existing.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'control_plane'
                  AND table_name = 'ctl_billing_facts_current'
                  AND column_name = 'amount_waived') THEN
        RAISE NOTICE 'ctl_billing_facts_current already carries amount_waived; 20261007-01 owns its shape';
        RETURN;
    END IF;
    EXECUTE $view$
        CREATE OR REPLACE VIEW control_plane.ctl_billing_facts_current AS
        SELECT DISTINCT ON (source_db, tenant_id, app_id, period, line_type)
               id, report_id, source_db, host, tier, silo_key, tenant_id, app_id,
               period, period_label, line_type, currency,
               amount_due, amount_paid, line_count, paid_line_count, billable_units,
               observed_at,
               local_currency, rate
          FROM control_plane.ctl_billing_facts
         ORDER BY source_db, tenant_id, app_id, period, line_type, observed_at DESC, id DESC
    $view$;
END $$;

-- STANDS ASIDE ONCE 20261004-13 HAS EXTENDED THIS VIEW.
--
-- Every migration re-runs on every deploy, so re-asserting this column list
-- after a later file appended to it gives
--
--     42P16: cannot drop columns from view
--
-- and the deploy stops before the file that owns the final shape is reached.
-- The dev pipeline had been failing on exactly this since 2026-10-04.
--
-- "Later wins" is the convention here and it holds for a seed -- a DELETE or an
-- UPDATE simply runs again. It does not hold for a view or a constraint, where
-- the earlier statement ERRORS first and the later one never runs.
--
-- GUARDED ON A COLUMN, not on the view existing. Skipping whenever the view is
-- present would be wrong in the other direction: on a FRESH database this file
-- has to create it so the later ones can extend it, and a bare existence check
-- would leave a new database stuck on this definition for ever. `charges_mrr`
-- is added by 20261004-13, so its presence means the later shape is already in
-- place and this statement would only undo it.
--
-- DROP and recreate is not the answer either, for the reason 20261004-07 writes
-- out: the GRANTs on these views are issued by files that run earlier in
-- filename order, so a drop would re-grant against a view that no longer exists
-- and the console would lose its billing screens.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'control_plane'
                  AND table_name = 'ctl_billing_customers_current'
                  AND column_name = 'charges_mrr') THEN
        RAISE NOTICE 'ctl_billing_customers_current already carries charges_mrr; 20261004-13 owns its shape';
        RETURN;
    END IF;
    EXECUTE $view$
CREATE OR REPLACE VIEW control_plane.ctl_billing_customers_current AS
SELECT DISTINCT ON (source_db, tenant_id)
       id, report_id, source_db, host, tier, silo_key, tenant_id,
       plans, apps, subs_total, subs_active, subs_trialing, subs_past_due, subs_lapsed,
       is_enterprise, next_charge_date, period_end, currency,
       mrr, lifetime_paid, outstanding, oldest_unpaid, payment_method,
       has_payment_method, auto_renew, observed_at,
       local_currency, rate
  FROM control_plane.ctl_billing_customers
 ORDER BY source_db, tenant_id, observed_at DESC, id DESC;
$view$;
END $$;

-- A rate of zero or below would make every local figure wrong in a way that reads as
-- configured rather than missing. NULL stays allowed: "the rows disagreed" is a real
-- answer and the honest one.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conrelid = 'control_plane.ctl_billing_facts'::regclass
           AND conname  = 'ck_ctl_billing_facts_rate'
    ) THEN
        ALTER TABLE control_plane.ctl_billing_facts
            ADD CONSTRAINT ck_ctl_billing_facts_rate
            CHECK (rate IS NULL OR rate > 0);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conrelid = 'control_plane.ctl_billing_customers'::regclass
           AND conname  = 'ck_ctl_billing_customers_rate'
    ) THEN
        ALTER TABLE control_plane.ctl_billing_customers
            ADD CONSTRAINT ck_ctl_billing_customers_rate
            CHECK (rate IS NULL OR rate > 0);
    END IF;
END $$;

-- ----------------------------------------------------------------- the old rows
-- WHY THIS IS A BACKFILL AFTER ALL
--
-- The first version of this file said none was needed: the views are latest-wins, so
-- one run of the corrected reporter replaces every current figure. That is true only
-- for keys that get reported AGAIN -- and a fact's key includes its tenant and its
-- period.
--
-- Running it proved the gap. Two facts on dev stayed GHS: Sep and Oct 2026 for a tenant
-- that has since been CLEARED. It has no billing rows, no subscriptions and no row in
-- cp_tenants, so no report will ever mention it again, and its last snapshot is
-- immortal -- correct history, wearing the wrong label, permanently.
--
-- So the rows are corrected here. This is not a guess: the amounts were ALWAYS USD, and
-- `currency` always held the tenant's local code, so moving that code to local_currency
-- and writing USD is exactly what the row already meant.
--
-- Only rows the new reporter has not already written: local_currency IS NULL identifies
-- them, because every row it writes sets it.
--
-- The rate is deliberately NOT filled in. 12.0 is today's and these are finished
-- months; a rate invented for a past month would make a local total that reconciles
-- against no invoice. NULL says "we did not record it", which is the truth.
UPDATE control_plane.ctl_billing_facts
   SET local_currency = currency,
       currency       = 'USD'
 WHERE currency IS DISTINCT FROM 'USD'
   AND local_currency IS NULL;

UPDATE control_plane.ctl_billing_customers
   SET local_currency = currency,
       currency       = 'USD'
 WHERE currency IS DISTINCT FROM 'USD'
   AND local_currency IS NULL;

UPDATE control_plane.ctl_billing_reports
   SET local_currency = currency,
       currency       = 'USD'
 WHERE currency IS DISTINCT FROM 'USD'
   AND local_currency IS NULL;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer;
BEGIN
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'control_plane'
       AND table_name IN ('ctl_billing_facts', 'ctl_billing_customers',
                          'ctl_billing_reports')
       AND column_name IN ('local_currency', 'rate');
    IF n <> 6 THEN
        RAISE EXCEPTION 'the currency columns were not all created (% of 6)', n;
    END IF;

    -- The views must expose them, or the console still cannot tell the two apart.
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'control_plane'
       AND table_name IN ('ctl_billing_facts_current', 'ctl_billing_customers_current')
       AND column_name IN ('local_currency', 'rate');
    IF n <> 4 THEN
        RAISE EXCEPTION 'the latest-wins views do not carry the currency columns '
                        '(% of 4)', n;
    END IF;

    -- The rate must keep its precision through the view. A rate truncated to two
    -- decimals is wrong by up to half a pesewa per dollar on every line.
    SELECT numeric_scale INTO n FROM information_schema.columns
     WHERE table_schema = 'control_plane' AND table_name = 'ctl_billing_facts'
       AND column_name = 'rate';
    IF n <> 4 THEN
        RAISE EXCEPTION 'ctl_billing_facts.rate has % decimal places, expected 4', n;
    END IF;

    -- Still no names, and still no card digits: this migration widens what crosses,
    -- so the rule it must not break is worth re-asserting here.
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'control_plane' AND table_name = 'ctl_billing_customers'
       AND (column_name LIKE '%last4%' OR column_name LIKE '%name%');
    IF n > 0 THEN
        RAISE EXCEPTION 'the customer table gained a name or card column';
    END IF;

    -- Nothing may still be labelled with a local currency. A row that is would be
    -- a dollar figure the console prints with a cedi sign, which is the whole bug.
    SELECT count(*) INTO n FROM control_plane.ctl_billing_facts
     WHERE currency IS DISTINCT FROM 'USD';
    IF n > 0 THEN
        RAISE EXCEPTION '% fact(s) are still labelled in a local currency', n;
    END IF;
    SELECT count(*) INTO n FROM control_plane.ctl_billing_customers
     WHERE currency IS DISTINCT FROM 'USD';
    IF n > 0 THEN
        RAISE EXCEPTION '% customer row(s) are still labelled in a local currency', n;
    END IF;

    PERFORM count(*) FROM control_plane.ctl_billing_facts_current;
    PERFORM count(*) FROM control_plane.ctl_billing_customers_current;

    -- Replacing a view in place keeps its grants; dropping one does not. Asserted,
    -- because the failure is invisible here and shows up as the console losing every
    -- billing screen on the next deploy.
    SELECT count(*) INTO n
      FROM information_schema.role_table_grants
     WHERE table_schema = 'control_plane'
       AND table_name IN ('ctl_billing_facts_current', 'ctl_billing_customers_current')
       AND privilege_type = 'SELECT'
       AND grantee ~ '^(coreplatform|deladetech)_[a-z0-9]+$';
    IF n = 0 AND EXISTS (
        SELECT 1 FROM pg_roles
         WHERE rolcanlogin AND rolname ~ '^(coreplatform|deladetech)_[a-z0-9]+$'
    ) THEN
        RAISE EXCEPTION 'replacing the views dropped the console''s SELECT grant';
    END IF;

    -- An application group must still not be able to read them.
    SELECT count(*) INTO n
      FROM information_schema.role_table_grants
     WHERE table_schema = 'control_plane'
       AND table_name IN ('ctl_billing_facts_current', 'ctl_billing_customers_current')
       AND grantee LIKE 'tvs_app%';
    IF n > 0 THEN
        RAISE EXCEPTION 'an application group can read the ledger views';
    END IF;

    RAISE NOTICE 'the ledger says which currency it means';
END $$;
