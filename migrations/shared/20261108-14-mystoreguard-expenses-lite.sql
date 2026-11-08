-- =====================================================================
-- MyStoreGuard expenses follow the Expenses lite standard (apps-setup/EXPENSES-LITE-STANDARD.md)
-- ---------------------------------------------------------------------
-- Owner, 2026-11-08: every app records expenses with ONE flow -- record, optionally one
-- approval, mark paid, void -- and the books are told when the money LEFT (PAID), not when an
-- expense was approved. 20261108-10 widened cp_expenses_history for that (SUBMITTED / APPROVED /
-- PAID / REJECTED / VOIDED, paid_from, payee, who/when columns) and left each app to move its
-- own rows and its own accounting trigger. This is MyStoreGuard's part:
--
--   1. Existing MyStoreGuard expenses become PAID (paid_at = when they were recorded). Until
--      now an MSG expense was money already spent: there was no unpaid state. ONCE only (a
--      marker row), because from now on APPROVED means "approved, not paid yet" and a re-run
--      on a later deploy must not pay those.
--   2. The accounting trigger (20261108-06) publishes msg.expense_recorded when a row is PAID
--      (was: APPROVED) and msg.expense_reversed when a published (paid) row is voided, deleted
--      or its figures change. Event kinds and payload keys are kept; the payload gains
--      paid_from, payee and paid_at. Accounting's MsgPostingRules reads amount, tax_amount,
--      category_id/name, account_code, description, document_number, date and currency, all
--      unchanged.
--   3. Step 1 publishes NOTHING: rows that existed when 20261108-06 first ran are BASELINE
--      (never published); rows published since keep their figures (the new keys are not
--      figures), and their stored payload is refreshed to the new shape here, so the deferred
--      trigger finds nothing changed at COMMIT. Checked at the end.
--   4. Plan: `mystoreguard.expenses` (Expenses lite), PREMIUM and above. The old `expenses` key
--      (ADVANCE) stays for the reports that read existing records.
--   5. Permissions: msg|expenses|approve (approve or reject) and msg|expenses|pay (mark paid),
--      given once to every role that may already change expenses (holds msg expenses update).
--      Void uses msg|expenses|delete (it replaces deleting a paid expense).
--
-- Idempotent; safe to re-run on every deploy.
-- =====================================================================
BEGIN;

-- ===================================================================== 2. the payload
CREATE OR REPLACE FUNCTION core_platform.cp_expense_acc_payload(e core_platform.cp_expenses_history)
RETURNS jsonb LANGUAGE sql STABLE AS $f$
    SELECT jsonb_build_object(
        'version', 1, 'app', 'mystoreguard',
        'id', e.id, 'tenant_id', e.tenant_id, 'org_id', e.org_id, 'bus_id', e.bus_id, 'loc_id', e.loc_id,
        'amount', core_platform.cp_expense_acc_money(coalesce(e.amount, 0)),
        'currency', coalesce(
            (SELECT upper(c.code) FROM core_platform.cp_currencies c
              WHERE c.tenant_id = e.tenant_id AND c.id = e.currency_id LIMIT 1),
            (SELECT upper(c.code) FROM core_platform.cp_currencies c
              WHERE c.tenant_id = e.tenant_id AND c.is_default AND c.delete_status = 'NOT_DELETED'
              ORDER BY c.cdatetime DESC NULLS LAST LIMIT 1),
            ''),
        'currency_id', e.currency_id,
        'category_id', e.category_id,
        'category_name', cat.name,
        'account_code', cat.account_code,
        'tax_rate_id', e.tax_rate_id,
        'tax_amount', CASE WHEN e.tax_amount IS NULL THEN NULL ELSE core_platform.cp_expense_acc_money(e.tax_amount) END,
        'supplier_id', e.supplier_id,
        'spent_on', coalesce(e.spent_on, e.cdatetime::date),
        'source', e.source,
        'reference', e.reference,
        'receipt_file_id', e.receipt_file_id,
        'description', coalesce(nullif(trim(e.used_for), ''), nullif(trim(e.description), '')),
        'paid_from', e.paid_from,
        'payee', e.payee,
        'paid_at', e.paid_at,
        'document_type', 'EXPENSE', 'document_id', e.id, 'document_number', coalesce(nullif(trim(e.reference), ''), e.id),
        'date', coalesce(e.spent_on, e.cdatetime::date))
      FROM (SELECT 1) one
      LEFT JOIN core_platform.cp_expense_categories cat ON cat.tenant_id = e.tenant_id AND cat.id = e.category_id
$f$;

-- Not figures: the note, the reference, who was paid and when / from where it was recorded as
-- paid (a paid expense cannot be edited, so paid_from never changes after posting). Leaving them
-- out is also what lets payloads published before this file compare equal to today's.
CREATE OR REPLACE FUNCTION core_platform.cp_expense_acc_figures(p jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE AS $f$
    SELECT p - ARRAY['version', 'description', 'reference', 'document_number', 'receipt_file_id',
                     'category_name', 'revision', 'reversal', 'paid_from', 'payee', 'paid_at']
$f$;

-- Live (counts in the books) = PAID, not deleted, active. Everything else as in 20261108-06.
CREATE OR REPLACE FUNCTION core_platform.cp_expense_acc_sync(p_tenant text, p_id text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
    e core_platform.cp_expenses_history;
    st core_platform.cp_expense_acc_state;
    live boolean := false;
    v_payload jsonb;
    v_revision integer;
BEGIN
    SELECT * INTO st FROM core_platform.cp_expense_acc_state WHERE tenant_id = p_tenant AND expense_id = p_id;
    IF FOUND AND st.kind = 'BASELINE' THEN RETURN; END IF;   -- history: never published

    SELECT * INTO e FROM core_platform.cp_expenses_history WHERE tenant_id = p_tenant AND id = p_id LIMIT 1;
    IF FOUND THEN
        live := e.app = 'MYSTOREGUARD' AND e.status = 'PAID'
                AND e.delete_status = 'NOT_DELETED' AND e.is_active;
    END IF;
    IF live THEN v_payload := core_platform.cp_expense_acc_payload(e); END IF;

    IF st.payload IS NOT NULL THEN
        IF live AND core_platform.cp_expense_acc_figures(st.payload) = core_platform.cp_expense_acc_figures(v_payload) THEN
            RETURN;   -- nothing the books care about changed
        END IF;
        PERFORM core_platform.cp_event_publish(p_tenant, st.bus_id, 'mystoreguard', 'msg.expense_reversed', p_id,
            st.payload || jsonb_build_object('reversal', true, 'revision', st.revision));
        UPDATE core_platform.cp_expense_acc_state SET payload = NULL, updated_at = now()
         WHERE tenant_id = p_tenant AND expense_id = p_id;
    END IF;

    IF live THEN
        v_revision := coalesce(st.revision, 0) + 1;
        v_payload := v_payload || jsonb_build_object('reversal', false, 'revision', v_revision);
        PERFORM core_platform.cp_event_publish(p_tenant, e.bus_id, 'mystoreguard', 'msg.expense_recorded', p_id, v_payload);
        INSERT INTO core_platform.cp_expense_acc_state (tenant_id, expense_id, bus_id, kind, revision, payload)
        VALUES (p_tenant, p_id, e.bus_id, 'PUBLISHED', v_revision, v_payload)
        ON CONFLICT (tenant_id, expense_id) DO UPDATE SET
            bus_id = EXCLUDED.bus_id, kind = 'PUBLISHED', revision = EXCLUDED.revision,
            payload = EXCLUDED.payload, updated_at = now();
    END IF;
END
$f$;

-- ===================================================================== 1 + 3. existing rows become PAID, once
DO $$
DECLARE n integer := 0;
BEGIN
    IF EXISTS (SELECT 1 FROM core_platform.cp_expense_acc_state WHERE tenant_id = '' AND expense_id = 'LITE-PAID-20261108') THEN
        RAISE NOTICE 'msg expenses lite: existing expenses were already moved to PAID on this database';
        RETURN;
    END IF;

    -- Any APPROVED one the trigger never tracked (written with it off) was never published:
    -- history, like the baseline.
    INSERT INTO core_platform.cp_expense_acc_state (tenant_id, expense_id, bus_id, kind)
    SELECT e.tenant_id, e.id, e.bus_id, 'BASELINE'
      FROM core_platform.cp_expenses_history e
     WHERE e.app = 'MYSTOREGUARD' AND e.status = 'APPROVED'
       AND NOT EXISTS (SELECT 1 FROM core_platform.cp_expense_acc_state st
                        WHERE st.tenant_id = e.tenant_id AND st.expense_id = e.id)
    ON CONFLICT DO NOTHING;

    UPDATE core_platform.cp_expenses_history
       SET status = 'PAID',
           paid_at = coalesce(paid_at, cdatetime),
           paid_by = coalesce(paid_by, created_by)
     WHERE app = 'MYSTOREGUARD' AND status = 'APPROVED';
    GET DIAGNOSTICS n = ROW_COUNT;

    -- Expenses published since 20261108-06: the stored payload takes the new shape (same
    -- figures), so the deferred trigger compares equal at COMMIT and publishes nothing.
    UPDATE core_platform.cp_expense_acc_state st
       SET payload = core_platform.cp_expense_acc_payload(e)
                     || jsonb_build_object('reversal', false, 'revision', st.revision),
           updated_at = now()
      FROM core_platform.cp_expenses_history e
     WHERE st.kind = 'PUBLISHED' AND st.payload IS NOT NULL
       AND e.tenant_id = st.tenant_id AND e.id = st.expense_id AND e.app = 'MYSTOREGUARD';

    INSERT INTO core_platform.cp_expense_acc_state (tenant_id, expense_id, bus_id, kind)
    VALUES ('', 'LITE-PAID-20261108', NULL, 'BASELINE')
    ON CONFLICT DO NOTHING;
    RAISE NOTICE 'msg expenses lite: % existing expense(s) moved from APPROVED to PAID', n;
END $$;

-- Fire the deferred trigger NOW, so the check below sees what it published.
SET CONSTRAINTS core_platform.cp_expense_acc_event IMMEDIATE;
SET CONSTRAINTS core_platform.cp_expense_acc_event DEFERRED;

-- Only THIS transaction's events (the app keeps publishing its own while this runs).
DO $$
DECLARE n integer;
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_events
     WHERE txid = pg_current_xact_id() AND (kind LIKE 'msg.expense_%' OR kind = 'msg.posting_error');
    IF n > 0 THEN
        RAISE EXCEPTION 'msg expenses lite: moving existing expenses to PAID published % accounting event(s); it must publish none', n;
    END IF;
END $$;

-- ===================================================================== event catalogue
DO $$
BEGIN
    IF to_regclass('core_platform.cp_event_schemas') IS NULL THEN
        RAISE NOTICE 'msg expenses lite: no cp_event_schemas here, nothing to register';
        RETURN;
    END IF;
    UPDATE core_platform.cp_event_schemas s
       SET schema = jsonb_set(s.schema, '{properties}',
                              (s.schema -> 'properties')
                              || jsonb_build_object(
                                   'paid_from', jsonb_build_object('type', jsonb_build_array('string', 'null'),
                                       'enum', jsonb_build_array('cash', 'bank', 'mobile_money', 'card', 'petty_cash', 'other', null)),
                                   'payee', jsonb_build_object('type', jsonb_build_array('string', 'null')),
                                   'paid_at', jsonb_build_object('type', jsonb_build_array('string', 'null')))),
           description = CASE s.kind
               WHEN 'msg.expense_recorded' THEN 'A MyStoreGuard expense PAID (money left the business): amount paid (tax inside), category and its account code, supplier or payee, date, paid from.'
               ELSE 'A published (paid) MyStoreGuard expense to take back out of the books: voided, deleted, or its figures changed (the new figures follow as msg.expense_recorded).'
           END,
           updated_at = now()
     WHERE s.kind IN ('msg.expense_recorded', 'msg.expense_reversed') AND s.version = 1
       AND (NOT (s.schema -> 'properties') ? 'paid_at'
            OR s.description NOT LIKE '%PAID%' AND s.kind = 'msg.expense_recorded'
            OR s.description NOT LIKE '%voided%' AND s.kind = 'msg.expense_reversed');
END
$$;

-- ===================================================================== 4. plan feature
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('mystoreguard.expenses', 'app-mystoreguard', 'Expenses', 3,
 'Record expenses with one optional approval, mark them paid, void them. Existing records stay readable on any plan.')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

-- ===================================================================== 5. permissions
-- 20260928-09 refills cp_resources on every deploy: the line is declared again here, after it.
INSERT INTO core_platform.cp_resources (app_prefix, resource_key, resource_type_id, actions)
VALUES ('msg', 'expenses', 'rt-msg-expenses', ARRAY['approve', 'create', 'delete', 'get', 'pay', 'statistics', 'update'])
ON CONFLICT (app_prefix, resource_key) DO UPDATE SET resource_type_id = EXCLUDED.resource_type_id,
                                                     actions          = EXCLUDED.actions;

INSERT INTO core_platform.cp_permissions
       (id, permission_name, resource_type_id, description, app_prefix, resource_key, action, target, scope,
        cdate, ctime, cdatetime)
VALUES ('permission-msg-expenses-approve', 'Mystoreguard Expenses Approve', 'rt-msg-expenses',
        'Can approve or reject expenses (never their own)', 'msg', 'expenses', 'approve', '', 'any',
        CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP),
       ('permission-msg-expenses-pay', 'Mystoreguard Expenses Pay', 'rt-msg-expenses',
        'Can mark approved expenses as paid', 'msg', 'expenses', 'pay', '', 'any',
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
DECLARE n integer := 0;
BEGIN
    IF EXISTS (SELECT 1 FROM core_platform.cp_expense_acc_state WHERE tenant_id = '' AND expense_id = 'LITE-GRANTS-20261108') THEN
        RETURN;
    END IF;
    INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
    SELECT DISTINCT rp.tenant_id, rp.role_id, np.id, np.description,
           CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
      FROM core_platform.cp_role_permissions rp
     CROSS JOIN (VALUES ('permission-msg-expenses-approve', 'Can approve or reject expenses (never their own)'),
                        ('permission-msg-expenses-pay', 'Can mark approved expenses as paid')) AS np(id, description)
     WHERE rp.permission_id = 'permission-msg-expenses-update'
       AND rp.delete_status = 'NOT_DELETED' AND rp.is_active
    ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;
    GET DIAGNOSTICS n = ROW_COUNT;
    INSERT INTO core_platform.cp_expense_acc_state (tenant_id, expense_id, bus_id, kind)
    VALUES ('', 'LITE-GRANTS-20261108', NULL, 'BASELINE')
    ON CONFLICT DO NOTHING;
    RAISE NOTICE 'msg expenses lite: % approve/pay grant(s) added', n;
END $$;

-- ===================================================================== checks (invariants)
DO $$
DECLARE bad text;
BEGIN
    SELECT string_agg(id, ', ') INTO bad
      FROM (VALUES ('permission-msg-expenses-approve', 'approve'), ('permission-msg-expenses-pay', 'pay')) AS v(id, action)
     WHERE NOT EXISTS (SELECT 1 FROM core_platform.cp_permissions p
                        WHERE p.id = v.id AND p.app_prefix = 'msg' AND p.resource_key = 'expenses' AND p.action = v.action);
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'msg expenses lite: permission(s) missing or mis-keyed: %', bad;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM core_platform.cp_app_feature_catalog
                    WHERE feature_key = 'mystoreguard.expenses' AND app_id = 'app-mystoreguard' AND min_tier_rank = 3 AND is_active) THEN
        RAISE EXCEPTION 'msg expenses lite: plan feature mystoreguard.expenses is not PREMIUM';
    END IF;
    IF position('''PAID''' IN pg_get_functiondef('core_platform.cp_expense_acc_sync(text,text)'::regprocedure)) = 0 THEN
        RAISE EXCEPTION 'msg expenses lite: the accounting sync does not post at PAID';
    END IF;
END $$;

COMMIT;
