-- =====================================================================
-- Tie a sale payment back to the gateway payment that produced it
-- ---------------------------------------------------------------------
-- A payment taken through Paystack, Hubtel, expressPay or Stripe is recorded
-- in CorePlatform as core_platform.cp_payment_collections, keyed by a reference.
-- Recording it against the sale needs that reference kept, for two reasons:
--
--   idempotency  the same gateway payment must never be banked twice — a double
--                click, a retried request or a replayed callback would otherwise
--                credit the customer's money to the sale more than once. The
--                unique index below makes that impossible rather than unlikely.
--
--   support      when a customer says they paid and the shop cannot see it,
--                the reference is what links the two systems together.
--
-- Nullable, because every payment taken any other way has no gateway behind it.
-- The unique index is partial for the same reason.
--
-- Runs after the EF migrations on every deploy. Idempotent; safe to re-run.
-- =====================================================================

ALTER TABLE mystoreguard.msg_sales_payments
    ADD COLUMN IF NOT EXISTS online_payment_reference text;

-- One sale payment per gateway payment, per tenant.
CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_sales_payments_online_reference
    ON mystoreguard.msg_sales_payments (tenant_id, online_payment_reference)
    WHERE online_payment_reference IS NOT NULL;

-- Looking a payment up by reference is what support does; without this it is a
-- sequential scan of every payment the tenant has ever taken.
CREATE INDEX IF NOT EXISTS idx_msg_sales_payments_online_reference
    ON mystoreguard.msg_sales_payments (online_payment_reference)
    WHERE online_payment_reference IS NOT NULL;
