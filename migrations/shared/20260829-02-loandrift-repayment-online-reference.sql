-- 20260829-02-loandrift-repayment-online-reference.sql
-- Tie a repayment back to the gateway payment that produced it.
--
-- A repayment taken through Paystack, Hubtel, expressPay or Stripe is recorded
-- in CorePlatform as core_platform.cp_payment_collections, keyed by a
-- reference. Keeping that reference on the repayment matters for two reasons:
--
--   idempotency  the same gateway payment must never be banked twice. A double
--                click, a retried request, a replayed callback or the sweep
--                racing the till would otherwise post the borrower's money
--                against the loan more than once — and unlike a sale, a
--                duplicated repayment moves the loan balance, the arrears
--                calculation, the penalty ledger and the journal all at once.
--                The unique index below makes that impossible rather than
--                unlikely.
--
--   support      when a borrower says they paid and the branch cannot see it,
--                the reference is what links the two systems together.
--
-- Nullable, because every repayment captured at a desk has no gateway behind
-- it. The unique index is partial for the same reason.
--
-- Added here rather than in EF, matching how
-- mystoreguard.msg_sales_payments.online_payment_reference was added: the
-- column belongs to the payment integration, not to the repayment model EF
-- owns, and this keeps the two able to move independently.
--
-- Runs after the EF migrations on every deploy. Idempotent; safe to re-run.

ALTER TABLE loandrift.ld_repayments
    ADD COLUMN IF NOT EXISTS online_payment_reference text;

-- One repayment per gateway payment, per tenant.
CREATE UNIQUE INDEX IF NOT EXISTS uq_ld_repayments_online_reference
    ON loandrift.ld_repayments (tenant_id, online_payment_reference)
    WHERE online_payment_reference IS NOT NULL;

-- Looking a repayment up by reference is what support does; without this it is
-- a sequential scan of every repayment the tenant has ever taken.
CREATE INDEX IF NOT EXISTS idx_ld_repayments_online_reference
    ON loandrift.ld_repayments (online_payment_reference)
    WHERE online_payment_reference IS NOT NULL;
