-- =====================================================================
-- Stock-take review / approval workflow + comments + email notifications
-- ---------------------------------------------------------------------
-- Adds an optional reviewer + approver to a stock take, a threaded
-- comment feed with @mentions, and a notification outbox drained by the
-- Azure Functions worker (process_stock_take_notifications).
--
-- Reviewer/approver are optional; the reviewer is only notified once all
-- variances are resolved, and the approver only after the reviewer approves.
--
-- Runs after the EF migrations (so mystoreguard.msg_stock_takes exists) on
-- every deploy. Idempotent; safe to re-run.
-- =====================================================================

-- 1. Reviewer / approver + workflow state on the stock take -----------
ALTER TABLE mystoreguard.msg_stock_takes
    ADD COLUMN IF NOT EXISTS reviewer_id     text,
    ADD COLUMN IF NOT EXISTS approver_id     text,
    ADD COLUMN IF NOT EXISTS workflow_status text NOT NULL DEFAULT 'NONE',
    ADD COLUMN IF NOT EXISTS reviewed_by     text,
    ADD COLUMN IF NOT EXISTS reviewed_at     timestamptz,
    ADD COLUMN IF NOT EXISTS review_note     text,
    ADD COLUMN IF NOT EXISTS approved_by     text,
    ADD COLUMN IF NOT EXISTS approved_at     timestamptz,
    ADD COLUMN IF NOT EXISTS approval_note   text;

-- workflow_status check constraint (Postgres has no ADD CONSTRAINT IF NOT EXISTS)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_stock_takes_workflow_status'
    ) THEN
        ALTER TABLE mystoreguard.msg_stock_takes
            ADD CONSTRAINT ck_msg_stock_takes_workflow_status
            CHECK (workflow_status IN (
                'NONE', 'PENDING_REVIEW', 'REVIEWED', 'PENDING_APPROVAL', 'APPROVED', 'REJECTED'
            ));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_msg_stock_takes_reviewer
    ON mystoreguard.msg_stock_takes (reviewer_id, tenant_id, org_id, bus_id);
CREATE INDEX IF NOT EXISTS idx_msg_stock_takes_approver
    ON mystoreguard.msg_stock_takes (approver_id, tenant_id, org_id, bus_id);
CREATE INDEX IF NOT EXISTS idx_msg_stock_takes_workflow_status
    ON mystoreguard.msg_stock_takes (workflow_status, tenant_id, org_id, bus_id);

-- 2. Comment feed -----------------------------------------------------
CREATE TABLE IF NOT EXISTS mystoreguard.msg_stock_take_comments (
    id            text NOT NULL DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    org_id        text NOT NULL,
    bus_id        text NOT NULL,
    stock_take_id text NOT NULL,
    body          text NOT NULL,
    edited_at     timestamptz,
    cdate         text,
    ctime         text,
    cdatetime     timestamptz DEFAULT NOW(),
    created_by    text,
    updated_by    text,
    CONSTRAINT pk_msg_stock_take_comments PRIMARY KEY (tenant_id, org_id, bus_id, id)
);

CREATE INDEX IF NOT EXISTS idx_msg_stock_take_comments_stock_take
    ON mystoreguard.msg_stock_take_comments (tenant_id, org_id, bus_id, stock_take_id);

-- 3. Comment @mentions ------------------------------------------------
CREATE TABLE IF NOT EXISTS mystoreguard.msg_stock_take_comment_mentions (
    id                text NOT NULL DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text NOT NULL,
    bus_id            text NOT NULL,
    comment_id        text NOT NULL,
    stock_take_id     text NOT NULL,
    mentioned_user_id text NOT NULL,
    created_by        text,
    cdate             text,
    ctime             text,
    cdatetime         timestamptz DEFAULT NOW(),
    CONSTRAINT pk_msg_stock_take_comment_mentions PRIMARY KEY (tenant_id, org_id, bus_id, id),
    CONSTRAINT uq_msg_stock_take_comment_mentions
        UNIQUE (tenant_id, org_id, bus_id, comment_id, mentioned_user_id)
);

CREATE INDEX IF NOT EXISTS idx_msg_stock_take_comment_mentions_comment
    ON mystoreguard.msg_stock_take_comment_mentions (tenant_id, org_id, bus_id, comment_id);

-- 4. Notification outbox (drained + emailed by the Functions worker) ---
CREATE TABLE IF NOT EXISTS mystoreguard.msg_stock_take_notifications (
    id                text NOT NULL DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text NOT NULL,
    bus_id            text NOT NULL,
    stock_take_id     text NOT NULL,
    recipient_user_id text NOT NULL,
    kind              text NOT NULL,
    status            text NOT NULL DEFAULT 'PENDING',
    comment_id        text,
    picked_up_at      timestamptz,
    sent_at           timestamptz,
    failure_reason    text,
    cdate             text,
    ctime             text,
    cdatetime         timestamptz DEFAULT NOW(),
    created_by        text,
    CONSTRAINT pk_msg_stock_take_notifications PRIMARY KEY (tenant_id, org_id, bus_id, id),
    CONSTRAINT ck_msg_stock_take_notifications_kind
        CHECK (kind IN ('NEEDS_REVIEW', 'NEEDS_APPROVAL', 'MENTIONED', 'REJECTED', 'APPROVED')),
    CONSTRAINT ck_msg_stock_take_notifications_status
        CHECK (status IN ('PENDING', 'SENT', 'FAILED'))
);

CREATE INDEX IF NOT EXISTS idx_msg_stock_take_notifications_pickup
    ON mystoreguard.msg_stock_take_notifications (status, picked_up_at);
