-- Loyalty tiers: ranked, single-membership tiers (e.g. Bronze/Silver/Gold).
-- A customer sits in exactly one tier, chosen by their lifetime spend against
-- each tier's threshold (highest qualifying rank wins). Idempotent.

-- ---------------------------------------------------------------------------
-- 1. Tier definitions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mystoreguard.msg_loyalty_tiers (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    org_id        text NOT NULL,
    bus_id        text NOT NULL,
    name          text NOT NULL,
    rank          integer NOT NULL DEFAULT 0,   -- higher = better tier
    min_spend     numeric(18, 2) NOT NULL DEFAULT 0,  -- lifetime spend to qualify
    color         text,
    perks         text,                          -- description of benefits
    is_active     boolean NOT NULL DEFAULT true,
    member_count  integer NOT NULL DEFAULT 0,
    last_computed_at timestamptz,
    delete_status text NOT NULL DEFAULT 'NOT_DELETED',
    cdate         text,
    ctime         text,
    cdatetime     timestamptz NOT NULL DEFAULT NOW(),
    created_by    text,
    updated_by    text,
    deleted_by    text
);

CREATE INDEX IF NOT EXISTS ix_msg_loyalty_tiers_lookup
    ON mystoreguard.msg_loyalty_tiers (tenant_id, org_id, bus_id, delete_status);

-- ---------------------------------------------------------------------------
-- 2. Current tier per customer (one row per customer)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mystoreguard.msg_customer_tier (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    org_id        text NOT NULL,
    bus_id        text NOT NULL,
    customer_id   text NOT NULL,
    tier_id       text NOT NULL,
    assigned_at   timestamptz NOT NULL DEFAULT NOW(),
    cdatetime     timestamptz NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_customer_tier
    ON mystoreguard.msg_customer_tier (tenant_id, org_id, bus_id, customer_id);

CREATE INDEX IF NOT EXISTS ix_msg_customer_tier_tier
    ON mystoreguard.msg_customer_tier (tenant_id, org_id, bus_id, tier_id);
