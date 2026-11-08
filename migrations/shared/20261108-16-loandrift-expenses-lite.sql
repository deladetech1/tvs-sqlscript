-- =====================================================================
-- LoanDrift expenses follow the Expenses lite standard (apps-setup/EXPENSES-LITE-STANDARD.md)
-- ---------------------------------------------------------------------
-- Owner, 2026-11-08: every app records expenses with ONE flow -- record, optionally one
-- approval, mark paid, void -- and the books hear about an expense when the money LEFT (PAID).
-- 20261108-10 widened cp_expenses_history for that and left each app to move its own rows;
-- MyStoreGuard's part is 20261108-14. This is LoanDrift's:
--
--   1. LoanDrift posts an expense to its OWN ledger (ld_journal_entries, source EXPENSE) and
--      Accounting hears from the ledger (ld_acc_sync_entry: ld.expense_paid for the entry,
--      ld.expense_reversed for its reversal). Until now it posted when the expense was
--      RECORDED, so every existing LOANDRIFT expense is money already spent and already in the
--      ledger: APPROVED becomes PAID (paid_at = when it was recorded, paid_by = who recorded it).
--      ONCE per database (core_platform.cp_migration_decisions), because from now on APPROVED
--      means "approved, not paid yet" and a re-run on a later deploy must not pay those.
--      NOTHING is posted, reversed or published: only the status column changes. (The
--      cp_expense_acc_event trigger on that table is MyStoreGuard's and ignores other apps.)
--   2. Every deploy: an APPROVED LoanDrift expense that HAS a live posted ledger entry was
--      recorded by the previous backend between step 1 and the new backend going live (it
--      posted at record). Under the new flow that cannot happen (posting is at PAID), so such a
--      row is PAID; nothing in the ledger changes. Idempotent.
--   3. ld_acc_sync_entry (20261108-07 is the definition this starts from, unchanged otherwise):
--      ld.expense_paid / ld.expense_reversed also carry paid_from, payee, paid_at and
--      payment_reference. Not figures: Accounting's LoanDrift rules read the lines and amount.
--   4. Plan: `loandrift.expenses` moves to PREMIUM (rank 3; was ADVANCE). The API reads stay
--      open on every plan (records stay readable after a downgrade); recording and changing need
--      the feature (403 PLAN_UPGRADE_REQUIRED).
--   5. Permissions: loandrift|expenses|approve (approve or reject; never your own) and
--      loandrift|expenses|pay (mark paid), given ONCE to every role that may already change
--      expenses (holds permission-loandrift-expenses-update). Void uses ...-expenses-delete.
--
-- Idempotent; safe to re-run on every deploy.
-- =====================================================================
BEGIN;

-- ===================================================================== 3. the event payload
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
                   'funding_source', x.source, 'reference', x.reference, 'receipt_file_id', x.receipt_file_id,
                   -- Expenses lite (this file): where the money came from, who was paid, when.
                   'paid_from', x.paid_from, 'payee', x.payee, 'paid_at', x.paid_at,
                   'payment_reference', x.payment_reference)
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


-- ===================================================================== 1. existing rows become PAID, once
CREATE TABLE IF NOT EXISTS core_platform.cp_migration_decisions (
    decision_key text PRIMARY KEY,
    applied_at   timestamptz NOT NULL DEFAULT now(),
    detail       jsonb NOT NULL DEFAULT '{}'
);

DO $$
DECLARE
    v_key text := 'loandrift-expenses-lite-paid@20261108';
    n integer := 0;
BEGIN
    IF EXISTS (SELECT 1 FROM core_platform.cp_migration_decisions WHERE decision_key = v_key) THEN
        RAISE NOTICE 'loandrift expenses lite: existing expenses were already moved to PAID on this database';
        RETURN;
    END IF;
    UPDATE core_platform.cp_expenses_history
       SET status  = 'PAID',
           paid_at = coalesce(paid_at, cdatetime),
           paid_by = coalesce(paid_by, created_by)
     WHERE app = 'LOANDRIFT' AND status = 'APPROVED';
    GET DIAGNOSTICS n = ROW_COUNT;
    INSERT INTO core_platform.cp_migration_decisions (decision_key, detail)
    VALUES (v_key, jsonb_build_object('moved_to_paid', n));
    RAISE NOTICE 'loandrift expenses lite: % existing expense(s) moved from APPROVED to PAID', n;
END $$;

-- ===================================================================== 2. every deploy: APPROVED but already posted = PAID
DO $$
DECLARE n integer := 0;
BEGIN
    UPDATE core_platform.cp_expenses_history x
       SET status  = 'PAID',
           paid_at = coalesce(x.paid_at, x.cdatetime),
           paid_by = coalesce(x.paid_by, x.created_by)
     WHERE x.app = 'LOANDRIFT' AND x.status = 'APPROVED'
       AND EXISTS (SELECT 1 FROM loandrift.ld_journal_entries j
                    WHERE j.tenant_id = x.tenant_id AND j.source_type = 'EXPENSE' AND j.source_id = x.id
                      AND j.status = 'POSTED' AND j.reversal_of_entry_id IS NULL
                      AND j.delete_status = 'NOT_DELETED');
    GET DIAGNOSTICS n = ROW_COUNT;
    IF n > 0 THEN
        RAISE NOTICE 'loandrift expenses lite: % approved expense(s) already in the ledger marked PAID', n;
    END IF;
END $$;

-- ===================================================================== 4. plan feature
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('loandrift.expenses', 'app-loandrift', 'Expenses', 3,
 'Record expenses with one optional approval, mark them paid, void them. Existing records and the expense reports stay readable on any plan.')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

-- ===================================================================== 5. permissions
-- 20260928-09 / -11 refill cp_resources on every deploy: the line is declared again here, after them.
INSERT INTO core_platform.cp_resources (app_prefix, resource_key, resource_type_id, actions)
VALUES ('loandrift', 'expenses', 'rt-loandrift-expenses',
        ARRAY['approve', 'create', 'delete', 'get', 'get:activity-logs', 'pay', 'statistics', 'update'])
ON CONFLICT (app_prefix, resource_key) DO UPDATE SET resource_type_id = EXCLUDED.resource_type_id,
                                                     actions          = EXCLUDED.actions;

INSERT INTO core_platform.cp_permissions
       (id, permission_name, resource_type_id, description, app_prefix, resource_key, action, target, scope,
        cdate, ctime, cdatetime)
VALUES ('permission-loandrift-expenses-approve', 'Loandrift Expenses Approve', 'rt-loandrift-expenses',
        'Can approve or reject expenses (never their own)', 'loandrift', 'expenses', 'approve', '', 'any',
        CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP),
       ('permission-loandrift-expenses-pay', 'Loandrift Expenses Pay', 'rt-loandrift-expenses',
        'Can mark approved expenses as paid', 'loandrift', 'expenses', 'pay', '', 'any',
        CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET resource_type_id = EXCLUDED.resource_type_id,
                               app_prefix       = EXCLUDED.app_prefix,
                               resource_key     = EXCLUDED.resource_key,
                               action           = EXCLUDED.action,
                               target           = EXCLUDED.target,
                               scope            = EXCLUDED.scope;

-- Once: the roles that may already change expenses may now approve and pay them. Not on
-- every deploy, so a role an administrator later narrows stays narrowed.
DO $$
DECLARE
    v_key text := 'loandrift-expenses-lite-grants@20261108';
    n integer := 0;
BEGIN
    IF EXISTS (SELECT 1 FROM core_platform.cp_migration_decisions WHERE decision_key = v_key) THEN
        RETURN;
    END IF;
    INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
    SELECT DISTINCT rp.tenant_id, rp.role_id, np.id, np.description,
           CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
      FROM core_platform.cp_role_permissions rp
     CROSS JOIN (VALUES ('permission-loandrift-expenses-approve', 'Can approve or reject expenses (never their own)'),
                        ('permission-loandrift-expenses-pay', 'Can mark approved expenses as paid')) AS np(id, description)
     WHERE rp.permission_id = 'permission-loandrift-expenses-update'
       AND rp.delete_status = 'NOT_DELETED' AND rp.is_active
    ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;
    GET DIAGNOSTICS n = ROW_COUNT;
    INSERT INTO core_platform.cp_migration_decisions (decision_key, detail)
    VALUES (v_key, jsonb_build_object('grants_added', n));
    RAISE NOTICE 'loandrift expenses lite: % approve/pay grant(s) added', n;
END $$;

-- ===================================================================== checks (invariants)
DO $$
DECLARE bad text;
BEGIN
    SELECT string_agg(id, ', ') INTO bad
      FROM (VALUES ('permission-loandrift-expenses-approve', 'approve'), ('permission-loandrift-expenses-pay', 'pay')) AS v(id, action)
     WHERE NOT EXISTS (SELECT 1 FROM core_platform.cp_permissions p
                        WHERE p.id = v.id AND p.app_prefix = 'loandrift' AND p.resource_key = 'expenses' AND p.action = v.action);
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'loandrift expenses lite: permission(s) missing or mis-keyed: %', bad;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM core_platform.cp_app_feature_catalog
                    WHERE feature_key = 'loandrift.expenses' AND app_id = 'app-loandrift' AND min_tier_rank = 3 AND is_active) THEN
        RAISE EXCEPTION 'loandrift expenses lite: plan feature loandrift.expenses is not PREMIUM';
    END IF;
    IF position('paid_from' IN pg_get_functiondef('loandrift.ld_acc_sync_entry(text)'::regprocedure)) = 0 THEN
        RAISE EXCEPTION 'loandrift expenses lite: ld_acc_sync_entry does not carry paid_from';
    END IF;
    -- The invariant step 2 keeps: no APPROVED LoanDrift expense is in the ledger.
    SELECT string_agg(x.id, ', ') INTO bad
      FROM core_platform.cp_expenses_history x
     WHERE x.app = 'LOANDRIFT' AND x.status = 'APPROVED'
       AND EXISTS (SELECT 1 FROM loandrift.ld_journal_entries j
                    WHERE j.tenant_id = x.tenant_id AND j.source_type = 'EXPENSE' AND j.source_id = x.id
                      AND j.status = 'POSTED' AND j.reversal_of_entry_id IS NULL AND j.delete_status = 'NOT_DELETED');
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'loandrift expenses lite: approved expense(s) already in the ledger: %', bad;
    END IF;
END $$;

COMMIT;
