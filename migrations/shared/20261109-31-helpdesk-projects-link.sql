-- Help Desk <-> Projects (docs/helpdesk in tvs-shared-apps-bk, Phase 1 "Projects integration").
--
-- Two links in Core Platform -> Connected apps (app_connections_catalogue.py), per business, OFF
-- until a business turns them on (no row in cp_app_connections is OFF; this file writes none):
--
--   helpdesk-projects   Help Desk -> Projects: work requested from a ticket, problem or change, and
--                       the tickets linked to a work item (how many, the worst priority, SLA risk,
--                       customers affected). Projects RECEIVES and enforces.
--   projects-helpdesk   Projects -> Help Desk: linked work's live state on the ticket, the Done
--                       follow-up, time logged, a plan's dates for a change, and known errors
--                       raised from bugs. Help Desk RECEIVES and enforces.
--
-- No app writes the other's tables:
--
--   * helpdesk.hd_work_links is Help Desk's: a ticket, problem or change linked to a Projects work
--     item. Help Desk writes it (linking an existing item, asking for a new one, a known error
--     raised from Projects that its own inbox took in). Several records may link one work item.
--   * New work is made BY PROJECTS: Help Desk publishes helpdesk.work_requested (cp_events,
--     platform/linkbox envelope) and Projects' inbox (projects.prj_link_inbox) creates the item as
--     the person who asked, with their own Projects permissions. Help Desk's link row waits with
--     request_id = the event's idempotency key and task_id NULL; Help Desk reads how it went from
--     helpdesk.src_projects_requests and fills task_id in its own row.
--   * A known error is made BY HELP DESK: Projects publishes projects.known_error_raised and Help
--     Desk's inbox (helpdesk.hd_link_inbox) creates the problem (and its link) as the person who
--     raised it, with their own Help Desk permissions. Projects reads how it went from
--     projects.src_helpdesk_known_errors.
--   * Everything else is read through views, each only where the other app's tables exist:
--     helpdesk.src_projects_work / src_projects_projects (Projects' items and projects, read-only)
--     and projects.src_helpdesk_links / src_helpdesk_tickets (Help Desk's links and the tickets
--     behind each item, directly or through a linked problem or change).
--
-- Whether any of it SHOWS or HAPPENS is decided per request and per job: the business must be
-- subscribed to both apps (core_platform.cp_business_app_tier), the link switched on (the
-- receiver checks, failing closed), the plan must include the feature (helpdesk.projects and
-- projects.suite-links, both PREMIUM), and a record's details show only to people allowed to read
-- it in its own app.
--
-- Also: hd_settings.projects_done_action -- what Help Desk does when the last linked work item of a
-- ticket moves to Done: 'notify' (default: the agent is told and confirms) or 'resolve'.
--
-- Idempotent; safe to re-run on every deploy. Nothing is narrowed. This file owns the catalogue
-- rows of its two event kinds (a newer file that changes a schema adds a version).

BEGIN;

-- ===================================================================== event catalogue
DO $$
BEGIN
    IF to_regclass('core_platform.cp_event_schemas') IS NULL THEN
        RAISE NOTICE 'helpdesk-projects: no event catalogue here (20261102-50 not applied); skipping its rows';
        RETURN;
    END IF;
    WITH envelope AS (
        SELECT jsonb_build_object(
            '$schema', 'https://json-schema.org/draft/2020-12/schema',
            'type', 'object',
            'required', jsonb_build_array('v', 'link', 'idempotency_key', 'data'),
            'properties', jsonb_build_object(
                'v', jsonb_build_object('type', 'integer', 'minimum', 1),
                'link', jsonb_build_object('type', 'string'),
                'idempotency_key', jsonb_build_object('type', 'string', 'minLength', 1, 'maxLength', 200),
                'sent_at', jsonb_build_object('type', 'string', 'format', 'date-time'),
                'sent_by', jsonb_build_object('type', 'string'))) AS e
    ), kinds (kind, version, link_key, source_app, target_app, phase, description, data) AS (
        SELECT * FROM (VALUES
        ('helpdesk.work_requested', 1, 'helpdesk-projects', 'app-helpdesk', 'app-projects', 1,
         'An agent asked for work in Projects from a ticket, problem or change: Projects creates the work item (or an epic with its tasks) as that person.',
         '{"type":"object","required":["request_id","record_type","record_id","number","title","project_id","requested_by","as"],"properties":{
            "request_id":{"type":"string"},"record_type":{"enum":["ticket","problem","change"]},"record_id":{"type":"string"},
            "number":{"type":"string"},"title":{"type":"string","minLength":1},"description":{"type":"string"},
            "link":{"type":"string"},"priority":{"enum":["low","medium","high","urgent"]},"requester_name":{"type":"string"},
            "project_id":{"type":"string"},"requested_by":{"type":"string"},"as":{"enum":["task","epic"]},
            "kind":{"enum":["task","bug","story"]},"start_date":{"type":"string","format":"date"},"due_date":{"type":"string","format":"date"},
            "children":{"type":"array","maxItems":100,"items":{"type":"object","required":["title"],"properties":{
              "title":{"type":"string","minLength":1},"description":{"type":"string"},"due_date":{"type":"string","format":"date"}}}}}}'::jsonb),
        ('projects.known_error_raised', 1, 'projects-helpdesk', 'app-projects', 'app-helpdesk', 1,
         'A bug in Projects is a known error: Help Desk opens a problem in the known-error state, linked to the work item, as the person who raised it.',
         '{"type":"object","required":["request_id","task_id","task_key","title","raised_by"],"properties":{
            "request_id":{"type":"string"},"task_id":{"type":"string"},"task_key":{"type":"string"},
            "title":{"type":"string","minLength":1},"description":{"type":"string"},"workaround":{"type":"string"},
            "priority":{"enum":["low","medium","high","urgent"]},"link":{"type":"string"},"raised_by":{"type":"string"}}}'::jsonb)
        ) v
    )
    INSERT INTO core_platform.cp_event_schemas (kind, version, link_key, source_app, target_app, phase, description, schema, updated_at)
    SELECT k.kind, k.version, k.link_key, k.source_app, k.target_app, k.phase, k.description,
           jsonb_set(e.e, '{properties,data}', k.data) || jsonb_build_object('title', k.kind || ' v' || k.version), now()
      FROM kinds k CROSS JOIN envelope e
    ON CONFLICT (kind, version) DO UPDATE SET
        link_key = EXCLUDED.link_key, source_app = EXCLUDED.source_app, target_app = EXCLUDED.target_app,
        phase = EXCLUDED.phase, description = EXCLUDED.description, schema = EXCLUDED.schema,
        updated_at = CASE WHEN core_platform.cp_event_schemas.schema IS DISTINCT FROM EXCLUDED.schema
                            OR core_platform.cp_event_schemas.description IS DISTINCT FROM EXCLUDED.description
                          THEN now() ELSE core_platform.cp_event_schemas.updated_at END;
END $$;

-- ===================================================================== plan features
-- PREMIUM (rank 3), next to ITSM. Projects' side is its existing projects.suite-links (PREMIUM),
-- renamed here to say it now covers Help Desk too (20261022-75 re-runs first; this file wins).
DO $$
BEGIN
    IF to_regclass('core_platform.cp_app_feature_catalog') IS NULL THEN
        RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_app_feature_catalog WHERE app_id = 'app-helpdesk') THEN
        INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
        ('helpdesk.projects', 'app-helpdesk', 'Projects Integration', 3,
         'Create and link Projects work from tickets, problems and changes; follow its status, time and Done (needs Projects too)')
        ON CONFLICT (feature_key) DO UPDATE SET app_id = EXCLUDED.app_id, title = EXCLUDED.title,
            min_tier_rank = EXCLUDED.min_tier_rank, description = EXCLUDED.description, is_active = true;
    END IF;
    UPDATE core_platform.cp_app_feature_catalog
       SET title = 'CRM, MyStoreGuard, LoanDrift & Help Desk Links',
           description = 'Start projects from won deals and link work to tickets, loans, store tasks and Help Desk tickets (needs that app too)'
     WHERE feature_key = 'projects.suite-links'
       AND (title IS DISTINCT FROM 'CRM, MyStoreGuard, LoanDrift & Help Desk Links'
            OR description IS DISTINCT FROM 'Start projects from won deals and link work to tickets, loans, store tasks and Help Desk tickets (needs that app too)');
END $$;

-- ===================================================================== Help Desk: links, setting, inbox
DO $$
BEGIN
    IF to_regclass('helpdesk.hd_tickets') IS NULL THEN
        RAISE NOTICE 'helpdesk-projects: no helpdesk schema here: its links and inbox come with it';
        RETURN;
    END IF;

    CREATE TABLE IF NOT EXISTS helpdesk.hd_work_links (
        id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
        tenant_id     text NOT NULL,
        bus_id        text NOT NULL,
        record_type   text NOT NULL,
        record_id     text NOT NULL,
        task_id       text,
        request_id    text,
        origin        text NOT NULL DEFAULT 'linked',
        -- The last Done (prj_tasks.done_at) the Done follow-up has acted on, so it acts once per Done.
        done_seen_at  timestamptz,
        cdatetime     timestamptz NOT NULL DEFAULT now(),
        created_by    text,
        CONSTRAINT hd_work_links_record_type_check CHECK (record_type IN ('ticket', 'problem', 'change')),
        CONSTRAINT hd_work_links_origin_check CHECK (origin IN ('linked', 'created', 'known_error')),
        CONSTRAINT hd_work_links_target_check CHECK (task_id IS NOT NULL OR request_id IS NOT NULL)
    );
    CREATE UNIQUE INDEX IF NOT EXISTS hd_work_links_once ON helpdesk.hd_work_links (tenant_id, record_type, record_id, task_id)
        WHERE task_id IS NOT NULL;
    CREATE UNIQUE INDEX IF NOT EXISTS hd_work_links_request_once ON helpdesk.hd_work_links (tenant_id, request_id)
        WHERE request_id IS NOT NULL;
    CREATE INDEX IF NOT EXISTS hd_work_links_task_idx ON helpdesk.hd_work_links (tenant_id, task_id);
    CREATE INDEX IF NOT EXISTS hd_work_links_record_idx ON helpdesk.hd_work_links (tenant_id, bus_id, record_type, record_id);

    ALTER TABLE helpdesk.hd_settings ADD COLUMN IF NOT EXISTS projects_done_action text NOT NULL DEFAULT 'notify';
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                    WHERE conrelid = 'helpdesk.hd_settings'::regclass AND conname = 'hd_settings_projects_done_action_check') THEN
        ALTER TABLE helpdesk.hd_settings ADD CONSTRAINT hd_settings_projects_done_action_check
            CHECK (projects_done_action IN ('notify', 'resolve'));
    END IF;

    CREATE TABLE IF NOT EXISTS helpdesk.hd_link_inbox (
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
        CONSTRAINT ck_hd_link_inbox_status CHECK (status IN ('PENDING', 'RETRY', 'DONE', 'REFUSED', 'DEAD'))
    );
    CREATE UNIQUE INDEX IF NOT EXISTS hd_link_inbox_once ON helpdesk.hd_link_inbox (tenant_id, source_app, idempotency_key);
    CREATE INDEX IF NOT EXISTS hd_link_inbox_due ON helpdesk.hd_link_inbox (next_attempt_at) WHERE status IN ('PENDING', 'RETRY');
    CREATE INDEX IF NOT EXISTS hd_link_inbox_business ON helpdesk.hd_link_inbox (tenant_id, bus_id, received_at DESC);
    CREATE INDEX IF NOT EXISTS hd_link_inbox_subject ON helpdesk.hd_link_inbox (tenant_id, subject_id);

    CREATE OR REPLACE FUNCTION helpdesk.hd_link_inbox_retry(p_tenant text, p_bus text, p_ids text[] DEFAULT NULL)
    RETURNS integer LANGUAGE sql AS $f$
        WITH r AS (
            UPDATE helpdesk.hd_link_inbox
               SET status = 'PENDING', attempts = 0, next_attempt_at = now(), claimed_until = NULL
             WHERE tenant_id = p_tenant AND bus_id = p_bus AND status IN ('DEAD', 'REFUSED')
               AND (p_ids IS NULL OR id = ANY (p_ids))
            RETURNING 1)
        SELECT count(*)::integer FROM r
    $f$;
END $$;

-- ===================================================================== Projects: inbox
DO $$
BEGIN
    IF to_regclass('projects.prj_tasks') IS NULL THEN
        RAISE NOTICE 'helpdesk-projects: no projects schema here: its inbox comes with it';
        RETURN;
    END IF;
    CREATE TABLE IF NOT EXISTS projects.prj_link_inbox (
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
        CONSTRAINT ck_prj_link_inbox_status CHECK (status IN ('PENDING', 'RETRY', 'DONE', 'REFUSED', 'DEAD'))
    );
    CREATE UNIQUE INDEX IF NOT EXISTS prj_link_inbox_once ON projects.prj_link_inbox (tenant_id, source_app, idempotency_key);
    CREATE INDEX IF NOT EXISTS prj_link_inbox_due ON projects.prj_link_inbox (next_attempt_at) WHERE status IN ('PENDING', 'RETRY');
    CREATE INDEX IF NOT EXISTS prj_link_inbox_business ON projects.prj_link_inbox (tenant_id, bus_id, received_at DESC);

    CREATE OR REPLACE FUNCTION projects.prj_link_inbox_retry(p_tenant text, p_bus text, p_ids text[] DEFAULT NULL)
    RETURNS integer LANGUAGE sql AS $f$
        WITH r AS (
            UPDATE projects.prj_link_inbox
               SET status = 'PENDING', attempts = 0, next_attempt_at = now(), claimed_until = NULL
             WHERE tenant_id = p_tenant AND bus_id = p_bus AND status IN ('DEAD', 'REFUSED')
               AND (p_ids IS NULL OR id = ANY (p_ids))
            RETURNING 1)
        SELECT count(*)::integer FROM r
    $f$;
END $$;

-- ===================================================================== the views (read-only, both directions)
DO $$
BEGIN
    IF to_regclass('helpdesk.hd_work_links') IS NULL OR to_regclass('projects.prj_tasks') IS NULL THEN
        RAISE NOTICE 'helpdesk-projects: Help Desk and Projects are not both here: no views';
        RETURN;
    END IF;

    -- ---------------------------------------------------------- what Help Desk reads of Projects
    -- A work item, as a link card shows it. Visibility (project, workspace, their members) is
    -- applied by Help Desk with src_projects_projects, as Projects' own visibleSQL does.
    EXECUTE $v$
    CREATE OR REPLACE VIEW helpdesk.src_projects_work AS
    SELECT t.tenant_id, t.bus_id, t.id AS task_id, p.key || '-' || t.number AS task_key, t.title, t.kind, t.priority,
           p.id AS project_id, p.name AS project_name, st.name AS status_name, st.category AS status_category,
           t.assignee_user_id, au.fullname AS assignee_name, t.sprint_id, sp.name AS sprint_name, sp.ends_on AS sprint_ends_on,
           t.start_date, t.due_date, t.done_at, t.parent_id, t.time_estimate_minutes,
           (SELECT count(*) FROM projects.prj_tasks c WHERE c.parent_id = t.id AND c.delete_status = 'NOT_DELETED')::int AS child_count,
           (SELECT count(*) FROM projects.prj_tasks c JOIN projects.prj_statuses cs ON cs.id = c.status_id
             WHERE c.parent_id = t.id AND c.delete_status = 'NOT_DELETED' AND cs.category = 'done')::int AS child_done_count,
           (SELECT count(*) FROM projects.prj_checklist_items ci WHERE ci.task_id = t.id)::int AS checklist_count,
           (SELECT count(*) FROM projects.prj_checklist_items ci WHERE ci.task_id = t.id AND ci.done)::int AS checklist_done_count,
           (SELECT coalesce(sum(wl.minutes), 0) FROM projects.prj_worklogs wl
             WHERE wl.task_id = t.id OR wl.task_id IN (SELECT c.id FROM projects.prj_tasks c WHERE c.parent_id = t.id AND c.delete_status = 'NOT_DELETED'))::int AS time_spent_minutes,
           (SELECT min(c.start_date) FROM projects.prj_tasks c WHERE c.parent_id = t.id AND c.delete_status = 'NOT_DELETED') AS children_start,
           (SELECT max(c.due_date) FROM projects.prj_tasks c WHERE c.parent_id = t.id AND c.delete_status = 'NOT_DELETED') AS children_due,
           t.updated_at
      FROM projects.prj_tasks t
      JOIN projects.prj_projects p ON p.id = t.project_id AND p.delete_status = 'NOT_DELETED'
      JOIN projects.prj_workspaces w ON w.id = p.workspace_id AND w.delete_status = 'NOT_DELETED'
      JOIN projects.prj_statuses st ON st.id = t.status_id
      LEFT JOIN projects.prj_sprints sp ON sp.id = t.sprint_id
      LEFT JOIN core_platform.cp_users au ON au.id = t.assignee_user_id AND au.tenant_id = t.tenant_id
     WHERE t.delete_status = 'NOT_DELETED'
    $v$;

    -- A project, with who may see it (Projects' visibleSQL, as data): open to the business, or its
    -- lead or members; in a workspace open to the business, or its owner or members.
    EXECUTE $v$
    CREATE OR REPLACE VIEW helpdesk.src_projects_projects AS
    SELECT p.tenant_id, p.bus_id, p.id AS project_id, p.key, p.name, p.status, p.is_template,
           p.visibility = 'business' AS project_open, w.visibility = 'business' AS workspace_open,
           array_remove(array_append(coalesce((SELECT array_agg(m.user_id) FROM projects.prj_members m WHERE m.project_id = p.id), '{}'), p.lead_user_id), NULL) AS member_ids,
           array_remove(array_append(coalesce((SELECT array_agg(wm.user_id) FROM projects.prj_workspace_members wm WHERE wm.workspace_id = w.id), '{}'), w.owner_user_id), NULL) AS workspace_member_ids
      FROM projects.prj_projects p
      JOIN projects.prj_workspaces w ON w.id = p.workspace_id AND w.delete_status = 'NOT_DELETED'
     WHERE p.delete_status = 'NOT_DELETED'
    $v$;

    -- How each work request went in Projects' inbox (by its idempotency key = hd_work_links.request_id).
    EXECUTE $v$
    CREATE OR REPLACE VIEW helpdesk.src_projects_requests AS
    SELECT i.tenant_id, i.bus_id, i.idempotency_key AS request_id, i.status, i.last_error, i.attempts,
           i.result ->> 'task_id' AS task_id, i.result ->> 'task_key' AS task_key, i.received_at, i.handled_at
      FROM projects.prj_link_inbox i
     WHERE i.kind = 'helpdesk.work_requested' AND i.source_app = 'app-helpdesk'
    $v$;

    -- ---------------------------------------------------------- what Projects reads of Help Desk
    -- The records linked to work items (made in Help Desk, or ready once a request is taken in).
    EXECUTE $v$
    CREATE OR REPLACE VIEW projects.src_helpdesk_links AS
    SELECT l.tenant_id, l.bus_id, l.id AS link_id, l.task_id, l.record_type, l.record_id, l.origin, l.cdatetime,
           r.number, r.title, r.priority, r.state, r.is_open, r.is_restricted, r.client_account_id
      FROM helpdesk.hd_work_links l
      JOIN LATERAL (
            SELECT k.number, k.subject AS title, k.priority, k.status_category AS state,
                   k.status_category NOT IN ('resolved', 'closed', 'cancelled') AS is_open, k.is_restricted, k.client_account_id
              FROM helpdesk.hd_tickets k
             WHERE l.record_type = 'ticket' AND k.id = l.record_id AND k.tenant_id = l.tenant_id AND k.deleted_at IS NULL AND k.merged_into_id IS NULL
            UNION ALL
            SELECT pr.number, pr.title, pr.priority, pr.state, pr.state NOT IN ('resolved', 'closed'), false, pr.client_account_id
              FROM helpdesk.hd_problems pr
             WHERE l.record_type = 'problem' AND pr.id = l.record_id AND pr.tenant_id = l.tenant_id
            UNION ALL
            SELECT c.number, c.title, CASE c.impact WHEN 'high' THEN 'high' WHEN 'low' THEN 'low' ELSE 'medium' END, c.state,
                   c.state NOT IN ('closed', 'rejected', 'cancelled'), false, c.client_account_id
              FROM helpdesk.hd_changes c
             WHERE l.record_type = 'change' AND c.id = l.record_id AND c.tenant_id = l.tenant_id) r ON true
     WHERE l.task_id IS NOT NULL
    $v$;

    -- The tickets behind each work item -- linked directly, or through a linked problem or change --
    -- with what impact needs: priority, open or not, the SLA (breached, or the soonest resolution
    -- due while running), and who the customer is (a customer party, else the requester).
    EXECUTE $v$
    CREATE OR REPLACE VIEW projects.src_helpdesk_tickets AS
    WITH via AS (
        SELECT l.tenant_id, l.bus_id, l.task_id, l.record_id AS ticket_id, 'ticket'::text AS via
          FROM helpdesk.hd_work_links l WHERE l.task_id IS NOT NULL AND l.record_type = 'ticket'
        UNION
        SELECT l.tenant_id, l.bus_id, l.task_id, pt.ticket_id, 'problem'
          FROM helpdesk.hd_work_links l JOIN helpdesk.hd_problem_tickets pt ON pt.problem_id = l.record_id
         WHERE l.task_id IS NOT NULL AND l.record_type = 'problem'
        UNION
        SELECT l.tenant_id, l.bus_id, l.task_id, ct.ticket_id, 'change'
          FROM helpdesk.hd_work_links l JOIN helpdesk.hd_change_tickets ct ON ct.change_id = l.record_id
         WHERE l.task_id IS NOT NULL AND l.record_type = 'change'
    )
    SELECT v.tenant_id, v.bus_id, v.task_id, v.via, k.id AS ticket_id, k.number, k.subject, k.priority, k.status_category,
           k.status_category NOT IN ('resolved', 'closed', 'cancelled') AS is_open, k.is_restricted, k.client_account_id,
           coalesce(k.customer_party_id, k.requester_user_id, lower(k.requester_email)) AS customer_key,
           coalesce(cp.name, k.requester_name, ru.fullname, k.requester_email) AS customer_name,
           EXISTS (SELECT 1 FROM helpdesk.hd_sla_clocks c WHERE c.ticket_id = k.id AND c.state = 'breached') AS sla_breached,
           (SELECT min(c.due_at) FROM helpdesk.hd_sla_clocks c WHERE c.ticket_id = k.id AND c.state = 'running') AS sla_due_at
      FROM via v
      JOIN helpdesk.hd_tickets k ON k.id = v.ticket_id AND k.tenant_id = v.tenant_id AND k.deleted_at IS NULL AND k.merged_into_id IS NULL
      LEFT JOIN core_platform.cp_parties cp ON cp.id = k.customer_party_id AND cp.tenant_id = k.tenant_id
      LEFT JOIN core_platform.cp_users ru ON ru.id = k.requester_user_id AND ru.tenant_id = k.tenant_id
    $v$;

    -- How each known error raised from Projects went: sent (cp_events), then Help Desk's inbox.
    EXECUTE $v$
    CREATE OR REPLACE VIEW projects.src_helpdesk_known_errors AS
    SELECT e.tenant_id, e.bus_id, e.subject_id AS task_id, e.id AS event_id, e.cdatetime AS sent_at,
           e.payload ->> 'idempotency_key' AS request_id, e.payload #>> '{data,raised_by}' AS raised_by,
           coalesce(i.status, 'SENT') AS status, i.last_error, i.result ->> 'problem_id' AS problem_id,
           i.result ->> 'problem_number' AS problem_number, i.handled_at
      FROM core_platform.cp_events e
      LEFT JOIN helpdesk.hd_link_inbox i ON i.tenant_id = e.tenant_id AND i.source_app = e.source_app
                                         AND i.idempotency_key = e.payload ->> 'idempotency_key'
     WHERE e.kind = 'projects.known_error_raised' AND e.source_app = 'app-projects'
    $v$;
END $$;

-- ===================================================================== checks (invariants, not counts)
DO $$
DECLARE bad text;
BEGIN
    IF to_regclass('core_platform.cp_event_schemas') IS NOT NULL THEN
        SELECT string_agg(kind || ' v' || version, ', ') INTO bad FROM core_platform.cp_event_schemas
         WHERE link_key IN ('helpdesk-projects', 'projects-helpdesk')
           AND (split_part(kind, '.', 1) <> CASE source_app WHEN 'app-helpdesk' THEN 'helpdesk' WHEN 'app-projects' THEN 'projects' END
                OR schema #> '{properties,data}' IS NULL);
        IF bad IS NOT NULL THEN
            RAISE EXCEPTION 'helpdesk-projects: catalogue rows whose prefix does not name the sender, or with no data schema: %', bad;
        END IF;
    END IF;
    -- The links start OFF for everyone: this file must never have switched one on.
    IF to_regclass('core_platform.cp_app_connections') IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM core_platform.cp_app_connections
                    WHERE link_key IN ('helpdesk-projects', 'projects-helpdesk') AND changed_by = 'system') THEN
            RAISE EXCEPTION 'helpdesk-projects: a system row switched a Help Desk <-> Projects link on; they start OFF';
        END IF;
    END IF;
END $$;

COMMIT;
