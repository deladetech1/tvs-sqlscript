-- Projects: rules that start on dates, email digests, and reminders by text.
--
--   * prj_rules.trigger gains overdue (work whose due date has passed) and due_soon (due
--     tomorrow); the hourly job sets them off, once per due date for each item
--     (prj_tasks.overdue_ruled_for / due_soon_ruled_for: the due date they last fired for).
--   * prj_member_prefs: how each person hears -- a summary email (off, daily, weekly; weekly
--     unless they change it) and due-soon and overdue reminders by text as well (off unless they
--     turn it on). last_digest_at: when the last summary went.
--   * prj_notifications.texted_at: when a reminder also went by text.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE projects.prj_rules DROP CONSTRAINT IF EXISTS prj_rules_trigger_check;
ALTER TABLE projects.prj_rules ADD CONSTRAINT prj_rules_trigger_check
    CHECK (trigger IN ('created', 'moved', 'assigned', 'priority_changed', 'commented', 'done', 'overdue', 'due_soon'));

-- Only what falls due from now sets rules off: on the run that adds the column, today's
-- overdue work is marked as already handled.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'projects'
                    AND table_name = 'prj_tasks' AND column_name = 'overdue_ruled_for') THEN
        ALTER TABLE projects.prj_tasks ADD COLUMN overdue_ruled_for date;
        UPDATE projects.prj_tasks SET overdue_ruled_for = due_date WHERE due_date < CURRENT_DATE AND delete_status = 'NOT_DELETED';
    END IF;
END $$;
ALTER TABLE projects.prj_tasks ADD COLUMN IF NOT EXISTS due_soon_ruled_for date;

CREATE TABLE IF NOT EXISTS projects.prj_member_prefs (
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    user_id         text NOT NULL,
    digest          text NOT NULL DEFAULT 'weekly' CHECK (digest IN ('off', 'daily', 'weekly')),
    sms_reminders   boolean NOT NULL DEFAULT false,
    last_digest_at  timestamptz,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, bus_id, user_id)
);

ALTER TABLE projects.prj_notifications ADD COLUMN IF NOT EXISTS texted_at timestamptz;

COMMIT;
