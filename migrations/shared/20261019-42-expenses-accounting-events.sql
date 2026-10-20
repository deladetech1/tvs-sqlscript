-- =====================================================================
-- Expenses tells the books what happened: accounting events
-- ---------------------------------------------------------------------
-- Roadmap Phase 1, step 3 (docs/POSTINGS.md §6). Every Expenses change that moves money publishes
-- an event to core_platform.cp_events IN THE SAME TRANSACTION as the change; Accounting reads them
-- (reader 'accounting') and posts journals into the business's books.
--
-- WHY TRIGGERS AND NOT THE GO SERVICE. The money in Expenses moves through more doors than one
-- service call: a claim is approved by the last approver, by finance, or by itself under the
-- auto-approve limit; it is paid back through the payout gateway (settled later by the
-- expenses-payouts job in the function app, or by "Check payments"), by hand, through ZelosHR's
-- payroll (marked paid when a payroll run is approved, read back by the job), or by netting an
-- advance; advances and bills are paid the same three ways; a statement line is matched to an
-- expense or made into one. Each of those ends in a write to exp_claims, exp_claim_payouts,
-- exp_bills, exp_bill_payouts, exp_advances or exp_statement_lines. Triggers on those tables see
-- every path, including the jobs and paths written after today.
--
-- WHY DEFERRED (fired at COMMIT). A claim's status, its expenses and its payouts change together
-- (netting an advance writes the payout, settles it and rolls the claim forward in one go). At
-- commit the trigger reads the document as it finally stands and compares it with what was last
-- published (expenses.exp_acc_state): only the difference is published. A write that fails rolls
-- back and publishes nothing.
--
-- Fail open, loudly: if describing a document raises, the write still commits and an
-- 'exp.posting_error' event names the document and the error; Accounting lists it as FAILED.
--
-- Events (subject = the Expenses id; amounts are strings with 2 decimals):
--   exp.claim_approved              a claim approved: its expenses by category (net + recoverable tax),
--                                   owed to the claimant
--   exp.claim_voided                reason CHANGED / UNAPPROVED / DELETED, with the figures it posted
--   exp.claim_reimbursed            a payout on a claim completed (method gateway / manual / payroll / advance)
--   exp.claim_reimbursement_reversed
--   exp.bill_approved               a supplier bill approved: owed to the supplier (cp_parties)
--   exp.bill_voided                 cancelled after approval (reason CANCELLED / CHANGED / DELETED)
--   exp.bill_paid                   a payout on a bill completed
--   exp.bill_payment_reversed
--   exp.advance_paid                an advance paid out to an employee
--   exp.advance_payment_reversed
--   exp.advance_returned            part of an advance handed back (cash)
--   exp.advance_return_reversed
--   exp.company_spend               money out of a business account (statement line) matched to an expense:
--                                   paid by the company, not owed to anybody
--   exp.company_spend_reversed      the line unmatched or set aside
--   exp.posting_error
--
-- Starts from now: rows that exist when this first runs are recorded as already published
-- (history belongs in the books' opening balances). Re-runs every deploy: idempotent.
-- =====================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS expenses.exp_acc_state (
    kind       text NOT NULL,          -- CLAIM, CLAIM_PAYOUT, BILL, BILL_PAYOUT, ADVANCE, ADVANCE_RETURN, SPEND, BASELINE
    doc_id     text NOT NULL,
    tenant_id  text NOT NULL,
    bus_id     text,
    revision   integer NOT NULL DEFAULT 0,
    -- What was last published (NULL: nothing stands in the books for it now). 'money' is what counts as a change.
    value      jsonb,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (kind, doc_id)
);
CREATE INDEX IF NOT EXISTS exp_acc_state_expense_idx ON expenses.exp_acc_state ((value->>'expense_id')) WHERE kind = 'SPEND';

-- ===================================================================== helpers
CREATE OR REPLACE FUNCTION expenses.exp_acc_money(v numeric) RETURNS text
LANGUAGE sql IMMUTABLE AS $f$ SELECT to_char(round(coalesce(v, 0), 2), 'FM9999999999999990.00') $f$;

-- The business's date at an instant: the tenant's zone in Core Platform, else UTC.
CREATE OR REPLACE FUNCTION expenses.exp_acc_day(p_tenant text, p_at timestamptz) RETURNS date
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

CREATE OR REPLACE FUNCTION expenses.exp_acc_org(p_tenant text, p_bus text) RETURNS text
LANGUAGE sql STABLE AS $f$
    SELECT org_id FROM core_platform.cp_businesses WHERE id = p_bus AND tenant_id = p_tenant LIMIT 1
$f$;

-- A category as the books need it: Accounting picks the account from the id (a business's own
-- choice in Settings → Posting accounts), else the category's own code, else its name and kind.
CREATE OR REPLACE FUNCTION expenses.exp_acc_category(p_id text) RETURNS jsonb
LANGUAGE sql STABLE AS $f$
    SELECT coalesce(
        (SELECT jsonb_build_object('category_id', k.id, 'category_name', k.name, 'category_code', nullif(k.code, ''), 'category_kind', k.kind)
           FROM expenses.exp_categories k WHERE k.id = p_id),
        jsonb_build_object('category_id', NULL, 'category_name', 'Uncategorised', 'category_code', NULL, 'category_kind', 'expense'))
$f$;

CREATE OR REPLACE FUNCTION expenses.exp_acc_publish(p_tenant text, p_bus text, p_kind text, p_subject text, p_payload jsonb)
RETURNS bigint LANGUAGE sql AS $f$
    SELECT core_platform.cp_event_publish(p_tenant, p_bus, 'expenses', p_kind, p_subject,
                                          jsonb_build_object('version', 1, 'app', 'expenses') || p_payload)
$f$;

-- Publishes the difference between what stands in the books for a document (its state) and what
-- should (p_target, NULL for nothing): a void of the old figures, then the new ones.
CREATE OR REPLACE FUNCTION expenses.exp_acc_apply(p_state text, p_id text, p_tenant text, p_bus text, p_target jsonb,
                                                  p_issue_kind text, p_void_kind text, p_gone_reason text, p_unrecognised_reason text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
    st expenses.exp_acc_state;
    old jsonb;
    rev integer;
    reason text;
BEGIN
    SELECT * INTO st FROM expenses.exp_acc_state WHERE kind = p_state AND doc_id = p_id;
    old := st.value;
    IF (old->'money') IS NOT DISTINCT FROM (p_target->'money') THEN RETURN; END IF;
    rev := coalesce(st.revision, 0);
    IF old IS NOT NULL THEN
        reason := CASE WHEN p_target IS NOT NULL THEN 'CHANGED' ELSE coalesce(p_gone_reason, p_unrecognised_reason) END;
        PERFORM expenses.exp_acc_publish(p_tenant, p_bus, p_void_kind, p_id, (old - 'money') || jsonb_build_object(
            'revision', rev, 'reason', reason,
            -- A change replaces the document on its own date; anything else is dated the day it happened.
            'date', CASE WHEN reason = 'CHANGED' THEN (old->>'date')::date
                         ELSE greatest((old->>'date')::date, expenses.exp_acc_day(p_tenant, now())) END));
    END IF;
    IF p_target IS NOT NULL THEN
        rev := rev + 1;
        PERFORM expenses.exp_acc_publish(p_tenant, p_bus, p_issue_kind, p_id, (p_target - 'money') || jsonb_build_object('revision', rev));
    END IF;
    INSERT INTO expenses.exp_acc_state (kind, doc_id, tenant_id, bus_id, revision, value, updated_at)
    VALUES (p_state, p_id, p_tenant, p_bus, rev, p_target, now())
    ON CONFLICT (kind, doc_id) DO UPDATE SET revision = EXCLUDED.revision, value = EXCLUDED.value, updated_at = now();
END
$f$;

-- ===================================================================== what each document puts in the books
-- A claim, once approved: its expenses by category, in the claim's currency (amount_base; tax at
-- the expense's own rate). Expenses the company already paid (a statement line matched to them,
-- published as exp.company_spend) are left out: they are not owed to the claimant.
CREATE OR REPLACE FUNCTION expenses.exp_acc_claim_figures(p_id text) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $f$
DECLARE
    c expenses.exp_claims;
    v_lines jsonb;
    v_money jsonb;
    v_total numeric;
    v_tax numeric;
    v_company numeric;
BEGIN
    SELECT * INTO c FROM expenses.exp_claims WHERE id = p_id;
    IF NOT FOUND OR c.status NOT IN ('approved', 'paid') THEN RETURN NULL; END IF;
    WITH x AS (
        SELECT e.category_id, round(e.amount_base, 2) AS gross,
               least(round(e.amount_base, 2), round(e.tax_amount * e.exchange_rate, 2)) AS tax,
               EXISTS (SELECT 1 FROM expenses.exp_acc_state s WHERE s.kind = 'SPEND' AND s.value IS NOT NULL AND s.value->>'expense_id' = e.id) AS company
          FROM expenses.exp_expenses e WHERE e.claim_id = c.id
    ), g AS (
        SELECT category_id, sum(gross - tax) AS net, sum(tax) AS tax FROM x WHERE NOT company GROUP BY category_id
    )
    SELECT coalesce(jsonb_agg(expenses.exp_acc_category(g.category_id)
                              || jsonb_build_object('net', expenses.exp_acc_money(g.net), 'tax', expenses.exp_acc_money(g.tax))
                              ORDER BY g.category_id NULLS LAST), '[]'::jsonb),
           coalesce(jsonb_agg(jsonb_build_array(g.category_id, round(g.net, 2), round(g.tax, 2)) ORDER BY g.category_id NULLS LAST), '[]'::jsonb),
           coalesce(sum(g.net + g.tax), 0), coalesce(sum(g.tax), 0),
           (SELECT coalesce(sum(gross), 0) FROM x WHERE company)
      INTO v_lines, v_money, v_total, v_tax, v_company
      FROM g;
    IF v_total = 0 THEN RETURN NULL; END IF;
    RETURN jsonb_build_object(
        'org_id', coalesce(c.org_id, expenses.exp_acc_org(c.tenant_id, c.bus_id)),
        'document_type', 'CLAIM', 'document_id', c.id, 'document_number', coalesce(c.number, c.id),
        'date', expenses.exp_acc_day(c.tenant_id, coalesce(c.approved_at, c.decided_at, now())),
        'currency', upper(c.currency::text),
        'claimant_id', c.claimant_id, 'claimant_name', nullif(c.claimant_name, ''), 'title', nullif(c.title, ''),
        'lines', v_lines, 'tax', expenses.exp_acc_money(v_tax), 'total', expenses.exp_acc_money(v_total),
        'amount', expenses.exp_acc_money(v_total), 'company_paid', expenses.exp_acc_money(v_company),
        'money', jsonb_build_object('lines', v_money, 'currency', c.currency, 'date', expenses.exp_acc_day(c.tenant_id, coalesce(c.approved_at, c.decided_at, now()))));
END
$f$;

-- A supplier bill, once approved: its category (else the supplier's), net and tax; owed to the supplier.
CREATE OR REPLACE FUNCTION expenses.exp_acc_bill_figures(p_id text) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $f$
DECLARE
    b expenses.exp_bills;
    v_cat text;
    v_vendor text;
    v_gross numeric;
    v_tax numeric;
BEGIN
    SELECT * INTO b FROM expenses.exp_bills WHERE id = p_id;
    IF NOT FOUND OR b.status NOT IN ('approved', 'paid') THEN RETURN NULL; END IF;
    v_cat := coalesce(b.category_id, (SELECT vs.category_id FROM expenses.exp_vendor_settings vs WHERE vs.party_id = b.vendor_id AND vs.bus_id = b.bus_id));
    SELECT p.name INTO v_vendor FROM core_platform.cp_parties p WHERE p.id = b.vendor_id;
    v_gross := round(b.amount, 2);
    v_tax := least(v_gross, round(b.tax_amount, 2));
    RETURN jsonb_build_object(
        'org_id', coalesce(b.org_id, expenses.exp_acc_org(b.tenant_id, b.bus_id)),
        'document_type', 'BILL', 'document_id', b.id, 'document_number', coalesce(nullif(b.number, ''), 'Bill ' || left(b.id, 8)),
        'date', b.issued_on, 'due_on', b.due_on, 'currency', upper(b.currency::text),
        'supplier_id', b.vendor_id, 'party_id', b.vendor_id, 'supplier_name', v_vendor, 'description', nullif(b.description, ''),
        'lines', jsonb_build_array(expenses.exp_acc_category(v_cat)
                 || jsonb_build_object('net', expenses.exp_acc_money(v_gross - v_tax), 'tax', expenses.exp_acc_money(v_tax))),
        'tax', expenses.exp_acc_money(v_tax), 'total', expenses.exp_acc_money(v_gross), 'amount', expenses.exp_acc_money(v_gross),
        'money', jsonb_build_object('category', v_cat, 'gross', v_gross, 'tax', v_tax, 'currency', b.currency, 'date', b.issued_on));
END
$f$;

-- A payout (claim or bill) once completed: success through the gateway, recorded by hand, through
-- payroll, or an advance netted off.
CREATE OR REPLACE FUNCTION expenses.exp_acc_payout_figures(p_kind text, p_id text) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $f$
DECLARE
    r record;
    d record;
BEGIN
    IF p_kind = 'CLAIM_PAYOUT' THEN
        SELECT po.id, po.tenant_id, po.bus_id, po.amount, po.currency, po.method, po.status, po.completed_at, po.cdatetime,
               po.manual_reference, po.app_reference, po.claim_id AS doc_id
          INTO r FROM expenses.exp_claim_payouts po WHERE po.id = p_id;
        IF NOT FOUND THEN RETURN NULL; END IF;
        SELECT c.number, c.claimant_name AS who, c.org_id INTO d FROM expenses.exp_claims c WHERE c.id = r.doc_id;
    ELSE
        SELECT po.id, po.tenant_id, po.bus_id, po.amount, po.currency, po.method, po.status, po.completed_at, po.cdatetime,
               po.manual_reference, po.app_reference, po.bill_id AS doc_id
          INTO r FROM expenses.exp_bill_payouts po WHERE po.id = p_id;
        IF NOT FOUND THEN RETURN NULL; END IF;
        SELECT coalesce(nullif(b.number, ''), 'Bill ' || left(b.id, 8)) AS number, p.name AS who, b.org_id, b.vendor_id
          INTO d FROM expenses.exp_bills b LEFT JOIN core_platform.cp_parties p ON p.id = b.vendor_id WHERE b.id = r.doc_id;
    END IF;
    IF r.status NOT IN ('success', 'manual') THEN RETURN NULL; END IF;
    RETURN jsonb_build_object(
        'org_id', coalesce(d.org_id, expenses.exp_acc_org(r.tenant_id, r.bus_id)),
        'document_type', CASE p_kind WHEN 'CLAIM_PAYOUT' THEN 'CLAIM' ELSE 'BILL' END,
        'document_id', r.doc_id, 'document_number', coalesce(d.number, r.doc_id), 'payout_id', r.id,
        'reference', coalesce(nullif(r.manual_reference, ''), r.app_reference),
        CASE p_kind WHEN 'CLAIM_PAYOUT' THEN 'claimant_name' ELSE 'supplier_name' END, d.who,
        'date', expenses.exp_acc_day(r.tenant_id, coalesce(r.completed_at, r.cdatetime)),
        'currency', upper(r.currency::text), 'method', upper(r.method), 'amount', expenses.exp_acc_money(r.amount),
        'money', jsonb_build_object('amount', round(r.amount, 2), 'method', r.method, 'currency', r.currency));
END
$f$;

-- An advance, once paid out.
CREATE OR REPLACE FUNCTION expenses.exp_acc_advance_figures(p_id text) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $f$
DECLARE a expenses.exp_advances;
BEGIN
    SELECT * INTO a FROM expenses.exp_advances WHERE id = p_id;
    IF NOT FOUND OR a.status NOT IN ('paid', 'settled') OR coalesce(a.payout_status, '') NOT IN ('success', 'manual') THEN RETURN NULL; END IF;
    RETURN jsonb_build_object(
        'org_id', expenses.exp_acc_org(a.tenant_id, a.bus_id),
        'document_type', 'ADVANCE', 'document_id', a.id, 'document_number', 'ADV-' || upper(left(replace(a.id, '-', ''), 8)),
        'employee_id', a.user_id, 'claimant_name', nullif(a.user_name, ''),
        'date', expenses.exp_acc_day(a.tenant_id, coalesce(a.paid_at, a.updated_at)),
        'currency', upper(a.currency::text), 'method', upper(coalesce(a.payout_method, 'manual')),
        'reference', coalesce(nullif(a.manual_reference, ''), a.app_reference),
        'amount', expenses.exp_acc_money(a.amount),
        'money', jsonb_build_object('amount', round(a.amount, 2), 'method', a.payout_method, 'currency', a.currency));
END
$f$;

-- Money out of a business account matched to an expense: the company paid it.
CREATE OR REPLACE FUNCTION expenses.exp_acc_spend_figures(p_id text) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $f$
DECLARE
    l expenses.exp_statement_lines;
    a expenses.exp_accounts;
    x expenses.exp_expenses;
    v_gross numeric;
    v_tax numeric;
BEGIN
    SELECT * INTO l FROM expenses.exp_statement_lines WHERE id = p_id;
    IF NOT FOUND OR l.status <> 'matched' OR l.matched_kind IS DISTINCT FROM 'expense' THEN RETURN NULL; END IF;
    SELECT * INTO x FROM expenses.exp_expenses WHERE id = l.matched_id;
    IF NOT FOUND THEN RETURN NULL; END IF;
    SELECT * INTO a FROM expenses.exp_accounts WHERE id = l.account_id;
    v_gross := round(x.amount, 2);
    v_tax := least(v_gross, round(x.tax_amount, 2));
    RETURN jsonb_build_object(
        'org_id', coalesce(x.org_id, expenses.exp_acc_org(l.tenant_id, l.bus_id)),
        'document_type', 'STATEMENT_LINE', 'document_id', l.id,
        'document_number', coalesce(nullif(l.reference, ''), nullif(left(l.description, 40), ''), 'Line ' || left(l.id, 8)),
        'expense_id', x.id, 'merchant', nullif(x.merchant, ''), 'description', nullif(l.description, ''),
        'account_id', a.id, 'account_kind', upper(coalesce(a.kind, 'bank')), 'account_name', a.name,
        'date', l.posted_on, 'currency', upper(x.currency::text),
        'lines', jsonb_build_array(expenses.exp_acc_category(x.category_id)
                 || jsonb_build_object('net', expenses.exp_acc_money(v_gross - v_tax), 'tax', expenses.exp_acc_money(v_tax))),
        'tax', expenses.exp_acc_money(v_tax), 'total', expenses.exp_acc_money(v_gross), 'amount', expenses.exp_acc_money(v_gross),
        'money', jsonb_build_object('expense', x.id, 'category', x.category_id, 'gross', v_gross, 'tax', v_tax, 'currency', x.currency,
                                    'account', a.kind, 'date', l.posted_on));
END
$f$;

-- ===================================================================== syncing one document
CREATE OR REPLACE FUNCTION expenses.exp_acc_sync_claim(p_id text, p_tenant text, p_bus text) RETURNS void
LANGUAGE plpgsql AS $f$
BEGIN
    PERFORM expenses.exp_acc_apply('CLAIM', p_id, p_tenant, p_bus, expenses.exp_acc_claim_figures(p_id),
        'exp.claim_approved', 'exp.claim_voided',
        CASE WHEN NOT EXISTS (SELECT 1 FROM expenses.exp_claims WHERE id = p_id) THEN 'DELETED' END, 'UNAPPROVED');
END
$f$;

CREATE OR REPLACE FUNCTION expenses.exp_acc_sync_bill(p_id text, p_tenant text, p_bus text) RETURNS void
LANGUAGE plpgsql AS $f$
BEGIN
    PERFORM expenses.exp_acc_apply('BILL', p_id, p_tenant, p_bus, expenses.exp_acc_bill_figures(p_id),
        'exp.bill_approved', 'exp.bill_voided',
        CASE WHEN NOT EXISTS (SELECT 1 FROM expenses.exp_bills WHERE id = p_id) THEN 'DELETED' END, 'CANCELLED');
END
$f$;

CREATE OR REPLACE FUNCTION expenses.exp_acc_sync_payout(p_kind text, p_id text, p_tenant text, p_bus text) RETURNS void
LANGUAGE plpgsql AS $f$
BEGIN
    IF p_kind = 'CLAIM_PAYOUT' THEN
        PERFORM expenses.exp_acc_apply(p_kind, p_id, p_tenant, p_bus, expenses.exp_acc_payout_figures(p_kind, p_id),
            'exp.claim_reimbursed', 'exp.claim_reimbursement_reversed', NULL, 'REVERSED');
    ELSE
        PERFORM expenses.exp_acc_apply(p_kind, p_id, p_tenant, p_bus, expenses.exp_acc_payout_figures(p_kind, p_id),
            'exp.bill_paid', 'exp.bill_payment_reversed', NULL, 'REVERSED');
    END IF;
END
$f$;

CREATE OR REPLACE FUNCTION expenses.exp_acc_sync_advance(p_id text, p_tenant text, p_bus text) RETURNS void
LANGUAGE plpgsql AS $f$
DECLARE
    a expenses.exp_advances;
    st expenses.exp_acc_state;
    was numeric;
    now_returned numeric;
    delta numeric;
BEGIN
    PERFORM expenses.exp_acc_apply('ADVANCE', p_id, p_tenant, p_bus, expenses.exp_acc_advance_figures(p_id),
        'exp.advance_paid', 'exp.advance_payment_reversed', NULL, 'REVERSED');
    -- Handed back: published as the difference in what has been returned.
    SELECT * INTO a FROM expenses.exp_advances WHERE id = p_id;
    SELECT * INTO st FROM expenses.exp_acc_state WHERE kind = 'ADVANCE_RETURN' AND doc_id = p_id;
    was := coalesce((st.value->>'returned')::numeric, 0);
    now_returned := CASE WHEN a.id IS NULL THEN 0 ELSE round(coalesce(a.returned, 0), 2) END;
    delta := now_returned - was;
    IF delta = 0 THEN RETURN; END IF;
    PERFORM expenses.exp_acc_publish(p_tenant, p_bus, CASE WHEN delta > 0 THEN 'exp.advance_returned' ELSE 'exp.advance_return_reversed' END, p_id,
        jsonb_build_object('org_id', expenses.exp_acc_org(p_tenant, p_bus),
            'document_type', 'ADVANCE', 'document_id', p_id, 'document_number', 'ADV-' || upper(left(replace(p_id, '-', ''), 8)),
            'claimant_name', nullif(a.user_name, ''), 'employee_id', a.user_id,
            'date', expenses.exp_acc_day(p_tenant, now()), 'currency', upper(coalesce(a.currency::text, '')),
            'method', 'CASH', 'amount', expenses.exp_acc_money(abs(delta)), 'returned', expenses.exp_acc_money(now_returned)));
    INSERT INTO expenses.exp_acc_state (kind, doc_id, tenant_id, bus_id, revision, value, updated_at)
    VALUES ('ADVANCE_RETURN', p_id, p_tenant, p_bus, coalesce(st.revision, 0) + 1, jsonb_build_object('returned', now_returned), now())
    ON CONFLICT (kind, doc_id) DO UPDATE SET revision = EXCLUDED.revision, value = EXCLUDED.value, updated_at = now();
END
$f$;

CREATE OR REPLACE FUNCTION expenses.exp_acc_sync_spend(p_id text, p_tenant text, p_bus text) RETURNS void
LANGUAGE plpgsql AS $f$
BEGIN
    PERFORM expenses.exp_acc_apply('SPEND', p_id, p_tenant, p_bus, expenses.exp_acc_spend_figures(p_id),
        'exp.company_spend', 'exp.company_spend_reversed',
        CASE WHEN NOT EXISTS (SELECT 1 FROM expenses.exp_statement_lines WHERE id = p_id) THEN 'DELETED' END, 'UNMATCHED');
END
$f$;

-- ===================================================================== the trigger: fail open, loudly
CREATE OR REPLACE FUNCTION expenses.exp_acc_trigger() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE
    v_id text; v_tenant text; v_bus text; v_claim text; v_old_claim text; v_matched text;
    msg text;
    flag text;
    l record;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_id := OLD.id; v_tenant := OLD.tenant_id; v_bus := OLD.bus_id;
    ELSE
        v_id := NEW.id; v_tenant := NEW.tenant_id; v_bus := NEW.bus_id;
    END IF;
    BEGIN
        CASE TG_TABLE_NAME
        WHEN 'exp_claims' THEN
            PERFORM expenses.exp_acc_sync_claim(v_id, v_tenant, v_bus);
        WHEN 'exp_expenses' THEN
            -- An expense changes its claim's figures (and a company payment matched to it).
            IF TG_OP <> 'INSERT' THEN v_old_claim := OLD.claim_id; END IF;
            IF TG_OP <> 'DELETE' THEN v_claim := NEW.claim_id; END IF;
            IF v_claim IS NOT NULL THEN PERFORM expenses.exp_acc_sync_claim(v_claim, v_tenant, v_bus); END IF;
            IF v_old_claim IS NOT NULL AND v_old_claim IS DISTINCT FROM v_claim THEN
                PERFORM expenses.exp_acc_sync_claim(v_old_claim, v_tenant, v_bus);
            END IF;
            FOR l IN SELECT id FROM expenses.exp_statement_lines WHERE matched_kind = 'expense' AND matched_id = v_id LOOP
                PERFORM expenses.exp_acc_sync_spend(l.id, v_tenant, v_bus);
            END LOOP;
        WHEN 'exp_claim_payouts' THEN
            PERFORM expenses.exp_acc_sync_payout('CLAIM_PAYOUT', v_id, v_tenant, v_bus);
        WHEN 'exp_bills' THEN
            PERFORM expenses.exp_acc_sync_bill(v_id, v_tenant, v_bus);
        WHEN 'exp_bill_payouts' THEN
            PERFORM expenses.exp_acc_sync_payout('BILL_PAYOUT', v_id, v_tenant, v_bus);
        WHEN 'exp_advances' THEN
            PERFORM expenses.exp_acc_sync_advance(v_id, v_tenant, v_bus);
        WHEN 'exp_statement_lines' THEN
            IF TG_OP <> 'DELETE' AND NEW.matched_kind = 'expense' THEN v_matched := NEW.matched_id; END IF;
            PERFORM expenses.exp_acc_sync_spend(v_id, v_tenant, v_bus);
            -- A company payment changes what its expense's claim owes the claimant.
            FOR l IN SELECT e.claim_id FROM expenses.exp_expenses e
                      WHERE e.claim_id IS NOT NULL
                        AND e.id IN (SELECT s.value->>'expense_id' FROM expenses.exp_acc_state s WHERE s.kind = 'SPEND' AND s.doc_id = v_id
                                     UNION SELECT v_matched WHERE v_matched IS NOT NULL) LOOP
                PERFORM expenses.exp_acc_sync_claim(l.claim_id, v_tenant, v_bus);
            END LOOP;
        END CASE;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS msg = MESSAGE_TEXT;
        -- Once per row per transaction (a row written several times fires several times).
        flag := 'exp_acc.e' || md5(TG_TABLE_NAME || v_id);
        IF coalesce(current_setting(flag, true), '') <> '1' THEN
            PERFORM set_config(flag, '1', true);
            PERFORM expenses.exp_acc_publish(v_tenant, v_bus, 'exp.posting_error', v_id,
                jsonb_build_object('org_id', expenses.exp_acc_org(v_tenant, v_bus),
                                   'document_type', CASE TG_TABLE_NAME WHEN 'exp_claims' THEN 'CLAIM' WHEN 'exp_expenses' THEN 'EXPENSE'
                                       WHEN 'exp_claim_payouts' THEN 'CLAIM_PAYOUT' WHEN 'exp_bills' THEN 'BILL'
                                       WHEN 'exp_bill_payouts' THEN 'BILL_PAYOUT' WHEN 'exp_advances' THEN 'ADVANCE'
                                       ELSE 'STATEMENT_LINE' END,
                                   'document_id', v_id, 'document_number', v_id,
                                   'date', expenses.exp_acc_day(v_tenant, now()), 'error', msg));
        END IF;
    END;
    RETURN NULL;
END
$f$;

-- ===================================================================== baseline (first run only)
-- Everything in Expenses before this runs is history: record it as already published, as it stands.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM expenses.exp_acc_state WHERE kind = 'BASELINE' AND doc_id = 'BASELINE') THEN
        -- Company payments first: claims leave them out.
        INSERT INTO expenses.exp_acc_state (kind, doc_id, tenant_id, bus_id, value)
        SELECT 'SPEND', l.id, l.tenant_id, l.bus_id, f FROM expenses.exp_statement_lines l, LATERAL expenses.exp_acc_spend_figures(l.id) f
         WHERE f IS NOT NULL ON CONFLICT DO NOTHING;
        INSERT INTO expenses.exp_acc_state (kind, doc_id, tenant_id, bus_id, value)
        SELECT 'CLAIM', c.id, c.tenant_id, c.bus_id, f FROM expenses.exp_claims c, LATERAL expenses.exp_acc_claim_figures(c.id) f
         WHERE f IS NOT NULL ON CONFLICT DO NOTHING;
        INSERT INTO expenses.exp_acc_state (kind, doc_id, tenant_id, bus_id, value)
        SELECT 'CLAIM_PAYOUT', p.id, p.tenant_id, p.bus_id, f FROM expenses.exp_claim_payouts p, LATERAL expenses.exp_acc_payout_figures('CLAIM_PAYOUT', p.id) f
         WHERE f IS NOT NULL ON CONFLICT DO NOTHING;
        INSERT INTO expenses.exp_acc_state (kind, doc_id, tenant_id, bus_id, value)
        SELECT 'BILL', b.id, b.tenant_id, b.bus_id, f FROM expenses.exp_bills b, LATERAL expenses.exp_acc_bill_figures(b.id) f
         WHERE f IS NOT NULL ON CONFLICT DO NOTHING;
        INSERT INTO expenses.exp_acc_state (kind, doc_id, tenant_id, bus_id, value)
        SELECT 'BILL_PAYOUT', p.id, p.tenant_id, p.bus_id, f FROM expenses.exp_bill_payouts p, LATERAL expenses.exp_acc_payout_figures('BILL_PAYOUT', p.id) f
         WHERE f IS NOT NULL ON CONFLICT DO NOTHING;
        INSERT INTO expenses.exp_acc_state (kind, doc_id, tenant_id, bus_id, value)
        SELECT 'ADVANCE', a.id, a.tenant_id, a.bus_id, f FROM expenses.exp_advances a, LATERAL expenses.exp_acc_advance_figures(a.id) f
         WHERE f IS NOT NULL ON CONFLICT DO NOTHING;
        INSERT INTO expenses.exp_acc_state (kind, doc_id, tenant_id, bus_id, value)
        SELECT 'ADVANCE_RETURN', a.id, a.tenant_id, a.bus_id, jsonb_build_object('returned', round(a.returned, 2))
          FROM expenses.exp_advances a WHERE a.returned <> 0 ON CONFLICT DO NOTHING;
        INSERT INTO expenses.exp_acc_state (kind, doc_id, tenant_id, bus_id, value)
        VALUES ('BASELINE', 'BASELINE', '', NULL, NULL) ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- ===================================================================== the triggers
DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['exp_claims', 'exp_expenses', 'exp_claim_payouts', 'exp_bills', 'exp_bill_payouts', 'exp_advances', 'exp_statement_lines'] LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS exp_acc_event ON expenses.%I', t);
        EXECUTE format('CREATE CONSTRAINT TRIGGER exp_acc_event AFTER INSERT OR UPDATE OR DELETE ON expenses.%I
                            DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION expenses.exp_acc_trigger()', t);
        -- Seeds and data fixes (session_replication_role = replica) are business changes too.
        EXECUTE format('ALTER TABLE expenses.%I ENABLE ALWAYS TRIGGER exp_acc_event', t);
    END LOOP;
END $$;

COMMIT;
