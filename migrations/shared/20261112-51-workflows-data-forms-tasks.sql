-- Workflows: data tables, forms, tasks for people, and four new triggers (form submitted, a date is
-- coming up, nothing has happened for X days, an email arrives). Owner's pick 2026-11-12.
--
--   cp_wf_tables              a business's data table: typed columns (text, number, boolean, date,
--                             datetime, json, person) as JSON the backend validates, an optional key
--                             column (for "upsert by key"). Soft-deleted.
--   cp_wf_table_rows          its rows: data jsonb keyed by column key; key_value = the row's value in the
--                             key column (unique per table). Rows are capped per business by the
--                             Workflows tier (wf_tables.ROW_LIMITS: 1k / 10k / 100k).
--   cp_wf_forms               a form: fields (JSON), a public token (the shareable link), open/closed,
--                             sign-in required or not, a thank-you message.
--   cp_wf_form_submissions    every accepted submission (answers, files' stored paths, who when signed in,
--                             a salted hash of the address for the rate limit, the runs it started).
--   cp_wf_tasks               "Ask someone to fill in": a run parked on people until one of them submits
--                             (COMPLETED) or it runs out (EXPIRED); reminders and escalation.
--   cp_wf_trigger_fired       once per (workflow, key): a date trigger fires once per row and date value,
--                             a quiet-record trigger once per quiet spell -- across versions and replicas.
--   cp_wf_inbound_addresses   the token in a workflow's inbound email address (lower-case hex).
--
-- trigger_type: the CHECK lists for versions and runs moved HERE from 20261110-71 (a widened list
-- must live in one file, the newest; 71 re-adding the old list would fail once a 'form' row exists).
--
-- Permissions workflows|tables|get/manage and workflows|forms|get/manage, granted pair by pair; the
-- features workflows.tables / .forms / .tasks at BASIC.
--
-- The backend tolerates every object here being missing (a silo the shared SQL has not reached):
-- screens say "not set up yet", steps fail with words, the runtime's passes skip. Idempotent.

BEGIN;

-- ===================================================================== trigger types (owned here)
DO $$
BEGIN
    ALTER TABLE core_platform.cp_workflow_versions DROP CONSTRAINT IF EXISTS cp_workflow_versions_trigger_type_check;
    ALTER TABLE core_platform.cp_workflow_versions DROP CONSTRAINT IF EXISTS cp_workflow_versions_trigger_type_ck;
    ALTER TABLE core_platform.cp_workflow_versions ADD CONSTRAINT cp_workflow_versions_trigger_type_ck
        CHECK (trigger_type IN ('event', 'schedule', 'manual', 'webhook', 'form', 'date', 'stale', 'email'));
    ALTER TABLE core_platform.cp_workflow_runs DROP CONSTRAINT IF EXISTS cp_workflow_runs_trigger_type_check;
    ALTER TABLE core_platform.cp_workflow_runs DROP CONSTRAINT IF EXISTS cp_workflow_runs_trigger_type_ck;
    ALTER TABLE core_platform.cp_workflow_runs ADD CONSTRAINT cp_workflow_runs_trigger_type_ck
        CHECK (trigger_type IN ('event', 'schedule', 'manual', 'webhook', 'list', 'sub', 'replay',
                                'form', 'date', 'stale', 'email'));
END $$;

CREATE INDEX IF NOT EXISTS ix_cp_workflow_versions_watch
    ON core_platform.cp_workflow_versions (next_fire_at) WHERE trigger_type IN ('date', 'stale');
CREATE INDEX IF NOT EXISTS ix_cp_workflow_versions_form
    ON core_platform.cp_workflow_versions (trigger_kind) WHERE trigger_type = 'form';

-- ===================================================================== data tables
CREATE TABLE IF NOT EXISTS core_platform.cp_wf_tables (
    tenant_id    text        NOT NULL,
    id           text        NOT NULL,
    bus_id       text        NOT NULL,
    name         text        NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 80),
    description  text        NOT NULL DEFAULT '',
    columns      jsonb       NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(columns) = 'array'),
    key_column   text,
    created_by   text,
    updated_by   text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    deleted_at   timestamptz,
    PRIMARY KEY (tenant_id, id)
);
CREATE INDEX IF NOT EXISTS ix_cp_wf_tables_bus ON core_platform.cp_wf_tables (tenant_id, bus_id) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS core_platform.cp_wf_table_rows (
    tenant_id    text        NOT NULL,
    id           text        NOT NULL,
    table_id     text        NOT NULL,
    bus_id       text        NOT NULL,
    data         jsonb       NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(data) = 'object'),
    key_value    text,
    created_by   text,
    updated_by   text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, id)
);
CREATE INDEX IF NOT EXISTS ix_cp_wf_table_rows_table ON core_platform.cp_wf_table_rows (tenant_id, table_id, cdatetime);
CREATE INDEX IF NOT EXISTS ix_cp_wf_table_rows_updated ON core_platform.cp_wf_table_rows (tenant_id, table_id, updated_at);
CREATE INDEX IF NOT EXISTS ix_cp_wf_table_rows_bus ON core_platform.cp_wf_table_rows (tenant_id, bus_id);
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_wf_table_rows_key
    ON core_platform.cp_wf_table_rows (tenant_id, table_id, key_value) WHERE key_value IS NOT NULL;

-- ===================================================================== forms
CREATE TABLE IF NOT EXISTS core_platform.cp_wf_forms (
    tenant_id      text        NOT NULL,
    id             text        NOT NULL,
    bus_id         text        NOT NULL,
    name           text        NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 120),
    description    text        NOT NULL DEFAULT '',
    fields         jsonb       NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(fields) = 'array'),
    status         text        NOT NULL DEFAULT 'ACTIVE',
    require_signin boolean     NOT NULL DEFAULT false,
    thank_you      text        NOT NULL DEFAULT '',
    token          text        NOT NULL,
    created_by     text,
    updated_by     text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    deleted_at     timestamptz,
    PRIMARY KEY (tenant_id, id)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_wf_forms_token ON core_platform.cp_wf_forms (token);
CREATE INDEX IF NOT EXISTS ix_cp_wf_forms_bus ON core_platform.cp_wf_forms (tenant_id, bus_id) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS core_platform.cp_wf_form_submissions (
    tenant_id     text        NOT NULL,
    id            text        NOT NULL,
    form_id       text        NOT NULL,
    bus_id        text        NOT NULL,
    answers       jsonb       NOT NULL DEFAULT '{}'::jsonb,
    files         jsonb       NOT NULL DEFAULT '[]'::jsonb,
    submitted_by  text,
    ip_hash       text,
    run_ids       text[]      NOT NULL DEFAULT '{}',
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, id)
);
CREATE INDEX IF NOT EXISTS ix_cp_wf_form_submissions_form ON core_platform.cp_wf_form_submissions (tenant_id, form_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS ix_cp_wf_form_submissions_ip ON core_platform.cp_wf_form_submissions (form_id, ip_hash, cdatetime);

-- ===================================================================== tasks for people
CREATE TABLE IF NOT EXISTS core_platform.cp_wf_tasks (
    tenant_id       text        NOT NULL,
    id              text        NOT NULL,
    bus_id          text        NOT NULL,
    workflow_id     text        NOT NULL,
    run_id          text        NOT NULL,
    node_id         text        NOT NULL,
    title           text        NOT NULL,
    message         text        NOT NULL DEFAULT '',
    fields          jsonb       NOT NULL DEFAULT '[]'::jsonb,
    assignee_ids    text[]      NOT NULL DEFAULT '{}',
    escalate_ids    text[]      NOT NULL DEFAULT '{}',
    status          text        NOT NULL DEFAULT 'PENDING',
    due_at          timestamptz,
    expires_at      timestamptz,
    next_remind_at  timestamptz,
    remind_every_hours integer  NOT NULL DEFAULT 0,
    reminders_sent  integer     NOT NULL DEFAULT 0,
    escalated_at    timestamptz,
    send_email      boolean     NOT NULL DEFAULT true,
    answers         jsonb,
    completed_by    text,
    completed_at    timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, id)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_wf_tasks_node ON core_platform.cp_wf_tasks (tenant_id, run_id, node_id);
CREATE INDEX IF NOT EXISTS ix_cp_wf_tasks_assignees ON core_platform.cp_wf_tasks USING gin (assignee_ids);
CREATE INDEX IF NOT EXISTS ix_cp_wf_tasks_pending ON core_platform.cp_wf_tasks (status, next_remind_at, due_at, expires_at)
    WHERE status = 'PENDING';

-- ===================================================================== trigger bookkeeping
CREATE TABLE IF NOT EXISTS core_platform.cp_wf_trigger_fired (
    tenant_id    text        NOT NULL,
    workflow_id  text        NOT NULL,
    fire_key     text        NOT NULL,
    run_id       text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, workflow_id, fire_key)
);
CREATE INDEX IF NOT EXISTS ix_cp_wf_trigger_fired_age ON core_platform.cp_wf_trigger_fired (cdatetime);

CREATE TABLE IF NOT EXISTS core_platform.cp_wf_inbound_addresses (
    tenant_id    text        NOT NULL,
    workflow_id  text        NOT NULL,
    token        text        NOT NULL,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, workflow_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_wf_inbound_addresses_token ON core_platform.cp_wf_inbound_addresses (token);

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-workflows-tables', 'Workflow Data Tables', 'The business''s data tables: columns and rows', 'rt-subscribed-app-workflows'),
('rt-workflows-forms',  'Workflow Forms',       'The business''s forms, their public links and submissions', 'rt-subscribed-app-workflows')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('manage', 'Manage', false, false)
ON CONFLICT (action) DO NOTHING;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('tables', 'rt-workflows-tables', 'get',    'See the business''s data tables and their rows'),
    ('tables', 'rt-workflows-tables', 'manage', 'Create and change data tables, their columns and rows; import and export CSV'),
    ('forms',  'rt-workflows-forms',  'get',    'See the business''s forms and their submissions'),
    ('forms',  'rt-workflows-forms',  'manage', 'Create, change, open, close and delete forms, and change their links')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-workflows-' || spec.resource_key || '-' || spec.action,
       'Workflows ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'workflows',
       resource_key = substring(p.id FROM '^permission-workflows-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id IN ('permission-workflows-tables-get', 'permission-workflows-tables-manage',
                'permission-workflows-forms-get', 'permission-workflows-forms-manage')
   AND (p.app_prefix IS DISTINCT FROM 'workflows' OR p.action IS NULL);

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (VALUES
        ('role-workflows-admin', 'tables', 'get'), ('role-workflows-admin', 'tables', 'manage'),
        ('role-workflows-admin', 'forms', 'get'), ('role-workflows-admin', 'forms', 'manage'),
        ('role-workflows-builder', 'tables', 'get'), ('role-workflows-builder', 'tables', 'manage'),
        ('role-workflows-builder', 'forms', 'get'), ('role-workflows-builder', 'forms', 'manage'),
        ('role-workflows-runner', 'tables', 'get'), ('role-workflows-runner', 'forms', 'get'),
        ('role-workflows-viewer', 'tables', 'get'), ('role-workflows-viewer', 'forms', 'get')
  ) AS spec(role_id, resource_key, action)
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'workflows' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND coalesce(p.delete_status, 'NOT_DELETED') = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ===================================================================== features (BASIC)
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('workflows.tables', 'app-workflows', 'Data Tables',      1, 'Tables of your own with typed columns, steps that find, add, change and remove rows, and triggers on their dates. 1,000 rows on Basic, 10,000 on Advance, 100,000 on Premium'),
('workflows.forms',  'app-workflows', 'Forms',            1, 'Forms with a public link (or for signed-in people) that start a workflow with the answers'),
('workflows.tasks',  'app-workflows', 'Tasks for People', 1, 'Ask people, groups or roles to fill something in, with a due date in working hours, reminders and escalation')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

-- ===================================================================== invariants (properties only)
DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions
     WHERE id IN ('permission-workflows-tables-get', 'permission-workflows-tables-manage',
                  'permission-workflows-forms-get', 'permission-workflows-forms-manage')
       AND (app_prefix <> 'workflows' OR resource_key IS NULL OR action IS NULL);
    IF n > 0 THEN
        RAISE EXCEPTION '% Workflows tables/forms permission(s) have no pair', n;
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
     WHERE rp.role_id IN ('role-workflows-viewer', 'role-workflows-runner') AND p.app_prefix = 'workflows'
       AND p.resource_key IN ('tables', 'forms') AND p.action <> 'get';
    IF n > 0 THEN
        RAISE EXCEPTION 'a Workflows Viewer or Runner manages tables or forms (% grants)', n;
    END IF;
END $$;

COMMIT;
