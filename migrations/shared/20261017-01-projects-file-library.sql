-- Projects: a file library per project, in folders.
--
--   * prj_attachments gains project_id and folder_id, and task_id becomes optional: a file is
--     a project's, attached to one of its work items or uploaded straight to the project. Every
--     existing file takes its work item's project.
--   * prj_file_folders: folders in a project's library, nested as deep as people like.
--     Deleting a folder moves what was in it (files and folders) up a level; no file is lost.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE projects.prj_attachments ADD COLUMN IF NOT EXISTS project_id text REFERENCES projects.prj_projects (id) ON DELETE CASCADE;
UPDATE projects.prj_attachments a SET project_id = t.project_id
  FROM projects.prj_tasks t WHERE t.id = a.task_id AND a.project_id IS NULL;
ALTER TABLE projects.prj_attachments ALTER COLUMN project_id SET NOT NULL;
ALTER TABLE projects.prj_attachments ALTER COLUMN task_id DROP NOT NULL;

CREATE TABLE IF NOT EXISTS projects.prj_file_folders (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    project_id     text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    parent_id      text REFERENCES projects.prj_file_folders (id) ON DELETE CASCADE,
    name           text NOT NULL CHECK (btrim(name) <> ''),
    created_by     text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    CHECK (parent_id IS DISTINCT FROM id)
);
CREATE INDEX IF NOT EXISTS prj_file_folders_project_idx ON projects.prj_file_folders (project_id, parent_id);
CREATE UNIQUE INDEX IF NOT EXISTS prj_file_folders_name_uq ON projects.prj_file_folders (project_id, coalesce(parent_id, ''), lower(name));

ALTER TABLE projects.prj_attachments ADD COLUMN IF NOT EXISTS folder_id text REFERENCES projects.prj_file_folders (id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS prj_attachments_library_idx ON projects.prj_attachments (project_id, folder_id) WHERE delete_status = 'NOT_DELETED';

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM projects.prj_attachments a JOIN projects.prj_tasks t ON t.id = a.task_id WHERE t.project_id <> a.project_id) THEN
        RAISE EXCEPTION 'a work item''s file is in another project''s library';
    END IF;
END $$;

COMMIT;
