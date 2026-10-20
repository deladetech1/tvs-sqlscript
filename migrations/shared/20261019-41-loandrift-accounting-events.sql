-- =====================================================================
-- Loandrift tells the books what happened: accounting events
-- ---------------------------------------------------------------------
-- Roadmap Phase 1, step 2 (docs/POSTINGS.md §5). Every Loandrift money movement publishes an
-- event to core_platform.cp_events IN THE SAME TRANSACTION as the movement; Accounting reads
-- them (reader 'accounting') and posts journals into the business's books.
--
-- WHAT IS PUBLISHED: LOANDRIFT'S OWN LEDGER. Unlike MyStoreGuard, Loandrift already states every
-- money movement as a balanced journal of its own (loandrift.ld_journal_entries / _lines,
-- app/src/entities/accounting/acc_base.py), written in the same transaction as the disbursement,
-- repayment, write-off, savings or investment transaction it describes. Its lines already carry
-- the split that matters: a repayment's principal (Loans receivable), interest (income on payment;
-- Loandrift prices loans flat and splits each payment pro rata) and penalty (income on payment,
-- after penalties-first allocation); charges taken at disbursement; write-offs against the
-- allowance; refinance clearing; overpayments held as client credit. Re-deriving those figures
-- from the loan tables here would be a second, disagreeing copy of the same rules. So the trigger
-- watches the ledger: one event per Loandrift journal entry, with its lines by Loandrift's
-- standard account key (system_key), and Accounting maps each key to a posting role.
--
-- Operational sources only. Loandrift's own bookkeeping (MANUAL journals, OPENING_BALANCE,
-- YEAR_END_CLOSE, fixed assets: ASSET_ACQUISITION, ASSET_DISPOSAL, DEPRECIATION) is NOT published:
-- the business keeps those in Accounting itself, and copying them would count them twice.
--
-- WHY DEFERRED (fired at COMMIT): an entry is inserted before its lines. At commit the trigger
-- reads the entry with every line; a Loandrift write that fails rolls back and publishes nothing.
-- Ledger entries are never edited (a correction is a mirror entry), so the state table only needs
-- to remember which entries were published.
--
-- Fail open, loudly: if describing an entry raises, Loandrift's write still commits and an
-- 'ld.posting_error' event names the entry and the error; Accounting lists it as FAILED.
--
-- Events (subject = the Loandrift journal entry id; amounts are strings with 2 decimals):
--   ld.loan_disbursed            ld.loan_disbursement_reversed
--   ld.loan_charges_collected    ld.loan_charges_reversed       (processing fee, insurance, other)
--   ld.repayment_received        ld.repayment_reversed
--   ld.penalty_charged           ld.penalty_charge_reversed     (Loandrift posts none today)
--   ld.penalty_waived            ld.penalty_waiver_reversed     (Loandrift posts none today)
--   ld.loan_written_off          ld.write_off_reversed
--   ld.write_off_recovered       ld.write_off_recovery_reversed
--   ld.loan_loss_provision       ld.loan_loss_provision_reversed
--   ld.savings_deposit           ld.savings_deposit_reversed
--   ld.savings_withdrawal        ld.savings_withdrawal_reversed
--   ld.savings_interest          ld.savings_interest_reversed
--   ld.investment_received       ld.investment_received_reversed
--   ld.investment_paid_out       ld.investment_paid_out_reversed
--   ld.client_credit_refunded    ld.client_credit_refund_reversed
--   ld.expense_paid              ld.expense_reversed
--   ld.posting_error
--
-- Starts from now: entries that exist when this first runs are recorded as already published
-- (history belongs in the books' opening balances). Re-runs every deploy: idempotent.
-- =====================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS loandrift.ld_acc_entry_state (
    entry_id     text PRIMARY KEY,
    tenant_id    text NOT NULL,
    bus_id       text,
    kind         text NOT NULL,
    -- What was published, so a later check can tell it was this entry as it then stood.
    total        numeric(18,2),
    published_at timestamptz NOT NULL DEFAULT now()
);

-- ===================================================================== helpers
CREATE OR REPLACE FUNCTION loandrift.ld_acc_money(v numeric) RETURNS text
LANGUAGE sql IMMUTABLE AS $f$ SELECT to_char(round(coalesce(v, 0), 2), 'FM9999999999999990.00') $f$;

-- A currency id as its code; with no id (or an unknown one), the tenant's default currency.
-- '' when unknown (Accounting then takes its base currency).
CREATE OR REPLACE FUNCTION loandrift.ld_acc_currency(p_tenant text, p_currency_id text DEFAULT NULL) RETURNS text
LANGUAGE sql STABLE AS $f$
    SELECT coalesce(
        (SELECT upper(code) FROM core_platform.cp_currencies
          WHERE tenant_id = p_tenant AND p_currency_id IS NOT NULL AND id = p_currency_id LIMIT 1),
        (SELECT upper(code) FROM core_platform.cp_currencies
          WHERE tenant_id = p_tenant AND is_default AND coalesce(delete_status, 'NOT_DELETED') = 'NOT_DELETED'
          ORDER BY cdatetime DESC NULLS LAST LIMIT 1),
        '')
$f$;

-- The event a Loandrift journal is, from its source; NULL for Loandrift's own bookkeeping, which is
-- not published. Loan charges are posted by Loandrift as source EXPENSE with source id 'charges-<loan>'.
CREATE OR REPLACE FUNCTION loandrift.ld_acc_kind(p_source_type text, p_source_id text, p_reversal boolean) RETURNS text
LANGUAGE sql IMMUTABLE AS $f$
    SELECT 'ld.' || CASE WHEN NOT p_reversal THEN
        CASE p_source_type
            WHEN 'LOAN_DISBURSEMENT' THEN 'loan_disbursed'
            WHEN 'EXPENSE' THEN CASE WHEN p_source_id LIKE 'charges-%' THEN 'loan_charges_collected' ELSE 'expense_paid' END
            WHEN 'REPAYMENT' THEN 'repayment_received'
            WHEN 'PENALTY' THEN 'penalty_charged'
            WHEN 'PENALTY_WAIVER' THEN 'penalty_waived'
            WHEN 'WRITE_OFF' THEN 'loan_written_off'
            WHEN 'WRITE_OFF_RECOVERY' THEN 'write_off_recovered'
            WHEN 'PROVISION' THEN 'loan_loss_provision'
            WHEN 'SAVINGS_DEPOSIT' THEN 'savings_deposit'
            WHEN 'SAVINGS_WITHDRAWAL' THEN 'savings_withdrawal'
            WHEN 'SAVINGS_INTEREST' THEN 'savings_interest'
            WHEN 'INVESTMENT' THEN 'investment_received'
            WHEN 'INVESTMENT_RETURN' THEN 'investment_paid_out'
            WHEN 'CLIENT_CREDIT' THEN 'client_credit_refunded'
        END
    ELSE
        CASE p_source_type
            WHEN 'LOAN_DISBURSEMENT' THEN 'loan_disbursement_reversed'
            WHEN 'EXPENSE' THEN CASE WHEN p_source_id LIKE 'charges-%' THEN 'loan_charges_reversed' ELSE 'expense_reversed' END
            WHEN 'REPAYMENT' THEN 'repayment_reversed'
            WHEN 'PENALTY' THEN 'penalty_charge_reversed'
            WHEN 'PENALTY_WAIVER' THEN 'penalty_waiver_reversed'
            WHEN 'WRITE_OFF' THEN 'write_off_reversed'
            WHEN 'WRITE_OFF_RECOVERY' THEN 'write_off_recovery_reversed'
            WHEN 'PROVISION' THEN 'loan_loss_provision_reversed'
            WHEN 'SAVINGS_DEPOSIT' THEN 'savings_deposit_reversed'
            WHEN 'SAVINGS_WITHDRAWAL' THEN 'savings_withdrawal_reversed'
            WHEN 'SAVINGS_INTEREST' THEN 'savings_interest_reversed'
            WHEN 'INVESTMENT' THEN 'investment_received_reversed'
            WHEN 'INVESTMENT_RETURN' THEN 'investment_paid_out_reversed'
            WHEN 'CLIENT_CREDIT' THEN 'client_credit_refund_reversed'
        END
    END
$f$;

-- ===================================================================== one journal entry
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
               'account_key', a.system_key, 'account_code', a.account_code, 'account_name', a.account_name,
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
        'lines', v_lines));
    INSERT INTO loandrift.ld_acc_entry_state (entry_id, tenant_id, bus_id, kind, total)
    VALUES (e.id, e.tenant_id, e.bus_id, v_kind, round(v_total, 2));
END
$f$;

-- ===================================================================== fail open, loudly
CREATE OR REPLACE FUNCTION loandrift.ld_acc_trigger() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE msg text; flag text;
BEGIN
    BEGIN
        PERFORM loandrift.ld_acc_sync_entry(NEW.id);
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS msg = MESSAGE_TEXT;
        -- Once per entry per transaction (an entry inserted then updated fires twice).
        flag := 'ld_acc.e' || md5(NEW.id);
        IF coalesce(current_setting(flag, true), '') <> '1' THEN
            PERFORM set_config(flag, '1', true);
            PERFORM core_platform.cp_event_publish(NEW.tenant_id, NEW.bus_id, 'loandrift', 'ld.posting_error', NEW.id,
                jsonb_build_object('version', 1, 'app', 'loandrift', 'org_id', NEW.org_id, 'loc_id', NEW.loc_id,
                                   'document_type', NEW.source_type, 'document_id', NEW.id,
                                   'document_number', coalesce(NEW.entry_number, NEW.id),
                                   'date', coalesce(NEW.original_date, NEW.entry_date), 'error', msg));
        END IF;
    END;
    RETURN NULL;
END
$f$;

-- ===================================================================== baseline (first run only)
-- Everything in Loandrift's ledger before this runs is history: record it as already published.
INSERT INTO loandrift.ld_acc_entry_state (entry_id, tenant_id, bus_id, kind, total)
SELECT e.id, e.tenant_id, e.bus_id, 'BASELINE', round(e.total_debit, 2)
  FROM loandrift.ld_journal_entries e
 WHERE NOT EXISTS (SELECT 1 FROM loandrift.ld_acc_entry_state WHERE entry_id = 'BASELINE')
ON CONFLICT DO NOTHING;

INSERT INTO loandrift.ld_acc_entry_state (entry_id, tenant_id, bus_id, kind, total)
VALUES ('BASELINE', '', NULL, 'BASELINE', NULL)
ON CONFLICT DO NOTHING;

-- ===================================================================== the trigger
DROP TRIGGER IF EXISTS ld_acc_event ON loandrift.ld_journal_entries;
CREATE CONSTRAINT TRIGGER ld_acc_event AFTER INSERT OR UPDATE ON loandrift.ld_journal_entries
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION loandrift.ld_acc_trigger();
-- Seeds and data fixes (session_replication_role = replica) are business changes too.
ALTER TABLE loandrift.ld_journal_entries ENABLE ALWAYS TRIGGER ld_acc_event;

COMMIT;
