-- Core Platform: Workflows slice 2 -- the apps join in (tvs-coreplatform-bk docs/workflows/DESIGN.md §10).
--
-- 1. LIFECYCLE EVENTS. Help Desk, Projects, CRM, Invoicing and ZelosHR now publish their records'
--    moments to core_platform.cp_events, each from one central place in the app, in the change's
--    transaction behind a savepoint (a failed publish never fails the change). Plain versioned
--    payloads ({"v": 1, ...}), not link envelopes: nobody receives them but whoever reads the log
--    (the workflow designer first). Catalogued here with link_key 'suite-events' and target
--    'app-coreplatform'. No requester email or phone, no notes or message bodies, never bank or pay
--    details; Help Desk never publishes a confidential (HR) ticket.
--
-- 2. APP ACTIONS. A workflow step that acts inside an app publishes workflow.<app>_<verb> (link
--    envelope, link 'core-workflows', source 'app-coreplatform'); the app's own inbox takes it in
--    and does it as the person who published the workflow, with that person's permissions in the
--    app (helpdesk.hd_link_inbox, projects.prj_link_inbox, and crm.crm_link_inbox, new here).
--    Core never writes an app's tables: it reads the outcome back from the inbox row.
--    The receiver checks only its own subscription for this link: publishing the workflow is the
--    business's switch (tvs-shared-apps-bk internal/platform/linkbox Gate).
--
-- 3. A `workflow` permission resource (get = view, update = build, run = run now / retry /
--    cancel) instead of borrowing settings. Owner, Admin and Core Platform Admin hold it by rule;
--    every role that holds settings|update today gets all three ONCE (marker below), so nobody who
--    could build workflows yesterday loses it.
--
-- 4. cp_events (tenant_id, bus_id, kind, id): the builder's "kinds this business sent" and sample
--    reads.
--
-- Idempotent; re-runs on every deploy. This file owns the catalogue rows of the kinds it names (a
-- newer file that changes a schema adds a version). Nothing is narrowed.

BEGIN;

-- ===================================================================== 4. the index
CREATE INDEX IF NOT EXISTS cp_events_business_kind_idx
    ON core_platform.cp_events (tenant_id, bus_id, kind, id);

-- ===================================================================== 1 + 2. event catalogue
DO $$
BEGIN
    IF to_regclass('core_platform.cp_event_schemas') IS NULL THEN
        RAISE NOTICE 'workflows-apps: no event catalogue here (20261102-50 not applied); skipping its rows';
        RETURN;
    END IF;

    -- -------------------------------------------------------- lifecycle events (plain payloads)
    WITH ticket AS (
        SELECT '{"v":{"type":"integer","minimum":1},"ticket_id":{"type":"string"},"number":{"type":"string"},
                 "ticket_type":{"type":"string"},"subject":{"type":"string"},"priority":{"type":"string"},
                 "status":{"type":"string"},"status_category":{"type":"string"},"source":{"type":"string"},
                 "department_id":{"type":"string"},"department_name":{"type":"string"},"team_id":{"type":"string"},
                 "team_name":{"type":"string"},"assignee_user_id":{"type":"string"},"assignee_name":{"type":"string"},
                 "category_id":{"type":"string"},"due_at":{"type":"string","format":"date-time"},
                 "created_at":{"type":"string","format":"date-time"},"path":{"type":"string"}}'::jsonb AS p
    ), work AS (
        SELECT '{"v":{"type":"integer","minimum":1},"task_id":{"type":"string"},"task_key":{"type":"string"},
                 "title":{"type":"string"},"kind":{"type":"string"},"priority":{"type":"string"},
                 "project_id":{"type":"string"},"project_key":{"type":"string"},"project_name":{"type":"string"},
                 "status":{"type":"string"},"status_category":{"type":"string"},"assignee_user_id":{"type":"string"},
                 "assignee_name":{"type":"string"},"due_date":{"type":"string","format":"date"},
                 "sprint_id":{"type":"string"},"sprint_name":{"type":"string"},"path":{"type":"string"}}'::jsonb AS p
    ), sprint AS (
        SELECT '{"v":{"type":"integer","minimum":1},"sprint_id":{"type":"string"},"sprint_name":{"type":"string"},
                 "project_id":{"type":"string"},"project_key":{"type":"string"},"project_name":{"type":"string"},
                 "starts_on":{"type":"string","format":"date"},"ends_on":{"type":"string","format":"date"},
                 "items":{"type":"integer"},"done_items":{"type":"integer"}}'::jsonb AS p
    ), deal AS (
        SELECT '{"v":{"type":"integer","minimum":1},"deal_id":{"type":"string"},"title":{"type":"string"},
                 "pipeline_id":{"type":"string"},"pipeline_name":{"type":"string"},"from_stage":{"type":"string"},
                 "to_stage":{"type":"string"},"status":{"enum":["open","won","lost"]},"amount":{"type":"string"},
                 "currency":{"type":"string"},"owner_user_id":{"type":"string"},"owner_name":{"type":"string"},
                 "company_name":{"type":"string"},"close_reason":{"type":"string"},"path":{"type":"string"}}'::jsonb AS p
    ), invoice AS (
        SELECT '{"v":{"type":"integer","minimum":1},"invoice_id":{"type":"string"},"number":{"type":"string"},
                 "customer_id":{"type":"string"},"customer_name":{"type":"string"},"total":{"type":"string"},
                 "amount_paid":{"type":"string"},"balance":{"type":"string"},"currency":{"type":"string"},
                 "issue_date":{"type":"string","format":"date"},"due_date":{"type":"string","format":"date"},
                 "paid_at":{"type":"string","format":"date-time"},"days_overdue":{"type":"integer"},
                 "path":{"type":"string"}}'::jsonb AS p
    ), leave AS (
        SELECT '{"v":{"type":"integer","minimum":1},"leave_request_id":{"type":"string"},"employee_id":{"type":"string"},
                 "employee_name":{"type":"string"},"leave_type":{"type":"string"},"start_date":{"type":"string","format":"date"},
                 "end_date":{"type":"string","format":"date"},"days":{"type":"number"},"status":{"type":"string"},
                 "requested_by":{"type":"string"},"approved_by":{"type":"string"},"approver_name":{"type":"string"}}'::jsonb AS p
    ), kinds (kind, source_app, description, props, required) AS (
        SELECT 'helpdesk.ticket_created', 'app-helpdesk', 'A ticket was opened in Help Desk (any channel).',
               (SELECT p FROM ticket), '["v","ticket_id","number"]'::jsonb
        UNION ALL SELECT 'helpdesk.ticket_assigned', 'app-helpdesk', 'A ticket was assigned to a team or a person.',
               (SELECT p FROM ticket), '["v","ticket_id","number"]'::jsonb
        UNION ALL SELECT 'helpdesk.ticket_status_changed', 'app-helpdesk', 'A ticket moved to another status.',
               (SELECT p FROM ticket) || '{"from_status":{"type":"string"},"from_category":{"type":"string"},
                                           "to_status":{"type":"string"},"to_category":{"type":"string"}}'::jsonb,
               '["v","ticket_id","number"]'::jsonb
        UNION ALL SELECT 'helpdesk.ticket_resolved', 'app-helpdesk', 'A ticket was resolved.',
               (SELECT p FROM ticket) || '{"from_status":{"type":"string"},"from_category":{"type":"string"}}'::jsonb,
               '["v","ticket_id","number"]'::jsonb
        UNION ALL SELECT 'helpdesk.sla_breached', 'app-helpdesk', 'A ticket missed an SLA target.',
               (SELECT p FROM ticket) || '{"metric":{"type":"string"}}'::jsonb, '["v","ticket_id","number","metric"]'::jsonb
        UNION ALL SELECT 'helpdesk.approval_decided', 'app-helpdesk', 'An approval on a ticket was decided.',
               (SELECT p FROM ticket) || '{"outcome":{"enum":["approved","rejected","cancelled"]},"request_id":{"type":"string"}}'::jsonb,
               '["v","ticket_id","number","outcome"]'::jsonb
        UNION ALL SELECT 'projects.work_created', 'app-projects', 'A work item was created in Projects.',
               (SELECT p FROM work), '["v","task_id","task_key"]'::jsonb
        UNION ALL SELECT 'projects.work_moved', 'app-projects', 'A work item moved to another status.',
               (SELECT p FROM work) || '{"from_status":{"type":"string"},"from_category":{"type":"string"}}'::jsonb,
               '["v","task_id","task_key"]'::jsonb
        UNION ALL SELECT 'projects.work_done', 'app-projects', 'A work item was done.',
               (SELECT p FROM work), '["v","task_id","task_key"]'::jsonb
        UNION ALL SELECT 'projects.sprint_started', 'app-projects', 'A sprint started.',
               (SELECT p FROM sprint), '["v","sprint_id"]'::jsonb
        UNION ALL SELECT 'projects.sprint_completed', 'app-projects', 'A sprint was completed.',
               (SELECT p FROM sprint), '["v","sprint_id"]'::jsonb
        UNION ALL SELECT 'crm.lead_created', 'app-crm', 'A lead was added in CRM.',
               '{"v":{"type":"integer","minimum":1},"lead_id":{"type":"string"},"name":{"type":"string"},
                 "company":{"type":"string"},"source":{"type":"string"},"status":{"type":"string"},
                 "owner_user_id":{"type":"string"},"owner_name":{"type":"string"},"score":{"type":"number"},
                 "path":{"type":"string"}}'::jsonb, '["v","lead_id"]'::jsonb
        UNION ALL SELECT 'crm.deal_stage_changed', 'app-crm', 'A deal moved to another stage (won and lost included).',
               (SELECT p FROM deal), '["v","deal_id","to_stage","status"]'::jsonb
        UNION ALL SELECT 'crm.deal_won', 'app-crm', 'A deal was won.', (SELECT p FROM deal), '["v","deal_id"]'::jsonb
        UNION ALL SELECT 'crm.deal_lost', 'app-crm', 'A deal was lost.', (SELECT p FROM deal), '["v","deal_id"]'::jsonb
        UNION ALL SELECT 'inv.invoice_paid', 'app-invoicing', 'An invoice was paid in full.',
               (SELECT p FROM invoice), '["v","invoice_id","number"]'::jsonb
        UNION ALL SELECT 'inv.invoice_overdue', 'app-invoicing', 'An invoice passed its due date unpaid (told once per due date).',
               (SELECT p FROM invoice), '["v","invoice_id","number","due_date"]'::jsonb
        UNION ALL SELECT 'zeloshr.leave_requested', 'app-zeloshr', 'An employee asked for leave.',
               (SELECT p FROM leave), '["v","leave_request_id","employee_id"]'::jsonb
        UNION ALL SELECT 'zeloshr.leave_approved', 'app-zeloshr', 'A leave request was approved (the final approval).',
               (SELECT p FROM leave), '["v","leave_request_id","employee_id"]'::jsonb
        UNION ALL SELECT 'zeloshr.employee_left', 'app-zeloshr', 'An employee left (resigned, terminated, contract ended).',
               '{"v":{"type":"integer","minimum":1},"employee_id":{"type":"string"},"employee_name":{"type":"string"},
                 "job_title":{"type":"string"},"department_name":{"type":"string"},
                 "exit_type":{"enum":["resignation","termination","contract_end","retirement","other"]},
                 "last_working_day":{"type":"string","format":"date"}}'::jsonb, '["v","employee_id","exit_type"]'::jsonb
    )
    INSERT INTO core_platform.cp_event_schemas (kind, version, link_key, source_app, target_app, phase, description, schema, updated_at)
    SELECT k.kind, 1, 'suite-events', k.source_app, 'app-coreplatform', 1, k.description,
           jsonb_build_object('$schema', 'https://json-schema.org/draft/2020-12/schema', 'type', 'object',
                              'title', k.kind || ' v1', 'required', k.required, 'properties', k.props), now()
      FROM kinds k
    ON CONFLICT (kind, version) DO UPDATE SET
        link_key = EXCLUDED.link_key, source_app = EXCLUDED.source_app, target_app = EXCLUDED.target_app,
        phase = EXCLUDED.phase, description = EXCLUDED.description, schema = EXCLUDED.schema,
        updated_at = CASE WHEN core_platform.cp_event_schemas.schema IS DISTINCT FROM EXCLUDED.schema
                            OR core_platform.cp_event_schemas.description IS DISTINCT FROM EXCLUDED.description
                          THEN now() ELSE core_platform.cp_event_schemas.updated_at END;

    -- -------------------------------------------------------- app actions (link envelopes)
    WITH envelope AS (
        SELECT jsonb_build_object(
            '$schema', 'https://json-schema.org/draft/2020-12/schema',
            'type', 'object',
            'required', jsonb_build_array('v', 'link', 'idempotency_key', 'data'),
            'properties', jsonb_build_object(
                'v', jsonb_build_object('type', 'integer', 'minimum', 1),
                'link', jsonb_build_object('const', 'core-workflows'),
                'idempotency_key', jsonb_build_object('type', 'string', 'minLength', 1, 'maxLength', 200),
                'sent_at', jsonb_build_object('type', 'string', 'format', 'date-time'),
                'sent_by', jsonb_build_object('type', 'string'))) AS e
    ), common AS (
        SELECT '{"request_id":{"type":"string"},"run_id":{"type":"string"},"workflow_id":{"type":"string"},
                 "workflow_name":{"type":"string"},"step_id":{"type":"string"},"run_as":{"type":"string"}}'::jsonb AS p
    ), kinds (kind, target_app, description, props, required) AS (
        SELECT 'workflow.helpdesk_ticket_create', 'app-helpdesk',
               'A workflow step opens a Help Desk ticket, as the person who published the workflow.',
               '{"subject":{"type":"string","minLength":1},"description":{"type":"string"},
                 "priority":{"enum":["","low","medium","high","urgent"]},"ticket_type":{"type":"string"},
                 "department_id":{"type":"string"},"team_id":{"type":"string"},"assignee_user_id":{"type":"string"}}'::jsonb,
               '["subject"]'::jsonb
        UNION ALL SELECT 'workflow.helpdesk_note_add', 'app-helpdesk',
               'A workflow step adds an internal note to a Help Desk ticket (by id or number).',
               '{"ticket":{"type":"string","minLength":1},"body":{"type":"string","minLength":1},"internal":{"type":"boolean"}}'::jsonb,
               '["ticket","body"]'::jsonb
        UNION ALL SELECT 'workflow.helpdesk_status_set', 'app-helpdesk',
               'A workflow step moves a Help Desk ticket to a status, with an optional internal comment.',
               '{"ticket":{"type":"string","minLength":1},"status_id":{"type":"string","minLength":1},"comment":{"type":"string"}}'::jsonb,
               '["ticket","status_id"]'::jsonb
        UNION ALL SELECT 'workflow.projects_work_create', 'app-projects',
               'A workflow step creates a Projects work item, as the person who published the workflow.',
               '{"project_id":{"type":"string","minLength":1},"title":{"type":"string","minLength":1},"description":{"type":"string"},
                 "kind":{"enum":["","task","bug","story"]},"priority":{"type":"string"},"assignee_user_id":{"type":"string"},
                 "due_date":{"type":"string"}}'::jsonb,
               '["project_id","title"]'::jsonb
        UNION ALL SELECT 'workflow.projects_work_move', 'app-projects',
               'A workflow step moves a work item (by id or key) to a status, or to its project''s first status of a category.',
               '{"task":{"type":"string","minLength":1},"status_id":{"type":"string"},
                 "category":{"enum":["","todo","in_progress","done"]}}'::jsonb,
               '["task"]'::jsonb
        UNION ALL SELECT 'workflow.projects_comment_add', 'app-projects',
               'A workflow step comments on a work item (by id or key).',
               '{"task":{"type":"string","minLength":1},"body":{"type":"string","minLength":1}}'::jsonb,
               '["task","body"]'::jsonb
        UNION ALL SELECT 'workflow.crm_task_create', 'app-crm',
               'A workflow step creates a CRM task, for its owner (the publisher when none is named).',
               '{"title":{"type":"string","minLength":1},"description":{"type":"string"},"due_date":{"type":"string"},
                 "owner_user_id":{"type":"string"},"deal_id":{"type":"string"},"contact_id":{"type":"string"},
                 "lead_id":{"type":"string"},"priority":{"type":"string"}}'::jsonb,
               '["title"]'::jsonb
        UNION ALL SELECT 'workflow.crm_activity_log', 'app-crm',
               'A workflow step logs a call, meeting, email or note in CRM.',
               '{"kind":{"enum":["call","meeting","email","note"]},"subject":{"type":"string","minLength":1},"body":{"type":"string"},
                 "deal_id":{"type":"string"},"contact_id":{"type":"string"},"lead_id":{"type":"string"},
                 "occurred_at":{"type":"string"}}'::jsonb,
               '["kind","subject"]'::jsonb
    )
    INSERT INTO core_platform.cp_event_schemas (kind, version, link_key, source_app, target_app, phase, description, schema, updated_at)
    SELECT k.kind, 1, 'core-workflows', 'app-coreplatform', k.target_app, 1, k.description,
           jsonb_set(e.e, '{properties,data}',
                     jsonb_build_object('type', 'object',
                                        'required', '["request_id","run_id","run_as"]'::jsonb || k.required,
                                        'properties', (SELECT p FROM common) || k.props))
             || jsonb_build_object('title', k.kind || ' v1'), now()
      FROM kinds k CROSS JOIN envelope e
    ON CONFLICT (kind, version) DO UPDATE SET
        link_key = EXCLUDED.link_key, source_app = EXCLUDED.source_app, target_app = EXCLUDED.target_app,
        phase = EXCLUDED.phase, description = EXCLUDED.description, schema = EXCLUDED.schema,
        updated_at = CASE WHEN core_platform.cp_event_schemas.schema IS DISTINCT FROM EXCLUDED.schema
                            OR core_platform.cp_event_schemas.description IS DISTINCT FROM EXCLUDED.description
                          THEN now() ELSE core_platform.cp_event_schemas.updated_at END;
END $$;

-- ===================================================================== 2. CRM's inbox
DO $$
BEGIN
    IF to_regclass('crm.crm_deals') IS NULL THEN
        RAISE NOTICE 'workflows-apps: no crm schema here: its inbox comes with it';
        RETURN;
    END IF;
    CREATE TABLE IF NOT EXISTS crm.crm_link_inbox (
        id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
        tenant_id        text NOT NULL,
        bus_id           text NOT NULL,
        link_key         text NOT NULL,
        source_app       text NOT NULL,
        kind             text NOT NULL,
        version          integer NOT NULL DEFAULT 1,
        event_id         bigint NOT NULL,
        idempotency_key  text NOT NULL,
        subject_id       text NOT NULL DEFAULT '',
        payload          jsonb NOT NULL DEFAULT '{}',
        sent_at          timestamptz NOT NULL,
        status           text NOT NULL DEFAULT 'PENDING',
        attempts         integer NOT NULL DEFAULT 0,
        next_attempt_at  timestamptz NOT NULL DEFAULT now(),
        claimed_until    timestamptz,
        last_error       text,
        result           jsonb,
        received_at      timestamptz NOT NULL DEFAULT now(),
        handled_at       timestamptz,
        CONSTRAINT ck_crm_link_inbox_status CHECK (status IN ('PENDING', 'RETRY', 'DONE', 'REFUSED', 'DEAD'))
    );
    CREATE UNIQUE INDEX IF NOT EXISTS crm_link_inbox_once ON crm.crm_link_inbox (tenant_id, source_app, idempotency_key);
    CREATE INDEX IF NOT EXISTS crm_link_inbox_due ON crm.crm_link_inbox (next_attempt_at) WHERE status IN ('PENDING', 'RETRY');
    CREATE INDEX IF NOT EXISTS crm_link_inbox_business ON crm.crm_link_inbox (tenant_id, bus_id, received_at DESC);

    CREATE OR REPLACE FUNCTION crm.crm_link_inbox_retry(p_tenant text, p_bus text, p_ids text[] DEFAULT NULL)
    RETURNS integer LANGUAGE sql AS $f$
        WITH r AS (
            UPDATE crm.crm_link_inbox
               SET status = 'PENDING', attempts = 0, next_attempt_at = now(), claimed_until = NULL
             WHERE tenant_id = p_tenant AND bus_id = p_bus AND status IN ('DEAD', 'REFUSED')
               AND (p_ids IS NULL OR id = ANY (p_ids))
            RETURNING 1)
        SELECT count(*)::integer FROM r
    $f$;
END $$;

-- ===================================================================== 3. the workflow permission
INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('run', 'Run', false, false)
ON CONFLICT (action) DO NOTHING;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-workflow', 'Workflows', 'Settings > Workflows: automations across the business''s apps', NULL)
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description;

-- 20260928-09 empties cp_resources and refills its own list on every deploy, so the line is
-- declared again here, after it, every time (as 20261022-65 does for app-connection).
INSERT INTO core_platform.cp_resources (app_prefix, resource_key, resource_type_id, actions, label)
VALUES ('', 'workflow', 'rt-workflow', ARRAY['get', 'update', 'run'], 'Workflows')
ON CONFLICT (app_prefix, resource_key) DO UPDATE SET resource_type_id = EXCLUDED.resource_type_id,
                                                     actions          = EXCLUDED.actions,
                                                     label            = EXCLUDED.label;
-- Written as the catalogue names them, not by sync_permissions_from_catalogue() (see 20261022-65).
INSERT INTO core_platform.cp_permissions
       (id, permission_name, resource_type_id, description, app_prefix, resource_key, action, target, scope,
        cdate, ctime, cdatetime)
VALUES ('permission-workflow-get', 'Workflow Get', 'rt-workflow',
        'See the business''s workflows and their run history', '', 'workflow', 'get', '', 'any',
        CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP),
       ('permission-workflow-update', 'Workflow Update', 'rt-workflow',
        'Build workflows: create, edit, publish, pause, delete, dry runs and webhook secrets', '', 'workflow', 'update', '', 'any',
        CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP),
       ('permission-workflow-run', 'Workflow Run', 'rt-workflow',
        'Run a workflow now, and retry or cancel its runs', '', 'workflow', 'run', '', 'any',
        CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET resource_type_id = EXCLUDED.resource_type_id,
                               app_prefix       = EXCLUDED.app_prefix,
                               resource_key     = EXCLUDED.resource_key,
                               action           = EXCLUDED.action,
                               target           = EXCLUDED.target,
                               scope            = EXCLUDED.scope;

-- Backfill ONCE: whoever could build workflows yesterday (settings|update, held by grant) keeps it.
-- Rule-based roles (Owner, Admin, Core Platform Admin) hold no grants and need none.
CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_backfills (
    key     text PRIMARY KEY,
    ran_at  timestamptz NOT NULL DEFAULT now(),
    rows    integer NOT NULL DEFAULT 0
);

DO $$
DECLARE n integer := 0;
BEGIN
    IF EXISTS (SELECT 1 FROM core_platform.cp_workflow_backfills WHERE key = 'workflow-permission@20261110') THEN
        RETURN;
    END IF;
    INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
    SELECT DISTINCT rp.tenant_id, rp.role_id, p.id
      FROM core_platform.cp_role_permissions rp
     CROSS JOIN (VALUES ('permission-workflow-get'), ('permission-workflow-update'), ('permission-workflow-run')) AS p(id)
     WHERE rp.permission_id = 'permission-settings-update'
    ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;
    GET DIAGNOSTICS n = ROW_COUNT;
    INSERT INTO core_platform.cp_workflow_backfills (key, rows) VALUES ('workflow-permission@20261110', n);
    RAISE NOTICE 'workflows-apps: % workflow grant(s) given to roles holding settings|update', n;
END $$;

-- ===================================================================== invariants, not counts
DO $$
DECLARE bad text;
BEGIN
    IF to_regclass('core_platform.cp_event_schemas') IS NOT NULL THEN
        SELECT string_agg(kind || ' v' || version, ', ') INTO bad FROM core_platform.cp_event_schemas
         WHERE link_key = 'core-workflows'
           AND (split_part(kind, '.', 1) <> 'workflow' OR source_app <> 'app-coreplatform'
                OR NOT (schema #> '{properties,data,required}') @> '["request_id","run_id","run_as"]'::jsonb);
        IF bad IS NOT NULL THEN
            RAISE EXCEPTION 'workflows-apps: app-action rows not from Core, not workflow.*, or not requiring request_id/run_id/run_as: %', bad;
        END IF;
        SELECT string_agg(kind || ' v' || version, ', ') INTO bad FROM core_platform.cp_event_schemas
         WHERE link_key = 'suite-events'
           AND (split_part(kind, '.', 1) <> CASE source_app WHEN 'app-helpdesk' THEN 'helpdesk' WHEN 'app-projects' THEN 'projects'
                                                            WHEN 'app-crm' THEN 'crm' WHEN 'app-invoicing' THEN 'inv'
                                                            WHEN 'app-zeloshr' THEN 'zeloshr' END
                OR NOT (schema -> 'required') @> '["v"]'::jsonb);
        IF bad IS NOT NULL THEN
            RAISE EXCEPTION 'workflows-apps: lifecycle rows whose prefix does not name the sender, or not versioned: %', bad;
        END IF;
    END IF;
    SELECT string_agg(v, ', ') INTO bad
      FROM (VALUES ('get'), ('update'), ('run')) AS w(v)
     WHERE NOT EXISTS (SELECT 1 FROM core_platform.cp_permissions p
                        WHERE p.app_prefix = '' AND p.resource_key = 'workflow' AND p.action = w.v
                          AND coalesce(p.delete_status, 'NOT_DELETED') = 'NOT_DELETED');
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'workflows-apps: the workflow permission is missing verb(s): %', bad;
    END IF;
END $$;

COMMIT;
