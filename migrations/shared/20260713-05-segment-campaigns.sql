-- Targeted email campaigns to a loyalty segment. Recipients are snapshotted
-- from the segment's members (with an email) at send time, then delivered by
-- the scheduled Functions job. Idempotent.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_segment_campaigns (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    org_id          text NOT NULL,
    bus_id          text NOT NULL,
    segment_id      text NOT NULL,
    subject         text NOT NULL,
    body            text NOT NULL,
    status          text NOT NULL DEFAULT 'PENDING',  -- PENDING | SENDING | SENT
    recipient_count integer NOT NULL DEFAULT 0,
    sent_count      integer NOT NULL DEFAULT 0,
    failed_count    integer NOT NULL DEFAULT 0,
    cdate           text,
    ctime           text,
    cdatetime       timestamptz NOT NULL DEFAULT NOW(),
    created_by      text
);

CREATE INDEX IF NOT EXISTS ix_msg_segment_campaigns_lookup
    ON mystoreguard.msg_segment_campaigns (tenant_id, org_id, bus_id, segment_id);

CREATE TABLE IF NOT EXISTS mystoreguard.msg_segment_campaign_recipients (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    org_id       text NOT NULL,
    bus_id       text NOT NULL,
    campaign_id  text NOT NULL,
    customer_id  text NOT NULL,
    email        text NOT NULL,
    status       text NOT NULL DEFAULT 'PENDING',  -- PENDING | SENT | FAILED
    cdatetime    timestamptz NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_msg_segment_campaign_recipients_pending
    ON mystoreguard.msg_segment_campaign_recipients (tenant_id, status)
    WHERE status = 'PENDING';

CREATE INDEX IF NOT EXISTS ix_msg_segment_campaign_recipients_campaign
    ON mystoreguard.msg_segment_campaign_recipients (campaign_id);
