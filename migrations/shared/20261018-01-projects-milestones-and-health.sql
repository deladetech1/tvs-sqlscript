-- Projects: milestones, project health and the weekly status update.
--
--   * prj_milestones: a dated point a project is working towards (Beta, Launch). Work joins one
--     through prj_tasks.milestone_id; reached_at says it was met. Whether it is on track, at
--     risk or late is worked out from its date and its work, never stored.
--   * prj_status_updates: the weekly word on a project -- how it is going (on track, at risk,
--     off track) as the person writing says, what happened, what is next, and the numbers as
--     they stood when it was written (snapshot), so last month's update still reads as it did.
--   * prj_projects.status_reminded_for: the Monday of the week the lead was last reminded to
--     write one, so the Friday reminder goes once a week.
--   * prj_notifications.project_id: what a notification about a whole project points at.
--   * prj_notifications.kind: this file now owns the list (it must live in one file, the newest
--     to touch it -- an older file re-run on deploy would put back a shorter list).
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS projects.prj_milestones (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    project_id     text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    name           text NOT NULL CHECK (btrim(name) <> ''),
    description    text NOT NULL DEFAULT '',
    due_date       date NOT NULL,
    reached_at     timestamptz,
    reached_by     text,
    created_by     text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    delete_status  text NOT NULL DEFAULT 'NOT_DELETED'
);
CREATE INDEX IF NOT EXISTS prj_milestones_project_idx ON projects.prj_milestones (project_id, due_date) WHERE delete_status = 'NOT_DELETED';

ALTER TABLE projects.prj_tasks ADD COLUMN IF NOT EXISTS milestone_id text REFERENCES projects.prj_milestones (id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS prj_tasks_milestone_idx ON projects.prj_tasks (milestone_id) WHERE milestone_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS projects.prj_status_updates (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    project_id     text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    health         text NOT NULL CHECK (health IN ('on_track', 'at_risk', 'off_track')),
    summary        text NOT NULL CHECK (btrim(summary) <> ''),
    next_steps     text NOT NULL DEFAULT '',
    snapshot       jsonb NOT NULL DEFAULT '{}'::jsonb,
    author_id      text NOT NULL,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    edited_at      timestamptz,
    delete_status  text NOT NULL DEFAULT 'NOT_DELETED'
);
CREATE INDEX IF NOT EXISTS prj_status_updates_project_idx ON projects.prj_status_updates (project_id, cdatetime DESC) WHERE delete_status = 'NOT_DELETED';

ALTER TABLE projects.prj_projects ADD COLUMN IF NOT EXISTS status_reminded_for date;

-- A notification about a whole project (a status update), not one work item.
ALTER TABLE projects.prj_notifications ADD COLUMN IF NOT EXISTS project_id text REFERENCES projects.prj_projects (id) ON DELETE CASCADE;

ALTER TABLE projects.prj_notifications DROP CONSTRAINT IF EXISTS prj_notifications_kind_check;
ALTER TABLE projects.prj_notifications ADD CONSTRAINT prj_notifications_kind_check
    CHECK (kind IN ('assigned', 'mentioned', 'commented', 'moved', 'done', 'approval', 'automation',
                    'due_soon', 'overdue', 'chat_mention', 'form_submitted',
                    'status_update', 'status_due', 'client_approval', 'client_comment', 'project_started',
                    'doc_comment', 'budget', 'doc_suggested', 'doc_suggestion_resolved'));

COMMIT;
