-- Projects: time and money -- billable hours, rates, budgets, expenses, profit and invoices.
--
--   * prj_projects gains how it is billed (hourly from logged time, a fixed fee, or not at
--     all), its currency (NULL: the business's default), a budget in money and/or hours, whether
--     new time is billable unless said otherwise, and who it is billed to. budget_alert_level is
--     the last share of the budget (80, 100) its people were told about, so each is said once.
--   * prj_worklogs.billable: whether the time is charged to the client. invoice_id: the invoice
--     that billed it, invoice_line_id the line; billed time cannot be changed until that
--     invoice is voided (or the line taken off the draft).
--   * prj_rate_roles: the role each person works as in a workspace (Designer, Developer), for
--     rates set by role.
--   * prj_rates: what an hour is charged at (bill_rate) and what it costs (cost_rate). A row is
--     for a workspace or one of its projects, and for a person, a role, or everyone. The most
--     specific wins, each rate on its own: project+person, project+role, project, then the same
--     for the workspace.
--   * prj_expenses: money spent on a project (travel, materials), billable or not, and the
--     invoice that billed it.
--   * prj_invoices / prj_invoice_lines: an invoice for a project's unbilled billable time and
--     expenses (or its fixed fee), numbered per business once issued. The lines keep the
--     hours, rates and amounts as they were billed. Voiding releases what it billed.
--   * prj_invoice_numbers: the last number given per business.
--   * permissions projects|money|<get|manage>: rates, costs, budgets, profit and invoices.
--     Managers both; members and viewers neither (they still mark their time billable).
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE projects.prj_projects ADD COLUMN IF NOT EXISTS billing text NOT NULL DEFAULT 'hourly';
ALTER TABLE projects.prj_projects DROP CONSTRAINT IF EXISTS prj_projects_billing_check;
ALTER TABLE projects.prj_projects ADD CONSTRAINT prj_projects_billing_check CHECK (billing IN ('hourly', 'fixed', 'none'));
ALTER TABLE projects.prj_projects ADD COLUMN IF NOT EXISTS fixed_fee numeric(14, 2) CHECK (fixed_fee IS NULL OR fixed_fee >= 0);
ALTER TABLE projects.prj_projects ADD COLUMN IF NOT EXISTS currency text;
ALTER TABLE projects.prj_projects ADD COLUMN IF NOT EXISTS budget_amount numeric(14, 2) CHECK (budget_amount IS NULL OR budget_amount >= 0);
ALTER TABLE projects.prj_projects ADD COLUMN IF NOT EXISTS budget_hours numeric(10, 2) CHECK (budget_hours IS NULL OR budget_hours >= 0);
ALTER TABLE projects.prj_projects ADD COLUMN IF NOT EXISTS billable_default boolean NOT NULL DEFAULT true;
ALTER TABLE projects.prj_projects ADD COLUMN IF NOT EXISTS client_name text;
ALTER TABLE projects.prj_projects ADD COLUMN IF NOT EXISTS client_email text;
ALTER TABLE projects.prj_projects ADD COLUMN IF NOT EXISTS client_address text;
ALTER TABLE projects.prj_projects ADD COLUMN IF NOT EXISTS budget_alert_level integer NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS projects.prj_rate_roles (
    workspace_id  text NOT NULL REFERENCES projects.prj_workspaces (id) ON DELETE CASCADE,
    user_id       text NOT NULL,
    tenant_id     text NOT NULL,
    role          text NOT NULL CHECK (btrim(role) <> ''),
    updated_by    text,
    updated_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, user_id)
);

CREATE TABLE IF NOT EXISTS projects.prj_rates (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    workspace_id  text NOT NULL REFERENCES projects.prj_workspaces (id) ON DELETE CASCADE,
    project_id    text REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    user_id       text,
    role          text,
    bill_rate     numeric(12, 2) CHECK (bill_rate IS NULL OR bill_rate >= 0),
    cost_rate     numeric(12, 2) CHECK (cost_rate IS NULL OR cost_rate >= 0),
    updated_by    text,
    updated_at    timestamptz NOT NULL DEFAULT now(),
    CHECK (user_id IS NULL OR role IS NULL)
);
CREATE UNIQUE INDEX IF NOT EXISTS prj_rates_uq ON projects.prj_rates
    (workspace_id, coalesce(project_id, ''), coalesce(user_id, ''), coalesce(lower(role), ''));

CREATE TABLE IF NOT EXISTS projects.prj_invoices (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    project_id       text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    -- Given when issued; a draft has none.
    number           text,
    status           text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'issued', 'paid', 'void')),
    currency         text NOT NULL,
    issue_date       date,
    due_date         date,
    period_from      date,
    period_to        date,
    bill_to_name     text NOT NULL DEFAULT '',
    bill_to_email    text NOT NULL DEFAULT '',
    bill_to_address  text NOT NULL DEFAULT '',
    notes            text NOT NULL DEFAULT '',
    tax_rate         numeric(6, 3) NOT NULL DEFAULT 0 CHECK (tax_rate >= 0 AND tax_rate <= 100),
    subtotal         numeric(14, 2) NOT NULL DEFAULT 0,
    tax_amount       numeric(14, 2) NOT NULL DEFAULT 0,
    total            numeric(14, 2) NOT NULL DEFAULT 0,
    issued_at        timestamptz,
    sent_at          timestamptz,
    paid_at          timestamptz,
    voided_at        timestamptz,
    created_by       text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS prj_invoices_number_uq ON projects.prj_invoices (tenant_id, bus_id, number) WHERE number IS NOT NULL;
CREATE INDEX IF NOT EXISTS prj_invoices_project_idx ON projects.prj_invoices (project_id, cdatetime DESC);

CREATE TABLE IF NOT EXISTS projects.prj_invoice_lines (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    invoice_id   text NOT NULL REFERENCES projects.prj_invoices (id) ON DELETE CASCADE,
    tenant_id    text NOT NULL,
    position     integer NOT NULL DEFAULT 0,
    kind         text NOT NULL CHECK (kind IN ('time', 'expense', 'fixed', 'other')),
    description  text NOT NULL CHECK (btrim(description) <> ''),
    quantity     numeric(12, 2) NOT NULL DEFAULT 1,
    unit_price   numeric(14, 2) NOT NULL DEFAULT 0,
    amount       numeric(14, 2) NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS prj_invoice_lines_invoice_idx ON projects.prj_invoice_lines (invoice_id, position);

CREATE TABLE IF NOT EXISTS projects.prj_invoice_numbers (
    tenant_id  text NOT NULL,
    bus_id     text NOT NULL,
    last       integer NOT NULL DEFAULT 0,
    PRIMARY KEY (tenant_id, bus_id)
);

ALTER TABLE projects.prj_worklogs ADD COLUMN IF NOT EXISTS billable boolean NOT NULL DEFAULT true;
ALTER TABLE projects.prj_worklogs ADD COLUMN IF NOT EXISTS invoice_id text REFERENCES projects.prj_invoices (id) ON DELETE SET NULL;
-- The line that bills it: removing the line from a draft frees the time (the key goes NULL).
ALTER TABLE projects.prj_worklogs ADD COLUMN IF NOT EXISTS invoice_line_id text REFERENCES projects.prj_invoice_lines (id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS prj_worklogs_unbilled_idx ON projects.prj_worklogs (project_id, work_date) WHERE billable AND invoice_id IS NULL;

CREATE TABLE IF NOT EXISTS projects.prj_expenses (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    project_id     text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    task_id        text REFERENCES projects.prj_tasks (id) ON DELETE SET NULL,
    spent_on       date NOT NULL,
    description    text NOT NULL CHECK (btrim(description) <> ''),
    category       text NOT NULL DEFAULT '',
    amount         numeric(14, 2) NOT NULL CHECK (amount > 0),
    billable       boolean NOT NULL DEFAULT true,
    invoice_id     text REFERENCES projects.prj_invoices (id) ON DELETE SET NULL,
    created_by     text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    delete_status  text NOT NULL DEFAULT 'NOT_DELETED'
);
ALTER TABLE projects.prj_expenses ADD COLUMN IF NOT EXISTS invoice_line_id text REFERENCES projects.prj_invoice_lines (id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS prj_expenses_project_idx ON projects.prj_expenses (project_id, spent_on) WHERE delete_status = 'NOT_DELETED';

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-projects-money', 'Projects Money', 'Rates, costs, budgets, profit and invoices', 'rt-subscribed-app-projects')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(action, label) AS (VALUES
    ('get',    'See rates, costs, budgets, profit and invoices'),
    ('manage', 'Set rates and budgets, record expenses and raise invoices')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-projects-money-' || spec.action, 'Projects Money ' || initcap(spec.action), 'rt-projects-money',
       spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name = EXCLUDED.permission_name, description = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'projects', resource_key = 'money', action = substring(p.id FROM '-([a-z]+)$'), target = '', scope = 'any'
 WHERE p.id LIKE 'permission-projects-money-%' AND (p.app_prefix IS DISTINCT FROM 'projects' OR p.action IS NULL);

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', g.role_id, p.id, r.role_name || ' can ' || lower(p.description), CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (VALUES ('role-projects-manager', 'get'), ('role-projects-manager', 'manage')) AS g(role_id, action)
  JOIN core_platform.cp_roles r ON r.id = g.role_id
  JOIN core_platform.cp_permissions p ON p.app_prefix = 'projects' AND p.resource_key = 'money' AND p.action = g.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE p.app_prefix = 'projects' AND p.resource_key = 'money'
                  AND rp.role_id IN ('role-projects-member', 'role-projects-viewer')) THEN
        RAISE EXCEPTION 'members and viewers must not see money';
    END IF;
END $$;

COMMIT;
