-- =====================================================================
-- Projects in the books: costs and revenue by project (docs/POSTINGS.md §9)
-- ---------------------------------------------------------------------
-- Roadmap Phase 1, last app. Projects itself posts nothing: its money is either already posted by
-- another app or is not the books' to hold (§9 says which). What it adds is the PROJECT analysis:
--
--   * Expenses' spending events (exp.claim_approved / exp.bill_approved / exp.company_spend and
--     their voids) carry the project on each line: project_id, project_key, project_name. A claim's
--     lines are now by category AND project (an expense's own project, else its claim's); a bill's
--     and a company payment's line take the bill's / the expense's project.
--   * Invoicing's documents (inv.invoice_issued / inv.credit_note_issued and their voids) carry
--     `projects` [project_id, project_key, project_name, net]: the revenue (net of tax) of the lines
--     that bill a project's time or expenses (inv_invoice_lines.source_project_id), scaled to the
--     document's subtotal so a whole-invoice discount is shared out.
--   Accounting tags those journal lines with a PROJECT dimension it creates per project on first use.
--
-- Tags are analysis, not money: they are never part of what counts as a change (exp_acc_state's
-- 'money', inv_acc_fingerprint), so documents published before this file stay as they were posted
-- (untagged) and nothing is posted again because of it. A document posted from now on carries its
-- project; its void reverses exactly what it posted, tags included.
--
--   * accounting.src_prj_projects and accounting.src_prj_time: Projects' projects and logged time
--     with each entry's cost rate (Projects' own rule, most specific first), for Accounting's
--     read-only Project profitability report. Created only where Projects' tables exist; Accounting
--     shows them only to a business subscribed to Projects.
--
-- Redefines expenses.exp_acc_claim_figures / exp_acc_bill_figures / exp_acc_spend_figures (from
-- 20261019-42) and invoicing.inv_acc_doc_figures / inv_acc_fingerprint (from 20261019-43); the
-- money in each is unchanged. Re-runs every deploy: idempotent.
-- =====================================================================
BEGIN;

-- ===================================================================== a project as the books name it
-- {project_id, project_key, project_name} for a Projects project id; NULL for none. Read dynamically:
-- a database without Projects still describes (the id alone), never fails.
CREATE OR REPLACE FUNCTION expenses.exp_acc_project(p_id text) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $f$
DECLARE r jsonb;
BEGIN
    IF nullif(btrim(coalesce(p_id, '')), '') IS NULL THEN RETURN NULL; END IF;
    IF to_regclass('projects.prj_projects') IS NOT NULL THEN
        EXECUTE $q$SELECT jsonb_build_object('project_id', p.id, 'project_key', nullif(p.key, ''), 'project_name', p.name)
                     FROM projects.prj_projects p WHERE p.id = $1$q$ INTO r USING p_id;
    END IF;
    RETURN coalesce(r, jsonb_build_object('project_id', p_id, 'project_key', NULL, 'project_name', NULL));
END
$f$;

CREATE OR REPLACE FUNCTION invoicing.inv_acc_project(p_id text) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $f$
DECLARE r jsonb;
BEGIN
    IF nullif(btrim(coalesce(p_id, '')), '') IS NULL THEN RETURN NULL; END IF;
    IF to_regclass('projects.prj_projects') IS NOT NULL THEN
        EXECUTE $q$SELECT jsonb_build_object('project_id', p.id, 'project_key', nullif(p.key, ''), 'project_name', p.name)
                     FROM projects.prj_projects p WHERE p.id = $1$q$ INTO r USING p_id;
    END IF;
    RETURN coalesce(r, jsonb_build_object('project_id', p_id, 'project_key', NULL, 'project_name', NULL));
END
$f$;

-- ===================================================================== Expenses: lines carry the project
-- As 20261019-42, lines by category and project. 'money' (what counts as a change) is unchanged: by category.
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
        SELECT e.category_id, nullif(coalesce(e.project_id, c.project_id), '') AS project_id, round(e.amount_base, 2) AS gross,
               least(round(e.amount_base, 2), round(e.tax_amount * e.exchange_rate, 2)) AS tax,
               EXISTS (SELECT 1 FROM expenses.exp_acc_state s WHERE s.kind = 'SPEND' AND s.value IS NOT NULL AND s.value->>'expense_id' = e.id) AS company
          FROM expenses.exp_expenses e WHERE e.claim_id = c.id
    ), gp AS (
        SELECT category_id, project_id, sum(gross - tax) AS net, sum(tax) AS tax FROM x WHERE NOT company GROUP BY category_id, project_id
    ), g AS (
        SELECT category_id, sum(net) AS net, sum(tax) AS tax FROM gp GROUP BY category_id
    )
    SELECT (SELECT coalesce(jsonb_agg(expenses.exp_acc_category(gp.category_id)
                                      || coalesce(expenses.exp_acc_project(gp.project_id), '{}'::jsonb)
                                      || jsonb_build_object('net', expenses.exp_acc_money(gp.net), 'tax', expenses.exp_acc_money(gp.tax))
                                      ORDER BY gp.category_id NULLS LAST, gp.project_id NULLS FIRST), '[]'::jsonb) FROM gp),
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
                 || coalesce(expenses.exp_acc_project(b.project_id), '{}'::jsonb)
                 || jsonb_build_object('net', expenses.exp_acc_money(v_gross - v_tax), 'tax', expenses.exp_acc_money(v_tax))),
        'tax', expenses.exp_acc_money(v_tax), 'total', expenses.exp_acc_money(v_gross), 'amount', expenses.exp_acc_money(v_gross),
        'money', jsonb_build_object('category', v_cat, 'gross', v_gross, 'tax', v_tax, 'currency', b.currency, 'date', b.issued_on));
END
$f$;

CREATE OR REPLACE FUNCTION expenses.exp_acc_spend_figures(p_id text) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $f$
DECLARE
    l expenses.exp_statement_lines;
    a expenses.exp_accounts;
    x expenses.exp_expenses;
    v_project text;
    v_gross numeric;
    v_tax numeric;
BEGIN
    SELECT * INTO l FROM expenses.exp_statement_lines WHERE id = p_id;
    IF NOT FOUND OR l.status <> 'matched' OR l.matched_kind IS DISTINCT FROM 'expense' THEN RETURN NULL; END IF;
    SELECT * INTO x FROM expenses.exp_expenses WHERE id = l.matched_id;
    IF NOT FOUND THEN RETURN NULL; END IF;
    SELECT * INTO a FROM expenses.exp_accounts WHERE id = l.account_id;
    v_project := coalesce(nullif(x.project_id, ''), (SELECT nullif(c.project_id, '') FROM expenses.exp_claims c WHERE c.id = x.claim_id));
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
                 || coalesce(expenses.exp_acc_project(v_project), '{}'::jsonb)
                 || jsonb_build_object('net', expenses.exp_acc_money(v_gross - v_tax), 'tax', expenses.exp_acc_money(v_tax))),
        'tax', expenses.exp_acc_money(v_tax), 'total', expenses.exp_acc_money(v_gross), 'amount', expenses.exp_acc_money(v_gross),
        'money', jsonb_build_object('expense', x.id, 'category', x.category_id, 'gross', v_gross, 'tax', v_tax, 'currency', x.currency,
                                    'account', a.kind, 'date', l.posted_on));
END
$f$;

-- ===================================================================== Invoicing: revenue by project
-- As 20261019-43, plus `projects` when any line bills a project. Left out when none, so a document
-- without projects is described exactly as before.
CREATE OR REPLACE FUNCTION invoicing.inv_acc_doc_figures(i invoicing.inv_invoices) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $f$
DECLARE
    v_taxes jsonb;
    v_tax_sum numeric;
    v_tax_total numeric := round(coalesce(i.tax_total, 0), 2);
    v_total numeric := round(coalesce(i.total, 0), 2);
    v_withheld numeric := round(coalesce(i.withheld, 0), 2);
    v_lines_net numeric;
    v_projects jsonb;
    v_out jsonb;
BEGIN
    IF i.id IS NULL OR i.kind NOT IN ('invoice', 'credit_note') OR i.number IS NULL
       OR i.status NOT IN ('open', 'paid', 'applied') OR invoicing.inv_acc_linked(i) THEN
        RETURN NULL;
    END IF;
    SELECT coalesce(jsonb_agg(jsonb_build_object(
               'tax_id', nullif(t->>'rate_id', ''), 'name', coalesce(nullif(t->>'name', ''), 'Tax'),
               'short_name', coalesce(t->>'short_name', ''),
               'amount', invoicing.inv_acc_money((t->>'amount')::numeric)) ORDER BY ord), '[]'::jsonb),
           coalesce(sum(round((t->>'amount')::numeric, 2)), 0)
      INTO v_taxes, v_tax_sum
      FROM jsonb_array_elements(CASE WHEN jsonb_typeof(i.calc->'taxes') = 'array' THEN i.calc->'taxes' ELSE '[]'::jsonb END)
           WITH ORDINALITY AS x(t, ord)
     WHERE coalesce(t->>'treatment', '') IN ('standard', 'zero_rated', '')
       AND coalesce((t->>'amount')::numeric, 0) <> 0;
    -- The summary is what was charged; whatever it does not explain of tax_total goes to "Tax".
    IF v_tax_total - v_tax_sum <> 0 THEN
        v_taxes := v_taxes || jsonb_build_array(jsonb_build_object('tax_id', NULL, 'name', 'Tax', 'short_name', '',
                                                                   'amount', invoicing.inv_acc_money(v_tax_total - v_tax_sum)));
    END IF;
    v_out := jsonb_build_object(
        'document_type', CASE i.kind WHEN 'credit_note' THEN 'CREDIT_NOTE' ELSE 'INVOICE' END,
        'date', i.issue_date,
        'currency', upper(i.currency::text),
        'subtotal', invoicing.inv_acc_money(v_total - v_tax_total),
        'taxes', v_taxes,
        'tax', invoicing.inv_acc_money(v_tax_total),
        'withheld', invoicing.inv_acc_money(v_withheld),
        'receivable', invoicing.inv_acc_money(v_total - v_withheld),
        'total', invoicing.inv_acc_money(v_total));

    -- Each project's share of the revenue: its lines' net over all lines' net, of the subtotal.
    SELECT sum(l.net) INTO v_lines_net FROM invoicing.inv_invoice_lines l WHERE l.invoice_id = i.id;
    IF coalesce(v_lines_net, 0) <> 0 AND v_total - v_tax_total <> 0 THEN
        SELECT jsonb_agg(invoicing.inv_acc_project(s.project_id)
                         || jsonb_build_object('net', invoicing.inv_acc_money((v_total - v_tax_total) * s.net / v_lines_net))
                         ORDER BY s.project_id)
          INTO v_projects
          FROM (SELECT l.source_project_id AS project_id, sum(l.net) AS net FROM invoicing.inv_invoice_lines l
                 WHERE l.invoice_id = i.id AND nullif(l.source_project_id, '') IS NOT NULL
                 GROUP BY l.source_project_id HAVING sum(l.net) <> 0) s;
        IF v_projects IS NOT NULL THEN
            v_out := v_out || jsonb_build_object('projects', v_projects);
        END IF;
    END IF;
    RETURN v_out;
END
$f$;

-- What counts as a change: the money, never the words, and never the project analysis.
CREATE OR REPLACE FUNCTION invoicing.inv_acc_fingerprint(v jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE AS $f$
    SELECT CASE WHEN v IS NULL THEN NULL ELSE v - 'credit_note_number' - 'document_number' - 'invoice_id' - 'projects' END
$f$;

-- ===================================================================== what the report reads
DO $$
BEGIN
    IF to_regclass('projects.prj_projects') IS NOT NULL AND to_regclass('projects.prj_worklogs') IS NOT NULL
       AND to_regclass('projects.prj_rates') IS NOT NULL AND to_regclass('accounting.acc_journal_lines') IS NOT NULL THEN
        -- Columns only ever appended: CREATE OR REPLACE VIEW cannot reorder them.
        EXECUTE $v$
        CREATE OR REPLACE VIEW accounting.src_prj_projects AS
        SELECT p.tenant_id, p.bus_id, p.id, coalesce(p.key, '') AS key, p.name, p.status,
               upper(coalesce(nullif(p.currency, ''),
                     (SELECT cu.code FROM core_platform.cp_currencies cu
                       WHERE cu.tenant_id = p.tenant_id AND cu.is_default AND cu.delete_status = 'NOT_DELETED' LIMIT 1), '')) AS currency,
               p.budget_amount, p.budget_hours, p.billing
          FROM projects.prj_projects p
         WHERE coalesce(p.delete_status, 'NOT_DELETED') = 'NOT_DELETED' AND NOT coalesce(p.is_template, false)
        $v$;
        -- Each time entry with the cost rate Projects applies to it (projecttime.RateSQL: the person's
        -- own on the project, then on the workspace, then their role's, then everyone's). NULL: no rate.
        EXECUTE $v$
        CREATE OR REPLACE VIEW accounting.src_prj_time AS
        SELECT wl.tenant_id, p.bus_id, wl.project_id, wl.id, wl.user_id, wl.work_date, wl.minutes, wl.billable,
               (SELECT r.cost_rate FROM projects.prj_rates r
                  LEFT JOIN projects.prj_rate_roles rr ON rr.workspace_id = r.workspace_id AND rr.user_id = wl.user_id
                 WHERE r.workspace_id = p.workspace_id AND r.cost_rate IS NOT NULL
                   AND (r.project_id = p.id OR r.project_id IS NULL)
                   AND (r.user_id = wl.user_id OR (r.user_id IS NULL AND (r.role IS NULL OR lower(r.role) = lower(rr.role))))
                 ORDER BY (r.project_id IS NOT NULL) DESC, (r.user_id IS NOT NULL) DESC, (r.role IS NOT NULL) DESC LIMIT 1) AS cost_rate
          FROM projects.prj_worklogs wl
          JOIN projects.prj_projects p ON p.id = wl.project_id
         WHERE coalesce(p.delete_status, 'NOT_DELETED') = 'NOT_DELETED' AND NOT coalesce(p.is_template, false)
        $v$;
    END IF;
END $$;

COMMIT;
