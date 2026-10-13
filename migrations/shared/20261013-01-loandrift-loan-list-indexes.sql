-- LoanDrift: indexes for the loan lists and repayments by loan.
--
-- ld_repayments is keyed (tenant_id, org_id, bus_id, loc_id, id), so "the repayments of
-- this loan" read every repayment in the branch. The loan lists (Active Loans and the other
-- Loan Features pages) look up each loan's latest repayment, and the Repayments screen for a
-- loan lists them all; both now go straight to the loan's rows, newest first.
--
-- ld_loan_details is keyed by branch and id, so "this branch's ACTIVE loans, newest first"
-- read and sorted every loan in the branch on each page view. The partial index matches
-- what every list asks: not deleted, one branch, by status, newest first.
--
-- Idempotent; safe to re-run on every deploy.

CREATE INDEX IF NOT EXISTS ix_ld_repayments_loan_latest
    ON loandrift.ld_repayments (tenant_id, loan_id, cdatetime DESC);

CREATE INDEX IF NOT EXISTS ix_ld_loan_details_branch_status_recent
    ON loandrift.ld_loan_details (tenant_id, org_id, bus_id, loc_id, status, cdatetime DESC)
    WHERE delete_status = 'NOT_DELETED';

-- All Loans asks for every status, newest first.
CREATE INDEX IF NOT EXISTS ix_ld_loan_details_branch_recent
    ON loandrift.ld_loan_details (tenant_id, org_id, bus_id, loc_id, cdatetime DESC)
    WHERE delete_status = 'NOT_DELETED';
