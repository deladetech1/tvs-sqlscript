-- Core Platform: Workflows projects and nested folders.
--
-- The Workflows app groups a business's workflows the way a team thinks about them: PROJECTS
-- ("HR Management", "Finance"), each holding FOLDERS nested up to five deep, each workflow in a
-- project and optionally in one of its folders.
--
--   cp_workflow_projects   one per project, per BUSINESS (workflows are per business, so is what
--                          groups them; a project never mixes two businesses' workflows, and the
--                          business's Workflows subscription gates it like the workflows).
--                          is_default: the "General" project every workflow lands in when none
--                          is named; one per business, never deleted.
--   cp_workflow_folders    a folder of a project; parent_folder_id NULL = at the project's root.
--                          The depth limit (5) and cycle refusal are the service's
--                          (tvs-coreplatform-bk wf_projects.py).
--   cp_workflows           + project_id, folder_id (NULL = the project's root), sort_order.
--
-- Backfill: every business with workflows gets its "General" project, id
-- 'wfp-' || substr(md5(tenant_id || ':' || bus_id), 1, 20) -- the same id the backend makes on
-- demand, so the two never create two defaults -- and workflows with no project go into it.
--
-- Idempotent; re-runs every deploy. The backend tolerates every object here being missing (a silo
-- the shared SQL has not reached yet): the sidebar then lists workflows without projects.

BEGIN;

CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_projects (
    tenant_id    text        NOT NULL,
    id           text        NOT NULL,
    bus_id       text        NOT NULL,
    name         text        NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 80),
    color        text        NOT NULL DEFAULT 'indigo',
    icon         text        NOT NULL DEFAULT 'folder' CHECK (length(icon) <= 30),
    description  text        NOT NULL DEFAULT '',
    sort_order   integer     NOT NULL DEFAULT 0,
    is_default   boolean     NOT NULL DEFAULT false,
    created_by   text,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_by   text,
    updated_at   timestamptz NOT NULL DEFAULT now(),
    archived_at  timestamptz,
    PRIMARY KEY (tenant_id, id)
);
CREATE INDEX IF NOT EXISTS ix_cp_workflow_projects_bus
    ON core_platform.cp_workflow_projects (tenant_id, bus_id);
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_workflow_projects_default
    ON core_platform.cp_workflow_projects (tenant_id, bus_id) WHERE is_default AND archived_at IS NULL;

CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_folders (
    tenant_id         text        NOT NULL,
    id                text        NOT NULL,
    bus_id            text        NOT NULL,
    project_id        text        NOT NULL,
    parent_folder_id  text,
    name              text        NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 80),
    sort_order        integer     NOT NULL DEFAULT 0,
    created_by        text,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, id)
);
CREATE INDEX IF NOT EXISTS ix_cp_workflow_folders_project
    ON core_platform.cp_workflow_folders (tenant_id, project_id);
CREATE INDEX IF NOT EXISTS ix_cp_workflow_folders_parent
    ON core_platform.cp_workflow_folders (tenant_id, parent_folder_id);

ALTER TABLE core_platform.cp_workflows ADD COLUMN IF NOT EXISTS project_id text;
ALTER TABLE core_platform.cp_workflows ADD COLUMN IF NOT EXISTS folder_id text;
ALTER TABLE core_platform.cp_workflows ADD COLUMN IF NOT EXISTS sort_order integer NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS ix_cp_workflows_project
    ON core_platform.cp_workflows (tenant_id, bus_id, project_id) WHERE deleted_at IS NULL;

-- ===================================================================== backfill
INSERT INTO core_platform.cp_workflow_projects (tenant_id, id, bus_id, name, is_default)
SELECT DISTINCT w.tenant_id, 'wfp-' || substr(md5(w.tenant_id || ':' || w.bus_id), 1, 20), w.bus_id, 'General', true
  FROM core_platform.cp_workflows w
 WHERE NOT EXISTS (SELECT 1 FROM core_platform.cp_workflow_projects p
                    WHERE p.tenant_id = w.tenant_id AND p.bus_id = w.bus_id AND p.is_default AND p.archived_at IS NULL)
ON CONFLICT (tenant_id, id) DO NOTHING;

-- A folder that no longer exists (or sits in another project) leaves its workflows at the root.
UPDATE core_platform.cp_workflows w SET folder_id = NULL
 WHERE w.folder_id IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM core_platform.cp_workflow_folders f
                    WHERE f.tenant_id = w.tenant_id AND f.id = w.folder_id AND f.bus_id = w.bus_id
                      AND f.project_id IS NOT DISTINCT FROM w.project_id);

-- A workflow with no project (or one that is gone) goes into its business's default project.
UPDATE core_platform.cp_workflows w
   SET project_id = p.id, folder_id = NULL
  FROM core_platform.cp_workflow_projects p
 WHERE p.tenant_id = w.tenant_id AND p.bus_id = w.bus_id AND p.is_default AND p.archived_at IS NULL
   AND (w.project_id IS NULL
        OR NOT EXISTS (SELECT 1 FROM core_platform.cp_workflow_projects q
                        WHERE q.tenant_id = w.tenant_id AND q.id = w.project_id AND q.bus_id = w.bus_id));

COMMIT;
