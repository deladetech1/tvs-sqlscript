-- 20260716-06-purchase-order-comments.sql
-- Discussion thread (approval chat) on a MyStoreGuard purchase order.
-- A private back-and-forth between the two people who matter on a PO: the
-- person who CREATED it and the person designated to APPROVE it. The worker
-- raises the PO, the approver asks questions / requests changes, and they
-- message until it is approved or rejected.
--
--   * Each message stores recipient_id (the OTHER participant) so the nav-bar
--     bell can count unread messages per user, and read_at so the sender sees
--     when the other party has read it ("seen"). The bell reads unread rows
--     directly (alerts_service._po_messages_provider) — no separate outbox.
--   * Files are uploaded via the file manager (msg_document_paths) and linked
--     here by document_id, mirroring msg_task_attachments.
-- Idempotent; safe to re-run on every deploy.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_purchase_order_comments (
    id                  text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text        NOT NULL,
    org_id              text        NOT NULL,
    bus_id              text        NOT NULL,
    purchase_order_id   text        NOT NULL,                    -- the PO this thread belongs to
    author_id           text        NOT NULL,                    -- participant who wrote the message
    recipient_id        text,                                    -- the other participant (bell + "seen")
    body                text        NOT NULL DEFAULT '',         -- message text ('' allowed when file-only)
    read_at             timestamptz,                             -- when the recipient first read it
    edited_at           timestamptz,                             -- set when the author edits the body
    cdate               text,
    ctime               text,
    cdatetime           timestamptz DEFAULT NOW(),
    created_by          text,
    updated_by          text,
    deleted_at          timestamptz                              -- soft delete marker
);

CREATE INDEX IF NOT EXISTS idx_msg_po_comments_thread
    ON mystoreguard.msg_purchase_order_comments
    (purchase_order_id, tenant_id, org_id, bus_id, deleted_at);

-- Drives the nav-bar bell: unread messages addressed to a given user.
CREATE INDEX IF NOT EXISTS idx_msg_po_comments_unread
    ON mystoreguard.msg_purchase_order_comments
    (recipient_id, read_at, deleted_at);

-- Files attached to a message. Uploaded first via the file manager, then linked
-- here by document_id (mirrors msg_task_attachments).
CREATE TABLE IF NOT EXISTS mystoreguard.msg_purchase_order_comment_attachments (
    id                  text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text        NOT NULL,
    org_id              text        NOT NULL,
    bus_id              text        NOT NULL,
    purchase_order_id   text        NOT NULL,
    comment_id          text        NOT NULL,
    document_id         text        NOT NULL,                    -- -> mystoreguard.msg_document_paths(id)
    is_active           boolean     DEFAULT TRUE,
    delete_status       text        DEFAULT 'NOT_DELETED',
    cdate               text,
    ctime               text,
    cdatetime           timestamptz DEFAULT NOW(),
    created_by          text,
    -- hard-deleting a comment removes its attachment junction rows
    CONSTRAINT fk_msg_po_comment_attachments_comment
        FOREIGN KEY (comment_id)
        REFERENCES mystoreguard.msg_purchase_order_comments(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_msg_po_comment_attachments_comment
    ON mystoreguard.msg_purchase_order_comment_attachments
    (comment_id, tenant_id, org_id, bus_id, delete_status, is_active);
