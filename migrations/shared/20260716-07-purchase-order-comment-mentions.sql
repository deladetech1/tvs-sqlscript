-- 20260716-07-purchase-order-comment-mentions.sql
-- @mentions on a MyStoreGuard purchase-order discussion message. Lets a
-- participant tag any active user in the organization; the tagged user gets a
-- nav-bar bell alert (alerts_service._po_mentions_provider) and can then read
-- and reply on the thread. Mirrors msg_task_comment_mentions.
--   * read_at clears the mention from the bell once the user opens the thread.
-- Idempotent; safe to re-run on every deploy.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_purchase_order_comment_mentions (
    id                  text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text        NOT NULL,
    org_id              text        NOT NULL,
    bus_id              text        NOT NULL,
    purchase_order_id   text        NOT NULL,
    comment_id          text        NOT NULL,
    mentioned_user_id   text        NOT NULL,
    read_at             timestamptz,                             -- when the mentioned user opened the thread
    cdatetime           timestamptz DEFAULT NOW(),
    created_by          text,
    CONSTRAINT uq_msg_po_comment_mentions
        UNIQUE (tenant_id, org_id, bus_id, comment_id, mentioned_user_id),
    -- deleting a comment removes its mention rows
    CONSTRAINT fk_msg_po_comment_mentions_comment
        FOREIGN KEY (comment_id)
        REFERENCES mystoreguard.msg_purchase_order_comments(id) ON DELETE CASCADE
);

-- Drives the nav-bar bell: unread mentions of a given user.
CREATE INDEX IF NOT EXISTS idx_msg_po_comment_mentions_unread
    ON mystoreguard.msg_purchase_order_comment_mentions
    (mentioned_user_id, read_at);

-- "Is this user a participant by mention?" lookups per PO.
CREATE INDEX IF NOT EXISTS idx_msg_po_comment_mentions_po_user
    ON mystoreguard.msg_purchase_order_comment_mentions
    (purchase_order_id, mentioned_user_id, tenant_id, org_id, bus_id);
