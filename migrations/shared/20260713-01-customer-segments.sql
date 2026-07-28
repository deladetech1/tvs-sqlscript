-- 20260713-01-customer-segments.sql
-- Loyalty segments for MyStoreGuard: define customer groups by criteria, and a
-- scheduled job auto-assigns customers who match. Each business defines its own
-- segments with its own thresholds (all criteria optional; a customer must meet
-- every criterion that is set). A customer can belong to many segments.
-- Idempotent; safe to re-run on every deploy.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_customer_segments (
    id                   text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id            text        NOT NULL,
    org_id               text        NOT NULL,
    bus_id               text        NOT NULL,

    name                 text        NOT NULL,
    description          text,
    color                text,                              -- optional UI accent (hex or token)
    is_active            boolean     NOT NULL DEFAULT TRUE,

    -- Criteria (all optional; NULL = not applied)
    min_total_spend      numeric(18,2),                     -- lifetime/window spend threshold
    spend_window_days    integer,                           -- NULL = all-time; else spend/orders over last N days
    min_order_count      integer,                           -- minimum number of (non-cancelled) sales
    min_tenure_days      integer,                           -- how long a customer (days since created)
    active_within_days   integer,                           -- must have purchased within last N days

    member_count         integer     NOT NULL DEFAULT 0,    -- cached, refreshed by the job
    last_computed_at     timestamptz,

    delete_status        text        NOT NULL DEFAULT 'NOT_DELETED',
    cdate                text,
    ctime                text,
    cdatetime            timestamptz DEFAULT NOW(),
    created_by           text,
    updated_by           text,
    deleted_by           text
);

CREATE INDEX IF NOT EXISTS idx_msg_customer_segments_scope
    ON mystoreguard.msg_customer_segments (tenant_id, org_id, bus_id, delete_status, is_active);

CREATE TABLE IF NOT EXISTS mystoreguard.msg_customer_segment_members (
    id           text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text        NOT NULL,
    org_id       text        NOT NULL,
    bus_id       text        NOT NULL,
    segment_id   text        NOT NULL,
    customer_id  text        NOT NULL,
    joined_at    timestamptz DEFAULT NOW(),
    cdatetime    timestamptz DEFAULT NOW()
);

-- One membership row per (segment, customer); lets the job upsert and preserve joined_at.
CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_customer_segment_members
    ON mystoreguard.msg_customer_segment_members (tenant_id, org_id, bus_id, segment_id, customer_id);

CREATE INDEX IF NOT EXISTS idx_msg_customer_segment_members_segment
    ON mystoreguard.msg_customer_segment_members (segment_id, tenant_id, org_id, bus_id);
