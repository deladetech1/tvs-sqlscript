-- Core Platform workflows: more triggers from ZelosHR and Accounting (tvs-coreplatform-bk
-- docs/workflows/DESIGN.md, slice 2 follow-on). Plain versioned payloads ({"v": 1, ...}) in
-- core_platform.cp_events, catalogued with link_key 'suite-events' and target 'app-coreplatform', as
-- 20261110-11. Nobody's inbox takes these; the workflow designer reads them.
--
-- 1. ZELOSHR, DATE-BASED (published by ZelosHR's DateEventsWorker, hourly, each tenant on its own
--    clock, ONCE per record per date: the worker looks for the same kind, record and date first):
--      zeloshr.contract_ending     a contract ends within 30 days (told once per end date)
--      zeloshr.probation_ending    someone on probation finishes it within 14 days
--      zeloshr.birthday            on the day; never the year or an age
--      zeloshr.work_anniversary    on the day, with the years served (1 or more)
--      zeloshr.document_expiring   an uploaded document, an identification or the record's own ID
--                                  expires within 30 days; never the document's number
--    No pay, bank or tax details, no date of birth.
--
-- 2. ACCOUNTING, from the books themselves. Deferred constraint triggers on Accounting's tables
--    (fired at COMMIT, so a journal's lines are in and a rolled-back change publishes nothing),
--    because Accounting posts journals from some twenty places (manual journals, invoices, bills,
--    payments, receipts, imports, revaluations, depreciation, year end, the postings worker) and a
--    choke point in C# would have to be remembered by every one written from now on:
--      accounting.journal_posted       a journal reached POSTED (once per journal): number, date,
--                                      memo, source, total debits in base currency + currency
--      accounting.period_closed        a fiscal period left OPEN (CLOSED or LOCKED)
--      accounting.reconciliation_done  a bank account's reconciliation was completed (signed off);
--                                      never the account number
--      accounting.posting_failed       an event from another app could not be posted (the posting
--                                      inbox row became FAILED; told again only after it recovered)
--    FAIL OPEN: each trigger catches its own errors (a missing event log, a bug) and lets the books'
--    change commit; a WARNING is logged.
--    Published by Accounting's PlanningWorker, once per document per due date, for documents that
--    fell due in the last 7 days (an old backlog is not replayed at the first pass):
--      accounting.invoice_overdue / accounting.bill_overdue   approved, past due, still owing
--    Amounts are business figures, always with their currency.
--
-- Idempotent; re-runs on every deploy. This file owns the catalogue rows of the kinds it names.
-- Guarded: a database without Accounting (or ZelosHR) gets the catalogue rows and nothing else.

BEGIN;

-- ===================================================================== catalogue
DO $$
BEGIN
    IF to_regclass('core_platform.cp_event_schemas') IS NULL THEN
        RETURN;
    END IF;

    WITH person AS (
        SELECT '{"v":{"type":"integer","minimum":1},"employee_id":{"type":"string"},"employee_name":{"type":"string"},
                 "job_title":{"type":"string"},"department_name":{"type":"string"}}'::jsonb AS p
    ), invoice AS (
        SELECT '{"v":{"type":"integer","minimum":1},"number":{"type":"string"},"issue_date":{"type":"string","format":"date"},
                 "due_date":{"type":"string","format":"date"},"days_overdue":{"type":"integer"},"total":{"type":"number"},
                 "balance":{"type":"number"},"currency":{"type":"string"},"source_type":{"type":"string"}}'::jsonb AS p
    ), kinds (kind, source_app, description, props, required) AS (
        SELECT 'zeloshr.contract_ending', 'app-zeloshr', 'A contract ends within 30 days (told once per end date).',
               (SELECT p FROM person) || '{"end_date":{"type":"string","format":"date"},"days_left":{"type":"integer"}}'::jsonb,
               '["v","employee_id","end_date"]'::jsonb
        UNION ALL SELECT 'zeloshr.probation_ending', 'app-zeloshr', 'Someone on probation finishes it within 14 days.',
               (SELECT p FROM person) || '{"end_date":{"type":"string","format":"date"},"days_left":{"type":"integer"}}'::jsonb,
               '["v","employee_id","end_date"]'::jsonb
        UNION ALL SELECT 'zeloshr.birthday', 'app-zeloshr', 'It is an employee''s birthday (no year or age).',
               (SELECT p FROM person) || '{"date":{"type":"string","format":"date"}}'::jsonb,
               '["v","employee_id","date"]'::jsonb
        UNION ALL SELECT 'zeloshr.work_anniversary', 'app-zeloshr', 'An employee''s work anniversary (one year or more).',
               (SELECT p FROM person) || '{"date":{"type":"string","format":"date"},"years":{"type":"integer","minimum":1}}'::jsonb,
               '["v","employee_id","date","years"]'::jsonb
        UNION ALL SELECT 'zeloshr.document_expiring', 'app-zeloshr', 'An employee''s ID, permit or document expires within 30 days.',
               '{"v":{"type":"integer","minimum":1},"employee_id":{"type":"string"},"employee_name":{"type":"string"},
                 "document_kind":{"enum":["document","identification"]},"document_name":{"type":"string"},
                 "expires_on":{"type":"string","format":"date"},"days_left":{"type":"integer"}}'::jsonb,
               '["v","employee_id","expires_on"]'::jsonb
        UNION ALL SELECT 'accounting.journal_posted', 'app-accounting', 'A journal was posted in the books.',
               '{"v":{"type":"integer","minimum":1},"journal_id":{"type":"string"},"number":{"type":"string"},
                 "date":{"type":"string","format":"date"},"memo":{"type":"string"},"reference":{"type":"string"},
                 "source_type":{"type":"string"},"source_reference":{"type":"string"},"is_reversal":{"type":"boolean"},
                 "total":{"type":"number"},"currency":{"type":"string"},"posted_by":{"type":"string"}}'::jsonb,
               '["v","journal_id","number","total","currency"]'::jsonb
        UNION ALL SELECT 'accounting.period_closed', 'app-accounting', 'A fiscal period was closed or locked.',
               '{"v":{"type":"integer","minimum":1},"period_id":{"type":"string"},"name":{"type":"string"},
                 "start_date":{"type":"string","format":"date"},"end_date":{"type":"string","format":"date"},
                 "fiscal_year":{"type":"integer"},"status":{"enum":["CLOSED","LOCKED"]},"closed_by":{"type":"string"}}'::jsonb,
               '["v","period_id","status"]'::jsonb
        UNION ALL SELECT 'accounting.reconciliation_done', 'app-accounting', 'A bank reconciliation was completed.',
               '{"v":{"type":"integer","minimum":1},"bank_account_id":{"type":"string"},"bank_account_name":{"type":"string"},
                 "statement_balance":{"type":"number"},"statement_date":{"type":"string","format":"date"},
                 "currency":{"type":"string"},"lines_signed":{"type":"integer"},"reconciled_by":{"type":"string"}}'::jsonb,
               '["v","bank_account_id","statement_date","currency"]'::jsonb
        UNION ALL SELECT 'accounting.posting_failed', 'app-accounting', 'Another app''s event could not be posted to the books.',
               '{"v":{"type":"integer","minimum":1},"inbox_id":{"type":"string"},"source_app":{"type":"string"},
                 "source_kind":{"type":"string"},"document_number":{"type":"string"},"document_date":{"type":"string","format":"date"},
                 "amount":{"type":"number"},"currency":{"type":"string"},"reason":{"type":"string"},"attempts":{"type":"integer"}}'::jsonb,
               '["v","inbox_id","source_app","source_kind"]'::jsonb
        UNION ALL SELECT 'accounting.invoice_overdue', 'app-accounting', 'An invoice in the books passed its due date unpaid (once per due date).',
               (SELECT p FROM invoice) || '{"invoice_id":{"type":"string"},"customer_name":{"type":"string"}}'::jsonb,
               '["v","invoice_id","number","due_date","balance","currency"]'::jsonb
        UNION ALL SELECT 'accounting.bill_overdue', 'app-accounting', 'A bill in the books passed its due date unpaid (once per due date).',
               (SELECT p FROM invoice) || '{"bill_id":{"type":"string"},"supplier_name":{"type":"string"},
                                            "supplier_reference":{"type":"string"}}'::jsonb,
               '["v","bill_id","number","due_date","balance","currency"]'::jsonb
    )
    INSERT INTO core_platform.cp_event_schemas (kind, version, link_key, source_app, target_app, phase, description, schema, updated_at)
    SELECT k.kind, 1, 'suite-events', k.source_app, 'app-coreplatform', 1, k.description,
           jsonb_build_object('$schema', 'https://json-schema.org/draft/2020-12/schema', 'type', 'object',
                              'title', k.kind || ' v1', 'required', k.required, 'properties', k.props), now()
      FROM kinds k
    ON CONFLICT (kind, version) DO UPDATE SET
        link_key = EXCLUDED.link_key, source_app = EXCLUDED.source_app, target_app = EXCLUDED.target_app,
        phase = EXCLUDED.phase, description = EXCLUDED.description, schema = EXCLUDED.schema,
        updated_at = CASE WHEN core_platform.cp_event_schemas.schema IS DISTINCT FROM EXCLUDED.schema
                            OR core_platform.cp_event_schemas.description IS DISTINCT FROM EXCLUDED.description
                          THEN now() ELSE core_platform.cp_event_schemas.updated_at END;
END $$;

-- ===================================================================== Accounting's triggers
DO $do$
BEGIN
    IF to_regclass('accounting.acc_journal_entries') IS NULL THEN
        RAISE NOTICE 'workflows-zeloshr-accounting: no Accounting here, no triggers';
        RETURN;
    END IF;

    -- A journal reached POSTED. Fired at commit for the insert and for each status change, so the
    -- row is read as it stands and a journal is told once however many times it was touched.
    EXECUTE $fn$
    CREATE OR REPLACE FUNCTION accounting.acc_wf_journal_event() RETURNS trigger
    LANGUAGE plpgsql AS $f$
    DECLARE j record; total numeric; cur text;
    BEGIN
        BEGIN
            SELECT * INTO j FROM accounting.acc_journal_entries WHERE id = NEW.id;
            IF NOT FOUND OR j.status <> 'POSTED' THEN
                RETURN NULL;
            END IF;
            IF EXISTS (SELECT 1 FROM core_platform.cp_events e
                        WHERE e.tenant_id = j.tenant_id AND e.bus_id = j.bus_id
                          AND e.kind = 'accounting.journal_posted' AND e.subject_id = j.id) THEN
                RETURN NULL;
            END IF;
            SELECT round(coalesce(sum(l.debit), 0), 2) INTO total FROM accounting.acc_journal_lines l WHERE l.journal_id = j.id;
            SELECT nullif(btrim(o.base_currency), '') INTO cur FROM accounting.acc_org_settings o
             WHERE o.tenant_id = j.tenant_id AND o.org_id = j.org_id AND o.bus_id = j.bus_id;
            PERFORM core_platform.cp_event_publish(j.tenant_id, j.bus_id, 'app-accounting', 'accounting.journal_posted', j.id,
                jsonb_build_object('v', 1, 'journal_id', j.id, 'number', j.number, 'date', j.date::text,
                    'memo', coalesce(j.memo, ''), 'reference', coalesce(j.reference, ''),
                    'source_type', coalesce(j.source_type, ''), 'source_reference', coalesce(j.source_reference, ''),
                    'is_reversal', j.reversal_of_id IS NOT NULL, 'total', total, 'currency', coalesce(cur, ''),
                    'posted_by', coalesce(j.posted_by_id, '')));
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'accounting.journal_posted not published for %: % (the journal stands)', NEW.id, SQLERRM;
        END;
        RETURN NULL;
    END $f$
    $fn$;

    EXECUTE $fn$
    CREATE OR REPLACE FUNCTION accounting.acc_wf_period_event() RETURNS trigger
    LANGUAGE plpgsql AS $f$
    BEGIN
        IF OLD.status IS NOT DISTINCT FROM NEW.status OR OLD.status <> 'OPEN' OR NEW.status NOT IN ('CLOSED', 'LOCKED') THEN
            RETURN NULL;
        END IF;
        BEGIN
            PERFORM core_platform.cp_event_publish(NEW.tenant_id, NEW.bus_id, 'app-accounting', 'accounting.period_closed', NEW.id,
                jsonb_build_object('v', 1, 'period_id', NEW.id, 'name', NEW.name, 'start_date', NEW.start_date::text,
                    'end_date', NEW.end_date::text, 'fiscal_year', NEW.fiscal_year, 'status', NEW.status,
                    'closed_by', coalesce(NEW.locked_by_id, NEW.updated_by_id, '')));
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'accounting.period_closed not published for %: % (the period stands)', NEW.id, SQLERRM;
        END;
        RETURN NULL;
    END $f$
    $fn$;

    -- Completing a reconciliation stamps last_reconciled_at; undoing one moves it back (never told).
    EXECUTE $fn$
    CREATE OR REPLACE FUNCTION accounting.acc_wf_reconciliation_event() RETURNS trigger
    LANGUAGE plpgsql AS $f$
    DECLARE signed integer;
    BEGIN
        IF NEW.last_reconciled_at IS NULL
           OR (OLD.last_reconciled_at IS NOT NULL AND NEW.last_reconciled_at <= OLD.last_reconciled_at) THEN
            RETURN NULL;
        END IF;
        BEGIN
            SELECT count(*) INTO signed FROM accounting.acc_bank_statement_lines l
             WHERE l.bank_account_id = NEW.id AND l.reconciled_at = NEW.last_reconciled_at;
            PERFORM core_platform.cp_event_publish(NEW.tenant_id, NEW.bus_id, 'app-accounting', 'accounting.reconciliation_done', NEW.id,
                jsonb_build_object('v', 1, 'bank_account_id', NEW.id, 'bank_account_name', NEW.name,
                    'statement_balance', NEW.statement_balance, 'statement_date', NEW.statement_date::text,
                    'currency', coalesce(NEW.currency, ''), 'lines_signed', signed,
                    'reconciled_by', coalesce(NEW.updated_by_id, '')));
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'accounting.reconciliation_done not published for %: % (the reconciliation stands)', NEW.id, SQLERRM;
        END;
        RETURN NULL;
    END $f$
    $fn$;

    -- An inbox row became FAILED (a retry that fails again stays FAILED and is not told again).
    EXECUTE $fn$
    CREATE OR REPLACE FUNCTION accounting.acc_wf_posting_failed_event() RETURNS trigger
    LANGUAGE plpgsql AS $f$
    BEGIN
        IF NEW.status <> 'FAILED' OR (TG_OP = 'UPDATE' AND OLD.status = 'FAILED') THEN
            RETURN NULL;
        END IF;
        BEGIN
            PERFORM core_platform.cp_event_publish(NEW.tenant_id, NEW.bus_id, 'app-accounting', 'accounting.posting_failed', NEW.id,
                jsonb_build_object('v', 1, 'inbox_id', NEW.id, 'source_app', NEW.source_app, 'source_kind', NEW.kind,
                    'document_number', coalesce(NEW.document_number, ''), 'document_date', coalesce(NEW.document_date::text, ''),
                    'amount', NEW.amount, 'currency', coalesce(NEW.currency, ''), 'reason', left(coalesce(NEW.reason, ''), 500),
                    'attempts', NEW.attempts));
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'accounting.posting_failed not published for %: %', NEW.id, SQLERRM;
        END;
        RETURN NULL;
    END $f$
    $fn$;

    DROP TRIGGER IF EXISTS acc_wf_journal_event ON accounting.acc_journal_entries;
    CREATE CONSTRAINT TRIGGER acc_wf_journal_event AFTER INSERT OR UPDATE OF status ON accounting.acc_journal_entries
        DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION accounting.acc_wf_journal_event();

    IF to_regclass('accounting.acc_fiscal_periods') IS NOT NULL THEN
        DROP TRIGGER IF EXISTS acc_wf_period_event ON accounting.acc_fiscal_periods;
        CREATE TRIGGER acc_wf_period_event AFTER UPDATE OF status ON accounting.acc_fiscal_periods
            FOR EACH ROW EXECUTE FUNCTION accounting.acc_wf_period_event();
    END IF;
    IF to_regclass('accounting.acc_bank_accounts') IS NOT NULL THEN
        DROP TRIGGER IF EXISTS acc_wf_reconciliation_event ON accounting.acc_bank_accounts;
        CREATE TRIGGER acc_wf_reconciliation_event AFTER UPDATE OF last_reconciled_at ON accounting.acc_bank_accounts
            FOR EACH ROW EXECUTE FUNCTION accounting.acc_wf_reconciliation_event();
    END IF;
    IF to_regclass('accounting.acc_posting_inbox') IS NOT NULL THEN
        DROP TRIGGER IF EXISTS acc_wf_posting_failed_event ON accounting.acc_posting_inbox;
        CREATE TRIGGER acc_wf_posting_failed_event AFTER INSERT OR UPDATE OF status ON accounting.acc_posting_inbox
            FOR EACH ROW EXECUTE FUNCTION accounting.acc_wf_posting_failed_event();
    END IF;
END $do$;

-- ===================================================================== invariants, not counts
DO $$
DECLARE bad text;
BEGIN
    IF to_regclass('core_platform.cp_event_schemas') IS NOT NULL THEN
        SELECT string_agg(kind || ' v' || version, ', ') INTO bad FROM core_platform.cp_event_schemas
         WHERE link_key = 'suite-events' AND source_app IN ('app-zeloshr', 'app-accounting')
           AND (split_part(kind, '.', 1) <> CASE source_app WHEN 'app-zeloshr' THEN 'zeloshr' ELSE 'accounting' END
                OR NOT (schema -> 'required') @> '["v"]'::jsonb);
        IF bad IS NOT NULL THEN
            RAISE EXCEPTION 'workflows-zeloshr-accounting: rows whose prefix does not name the sender, or not versioned: %', bad;
        END IF;
        -- Never pay, bank or tax details in a workflow event.
        SELECT string_agg(kind, ', ') INTO bad FROM core_platform.cp_event_schemas
         WHERE link_key = 'suite-events' AND source_app IN ('app-zeloshr', 'app-accounting')
           AND EXISTS (SELECT 1 FROM jsonb_object_keys(schema -> 'properties') k
                        WHERE k ~ '^(salary|gross_salary|net_salary|net_pay|bank_name|bank_account_number|account_number|iban|tin|tax_id|ssnit_number|date_of_birth|id_number)$');
        IF bad IS NOT NULL THEN
            RAISE EXCEPTION 'workflows-zeloshr-accounting: a lifecycle event carries pay, bank, tax or identity details: %', bad;
        END IF;
    END IF;
END $$;

COMMIT;
