-- Loyalty points program: customers earn points on paid sales and redeem them.
-- Per-business settings, a running balance per customer, and a full ledger.
-- Idempotent.

-- ---------------------------------------------------------------------------
-- 1. Per-business points configuration (one row per tenant/org/bus)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mystoreguard.msg_loyalty_settings (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    org_id             text NOT NULL,
    bus_id             text NOT NULL,
    is_active          boolean NOT NULL DEFAULT false,
    earn_rate          numeric(18, 4) NOT NULL DEFAULT 1,     -- points earned per 1.0 spent
    redeem_rate        numeric(18, 4) NOT NULL DEFAULT 1,     -- currency value of 1 point on redemption
    min_redeem_points  numeric(18, 2) NOT NULL DEFAULT 0,     -- minimum points per redemption
    points_expiry_days integer,                               -- optional expiry (informational)
    currency_id        text,
    cdate              text,
    ctime              text,
    cdatetime          timestamptz NOT NULL DEFAULT NOW(),
    created_by         text,
    updated_by         text
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_loyalty_settings
    ON mystoreguard.msg_loyalty_settings (tenant_id, org_id, bus_id);

-- ---------------------------------------------------------------------------
-- 2. Running points balance per customer
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mystoreguard.msg_customer_points (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    org_id             text NOT NULL,
    bus_id             text NOT NULL,
    customer_id        text NOT NULL,
    points_balance     numeric(18, 2) NOT NULL DEFAULT 0,
    lifetime_earned    numeric(18, 2) NOT NULL DEFAULT 0,
    lifetime_redeemed  numeric(18, 2) NOT NULL DEFAULT 0,
    updated_at         timestamptz NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_customer_points
    ON mystoreguard.msg_customer_points (tenant_id, org_id, bus_id, customer_id);

-- ---------------------------------------------------------------------------
-- 3. Points ledger (earn / redeem / adjust / expire)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mystoreguard.msg_loyalty_transactions (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    org_id        text NOT NULL,
    bus_id        text NOT NULL,
    customer_id   text NOT NULL,
    txn_type      text NOT NULL,          -- EARN | REDEEM | ADJUST | EXPIRE
    points        numeric(18, 2) NOT NULL, -- positive earn, negative redeem
    sale_id       text,                    -- source sale for EARN (dedup)
    note          text,
    cdate         text,
    ctime         text,
    cdatetime     timestamptz NOT NULL DEFAULT NOW(),
    created_by    text
);

ALTER TABLE mystoreguard.msg_loyalty_transactions
    DROP CONSTRAINT IF EXISTS ck_msg_loyalty_transactions_txn_type;
ALTER TABLE mystoreguard.msg_loyalty_transactions
    ADD CONSTRAINT ck_msg_loyalty_transactions_txn_type
    CHECK (txn_type IN ('EARN', 'REDEEM', 'ADJUST', 'EXPIRE'));

CREATE INDEX IF NOT EXISTS ix_msg_loyalty_transactions_customer
    ON mystoreguard.msg_loyalty_transactions (tenant_id, org_id, bus_id, customer_id);

-- One EARN row per sale (prevents double-awarding when the job re-runs)
CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_loyalty_transactions_earn_sale
    ON mystoreguard.msg_loyalty_transactions (tenant_id, org_id, bus_id, sale_id)
    WHERE txn_type = 'EARN' AND sale_id IS NOT NULL;
