-- Projects: due-soon and overdue reminders, and the notification kinds release 8 brings.
--
--   * prj_tasks.due_reminded_for / overdue_reminded_for: the due date a reminder was last sent
--     for. A reminder goes once per due date; moving the date re-arms it.
--   * prj_notifications.kind gains due_soon and overdue (the reminders), chat_mention (a chat
--     message naming someone) and form_submitted (an answer to a project's form).
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE projects.prj_tasks ADD COLUMN IF NOT EXISTS due_reminded_for date;
ALTER TABLE projects.prj_tasks ADD COLUMN IF NOT EXISTS overdue_reminded_for date;

-- Nothing already overdue on the day this arrives is reminded about: only what falls due from now.
UPDATE projects.prj_tasks SET overdue_reminded_for = due_date
 WHERE due_date < CURRENT_DATE AND overdue_reminded_for IS NULL AND delete_status = 'NOT_DELETED';

CREATE INDEX IF NOT EXISTS prj_tasks_reminder_idx ON projects.prj_tasks (due_date)
 WHERE delete_status = 'NOT_DELETED' AND done_at IS NULL AND assignee_user_id IS NOT NULL;

ALTER TABLE projects.prj_notifications DROP CONSTRAINT IF EXISTS prj_notifications_kind_check;
ALTER TABLE projects.prj_notifications ADD CONSTRAINT prj_notifications_kind_check
    CHECK (kind IN ('assigned', 'mentioned', 'commented', 'moved', 'done', 'approval', 'automation',
                    'due_soon', 'overdue', 'chat_mention', 'form_submitted'));

COMMIT;
