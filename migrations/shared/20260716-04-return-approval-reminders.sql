-- 20260716-04-return-approval-reminders.sql
-- Recurring "still awaiting your approval" email reminders for PENDING store
-- returns. A scheduled function re-emails the policy's approvers every N minutes
-- while the return is PENDING; approving/rejecting/processing moves it out of
-- PENDING so reminders stop automatically. Idempotent.

-- Marker for the last reminder sent (NULL => never; creation email is the baseline).
ALTER TABLE mystoreguard.msg_returns
    ADD COLUMN IF NOT EXISTS last_approval_reminder_at timestamptz;

-- Per-business reminder settings (enable + cadence).
CREATE TABLE IF NOT EXISTS mystoreguard.msg_return_notification_settings (
    id                        text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id                 text NOT NULL,
    org_id                    text NOT NULL,
    bus_id                    text NOT NULL,
    is_active                 boolean NOT NULL DEFAULT true,   -- send approval reminders
    reminder_interval_minutes integer NOT NULL DEFAULT 60,     -- cadence (min 5)
    cdate                     text,
    ctime                     text,
    cdatetime                 timestamptz NOT NULL DEFAULT NOW(),
    created_by                text,
    updated_by                text
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_return_notification_settings
    ON mystoreguard.msg_return_notification_settings (tenant_id, org_id, bus_id);

ALTER TABLE mystoreguard.msg_return_notification_settings
    DROP CONSTRAINT IF EXISTS ck_msg_return_notification_settings_interval;
ALTER TABLE mystoreguard.msg_return_notification_settings
    ADD CONSTRAINT ck_msg_return_notification_settings_interval
    CHECK (reminder_interval_minutes >= 5);
