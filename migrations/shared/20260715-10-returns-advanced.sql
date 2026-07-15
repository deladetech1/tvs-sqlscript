-- 20260715-10-returns-advanced.sql
-- Advanced returns: composable approval gates, per-line policy resolution &
-- per-condition restocking fees, receipt/condition enforcement, velocity fraud
-- flags, tax proration, store-credit issuance, and exchange price-difference.
--
-- Follows the raw-SQL feature-migration precedent (loyalty-points,
-- purchase-returns, sales-audit-logs). The returns tables are also EF-managed;
-- these columns are added out-of-band with ADD COLUMN IF NOT EXISTS, which is
-- invisible-but-safe to the EF model (EF diffs model-vs-snapshot, never dropping
-- unknown columns). Idempotent; safe to re-run on every deploy.

-- ---------------------------------------------------------------------------
-- 1. Return policies: new gate / fee / velocity configuration
-- ---------------------------------------------------------------------------
ALTER TABLE mystoreguard.msg_return_policies
    ADD COLUMN IF NOT EXISTS approval_conditions        jsonb,          -- e.g. ["DAMAGED","OPENED"]  force approval when a returned item is in this set
    ADD COLUMN IF NOT EXISTS approval_reasons           jsonb,          -- e.g. ["DEFECTIVE"]         force approval for these return reasons
    ADD COLUMN IF NOT EXISTS approval_refund_methods    jsonb,          -- e.g. ["CASH"]              force approval for these refund methods
    ADD COLUMN IF NOT EXISTS approval_on_no_receipt     boolean         DEFAULT false,  -- force approval when the return has no receipt
    ADD COLUMN IF NOT EXISTS restocking_fee_by_condition jsonb,         -- e.g. {"OPENED":20,"DAMAGED":0}  per-condition fee %, overrides restocking_fee_percent
    ADD COLUMN IF NOT EXISTS enforce_condition          boolean         DEFAULT false,  -- when true, condition_required is a hard gate (block on mismatch)
    ADD COLUMN IF NOT EXISTS max_returns_per_customer_period integer,   -- velocity threshold: max completed/pending returns per customer within the window
    ADD COLUMN IF NOT EXISTS returns_period_days        integer;        -- velocity window in days (NULL disables the velocity gate)

-- ---------------------------------------------------------------------------
-- 2. Returns header: receipt flag, settlement amounts, fraud flags
-- ---------------------------------------------------------------------------
ALTER TABLE mystoreguard.msg_returns
    ADD COLUMN IF NOT EXISTS has_receipt               boolean        DEFAULT true,   -- customer presented proof of purchase
    ADD COLUMN IF NOT EXISTS exchange_difference_amount numeric(18,2) DEFAULT 0,      -- EXCHANGE: (+) customer owes, (-) store owes; settled via cash/store-credit
    ADD COLUMN IF NOT EXISTS store_credit_issued_amount numeric(18,2) DEFAULT 0,      -- store credit issued on process (refund_method = STORE_CREDIT)
    ADD COLUMN IF NOT EXISTS tax_refund_amount         numeric(18,2)  DEFAULT 0,      -- prorated tax portion of the refund
    ADD COLUMN IF NOT EXISTS fraud_flagged             boolean        DEFAULT false,  -- velocity/other heuristic tripped
    ADD COLUMN IF NOT EXISTS fraud_reason              text;

-- ---------------------------------------------------------------------------
-- 3. Return items: per-line fee, per-line resolved policy, per-line tax
-- ---------------------------------------------------------------------------
ALTER TABLE mystoreguard.msg_return_items
    ADD COLUMN IF NOT EXISTS restocking_fee_percent    numeric(18,2)  DEFAULT 0,      -- fee % applied to this line
    ADD COLUMN IF NOT EXISTS restocking_fee_amount     numeric(18,2)  DEFAULT 0,      -- fee amount deducted from this line
    ADD COLUMN IF NOT EXISTS return_policy_id          text,                          -- policy resolved for THIS line (mixed-cart support)
    ADD COLUMN IF NOT EXISTS tax_refund_amount         numeric(18,2)  DEFAULT 0;      -- prorated tax refunded for this line

-- ---------------------------------------------------------------------------
-- 4. Store credit: running balance + ledger (mirrors loyalty-points design)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mystoreguard.msg_customer_store_credit (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    org_id             text NOT NULL,
    bus_id             text NOT NULL,
    customer_id        text NOT NULL,
    credit_balance     numeric(18,2) NOT NULL DEFAULT 0,
    lifetime_issued    numeric(18,2) NOT NULL DEFAULT 0,
    lifetime_redeemed  numeric(18,2) NOT NULL DEFAULT 0,
    updated_at         timestamptz   NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_customer_store_credit
    ON mystoreguard.msg_customer_store_credit (tenant_id, org_id, bus_id, customer_id);

CREATE TABLE IF NOT EXISTS mystoreguard.msg_store_credit_transactions (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text NOT NULL,
    bus_id           text NOT NULL,
    customer_id      text NOT NULL,
    txn_type         text NOT NULL,           -- ISSUE | REDEEM | ADJUST | EXPIRE
    amount           numeric(18,2) NOT NULL,  -- positive issue, negative redeem
    source_return_id text,                     -- return that issued this credit
    note             text,
    cdate            text,
    ctime            text,
    cdatetime        timestamptz NOT NULL DEFAULT NOW(),
    created_by       text
);

ALTER TABLE mystoreguard.msg_store_credit_transactions
    DROP CONSTRAINT IF EXISTS ck_msg_store_credit_transactions_txn_type;
ALTER TABLE mystoreguard.msg_store_credit_transactions
    ADD CONSTRAINT ck_msg_store_credit_transactions_txn_type
    CHECK (txn_type IN ('ISSUE', 'REDEEM', 'ADJUST', 'EXPIRE'));

CREATE INDEX IF NOT EXISTS ix_msg_store_credit_transactions_customer
    ON mystoreguard.msg_store_credit_transactions (tenant_id, org_id, bus_id, customer_id);

-- One ISSUE row per return (prevents double-issuing if process re-runs)
CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_store_credit_transactions_issue_return
    ON mystoreguard.msg_store_credit_transactions (tenant_id, org_id, bus_id, source_return_id)
    WHERE txn_type = 'ISSUE' AND source_return_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 5. Exchange replacement items chosen for an EXCHANGE return
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mystoreguard.msg_return_exchange_items (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    org_id       text NOT NULL,
    bus_id       text NOT NULL,
    loc_id       text NOT NULL,
    return_id    text NOT NULL,
    product_id   text NOT NULL,
    batch_id     text,
    quantity     numeric(18,2) NOT NULL CHECK (quantity > 0),
    unit_price   numeric(18,2) NOT NULL DEFAULT 0,
    line_total   numeric(18,2) NOT NULL DEFAULT 0,
    cdate        text,
    ctime        text,
    cdatetime    timestamptz NOT NULL DEFAULT NOW(),
    created_by   text
);

CREATE INDEX IF NOT EXISTS ix_msg_return_exchange_items_return
    ON mystoreguard.msg_return_exchange_items (tenant_id, org_id, bus_id, loc_id, return_id);

-- ---------------------------------------------------------------------------
-- 6. Permissions for store credit (attached to the existing store-returns resource)
-- ---------------------------------------------------------------------------
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime) VALUES
('permission-msg-store-credit-get',    'Mystoreguard Store Credit Get',    'rt-store-returns', 'Can view customer store-credit balances and ledger', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-store-credit-manage', 'Mystoreguard Store Credit Manage', 'rt-store-returns', 'Can adjust customer store-credit balances', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET
    permission_name  = EXCLUDED.permission_name,
    resource_type_id = EXCLUDED.resource_type_id,
    description      = EXCLUDED.description;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id) VALUES
('system-tenant-id', 'role-msg-store-returns-admin', 'permission-msg-store-credit-get'),
('system-tenant-id', 'role-msg-store-returns-admin', 'permission-msg-store-credit-manage'),
('system-tenant-id', 'role-msg-store-admin',         'permission-msg-store-credit-get'),
('system-tenant-id', 'role-msg-store-admin',         'permission-msg-store-credit-manage')
ON CONFLICT DO NOTHING;
