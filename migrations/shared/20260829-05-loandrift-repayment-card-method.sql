-- 20260829-05-loandrift-repayment-card-method.sql
-- Let a repayment be a card payment.
--
-- ld_repayments.payment_method allowed CASH, CHEQUE, MOMO, BANK_TRANSFER and
-- OTHERS. That covered every way money reached a branch counter, and stopped
-- being enough the moment a borrower could pay through a gateway: a gateway
-- checkout settles as card, mobile money, bank transfer, USSD or QR, and the
-- borrower chooses on the gateway's own screen.
--
-- Mobile money and bank transfer already have somewhere honest to go. A card
-- did not. Filing it as OTHERS would have been worse than untidy — the
-- accounting posts a repayment to a cash or bank account by reading this very
-- column, and an unrecognised value falls back to CASH. A lender would have
-- ended each day with a till the books said held money no one could count.
--
-- CARD is posted to BANK, which is where a gateway actually settles it.
--
-- The constraint is EF's (ck_<table>_<column>), so it is dropped by that name
-- and recreated wider here. The EF configuration is updated to match, so
-- regenerating it later does not narrow it again.
--
-- Idempotent; safe to re-run on every deploy.

ALTER TABLE loandrift.ld_repayments
    DROP CONSTRAINT IF EXISTS ck_ld_repayments_payment_method;

ALTER TABLE loandrift.ld_repayments
    ADD CONSTRAINT ck_ld_repayments_payment_method
    CHECK (payment_method IN
        ('CASH', 'CHEQUE', 'MOMO', 'BANK_TRANSFER', 'CARD', 'OTHERS')
        OR payment_method IS NULL);
