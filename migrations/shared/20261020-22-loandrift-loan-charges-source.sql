-- LoanDrift: loan charges get their own journal source, LOAN_CHARGES.
--
-- The entry posted at disbursement for processing fees, insurance and other
-- charges ("Charges on loan LN-...") was tagged source_type EXPENSE, so the
-- journal list showed fee income as an expense and the cash flow statement
-- counted it under "Expenses paid". New entries are posted as LOAN_CHARGES.
--
-- This relabels the existing ones so old and new agree (and so the posting
-- guard, which looks up (source_type, source_id), still finds them). It changes
-- ONLY source_type: no amount, account, line, date or status is touched.
-- Reversals of a charges entry carry the source of the entry they reverse, so
-- they are relabelled with it.
--
-- Idempotent: the constraint is dropped and recreated by name, and the UPDATEs
-- only match rows still labelled EXPENSE.

ALTER TABLE loandrift.ld_journal_entries
    DROP CONSTRAINT IF EXISTS ck_ld_journal_entries_source_type;

ALTER TABLE loandrift.ld_journal_entries
    ADD CONSTRAINT ck_ld_journal_entries_source_type
        CHECK (source_type IN (
            'LOAN_DISBURSEMENT','REPAYMENT','PENALTY','PENALTY_WAIVER','EXPENSE','LOAN_CHARGES',
            'SAVINGS_DEPOSIT','SAVINGS_WITHDRAWAL','SAVINGS_INTEREST','INVESTMENT','INVESTMENT_RETURN',
            'DEPRECIATION','ASSET_ACQUISITION','ASSET_DISPOSAL','WRITE_OFF','MANUAL','CLIENT_CREDIT',
            'OPENING_BALANCE','PROVISION','WRITE_OFF_RECOVERY','YEAR_END_CLOSE'));

-- Reversals first, while the entries they point at are still labelled EXPENSE.
UPDATE loandrift.ld_journal_entries rev
SET source_type = 'LOAN_CHARGES'
FROM loandrift.ld_journal_entries orig
WHERE rev.reversal_of_entry_id = orig.id
  AND rev.tenant_id = orig.tenant_id
  AND rev.source_type = 'EXPENSE'
  AND orig.source_type = 'EXPENSE'
  AND orig.source_id LIKE 'charges-%';

UPDATE loandrift.ld_journal_entries
SET source_type = 'LOAN_CHARGES'
WHERE source_type = 'EXPENSE'
  AND source_id LIKE 'charges-%';
