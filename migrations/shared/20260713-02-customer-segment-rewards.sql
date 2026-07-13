-- Customer loyalty segments: per-segment reward configuration + issuance ledger.
-- When a customer joins a segment, the store can automatically reward them
-- (e.g. issue a gift card) and/or email them. Idempotent.

-- ---------------------------------------------------------------------------
-- 1. Reward configuration columns on the segment itself
-- ---------------------------------------------------------------------------
ALTER TABLE mystoreguard.msg_customer_segments
    ADD COLUMN IF NOT EXISTS reward_type text NOT NULL DEFAULT 'NONE';

ALTER TABLE mystoreguard.msg_customer_segments
    ADD COLUMN IF NOT EXISTS reward_value numeric(18, 2);

ALTER TABLE mystoreguard.msg_customer_segments
    ADD COLUMN IF NOT EXISTS reward_discount_type text;

ALTER TABLE mystoreguard.msg_customer_segments
    ADD COLUMN IF NOT EXISTS reward_currency_id text;

ALTER TABLE mystoreguard.msg_customer_segments
    ADD COLUMN IF NOT EXISTS reward_location_ids text[];

ALTER TABLE mystoreguard.msg_customer_segments
    ADD COLUMN IF NOT EXISTS reward_expiry_days integer;

ALTER TABLE mystoreguard.msg_customer_segments
    ADD COLUMN IF NOT EXISTS reward_notify boolean NOT NULL DEFAULT false;

ALTER TABLE mystoreguard.msg_customer_segments
    ADD COLUMN IF NOT EXISTS reward_message text;

-- reward_type is one of a known set (drop-then-add so re-runs stay in sync)
ALTER TABLE mystoreguard.msg_customer_segments
    DROP CONSTRAINT IF EXISTS ck_msg_customer_segments_reward_type;
ALTER TABLE mystoreguard.msg_customer_segments
    ADD CONSTRAINT ck_msg_customer_segments_reward_type
    CHECK (reward_type IN ('NONE', 'GIFT_CARD', 'PROMO_CODE', 'DISCOUNT', 'NOTIFY'));

-- ---------------------------------------------------------------------------
-- 2. Issuance ledger: one row per (segment, customer) reward, so a member is
--    rewarded at most once and we can track what/when was issued + emailed.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mystoreguard.msg_customer_segment_rewards (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    org_id        text NOT NULL,
    bus_id        text NOT NULL,
    segment_id    text NOT NULL,
    customer_id   text NOT NULL,
    reward_type   text NOT NULL,
    reference_id  text,               -- gift card / promo code id (if any)
    reference_code text,              -- gift card / promo code (human readable)
    status        text NOT NULL DEFAULT 'ISSUED',
    notified      boolean NOT NULL DEFAULT false,
    cdate         text,
    ctime         text,
    cdatetime     timestamptz NOT NULL DEFAULT NOW(),
    created_by    text
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_customer_segment_rewards
    ON mystoreguard.msg_customer_segment_rewards
    (tenant_id, org_id, bus_id, segment_id, customer_id);

-- Pending-email lookup (rows not yet emailed)
CREATE INDEX IF NOT EXISTS ix_msg_customer_segment_rewards_pending
    ON mystoreguard.msg_customer_segment_rewards (tenant_id, notified)
    WHERE notified = false;
