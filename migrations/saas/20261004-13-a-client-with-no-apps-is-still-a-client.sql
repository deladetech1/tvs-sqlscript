-- =====================================================================================
-- A client with no app subscriptions is still a client, and may still owe us money.
--
-- WHAT WAS WRONG
-- The customer snapshot was built FROM cp_app_subscriptions, so a tenant with none
-- produced no row and appeared nowhere on the Customers screen. On dev that hid both
-- silo clients -- itech and accesspoint -- which is how it was found: "under customers I
-- can only see pooled customers".
--
-- It was always slightly wrong (a client exists from the moment they sign up, not from
-- the moment they subscribe) and it became properly wrong the day infrastructure became
-- chargeable: a silo client with no apps can now be billed for their database and owe
-- real money, while being invisible on the screen that lists who owes.
--
-- AND A SECOND UNDER-REPORT
-- `mrr` is the subscription run rate. For a silo client charged 750 a month for their
-- database and nothing for software, that is 0 -- which reads as a client worth nothing.
-- The fix is NOT to fold the charges into mrr: that column has one meaning everywhere it
-- is read, and two meanings would make every comparison with it suspect. So the
-- recurring platform charges are carried BESIDE it, and a screen that wants the whole
-- picture adds them.
-- =====================================================================================

ALTER TABLE control_plane.ctl_billing_customers
    ADD COLUMN IF NOT EXISTS charges_mrr numeric(18,2) NOT NULL DEFAULT 0;

COMMENT ON COLUMN control_plane.ctl_billing_customers.charges_mrr IS
    'The recurring platform charges on this client -- their database, storage, backups '
    '-- as a monthly equivalent, in `currency`. Carried BESIDE mrr rather than folded '
    'into it: mrr is the subscription run rate and has one meaning everywhere it is '
    'read. One-off charges are excluded, because a migration fee is not a run rate.';

-- Appended, not slotted in: CREATE OR REPLACE VIEW may only ADD columns at the end.
CREATE OR REPLACE VIEW control_plane.ctl_billing_customers_current AS
SELECT DISTINCT ON (source_db, tenant_id)
       id, report_id, source_db, host, tier, silo_key, tenant_id,
       plans, apps, subs_total, subs_active, subs_trialing, subs_past_due, subs_lapsed,
       is_enterprise, next_charge_date, period_end, currency,
       mrr, lifetime_paid, outstanding, oldest_unpaid, payment_method,
       has_payment_method, auto_renew, observed_at,
       local_currency, rate,
       charges_mrr
  FROM control_plane.ctl_billing_customers
 ORDER BY source_db, tenant_id, observed_at DESC, id DESC;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer;
BEGIN
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'control_plane' AND table_name = 'ctl_billing_customers'
       AND column_name = 'charges_mrr';
    IF n <> 1 THEN
        RAISE EXCEPTION 'charges_mrr was not created';
    END IF;

    -- The view must expose it, or the console cannot read it and the screen keeps
    -- under-reporting a silo client as worth nothing.
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'control_plane'
       AND table_name = 'ctl_billing_customers_current'
       AND column_name = 'charges_mrr';
    IF n <> 1 THEN
        RAISE EXCEPTION 'the latest-wins view does not carry charges_mrr';
    END IF;

    -- NOT NULL with a default of zero: "no charges" and "charges we failed to read"
    -- would otherwise be the same value, and one of them should be loud.
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'control_plane' AND table_name = 'ctl_billing_customers'
       AND column_name = 'charges_mrr' AND (is_nullable <> 'NO' OR column_default IS NULL);
    IF n > 0 THEN
        RAISE EXCEPTION 'charges_mrr is nullable or has no default';
    END IF;

    PERFORM count(*) FROM control_plane.ctl_billing_customers_current;
    RAISE NOTICE 'a client with no apps is still a client';
END $$;
