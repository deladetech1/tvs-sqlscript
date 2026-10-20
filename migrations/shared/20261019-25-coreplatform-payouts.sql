-- =====================================================================
-- Core Platform: sending money out (payouts)
-- ---------------------------------------------------------------------
-- Core Platform could only COLLECT money (cp_payment_collections). Apps now
-- need to SEND it: Expenses paying staff back, later ZelosHR salaries,
-- LoanDrift disbursements, Invoicing refunds. A payout goes through the
-- business's own gateway -- whichever of its connected ones it marks for
-- payouts and whose client can send money (Paystack today) -- or, when none can,
-- is recorded as paid by hand with a reference.
--
--   cp_payouts            one payout: who asked (app + its own reference, unique,
--                         so a retried request never pays twice), to whom, how
--                         much, through which gateway, and what came of it
--   cp_payout_recipients  a recipient as a gateway knows it (Paystack's
--                         recipient_code), kept so the same account is not
--                         registered again for every payout
--   cp_tenant_payment_providers.is_payout_default
--                         the gateway that sends this tenant's payouts
--
-- Idempotent; safe to re-run.
-- =====================================================================
BEGIN;

ALTER TABLE core_platform.cp_tenant_payment_providers
    ADD COLUMN IF NOT EXISTS is_payout_default boolean NOT NULL DEFAULT false;
CREATE UNIQUE INDEX IF NOT EXISTS cp_tenant_payment_providers_payout_default_uq
    ON core_platform.cp_tenant_payment_providers (tenant_id)
    WHERE is_payout_default AND delete_status = 'NOT_DELETED';

CREATE TABLE IF NOT EXISTS core_platform.cp_payout_recipients (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    provider_code   text NOT NULL,
    -- 'mobile_money' or 'bank'; bank_code is the gateway's code for the bank or telco.
    kind            text NOT NULL CHECK (kind IN ('mobile_money', 'bank')),
    bank_code       text NOT NULL,
    account_number  text NOT NULL,
    account_name    text NOT NULL DEFAULT '',
    currency        char(3) NOT NULL,
    recipient_code  text NOT NULL,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, provider_code, kind, bank_code, account_number, currency)
);

CREATE TABLE IF NOT EXISTS core_platform.cp_payouts (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    org_id             text,
    bus_id             text,
    -- Who asked, and its own reference for the thing paid (an expense claim): unique,
    -- so asking twice returns the first payout rather than paying again.
    app_id             text NOT NULL,
    app_reference      text NOT NULL,
    -- Ours, sent to the gateway (and the idempotency key there).
    reference          text NOT NULL UNIQUE,
    provider_code      text,
    provider_reference text,
    recipient_id       text REFERENCES core_platform.cp_payout_recipients (id) ON DELETE SET NULL,
    -- To whom, as asked: kind, bank_code, bank_name, account_number, account_name.
    recipient          jsonb NOT NULL,
    amount_minor       bigint NOT NULL CHECK (amount_minor > 0),
    currency           char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
    reason             text NOT NULL DEFAULT '',
    -- pending: not yet sent; processing: the gateway has it; success / failed /
    -- reversed: its outcome; manual: paid outside, by hand, with manual_reference.
    status             text NOT NULL DEFAULT 'pending'
                       CHECK (status IN ('pending', 'processing', 'success', 'failed', 'reversed', 'cancelled', 'manual')),
    failure_reason     text,
    manual_reference   text,
    provider_response  jsonb,
    requested_by       text,
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    udatetime          timestamptz NOT NULL DEFAULT now(),
    completed_at       timestamptz,
    UNIQUE (tenant_id, app_id, app_reference)
);
CREATE INDEX IF NOT EXISTS cp_payouts_tenant_idx ON core_platform.cp_payouts (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS cp_payouts_open_idx ON core_platform.cp_payouts (status) WHERE status IN ('pending', 'processing');

COMMIT;
