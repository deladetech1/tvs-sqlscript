-- 20260716-02-store-credit-settings.sql
-- Per-business store-credit configuration (mirrors msg_loyalty_settings).
-- One row per tenant/org/bus. Safe defaults so an unconfigured business keeps
-- today's behaviour (store credit on, never expires). Idempotent.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_store_credit_settings (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    org_id             text NOT NULL,
    bus_id             text NOT NULL,
    is_active          boolean       NOT NULL DEFAULT true,   -- master on/off for store credit
    expiry_days        integer,                               -- NULL = never expires
    min_issue_amount   numeric(18,2) NOT NULL DEFAULT 0,      -- don't issue credit below this refund amount
    currency_id        text,
    cdate              text,
    ctime              text,
    cdatetime          timestamptz   NOT NULL DEFAULT NOW(),
    created_by         text,
    updated_by         text
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_store_credit_settings
    ON mystoreguard.msg_store_credit_settings (tenant_id, org_id, bus_id);
