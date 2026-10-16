-- Projects: Docs -- pages and a wiki inside each workspace.
--
--   * prj_docs: a page. It lives in a workspace, optionally belongs to a project, and nests
--     under another page (parent_id) as deep as people like. content is the editor's document
--     (JSON, so live co-editing can be added later without converting anything); text is its
--     words, for search. visibility 'workspace' follows the workspace (and the project, when it
--     has one); 'private' is its author's alone. Deleting moves a page and everything under it to
--     the trash (deleted_at), from where it can be restored.
--     One person edits at a time: locked_by/locked_until is that person's hold, renewed while
--     they type and released when they leave; anyone else reads.
--   * prj_doc_versions: what a page was, kept as people edit (a new version when a different
--     person saves, or ten minutes after the last one), so any earlier state can be restored.
--   * prj_doc_favorites: pages a person has starred.
--   * prj_doc_task_links: work items a page mentions (WEB-12), so a work item can show the
--     docs that mention it.
--   * prj_doc_files: images and files put in a page; bytes in Projects' storage account.
--   * prj_notifications.doc_id: being @mentioned in a page rings the bell (and emails) like
--     being mentioned on a work item; the bell opens the page.
--   * permissions projects|docs|<get|create|update|delete>: managers all, members all but
--     delete, viewers get.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS projects.prj_docs (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    org_id         text,
    bus_id         text NOT NULL,
    workspace_id   text NOT NULL REFERENCES projects.prj_workspaces (id) ON DELETE CASCADE,
    project_id     text REFERENCES projects.prj_projects (id) ON DELETE SET NULL,
    parent_id      text REFERENCES projects.prj_docs (id) ON DELETE CASCADE,
    title          text NOT NULL DEFAULT '',
    icon           text NOT NULL DEFAULT '',
    content        jsonb NOT NULL DEFAULT '{"type":"doc","content":[]}'::jsonb,
    text           text NOT NULL DEFAULT '',
    visibility     text NOT NULL DEFAULT 'workspace' CHECK (visibility IN ('workspace', 'private')),
    position       integer NOT NULL DEFAULT 0,
    locked_by      text,
    locked_until   timestamptz,
    created_by     text,
    updated_by     text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    deleted_at     timestamptz,
    deleted_by     text,
    CHECK (parent_id IS DISTINCT FROM id)
);
CREATE INDEX IF NOT EXISTS prj_docs_tree_idx ON projects.prj_docs (tenant_id, workspace_id, parent_id, position) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS prj_docs_project_idx ON projects.prj_docs (project_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS prj_docs_search_idx ON projects.prj_docs
    USING gin (to_tsvector('simple', title || ' ' || text)) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS projects.prj_doc_versions (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    doc_id         text NOT NULL REFERENCES projects.prj_docs (id) ON DELETE CASCADE,
    number         integer NOT NULL,
    title          text NOT NULL,
    icon           text NOT NULL DEFAULT '',
    content        jsonb NOT NULL,
    text           text NOT NULL DEFAULT '',
    edited_by      text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (doc_id, number)
);

CREATE TABLE IF NOT EXISTS projects.prj_doc_favorites (
    doc_id         text NOT NULL REFERENCES projects.prj_docs (id) ON DELETE CASCADE,
    tenant_id      text NOT NULL,
    user_id        text NOT NULL,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (doc_id, user_id)
);

CREATE TABLE IF NOT EXISTS projects.prj_doc_task_links (
    doc_id         text NOT NULL REFERENCES projects.prj_docs (id) ON DELETE CASCADE,
    task_id        text NOT NULL REFERENCES projects.prj_tasks (id) ON DELETE CASCADE,
    tenant_id      text NOT NULL,
    PRIMARY KEY (doc_id, task_id)
);
CREATE INDEX IF NOT EXISTS prj_doc_task_links_task_idx ON projects.prj_doc_task_links (task_id);

CREATE TABLE IF NOT EXISTS projects.prj_doc_files (
    id             text PRIMARY KEY,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    doc_id         text NOT NULL REFERENCES projects.prj_docs (id) ON DELETE CASCADE,
    file_name      text NOT NULL,
    content_type   text NOT NULL,
    size_bytes     bigint NOT NULL CHECK (size_bytes >= 0),
    blob_path      text NOT NULL,
    uploaded_by    text,
    cdatetime      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prj_doc_files_doc_idx ON projects.prj_doc_files (doc_id);

ALTER TABLE projects.prj_notifications ADD COLUMN IF NOT EXISTS doc_id text REFERENCES projects.prj_docs (id) ON DELETE CASCADE;

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-projects-docs', 'Projects Docs', 'Docs and wiki pages', 'rt-subscribed-app-projects')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(action, label) AS (VALUES
    ('get',    'Read docs'),
    ('create', 'Create docs'),
    ('update', 'Edit, move and restore docs'),
    ('delete', 'Delete docs')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-projects-docs-' || spec.action, 'Projects Docs ' || initcap(spec.action), 'rt-projects-docs',
       spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name = EXCLUDED.permission_name, description = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'projects', resource_key = 'docs', action = substring(p.id FROM '-([a-z]+)$'), target = '', scope = 'any'
 WHERE p.id LIKE 'permission-projects-docs-%' AND (p.app_prefix IS DISTINCT FROM 'projects' OR p.action IS NULL);

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', g.role_id, p.id, r.role_name || ' can ' || lower(p.description), CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (VALUES ('role-projects-manager', 'get'), ('role-projects-manager', 'create'), ('role-projects-manager', 'update'), ('role-projects-manager', 'delete'),
               ('role-projects-member', 'get'), ('role-projects-member', 'create'), ('role-projects-member', 'update'),
               ('role-projects-viewer', 'get')) AS g(role_id, action)
  JOIN core_platform.cp_roles r ON r.id = g.role_id
  JOIN core_platform.cp_permissions p ON p.app_prefix = 'projects' AND p.resource_key = 'docs' AND p.action = g.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM core_platform.cp_permissions p WHERE p.app_prefix = 'projects'
                AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                                 WHERE rp.role_id = 'role-projects-manager' AND rp.permission_id = p.id)) THEN
        RAISE EXCEPTION 'role-projects-manager lacks a Projects permission';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions WHERE role_id = 'role-projects-viewer' AND permission_id = 'permission-projects-docs-get') THEN
        RAISE EXCEPTION 'viewers cannot read docs';
    END IF;
END $$;

COMMIT;
