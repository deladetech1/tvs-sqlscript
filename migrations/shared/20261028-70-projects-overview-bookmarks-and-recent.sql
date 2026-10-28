-- Projects: the Overview tab -- bookmarks and recently opened items.
--
--   * prj_bookmarks: links kept on a project (or one of its folders) for everyone who can see
--     the project. A bookmark is a title and either any URL or an item in the project
--     (target_kind + target_id: a work item, a page, a board or a folder), whose name and link
--     the API resolves each time it is read, so a renamed item is never stale and one the reader
--     may not see is not shown. Deleting a folder moves its bookmarks up to the project, like
--     everything else in it; deleting the project deletes them.
--   * prj_recent_items: what each person opened in a project, newest first, so their Recent
--     card follows them from device to device. One row per item (opening it again moves it to
--     the top); the API keeps the newest 20 per person and project and deletes the rest as it
--     writes. Nothing to purge: it never grows past that.
--
-- Table grants come from the schema's default privileges. Idempotent; safe to re-run on every
-- deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS projects.prj_bookmarks (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    project_id     text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    folder_id      text REFERENCES projects.prj_folders (id) ON DELETE SET NULL,
    title          text NOT NULL CHECK (btrim(title) <> '' AND length(title) <= 200),
    url            text CHECK (url IS NULL OR (url ~* '^https?://' AND length(url) <= 2000)),
    target_kind    text CHECK (target_kind IS NULL OR target_kind IN ('task', 'doc', 'board', 'folder')),
    target_id      text,
    position       integer NOT NULL DEFAULT 0,
    created_by     text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    -- Exactly one of: a URL, or an item in the project.
    CHECK ((url IS NOT NULL AND target_kind IS NULL AND target_id IS NULL)
        OR (url IS NULL AND target_kind IS NOT NULL AND target_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS prj_bookmarks_project_idx ON projects.prj_bookmarks (project_id, folder_id, position);
CREATE INDEX IF NOT EXISTS prj_bookmarks_tenant_idx ON projects.prj_bookmarks (tenant_id, bus_id);

CREATE TABLE IF NOT EXISTS projects.prj_recent_items (
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    user_id        text NOT NULL,
    project_id     text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    kind           text NOT NULL CHECK (kind IN ('task', 'doc', 'board', 'folder')),
    ref_id         text NOT NULL,
    opened_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, user_id, project_id, kind, ref_id)
);
CREATE INDEX IF NOT EXISTS prj_recent_items_user_idx ON projects.prj_recent_items (tenant_id, user_id, project_id, opened_at DESC);

COMMIT;
