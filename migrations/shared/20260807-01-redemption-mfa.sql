-- 20260807-01-redemption-mfa.sql
-- Customer-verified redemption (MFA) for loyalty points and store credit.
--
-- Redeeming points or store credit spends real customer value, but until now the
-- only thing required was for the cashier to select the customer on the sale.
-- This table backs a one-time code sent to the CUSTOMER (not the cashier): the
-- cashier has to ask the customer to read it back, which is what proves the
-- customer was present and consented.
--
-- Flow: request -> a 6-digit code is emailed to the customer (SMS pending) and
-- stored here as a hash -> verify -> a single-use token is issued -> the sale
-- consumes the token when the LOYALTY_POINTS / STORE_CREDIT tender is applied.
--
-- Codes are never stored in plaintext, so a DB reader cannot approve a
-- redemption. Idempotent.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_redemption_verifications (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    org_id             text NOT NULL,
    bus_id             text NOT NULL,
    customer_id        text NOT NULL,
    redeem_type        text NOT NULL,                       -- LOYALTY_POINTS | STORE_CREDIT
    channel            text NOT NULL,                       -- EMAIL | SMS (SMS not yet enabled)
    destination        text,                                -- masked address/number the code went to
    code_hash          text NOT NULL,                       -- sha256(code + id); never the code itself
    amount_authorised  numeric(18,2) NOT NULL DEFAULT 0,    -- ceiling this token may authorise
    token              text,                                -- issued on successful verification
    status             text NOT NULL DEFAULT 'PENDING',     -- PENDING | VERIFIED | CONSUMED | SUPERSEDED
    attempts           integer NOT NULL DEFAULT 0,          -- wrong-code attempts, capped by the service
    expires_at         timestamptz NOT NULL,                -- code validity (short)
    token_expires_at   timestamptz,                         -- token validity after verification
    verified_at        timestamptz,
    consumed_at        timestamptz,
    sale_id            text,                                -- the sale that consumed the token
    cdate              text,
    ctime              text,
    cdatetime          timestamptz NOT NULL DEFAULT NOW(),
    created_by         text                                 -- the cashier who requested it
);

-- Lookup for the pending/verified row of a customer at the till.
CREATE INDEX IF NOT EXISTS idx_msg_redemption_verifications_scope
    ON mystoreguard.msg_redemption_verifications
       (tenant_id, org_id, bus_id, customer_id, redeem_type, status);

-- Token redemption at sale time. Partial: tokens only exist once verified.
CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_redemption_verifications_token
    ON mystoreguard.msg_redemption_verifications (token)
    WHERE token IS NOT NULL;

-- Supports the opportunistic purge of expired rows (see redemption_mfa_service).
CREATE INDEX IF NOT EXISTS idx_msg_redemption_verifications_expiry
    ON mystoreguard.msg_redemption_verifications (expires_at);

-- Who authorised what, for the fraud reports. Kept even after consumption.
CREATE INDEX IF NOT EXISTS idx_msg_redemption_verifications_actor
    ON mystoreguard.msg_redemption_verifications (tenant_id, created_by, cdatetime DESC);
