-- =====================================================================
-- MyStoreGuard expenses tell the books what happened: msg.expense_recorded / msg.expense_reversed
-- ---------------------------------------------------------------------
-- MyStoreGuard records its expenses in core_platform.cp_expenses_history (app = 'MYSTOREGUARD'),
-- which since 20261108-04 carries Core Platform's expense pattern: a category (with its
-- accounting code), the day the money went out, the tax inside the amount, the supplier and a
-- receipt. This publishes each APPROVED MyStoreGuard expense to core_platform.cp_events IN THE
-- SAME TRANSACTION as the expense, so Accounting (reader 'accounting') can post it later.
-- Accounting does not read these kinds yet; publishing alone changes nothing for anyone.
--
-- Events (subject = the expense id; amounts are strings with 2 decimals):
--   msg.expense_recorded   an APPROVED, not-deleted MyStoreGuard expense, or one whose figures
--                          changed (a change is a msg.expense_reversed of the old figures, then
--                          a msg.expense_recorded of the new: 'revision' counts them)
--   msg.expense_reversed   a published expense deleted (DELETE, or delete_status leaving
--                          NOT_DELETED), deactivated, no longer APPROVED, or changed
--   msg.posting_error      an expense this could not describe (fail open, loudly)
-- Payload: id, tenant_id, org_id, bus_id, loc_id, amount, currency (code), currency_id,
--   category_id, category_name, account_code, tax_rate_id, tax_amount, supplier_id, spent_on,
--   source (the funding kind: ALLOCATED came out of the Core budget), reference,
--   receipt_file_id, description, revision, reversal. `amount` is what was PAID; the tax is
--   inside it (net = amount - tax_amount).
--
-- WHY DEFERRED (fired at COMMIT): MyStoreGuard writes the expense and may edit it again in the
-- same transaction; at commit the trigger reads the row as it finally stands and compares it
-- with what was last published (core_platform.cp_expense_acc_state), so only the difference is
-- published, and a write that rolls back publishes nothing. The state lives in core_platform
-- (not mystoreguard) because the table it watches is Core's and every database has that schema.
--
-- Fail open, loudly: if describing an expense raises, the expense still commits and a
-- 'msg.posting_error' event names it and the error (a trigger bug must never stop an expense).
-- Other apps' rows (LoanDrift publishes its own ledger) are ignored at the top of the trigger.
--
-- Starts from now: MyStoreGuard expenses that exist when this first runs are BASELINE and
-- publish nothing, ever (history belongs in the books' opening balances).
-- Re-runs every deploy: idempotent.
-- =====================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS core_platform.cp_expense_acc_state (
    tenant_id   text NOT NULL,
    expense_id  text NOT NULL,
    bus_id      text,
    -- BASELINE (existed before this ran: never published) or PUBLISHED.
    kind        text NOT NULL,
    revision    integer NOT NULL DEFAULT 0,
    -- What was last published while the expense counts in the books; NULL once reversed.
    payload     jsonb,
    updated_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, expense_id)
);

-- ===================================================================== helpers
CREATE OR REPLACE FUNCTION core_platform.cp_expense_acc_money(v numeric) RETURNS text
LANGUAGE sql IMMUTABLE AS $f$ SELECT to_char(round(v, 2), 'FM9999999999999990.00') $f$;

-- What the expense is, as published. NULL keys are kept (a reader can tell "none" from "absent").
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
        'document_type', 'EXPENSE', 'document_id', e.id, 'document_number', coalesce(nullif(trim(e.reference), ''), e.id),
        'date', coalesce(e.spent_on, e.cdatetime::date))
      FROM (SELECT 1) one
      LEFT JOIN core_platform.cp_expense_categories cat ON cat.tenant_id = e.tenant_id AND cat.id = e.category_id
$f$;

-- The part of a payload that matters to the books: a change to the note or the reference alone
-- is not a reason to reverse and record again.
CREATE OR REPLACE FUNCTION core_platform.cp_expense_acc_figures(p jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE AS $f$
    SELECT p - ARRAY['version', 'description', 'reference', 'document_number', 'receipt_file_id',
                     'category_name', 'revision', 'reversal']
$f$;

-- ===================================================================== one expense
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
        live := e.app = 'MYSTOREGUARD' AND e.status = 'APPROVED'
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

-- ===================================================================== fail open, loudly
CREATE OR REPLACE FUNCTION core_platform.cp_expense_acc_trigger() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE r core_platform.cp_expenses_history; msg text; flag text;
BEGIN
    IF TG_OP = 'DELETE' THEN r := OLD; ELSE r := NEW; END IF;
    -- Only MyStoreGuard's expenses (an UPDATE that moves a row away from it still reverses).
    IF r.app IS DISTINCT FROM 'MYSTOREGUARD'
       AND (TG_OP <> 'UPDATE' OR OLD.app IS DISTINCT FROM 'MYSTOREGUARD') THEN
        RETURN NULL;
    END IF;
    BEGIN
        PERFORM core_platform.cp_expense_acc_sync(r.tenant_id, r.id);
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS msg = MESSAGE_TEXT;
        -- Once per expense per transaction (an expense inserted then updated fires twice).
        flag := 'cp_exp_acc.e' || md5(r.tenant_id || '/' || r.id);
        IF coalesce(current_setting(flag, true), '') <> '1' THEN
            PERFORM set_config(flag, '1', true);
            PERFORM core_platform.cp_event_publish(r.tenant_id, r.bus_id, 'mystoreguard', 'msg.posting_error', r.id,
                jsonb_build_object('version', 1, 'app', 'mystoreguard', 'org_id', r.org_id, 'loc_id', r.loc_id,
                                   'document_type', 'EXPENSE', 'document_id', r.id,
                                   'document_number', coalesce(nullif(trim(r.reference), ''), r.id),
                                   'date', coalesce(r.spent_on, r.cdatetime::date), 'error', msg));
        END IF;
    END;
    RETURN NULL;
END
$f$;

-- ===================================================================== baseline (first run only)
INSERT INTO core_platform.cp_expense_acc_state (tenant_id, expense_id, bus_id, kind)
SELECT e.tenant_id, e.id, e.bus_id, 'BASELINE'
  FROM core_platform.cp_expenses_history e
 WHERE e.app = 'MYSTOREGUARD'
   AND NOT EXISTS (SELECT 1 FROM core_platform.cp_expense_acc_state WHERE tenant_id = '' AND expense_id = 'BASELINE')
ON CONFLICT DO NOTHING;

INSERT INTO core_platform.cp_expense_acc_state (tenant_id, expense_id, bus_id, kind)
VALUES ('', 'BASELINE', NULL, 'BASELINE')
ON CONFLICT DO NOTHING;

-- ===================================================================== the trigger
DROP TRIGGER IF EXISTS cp_expense_acc_event ON core_platform.cp_expenses_history;
CREATE CONSTRAINT TRIGGER cp_expense_acc_event AFTER INSERT OR UPDATE OR DELETE ON core_platform.cp_expenses_history
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION core_platform.cp_expense_acc_trigger();
-- Seeds and data fixes (session_replication_role = replica) are business changes too.
ALTER TABLE core_platform.cp_expenses_history ENABLE ALWAYS TRIGGER cp_expense_acc_event;

-- ===================================================================== event catalogue
-- Accounting events are flat (no link envelope, like every other msg.* posting event); the
-- schema below describes the payload itself so a reader can check what it takes in.
DO $$
BEGIN
    IF to_regclass('core_platform.cp_event_schemas') IS NULL THEN
        RAISE NOTICE 'msg expense events: no cp_event_schemas here, nothing to register';
        RETURN;
    END IF;
    INSERT INTO core_platform.cp_event_schemas (kind, version, link_key, source_app, target_app, phase, description, schema, updated_at)
    SELECT k.kind, 1, 'mystoreguard-accounting', 'app-mystoreguard', 'app-accounting', 1, k.description,
           jsonb_build_object(
               '$schema', 'https://json-schema.org/draft/2020-12/schema',
               'title', k.kind || ' v1',
               'type', 'object',
               'required', jsonb_build_array('id', 'tenant_id', 'bus_id', 'loc_id', 'amount', 'currency',
                                             'spent_on', 'source', 'revision', 'reversal'),
               'properties', jsonb_build_object(
                   'version', jsonb_build_object('type', 'integer', 'const', 1),
                   'id', jsonb_build_object('type', 'string'),
                   'tenant_id', jsonb_build_object('type', 'string'),
                   'org_id', jsonb_build_object('type', 'string'),
                   'bus_id', jsonb_build_object('type', 'string'),
                   'loc_id', jsonb_build_object('type', 'string'),
                   'amount', jsonb_build_object('type', 'string', 'pattern', '^[0-9]+\.[0-9]{2}$'),
                   'currency', jsonb_build_object('type', 'string'),
                   'currency_id', jsonb_build_object('type', 'string'),
                   'category_id', jsonb_build_object('type', jsonb_build_array('string', 'null')),
                   'category_name', jsonb_build_object('type', jsonb_build_array('string', 'null')),
                   'account_code', jsonb_build_object('type', jsonb_build_array('string', 'null')),
                   'tax_rate_id', jsonb_build_object('type', jsonb_build_array('string', 'null')),
                   'tax_amount', jsonb_build_object('type', jsonb_build_array('string', 'null')),
                   'supplier_id', jsonb_build_object('type', jsonb_build_array('string', 'null')),
                   'spent_on', jsonb_build_object('type', 'string', 'format', 'date'),
                   'source', jsonb_build_object('type', 'string',
                       'enum', jsonb_build_array('ALLOCATED', 'CONTIGENCY', 'FIXED', 'REIMBURSABLE', 'SALARY', 'OTHERS')),
                   'reference', jsonb_build_object('type', jsonb_build_array('string', 'null')),
                   'receipt_file_id', jsonb_build_object('type', jsonb_build_array('string', 'null')),
                   'description', jsonb_build_object('type', jsonb_build_array('string', 'null')),
                   'revision', jsonb_build_object('type', 'integer', 'minimum', 1),
                   'reversal', jsonb_build_object('type', 'boolean'))),
           now()
      FROM (VALUES
        ('msg.expense_recorded', 'A MyStoreGuard expense the books should post: amount paid (tax inside), category and its account code, supplier, date.'),
        ('msg.expense_reversed', 'A published MyStoreGuard expense to take back out of the books: deleted, no longer approved, or changed (the new figures follow as msg.expense_recorded).')
      ) AS k(kind, description)
    ON CONFLICT (kind, version) DO UPDATE SET
        link_key = EXCLUDED.link_key, source_app = EXCLUDED.source_app, target_app = EXCLUDED.target_app,
        phase = EXCLUDED.phase, description = EXCLUDED.description, schema = EXCLUDED.schema,
        updated_at = CASE WHEN core_platform.cp_event_schemas.schema IS DISTINCT FROM EXCLUDED.schema
                            OR core_platform.cp_event_schemas.description IS DISTINCT FROM EXCLUDED.description
                          THEN now() ELSE core_platform.cp_event_schemas.updated_at END;
END
$$;

COMMIT;
