-- =====================================================================
-- HMS and CloudHams expenses on their links to Accounting: the event catalogue
-- ---------------------------------------------------------------------
-- Core Platform's connected apps now have 'hms-accounting' and 'hospital-accounting'
-- (core-platform-bk app_connections_catalogue.py; inbox sources 'hms' and 'hospital'). The
-- apps publish to core_platform.cp_events in the transaction that makes the change, with
-- source_app = the inbox source ('hms', 'hospital'): Accounting keeps it as the inbox row's
-- source and finds the business's switch as 'app-' || source. This registers the kinds and
-- their payloads in core_platform.cp_event_schemas, as 20261108-06 does for MyStoreGuard.
-- Accounting does not post these kinds yet; registering changes nothing for anyone.
--
-- Events (flat payloads, no link envelope, like every other posting event; subject = the expense):
--   hms_expense.approved     an HMS expense approved (recorded by someone who may approve, or
--                            approved later). amount is what was PAID; tax_amount is inside it
--                            (net = amount - tax_amount).
--   hms_expense.voided       an approved HMS expense voided: take it back out of the books.
--   hospital_expense.paid    a CloudHams expense paid (through Core Platform's payout gateway,
--                            or recorded as paid by hand). Only expenses paid from now on: one
--                            paid before this never publishes. A paid expense is final in
--                            CloudHams (no void, no un-pay), so there is no reversal kind.
-- Amounts are strings with 2 decimals; null keys are kept (none, not absent).
--
-- Idempotent; safe to re-run on every deploy. This file owns these catalogue rows.
-- =====================================================================
BEGIN;

DO $$
DECLARE
    money   jsonb := jsonb_build_object('type', 'string', 'pattern', '^[0-9]+\.[0-9]{2}$');
    money_n jsonb := jsonb_build_object('type', jsonb_build_array('string', 'null'), 'pattern', '^[0-9]+\.[0-9]{2}$');
    str     jsonb := jsonb_build_object('type', 'string');
    str_n   jsonb := jsonb_build_object('type', jsonb_build_array('string', 'null'));
    day     jsonb := jsonb_build_object('type', 'string', 'format', 'date');
    hms_common jsonb;
BEGIN
    IF to_regclass('core_platform.cp_event_schemas') IS NULL THEN
        RAISE NOTICE 'hms/cloudhams expense events: no cp_event_schemas here, nothing to register';
        RETURN;
    END IF;

    hms_common := jsonb_build_object(
        'id', str, 'amount', money, 'currency', str, 'spent_on', day, 'date', day,
        'org_id', str_n, 'document_type', jsonb_build_object('type', 'string', 'const', 'EXPENSE'),
        'document_id', str, 'document_number', str,
        'core_category_id', str_n, 'account_code', str_n, 'tax_rate_id', str_n, 'tax_amount', money_n);

    INSERT INTO core_platform.cp_event_schemas (kind, version, link_key, source_app, target_app, phase, description, schema, updated_at)
    SELECT k.kind, 1, k.link_key, k.source_app, 'app-accounting', 1, k.description,
           jsonb_build_object('$schema', 'https://json-schema.org/draft/2020-12/schema', 'title', k.kind || ' v1',
                              'type', 'object', 'required', k.required, 'properties', k.properties),
           now()
      FROM (VALUES
        ('hms_expense.approved', 'hms-accounting', 'app-hms',
         'An approved HMS expense for the books: amount paid (tax inside), Core category and its account code, department, where the money came from.',
         jsonb_build_array('id', 'amount', 'currency', 'spent_on', 'date', 'paid_from', 'core_category_id', 'account_code', 'tax_rate_id', 'tax_amount'),
         hms_common || jsonb_build_object(
             'category', str, 'department', str, 'description', str, 'reference', str,
             'paid_from', jsonb_build_object('type', 'string',
                 'enum', jsonb_build_array('cash', 'petty_cash', 'bank', 'momo', 'card', 'cheque', 'owner', 'other')),
             'supplier_id', str, 'property_id', str)),
        ('hms_expense.voided', 'hms-accounting', 'app-hms',
         'An approved HMS expense voided: take it back out of the books (same figures as its hms_expense.approved).',
         jsonb_build_array('id', 'amount', 'currency', 'date', 'reason', 'core_category_id', 'account_code', 'tax_rate_id', 'tax_amount'),
         hms_common || jsonb_build_object('reason', str)),
        ('hospital_expense.paid', 'hospital-accounting', 'app-hospital',
         'A CloudHams expense paid: amount (tax inside), Core category and its account code, tax, how it was paid (payout gateway or by hand).',
         jsonb_build_array('id', 'tenant_id', 'bus_id', 'facility_id', 'amount', 'currency', 'spent_on', 'paid_on', 'date',
                           'core_category_id', 'category', 'account_code', 'tax_rate_id', 'tax_amount', 'method'),
         jsonb_build_object(
             'version', jsonb_build_object('type', 'integer', 'const', 1), 'app', jsonb_build_object('type', 'string', 'const', 'hospital'),
             'id', str, 'tenant_id', str, 'org_id', str_n, 'bus_id', str, 'facility_id', str, 'loc_id', str_n, 'number', str,
             'amount', money, 'currency', str, 'spent_on', day, 'paid_on', day, 'date', day,
             'core_category_id', str_n, 'category', str_n, 'account_code', str_n, 'tax_rate_id', str_n, 'tax_amount', money_n,
             'supplier_id', str_n, 'payee', str_n, 'reference', str_n, 'description', str_n,
             'method', jsonb_build_object('type', 'string', 'enum', jsonb_build_array('payout', 'manual')),
             'payment_method', str_n, 'payout_id', str, 'payout_reference', str_n, 'manual_reference', str_n,
             'document_type', jsonb_build_object('type', 'string', 'const', 'EXPENSE'), 'document_id', str, 'document_number', str))
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
