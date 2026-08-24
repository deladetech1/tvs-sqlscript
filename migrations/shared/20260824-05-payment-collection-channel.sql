-- =====================================================================
-- How the customer actually paid
-- ---------------------------------------------------------------------
-- A gateway checkout covers several instruments behind one page: a Paystack
-- payment may be a card, mobile money, a bank transfer or USSD, and the
-- customer chooses on the gateway's own screen. Until now everything came back
-- as one undifferentiated "online payment", so a shop's books could not tell a
-- card sale from a momo sale — which is exactly the split most Ghanaian
-- merchants reconcile on.
--
-- The gateways do report it on verification, each under its own name, so this
-- holds the normalised value: 'card', 'mobile_money', 'bank_transfer', 'ussd',
-- 'qr' or whatever the gateway said when it does not map to one of those.
--
-- Nullable: a payment that has not been verified yet has no channel, and
-- expressPay's query response does not always carry one.
--
-- Runs after the EF migrations on every deploy. Idempotent; safe to re-run.
-- =====================================================================

ALTER TABLE core_platform.cp_payment_collections
    ADD COLUMN IF NOT EXISTS channel text;

-- Reporting splits by channel far more often than it looks a payment up by one,
-- so this rides along with the existing tenant/date access pattern.
CREATE INDEX IF NOT EXISTS idx_cp_payment_collections_channel
    ON core_platform.cp_payment_collections (tenant_id, channel)
    WHERE channel IS NOT NULL;
