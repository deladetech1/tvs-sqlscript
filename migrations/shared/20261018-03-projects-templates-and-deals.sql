-- Projects: project templates, and projects started from won CRM deals.
--
--   * prj_projects.is_template: a project kept as a starting point. A new project made from it
--     copies its statuses, boards and folders, fields, automation, item templates, milestones,
--     work (dates moved to the new start, unassigned, not started), project docs and how it is
--     billed. template_id says which template a project came from.
--   * prj_projects.crm_deal_id / crm_company_id: the CRM deal a project was started for, and
--     its account. One project per deal.
--   * prj_deal_rules: "when a deal is won, start a project from this template" -- for a
--     workspace, all pipelines or one. Only deals won after the rule was made (since) start
--     one, so turning it on never starts projects for last year's deals.
--   * projects.src_crm_deal_details: a deal as a project needs it -- its account and contact --
--     read-only, where the CRM is installed.
--   * crm.src_projects: projects started for deals, seen from the CRM: for a deal's and an
--     account's page. is_open: project and workspace open to the whole business, the only ones
--     the CRM may name.
--
-- Whether any of it shows is decided per request: the business must be subscribed to both apps.
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE projects.prj_projects ADD COLUMN IF NOT EXISTS is_template boolean NOT NULL DEFAULT false;
ALTER TABLE projects.prj_projects ADD COLUMN IF NOT EXISTS template_id text REFERENCES projects.prj_projects (id) ON DELETE SET NULL;
ALTER TABLE projects.prj_projects ADD COLUMN IF NOT EXISTS crm_deal_id text;
ALTER TABLE projects.prj_projects ADD COLUMN IF NOT EXISTS crm_company_id text;
CREATE UNIQUE INDEX IF NOT EXISTS prj_projects_deal_uq ON projects.prj_projects (tenant_id, crm_deal_id)
    WHERE crm_deal_id IS NOT NULL AND delete_status = 'NOT_DELETED';
CREATE INDEX IF NOT EXISTS prj_projects_company_idx ON projects.prj_projects (tenant_id, crm_company_id) WHERE crm_company_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS projects.prj_deal_rules (
    id                   text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id            text NOT NULL,
    bus_id               text NOT NULL,
    workspace_id         text NOT NULL REFERENCES projects.prj_workspaces (id) ON DELETE CASCADE,
    template_project_id  text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    -- NULL: every pipeline.
    pipeline_id          text,
    enabled              boolean NOT NULL DEFAULT true,
    since                timestamptz NOT NULL DEFAULT now(),
    created_by           text,
    cdatetime            timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prj_deal_rules_bus_idx ON projects.prj_deal_rules (tenant_id, bus_id) WHERE enabled;

DO $$
BEGIN
    IF to_regclass('crm.crm_deals') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW projects.src_crm_deal_details AS
        SELECT d.tenant_id, d.bus_id, d.id, d.title, d.status, d.amount, coalesce(cu.code, '') AS currency, d.pipeline_id,
               d.closed_at, d.owner_user_id, d.company_id, co.name AS company_name, coalesce(co.email, '') AS company_email,
               concat_ws(E'\n', nullif(co.address_line, ''), nullif(co.city, ''), nullif(co.region, ''), nullif(co.country, '')) AS company_address,
               d.contact_id, ct.full_name AS contact_name, coalesce(ct.primary_email, '') AS contact_email, pl.name AS pipeline_name
          FROM crm.crm_deals d
          LEFT JOIN crm.crm_pipelines pl ON pl.id = d.pipeline_id
          LEFT JOIN crm.crm_companies co ON co.id = d.company_id AND co.tenant_id = d.tenant_id AND co.delete_status = 'NOT_DELETED'
          LEFT JOIN crm.crm_contacts ct ON ct.id = d.contact_id AND ct.tenant_id = d.tenant_id AND ct.delete_status = 'NOT_DELETED'
          LEFT JOIN core_platform.cp_currencies cu ON cu.id = d.currency_id
         WHERE d.delete_status = 'NOT_DELETED'
        $v$;

        EXECUTE $v$
        CREATE OR REPLACE VIEW crm.src_projects AS
        SELECT p.tenant_id, p.bus_id, p.id AS project_id, p.key, p.name, p.crm_deal_id, p.crm_company_id, p.status,
               (p.visibility = 'business' AND w.visibility = 'business') AS is_open,
               (SELECT count(*) FROM projects.prj_tasks t JOIN projects.prj_statuses st ON st.id = t.status_id
                 WHERE t.project_id = p.id AND t.delete_status = 'NOT_DELETED' AND st.category <> 'done')::int AS open_count,
               (SELECT count(*) FROM projects.prj_tasks t JOIN projects.prj_statuses st ON st.id = t.status_id
                 WHERE t.project_id = p.id AND t.delete_status = 'NOT_DELETED' AND st.category = 'done')::int AS done_count,
               (SELECT count(*) FROM projects.prj_tasks t JOIN projects.prj_statuses st ON st.id = t.status_id
                 WHERE t.project_id = p.id AND t.delete_status = 'NOT_DELETED' AND st.category <> 'done' AND t.due_date < CURRENT_DATE)::int AS overdue_count,
               (SELECT su.health FROM projects.prj_status_updates su WHERE su.project_id = p.id AND su.delete_status = 'NOT_DELETED'
                 ORDER BY su.cdatetime DESC LIMIT 1) AS reported_health,
               lu.fullname AS lead_name, p.cdatetime
          FROM projects.prj_projects p
          JOIN projects.prj_workspaces w ON w.id = p.workspace_id AND w.delete_status = 'NOT_DELETED'
          LEFT JOIN core_platform.cp_users lu ON lu.id = p.lead_user_id AND lu.tenant_id = p.tenant_id
         WHERE p.delete_status = 'NOT_DELETED' AND (p.crm_deal_id IS NOT NULL OR p.crm_company_id IS NOT NULL)
        $v$;
    END IF;
END $$;

COMMIT;
