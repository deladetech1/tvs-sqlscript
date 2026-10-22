-- Loandrift's loan charges reach Accounting again (2026-10-21).
--
-- 20261020-21 gave disbursement charges their own journal source type, LOAN_CHARGES, and
-- relabels the old EXPENSE ('charges-%') entries to it on every deploy. But
-- loandrift.ld_acc_kind (20261019-41) only knew charges as EXPENSE + 'charges-%', so for
-- LOAN_CHARGES it returned NULL and ld_acc_sync_entry quietly skipped the entry: no
-- ld.loan_charges_collected event, no journal in Accounting, no error.
--
-- This redefines ld_acc_kind with LOAN_CHARGES mapped to the same events the old EXPENSE
-- charges used. It runs after 20261019-41 on every deploy, so the later definition wins.
-- The EXPENSE + 'charges-%' case stays for entries not yet relabelled.
--
-- Then it publishes the charges entries that were skipped: ld_acc_sync_entry writes
-- ld_acc_entry_state only when it publishes, so an entry with no state row was never sent,
-- and the function refuses an entry it already sent. Idempotent; safe to re-run.

BEGIN;

CREATE OR REPLACE FUNCTION loandrift.ld_acc_kind(p_source_type text, p_source_id text, p_reversal boolean) RETURNS text
LANGUAGE sql IMMUTABLE AS $f$
    SELECT 'ld.' || CASE WHEN NOT p_reversal THEN
        CASE p_source_type
            WHEN 'LOAN_DISBURSEMENT' THEN 'loan_disbursed'
            WHEN 'LOAN_CHARGES' THEN 'loan_charges_collected'
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
            WHEN 'LOAN_CHARGES' THEN 'loan_charges_reversed'
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

-- Publish the LOAN_CHARGES entries (and their reversals) that the old definition skipped.
DO $$
DECLARE r record;
BEGIN
    FOR r IN
        SELECT e.id
          FROM loandrift.ld_journal_entries e
          LEFT JOIN loandrift.ld_journal_entries o ON o.id = e.reversal_of_entry_id
         WHERE coalesce(o.source_type, e.source_type) = 'LOAN_CHARGES'
           AND e.status IN ('POSTED', 'REVERSED')
           AND e.delete_status = 'NOT_DELETED'
           AND NOT EXISTS (SELECT 1 FROM loandrift.ld_acc_entry_state s WHERE s.entry_id = e.id)
         ORDER BY e.id
    LOOP
        PERFORM loandrift.ld_acc_sync_entry(r.id);
    END LOOP;
END $$;

COMMIT;
