-- =====================================================================
-- ZelosHR's payroll tells the books what happened: accounting events
-- ---------------------------------------------------------------------
-- Roadmap Phase 1, step 5 (docs/POSTINGS.md §8). Every ZelosHR change that moves payroll money
-- publishes an event to core_platform.cp_events IN THE SAME TRANSACTION as the change; Accounting
-- reads them (reader 'accounting') and posts journals into the business's books.
--
-- WHY TRIGGERS AND NOT THE .NET SERVICE. A run's figures and its state live in two tables written
-- by two services (PayrollService: calculate, upload provider results, approve, mark paid;
-- PayrollExtrasService: payment batches, whose last confirmation marks the run paid), and the
-- same code is deployed twice (tvs-zeloshr-admin-bk and tvs-zeloshr-employees-bk share the
-- payroll entities and the database). Remittances are recorded by PayrollFilingsService and staff
-- loans by PayrollSetupService. Every one of them ends in a write to zhr_payroll_runs,
-- zhr_payroll_lines, zhr_payment_batches, zhr_payroll_filings or zhr_employee_loans, so the
-- triggers sit there and both deployments (and data fixes) are covered.
--
-- WHY DEFERRED (fired at COMMIT). Recalculating replaces every line, and confirming the last batch
-- marks the run paid in the same request. At commit the trigger reads the run as it finally stands
-- and compares it with what was last published (zeloshr.zhr_acc_state): only the difference is
-- published. A write that fails rolls back and publishes nothing.
--
-- WHICH BOOKS. ZelosHR keeps one payroll per organisation; the books are per business. Events go to
-- the organisation's business that subscribes to Accounting (then ZelosHR; the oldest when several
-- do), and a run stays with the business its first event went to.
--
-- Fail open, loudly: if describing a run raises, the write still commits and a 'zhr.posting_error'
-- event names it and the error; Accounting lists it as FAILED.
--
-- Events (subject = the ZelosHR id; amounts are strings with 2 decimals):
--   zhr.payroll_approved            a run approved (or paid): earnings by kind, deductions by kind,
--                                   employer contributions, SSNIT split into Tier 1 and Tier 2
--   zhr.payroll_voided              reason CHANGED / UNAPPROVED / DELETED, with the figures it posted
--   zhr.salaries_paid               net pay paid out, by channel (batch payments confirmed, or the run marked paid)
--   zhr.salary_payment_reversed     a paid batch payment failed afterwards (or a paid run undone)
--   zhr.remittance_paid             SSNIT (Tier 1) or Tier 2 remittance recorded as paid in Filings
--   zhr.remittance_reversed         taken back (or its date / amount corrected: reversed, then paid again)
--   zhr.staff_loan_granted          a staff loan or salary advance recorded
--   zhr.staff_loan_voided           deleted, or cancelled before anything was repaid
--   zhr.posting_error
--
-- Starts from now: runs, payments, remittances and loans that exist when this first runs are
-- recorded as already published (history belongs in the books' opening balances). Re-runs every
-- deploy: idempotent.
-- =====================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS zeloshr.zhr_acc_state (
    kind       text NOT NULL,          -- RUN, PAYMENT, REMITTANCE, LOAN, BASELINE
    doc_id     text NOT NULL,
    tenant_id  text NOT NULL,
    org_id     text,
    bus_id     text,
    revision   integer NOT NULL DEFAULT 0,
    -- What was last published (NULL: nothing stands in the books for it now). 'money' is what counts as a change.
    value      jsonb,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (kind, doc_id)
);
CREATE INDEX IF NOT EXISTS zhr_acc_state_period_idx ON zeloshr.zhr_acc_state (tenant_id, org_id, (value->>'period')) WHERE kind = 'RUN';

-- ===================================================================== helpers
CREATE OR REPLACE FUNCTION zeloshr.zhr_acc_money(v numeric) RETURNS text
LANGUAGE sql IMMUTABLE AS $f$ SELECT to_char(round(coalesce(v, 0), 2), 'FM9999999999999990.00') $f$;

-- The business's date at an instant: the tenant's zone in Core Platform, else UTC.
CREATE OR REPLACE FUNCTION zeloshr.zhr_acc_day(p_tenant text, p_at timestamptz) RETURNS date
LANGUAGE plpgsql STABLE AS $f$
DECLARE z text;
BEGIN
    IF to_regclass('core_platform.cp_timezone_settings') IS NOT NULL THEN
        SELECT timezone INTO z FROM core_platform.cp_timezone_settings
         WHERE tenant_id = p_tenant AND is_active ORDER BY cdatetime DESC NULLS LAST LIMIT 1;
    END IF;
    BEGIN
        RETURN (coalesce(p_at, now()) AT TIME ZONE coalesce(nullif(z, ''), 'UTC'))::date;
    EXCEPTION WHEN invalid_parameter_value THEN
        RETURN (coalesce(p_at, now()) AT TIME ZONE 'UTC')::date;
    END;
END
$f$;

-- The books an organisation's payroll posts into: its business that subscribes to Accounting, then
-- to ZelosHR, the oldest first. NULL when the organisation has no business (nothing can post).
CREATE OR REPLACE FUNCTION zeloshr.zhr_acc_business(p_tenant text, p_org text) RETURNS text
LANGUAGE plpgsql STABLE AS $f$
DECLARE v text;
BEGIN
    SELECT b.id INTO v FROM core_platform.cp_businesses b
     WHERE b.tenant_id = p_tenant AND b.org_id = p_org
       AND coalesce(b.is_active, true) AND coalesce(b.delete_status, 'NOT_DELETED') <> 'DELETED'
     ORDER BY EXISTS (SELECT 1 FROM core_platform.cp_business_app_tier t
                       WHERE t.tenant_id = b.tenant_id AND t.business_id = b.id AND t.app_id = 'app-accounting') DESC,
              EXISTS (SELECT 1 FROM core_platform.cp_business_app_tier t
                       WHERE t.tenant_id = b.tenant_id AND t.business_id = b.id AND t.app_id = 'app-zeloshr') DESC,
              b.cdatetime NULLS LAST, b.id
     LIMIT 1;
    RETURN v;
END
$f$;

CREATE OR REPLACE FUNCTION zeloshr.zhr_acc_publish(p_tenant text, p_bus text, p_kind text, p_subject text, p_payload jsonb)
RETURNS bigint LANGUAGE sql AS $f$
    SELECT core_platform.cp_event_publish(p_tenant, p_bus, 'zeloshr', p_kind, p_subject,
                                          jsonb_build_object('version', 1, 'app', 'zeloshr') || p_payload)
$f$;

-- Publishes the difference between what stands in the books for a document (its state) and what
-- should (p_target, NULL for nothing): a void of the old figures, then the new ones.
CREATE OR REPLACE FUNCTION zeloshr.zhr_acc_apply(p_state text, p_id text, p_tenant text, p_org text, p_target jsonb,
                                                 p_issue_kind text, p_void_kind text, p_gone_reason text, p_unrecognised_reason text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
    st zeloshr.zhr_acc_state;
    old jsonb;
    rev integer;
    reason text;
    v_bus text;
BEGIN
    SELECT * INTO st FROM zeloshr.zhr_acc_state WHERE kind = p_state AND doc_id = p_id;
    old := st.value;
    IF (old->'money') IS NOT DISTINCT FROM (p_target->'money') THEN RETURN; END IF;
    -- A document stays with the books its first event went to.
    v_bus := coalesce(st.bus_id, zeloshr.zhr_acc_business(p_tenant, p_org));
    rev := coalesce(st.revision, 0);
    IF old IS NOT NULL THEN
        reason := CASE WHEN p_target IS NOT NULL THEN 'CHANGED' ELSE coalesce(p_gone_reason, p_unrecognised_reason) END;
        PERFORM zeloshr.zhr_acc_publish(p_tenant, v_bus, p_void_kind, p_id, (old - 'money') || jsonb_build_object(
            'revision', rev, 'reason', reason,
            -- A change replaces the document on its own date; anything else is dated the day it happened.
            'date', CASE WHEN reason = 'CHANGED' THEN (old->>'date')::date
                         ELSE greatest((old->>'date')::date, zeloshr.zhr_acc_day(p_tenant, now())) END));
    END IF;
    IF p_target IS NOT NULL THEN
        rev := rev + 1;
        PERFORM zeloshr.zhr_acc_publish(p_tenant, v_bus, p_issue_kind, p_id, (p_target - 'money') || jsonb_build_object('revision', rev));
    END IF;
    INSERT INTO zeloshr.zhr_acc_state (kind, doc_id, tenant_id, org_id, bus_id, revision, value, updated_at)
    VALUES (p_state, p_id, p_tenant, p_org, v_bus, rev, p_target, now())
    ON CONFLICT (kind, doc_id) DO UPDATE SET revision = EXCLUDED.revision, value = EXCLUDED.value, updated_at = now();
END
$f$;

-- ===================================================================== what a run puts in the books
-- A run, once approved (or paid): every line's earnings, deductions and employer contributions,
-- added up by kind. Earnings: BASIC (basic salary; a provider's gross), SETTLEMENT (final settlement),
-- OVERTIME, BONUS (bonus, commission, incentive), REIMBURSEMENT (an Expenses claim paid back on the
-- payslip: a one-off on this run that an Expenses payout points at), ALLOWANCE (any other component).
-- Deductions: PAYE, SSNIT, LOAN (a staff loan's instalment), OTHER (company deductions, union dues,
-- Tier 3, a provider's lump). Employer: SSNIT, OTHER. SSNIT (employee + employer) is split into
-- Tier 2 (5% of basic in Ghana, PayRulePacks.Ghana.Tier2Percent) and Tier 1 (the rest), person by
-- person, which is what Filings' schedules pay over.
CREATE OR REPLACE FUNCTION zeloshr.zhr_acc_run_figures(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $f$
DECLARE
    r zeloshr.zhr_payroll_runs;
    g zeloshr.zhr_pay_groups;
    v_reimb jsonb := '[]';
    v_earn jsonb; v_ded jsonb; v_emp jsonb;
    v_gross numeric; v_deductions numeric; v_employer numeric;
    v_tier1 numeric; v_tier2 numeric; v_people integer;
    v_tier2_pct numeric;
    v_date date;
BEGIN
    SELECT * INTO r FROM zeloshr.zhr_payroll_runs WHERE id = p_id;
    IF NOT FOUND OR r.status NOT IN ('approved', 'paid') THEN RETURN NULL; END IF;
    SELECT * INTO g FROM zeloshr.zhr_pay_groups
     WHERE (r.pay_group_id IS NOT NULL AND id = r.pay_group_id)
        OR (r.pay_group_id IS NULL AND tenant_id = r.tenant_id AND org_id = r.org_id AND is_default)
     ORDER BY (id = r.pay_group_id) DESC NULLS LAST LIMIT 1;
    v_tier2_pct := CASE WHEN upper(coalesce(g.country, 'GH')) = 'GH' AND coalesce(r.calculation_mode, 'native') = 'native' THEN 5 ELSE 0 END;
    -- Claims Expenses pays back on this run's payslips.
    IF to_regclass('expenses.exp_claim_payouts') IS NOT NULL THEN
        SELECT coalesce(jsonb_agg(jsonb_build_array(o.employee_id::text, o.component)), '[]') INTO v_reimb
          FROM zeloshr.zhr_payroll_one_offs o
         WHERE o.tenant_id = r.tenant_id AND o.org_id = r.org_id AND o.included_run_ids_json ? r.id::text
           AND EXISTS (SELECT 1 FROM expenses.exp_claim_payouts p WHERE p.payroll_one_off_id = o.id::text);
    END IF;

    WITH l AS (
        SELECT * FROM zeloshr.zhr_payroll_lines WHERE run_id = r.id
    ), e AS (
        SELECT l.employee_id, x->>'code' AS code, x->>'label' AS label, round(coalesce((x->>'amount')::numeric, 0), 2) AS amount,
               CASE WHEN x->>'code' IN ('basic', 'gross') THEN 'BASIC'
                    WHEN v_reimb @> jsonb_build_array(jsonb_build_array(l.employee_id::text, x->>'label')) THEN 'REIMBURSEMENT'
                    WHEN x->>'code' LIKE 'overtime%' THEN 'OVERTIME'
                    WHEN x->>'label' ILIKE 'final settlement%' THEN 'SETTLEMENT'
                    WHEN x->>'label' ~* '(bonus|commission|incentive|13th)' THEN 'BONUS'
                    ELSE 'ALLOWANCE' END AS kind
          FROM l, jsonb_array_elements(coalesce(l.earnings_json, '[]')) x
    ), d AS (
        SELECT l.employee_id, x->>'code' AS code, x->>'label' AS label, round(coalesce((x->>'amount')::numeric, 0), 2) AS amount,
               CASE WHEN x->>'code' = 'paye' THEN 'PAYE'
                    WHEN x->>'code' = 'ssnit_employee' THEN 'SSNIT'
                    WHEN x->>'code' LIKE 'loan\_%' THEN 'LOAN'
                    ELSE 'OTHER' END AS kind
          FROM l, jsonb_array_elements(coalesce(l.deductions_json, '[]')) x
    ), c AS (
        SELECT l.employee_id, x->>'code' AS code, x->>'label' AS label, round(coalesce((x->>'amount')::numeric, 0), 2) AS amount,
               CASE WHEN x->>'code' = 'ssnit_employer' THEN 'SSNIT' ELSE 'OTHER' END AS kind
          FROM l, jsonb_array_elements(coalesce(l.employer_contributions_json, '[]')) x
    ), tiers AS (
        -- Person by person: Tier 2 is its share of basic, never more than the SSNIT paid; Tier 1 the rest.
        SELECT p.employee_id, p.ssnit, least(p.ssnit, round(p.basic * v_tier2_pct / 100, 2)) AS tier2
          FROM (SELECT l.employee_id,
                       (SELECT coalesce(sum(amount), 0) FROM e WHERE e.employee_id = l.employee_id AND e.code = 'basic') AS basic,
                       (SELECT coalesce(sum(amount), 0) FROM d WHERE d.employee_id = l.employee_id AND d.kind = 'SSNIT')
                     + (SELECT coalesce(sum(amount), 0) FROM c WHERE c.employee_id = l.employee_id AND c.kind = 'SSNIT') AS ssnit
                  FROM l) p
    )
    SELECT
        (SELECT coalesce(jsonb_agg(jsonb_build_object('kind', kind, 'code', code, 'label', label, 'amount', zeloshr.zhr_acc_money(amount))
                                   ORDER BY kind, code), '[]')
           FROM (SELECT kind, CASE kind WHEN 'OVERTIME' THEN 'overtime' ELSE code END AS code,
                        min(CASE kind WHEN 'OVERTIME' THEN 'Overtime' WHEN 'BASIC' THEN 'Basic salary' ELSE label END) AS label, sum(amount) AS amount
                   FROM e GROUP BY 1, 2 HAVING sum(amount) <> 0) a),
        (SELECT coalesce(jsonb_agg(jsonb_build_object('kind', kind, 'code', code, 'label', label, 'amount', zeloshr.zhr_acc_money(amount))
                                   ORDER BY kind, code), '[]')
           FROM (SELECT kind, code, min(label) AS label, sum(amount) AS amount FROM d GROUP BY 1, 2 HAVING sum(amount) <> 0) a),
        (SELECT coalesce(jsonb_agg(jsonb_build_object('kind', kind, 'code', code, 'label', label, 'amount', zeloshr.zhr_acc_money(amount))
                                   ORDER BY kind, code), '[]')
           FROM (SELECT kind, code, min(label) AS label, sum(amount) AS amount FROM c GROUP BY 1, 2 HAVING sum(amount) <> 0) a),
        (SELECT coalesce(sum(amount), 0) FROM e),
        (SELECT coalesce(sum(amount), 0) FROM d),
        (SELECT coalesce(sum(amount), 0) FROM c),
        (SELECT coalesce(sum(ssnit - tier2), 0) FROM tiers),
        (SELECT coalesce(sum(tier2), 0) FROM tiers),
        (SELECT count(*) FROM l)
      INTO v_earn, v_ded, v_emp, v_gross, v_deductions, v_employer, v_tier1, v_tier2, v_people;

    IF v_gross = 0 AND v_employer = 0 THEN RETURN NULL; END IF;
    -- In the month the pay belongs to, and never after the day it was approved (the books post nothing
    -- dated in the future): the pay date, else the period's end, else the approval day.
    v_date := greatest(r.period_start, least(coalesce(r.pay_date, r.period_end), r.period_end,
                                             zeloshr.zhr_acc_day(r.tenant_id, coalesce(r.approved_at, now()))));
    RETURN jsonb_build_object(
        'org_id', r.org_id, 'document_type', 'PAYROLL_RUN', 'document_id', r.id::text,
        'document_number', 'PAY-' || r.period || CASE WHEN coalesce(r.kind, 'regular') <> 'regular' THEN '-' || upper(r.kind) ELSE '' END
                           || CASE WHEN coalesce(g.is_default, true) THEN '' ELSE ' ' || g.name END,
        'period', r.period, 'period_start', r.period_start, 'period_end', r.period_end, 'pay_date', r.pay_date,
        'date', v_date, 'currency', upper(r.currency), 'pay_group', g.name, 'country', upper(coalesce(g.country, 'GH')),
        'mode', coalesce(r.calculation_mode, 'native'), 'employees', v_people,
        'earnings', v_earn, 'deductions', v_ded, 'employer', v_emp,
        'gross', zeloshr.zhr_acc_money(v_gross), 'total_deductions', zeloshr.zhr_acc_money(v_deductions),
        'net', zeloshr.zhr_acc_money(v_gross - v_deductions), 'employer_contributions', zeloshr.zhr_acc_money(v_employer),
        'ssnit_tier1', zeloshr.zhr_acc_money(v_tier1), 'ssnit_tier2', zeloshr.zhr_acc_money(v_tier2),
        'amount', zeloshr.zhr_acc_money(v_gross + v_employer),
        'money', jsonb_build_object('earnings', v_earn, 'deductions', v_ded, 'employer', v_emp, 'tier2', v_tier2,
                                    'currency', r.currency, 'date', v_date));
END
$f$;

-- ===================================================================== syncing
CREATE OR REPLACE FUNCTION zeloshr.zhr_acc_sync_run(p_id uuid, p_tenant text, p_org text) RETURNS void
LANGUAGE plpgsql AS $f$
BEGIN
    PERFORM zeloshr.zhr_acc_apply('RUN', p_id::text, p_tenant, p_org, zeloshr.zhr_acc_run_figures(p_id),
        'zhr.payroll_approved', 'zhr.payroll_voided',
        CASE WHEN NOT EXISTS (SELECT 1 FROM zeloshr.zhr_payroll_runs WHERE id = p_id) THEN 'DELETED' END, 'UNAPPROVED');
END
$f$;

-- Net pay paid out, by channel: everything once the run is marked paid, before that what its
-- batches have confirmed person by person. Published as the difference from what was published.
-- Nothing is paid against a run the books do not hold.
CREATE OR REPLACE FUNCTION zeloshr.zhr_acc_sync_payments(p_id uuid, p_tenant text, p_org text) RETURNS void
LANGUAGE plpgsql AS $f$
DECLARE
    r zeloshr.zhr_payroll_runs;
    run_st zeloshr.zhr_acc_state;
    st zeloshr.zhr_acc_state;
    v_now jsonb := '{}';
    v_was jsonb;
    v_paid jsonb := '[]';
    v_back jsonb := '[]';
    v_paid_total numeric := 0;
    v_back_total numeric := 0;
    ch text;
    delta numeric;
    v_date date;
    v_common jsonb;
BEGIN
    SELECT * INTO r FROM zeloshr.zhr_payroll_runs WHERE id = p_id;
    SELECT * INTO run_st FROM zeloshr.zhr_acc_state WHERE kind = 'RUN' AND doc_id = p_id::text;
    IF FOUND AND run_st.value IS NOT NULL AND r.id IS NOT NULL THEN
        SELECT coalesce(jsonb_object_agg(x.channel, round(x.amount, 2)), '{}') INTO v_now
          FROM (SELECT coalesce(nullif(l.payment_channel, ''), 'bank_transfer') AS channel,
                       sum(CASE WHEN r.status = 'paid' THEN greatest(l.net, 0)
                                ELSE least(greatest(l.net, 0), coalesce(b.amount, 0)) END) AS amount
                  FROM zeloshr.zhr_payroll_lines l
                  LEFT JOIN (SELECT (i->>'employee_id') AS employee_id, sum((i->>'amount')::numeric) AS amount
                               FROM zeloshr.zhr_payment_batches pb, jsonb_array_elements(coalesce(pb.items_json, '[]')) i
                              WHERE pb.run_id = r.id AND i->>'status' = 'paid'
                              GROUP BY 1) b ON b.employee_id = l.employee_id::text
                 WHERE l.run_id = r.id
                 GROUP BY 1) x
         WHERE x.amount <> 0;
    END IF;
    SELECT * INTO st FROM zeloshr.zhr_acc_state WHERE kind = 'PAYMENT' AND doc_id = p_id::text;
    v_was := coalesce(st.value->'paid', '{}');
    IF v_was = v_now THEN RETURN; END IF;
    FOR ch IN SELECT k FROM jsonb_object_keys(v_was || v_now) k ORDER BY k LOOP
        delta := coalesce((v_now->>ch)::numeric, 0) - coalesce((v_was->>ch)::numeric, 0);
        IF delta > 0 THEN
            v_paid := v_paid || jsonb_build_array(jsonb_build_object('channel', upper(ch), 'amount', zeloshr.zhr_acc_money(delta)));
            v_paid_total := v_paid_total + delta;
        ELSIF delta < 0 THEN
            v_back := v_back || jsonb_build_array(jsonb_build_object('channel', upper(ch), 'amount', zeloshr.zhr_acc_money(-delta)));
            v_back_total := v_back_total - delta;
        END IF;
    END LOOP;
    -- Dated the day the money went (or came back), which may be before the run's pay date.
    v_date := zeloshr.zhr_acc_day(p_tenant, now());
    v_common := coalesce(run_st.value, st.value->'run', '{}') - 'money' - 'earnings' - 'deductions' - 'employer' - 'revision';
    v_common := jsonb_build_object(
        'org_id', p_org, 'document_type', 'PAYROLL_RUN', 'document_id', p_id::text,
        'document_number', v_common->>'document_number', 'period', v_common->>'period', 'pay_group', v_common->>'pay_group',
        'currency', coalesce(v_common->>'currency', upper(r.currency)), 'date', v_date);
    IF v_paid_total > 0 THEN
        PERFORM zeloshr.zhr_acc_publish(p_tenant, coalesce(st.bus_id, run_st.bus_id), 'zhr.salaries_paid', p_id::text,
            v_common || jsonb_build_object('lines', v_paid, 'amount', zeloshr.zhr_acc_money(v_paid_total),
                                           'run_paid', r.status = 'paid'));
    END IF;
    IF v_back_total > 0 THEN
        PERFORM zeloshr.zhr_acc_publish(p_tenant, coalesce(st.bus_id, run_st.bus_id), 'zhr.salary_payment_reversed', p_id::text,
            v_common || jsonb_build_object('lines', v_back, 'amount', zeloshr.zhr_acc_money(v_back_total),
                                           'reason', CASE WHEN r.id IS NULL OR run_st.value IS NULL THEN 'RUN_UNDONE' ELSE 'FAILED' END));
    END IF;
    INSERT INTO zeloshr.zhr_acc_state (kind, doc_id, tenant_id, org_id, bus_id, revision, value, updated_at)
    VALUES ('PAYMENT', p_id::text, p_tenant, p_org, coalesce(st.bus_id, run_st.bus_id), coalesce(st.revision, 0) + 1,
            jsonb_build_object('paid', v_now, 'date', v_date,
                               'run', coalesce(run_st.value, st.value->'run') - 'money' - 'earnings' - 'deductions' - 'employer'), now())
    ON CONFLICT (kind, doc_id) DO UPDATE SET revision = EXCLUDED.revision, value = EXCLUDED.value, bus_id = EXCLUDED.bus_id, updated_at = now();
END
$f$;

-- A remittance recorded as paid in Filings: what the period's runs in the books owe that payee
-- (SSNIT: Tier 1; the Tier 2 trustee: Tier 2). PAYE is a return in ZelosHR: filed, never "paid".
CREATE OR REPLACE FUNCTION zeloshr.zhr_acc_filing_figures(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $f$
DECLARE
    f zeloshr.zhr_payroll_filings;
    v_tier text;
    v_amount numeric;
    v_currency text;
BEGIN
    SELECT * INTO f FROM zeloshr.zhr_payroll_filings WHERE id = p_id;
    IF NOT FOUND OR f.paid_on IS NULL THEN RETURN NULL; END IF;
    v_tier := CASE f.deadline_id WHEN 'ssnit-contributions' THEN 'TIER1' WHEN 'tier2-remittance' THEN 'TIER2' END;
    IF v_tier IS NULL THEN RETURN NULL; END IF;
    SELECT sum((s.value->>CASE v_tier WHEN 'TIER1' THEN 'ssnit_tier1' ELSE 'ssnit_tier2' END)::numeric), max(s.value->>'currency')
      INTO v_amount, v_currency
      FROM zeloshr.zhr_acc_state s
     WHERE s.kind = 'RUN' AND s.value IS NOT NULL AND s.tenant_id = f.tenant_id AND s.org_id = f.org_id
       AND s.value->>'period' = f.period AND s.value->>'country' = upper(f.country);
    IF coalesce(v_amount, 0) = 0 THEN RETURN NULL; END IF;
    RETURN jsonb_build_object(
        'org_id', f.org_id, 'document_type', 'REMITTANCE', 'document_id', f.id::text,
        'document_number', coalesce(nullif(f.paid_ref, ''), CASE v_tier WHEN 'TIER1' THEN 'SSNIT ' ELSE 'Tier 2 ' END || f.period),
        'deadline_id', f.deadline_id, 'allocation', v_tier,
        'payee', CASE v_tier WHEN 'TIER1' THEN 'SSNIT' ELSE 'Tier 2 trustee' END,
        'period', f.period, 'country', upper(f.country), 'reference', f.paid_ref, 'date', f.paid_on,
        'currency', v_currency, 'method', 'BANK', 'amount', zeloshr.zhr_acc_money(v_amount),
        'money', jsonb_build_object('amount', round(v_amount, 2), 'date', f.paid_on, 'currency', v_currency, 'tier', v_tier));
END
$f$;

CREATE OR REPLACE FUNCTION zeloshr.zhr_acc_sync_filing(p_id uuid, p_tenant text, p_org text) RETURNS void
LANGUAGE plpgsql AS $f$
BEGIN
    PERFORM zeloshr.zhr_acc_apply('REMITTANCE', p_id::text, p_tenant, p_org, zeloshr.zhr_acc_filing_figures(p_id),
        'zhr.remittance_paid', 'zhr.remittance_reversed',
        CASE WHEN NOT EXISTS (SELECT 1 FROM zeloshr.zhr_payroll_filings WHERE id = p_id) THEN 'DELETED' END, 'TAKEN_BACK');
END
$f$;

-- A staff loan or salary advance: the money the business gave the employee, repaid from pay. It
-- stands until deleted, or cancelled before any instalment reached the books.
CREATE OR REPLACE FUNCTION zeloshr.zhr_acc_loan_figures(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $f$
DECLARE
    ln zeloshr.zhr_employee_loans;
    v_name text;
    v_currency text;
    v_repaid numeric;
    v_date date;
BEGIN
    SELECT * INTO ln FROM zeloshr.zhr_employee_loans WHERE id = p_id;
    IF NOT FOUND OR coalesce(ln.principal, 0) <= 0 THEN RETURN NULL; END IF;
    IF ln.status = 'cancelled' THEN
        SELECT coalesce(sum((x->>'amount')::numeric), 0) INTO v_repaid
          FROM zeloshr.zhr_acc_state s, jsonb_array_elements(s.value->'deductions') x
         WHERE s.kind = 'RUN' AND s.value IS NOT NULL AND s.tenant_id = ln.tenant_id AND s.org_id = ln.org_id
           AND x->>'code' = 'loan_' || replace(ln.id::text, '-', '');
        IF v_repaid = 0 THEN RETURN NULL; END IF;
    END IF;
    SELECT coalesce(nullif(e.full_name, ''), trim(coalesce(e.first_name, '') || ' ' || coalesce(e.last_name, ''))) INTO v_name
      FROM zeloshr.zhr_employees e WHERE e.id = ln.employee_id;
    SELECT upper(g.currency) INTO v_currency FROM zeloshr.zhr_pay_groups g
     WHERE g.tenant_id = ln.tenant_id AND g.org_id = ln.org_id
       AND (g.id = (SELECT m.pay_group_id FROM zeloshr.zhr_pay_group_members m WHERE m.employee_id = ln.employee_id LIMIT 1) OR g.is_default)
     ORDER BY g.is_default LIMIT 1;
    v_date := zeloshr.zhr_acc_day(ln.tenant_id, ln.created_at);
    RETURN jsonb_build_object(
        'org_id', ln.org_id, 'document_type', 'STAFF_LOAN', 'document_id', ln.id::text,
        'document_number', 'LOAN-' || upper(left(replace(ln.id::text, '-', ''), 8)),
        'employee_id', ln.employee_id::text, 'employee_name', nullif(v_name, ''), 'name', ln.name,
        'installment', zeloshr.zhr_acc_money(ln.installment), 'start_period', ln.start_period,
        'date', v_date, 'currency', coalesce(v_currency, 'GHS'), 'method', 'BANK', 'amount', zeloshr.zhr_acc_money(ln.principal),
        'money', jsonb_build_object('amount', round(ln.principal, 2), 'currency', coalesce(v_currency, 'GHS'), 'date', v_date));
END
$f$;

CREATE OR REPLACE FUNCTION zeloshr.zhr_acc_sync_loan(p_id uuid, p_tenant text, p_org text) RETURNS void
LANGUAGE plpgsql AS $f$
BEGIN
    PERFORM zeloshr.zhr_acc_apply('LOAN', p_id::text, p_tenant, p_org, zeloshr.zhr_acc_loan_figures(p_id),
        'zhr.staff_loan_granted', 'zhr.staff_loan_voided',
        CASE WHEN NOT EXISTS (SELECT 1 FROM zeloshr.zhr_employee_loans WHERE id = p_id) THEN 'DELETED' END, 'CANCELLED');
END
$f$;

-- ===================================================================== the trigger: fail open, loudly
CREATE OR REPLACE FUNCTION zeloshr.zhr_acc_trigger() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE
    v_id uuid; v_tenant text; v_org text; v_run uuid; v_old_run uuid;
    msg text;
    flag text;
    done text;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_id := OLD.id; v_tenant := OLD.tenant_id; v_org := OLD.org_id;
    ELSE
        v_id := NEW.id; v_tenant := NEW.tenant_id; v_org := NEW.org_id;
    END IF;
    BEGIN
        CASE TG_TABLE_NAME
        WHEN 'zhr_payroll_runs' THEN
            v_run := v_id;
        WHEN 'zhr_payroll_lines', 'zhr_payment_batches' THEN
            IF TG_OP <> 'DELETE' THEN v_run := NEW.run_id; END IF;
            IF TG_OP <> 'INSERT' THEN v_old_run := OLD.run_id; END IF;
            v_run := coalesce(v_run, v_old_run);
        WHEN 'zhr_payroll_filings' THEN
            PERFORM zeloshr.zhr_acc_sync_filing(v_id, v_tenant, v_org);
        WHEN 'zhr_employee_loans' THEN
            PERFORM zeloshr.zhr_acc_sync_loan(v_id, v_tenant, v_org);
        END CASE;
        IF v_run IS NOT NULL THEN
            -- At commit every row of a run sees the run as it finally stands: once per run per transaction
            -- (recalculating rewrites every line).
            done := 'zhr_acc.r' || md5(v_run::text);
            IF coalesce(current_setting(done, true), '') <> '1' THEN
                PERFORM set_config(done, '1', true);
                PERFORM zeloshr.zhr_acc_sync_run(v_run, v_tenant, v_org);
                PERFORM zeloshr.zhr_acc_sync_payments(v_run, v_tenant, v_org);
            END IF;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS msg = MESSAGE_TEXT;
        -- Once per document per transaction (a run's lines and the run itself each fire).
        flag := 'zhr_acc.e' || md5(CASE WHEN v_run IS NOT NULL THEN 'run' ELSE TG_TABLE_NAME END || coalesce(v_run, v_id)::text);
        IF coalesce(current_setting(flag, true), '') <> '1' THEN
            PERFORM set_config(flag, '1', true);
            PERFORM zeloshr.zhr_acc_publish(v_tenant, zeloshr.zhr_acc_business(v_tenant, v_org), 'zhr.posting_error', coalesce(v_run, v_id)::text,
                jsonb_build_object('org_id', v_org,
                                   'document_type', CASE WHEN v_run IS NOT NULL THEN 'PAYROLL_RUN'
                                       WHEN TG_TABLE_NAME = 'zhr_payroll_filings' THEN 'REMITTANCE' ELSE 'STAFF_LOAN' END,
                                   'document_id', coalesce(v_run, v_id)::text, 'document_number', coalesce(v_run, v_id)::text,
                                   'date', zeloshr.zhr_acc_day(v_tenant, now()), 'error', msg));
        END IF;
    END;
    RETURN NULL;
END
$f$;

-- ===================================================================== baseline (first run only)
-- Everything in ZelosHR before this runs is history: record it as already published, as it stands.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM zeloshr.zhr_acc_state WHERE kind = 'BASELINE' AND doc_id = 'BASELINE') THEN
        INSERT INTO zeloshr.zhr_acc_state (kind, doc_id, tenant_id, org_id, bus_id, value)
        SELECT 'RUN', r.id::text, r.tenant_id, r.org_id, zeloshr.zhr_acc_business(r.tenant_id, r.org_id), f
          FROM zeloshr.zhr_payroll_runs r, LATERAL zeloshr.zhr_acc_run_figures(r.id) f
         WHERE f IS NOT NULL ON CONFLICT DO NOTHING;
        -- Runs whose pay went out (marked paid, or batches confirmed): recorded as paid as they stand.
        INSERT INTO zeloshr.zhr_acc_state (kind, doc_id, tenant_id, org_id, bus_id, value)
        SELECT 'PAYMENT', r.id::text, r.tenant_id, r.org_id, s.bus_id,
               jsonb_build_object('paid', coalesce((
                   SELECT jsonb_object_agg(x.channel, round(x.amount, 2)) FROM (
                       SELECT coalesce(nullif(l.payment_channel, ''), 'bank_transfer') AS channel,
                              sum(CASE WHEN r.status = 'paid' THEN greatest(l.net, 0)
                                       ELSE least(greatest(l.net, 0), coalesce((
                                           SELECT sum((i->>'amount')::numeric) FROM zeloshr.zhr_payment_batches pb, jsonb_array_elements(coalesce(pb.items_json, '[]')) i
                                            WHERE pb.run_id = r.id AND i->>'status' = 'paid' AND i->>'employee_id' = l.employee_id::text), 0)) END) AS amount
                         FROM zeloshr.zhr_payroll_lines l WHERE l.run_id = r.id GROUP BY 1) x WHERE x.amount <> 0), '{}'),
                   'date', s.value->>'date', 'run', s.value - 'money' - 'earnings' - 'deductions' - 'employer')
          FROM zeloshr.zhr_payroll_runs r JOIN zeloshr.zhr_acc_state s ON s.kind = 'RUN' AND s.doc_id = r.id::text AND s.value IS NOT NULL
        ON CONFLICT DO NOTHING;
        INSERT INTO zeloshr.zhr_acc_state (kind, doc_id, tenant_id, org_id, bus_id, value)
        SELECT 'REMITTANCE', f.id::text, f.tenant_id, f.org_id, zeloshr.zhr_acc_business(f.tenant_id, f.org_id), x
          FROM zeloshr.zhr_payroll_filings f, LATERAL zeloshr.zhr_acc_filing_figures(f.id) x
         WHERE x IS NOT NULL ON CONFLICT DO NOTHING;
        INSERT INTO zeloshr.zhr_acc_state (kind, doc_id, tenant_id, org_id, bus_id, value)
        SELECT 'LOAN', ln.id::text, ln.tenant_id, ln.org_id, zeloshr.zhr_acc_business(ln.tenant_id, ln.org_id), x
          FROM zeloshr.zhr_employee_loans ln, LATERAL zeloshr.zhr_acc_loan_figures(ln.id) x
         WHERE x IS NOT NULL ON CONFLICT DO NOTHING;
        INSERT INTO zeloshr.zhr_acc_state (kind, doc_id, tenant_id, org_id, bus_id, value)
        VALUES ('BASELINE', 'BASELINE', '', NULL, NULL, NULL) ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- ===================================================================== the triggers
DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['zhr_payroll_runs', 'zhr_payroll_lines', 'zhr_payment_batches', 'zhr_payroll_filings', 'zhr_employee_loans'] LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS zhr_acc_event ON zeloshr.%I', t);
        EXECUTE format('CREATE CONSTRAINT TRIGGER zhr_acc_event AFTER INSERT OR UPDATE OR DELETE ON zeloshr.%I
                            DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION zeloshr.zhr_acc_trigger()', t);
        -- Seeds and data fixes (session_replication_role = replica) are business changes too.
        EXECUTE format('ALTER TABLE zeloshr.%I ENABLE ALWAYS TRIGGER zhr_acc_event', t);
    END LOOP;
END $$;

COMMIT;
