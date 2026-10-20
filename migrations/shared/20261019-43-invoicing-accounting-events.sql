-- =====================================================================
-- Invoicing tells the books what happened: accounting events
-- ---------------------------------------------------------------------
-- Roadmap Phase 1, step 4 (docs/POSTINGS.md §7). Invoicing is the INVOICE OF RECORD: customers
-- get their invoices from Invoicing, and each one posts into the business's Accounting books as a
-- receivable. Every change that moves money publishes an event to core_platform.cp_events IN THE
-- SAME TRANSACTION as the change; Accounting reads them (reader 'accounting') and posts journals.
--
-- WHY TRIGGERS AND NOT THE GO SERVICE. Invoicing writes its documents and payments from many
-- places: the editor (issue, correct, void), payments by hand, the customer's online payment
-- settled on return / on opening the link / by "Check online payments" / by the payments job,
-- the portal's pay-several-at-once, autopay on a saved card (a job), credit notes (applied by
-- hand, auto-applied when made for an invoice, refunded), refunds (a credit note issued and paid
-- back in one step), late fees (their own invoice, issued by a job), recurring invoices (a job),
-- and bank reconciliation recording a payment from a statement line. Jobs run in the Azure
-- function app, not the API. Every one of them ends in a write to inv_invoices or inv_payments,
-- and recalcInvoice / recalcCreditNote are not called by all of them in the same way. Triggers
-- on the two tables see every path, including ones written after today.
--
-- WHY DEFERRED (fired at COMMIT). An invoice is issued header first, lines and totals after,
-- then its number; a payment is inserted, then the invoice is recalculated. At commit the
-- trigger reads the document as it finally stands and compares it with what was last published
-- (invoicing.inv_acc_state): only the difference is published. A write that fails rolls back
-- and publishes nothing.
--
-- THE MYSTOREGUARD GUARD. Invoicing brings MyStoreGuard's invoices in LINKED (source_app =
-- 'mystoreguard', source_id = the MSG invoice; 20261019-22). MyStoreGuard already publishes that
-- sale (msg.* events, 20261019-38): its revenue, tax and every payment, including payments taken
-- here, which reach MSG through inv_msg_payment_queue and are posted by MSG's own create_payment.
-- So a document linked to another app (source_app AND source_id set) publishes NOTHING here, and
-- neither do its payments (the shop's own, channel 'mystoreguard', and the ones queued back).
-- Otherwise the books would hold the sale twice.
--
-- Fail open, loudly: if describing a document raises, the write still commits and an
-- 'inv.posting_error' event names the document and the error; Accounting lists it as FAILED.
--
-- Events (subject = the Invoicing id; amounts are strings with 2 decimals):
--   inv.invoice_issued              an invoice issued (or corrected: a void of the old figures, then
--                                   the new revision): subtotal, each charged tax, withheld, receivable
--   inv.invoice_voided              reason VOIDED / CHANGED / DELETED, with the figures it posted
--   inv.credit_note_issued          the same for a credit note: the invoice turned round
--   inv.credit_note_voided
--   inv.payment_received            money in against an invoice (any method but credit)
--   inv.payment_reversed            a payment voided (or deleted)
--   inv.credit_applied              a credit note's credit used on an invoice
--   inv.credit_application_reversed
--   inv.refund_paid                 money paid back (a credit note refunded, or a refund on an invoice)
--   inv.refund_reversed
--   inv.posting_error
--
-- Starts from now: documents and payments that exist when this first runs are recorded as already
-- published (history belongs in the books' opening balances). Re-runs every deploy: idempotent.
-- =====================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS invoicing.inv_acc_state (
    kind       text NOT NULL,          -- DOC, PAYMENT, BASELINE
    doc_id     text NOT NULL,
    tenant_id  text NOT NULL,
    bus_id     text,
    revision   integer NOT NULL DEFAULT 0,
    -- What was last published (NULL: nothing stands in the books for it now).
    value      jsonb,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (kind, doc_id)
);

-- ===================================================================== helpers
CREATE OR REPLACE FUNCTION invoicing.inv_acc_money(v numeric) RETURNS text
LANGUAGE sql IMMUTABLE AS $f$ SELECT to_char(round(coalesce(v, 0), 2), 'FM9999999999999990.00') $f$;

-- The business's date at an instant: the tenant's zone in Core Platform, else UTC.
CREATE OR REPLACE FUNCTION invoicing.inv_acc_day(p_tenant text, p_at timestamptz) RETURNS date
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

-- A document another app owns (MyStoreGuard's invoices brought in linked): that app posts it.
CREATE OR REPLACE FUNCTION invoicing.inv_acc_linked(i invoicing.inv_invoices) RETURNS boolean
LANGUAGE sql IMMUTABLE AS $f$ SELECT nullif(i.source_app, '') IS NOT NULL AND nullif(i.source_id, '') IS NOT NULL $f$;

-- What an issued invoice or credit note puts in the books; NULL when nothing should stand
-- (draft, void, a quote or purchase order, or a document another app owns).
-- Receivable = total - withheld (what the customer pays); revenue = total - charged taxes, so the
-- event balances by construction (the same split as exports.go's journal export).
CREATE OR REPLACE FUNCTION invoicing.inv_acc_doc_figures(i invoicing.inv_invoices) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $f$
DECLARE
    v_taxes jsonb;
    v_tax_sum numeric;
    v_tax_total numeric := round(coalesce(i.tax_total, 0), 2);
    v_total numeric := round(coalesce(i.total, 0), 2);
    v_withheld numeric := round(coalesce(i.withheld, 0), 2);
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
    RETURN jsonb_build_object(
        'document_type', CASE i.kind WHEN 'credit_note' THEN 'CREDIT_NOTE' ELSE 'INVOICE' END,
        'date', i.issue_date,
        'currency', upper(i.currency::text),
        'subtotal', invoicing.inv_acc_money(v_total - v_tax_total),
        'taxes', v_taxes,
        'tax', invoicing.inv_acc_money(v_tax_total),
        'withheld', invoicing.inv_acc_money(v_withheld),
        'receivable', invoicing.inv_acc_money(v_total - v_withheld),
        'total', invoicing.inv_acc_money(v_total));
END
$f$;

-- What a payment puts in the books; NULL when nothing should stand (voided, or on a document
-- another app owns -- the MyStoreGuard guard -- or on a quote / purchase order).
CREATE OR REPLACE FUNCTION invoicing.inv_acc_payment_figures(p invoicing.inv_payments) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $f$
DECLARE
    d invoicing.inv_invoices;
    cn_number text;
    v_event text;
BEGIN
    IF p.id IS NULL OR p.status <> 'received' THEN RETURN NULL; END IF;
    SELECT * INTO d FROM invoicing.inv_invoices WHERE id = p.invoice_id;
    IF NOT FOUND OR d.kind NOT IN ('invoice', 'credit_note') OR invoicing.inv_acc_linked(d) THEN RETURN NULL; END IF;
    v_event := CASE WHEN p.method = 'credit_note' THEN 'inv.credit_applied'
                    WHEN p.kind = 'refund' THEN 'inv.refund_paid'
                    ELSE 'inv.payment_received' END;
    IF p.credit_note_id IS NOT NULL THEN
        SELECT c.number INTO cn_number FROM invoicing.inv_invoices c WHERE c.id = p.credit_note_id;
    END IF;
    RETURN jsonb_build_object(
        'event', v_event,
        'against', CASE d.kind WHEN 'credit_note' THEN 'CREDIT_NOTE' ELSE 'INVOICE' END,
        'method', upper(p.method),
        'amount', invoicing.inv_acc_money(p.amount),
        'currency', upper(p.currency::text),
        'date', p.paid_on,
        'credit_note_id', p.credit_note_id,
        'credit_note_number', cn_number);
END
$f$;

-- The money in a figures object, without the words (what counts as a change).
CREATE OR REPLACE FUNCTION invoicing.inv_acc_fingerprint(v jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE AS $f$
    SELECT CASE WHEN v IS NULL THEN NULL ELSE v - 'credit_note_number' - 'document_number' - 'invoice_id' END
$f$;

CREATE OR REPLACE FUNCTION invoicing.inv_acc_publish(p_tenant text, p_bus text, p_kind text, p_subject text, p_payload jsonb)
RETURNS bigint LANGUAGE sql AS $f$
    SELECT core_platform.cp_event_publish(p_tenant, p_bus, 'invoicing', p_kind, p_subject,
                                          jsonb_build_object('version', 1, 'app', 'invoicing') || p_payload)
$f$;

-- ===================================================================== one document
CREATE OR REPLACE FUNCTION invoicing.inv_acc_sync_doc(p_id text, p_tenant text, p_bus text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
    i invoicing.inv_invoices;
    found_doc boolean;
    st invoicing.inv_acc_state;
    target jsonb;
    old jsonb;
    rev integer;
    reason text;
    common jsonb;
    noun text;
BEGIN
    SELECT * INTO i FROM invoicing.inv_invoices WHERE id = p_id;
    found_doc := FOUND;
    target := CASE WHEN found_doc THEN invoicing.inv_acc_doc_figures(i) END;
    SELECT * INTO st FROM invoicing.inv_acc_state WHERE kind = 'DOC' AND doc_id = p_id;
    old := st.value;
    IF invoicing.inv_acc_fingerprint(old) IS NOT DISTINCT FROM invoicing.inv_acc_fingerprint(target) THEN
        RETURN;
    END IF;
    rev := coalesce(st.revision, 0);
    common := jsonb_build_object(
        'org_id', coalesce(i.org_id, (SELECT b.org_id FROM core_platform.cp_businesses b WHERE b.id = p_bus AND b.tenant_id = p_tenant LIMIT 1)),
        'document_id', p_id,
        'document_number', coalesce(i.number, old->>'document_number', p_id),
        'customer_id', i.customer_id,
        'customer_name', nullif(i.customer_snapshot->>'name', ''),
        'reference', nullif(i.reference, ''),
        'late_fee_for_id', i.late_fee_for_id,
        'credit_for_id', i.credit_for_id,
        'credit_for_number', (SELECT c.number FROM invoicing.inv_invoices c WHERE c.id = i.credit_for_id));

    IF old IS NOT NULL THEN
        reason := CASE WHEN NOT found_doc THEN 'DELETED' WHEN target IS NULL THEN 'VOIDED' ELSE 'CHANGED' END;
        noun := CASE old->>'document_type' WHEN 'CREDIT_NOTE' THEN 'credit_note' ELSE 'invoice' END;
        PERFORM invoicing.inv_acc_publish(p_tenant, p_bus, 'inv.' || noun || '_voided', p_id,
            common || old || jsonb_build_object(
                'revision', rev, 'reason', reason,
                'document_number', coalesce(i.number, old->>'document_number', p_id),
                -- A correction replaces the document on its own date; a void or deletion is dated the day it happened.
                'date', CASE WHEN reason = 'CHANGED' THEN (old->>'date')::date
                             ELSE greatest((old->>'date')::date, invoicing.inv_acc_day(p_tenant, coalesce(i.voided_at, now()))) END,
                'amount', old->>'total'));
    END IF;
    IF target IS NOT NULL THEN
        rev := rev + 1;
        noun := CASE target->>'document_type' WHEN 'CREDIT_NOTE' THEN 'credit_note' ELSE 'invoice' END;
        PERFORM invoicing.inv_acc_publish(p_tenant, p_bus, 'inv.' || noun || '_issued', p_id,
            common || target || jsonb_build_object('revision', rev, 'amount', target->>'total'));
    END IF;
    INSERT INTO invoicing.inv_acc_state (kind, doc_id, tenant_id, bus_id, revision, value, updated_at)
    VALUES ('DOC', p_id, p_tenant, p_bus, rev,
            CASE WHEN target IS NULL THEN NULL ELSE target || jsonb_build_object('document_number', i.number) END, now())
    ON CONFLICT (kind, doc_id) DO UPDATE SET revision = EXCLUDED.revision, value = EXCLUDED.value, updated_at = now();
END
$f$;

-- ===================================================================== one payment
CREATE OR REPLACE FUNCTION invoicing.inv_acc_sync_payment(p_id text, p_tenant text, p_bus text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
    p invoicing.inv_payments;
    found_pay boolean;
    d record;
    st invoicing.inv_acc_state;
    target jsonb;
    old jsonb;
    common jsonb;
    reason text;
BEGIN
    SELECT * INTO p FROM invoicing.inv_payments WHERE id = p_id;
    found_pay := FOUND;
    target := CASE WHEN found_pay THEN invoicing.inv_acc_payment_figures(p) END;
    SELECT * INTO st FROM invoicing.inv_acc_state WHERE kind = 'PAYMENT' AND doc_id = p_id;
    old := st.value;
    IF invoicing.inv_acc_fingerprint(old) IS NOT DISTINCT FROM invoicing.inv_acc_fingerprint(target) THEN
        RETURN;
    END IF;
    SELECT i.number, i.customer_id, i.customer_snapshot->>'name' AS customer_name, i.org_id
      INTO d FROM invoicing.inv_invoices i WHERE i.id = coalesce(p.invoice_id, old->>'invoice_id');
    common := jsonb_build_object(
        'org_id', coalesce(p.org_id, d.org_id, (SELECT b.org_id FROM core_platform.cp_businesses b WHERE b.id = p_bus AND b.tenant_id = p_tenant LIMIT 1)),
        'document_type', 'PAYMENT', 'document_id', p_id,
        'document_number', coalesce(nullif(p.receipt_number, ''), d.number, p_id),
        'receipt_number', p.receipt_number,
        'invoice_id', coalesce(p.invoice_id, old->>'invoice_id'), 'invoice_number', d.number,
        'customer_id', d.customer_id, 'customer_name', nullif(d.customer_name, ''),
        'reference', nullif(p.reference, ''), 'channel', nullif(p.channel, ''));

    IF old IS NOT NULL THEN
        reason := CASE WHEN NOT found_pay THEN 'DELETED' WHEN target IS NULL THEN 'VOIDED' ELSE 'CHANGED' END;
        PERFORM invoicing.inv_acc_publish(p_tenant, p_bus,
            CASE old->>'event' WHEN 'inv.credit_applied' THEN 'inv.credit_application_reversed'
                               WHEN 'inv.refund_paid' THEN 'inv.refund_reversed'
                               ELSE 'inv.payment_reversed' END, p_id,
            common || old || jsonb_build_object('reason', reason,
                'date', CASE WHEN reason = 'CHANGED' THEN (old->>'date')::date
                             ELSE greatest((old->>'date')::date, invoicing.inv_acc_day(p_tenant, coalesce(p.voided_at, now()))) END));
    END IF;
    IF target IS NOT NULL THEN
        PERFORM invoicing.inv_acc_publish(p_tenant, p_bus, target->>'event', p_id, common || target);
    END IF;
    INSERT INTO invoicing.inv_acc_state (kind, doc_id, tenant_id, bus_id, revision, value, updated_at)
    VALUES ('PAYMENT', p_id, p_tenant, p_bus, coalesce(st.revision, 0) + 1,
            CASE WHEN target IS NULL THEN NULL ELSE target || jsonb_build_object('invoice_id', p.invoice_id) END, now())
    ON CONFLICT (kind, doc_id) DO UPDATE SET revision = EXCLUDED.revision, value = EXCLUDED.value, updated_at = now();
END
$f$;

-- ===================================================================== fail open, loudly
CREATE OR REPLACE FUNCTION invoicing.inv_acc_trigger() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE
    v_id text; v_tenant text; v_bus text; v_org text; v_number text;
    msg text;
    flag text;
    what text := CASE TG_TABLE_NAME WHEN 'inv_payments' THEN 'PAYMENT' ELSE 'DOCUMENT' END;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_id := OLD.id; v_tenant := OLD.tenant_id; v_bus := OLD.bus_id; v_org := OLD.org_id;
    ELSE
        v_id := NEW.id; v_tenant := NEW.tenant_id; v_bus := NEW.bus_id; v_org := NEW.org_id;
    END IF;
    BEGIN
        IF what = 'PAYMENT' THEN
            PERFORM invoicing.inv_acc_sync_payment(v_id, v_tenant, v_bus);
        ELSE
            PERFORM invoicing.inv_acc_sync_doc(v_id, v_tenant, v_bus);
        END IF;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS msg = MESSAGE_TEXT;
        -- Once per row per transaction (a row written several times fires several times).
        flag := 'inv_acc.e' || md5(what || v_id);
        IF coalesce(current_setting(flag, true), '') <> '1' THEN
            PERFORM set_config(flag, '1', true);
            IF what = 'PAYMENT' THEN
                SELECT receipt_number INTO v_number FROM invoicing.inv_payments WHERE id = v_id;
            ELSE
                SELECT number INTO v_number FROM invoicing.inv_invoices WHERE id = v_id;
            END IF;
            PERFORM invoicing.inv_acc_publish(v_tenant, v_bus, 'inv.posting_error', v_id,
                jsonb_build_object('org_id', v_org, 'document_type', what, 'document_id', v_id,
                                   'document_number', coalesce(v_number, v_id),
                                   'date', invoicing.inv_acc_day(v_tenant, now()), 'error', msg));
        END IF;
    END;
    RETURN NULL;
END
$f$;

-- ===================================================================== baseline (first run only)
-- Everything before this runs is history: record it as already published, as it stands.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM invoicing.inv_acc_state WHERE kind = 'BASELINE' AND doc_id = 'BASELINE') THEN
        INSERT INTO invoicing.inv_acc_state (kind, doc_id, tenant_id, bus_id, revision, value)
        SELECT 'DOC', i.id, i.tenant_id, i.bus_id, 0, f || jsonb_build_object('document_number', i.number)
          FROM invoicing.inv_invoices i, LATERAL invoicing.inv_acc_doc_figures(i) f
         WHERE f IS NOT NULL
        ON CONFLICT DO NOTHING;
        INSERT INTO invoicing.inv_acc_state (kind, doc_id, tenant_id, bus_id, revision, value)
        SELECT 'PAYMENT', p.id, p.tenant_id, p.bus_id, 0, f || jsonb_build_object('invoice_id', p.invoice_id)
          FROM invoicing.inv_payments p, LATERAL invoicing.inv_acc_payment_figures(p) f
         WHERE f IS NOT NULL
        ON CONFLICT DO NOTHING;
        INSERT INTO invoicing.inv_acc_state (kind, doc_id, tenant_id, bus_id, revision, value)
        VALUES ('BASELINE', 'BASELINE', '', NULL, 0, NULL)
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- ===================================================================== the triggers
DROP TRIGGER IF EXISTS inv_acc_event ON invoicing.inv_invoices;
CREATE CONSTRAINT TRIGGER inv_acc_event AFTER INSERT OR UPDATE OR DELETE ON invoicing.inv_invoices
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION invoicing.inv_acc_trigger();
-- Seeds and data fixes (session_replication_role = replica) are business changes too.
ALTER TABLE invoicing.inv_invoices ENABLE ALWAYS TRIGGER inv_acc_event;

DROP TRIGGER IF EXISTS inv_acc_event ON invoicing.inv_payments;
CREATE CONSTRAINT TRIGGER inv_acc_event AFTER INSERT OR UPDATE OR DELETE ON invoicing.inv_payments
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION invoicing.inv_acc_trigger();
ALTER TABLE invoicing.inv_payments ENABLE ALWAYS TRIGGER inv_acc_event;

COMMIT;
