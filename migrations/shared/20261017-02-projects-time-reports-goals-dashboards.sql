-- Projects, release 7: time tracking, sprint reports, goals (OKRs) and dashboards.
--
--   * prj_tasks.time_estimate_minutes: how long a work item should take, beside its points.
--   * prj_worklogs: time someone spent on a work item, on a day. prj_timers: the one item each
--     person has a clock running on.
--   * prj_sprint_tasks: when each work item came into and left each sprint, kept by a trigger on
--     prj_tasks.sprint_id. Completing a sprint moves its unfinished work out, so without this a
--     finished sprint's burndown and commitment could not be drawn. prj_sprints.started_at is
--     the moment it started (starts_on is only a date).
--   * prj_goals / prj_key_results / prj_kr_work / prj_kr_checkins: objectives for a period in a
--     workspace, aligned under one another, each measured by key results -- a number moved from
--     a start to a target, or the share of linked work that is done -- with check-ins.
--   * prj_dashboards / prj_dashboard_widgets: dashboards people build from widgets, private or
--     shared with the workspace.
--   * permissions projects|goals|<get|create|update|delete>: managers all, members all but
--     delete, viewers get.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

-- ===================================================================== time
ALTER TABLE projects.prj_tasks ADD COLUMN IF NOT EXISTS time_estimate_minutes integer
    CHECK (time_estimate_minutes IS NULL OR time_estimate_minutes >= 0);

CREATE TABLE IF NOT EXISTS projects.prj_worklogs (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    task_id     text NOT NULL REFERENCES projects.prj_tasks (id) ON DELETE CASCADE,
    project_id  text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    user_id     text NOT NULL,
    work_date   date NOT NULL,
    minutes     integer NOT NULL CHECK (minutes > 0 AND minutes <= 1440),
    note        text NOT NULL DEFAULT '',
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prj_worklogs_task_idx    ON projects.prj_worklogs (task_id, work_date);
CREATE INDEX IF NOT EXISTS prj_worklogs_user_idx    ON projects.prj_worklogs (tenant_id, user_id, work_date);
CREATE INDEX IF NOT EXISTS prj_worklogs_project_idx ON projects.prj_worklogs (project_id, work_date);

CREATE TABLE IF NOT EXISTS projects.prj_timers (
    tenant_id   text NOT NULL,
    user_id     text NOT NULL,
    task_id     text NOT NULL REFERENCES projects.prj_tasks (id) ON DELETE CASCADE,
    started_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, user_id)
);

-- ===================================================================== sprint membership
ALTER TABLE projects.prj_sprints ADD COLUMN IF NOT EXISTS started_at timestamptz;
UPDATE projects.prj_sprints SET started_at = coalesce(starts_on::timestamptz, cdatetime)
 WHERE started_at IS NULL AND status IN ('active', 'closed');

CREATE TABLE IF NOT EXISTS projects.prj_sprint_tasks (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    sprint_id   text NOT NULL REFERENCES projects.prj_sprints (id) ON DELETE CASCADE,
    task_id     text NOT NULL REFERENCES projects.prj_tasks (id) ON DELETE CASCADE,
    added_at    timestamptz NOT NULL DEFAULT now(),
    removed_at  timestamptz,
    CHECK (removed_at IS NULL OR removed_at >= added_at)
);
CREATE INDEX IF NOT EXISTS prj_sprint_tasks_sprint_idx ON projects.prj_sprint_tasks (sprint_id);
-- A work item is in a sprint once at a time.
CREATE UNIQUE INDEX IF NOT EXISTS prj_sprint_tasks_open_uq ON projects.prj_sprint_tasks (task_id) WHERE removed_at IS NULL;

CREATE OR REPLACE FUNCTION projects.prj_track_sprint() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.sprint_id IS NOT DISTINCT FROM NEW.sprint_id THEN
        RETURN NEW;
    END IF;
    UPDATE projects.prj_sprint_tasks SET removed_at = now() WHERE task_id = NEW.id AND removed_at IS NULL;
    IF NEW.sprint_id IS NOT NULL THEN
        INSERT INTO projects.prj_sprint_tasks (tenant_id, sprint_id, task_id) VALUES (NEW.tenant_id, NEW.sprint_id, NEW.id);
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS prj_track_sprint ON projects.prj_tasks;
CREATE TRIGGER prj_track_sprint AFTER INSERT OR UPDATE OF sprint_id ON projects.prj_tasks
    FOR EACH ROW EXECUTE FUNCTION projects.prj_track_sprint();

-- What is in a sprint now came in when the item was made, or when the sprint started if later
-- than that is unknowable -- the earlier of the two, so it counts as committed.
INSERT INTO projects.prj_sprint_tasks (tenant_id, sprint_id, task_id, added_at)
SELECT t.tenant_id, t.sprint_id, t.id, least(t.cdatetime, coalesce(sp.started_at, t.cdatetime))
  FROM projects.prj_tasks t JOIN projects.prj_sprints sp ON sp.id = t.sprint_id
 WHERE NOT EXISTS (SELECT 1 FROM projects.prj_sprint_tasks x WHERE x.task_id = t.id AND x.removed_at IS NULL);

-- ===================================================================== goals
CREATE TABLE IF NOT EXISTS projects.prj_goals (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    workspace_id   text NOT NULL REFERENCES projects.prj_workspaces (id) ON DELETE CASCADE,
    -- The goal this one supports.
    parent_id      text REFERENCES projects.prj_goals (id) ON DELETE SET NULL,
    title          text NOT NULL CHECK (btrim(title) <> ''),
    description    text NOT NULL DEFAULT '',
    owner_user_id  text,
    -- 2026-Q4, 2026-H2 or 2026.
    period         text NOT NULL CHECK (period ~ '^[0-9]{4}(-Q[1-4]|-H[12])?$'),
    status         text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'achieved', 'missed', 'dropped')),
    created_by     text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    delete_status  text NOT NULL DEFAULT 'NOT_DELETED',
    CHECK (parent_id IS DISTINCT FROM id)
);
CREATE INDEX IF NOT EXISTS prj_goals_ws_idx ON projects.prj_goals (tenant_id, workspace_id, period) WHERE delete_status = 'NOT_DELETED';

CREATE TABLE IF NOT EXISTS projects.prj_key_results (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    goal_id        text NOT NULL REFERENCES projects.prj_goals (id) ON DELETE CASCADE,
    title          text NOT NULL CHECK (btrim(title) <> ''),
    -- number: from start to target in a unit; percent and money likewise; done: yes or no;
    -- work: the share of linked work items that is done.
    measure        text NOT NULL DEFAULT 'number' CHECK (measure IN ('number', 'percent', 'money', 'done', 'work')),
    start_value    numeric(18, 2) NOT NULL DEFAULT 0,
    target_value   numeric(18, 2) NOT NULL DEFAULT 100,
    current_value  numeric(18, 2) NOT NULL DEFAULT 0,
    unit           text NOT NULL DEFAULT '',
    owner_user_id  text,
    -- The latest check-in's word for it.
    confidence     text CHECK (confidence IS NULL OR confidence IN ('on_track', 'at_risk', 'off_track')),
    rank           double precision NOT NULL DEFAULT 0,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prj_key_results_goal_idx ON projects.prj_key_results (goal_id, rank);

CREATE TABLE IF NOT EXISTS projects.prj_kr_work (
    kr_id      text NOT NULL REFERENCES projects.prj_key_results (id) ON DELETE CASCADE,
    task_id    text NOT NULL REFERENCES projects.prj_tasks (id) ON DELETE CASCADE,
    tenant_id  text NOT NULL,
    cdatetime  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (kr_id, task_id)
);
CREATE INDEX IF NOT EXISTS prj_kr_work_task_idx ON projects.prj_kr_work (task_id);

CREATE TABLE IF NOT EXISTS projects.prj_kr_checkins (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    kr_id       text NOT NULL REFERENCES projects.prj_key_results (id) ON DELETE CASCADE,
    value       numeric(18, 2),
    confidence  text NOT NULL CHECK (confidence IN ('on_track', 'at_risk', 'off_track')),
    note        text NOT NULL DEFAULT '',
    user_id     text,
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prj_kr_checkins_kr_idx ON projects.prj_kr_checkins (kr_id, cdatetime DESC);

-- ===================================================================== dashboards
CREATE TABLE IF NOT EXISTS projects.prj_dashboards (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    workspace_id   text NOT NULL REFERENCES projects.prj_workspaces (id) ON DELETE CASCADE,
    name           text NOT NULL CHECK (btrim(name) <> ''),
    description    text NOT NULL DEFAULT '',
    owner_user_id  text NOT NULL,
    -- Shared: everyone in the workspace sees it; only its owner changes it.
    shared         boolean NOT NULL DEFAULT false,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prj_dashboards_ws_idx ON projects.prj_dashboards (tenant_id, workspace_id);

CREATE TABLE IF NOT EXISTS projects.prj_dashboard_widgets (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    dashboard_id  text NOT NULL REFERENCES projects.prj_dashboards (id) ON DELETE CASCADE,
    kind          text NOT NULL CHECK (kind IN ('count', 'breakdown', 'list', 'created_done', 'burndown', 'velocity', 'time', 'goals')),
    title         text NOT NULL DEFAULT '',
    config        jsonb NOT NULL DEFAULT '{}'::jsonb,
    -- Columns of three it spans.
    width         smallint NOT NULL DEFAULT 1 CHECK (width BETWEEN 1 AND 3),
    rank          double precision NOT NULL DEFAULT 0,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prj_dashboard_widgets_dash_idx ON projects.prj_dashboard_widgets (dashboard_id, rank);

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-projects-goals', 'Projects Goals', 'Goals and key results (OKRs)', 'rt-subscribed-app-projects')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(action, label) AS (VALUES
    ('get',    'See goals'),
    ('create', 'Create goals'),
    ('update', 'Edit goals and check in on key results'),
    ('delete', 'Delete goals')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-projects-goals-' || spec.action, 'Projects Goals ' || initcap(spec.action), 'rt-projects-goals',
       spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name = EXCLUDED.permission_name, description = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'projects', resource_key = 'goals', action = substring(p.id FROM '-([a-z]+)$'), target = '', scope = 'any'
 WHERE p.id LIKE 'permission-projects-goals-%' AND (p.app_prefix IS DISTINCT FROM 'projects' OR p.action IS NULL);

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', g.role_id, p.id, r.role_name || ' can ' || lower(p.description), CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (VALUES ('role-projects-manager', 'get'), ('role-projects-manager', 'create'), ('role-projects-manager', 'update'), ('role-projects-manager', 'delete'),
               ('role-projects-member', 'get'), ('role-projects-member', 'create'), ('role-projects-member', 'update'),
               ('role-projects-viewer', 'get')) AS g(role_id, action)
  JOIN core_platform.cp_roles r ON r.id = g.role_id
  JOIN core_platform.cp_permissions p ON p.app_prefix = 'projects' AND p.resource_key = 'goals' AND p.action = g.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM core_platform.cp_permissions p WHERE p.app_prefix = 'projects'
                AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                                 WHERE rp.role_id = 'role-projects-manager' AND rp.permission_id = p.id)) THEN
        RAISE EXCEPTION 'role-projects-manager lacks a Projects permission';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions WHERE role_id = 'role-projects-viewer' AND permission_id = 'permission-projects-goals-get') THEN
        RAISE EXCEPTION 'viewers cannot see goals';
    END IF;
    IF EXISTS (SELECT 1 FROM projects.prj_tasks t WHERE t.sprint_id IS NOT NULL
                AND NOT EXISTS (SELECT 1 FROM projects.prj_sprint_tasks x WHERE x.task_id = t.id AND x.sprint_id = t.sprint_id AND x.removed_at IS NULL)) THEN
        RAISE EXCEPTION 'a work item in a sprint has no record of joining it';
    END IF;
END $$;

COMMIT;
