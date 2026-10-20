-- Projects: suite links -- a work item linked to a CRM deal or ticket, a MyStoreGuard job or a
-- LoanDrift loan, each shown with its live state, and the link shown back in that app.
--
--   * prj_suite_links: the link. app is crm_deal, crm_ticket, msg_job or ld_loan; ref_id the
--     record's id there. Made in Projects; never written into the other app.
--   * projects.src_crm_deals, src_crm_tickets, src_ld_loans (src_msg_jobs exists): what a link
--     card shows, read-only, each only where that app is installed.
--   * crm.src_projects_links, mystoreguard.src_projects_links, loandrift.src_projects_links: the
--     same links seen from the other side -- each app lists the work items linked to its
--     records, read-only, only where both apps are installed. is_open: the item's project and
--     workspace are open to the whole business -- the only ones another app may name.
--
-- Whether any of it SHOWS is decided per request: the business must be subscribed to both apps
-- (core_platform.cp_business_app_tier), and the person must be allowed to read the record.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS projects.prj_suite_links (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    task_id     text NOT NULL REFERENCES projects.prj_tasks (id) ON DELETE CASCADE,
    app         text NOT NULL CHECK (app IN ('crm_deal', 'crm_ticket', 'msg_job', 'ld_loan')),
    ref_id      text NOT NULL,
    created_by  text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (task_id, app, ref_id)
);
CREATE INDEX IF NOT EXISTS prj_suite_links_ref_idx ON projects.prj_suite_links (tenant_id, app, ref_id);

DO $$
BEGIN
    -- ------------------------------------------------------------- what a card shows
    IF to_regclass('crm.crm_deals') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW projects.src_crm_deals AS
        SELECT d.tenant_id, d.bus_id, d.id, d.title, d.status, d.amount, coalesce(cu.code, '') AS currency,
               coalesce(st.name, '') AS stage, d.expected_close_date, ou.fullname AS owner_name, d.updated_at
          FROM crm.crm_deals d
          LEFT JOIN crm.crm_pipeline_stages st ON st.id = d.stage_id
          LEFT JOIN core_platform.cp_currencies cu ON cu.id = d.currency_id
          LEFT JOIN core_platform.cp_users ou ON ou.id = d.owner_user_id AND ou.tenant_id = d.tenant_id
         WHERE d.delete_status = 'NOT_DELETED'
        $v$;
    END IF;
    IF to_regclass('crm.crm_tickets') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW projects.src_crm_tickets AS
        SELECT t.tenant_id, t.bus_id, t.id, t.number, t.subject, t.status, t.priority, au.fullname AS assignee_name,
               t.resolution_due_at, t.updated_at
          FROM crm.crm_tickets t
          LEFT JOIN core_platform.cp_users au ON au.id = t.assignee_user_id AND au.tenant_id = t.tenant_id
         WHERE t.delete_status = 'NOT_DELETED'
        $v$;
    END IF;
    IF to_regclass('loandrift.ld_loan_details') IS NOT NULL AND to_regclass('loandrift.ld_clients') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW projects.src_ld_loans AS
        SELECT l.tenant_id, l.bus_id, l.id, coalesce(l.loan_reference, l.registration_id, '') AS reference, coalesce(l.status, '') AS status,
               l.requested_amount AS amount, coalesce(cu.code, '') AS currency, coalesce(l.loan_type, '') AS loan_type,
               coalesce(nullif(c.fullname, ''), concat_ws(' ', c.first_name, c.surname)) AS client_name, l.cdatetime
          FROM loandrift.ld_loan_details l
          LEFT JOIN loandrift.ld_clients c ON c.id = l.client_id AND c.tenant_id = l.tenant_id
          LEFT JOIN core_platform.cp_currencies cu ON cu.id = l.currency_id
         WHERE coalesce(l.delete_status, 'NOT_DELETED') = 'NOT_DELETED'
        $v$;
    END IF;

    -- ------------------------------------------------------------- the other side
    IF to_regclass('crm.crm_deals') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW crm.src_projects_links AS
        SELECT l.tenant_id, l.bus_id, l.app, l.ref_id, t.id AS task_id, p.key || '-' || t.number AS task_key, t.title,
               st.name AS status_name, st.category AS status_category, p.name AS project_name, t.due_date, au.fullname AS assignee_name,
               (p.visibility = 'business' AND w.visibility = 'business') AS is_open, p.id AS project_id
          FROM projects.prj_suite_links l
          JOIN projects.prj_tasks t ON t.id = l.task_id AND t.delete_status = 'NOT_DELETED'
          JOIN projects.prj_projects p ON p.id = t.project_id AND p.delete_status = 'NOT_DELETED'
          JOIN projects.prj_workspaces w ON w.id = p.workspace_id AND w.delete_status = 'NOT_DELETED'
          JOIN projects.prj_statuses st ON st.id = t.status_id
          LEFT JOIN core_platform.cp_users au ON au.id = t.assignee_user_id AND au.tenant_id = t.tenant_id
         WHERE l.app IN ('crm_deal', 'crm_ticket')
        $v$;
    END IF;
    IF to_regclass('mystoreguard.msg_tasks') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW mystoreguard.src_projects_links AS
        SELECT l.tenant_id, l.bus_id, l.ref_id AS msg_task_id, t.id AS task_id, p.key || '-' || t.number AS task_key, t.title,
               st.name AS status_name, st.category AS status_category, p.name AS project_name, t.due_date, au.fullname AS assignee_name,
               (p.visibility = 'business' AND w.visibility = 'business') AS is_open
          FROM projects.prj_suite_links l
          JOIN projects.prj_tasks t ON t.id = l.task_id AND t.delete_status = 'NOT_DELETED'
          JOIN projects.prj_projects p ON p.id = t.project_id AND p.delete_status = 'NOT_DELETED'
          JOIN projects.prj_workspaces w ON w.id = p.workspace_id AND w.delete_status = 'NOT_DELETED'
          JOIN projects.prj_statuses st ON st.id = t.status_id
          LEFT JOIN core_platform.cp_users au ON au.id = t.assignee_user_id AND au.tenant_id = t.tenant_id
         WHERE l.app = 'msg_job'
        $v$;
    END IF;
    IF to_regclass('loandrift.ld_loan_details') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW loandrift.src_projects_links AS
        SELECT l.tenant_id, l.bus_id, l.ref_id AS loan_id, t.id AS task_id, p.key || '-' || t.number AS task_key, t.title,
               st.name AS status_name, st.category AS status_category, p.name AS project_name, t.due_date, au.fullname AS assignee_name,
               (p.visibility = 'business' AND w.visibility = 'business') AS is_open
          FROM projects.prj_suite_links l
          JOIN projects.prj_tasks t ON t.id = l.task_id AND t.delete_status = 'NOT_DELETED'
          JOIN projects.prj_projects p ON p.id = t.project_id AND p.delete_status = 'NOT_DELETED'
          JOIN projects.prj_workspaces w ON w.id = p.workspace_id AND w.delete_status = 'NOT_DELETED'
          JOIN projects.prj_statuses st ON st.id = t.status_id
          LEFT JOIN core_platform.cp_users au ON au.id = t.assignee_user_id AND au.tenant_id = t.tenant_id
         WHERE l.app = 'ld_loan'
        $v$;
    END IF;
END $$;

COMMIT;
