-- =====================================================================
-- LoanDrift expenses carry Core Platform's expense pattern to the books
-- ---------------------------------------------------------------------
-- LoanDrift now records each expense with a Core expense category, the day it was spent, the
-- tax inside it, a reference and a receipt (core_platform.cp_expenses_history, 20261108-04),
-- and debits the account its category's accounting code names in LoanDrift's chart, when the
-- tenant has one, instead of Operating Expenses.
--
-- LoanDrift publishes its LEDGER, not the expense row (20261019-41: one event per journal
-- entry, lines by system_key). Two things change here, both in ld_acc_sync_entry:
--
--   1. A line on an EXPENSE account with no system key (an account the tenant added for a
--      category) is published with account_key OPERATING_EXPENSE, so Accounting still posts it
--      (it maps keys to roles and refuses a key it does not know). The line's own
--      account_code/account_name stay as they are.
--   2. ld.expense_paid / ld.expense_reversed gain the expense's details at the top level:
--      expense_id, category_id, category_name, category_account_code, tax_rate_id, tax_amount
--      (string, 2 decimals; the tax is INSIDE amount), spent_on, funding_source (LoanDrift's
--      `source`: ALLOCATED came out of the Core budget), reference, receipt_file_id.
--      Loan charges (also source EXPENSE, 'charges-%') are unchanged.
--
-- Everything else in the function is 20261019-41's, unchanged (checked against the live
-- function on dev 2026-11-08). This file is now the definition of ld_acc_sync_entry: a later
-- change to it must start from here. Idempotent; safe to re-run on every deploy.
-- =====================================================================
BEGIN;

CREATE OR REPLACE FUNCTION loandrift.ld_acc_sync_entry(p_entry text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
    e loandrift.ld_journal_entries;
    o loandrift.ld_journal_entries;
    reversal boolean;
    v_source_id text;
    v_kind text;
    v_lines jsonb;
    v_total numeric;
    v_loan_id text;
    v_client_id text;
    ln record;
    cl record;
    v_doc_type text;
    v_doc_number text;
    v_account_number text;
    v_expense jsonb := '{}'::jsonb;
BEGIN
    SELECT * INTO e FROM loandrift.ld_journal_entries WHERE id = p_entry;
    IF NOT FOUND OR e.status NOT IN ('POSTED', 'REVERSED') OR e.delete_status IS DISTINCT FROM 'NOT_DELETED' THEN RETURN; END IF;
    IF EXISTS (SELECT 1 FROM loandrift.ld_acc_entry_state WHERE entry_id = p_entry) THEN RETURN; END IF;

    reversal := e.reversal_of_entry_id IS NOT NULL;
    IF reversal THEN
        SELECT * INTO o FROM loandrift.ld_journal_entries WHERE id = e.reversal_of_entry_id;
    END IF;
    v_source_id := coalesce(e.source_id, o.source_id);
    v_kind := loandrift.ld_acc_kind(e.source_type, v_source_id, reversal);
    IF v_kind IS NULL THEN RETURN; END IF;   -- Loandrift's own bookkeeping: not the books' business

    SELECT coalesce(jsonb_agg(jsonb_build_object(
               -- An expense debited to the account its category names (an account the tenant added,
               -- so no system key) is still an operating expense to the books.
               'account_key', coalesce(a.system_key,
                                       CASE WHEN e.source_type = 'EXPENSE' AND a.account_type = 'EXPENSE'
                                            THEN 'OPERATING_EXPENSE' END),
               'account_code', a.account_code, 'account_name', a.account_name,
               'account_type', a.account_type,
               'debit', loandrift.ld_acc_money(l.debit), 'credit', loandrift.ld_acc_money(l.credit),
               'description', l.description) ORDER BY l.line_number, l.id), '[]'::jsonb),
           sum(round(l.debit, 2)),
           (array_agg(l.loan_id ORDER BY l.line_number) FILTER (WHERE l.loan_id IS NOT NULL))[1],
           (array_agg(l.client_id ORDER BY l.line_number) FILTER (WHERE l.client_id IS NOT NULL))[1]
      INTO v_lines, v_total, v_loan_id, v_client_id
      FROM loandrift.ld_journal_lines l
      LEFT JOIN loandrift.ld_chart_of_accounts a ON a.id = l.account_id AND a.tenant_id = l.tenant_id
     WHERE l.journal_entry_id = e.id AND l.tenant_id = e.tenant_id;
    IF v_total IS NULL THEN RETURN; END IF;   -- no lines: nothing moved

    SELECT d.loan_reference, d.currency_id INTO ln FROM loandrift.ld_loan_details d
     WHERE d.id = v_loan_id AND d.tenant_id = e.tenant_id LIMIT 1;
    SELECT c.party_id, coalesce(nullif(trim(c.fullname), ''), nullif(trim(concat_ws(' ', c.first_name, c.surname)), '')) AS name
      INTO cl FROM loandrift.ld_clients c WHERE c.id = v_client_id AND c.tenant_id = e.tenant_id LIMIT 1;

    IF e.source_type LIKE 'SAVINGS_%' THEN
        SELECT s.account_number INTO v_account_number FROM loandrift.ld_savings_transactions t
          JOIN loandrift.ld_savings_accounts s ON s.id = t.savings_id AND s.tenant_id = t.tenant_id
         WHERE t.id = v_source_id AND t.tenant_id = e.tenant_id LIMIT 1;
    ELSIF e.source_type LIKE 'INVESTMENT%' THEN
        SELECT i.account_number INTO v_account_number FROM loandrift.ld_investment_transactions t
          JOIN loandrift.ld_investments i ON i.id = t.investment_id AND i.tenant_id = t.tenant_id
         WHERE t.id = v_source_id AND t.tenant_id = e.tenant_id LIMIT 1;
    END IF;

    -- An expense (not loan charges, which LoanDrift also files as EXPENSE): what Core's expense
    -- record says about it. The row is gone when the expense was deleted; the keys are then null.
    IF e.source_type = 'EXPENSE' AND coalesce(v_source_id, '') NOT LIKE 'charges-%' THEN
        SELECT jsonb_build_object(
                   'expense_id', v_source_id,
                   'category_id', x.category_id, 'category_name', cat.name, 'category_account_code', cat.account_code,
                   'tax_rate_id', x.tax_rate_id,
                   'tax_amount', CASE WHEN x.tax_amount IS NULL THEN NULL ELSE loandrift.ld_acc_money(x.tax_amount) END,
                   'spent_on', coalesce(x.spent_on, x.cdatetime::date),
                   'funding_source', x.source, 'reference', x.reference, 'receipt_file_id', x.receipt_file_id)
          INTO v_expense
          FROM (SELECT 1) one
          LEFT JOIN core_platform.cp_expenses_history x
                 ON x.tenant_id = e.tenant_id AND x.id = v_source_id AND x.app = 'LOANDRIFT'
          LEFT JOIN core_platform.cp_expense_categories cat
                 ON cat.tenant_id = x.tenant_id AND cat.id = x.category_id;
    END IF;

    v_doc_type := CASE
        WHEN e.source_type = 'REPAYMENT' THEN 'REPAYMENT'
        WHEN e.source_type IN ('LOAN_DISBURSEMENT', 'PENALTY', 'PENALTY_WAIVER') OR v_source_id LIKE 'charges-%' THEN 'LOAN'
        WHEN e.source_type IN ('WRITE_OFF', 'WRITE_OFF_RECOVERY') THEN 'WRITE_OFF'
        WHEN e.source_type LIKE 'SAVINGS_%' THEN 'SAVINGS'
        WHEN e.source_type LIKE 'INVESTMENT%' THEN 'INVESTMENT'
        ELSE e.source_type END;
    -- A repayment's number is the receipt Loandrift prints (rc_receipt_service._receipt_number).
    v_doc_number := coalesce(
        CASE WHEN e.source_type = 'REPAYMENT' AND v_source_id IS NOT NULL
             THEN 'RCP-' || upper(right(replace(v_source_id, '-', ''), 8)) END,
        v_account_number, nullif(e.loan_reference, ''), ln.loan_reference, e.entry_number, e.id);

    PERFORM core_platform.cp_event_publish(e.tenant_id, e.bus_id, 'loandrift', v_kind, e.id, jsonb_build_object(
        'version', 1, 'app', 'loandrift',
        'org_id', e.org_id, 'loc_id', e.loc_id,
        'location_name', (SELECT l.loc_name FROM core_platform.cp_locations l WHERE l.id = e.loc_id AND l.tenant_id = e.tenant_id LIMIT 1),
        'currency', loandrift.ld_acc_currency(e.tenant_id, coalesce(e.currency_id, ln.currency_id)),
        -- The day it happened: Loandrift moves an entry dated in its own closed period to the first
        -- open day and keeps the real date in original_date. The books have their own periods.
        'date', coalesce(e.original_date, e.entry_date),
        'document_type', v_doc_type, 'document_number', v_doc_number, 'document_id', v_source_id,
        'entry_id', e.id, 'entry_number', e.entry_number, 'source_type', e.source_type,
        'reversal', reversal, 'reverses_entry_id', e.reversal_of_entry_id, 'reverses_entry_number', o.entry_number,
        'loan_id', v_loan_id, 'loan_number', coalesce(nullif(e.loan_reference, ''), ln.loan_reference),
        'client_id', v_client_id, 'party_id', cl.party_id, 'customer_name', cl.name,
        'description', e.description,
        'amount', loandrift.ld_acc_money(v_total),
        'lines', v_lines) || coalesce(v_expense, '{}'::jsonb));
    INSERT INTO loandrift.ld_acc_entry_state (entry_id, tenant_id, bus_id, kind, total)
    VALUES (e.id, e.tenant_id, e.bus_id, v_kind, round(v_total, 2));
END
$f$;

COMMIT;
