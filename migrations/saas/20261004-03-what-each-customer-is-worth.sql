-- =====================================================================================
-- What each customer is on, what they pay, and whether they are paying it.
--
-- 20261004-01 gathered the MONEY: amounts billed and collected per month. That answers
-- "what did we earn" and nothing else. It cannot answer the questions an owner actually
-- opens a console to ask -- which plan is this client on, when are they next charged, is
-- there a card on file, have they paid, what have they paid us since they joined -- all
-- of which live in cp_app_subscriptions and cp_payment_authorizations, and all of which
-- are inside the tenant's own database.
--
-- Same shape as the facts, for the same reason: each database reports its own, over its
-- existing connection to the pooled one, into a table it may INSERT and never read. See
-- 20261004-01 for why the push direction is the only safe one.
--
-- WHY A SEPARATE TABLE AND NOT MORE COLUMNS ON ctl_billing_facts
-- A fact is per (tenant, app, month, line type) and describes a period that is finished.
-- A customer's plan, card and next charge date are ONE per tenant and describe now. Put
-- them on the fact rows and every attribute is repeated per app per month, and "what
-- plan are they on" becomes a question about which duplicate to believe.
--
-- WHAT DELIBERATELY DOES NOT CROSS
-- The same rule as the facts: ids, states, counts and money. No organisation, business
-- or location names -- the console joins our own setup records for those.
--
-- And no card digits. last4 and the issuing bank are in cp_payment_authorizations and it
-- would be easy to carry them, but "is there a card on file, and is it a card or mobile
-- money" is the whole of what an owner decides anything with. The digits identify a
-- payment instrument, so carrying them across a boundary widens what a reader of this
-- table learns while changing no decision.
--
-- NO INFRASTRUCTURE COST HERE
-- The obvious next column is what the customer costs to run, to put margin beside
-- revenue. Deliberately not yet: a cost figure is only worth having if it is real, and
-- deriving one needs per-silo server, storage and backup metering that does not exist.
-- A made-up cost would make every margin on the dashboard confidently wrong.
-- =====================================================================================

CREATE TABLE IF NOT EXISTS control_plane.ctl_billing_customers (
    id              text        NOT NULL
                    DEFAULT ('billcust_' || replace(gen_random_uuid()::text, '-', '')),

    -- Carried by a report, exactly as a fact is: nothing arrives here without a
    -- heartbeat accounting for it.
    report_id       text        NOT NULL,

    source_db       text        NOT NULL,
    host            text,
    tier            text        NOT NULL,
    silo_key        text,
    tenant_id       text        NOT NULL,

    -- WHAT THEY ARE ON
    -- The plan names on their active subscriptions, joined. A tenant can hold several
    -- apps on different plans, and picking one to show would be arbitrary.
    plans           text,
    apps            integer     NOT NULL DEFAULT 0,

    subs_total      integer     NOT NULL DEFAULT 0,
    subs_active     integer     NOT NULL DEFAULT 0,
    subs_trialing   integer     NOT NULL DEFAULT 0,
    subs_past_due   integer     NOT NULL DEFAULT 0,
    subs_lapsed     integer     NOT NULL DEFAULT 0,
    is_enterprise   boolean     NOT NULL DEFAULT false,

    -- WHEN
    -- The EARLIEST next charge across their subscriptions: the next time money is taken
    -- from them, which is the date worth showing.
    next_charge_date date,
    period_end       date,

    -- WHAT THEY PAY
    currency        text,
    -- The recurring monthly amount on subscriptions that are ACTIVE now. This is the
    -- run rate, not what happened to be billed -- a client who joined on the 28th has a
    -- small first bill and a full MRR, and summing bills would understate them.
    mrr             numeric(18,2) NOT NULL DEFAULT 0,
    -- Everything they have ever paid us, across every month still on record.
    lifetime_paid   numeric(18,2) NOT NULL DEFAULT 0,
    outstanding     numeric(18,2) NOT NULL DEFAULT 0,
    -- The oldest month they still owe for. Days overdue without this is guesswork.
    oldest_unpaid   date,

    -- HOW THEY PAY
    -- CARD, MOBILE_MONEY, BANK... or NONE. See the header for why no digits.
    payment_method  text,
    has_payment_method boolean  NOT NULL DEFAULT false,
    -- Derived, not stored anywhere: a subscription renews itself only if it is active,
    -- payment is required of it, and there is an instrument to charge. Any one missing
    -- and somebody has to do something by hand next cycle.
    auto_renew      boolean     NOT NULL DEFAULT false,

    observed_at     timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_ctl_billing_customers PRIMARY KEY (id),
    CONSTRAINT fk_ctl_billing_customers_report FOREIGN KEY (report_id)
        REFERENCES control_plane.ctl_billing_reports (id),
    CONSTRAINT ck_ctl_billing_customers_sane CHECK (
        apps >= 0 AND subs_total >= 0 AND subs_active >= 0
        AND mrr >= 0 AND lifetime_paid >= 0
    )
);

CREATE INDEX IF NOT EXISTS ix_ctl_billing_customers_latest
    ON control_plane.ctl_billing_customers
       (source_db, tenant_id, observed_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS ix_ctl_billing_customers_tier
    ON control_plane.ctl_billing_customers (tier, observed_at DESC);

COMMENT ON TABLE control_plane.ctl_billing_customers IS
    'One append-only snapshot per customer per report: plan, subscription states, next '
    'charge, MRR, lifetime paid, outstanding and whether a payment instrument exists. '
    'No names and no card digits.';

-- The current state of each customer, so no reader has to know about revisions.
CREATE OR REPLACE VIEW control_plane.ctl_billing_customers_current AS
SELECT DISTINCT ON (source_db, tenant_id)
       id, report_id, source_db, host, tier, silo_key, tenant_id,
       plans, apps, subs_total, subs_active, subs_trialing, subs_past_due, subs_lapsed,
       is_enterprise, next_charge_date, period_end, currency, mrr, lifetime_paid,
       outstanding, oldest_unpaid, payment_method, has_payment_method, auto_renew,
       observed_at
  FROM control_plane.ctl_billing_customers
 ORDER BY source_db, tenant_id, observed_at DESC, id DESC;

COMMENT ON VIEW control_plane.ctl_billing_customers_current IS
    'The latest snapshot per customer. What the owner dashboard reads.';

-- ----------------------------------------------------------------- revoke first
-- control_plane grants SELECT on new tables to every application group by default
-- (ALTER DEFAULT PRIVILEGES, in 20261001-01). Correct for a route table, wrong for this:
-- without the revoke, every app in the cluster could read what every customer pays.
DO $$
DECLARE grp text;
BEGIN
    FOR grp IN
        SELECT rolname FROM pg_roles
         WHERE rolname ~ '^tvs_app_[a-z0-9_]+$' AND NOT rolcanlogin
    LOOP
        EXECUTE format('REVOKE ALL ON control_plane.ctl_billing_customers FROM %I', grp);
        EXECUTE format(
            'REVOKE ALL ON control_plane.ctl_billing_customers_current FROM %I', grp);
        EXECUTE format('GRANT INSERT ON control_plane.ctl_billing_customers TO %I', grp);
        RAISE NOTICE 'billing customers: append-only for %', grp;
    END LOOP;
END $$;

DO $$
DECLARE r text; n integer := 0;
BEGIN
    FOR r IN
        SELECT rolname FROM pg_roles
         WHERE rolcanlogin AND rolname ~ '^(coreplatform|deladetech)_[a-z0-9]+$'
    LOOP
        EXECUTE format(
            'GRANT SELECT ON control_plane.ctl_billing_customers TO %I', r);
        EXECUTE format(
            'GRANT SELECT ON control_plane.ctl_billing_customers_current TO %I', r);
        n := n + 1;
    END LOOP;
    IF n = 0 THEN
        RAISE WARNING 'billing customers: no console login matched, so nothing can read it';
    END IF;
END $$;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer;
BEGIN
    IF to_regclass('control_plane.ctl_billing_customers') IS NULL THEN
        RAISE EXCEPTION 'ctl_billing_customers was not created';
    END IF;

    SELECT count(*) INTO n
      FROM information_schema.role_table_grants
     WHERE table_schema = 'control_plane'
       AND table_name IN ('ctl_billing_customers', 'ctl_billing_customers_current')
       AND privilege_type IN ('SELECT', 'UPDATE', 'DELETE', 'TRUNCATE')
       AND grantee LIKE 'tvs_app%';
    IF n > 0 THEN
        RAISE EXCEPTION 'an application group can read or change what customers pay';
    END IF;

    SELECT count(*) INTO n
      FROM information_schema.role_column_grants
     WHERE table_schema = 'control_plane'
       AND table_name = 'ctl_billing_customers'
       AND privilege_type = 'SELECT'
       AND grantee LIKE 'tvs_app%';
    IF n > 0 THEN
        RAISE EXCEPTION 'an application group can read % column(s) of the customer table', n;
    END IF;

    -- No card digits, ever. Checked as a column name rather than trusted to review,
    -- because this is the table somebody will reach for when they want to show a card.
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'control_plane' AND table_name = 'ctl_billing_customers'
       AND (column_name LIKE '%last4%' OR column_name LIKE '%card_number%'
            OR column_name LIKE '%pan%' OR column_name LIKE '%name%');
    IF n > 0 THEN
        RAISE EXCEPTION 'the customer table has a column for a card detail or a name';
    END IF;

    -- A customer row without a report behind it must be impossible.
    BEGIN
        INSERT INTO control_plane.ctl_billing_customers
            (report_id, source_db, tier, tenant_id)
        VALUES ('no-such-report', 'probe', 'POOLED', 'tnt_probe');
        RAISE EXCEPTION 'a customer row was accepted with no report behind it';
    EXCEPTION WHEN foreign_key_violation THEN
        NULL;
    END;

    PERFORM count(*) FROM control_plane.ctl_billing_customers_current;

    RAISE NOTICE 'the customer ledger is ready';
END $$;
