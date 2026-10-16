-- Projects: files on work items, and telling people what happened.
--
--   * prj_attachments: a work item's files. The bytes are in Projects' own storage account
--     (projects-files, private; a silo's beside its other apps'); a row says where.
--   * prj_notifications: what each person is told -- assigned to them, mentioned, a comment
--     or a move on something they watch. The bell reads these; the ones worth an email
--     (assigned, mentioned) are emailed once, and emailed_at says so.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS projects.prj_attachments (
    id             text PRIMARY KEY,
    tenant_id      text NOT NULL,
    org_id         text,
    bus_id         text NOT NULL,
    task_id        text NOT NULL REFERENCES projects.prj_tasks (id) ON DELETE CASCADE,
    file_name      text NOT NULL CHECK (btrim(file_name) <> ''),
    extension      text,
    content_type   text NOT NULL,
    size_bytes     bigint NOT NULL CHECK (size_bytes >= 0),
    blob_path      text NOT NULL,
    uploaded_by    text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    delete_status  text NOT NULL DEFAULT 'NOT_DELETED'
);
CREATE INDEX IF NOT EXISTS prj_attachments_task_idx ON projects.prj_attachments (task_id, cdatetime) WHERE delete_status = 'NOT_DELETED';
CREATE INDEX IF NOT EXISTS prj_attachments_bus_idx  ON projects.prj_attachments (tenant_id, bus_id);

CREATE TABLE IF NOT EXISTS projects.prj_notifications (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    user_id     text NOT NULL,
    task_id     text REFERENCES projects.prj_tasks (id) ON DELETE CASCADE,
    kind        text NOT NULL CHECK (kind IN ('assigned', 'mentioned', 'commented', 'moved', 'done')),
    actor_id    text,
    -- What the bell shows, written when it happened, so a later rename does not rewrite history.
    title       text NOT NULL,
    body        text NOT NULL DEFAULT '',
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    read_at     timestamptz,
    emailed_at  timestamptz
);
CREATE INDEX IF NOT EXISTS prj_notifications_user_idx
    ON projects.prj_notifications (tenant_id, bus_id, user_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS prj_notifications_unread_idx
    ON projects.prj_notifications (tenant_id, bus_id, user_id) WHERE read_at IS NULL;

-- Nobody is told about their own actions; the code never writes such a row. Kept as a rule
-- so a later change cannot start doing it unnoticed.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'prj_notifications_not_self') THEN
        ALTER TABLE projects.prj_notifications
            ADD CONSTRAINT prj_notifications_not_self CHECK (actor_id IS NULL OR actor_id <> user_id);
    END IF;
END $$;

COMMIT;
