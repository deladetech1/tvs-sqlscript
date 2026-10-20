-- Projects: forms -- a public page whose every answer becomes a work item in a project
-- (requests, bug reports, onboarding).
--
--   * prj_forms: the form. fields is a list of questions ({id, label, kind, required, options,
--     help, maps_to}); maps_to sends an answer into the work item (title, description, due_date,
--     priority) -- every answer is also written into the item's description. The item takes
--     the form's kind, priority, labels, board and assignee; notify_user_ids are told of each
--     answer. public_token is the unguessable part of its address; is_open lets it be closed.
--   * prj_form_submissions: one answer, the work item it made, and a hash of where it came
--     from (never the address itself), to slow down abuse.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS projects.prj_forms (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    project_id        text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    name              text NOT NULL CHECK (btrim(name) <> ''),
    description       text NOT NULL DEFAULT '',
    fields            jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(fields) = 'array'),
    kind              text NOT NULL DEFAULT 'task' CHECK (kind IN ('story', 'task', 'bug')),
    priority          text NOT NULL DEFAULT 'medium' CHECK (priority IN ('urgent', 'high', 'medium', 'low')),
    labels            text[] NOT NULL DEFAULT '{}',
    board_id          text REFERENCES projects.prj_boards (id) ON DELETE SET NULL,
    assignee_user_id  text,
    notify_user_ids   text[] NOT NULL DEFAULT '{}',
    thanks_message    text NOT NULL DEFAULT '',
    -- Ask who is answering (name and email), and require it.
    ask_contact       boolean NOT NULL DEFAULT true,
    public_token      text NOT NULL UNIQUE,
    is_open           boolean NOT NULL DEFAULT true,
    created_by        text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    delete_status     text NOT NULL DEFAULT 'NOT_DELETED'
);
CREATE INDEX IF NOT EXISTS prj_forms_project_idx ON projects.prj_forms (project_id) WHERE delete_status = 'NOT_DELETED';

CREATE TABLE IF NOT EXISTS projects.prj_form_submissions (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    form_id          text NOT NULL REFERENCES projects.prj_forms (id) ON DELETE CASCADE,
    task_id          text REFERENCES projects.prj_tasks (id) ON DELETE SET NULL,
    answers          jsonb NOT NULL DEFAULT '{}'::jsonb,
    submitter_name   text NOT NULL DEFAULT '',
    submitter_email  text NOT NULL DEFAULT '',
    source_hash      text NOT NULL DEFAULT '',
    cdatetime        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prj_form_submissions_form_idx ON projects.prj_form_submissions (form_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS prj_form_submissions_source_idx ON projects.prj_form_submissions (form_id, source_hash, cdatetime DESC);

-- Notifications about an answer point at its work item; nothing more is needed.

COMMIT;
