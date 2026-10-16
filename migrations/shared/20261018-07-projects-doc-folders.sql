-- Projects: folders for Docs.
--
--   * prj_doc_folders: folders in a workspace's Docs, nested to any depth, to arrange pages.
--     Shared with the workspace (a folder holds nothing secret: a private page in it is still
--     seen only by its author).
--   * prj_docs.folder_id: the folder a top-level page sits in (NULL: none). Pages inside other
--     pages go where their parent goes. Deleting a folder moves what is in it up a level.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS projects.prj_doc_folders (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    workspace_id  text NOT NULL REFERENCES projects.prj_workspaces (id) ON DELETE CASCADE,
    parent_id     text REFERENCES projects.prj_doc_folders (id) ON DELETE SET NULL,
    name          text NOT NULL CHECK (btrim(name) <> ''),
    position      integer NOT NULL DEFAULT 0,
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    CHECK (parent_id IS NULL OR parent_id <> id)
);
CREATE INDEX IF NOT EXISTS prj_doc_folders_ws_idx ON projects.prj_doc_folders (tenant_id, workspace_id);

ALTER TABLE projects.prj_docs ADD COLUMN IF NOT EXISTS folder_id text REFERENCES projects.prj_doc_folders (id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS prj_docs_folder_idx ON projects.prj_docs (folder_id) WHERE folder_id IS NOT NULL;

COMMIT;
