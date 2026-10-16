-- Projects: automation rules, approval steps and work templates.
--
--   * prj_rules: "when this happens, if the work matches, do these things". trigger is what
--     happened (created, moved, assigned, priority_changed, commented, done); trigger_config
--     narrows it (moved to a status, or into a group); condition is a work query (the same
--     language as the lists); actions is the list of things to do, in order. run_count and
--     last_run_at say whether it is doing anything.
--   * prj_rule_runs: what each rule did to which item, or why it could not -- the last few
--     hundred per rule are kept.
--   * prj_statuses.approval_*: a status can need someone's approval. Entering it asks the
--     approvers; work cannot be finished (moved into a done status) until one of them approves;
--     approving or rejecting can move it on (approve_to) or back (reject_to, else where it came
--     from).
--   * prj_approvals: each request, who asked, who decided, and what.
--   * prj_templates: a reusable set of work -- a parent item and its steps, with assignees,
--     approvers and steps that wait on others -- made into real work in one go. Made by hand,
--     saved from an existing item, or brought in from MyStoreGuard's workflow templates
--     (source/source_id, so one is not brought into a project twice).
--   * prj_notifications kinds: 'approval' (you are asked to approve; your work was approved or
--     rejected) and 'automation' (a rule said to tell you).
--   * projects.src_msg_wf_*: read-only views of MyStoreGuard's workflow templates (only where
--     those tables exist), groups expanded to their members.
--
-- Managing rules, approvals and templates is project settings (projects|projects|update);
-- making work from a template is creating work (projects|tasks|create).
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS projects.prj_rules (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    project_id     text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    name           text NOT NULL CHECK (btrim(name) <> ''),
    enabled        boolean NOT NULL DEFAULT true,
    trigger        text NOT NULL CHECK (trigger IN ('created', 'moved', 'assigned', 'priority_changed', 'commented', 'done')),
    trigger_config jsonb NOT NULL DEFAULT '{}'::jsonb,
    condition      text NOT NULL DEFAULT '',
    actions        jsonb NOT NULL DEFAULT '[]'::jsonb,
    position       integer NOT NULL DEFAULT 0,
    run_count      integer NOT NULL DEFAULT 0,
    last_run_at    timestamptz,
    created_by     text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prj_rules_project_idx ON projects.prj_rules (project_id, trigger) WHERE enabled;

CREATE TABLE IF NOT EXISTS projects.prj_rule_runs (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    rule_id        text NOT NULL REFERENCES projects.prj_rules (id) ON DELETE CASCADE,
    task_id        text REFERENCES projects.prj_tasks (id) ON DELETE SET NULL,
    ok             boolean NOT NULL,
    message        text NOT NULL DEFAULT '',
    cdatetime      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prj_rule_runs_rule_idx ON projects.prj_rule_runs (rule_id, cdatetime DESC);

ALTER TABLE projects.prj_statuses ADD COLUMN IF NOT EXISTS approval_required boolean NOT NULL DEFAULT false;
ALTER TABLE projects.prj_statuses ADD COLUMN IF NOT EXISTS approvers text[] NOT NULL DEFAULT '{}';
ALTER TABLE projects.prj_statuses ADD COLUMN IF NOT EXISTS approve_to_status_id text REFERENCES projects.prj_statuses (id) ON DELETE SET NULL;
ALTER TABLE projects.prj_statuses ADD COLUMN IF NOT EXISTS reject_to_status_id text REFERENCES projects.prj_statuses (id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS projects.prj_approvals (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    task_id        text NOT NULL REFERENCES projects.prj_tasks (id) ON DELETE CASCADE,
    status_id      text NOT NULL REFERENCES projects.prj_statuses (id) ON DELETE CASCADE,
    from_status_id text REFERENCES projects.prj_statuses (id) ON DELETE SET NULL,
    approvers      text[] NOT NULL DEFAULT '{}',
    state          text NOT NULL DEFAULT 'pending' CHECK (state IN ('pending', 'approved', 'rejected', 'cancelled')),
    requested_by   text,
    requested_at   timestamptz NOT NULL DEFAULT now(),
    decided_by     text,
    decided_at     timestamptz,
    note           text NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS prj_approvals_task_idx ON projects.prj_approvals (task_id, requested_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS prj_approvals_one_pending ON projects.prj_approvals (task_id) WHERE state = 'pending';

CREATE TABLE IF NOT EXISTS projects.prj_templates (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    project_id     text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    name           text NOT NULL CHECK (btrim(name) <> ''),
    description    text NOT NULL DEFAULT '',
    root           jsonb NOT NULL DEFAULT '{}'::jsonb,
    items          jsonb NOT NULL DEFAULT '[]'::jsonb,
    source         text NOT NULL DEFAULT 'manual' CHECK (source IN ('manual', 'saved', 'mystoreguard')),
    source_id      text,
    use_count      integer NOT NULL DEFAULT 0,
    created_by     text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS prj_templates_source_uq ON projects.prj_templates (project_id, source, source_id) WHERE source_id IS NOT NULL;

ALTER TABLE projects.prj_notifications DROP CONSTRAINT IF EXISTS prj_notifications_kind_check;
ALTER TABLE projects.prj_notifications ADD CONSTRAINT prj_notifications_kind_check
    CHECK (kind IN ('assigned', 'mentioned', 'commented', 'moved', 'done', 'approval', 'automation'));

-- MyStoreGuard's workflow templates, read-only, where they exist.
DO $$
BEGIN
    IF to_regclass('mystoreguard.msg_workflow_templates') IS NULL OR to_regclass('mystoreguard.msg_workflow_template_steps') IS NULL THEN
        RAISE NOTICE 'MyStoreGuard workflow templates are not here; no template views';
        RETURN;
    END IF;
    EXECUTE $v$
    CREATE OR REPLACE VIEW projects.src_msg_wf_templates AS
    SELECT t.tenant_id, t.bus_id, t.id, t.name, coalesce(t.description, '') AS description, t.template_type, t.is_active, t.cdatetime,
           (SELECT count(*) FROM mystoreguard.msg_workflow_template_steps s WHERE s.tenant_id = t.tenant_id AND s.template_id = t.id) AS step_count
      FROM mystoreguard.msg_workflow_templates t
     WHERE coalesce(t.delete_status, 'NOT_DELETED') = 'NOT_DELETED'
    $v$;
    EXECUTE $v$
    CREATE OR REPLACE VIEW projects.src_msg_wf_template_steps AS
    SELECT s.tenant_id, s.bus_id, s.id, s.template_id, s.name, coalesce(s.description, '') AS description, s.display_order, s.cdatetime
      FROM mystoreguard.msg_workflow_template_steps s
    $v$;
    EXECUTE $v$
    CREATE OR REPLACE VIEW projects.src_msg_wf_template_people AS
    SELECT t.tenant_id, t.bus_id, t.step_id, t.target_kind, t.target_id AS user_id, t.cdatetime
      FROM mystoreguard.msg_workflow_template_step_targets t WHERE t.target_type = 'USER'
    UNION ALL
    SELECT t.tenant_id, t.bus_id, t.step_id, t.target_kind, ug.user_id, t.cdatetime
      FROM mystoreguard.msg_workflow_template_step_targets t
      JOIN core_platform.cp_user_groups ug ON ug.group_id = t.target_id AND ug.tenant_id = t.tenant_id
       AND coalesce(ug.delete_status, 'NOT_DELETED') = 'NOT_DELETED'
     WHERE t.target_type = 'GROUP'
    $v$;
    EXECUTE $v$
    CREATE OR REPLACE VIEW projects.src_msg_wf_template_deps AS
    SELECT d.tenant_id, d.bus_id, d.step_id, d.depends_on_step_id FROM mystoreguard.msg_workflow_template_step_deps d
    $v$;
END $$;

COMMIT;
