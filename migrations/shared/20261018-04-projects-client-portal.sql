-- Projects: the client portal, and read-only links to pages.
--
--   * prj_portal_clients: someone outside the business given a project's portal -- by a link
--     of their own (token), emailed to them, as long and random as a form's. A new link stops
--     the old one; revoking it (revoked_at) shuts the portal for them at once.
--   * In the portal a client sees how the project is going -- its progress and milestones,
--     the status updates the team chose to share (prj_status_updates.client_visible), the
--     pages shared with them (prj_docs.client_visible) -- and answers what the team asks them
--     to approve (prj_client_reviews), and writes to the team (prj_client_messages).
--   * prj_client_reviews: a work item put to the client: pending until they approve it or ask
--     for changes, with their note. A newer request replaces a pending one.
--   * prj_client_messages: the project's conversation with its clients; client_id when a
--     client wrote it, author_user_id when the team did.
--   * prj_docs.public_token: a page anyone with the link may read (not change). NULL: none.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS projects.prj_portal_clients (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    project_id    text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    name          text NOT NULL CHECK (btrim(name) <> ''),
    email         text NOT NULL DEFAULT '',
    token         text NOT NULL UNIQUE,
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    last_seen_at  timestamptz,
    sent_at       timestamptz,
    revoked_at    timestamptz
);
CREATE INDEX IF NOT EXISTS prj_portal_clients_project_idx ON projects.prj_portal_clients (project_id);

CREATE TABLE IF NOT EXISTS projects.prj_client_reviews (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    project_id     text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    task_id        text NOT NULL REFERENCES projects.prj_tasks (id) ON DELETE CASCADE,
    note           text NOT NULL DEFAULT '',
    requested_by   text NOT NULL,
    requested_at   timestamptz NOT NULL DEFAULT now(),
    status         text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'changes', 'withdrawn')),
    decided_by     text REFERENCES projects.prj_portal_clients (id) ON DELETE SET NULL,
    decided_at     timestamptz,
    client_note    text NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS prj_client_reviews_task_idx ON projects.prj_client_reviews (task_id, requested_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS prj_client_reviews_one_pending_uq ON projects.prj_client_reviews (task_id) WHERE status = 'pending';

CREATE TABLE IF NOT EXISTS projects.prj_client_messages (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    project_id      text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    client_id       text REFERENCES projects.prj_portal_clients (id) ON DELETE SET NULL,
    author_user_id  text,
    body            text NOT NULL CHECK (btrim(body) <> ''),
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    CHECK (client_id IS NULL OR author_user_id IS NULL)
);
CREATE INDEX IF NOT EXISTS prj_client_messages_project_idx ON projects.prj_client_messages (project_id, cdatetime);

ALTER TABLE projects.prj_status_updates ADD COLUMN IF NOT EXISTS client_visible boolean NOT NULL DEFAULT false;
ALTER TABLE projects.prj_docs ADD COLUMN IF NOT EXISTS client_visible boolean NOT NULL DEFAULT false;
ALTER TABLE projects.prj_docs ADD COLUMN IF NOT EXISTS public_token text;
CREATE UNIQUE INDEX IF NOT EXISTS prj_docs_public_token_uq ON projects.prj_docs (public_token) WHERE public_token IS NOT NULL;

COMMIT;
