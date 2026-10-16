-- Projects: workspaces.
--
-- A workspace is the top of Projects inside a business: a team's own place, with its own
-- projects, members and everything under them. People switch between them at the logo.
--
--   * prj_workspaces: name, icon, colour, open to the business or members only, an owner.
--     One per business is the default ("General"): it cannot be deleted, and work made
--     before workspaces existed lives in it.
--   * prj_workspace_members.
--   * prj_projects.workspace_id: every project is in exactly one workspace. Project keys stay
--     unique across the business, so WEB-12 means one thing wherever it is pasted.
--   * permissions projects|workspaces|<action>||any, granted to the roles.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS projects.prj_workspaces (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    org_id         text,
    bus_id         text NOT NULL,
    name           text NOT NULL CHECK (btrim(name) <> ''),
    description    text NOT NULL DEFAULT '',
    -- A short mark for the switcher: an emoji or up to two letters.
    icon           text NOT NULL DEFAULT '',
    color          text NOT NULL DEFAULT 'amber',
    visibility     text NOT NULL DEFAULT 'business' CHECK (visibility IN ('business', 'members')),
    owner_user_id  text,
    is_default     boolean NOT NULL DEFAULT false,
    status         text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
    created_by     text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    delete_status  text NOT NULL DEFAULT 'NOT_DELETED'
);
CREATE UNIQUE INDEX IF NOT EXISTS prj_workspaces_name_uq
    ON projects.prj_workspaces (tenant_id, bus_id, lower(name)) WHERE delete_status = 'NOT_DELETED';
CREATE UNIQUE INDEX IF NOT EXISTS prj_workspaces_default_uq
    ON projects.prj_workspaces (tenant_id, bus_id) WHERE is_default AND delete_status = 'NOT_DELETED';

CREATE TABLE IF NOT EXISTS projects.prj_workspace_members (
    workspace_id  text NOT NULL REFERENCES projects.prj_workspaces (id) ON DELETE CASCADE,
    tenant_id     text NOT NULL,
    user_id       text NOT NULL,
    added_by      text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, user_id)
);
CREATE INDEX IF NOT EXISTS prj_workspace_members_user_idx ON projects.prj_workspace_members (tenant_id, user_id);

ALTER TABLE projects.prj_projects ADD COLUMN IF NOT EXISTS workspace_id text REFERENCES projects.prj_workspaces (id);
CREATE INDEX IF NOT EXISTS prj_projects_workspace_idx ON projects.prj_projects (workspace_id) WHERE delete_status = 'NOT_DELETED';

-- Every business that has projects gets its default workspace, and its projects go in it.
INSERT INTO projects.prj_workspaces (tenant_id, org_id, bus_id, name, description, icon, is_default)
SELECT DISTINCT ON (p.tenant_id, p.bus_id) p.tenant_id, p.org_id, p.bus_id, 'General', 'Everyone''s work, until it has a home of its own.', 'G', true
  FROM projects.prj_projects p
 WHERE NOT EXISTS (SELECT 1 FROM projects.prj_workspaces w
                    WHERE w.tenant_id = p.tenant_id AND w.bus_id = p.bus_id AND w.is_default AND w.delete_status = 'NOT_DELETED')
ON CONFLICT DO NOTHING;

UPDATE projects.prj_projects p
   SET workspace_id = w.id
  FROM projects.prj_workspaces w
 WHERE p.workspace_id IS NULL
   AND w.tenant_id = p.tenant_id AND w.bus_id = p.bus_id AND w.is_default AND w.delete_status = 'NOT_DELETED';

ALTER TABLE projects.prj_projects ALTER COLUMN workspace_id SET NOT NULL;

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-projects-workspaces', 'Projects Workspaces', 'Workspaces: a team''s own place in Projects', 'rt-subscribed-app-projects')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(action, label) AS (VALUES
    ('get',    'View workspaces'),
    ('create', 'Create workspaces'),
    ('update', 'Edit workspaces and their members'),
    ('delete', 'Delete workspaces')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-projects-workspaces-' || spec.action, 'Projects Workspaces ' || initcap(spec.action), 'rt-projects-workspaces',
       spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name = EXCLUDED.permission_name, description = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'projects', resource_key = 'workspaces', action = substring(p.id FROM '-([a-z]+)$'), target = '', scope = 'any'
 WHERE p.id LIKE 'permission-projects-workspaces-%' AND (p.app_prefix IS DISTINCT FROM 'projects' OR p.action IS NULL);

-- The manager everything; member and viewer may see the workspaces they are in.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', g.role_id, p.id, r.role_name || ' can ' || lower(p.description), CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (VALUES ('role-projects-manager', 'get'), ('role-projects-manager', 'create'), ('role-projects-manager', 'update'),
               ('role-projects-manager', 'delete'), ('role-projects-member', 'get'), ('role-projects-viewer', 'get')) AS g(role_id, action)
  JOIN core_platform.cp_roles r ON r.id = g.role_id
  JOIN core_platform.cp_permissions p ON p.app_prefix = 'projects' AND p.resource_key = 'workspaces' AND p.action = g.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM projects.prj_projects WHERE workspace_id IS NULL) THEN
        RAISE EXCEPTION 'a project has no workspace';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_permissions p WHERE p.app_prefix = 'projects'
                AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                                 WHERE rp.role_id = 'role-projects-manager' AND rp.permission_id = p.id)) THEN
        RAISE EXCEPTION 'role-projects-manager lacks a Projects permission';
    END IF;
END $$;

COMMIT;
