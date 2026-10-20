-- Expenses joins the platform: claims, approvals, paying people back, budgets.
--
-- Served by the shared apps backend (deladetech1/tvs-shared-apps-bk, module "expenses")
-- like the CRM, Projects and Invoicing; frontend tvs-expenses-ft. Its cp_apps row and tier
-- prices live in the CorePlatform seed (04_others.sql), which owns every app row. This file
-- holds the rest:
--
--   * the expenses schema and its audit trail (exp_audit_logs); the claims, categories,
--     policies and the rest come in later files;
--   * its cp_app_schemas row, so activity-log retention finds expenses.exp_audit_logs;
--   * resource types, permissions (expenses|<resource>|<action>||any) and the roles:
--     Expenses Admin is allowed by BEING the role (tvs-package-go appAdminRoles) and holds
--     no Expenses rows; Finance Manager, Approver, Employee and Viewer carry grants.
--     Everyone may claim their own expenses with claims|create; claims|get is seeing
--     EVERYONE's (an employee sees their own without it);
--   * the reserved label "expenses" and the frontend's route row.
--
-- Nothing here asserts on rows a module seed creates. Idempotent; safe to re-run.

BEGIN;

CREATE SCHEMA IF NOT EXISTS expenses;

INSERT INTO core_platform.cp_app_schemas (app_id, schema_name, description)
VALUES ('app-expenses', 'expenses', 'Expenses audit logs')
ON CONFLICT (app_id) DO UPDATE SET schema_name = EXCLUDED.schema_name,
                                   description = EXCLUDED.description;

CREATE TABLE IF NOT EXISTS expenses.exp_audit_logs (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    org_id       text,
    bus_id       text,
    entity_type  text NOT NULL,
    entity_id    text NOT NULL,
    action       text NOT NULL,
    changes      jsonb NOT NULL DEFAULT '{}',
    actor_id     text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS exp_audit_entity_idx
    ON expenses.exp_audit_logs (tenant_id, entity_type, entity_id, cdatetime DESC);

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-subscribed-app-expenses', 'EXPENSES APP', 'Expenses Subscribed APP', NULL)
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-expenses-claims',   'Expenses Claims',   'Expense claims, their receipts and approvals', 'rt-subscribed-app-expenses'),
('rt-expenses-payouts',  'Expenses Payouts',  'Paying approved claims back',                  'rt-subscribed-app-expenses'),
('rt-expenses-settings', 'Expenses Settings', 'Categories, policies, mileage and approvals',  'rt-subscribed-app-expenses'),
('rt-expenses-reports',  'Expenses Reports',  'Spend by category, person, project and month', 'rt-subscribed-app-expenses'),
('rt-expenses-logs',     'Expenses Logs',     'The audit trail of Expenses',                  'rt-subscribed-app-expenses')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('claims',   'rt-expenses-claims',   'create',  'Claim their own expenses'),
    ('claims',   'rt-expenses-claims',   'get',     'View everyone''s claims'),
    ('claims',   'rt-expenses-claims',   'approve', 'Approve claims sent to them'),
    ('claims',   'rt-expenses-claims',   'reject',  'Send claims back or reject them'),
    ('claims',   'rt-expenses-claims',   'export',  'Export claims'),
    ('payouts',  'rt-expenses-payouts',  'get',     'View what has been paid back'),
    ('payouts',  'rt-expenses-payouts',  'pay',     'Pay approved claims back'),
    ('settings', 'rt-expenses-settings', 'get',     'View categories, policies and approvals'),
    ('settings', 'rt-expenses-settings', 'manage',  'Set categories, policies, mileage rates and approvals'),
    ('reports',  'rt-expenses-reports',  'get',     'View spend reports'),
    ('reports',  'rt-expenses-reports',  'export',  'Export spend reports'),
    ('logs',     'rt-expenses-logs',     'get',     'View the Expenses audit trail')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-expenses-' || spec.resource_key || '-' || spec.action,
       'Expenses ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'expenses',
       resource_key = substring(p.id FROM '^permission-expenses-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-expenses-%'
   AND (p.app_prefix IS DISTINCT FROM 'expenses' OR p.action IS NULL);

-- ========================================================================== roles
INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-subscribed-app-expenses-admin', 'system-tenant-id', 'Expenses Admin', 'Administrator of Expenses: every Expenses permission', 'rt-subscribed-app-expenses', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-expenses-finance',  'system-tenant-id', 'Expenses Finance Manager',  'Runs expenses: sees every claim, approves, pays back, sets policies and exports', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-expenses-approver', 'system-tenant-id', 'Expense Approver', 'Claims their own expenses and approves or sends back the claims sent to them', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-expenses-employee', 'system-tenant-id', 'Expenses Claimant', 'Claims their own expenses and follows them to payment', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-expenses-viewer',   'system-tenant-id', 'Expenses Viewer',  'Reads every claim, payout and report; changes nothing', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name        = EXCLUDED.role_name,
                               description      = EXCLUDED.description,
                               resource_type_id = EXCLUDED.resource_type_id,
                               is_system        = EXCLUDED.is_system,
                               is_active        = EXCLUDED.is_active;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-expenses-finance' AS role_id, p2.resource_key, p2.action
      FROM core_platform.cp_permissions p2 WHERE p2.app_prefix = 'expenses'
    UNION ALL
    SELECT 'role-expenses-approver', k, a FROM (VALUES
        ('claims', 'create'), ('claims', 'approve'), ('claims', 'reject'), ('settings', 'get')) AS c(k, a)
    UNION ALL
    SELECT 'role-expenses-employee', k, a FROM (VALUES
        ('claims', 'create'), ('settings', 'get')) AS e(k, a)
    UNION ALL
    SELECT 'role-expenses-viewer', k, a FROM (VALUES
        ('claims', 'get'), ('payouts', 'get'), ('settings', 'get'), ('reports', 'get')) AS v(k, a)
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'expenses' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- The core-platform navigation block every app role seeds for itself.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', r.id, p.id
  FROM core_platform.cp_roles r
  JOIN core_platform.cp_permissions p
    ON p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations',
                'permission-user-get-locations')
 WHERE r.id IN ('role-subscribed-app-expenses-admin', 'role-expenses-finance', 'role-expenses-approver',
                'role-expenses-employee', 'role-expenses-viewer')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ================================================================ label and routes
INSERT INTO control_plane.ctl_reserved_labels (label, reason, created_by)
SELECT v.label, v.reason, 'migration:20261019-26'
  FROM (VALUES ('expenses', 'a product: expenses.dev.trovesuite.com, claims and payouts')) AS v(label, reason)
 WHERE NOT EXISTS (SELECT 1 FROM control_plane.ctl_reserved_labels r WHERE r.label = v.label);

INSERT INTO control_plane.ctl_tenant_routes (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT h.host, NULL, 'POOLED', h.cell, 'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261019-26'
  FROM (VALUES ('expenses.dev.trovesuite.com', 'uksouth-dev')) AS h(host, cell)
 WHERE EXISTS (SELECT 1 FROM control_plane.ctl_cells c WHERE c.cell_key = h.cell)
ON CONFLICT (host) DO NOTHING;

-- ===================================================================== invariants
DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions
     WHERE id LIKE 'permission-expenses-%' AND (app_prefix <> 'expenses' OR resource_key IS NULL OR action IS NULL);
    IF n > 0 THEN
        RAISE EXCEPTION '% Expenses permission(s) have no pair; nothing would match them', n;
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-expenses-viewer' AND p.app_prefix = 'expenses' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-expenses-viewer holds % Expenses permission(s) that change data', n;
    END IF;
    -- Only the finance manager pays, and an employee neither approves nor sees others' claims.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id IN ('role-expenses-employee', 'role-expenses-approver', 'role-expenses-viewer')
                  AND p.app_prefix = 'expenses' AND p.resource_key = 'payouts' AND p.action = 'pay') THEN
        RAISE EXCEPTION 'a role other than Expenses Finance Manager may pay claims back';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-expenses-employee' AND p.app_prefix = 'expenses'
                  AND (p.action IN ('approve', 'reject', 'manage', 'pay') OR (p.resource_key = 'claims' AND p.action = 'get'))) THEN
        RAISE EXCEPTION 'role-expenses-employee holds more than claiming their own';
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_permissions p
     WHERE p.app_prefix = 'expenses' AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                        WHERE rp.role_id = 'role-expenses-finance' AND rp.permission_id = p.id);
    IF n > 0 THEN
        RAISE EXCEPTION 'role-expenses-finance lacks % Expenses permission(s)', n;
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-expenses-admin' AND permission_id LIKE 'permission-expenses-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-expenses-admin holds Expenses permission rows';
    END IF;
    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host = 'expenses.dev.trovesuite.com' AND tenant_id IS NOT NULL) THEN
        RAISE EXCEPTION 'the Expenses address has been given to a tenant';
    END IF;
END $$;

COMMIT;
