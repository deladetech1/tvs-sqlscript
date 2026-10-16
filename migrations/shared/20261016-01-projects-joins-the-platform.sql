-- Projects joins the platform: the project manager, Release 1 (projects and tasks).
--
-- Served by the shared apps backend (deladetech1/tvs-shared-apps-bk, module "projects")
-- like the CRM. Its cp_apps row and tier prices live in the CorePlatform seed
-- (04_others.sql), which owns every app row. This file holds the rest:
--
--   * the projects schema and its tables (prj_*), every row carrying tenant_id, org_id
--     and bus_id;
--   * its cp_app_schemas row, so activity-log retention finds projects.prj_audit_logs;
--   * resource types, permissions (projects|<resource>|<action>||any) and the roles:
--     Projects Admin is allowed by BEING the role (tvs-package-go appAdminRoles) and holds
--     no Projects rows; Project Manager, Member and Viewer carry explicit grants;
--   * the reserved label "projects" and the frontend's route row.
--
-- How a project is reached: business roles say what someone may do; a project whose
-- visibility is 'members' is seen only by its members (and by whoever may manage every
-- project). Work items are numbered per project and shown as <KEY>-<number>.
--
-- Nothing here asserts on rows a module seed creates: a shared file runs on deploys that
-- did not run the CorePlatform seed. Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE SCHEMA IF NOT EXISTS projects;

INSERT INTO core_platform.cp_app_schemas (app_id, schema_name, description)
VALUES ('app-projects', 'projects', 'Projects audit logs')
ON CONFLICT (app_id) DO UPDATE SET schema_name = EXCLUDED.schema_name,
                                   description = EXCLUDED.description;

-- ========================================================================= tables

CREATE TABLE IF NOT EXISTS projects.prj_projects (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    org_id         text,
    bus_id         text NOT NULL,
    -- Short and upper case; the prefix of every work item's key (WEB-12).
    key            text NOT NULL CHECK (key ~ '^[A-Z][A-Z0-9]{1,9}$'),
    name           text NOT NULL CHECK (btrim(name) <> ''),
    description    text NOT NULL DEFAULT '',
    -- kanban: a board. scrum: a backlog and sprints as well.
    template       text NOT NULL DEFAULT 'kanban' CHECK (template IN ('kanban', 'scrum')),
    visibility     text NOT NULL DEFAULT 'business' CHECK (visibility IN ('business', 'members')),
    lead_user_id   text,
    color          text NOT NULL DEFAULT 'cyan',
    -- The last number given to a work item; the next one is this plus one.
    last_number    integer NOT NULL DEFAULT 0,
    status         text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
    created_by     text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    delete_status  text NOT NULL DEFAULT 'NOT_DELETED'
);
CREATE UNIQUE INDEX IF NOT EXISTS prj_projects_key_uq
    ON projects.prj_projects (tenant_id, bus_id, key) WHERE delete_status = 'NOT_DELETED';
CREATE INDEX IF NOT EXISTS prj_projects_bus_idx ON projects.prj_projects (tenant_id, bus_id, status);

CREATE TABLE IF NOT EXISTS projects.prj_members (
    project_id  text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    tenant_id   text NOT NULL,
    user_id     text NOT NULL,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    added_by    text,
    PRIMARY KEY (project_id, user_id)
);
CREATE INDEX IF NOT EXISTS prj_members_user_idx ON projects.prj_members (tenant_id, user_id);

CREATE TABLE IF NOT EXISTS projects.prj_statuses (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    project_id  text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    name        text NOT NULL CHECK (btrim(name) <> ''),
    -- What the status means, whatever it is called: done is what counts as finished.
    category    text NOT NULL CHECK (category IN ('todo', 'in_progress', 'done')),
    position    integer NOT NULL DEFAULT 0,
    -- A column's work-in-progress limit; the board warns past it, never refuses.
    wip_limit   integer CHECK (wip_limit IS NULL OR wip_limit > 0),
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS prj_statuses_name_uq ON projects.prj_statuses (project_id, lower(name));

CREATE TABLE IF NOT EXISTS projects.prj_sprints (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    project_id  text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    name        text NOT NULL CHECK (btrim(name) <> ''),
    goal        text NOT NULL DEFAULT '',
    starts_on   date,
    ends_on     date,
    status      text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned', 'active', 'closed')),
    closed_at   timestamptz,
    created_by  text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    CHECK (ends_on IS NULL OR starts_on IS NULL OR ends_on >= starts_on)
);
-- One sprint runs at a time in a project.
CREATE UNIQUE INDEX IF NOT EXISTS prj_sprints_one_active_uq
    ON projects.prj_sprints (project_id) WHERE status = 'active';

CREATE TABLE IF NOT EXISTS projects.prj_tasks (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    project_id        text NOT NULL REFERENCES projects.prj_projects (id),
    number            integer NOT NULL,
    kind              text NOT NULL DEFAULT 'task' CHECK (kind IN ('epic', 'story', 'task', 'bug', 'subtask')),
    title             text NOT NULL CHECK (btrim(title) <> ''),
    description       text NOT NULL DEFAULT '',
    status_id         text NOT NULL REFERENCES projects.prj_statuses (id),
    priority          text NOT NULL DEFAULT 'medium' CHECK (priority IN ('urgent', 'high', 'medium', 'low')),
    assignee_user_id  text,
    reporter_user_id  text,
    -- An epic's stories and tasks, or a task's subtasks.
    parent_id         text REFERENCES projects.prj_tasks (id),
    sprint_id         text REFERENCES projects.prj_sprints (id) ON DELETE SET NULL,
    start_date        date,
    due_date          date,
    -- Story points, or whatever unit the team estimates in.
    estimate          numeric(8, 2) CHECK (estimate IS NULL OR estimate >= 0),
    labels            text[] NOT NULL DEFAULT '{}',
    -- Order on the board and in the backlog: smaller first, gaps allowed.
    rank              double precision NOT NULL DEFAULT 0,
    -- Repeating work: when this one is done, the next is created due one step later.
    repeat_every      text CHECK (repeat_every IS NULL OR repeat_every IN ('day', 'week', 'month')),
    done_at           timestamptz,
    created_by        text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    delete_status     text NOT NULL DEFAULT 'NOT_DELETED',
    UNIQUE (project_id, number),
    CHECK (parent_id IS NULL OR parent_id <> id)
);
CREATE INDEX IF NOT EXISTS prj_tasks_board_idx    ON projects.prj_tasks (project_id, status_id, rank) WHERE delete_status = 'NOT_DELETED';
CREATE INDEX IF NOT EXISTS prj_tasks_assignee_idx ON projects.prj_tasks (tenant_id, bus_id, assignee_user_id) WHERE delete_status = 'NOT_DELETED';
CREATE INDEX IF NOT EXISTS prj_tasks_parent_idx   ON projects.prj_tasks (parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS prj_tasks_sprint_idx   ON projects.prj_tasks (sprint_id) WHERE sprint_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS prj_tasks_due_idx      ON projects.prj_tasks (tenant_id, bus_id, due_date) WHERE delete_status = 'NOT_DELETED' AND done_at IS NULL;

CREATE TABLE IF NOT EXISTS projects.prj_comments (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    task_id        text NOT NULL REFERENCES projects.prj_tasks (id) ON DELETE CASCADE,
    author_id      text NOT NULL,
    body           text NOT NULL CHECK (btrim(body) <> ''),
    -- Who the comment named with @, so they can be told.
    mentions       text[] NOT NULL DEFAULT '{}',
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    edited_at      timestamptz,
    delete_status  text NOT NULL DEFAULT 'NOT_DELETED'
);
CREATE INDEX IF NOT EXISTS prj_comments_task_idx ON projects.prj_comments (task_id, cdatetime);

CREATE TABLE IF NOT EXISTS projects.prj_watchers (
    task_id    text NOT NULL REFERENCES projects.prj_tasks (id) ON DELETE CASCADE,
    tenant_id  text NOT NULL,
    user_id    text NOT NULL,
    cdatetime  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (task_id, user_id)
);

CREATE TABLE IF NOT EXISTS projects.prj_links (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    -- from blocks to; relates and duplicates read the same either way round.
    from_task_id  text NOT NULL REFERENCES projects.prj_tasks (id) ON DELETE CASCADE,
    to_task_id    text NOT NULL REFERENCES projects.prj_tasks (id) ON DELETE CASCADE,
    kind          text NOT NULL CHECK (kind IN ('blocks', 'relates', 'duplicates')),
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    UNIQUE (from_task_id, to_task_id, kind),
    CHECK (from_task_id <> to_task_id)
);
CREATE INDEX IF NOT EXISTS prj_links_to_idx ON projects.prj_links (to_task_id);

CREATE TABLE IF NOT EXISTS projects.prj_checklist_items (
    id         text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id  text NOT NULL,
    task_id    text NOT NULL REFERENCES projects.prj_tasks (id) ON DELETE CASCADE,
    body       text NOT NULL CHECK (btrim(body) <> ''),
    done       boolean NOT NULL DEFAULT false,
    position   integer NOT NULL DEFAULT 0,
    done_by    text,
    done_at    timestamptz,
    cdatetime  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prj_checklist_task_idx ON projects.prj_checklist_items (task_id, position);

-- The audit trail: named *_audit_logs with tenant_id and cdatetime, so retention finds it.
CREATE TABLE IF NOT EXISTS projects.prj_audit_logs (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    org_id       text,
    bus_id       text,
    entity_type  text NOT NULL,
    entity_id    text NOT NULL,
    action       text NOT NULL,
    changes      jsonb NOT NULL DEFAULT '{}',
    actor_id     text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prj_audit_entity_idx
    ON projects.prj_audit_logs (tenant_id, entity_type, entity_id, cdatetime DESC);

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-subscribed-app-projects', 'PROJECTS APP', 'Projects Subscribed APP', NULL)
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-projects-projects', 'Projects Projects', 'Projects, their members, statuses and settings', 'rt-subscribed-app-projects'),
('rt-projects-tasks',    'Projects Tasks',    'Epics, stories, tasks, bugs and subtasks',        'rt-subscribed-app-projects'),
('rt-projects-comments', 'Projects Comments', 'Comments on work items',                          'rt-subscribed-app-projects'),
('rt-projects-sprints',  'Projects Sprints',  'Sprints and the backlog',                         'rt-subscribed-app-projects'),
('rt-projects-logs',     'Projects Logs',     'The audit trail of Projects',                     'rt-subscribed-app-projects')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('projects', 'rt-projects-projects', 'get',    'View projects'),
    ('projects', 'rt-projects-projects', 'create', 'Create projects'),
    ('projects', 'rt-projects-projects', 'update', 'Edit projects: members, statuses and settings'),
    ('projects', 'rt-projects-projects', 'delete', 'Delete projects'),
    ('projects', 'rt-projects-projects', 'manage', 'See and manage every project, private ones included'),
    ('tasks', 'rt-projects-tasks', 'get',    'View work items'),
    ('tasks', 'rt-projects-tasks', 'create', 'Create work items'),
    ('tasks', 'rt-projects-tasks', 'update', 'Edit and move work items'),
    ('tasks', 'rt-projects-tasks', 'delete', 'Delete work items'),
    ('tasks', 'rt-projects-tasks', 'assign', 'Change who a work item is assigned to'),
    ('tasks', 'rt-projects-tasks', 'import', 'Import work items'),
    ('tasks', 'rt-projects-tasks', 'export', 'Export work items'),
    ('comments', 'rt-projects-comments', 'create', 'Comment on work items'),
    ('comments', 'rt-projects-comments', 'delete', 'Delete other people''s comments'),
    ('sprints', 'rt-projects-sprints', 'get',    'View sprints and the backlog'),
    ('sprints', 'rt-projects-sprints', 'manage', 'Plan, start and complete sprints'),
    ('logs', 'rt-projects-logs', 'get', 'View the Projects audit trail')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-projects-' || spec.resource_key || '-' || spec.action,
       'Projects ' || initcap(replace(spec.resource_key, '-', ' ')) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

-- The pair every package checks: projects|<resource>|<action>||any.
UPDATE core_platform.cp_permissions p
   SET app_prefix = 'projects',
       resource_key = substring(p.id FROM '^permission-projects-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-projects-%'
   AND (p.app_prefix IS DISTINCT FROM 'projects' OR p.action IS NULL);

-- ========================================================================== roles
INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-subscribed-app-projects-admin', 'system-tenant-id', 'Projects Admin',  'Administrator of Projects: every Projects permission', 'rt-subscribed-app-projects', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-projects-manager', 'system-tenant-id', 'Project Manager', 'Runs projects: creates them, manages members, sprints and every work item, private projects included', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-projects-member',  'system-tenant-id', 'Project Member',  'Works in projects: creates, edits, moves and assigns work items, and comments', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-projects-viewer',  'system-tenant-id', 'Project Viewer',  'Reads projects, boards and work items; changes nothing', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name        = EXCLUDED.role_name,
                               description      = EXCLUDED.description,
                               resource_type_id = EXCLUDED.resource_type_id,
                               is_system        = EXCLUDED.is_system,
                               is_active        = EXCLUDED.is_active;

-- The manager holds every Projects permission; member and viewer a chosen set.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-projects-manager' AS role_id, p2.resource_key, p2.action
      FROM core_platform.cp_permissions p2 WHERE p2.app_prefix = 'projects'
    UNION ALL
    SELECT 'role-projects-member', k, a FROM (VALUES
        ('projects', 'get'), ('tasks', 'get'), ('tasks', 'create'), ('tasks', 'update'), ('tasks', 'assign'),
        ('tasks', 'export'), ('comments', 'create'), ('sprints', 'get')) AS m(k, a)
    UNION ALL
    SELECT 'role-projects-viewer', k, a FROM (VALUES
        ('projects', 'get'), ('tasks', 'get'), ('sprints', 'get')) AS v(k, a)
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'projects' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- The core-platform navigation block every app role seeds for itself.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', r.id, p.id
  FROM core_platform.cp_roles r
  JOIN core_platform.cp_permissions p
    ON p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations',
                'permission-user-get-locations')
 WHERE r.id IN ('role-subscribed-app-projects-admin', 'role-projects-manager', 'role-projects-member', 'role-projects-viewer')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ================================================================ label and routes
INSERT INTO control_plane.ctl_reserved_labels (label, reason, created_by)
SELECT v.label, v.reason, 'migration:20261016-01'
  FROM (VALUES ('projects', 'a product: projects.dev.trovesuite.com, the project manager')) AS v(label, reason)
 WHERE NOT EXISTS (SELECT 1 FROM control_plane.ctl_reserved_labels r WHERE r.label = v.label);

-- The container app's own address is already claimed by the CRM's migration (one container).
INSERT INTO control_plane.ctl_tenant_routes (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT h.host, NULL, 'POOLED', h.cell, 'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261016-01'
  FROM (VALUES ('projects.dev.trovesuite.com', 'uksouth-dev')) AS h(host, cell)
 WHERE EXISTS (SELECT 1 FROM control_plane.ctl_cells c WHERE c.cell_key = h.cell)
ON CONFLICT (host) DO NOTHING;

-- ===================================================================== invariants
DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions
     WHERE id LIKE 'permission-projects-%' AND (app_prefix <> 'projects' OR resource_key IS NULL OR action IS NULL);
    IF n > 0 THEN
        RAISE EXCEPTION '% Projects permission(s) have no pair; nothing would match them', n;
    END IF;
    -- A viewer changes nothing.
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-projects-viewer' AND p.app_prefix = 'projects' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-projects-viewer holds % Projects permission(s) that change data', n;
    END IF;
    -- A member neither deletes work nor sees private projects they are not in.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-projects-member' AND p.app_prefix = 'projects'
                  AND (p.action = 'delete' OR (p.resource_key = 'projects' AND p.action IN ('manage', 'create')))) THEN
        RAISE EXCEPTION 'role-projects-member holds a delete or project-wide permission';
    END IF;
    -- The manager lacks nothing.
    SELECT count(*) INTO n FROM core_platform.cp_permissions p
     WHERE p.app_prefix = 'projects' AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                        WHERE rp.role_id = 'role-projects-manager' AND rp.permission_id = p.id);
    IF n > 0 THEN
        RAISE EXCEPTION 'role-projects-manager lacks % Projects permission(s)', n;
    END IF;
    -- Projects Admin is allowed by being the role and holds no Projects rows.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-projects-admin' AND permission_id LIKE 'permission-projects-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-projects-admin holds Projects permission rows';
    END IF;
    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host = 'projects.dev.trovesuite.com' AND tenant_id IS NOT NULL) THEN
        RAISE EXCEPTION 'the Projects address has been given to a tenant';
    END IF;
END $$;

COMMIT;
