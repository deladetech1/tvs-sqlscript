-- Projects: custom fields and saved views.
--
--   * prj_fields: a project's own fields on its work items -- text, number, date, a choice,
--     several choices, a person, a checkbox or a link. options holds a choice field's choices
--     ([{"id":..,"label":..,"color":..}]); an option's id never changes, so renaming a choice
--     never loses the work items that chose it.
--   * prj_field_values: one value per work item and field, as JSON shaped by the field's kind
--     (a string, a number, "YYYY-MM-DD", an option id, a list of option ids, a user id, true).
--     A value is removed rather than stored empty.
--   * prj_views: a saved way of looking at work -- a query, list or board, sort, grouping and
--     columns. On a project (project_id) or across the workspace (project_id NULL). Shared
--     views are everyone's; the rest are their owner's alone.
--
-- Managing fields is project settings (projects|projects|update); filling them in is editing
-- work (projects|tasks|update). No new permissions.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS projects.prj_fields (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    project_id     text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    name           text NOT NULL CHECK (btrim(name) <> ''),
    kind           text NOT NULL CHECK (kind IN ('text', 'number', 'date', 'select', 'multi_select', 'person', 'checkbox', 'url')),
    options        jsonb NOT NULL DEFAULT '[]'::jsonb,
    description    text NOT NULL DEFAULT '',
    position       integer NOT NULL DEFAULT 0,
    created_by     text,
    cdatetime      timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS prj_fields_name_uq ON projects.prj_fields (project_id, lower(name));

CREATE TABLE IF NOT EXISTS projects.prj_field_values (
    task_id        text NOT NULL REFERENCES projects.prj_tasks (id) ON DELETE CASCADE,
    field_id       text NOT NULL REFERENCES projects.prj_fields (id) ON DELETE CASCADE,
    tenant_id      text NOT NULL,
    value          jsonb NOT NULL,
    updated_by     text,
    updated_at     timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (task_id, field_id)
);
CREATE INDEX IF NOT EXISTS prj_field_values_field_idx ON projects.prj_field_values (field_id);

CREATE TABLE IF NOT EXISTS projects.prj_views (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    workspace_id   text NOT NULL REFERENCES projects.prj_workspaces (id) ON DELETE CASCADE,
    project_id     text REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    name           text NOT NULL CHECK (btrim(name) <> ''),
    layout         text NOT NULL DEFAULT 'list' CHECK (layout IN ('list', 'board')),
    query          text NOT NULL DEFAULT '',
    sort           text NOT NULL DEFAULT 'updated',
    group_by       text NOT NULL DEFAULT '',
    columns        jsonb NOT NULL DEFAULT '[]'::jsonb,
    shared         boolean NOT NULL DEFAULT false,
    owner_user_id  text NOT NULL,
    position       integer NOT NULL DEFAULT 0,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prj_views_place_idx ON projects.prj_views (tenant_id, workspace_id, project_id);

COMMIT;
