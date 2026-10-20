-- LoanDrift: payment reconciliation recognises a gateway payment that is already
-- applied to a loan.
--
-- An online repayment (Repay online -> Paystack) records the repayment itself,
-- tagged with the gateway reference in ld_repayments.online_payment_reference.
-- Reconciliation used to ignore that link and only look for a loan reference,
-- phone number or amount, so such a payment showed UNMATCHED although the loan
-- had it. It now settles those first and records them as POSTED with
-- match_method GATEWAY_REFERENCE, which this widens the check constraint for.
--
-- Idempotent: the constraint is dropped and recreated with the same name.

ALTER TABLE loandrift.ld_payment_reconciliations
    DROP CONSTRAINT IF EXISTS ck_ld_payment_reconciliations_method;

ALTER TABLE loandrift.ld_payment_reconciliations
    ADD CONSTRAINT ck_ld_payment_reconciliations_method
        CHECK (match_method IS NULL OR match_method IN
               ('GATEWAY_REFERENCE','LOAN_REFERENCE','ACCOUNT_NUMBER','AMOUNT_AND_DATE','MANUAL'));
