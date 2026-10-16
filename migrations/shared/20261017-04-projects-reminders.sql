-- Projects: due-soon and overdue reminders, and the notification kinds release 8 brings.
--
--   * prj_tasks.due_reminded_for / overdue_reminded_for: the due date a reminder was last sent
--     for. A reminder goes once per due date; moving the date re-arms it.
--   * notification kinds due_soon and overdue (the reminders), chat_mention (a chat message
--     naming someone) and form_submitted (an answer to a project's form), listed in 20261018-01.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE projects.prj_tasks ADD COLUMN IF NOT EXISTS due_reminded_for date;

-- Nothing already overdue on the day this arrives is reminded about: only what falls due from
-- now. Only on the run that adds the column -- re-run on every deploy, it would silence the
-- reminders of work that went overdue since.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'projects'
                    AND table_name = 'prj_tasks' AND column_name = 'overdue_reminded_for') THEN
        ALTER TABLE projects.prj_tasks ADD COLUMN overdue_reminded_for date;
        UPDATE projects.prj_tasks SET overdue_reminded_for = due_date
         WHERE due_date < CURRENT_DATE AND delete_status = 'NOT_DELETED';
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS prj_tasks_reminder_idx ON projects.prj_tasks (due_date)
 WHERE delete_status = 'NOT_DELETED' AND done_at IS NULL AND assignee_user_id IS NOT NULL;

-- The notification kinds are listed in the newest file to change them (20261018-01).

COMMIT;
