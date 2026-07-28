-- 20260712-03-purchase-order-notifications.sql
-- Email notifications for MyStoreGuard purchase orders.
--   * On create/update: notify the assignee and the designated approver.
--   * While a PO is still awaiting approval (DRAFT with an approver), the
--     approver is reminded every N minutes (per-user setting, min 5). Once the
--     PO is approved/rejected it leaves DRAFT, so reminders stop automatically.
-- Mirrors msg_task_notifications / msg_task_notification_settings.
-- Idempotent; safe to re-run on every deploy.

-- Per-user notification preferences (opt-in + reminder cadence in minutes).
CREATE TABLE IF NOT EXISTS mystoreguard.msg_purchase_order_notification_settings (
    id                        text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id                 text        NOT NULL,
    org_id                    text        NOT NULL,
    bus_id                    text        NOT NULL,
    user_id                   text        NOT NULL,
    opt_in                    boolean     NOT NULL DEFAULT TRUE,
    reminder_interval_minutes integer     NOT NULL DEFAULT 5 CHECK (reminder_interval_minutes >= 5),
    cdate                     text,
    ctime                     text,
    cdatetime                 timestamptz DEFAULT NOW(),
    created_by                text,
    updated_by                text,
    deleted_by                text
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_po_notification_settings_user
    ON mystoreguard.msg_purchase_order_notification_settings (tenant_id, org_id, bus_id, user_id);

-- Outbox of pending/sent notification emails, drained by the Functions app.
CREATE TABLE IF NOT EXISTS mystoreguard.msg_purchase_order_notifications (
    id                  text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text        NOT NULL,
    org_id              text        NOT NULL,
    bus_id              text        NOT NULL,
    purchase_order_id   text        NOT NULL,
    recipient_user_id   text        NOT NULL,
    kind                text        NOT NULL,                    -- ASSIGNED | NEEDS_APPROVAL | REMINDER
    status              text        NOT NULL DEFAULT 'PENDING',  -- PENDING | SENT | FAILED
    picked_up_at        timestamptz,
    sent_at             timestamptz,
    failure_reason      text,
    cdatetime           timestamptz DEFAULT NOW(),
    created_by          text
);

CREATE INDEX IF NOT EXISTS idx_msg_po_notifications_dispatch
    ON mystoreguard.msg_purchase_order_notifications (status, picked_up_at);

CREATE INDEX IF NOT EXISTS idx_msg_po_notifications_po
    ON mystoreguard.msg_purchase_order_notifications (purchase_order_id, recipient_user_id, kind, cdatetime);
