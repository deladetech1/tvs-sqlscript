-- =====================================================================
-- HMS and CloudHams expenses follow the Expenses lite standard (apps-setup/EXPENSES-LITE-STANDARD.md)
-- ---------------------------------------------------------------------
-- Owner, 2026-11-08: every app records expenses with ONE flow -- record, optionally one
-- approval (Core's cp_expense_settings), mark paid, void with a reason -- and the books are told
-- when the money LEFT (PAID), not when an expense was approved. MyStoreGuard did its part in
-- 20261108-14; this is HMS's and CloudHams'.
--
-- HMS (hms.hms_expenses; the API is tvs-shared-apps-bk internal/apps/hms/expenses.go):
--   1. Status gains 'paid'. Stored values stay lowercase: pending (= SUBMITTED, awaiting the
--      one approval), approved (= APPROVED, not paid yet), paid, rejected; voided_at set =
--      VOIDED (the status is kept, so a void knows whether money had gone).
--   2. New columns: paid_at, paid_by, payment_reference, voided_by, payee (free text when there
--      is no Core supplier).
--   3. Existing 'approved' expenses become 'paid' (paid_at = when they were approved, else
--      recorded; paid_by = who approved). HMS had no separate pay step: an approved expense
--      was money already spent, counted in the P&L, the drawer and the transactions list.
--      ONCE only -- it runs in the deploy that adds paid_at -- because from now on 'approved'
--      means "approved, not paid yet" and a re-run must not pay those. Publishes nothing:
--      events are written by the API, never by a trigger, and Accounting already heard of these
--      as hms_expense.approved.
--
-- CloudHams (hospital.hospital_entries kind 'expense'; internal/apps/hospital/expenses_lite.go):
--   4. Status gains 'voided' (status is free text there; the kind's list is in the API).
--   5. 'draft' is not part of lite. Each existing draft becomes 'submitted' when its business
--      has approval on (Core: the business's row, else the organisation's, else off), else
--      'approved' (approval off: a new expense is APPROVED at once). Not 'paid': nobody has
--      said the money went. A history row says why. Re-runnable: only drafts move, and a
--      draft made later through the old records route moves the same way.
--
-- Accounting (core_platform.cp_event_schemas, links 'hms-accounting' / 'hospital-accounting'):
--   6. hms_expense.paid (new): the keys of hms_expense.approved plus paid_at and
--      payment_reference; date = the day it was paid.
--      hms_expense.voided (replaces 20261108-09's row, which this file now outranks on every
--      deploy): ONLY a paid expense voided; the same keys as hms_expense.paid plus reason and
--      voided_at; date = the day it was voided.
--      hms_expense.approved stays registered (20261108-09; events already published) but is no
--      longer sent.
--      hospital_expense.voided (new): a PAID CloudHams expense voided; the keys of
--      hospital_expense.paid plus reason and voided_at; date = the day it was voided.
--
-- Plan:
--   7. hms.expenses and hospital.expenses are PREMIUM and above (ENTERPRISE has every
--      feature). Existing records stay readable on every plan; the API refuses writes below.
--      The older files (20261023-62, 20261107-08) still insert them at rank 1 on every deploy;
--      this later file sets the rank after them.
--
-- Idempotent; safe to re-run on every deploy.
-- =====================================================================
BEGIN;

-- ===================================================================== HMS
DO $$
DECLARE
    first_run boolean;
    n int;
BEGIN
    IF to_regclass('hms.hms_expenses') IS NULL THEN
        RAISE NOTICE 'hms expenses lite: no HMS here, nothing to do';
        RETURN;
    END IF;
    first_run := NOT EXISTS (SELECT 1 FROM information_schema.columns
                              WHERE table_schema = 'hms' AND table_name = 'hms_expenses' AND column_name = 'paid_at');

    ALTER TABLE hms.hms_expenses ADD COLUMN IF NOT EXISTS paid_at           timestamptz;
    ALTER TABLE hms.hms_expenses ADD COLUMN IF NOT EXISTS paid_by           text;
    ALTER TABLE hms.hms_expenses ADD COLUMN IF NOT EXISTS payment_reference text;
    ALTER TABLE hms.hms_expenses ADD COLUMN IF NOT EXISTS voided_by         text;
    ALTER TABLE hms.hms_expenses ADD COLUMN IF NOT EXISTS payee             text;

    ALTER TABLE hms.hms_expenses DROP CONSTRAINT IF EXISTS hms_expenses_status_check;
    ALTER TABLE hms.hms_expenses ADD CONSTRAINT hms_expenses_status_check
        CHECK (status IN ('pending', 'approved', 'paid', 'rejected'));

    IF first_run THEN
        UPDATE hms.hms_expenses
           SET status = 'paid', paid_at = coalesce(decided_at, cdatetime), paid_by = decided_by
         WHERE status = 'approved';
        GET DIAGNOSTICS n = ROW_COUNT;
        RAISE NOTICE 'hms expenses lite: % approved expense(s) marked paid (once)', n;
    END IF;

    CREATE INDEX IF NOT EXISTS hms_expenses_status_idx ON hms.hms_expenses (bus_id, status);
END
$$;

-- ===================================================================== CloudHams
DO $$
DECLARE
    n int;
BEGIN
    IF to_regclass('hospital.hospital_entries') IS NULL OR to_regclass('hospital.hospital_entry_events') IS NULL THEN
        RAISE NOTICE 'cloudhams expenses lite: no CloudHams here, nothing to do';
        RETURN;
    END IF;

    WITH moved AS (
        UPDATE hospital.hospital_entries x
           SET status = CASE WHEN coalesce((
                       SELECT s.approval_required FROM core_platform.cp_expense_settings s
                        WHERE s.tenant_id = x.tenant_id AND (s.bus_id IS NULL OR s.bus_id = x.bus_id)
                        ORDER BY (s.bus_id IS NULL) LIMIT 1), false)
                       THEN 'submitted' ELSE 'approved' END,
               updated_at = now()
         WHERE x.kind = 'expense' AND x.status = 'draft'
        RETURNING x.id, x.status
    )
    INSERT INTO hospital.hospital_entry_events (entry_id, from_status, to_status, note)
    SELECT id, 'draft', status,
           CASE WHEN status = 'submitted' THEN 'Expenses lite: drafts are gone; sent for approval (the business has approval on)'
                ELSE 'Expenses lite: drafts are gone; approved, not paid yet (the business has approval off)' END
      FROM moved;
    GET DIAGNOSTICS n = ROW_COUNT;
    IF n > 0 THEN
        RAISE NOTICE 'cloudhams expenses lite: % draft expense(s) moved on', n;
    END IF;
END
$$;

-- ===================================================================== plan
DO $$
BEGIN
    IF to_regclass('core_platform.cp_app_feature_catalog') IS NULL THEN
        RETURN;
    END IF;
    INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
    ('hms.expenses',      'app-hms',      'Expenses', 3, 'Record expenses, one optional approval, mark paid, void; posted to Accounting when paid'),
    ('hospital.expenses', 'app-hospital', 'Expenses', 3, 'Record expenses, one optional approval, mark paid, void; posted to Accounting when paid')
    ON CONFLICT (feature_key) DO UPDATE SET app_id = EXCLUDED.app_id, title = EXCLUDED.title,
        min_tier_rank = EXCLUDED.min_tier_rank, description = EXCLUDED.description, is_active = true;
END
$$;

-- ===================================================================== events
DO $$
DECLARE
    money   jsonb := jsonb_build_object('type', 'string', 'pattern', '^[0-9]+\.[0-9]{2}$');
    money_n jsonb := jsonb_build_object('type', jsonb_build_array('string', 'null'), 'pattern', '^[0-9]+\.[0-9]{2}$');
    str     jsonb := jsonb_build_object('type', 'string');
    str_n   jsonb := jsonb_build_object('type', jsonb_build_array('string', 'null'));
    day     jsonb := jsonb_build_object('type', 'string', 'format', 'date');
    ts      jsonb := jsonb_build_object('type', 'string', 'format', 'date-time');
    hms_paid jsonb;
    hms_req  jsonb := jsonb_build_array('id', 'amount', 'currency', 'spent_on', 'date', 'paid_from', 'core_category_id',
                                        'account_code', 'tax_rate_id', 'tax_amount', 'paid_at');
    hosp_paid jsonb;
    hosp_req  jsonb := jsonb_build_array('id', 'tenant_id', 'bus_id', 'facility_id', 'amount', 'currency', 'spent_on', 'paid_on', 'date',
                                         'core_category_id', 'category', 'account_code', 'tax_rate_id', 'tax_amount', 'method');
BEGIN
    IF to_regclass('core_platform.cp_event_schemas') IS NULL THEN
        RAISE NOTICE 'hms/cloudhams expenses lite: no cp_event_schemas here, nothing to register';
        RETURN;
    END IF;

    hms_paid := jsonb_build_object(
        'id', str, 'amount', money, 'currency', str, 'spent_on', day, 'date', day,
        'org_id', str_n, 'document_type', jsonb_build_object('type', 'string', 'const', 'EXPENSE'),
        'document_id', str, 'document_number', str,
        'core_category_id', str_n, 'account_code', str_n, 'tax_rate_id', str_n, 'tax_amount', money_n,
        'category', str, 'department', str, 'description', str, 'reference', str,
        'paid_from', jsonb_build_object('type', 'string',
            'enum', jsonb_build_array('cash', 'petty_cash', 'bank', 'momo', 'card', 'cheque', 'owner', 'other')),
        'supplier_id', str, 'property_id', str,
        'paid_at', ts, 'payment_reference', str_n);

    -- The same keys hospital_expense.paid has had since 20261108-09.
    hosp_paid := jsonb_build_object(
        'version', jsonb_build_object('type', 'integer', 'const', 1), 'app', jsonb_build_object('type', 'string', 'const', 'hospital'),
        'id', str, 'tenant_id', str, 'org_id', str_n, 'bus_id', str, 'facility_id', str, 'loc_id', str_n, 'number', str,
        'amount', money, 'currency', str, 'spent_on', day, 'paid_on', day, 'date', day,
        'core_category_id', str_n, 'category', str_n, 'account_code', str_n, 'tax_rate_id', str_n, 'tax_amount', money_n,
        'supplier_id', str_n, 'payee', str_n, 'reference', str_n, 'description', str_n,
        'method', jsonb_build_object('type', 'string', 'enum', jsonb_build_array('payout', 'manual')),
        'payment_method', str_n, 'payout_id', str_n, 'payout_reference', str_n, 'manual_reference', str_n,
        'document_type', jsonb_build_object('type', 'string', 'const', 'EXPENSE'), 'document_id', str, 'document_number', str);

    INSERT INTO core_platform.cp_event_schemas (kind, version, link_key, source_app, target_app, phase, description, schema, updated_at)
    SELECT k.kind, 1, k.link_key, k.source_app, 'app-accounting', 1, k.description,
           jsonb_build_object('$schema', 'https://json-schema.org/draft/2020-12/schema', 'title', k.kind || ' v1',
                              'type', 'object', 'required', k.required, 'properties', k.properties),
           now()
      FROM (VALUES
        ('hms_expense.paid', 'hms-accounting', 'app-hms',
         'An HMS expense paid (the money left): amount paid (tax inside), Core category and its account code, department, where the money came from; date = the day it was paid.',
         hms_req, hms_paid),
        ('hms_expense.voided', 'hms-accounting', 'app-hms',
         'A PAID HMS expense voided: take it back out of the books. The same figures as its hms_expense.paid, the reason, and date = the day it was voided.',
         hms_req || jsonb_build_array('reason', 'voided_at'),
         hms_paid || jsonb_build_object('reason', str, 'voided_at', ts)),
        ('hospital_expense.voided', 'hospital-accounting', 'app-hospital',
         'A PAID CloudHams expense voided: take it back out of the books. The same figures as its hospital_expense.paid, the reason, and date = the day it was voided.',
         hosp_req || jsonb_build_array('reason', 'voided_at'),
         hosp_paid || jsonb_build_object('reason', str, 'voided_at', ts))
      ) AS k(kind, link_key, source_app, description, required, properties)
    ON CONFLICT (kind, version) DO UPDATE SET
        link_key = EXCLUDED.link_key, source_app = EXCLUDED.source_app, target_app = EXCLUDED.target_app,
        phase = EXCLUDED.phase, description = EXCLUDED.description, schema = EXCLUDED.schema,
        updated_at = CASE WHEN core_platform.cp_event_schemas.schema IS DISTINCT FROM EXCLUDED.schema
                            OR core_platform.cp_event_schemas.description IS DISTINCT FROM EXCLUDED.description
                          THEN now() ELSE core_platform.cp_event_schemas.updated_at END;

END
$$;

COMMIT;
