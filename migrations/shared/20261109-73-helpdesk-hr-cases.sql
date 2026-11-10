-- HR cases on Help Desk, HR data in ZelosHR (Phase 2; tvs-shared-apps-bk docs/helpdesk/contracts/HR.md).
--
-- Two links in Core Platform -> Connected apps, per business, OFF until a business turns them on
-- (no row in cp_app_connections is OFF; this file writes none):
--
--   zeloshr-helpdesk   ZelosHR -> Help Desk: the requester's employee summary on an HR case (read
--                      through helpdesk.src_zeloshr_*), and zeloshr.employee_hired events that open
--                      the onboarding case (Help Desk's inbox helpdesk.hd_link_inbox). Help Desk
--                      RECEIVES and enforces.
--   helpdesk-zeloshr   Help Desk -> ZelosHR: approved onboarding, offboarding and detail-change
--                      cases as events; ZelosHR's inbox zeloshr.zhr_link_inbox does the write with
--                      ZelosHR's own services and rules. ZelosHR RECEIVES and enforces.
--
-- No app writes the other's tables. Bank details never travel in cp_events: ZelosHR reads them from
-- zeloshr.src_helpdesk_hr_bank_changes (the answers of that one case's catalogue request).
--
-- Help Desk confidentiality: hd_departments.is_confidential, hd_tickets.confidentiality
-- (none | department | named) and case_manager_user_id. A trigger derives it (a ticket in a
-- confidential department is at least 'department'; a catalogue item marked 'named' makes its
-- ticket 'named'); it never goes down, and a confidential ticket never moves to a department that
-- is not confidential. Who may see one is decided in the app (visibleTicketsSQL).
--
-- Also: knowledge audience 'department'; hd_hr_actions (what Help Desk asked ZelosHR to do);
-- hd_template_parts (what the HR template made, so it can be set up again idempotently);
-- role-helpdesk-hr-agent; plan feature helpdesk.hr (PREMIUM).
--
-- Idempotent; safe to re-run on every deploy. Nothing is narrowed.

BEGIN;

-- ===================================================================== event catalogue
DO $$
BEGIN
    IF to_regclass('core_platform.cp_event_schemas') IS NULL THEN
        RAISE NOTICE 'helpdesk-hr: no event catalogue here; skipping its rows';
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
        ('helpdesk.hr_onboarding_approved', 1, 'helpdesk-zeloshr', 'app-helpdesk', 'app-zeloshr', 1,
         'An approved new-starter case in Help Desk: ZelosHR makes the draft employee record and its onboarding checklist, as the HR approver.',
         '{"type":"object","required":["request_id","ticket_id","number","requested_by","approved_by","full_name","start_date"],"properties":{
            "request_id":{"type":"string"},"ticket_id":{"type":"string"},"number":{"type":"string"},
            "requested_by":{"type":"string"},"approved_by":{"type":"string"},"full_name":{"type":"string","minLength":1},
            "first_name":{"type":"string"},"last_name":{"type":"string"},"work_email":{"type":"string"},"personal_email":{"type":"string"},
            "phone":{"type":"string"},"job_title":{"type":"string"},"department_name":{"type":"string"},"manager_email":{"type":"string"},
            "start_date":{"type":"string","format":"date"},"employment_type":{"type":"string"},"note":{"type":"string"}}}'::jsonb),
        ('helpdesk.hr_offboarding_approved', 1, 'helpdesk-zeloshr', 'app-helpdesk', 'app-zeloshr', 1,
         'An approved leaver case in Help Desk: ZelosHR opens the exit (resignation, termination or contract end), which starts offboarding, as the HR approver.',
         '{"type":"object","required":["request_id","ticket_id","number","requested_by","approved_by","employee_email","reason","last_working_day"],"properties":{
            "request_id":{"type":"string"},"ticket_id":{"type":"string"},"number":{"type":"string"},
            "requested_by":{"type":"string"},"approved_by":{"type":"string"},"employee_email":{"type":"string"},
            "employee_user_id":{"type":"string"},"reason":{"enum":["resignation","termination","contract_end"]},
            "last_working_day":{"type":"string","format":"date"},"note":{"type":"string"}}}'::jsonb),
        ('helpdesk.hr_detail_change_approved', 1, 'helpdesk-zeloshr', 'app-helpdesk', 'app-zeloshr', 1,
         'An approved change of an employee''s own details: ZelosHR applies it or queues it for HR approval under its self-service rules. Bank details are read from zeloshr.src_helpdesk_hr_bank_changes, never sent.',
         '{"type":"object","required":["request_id","ticket_id","number","requested_by","approved_by","employee_user_id","changes"],"properties":{
            "request_id":{"type":"string"},"ticket_id":{"type":"string"},"number":{"type":"string"},
            "requested_by":{"type":"string"},"approved_by":{"type":"string"},"employee_user_id":{"type":"string"},
            "changes":{"type":"object","additionalProperties":false,"properties":{
              "residential_address":{"type":"string"},"phone":{"type":"string"},"personal_email":{"type":"string"}}},
            "bank_change":{"type":"boolean"}}}'::jsonb),
        ('zeloshr.employee_hired', 1, 'zeloshr-helpdesk', 'app-zeloshr', 'app-helpdesk', 1,
         'A new hire in ZelosHR: Help Desk opens the onboarding case with its fulfilment tasks (IT equipment and accounts), unless it asked for the hire itself.',
         '{"type":"object","required":["employee_id","full_name","hired_by"],"properties":{
            "employee_id":{"type":"string"},"full_name":{"type":"string","minLength":1},"hired_by":{"type":"string"},
            "job_title":{"type":"string"},"department_name":{"type":"string"},"manager_name":{"type":"string"},
            "start_date":{"type":"string","format":"date"},"work_email":{"type":"string"},"origin_request_id":{"type":"string"}}}'::jsonb)
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

-- ===================================================================== plan feature (PREMIUM, never Enterprise-only)
DO $$
BEGIN
    IF to_regclass('core_platform.cp_app_feature_catalog') IS NULL THEN
        RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_app_feature_catalog WHERE app_id = 'app-helpdesk') THEN
        INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
        ('helpdesk.hr', 'app-helpdesk', 'HR Service Delivery', 3,
         'A confidential HR department: HR cases, onboarding and offboarding, grievances with a named case manager, the employee''s ZelosHR record on the case and approved cases carried out in ZelosHR (needs ZelosHR for those)')
        ON CONFLICT (feature_key) DO UPDATE SET app_id = EXCLUDED.app_id, title = EXCLUDED.title,
            min_tier_rank = EXCLUDED.min_tier_rank, description = EXCLUDED.description, is_active = true;
    END IF;
END $$;

-- ===================================================================== Help Desk: confidentiality, actions, template
DO $$
BEGIN
    IF to_regclass('helpdesk.hd_tickets') IS NULL THEN
        RAISE NOTICE 'helpdesk-hr: no helpdesk schema here: its HR tables come with it';
        RETURN;
    END IF;

    ALTER TABLE helpdesk.hd_departments ADD COLUMN IF NOT EXISTS is_confidential boolean NOT NULL DEFAULT false;
    ALTER TABLE helpdesk.hd_tickets ADD COLUMN IF NOT EXISTS confidentiality text NOT NULL DEFAULT 'none';
    ALTER TABLE helpdesk.hd_tickets ADD COLUMN IF NOT EXISTS case_manager_user_id text;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'helpdesk.hd_tickets'::regclass
                    AND conname = 'hd_tickets_confidentiality_check') THEN
        ALTER TABLE helpdesk.hd_tickets ADD CONSTRAINT hd_tickets_confidentiality_check
            CHECK (confidentiality IN ('none', 'department', 'named'));
    END IF;
    CREATE INDEX IF NOT EXISTS hd_tickets_confidential_idx ON helpdesk.hd_tickets (tenant_id, bus_id, department_id)
        WHERE confidentiality <> 'none';

    ALTER TABLE helpdesk.hd_catalog_items ADD COLUMN IF NOT EXISTS confidentiality text NOT NULL DEFAULT 'none';
    ALTER TABLE helpdesk.hd_catalog_items ADD COLUMN IF NOT EXISTS hr_action text;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'helpdesk.hd_catalog_items'::regclass
                    AND conname = 'hd_catalog_items_confidentiality_check') THEN
        ALTER TABLE helpdesk.hd_catalog_items ADD CONSTRAINT hd_catalog_items_confidentiality_check
            CHECK (confidentiality IN ('none', 'named'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'helpdesk.hd_catalog_items'::regclass
                    AND conname = 'hd_catalog_items_hr_action_check') THEN
        ALTER TABLE helpdesk.hd_catalog_items ADD CONSTRAINT hd_catalog_items_hr_action_check
            CHECK (hr_action IS NULL OR hr_action IN ('onboarding', 'offboarding', 'detail_change'));
    END IF;

    -- Knowledge: 'department' = only the article's department's team members (and Help Desk Admin).
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'helpdesk.hd_articles'::regclass
                AND conname = 'hd_articles_audience_check'
                AND pg_get_constraintdef(oid) NOT LIKE '%department%') THEN
        ALTER TABLE helpdesk.hd_articles DROP CONSTRAINT hd_articles_audience_check;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'helpdesk.hd_articles'::regclass
                    AND conname = 'hd_articles_audience_check') THEN
        ALTER TABLE helpdesk.hd_articles ADD CONSTRAINT hd_articles_audience_check
            CHECK (audience IN ('internal', 'employees', 'public', 'department'));
    END IF;

    -- What Help Desk asked ZelosHR to do for a case (one per case), or a case opened from a hire.
    CREATE TABLE IF NOT EXISTS helpdesk.hd_hr_actions (
        id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
        tenant_id    text NOT NULL,
        bus_id       text NOT NULL,
        ticket_id    text NOT NULL,
        kind         text NOT NULL,
        request_id   text NOT NULL,
        event_id     bigint,
        employee_id  text,
        cdatetime    timestamptz NOT NULL DEFAULT now(),
        created_by   text,
        CONSTRAINT hd_hr_actions_kind_check CHECK (kind IN ('onboarding', 'offboarding', 'detail_change', 'hired'))
    );
    CREATE UNIQUE INDEX IF NOT EXISTS hd_hr_actions_request_once ON helpdesk.hd_hr_actions (tenant_id, request_id);
    CREATE UNIQUE INDEX IF NOT EXISTS hd_hr_actions_ticket_once ON helpdesk.hd_hr_actions (tenant_id, bus_id, ticket_id);

    -- The parts a template (the HR department) made, so setting it up again repairs rather than doubles.
    CREATE TABLE IF NOT EXISTS helpdesk.hd_template_parts (
        tenant_id  text NOT NULL,
        bus_id     text NOT NULL,
        template   text NOT NULL,
        part       text NOT NULL,
        ref_id     text NOT NULL,
        cdatetime  timestamptz NOT NULL DEFAULT now(),
        created_by text,
        PRIMARY KEY (tenant_id, bus_id, template, part)
    );

    -- Derivation and stickiness, whatever path writes the ticket.
    CREATE OR REPLACE FUNCTION helpdesk.hd_tickets_confidentiality() RETURNS trigger LANGUAGE plpgsql AS $f$
    DECLARE
        conf boolean := false;
        rank_new int;
        rank_old int;
    BEGIN
        IF NEW.department_id IS NOT NULL THEN
            SELECT d.is_confidential INTO conf FROM helpdesk.hd_departments d
             WHERE d.id = NEW.department_id AND d.tenant_id = NEW.tenant_id;
            conf := coalesce(conf, false);
        END IF;
        IF conf AND NEW.confidentiality = 'none' THEN
            NEW.confidentiality := 'department';
        END IF;
        IF TG_OP = 'UPDATE' THEN
            rank_old := CASE OLD.confidentiality WHEN 'named' THEN 2 WHEN 'department' THEN 1 ELSE 0 END;
            rank_new := CASE NEW.confidentiality WHEN 'named' THEN 2 WHEN 'department' THEN 1 ELSE 0 END;
            IF rank_new < rank_old THEN
                NEW.confidentiality := OLD.confidentiality;
            END IF;
            IF OLD.confidentiality <> 'none' AND NOT conf THEN
                RAISE EXCEPTION 'A confidential case stays in a confidential department.'
                    USING ERRCODE = 'check_violation', CONSTRAINT = 'hd_tickets_confidential_department';
            END IF;
        END IF;
        RETURN NEW;
    END
    $f$;
    DROP TRIGGER IF EXISTS hd_tickets_confidentiality ON helpdesk.hd_tickets;
    CREATE TRIGGER hd_tickets_confidentiality BEFORE INSERT OR UPDATE OF department_id, confidentiality ON helpdesk.hd_tickets
        FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_tickets_confidentiality();

    -- A catalogue item marked 'named' (a grievance) makes its ticket 'named'; its owner is the
    -- first case manager (none: the department's manager names one).
    CREATE OR REPLACE FUNCTION helpdesk.hd_ticket_requests_confidentiality() RETURNS trigger LANGUAGE plpgsql AS $f$
    DECLARE
        it record;
    BEGIN
        SELECT i.confidentiality, i.owner_user_id INTO it FROM helpdesk.hd_catalog_items i
         WHERE i.id = NEW.item_id AND i.tenant_id = NEW.tenant_id;
        IF FOUND AND it.confidentiality = 'named' THEN
            UPDATE helpdesk.hd_tickets
               SET confidentiality = 'named', case_manager_user_id = coalesce(case_manager_user_id, it.owner_user_id)
             WHERE id = NEW.ticket_id AND tenant_id = NEW.tenant_id;
        END IF;
        RETURN NEW;
    END
    $f$;
    DROP TRIGGER IF EXISTS hd_ticket_requests_confidentiality ON helpdesk.hd_ticket_requests;
    CREATE TRIGGER hd_ticket_requests_confidentiality AFTER INSERT ON helpdesk.hd_ticket_requests
        FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_ticket_requests_confidentiality();
END $$;

-- ===================================================================== the HR agent role
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM core_platform.cp_roles WHERE id = 'role-helpdesk-agent') THEN
        RAISE NOTICE 'helpdesk-hr: Help Desk is not registered here; no HR agent role';
        RETURN;
    END IF;
    INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
    ('role-helpdesk-hr-agent', 'system-tenant-id', 'Help Desk HR Agent',
     'Works HR cases: tickets, requests, approvals, fulfilment and HR knowledge. Being on the HR team is what opens HR cases',
     'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
    ON CONFLICT (id) DO UPDATE SET role_name = EXCLUDED.role_name, description = EXCLUDED.description,
        resource_type_id = EXCLUDED.resource_type_id, is_system = EXCLUDED.is_system, is_active = EXCLUDED.is_active;

    -- The Agent's grants without merging, workflows and the IT, customer and MSP resources, plus
    -- writing (not publishing) knowledge. Re-derived on every deploy, so it follows the Agent.
    INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
    SELECT 'system-tenant-id', 'role-helpdesk-hr-agent', p.id, 'Help Desk HR Agent can ' || lower(coalesce(p.description, p.id)),
           CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
      FROM core_platform.cp_permissions p
     WHERE p.delete_status = 'NOT_DELETED'
       AND (p.id IN (SELECT rp.permission_id FROM core_platform.cp_role_permissions rp
                      WHERE rp.role_id = 'role-helpdesk-agent' AND rp.tenant_id = 'system-tenant-id')
            OR (p.app_prefix = 'helpdesk' AND coalesce(p.target, '') = '' AND
                ((p.resource_key = 'knowledge' AND p.action IN ('get', 'create', 'update'))
                 OR (p.resource_key = 'approvals' AND p.action IN ('get', 'approve'))
                 OR (p.resource_key = 'tasks' AND p.action IN ('get', 'create', 'update'))
                 OR (p.resource_key = 'catalog' AND p.action = 'get'))))
       AND NOT (p.app_prefix = 'helpdesk' AND (
                (p.resource_key = 'tickets' AND p.action IN ('merge', 'delete', 'export'))
             OR p.resource_key IN ('workflows', 'incidents', 'problems', 'changes', 'assets', 'cmdb', 'vendors', 'status',
                                   'customers', 'contracts', 'chat', 'channels', 'clients', 'integrations', 'imports', 'ai',
                                   'workorders', 'technicians')
             OR p.action IN ('manage', 'publish', 'export')))
    ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

    -- The core-platform navigation block every app role seeds for itself.
    INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
    SELECT 'system-tenant-id', 'role-helpdesk-hr-agent', p.id
      FROM core_platform.cp_permissions p
     WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                    'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
    ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;
END $$;

-- ===================================================================== ZelosHR: its inbox
DO $$
BEGIN
    IF to_regclass('zeloshr.zhr_employees') IS NULL THEN
        RAISE NOTICE 'helpdesk-hr: no zeloshr schema here: its inbox comes with it';
        RETURN;
    END IF;
    CREATE TABLE IF NOT EXISTS zeloshr.zhr_link_inbox (
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
        CONSTRAINT ck_zhr_link_inbox_status CHECK (status IN ('PENDING', 'RETRY', 'DONE', 'REFUSED', 'DEAD'))
    );
    CREATE UNIQUE INDEX IF NOT EXISTS zhr_link_inbox_once ON zeloshr.zhr_link_inbox (tenant_id, source_app, idempotency_key);
    CREATE INDEX IF NOT EXISTS zhr_link_inbox_due ON zeloshr.zhr_link_inbox (next_attempt_at) WHERE status IN ('PENDING', 'RETRY');
    CREATE INDEX IF NOT EXISTS zhr_link_inbox_business ON zeloshr.zhr_link_inbox (tenant_id, bus_id, received_at DESC);

    CREATE OR REPLACE FUNCTION zeloshr.zhr_link_inbox_retry(p_tenant text, p_bus text, p_ids text[] DEFAULT NULL)
    RETURNS integer LANGUAGE sql AS $f$
        WITH r AS (
            UPDATE zeloshr.zhr_link_inbox
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
    IF to_regclass('helpdesk.hd_hr_actions') IS NULL OR to_regclass('zeloshr.zhr_link_inbox') IS NULL THEN
        RAISE NOTICE 'helpdesk-hr: Help Desk and ZelosHR are not both here: no views';
        RETURN;
    END IF;

    -- ---------------------------------------------------------- what Help Desk reads of ZelosHR
    -- A person, as an HR case shows them. A linked employee's name may live on the platform user.
    EXECUTE $v$
    CREATE OR REPLACE VIEW helpdesk.src_zeloshr_people AS
    SELECT e.tenant_id, e.org_id, e.id::text AS employee_id, e.user_id::text AS user_id,
           coalesce(nullif(btrim(e.full_name), ''), nullif(btrim(concat_ws(' ', e.first_name, e.last_name)), ''), cu.fullname) AS full_name,
           e.work_email, cu.email AS user_email, e.job_title, d.name AS department_name,
           coalesce(nullif(btrim(m.full_name), ''), mu.fullname) AS manager_name,
           coalesce(e.employment_start_date, e.start_date) AS start_date, e.employment_status, coalesce(e.is_draft, false) AS is_draft
      FROM zeloshr.zhr_employees e
      LEFT JOIN core_platform.cp_users cu ON cu.id = e.user_id AND cu.tenant_id = e.tenant_id
      LEFT JOIN zeloshr.zhr_departments d ON d.id = e.department_id AND d.tenant_id = e.tenant_id
      LEFT JOIN zeloshr.zhr_employees m ON m.id = coalesce(e.manager_id, e.reports_to_id) AND m.tenant_id = e.tenant_id
      LEFT JOIN core_platform.cp_users mu ON mu.id = m.user_id AND mu.tenant_id = m.tenant_id
     WHERE coalesce(e.is_deleted, false) = false
    $v$;

    EXECUTE $v$
    CREATE OR REPLACE VIEW helpdesk.src_zeloshr_leave AS
    SELECT b.tenant_id, b.org_id, b.employee_id::text AS employee_id, coalesce(t.name, b.leave_type) AS leave_type,
           b.entitled_days, b.used_days, b.remaining_days
      FROM zeloshr.zhr_leave_balances b
      LEFT JOIN zeloshr.zhr_leave_types t ON t.id = b.leave_type_id AND t.tenant_id = b.tenant_id
    $v$;

    -- Pay: Help Desk shows it only to a viewer holding ZelosHR's payroll read. Never a full account number.
    EXECUTE $v$
    CREATE OR REPLACE VIEW helpdesk.src_zeloshr_pay AS
    SELECT e.tenant_id, e.org_id, e.id::text AS employee_id, e.gross_salary, e.net_salary, e.currency_id AS currency,
           e.pay_frequency, coalesce(pm.payment_mode, e.payment_method) AS payment_method, pm.bank_name,
           right(regexp_replace(coalesce(pm.account_number, e.bank_account_number, e.mobile_money_number, ''), '\s', '', 'g'), 4) AS account_last4
      FROM zeloshr.zhr_employees e
      LEFT JOIN LATERAL (SELECT p.payment_mode, p.bank_name, p.account_number FROM zeloshr.zhr_employee_payment_methods p
                          WHERE p.employee_id = e.id ORDER BY p.is_primary DESC, p.updated_at DESC NULLS LAST LIMIT 1) pm ON true
     WHERE coalesce(e.is_deleted, false) = false
    $v$;

    -- How each request went in ZelosHR's inbox (by its idempotency key = hd_hr_actions.request_id).
    EXECUTE $v$
    CREATE OR REPLACE VIEW helpdesk.src_zeloshr_requests AS
    SELECT i.tenant_id, i.bus_id, i.idempotency_key AS request_id, i.kind, i.status, i.last_error, i.attempts, i.result,
           i.received_at, i.handled_at
      FROM zeloshr.zhr_link_inbox i
     WHERE i.source_app = 'app-helpdesk'
    $v$;

    -- ---------------------------------------------------------- what ZelosHR reads of Help Desk
    -- The bank or mobile-money details of one approved detail change, from that case's own request.
    EXECUTE $v$
    CREATE OR REPLACE VIEW zeloshr.src_helpdesk_hr_bank_changes AS
    SELECT a.tenant_id, a.bus_id, a.ticket_id, a.request_id,
           nullif(btrim(r.answers ->> 'bank_name'), '') AS bank_name,
           nullif(btrim(r.answers ->> 'account_name'), '') AS account_name,
           nullif(btrim(r.answers ->> 'account_number'), '') AS account_number,
           nullif(btrim(r.answers ->> 'branch_name'), '') AS branch_name,
           nullif(btrim(r.answers ->> 'mobile_money_number'), '') AS mobile_money_number
      FROM helpdesk.hd_hr_actions a
      JOIN helpdesk.hd_ticket_requests r ON r.ticket_id = a.ticket_id AND r.tenant_id = a.tenant_id AND r.bus_id = a.bus_id
     WHERE a.kind = 'detail_change'
    $v$;
END $$;

-- ===================================================================== Projects never reads an HR case
-- 20261109-31's two views over Help Desk's tickets, restated with confidential cases left out (that
-- file re-runs first on every deploy; this one wins). Linking an HR case to Projects is refused in
-- the app; this keeps a case that became confidential after it was linked out of Projects too.
DO $$
BEGIN
    IF to_regclass('helpdesk.hd_work_links') IS NULL OR to_regclass('projects.prj_tasks') IS NULL
       OR NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'helpdesk' AND table_name = 'hd_tickets'
                       AND column_name = 'confidentiality') THEN
        RETURN;
    END IF;
    EXECUTE $v$
    CREATE OR REPLACE VIEW projects.src_helpdesk_links AS
    SELECT l.tenant_id, l.bus_id, l.id AS link_id, l.task_id, l.record_type, l.record_id, l.origin, l.cdatetime,
           r.number, r.title, r.priority, r.state, r.is_open, r.is_restricted, r.client_account_id
      FROM helpdesk.hd_work_links l
      JOIN LATERAL (
            SELECT k.number, k.subject AS title, k.priority, k.status_category AS state,
                   k.status_category NOT IN ('resolved', 'closed', 'cancelled') AS is_open, k.is_restricted, k.client_account_id
              FROM helpdesk.hd_tickets k
             WHERE l.record_type = 'ticket' AND k.id = l.record_id AND k.tenant_id = l.tenant_id AND k.deleted_at IS NULL AND k.merged_into_id IS NULL AND k.confidentiality = 'none'
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
      JOIN helpdesk.hd_tickets k ON k.id = v.ticket_id AND k.tenant_id = v.tenant_id AND k.deleted_at IS NULL AND k.merged_into_id IS NULL AND k.confidentiality = 'none'
      LEFT JOIN core_platform.cp_parties cp ON cp.id = k.customer_party_id AND cp.tenant_id = k.tenant_id
      LEFT JOIN core_platform.cp_users ru ON ru.id = k.requester_user_id AND ru.tenant_id = k.tenant_id
    $v$;
END $$;

-- ===================================================================== checks (invariants, not counts)
DO $$
DECLARE bad text;
BEGIN
    IF to_regclass('core_platform.cp_event_schemas') IS NOT NULL THEN
        SELECT string_agg(kind || ' v' || version, ', ') INTO bad FROM core_platform.cp_event_schemas
         WHERE link_key IN ('helpdesk-zeloshr', 'zeloshr-helpdesk')
           AND (split_part(kind, '.', 1) <> CASE source_app WHEN 'app-helpdesk' THEN 'helpdesk' WHEN 'app-zeloshr' THEN 'zeloshr' END
                OR schema #> '{properties,data}' IS NULL);
        IF bad IS NOT NULL THEN
            RAISE EXCEPTION 'helpdesk-hr: catalogue rows whose prefix does not name the sender, or with no data schema: %', bad;
        END IF;
        -- Bank details never travel in an event.
        IF EXISTS (SELECT 1 FROM core_platform.cp_event_schemas WHERE link_key = 'helpdesk-zeloshr'
                    AND schema::text ~ '(account_number|bank_name|mobile_money)') THEN
            RAISE EXCEPTION 'helpdesk-hr: a Help Desk -> ZelosHR event schema carries bank details';
        END IF;
    END IF;
    IF to_regclass('core_platform.cp_app_connections') IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM core_platform.cp_app_connections
                    WHERE link_key IN ('helpdesk-zeloshr', 'zeloshr-helpdesk') AND changed_by = 'system') THEN
            RAISE EXCEPTION 'helpdesk-hr: a system row switched a Help Desk <-> ZelosHR link on; they start OFF';
        END IF;
    END IF;
    IF to_regclass('core_platform.cp_app_feature_catalog') IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM core_platform.cp_app_feature_catalog WHERE feature_key = 'helpdesk.hr' AND min_tier_rank >= 4) THEN
            RAISE EXCEPTION 'helpdesk-hr: helpdesk.hr is gated at ENTERPRISE';
        END IF;
    END IF;
    -- The HR agent never holds the Service Manager's own rights.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-helpdesk-hr-agent' AND p.app_prefix = 'helpdesk'
                  AND (p.action IN ('manage', 'publish', 'export') OR (p.resource_key = 'workflows'))) THEN
        RAISE EXCEPTION 'helpdesk-hr: Help Desk HR Agent holds a manage, publish, export or workflow permission';
    END IF;
END $$;

COMMIT;
