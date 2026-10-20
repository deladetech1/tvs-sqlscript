-- Invoicing joins the platform: invoices, quotes and payments for any business, in any country.
--
-- Served by the shared apps backend (deladetech1/tvs-shared-apps-bk, module "invoicing")
-- like the CRM and Projects; frontend tvs-invoicing-ft. Its cp_apps row and tier prices live
-- in the CorePlatform seed (04_others.sql), which owns every app row. This file holds the rest:
--
--   * the invoicing schema and its audit trail (inv_*); every row carries tenant_id, org_id
--     and bus_id. The invoices, customers, items and the tax engine come in later files;
--   * its cp_app_schemas row, so activity-log retention finds invoicing.inv_audit_logs;
--   * resource types, permissions (invoicing|<resource>|<action>||any) and the roles:
--     Invoicing Admin is allowed by BEING the role (tvs-package-go appAdminRoles) and holds
--     no Invoicing rows; Billing Manager, Billing Clerk, Accountant and Viewer carry grants;
--   * the reserved label "invoicing" and the frontend's route row.
--
-- Nothing here asserts on rows a module seed creates: a shared file runs on deploys that
-- did not run the CorePlatform seed. Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE SCHEMA IF NOT EXISTS invoicing;

INSERT INTO core_platform.cp_app_schemas (app_id, schema_name, description)
VALUES ('app-invoicing', 'invoicing', 'Invoicing audit logs')
ON CONFLICT (app_id) DO UPDATE SET schema_name = EXCLUDED.schema_name,
                                   description = EXCLUDED.description;

-- The audit trail: named *_audit_logs with tenant_id and cdatetime, so retention finds it.
CREATE TABLE IF NOT EXISTS invoicing.inv_audit_logs (
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
CREATE INDEX IF NOT EXISTS inv_audit_entity_idx
    ON invoicing.inv_audit_logs (tenant_id, entity_type, entity_id, cdatetime DESC);

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-subscribed-app-invoicing', 'INVOICING APP', 'Invoicing Subscribed APP', NULL)
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-invoicing-invoices',  'Invoicing Invoices',  'Invoices and credit notes',                       'rt-subscribed-app-invoicing'),
('rt-invoicing-quotes',    'Invoicing Quotes',    'Quotes and estimates',                            'rt-subscribed-app-invoicing'),
('rt-invoicing-payments',  'Invoicing Payments',  'Payments received, receipts and refunds',         'rt-subscribed-app-invoicing'),
('rt-invoicing-customers', 'Invoicing Customers', 'The customers invoices go to',                    'rt-subscribed-app-invoicing'),
('rt-invoicing-items',     'Invoicing Items',     'Products and services put on invoices',           'rt-subscribed-app-invoicing'),
('rt-invoicing-taxes',     'Invoicing Taxes',     'Tax rates, groups, rules and exemptions',         'rt-subscribed-app-invoicing'),
('rt-invoicing-settings',  'Invoicing Settings',  'Branding, numbering, templates and payment ways', 'rt-subscribed-app-invoicing'),
('rt-invoicing-reports',   'Invoicing Reports',   'What is owed, revenue and tax reports',           'rt-subscribed-app-invoicing'),
('rt-invoicing-logs',      'Invoicing Logs',      'The audit trail of Invoicing',                    'rt-subscribed-app-invoicing')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('invoices', 'rt-invoicing-invoices', 'get',    'View invoices'),
    ('invoices', 'rt-invoicing-invoices', 'create', 'Create invoices'),
    ('invoices', 'rt-invoicing-invoices', 'update', 'Edit invoices'),
    ('invoices', 'rt-invoicing-invoices', 'delete', 'Delete draft invoices'),
    ('invoices', 'rt-invoicing-invoices', 'send',   'Send invoices to customers'),
    ('invoices', 'rt-invoicing-invoices', 'void',   'Void issued invoices'),
    ('invoices', 'rt-invoicing-invoices', 'export', 'Export invoices'),
    ('quotes', 'rt-invoicing-quotes', 'get',    'View quotes'),
    ('quotes', 'rt-invoicing-quotes', 'create', 'Create quotes'),
    ('quotes', 'rt-invoicing-quotes', 'update', 'Edit quotes'),
    ('quotes', 'rt-invoicing-quotes', 'delete', 'Delete quotes'),
    ('quotes', 'rt-invoicing-quotes', 'send',   'Send quotes to customers'),
    ('payments', 'rt-invoicing-payments', 'get',    'View payments'),
    ('payments', 'rt-invoicing-payments', 'create', 'Record payments'),
    ('payments', 'rt-invoicing-payments', 'delete', 'Delete recorded payments'),
    ('payments', 'rt-invoicing-payments', 'refund', 'Refund payments'),
    ('customers', 'rt-invoicing-customers', 'get',    'View customers'),
    ('customers', 'rt-invoicing-customers', 'create', 'Add customers'),
    ('customers', 'rt-invoicing-customers', 'update', 'Edit customers'),
    ('customers', 'rt-invoicing-customers', 'delete', 'Delete customers'),
    ('customers', 'rt-invoicing-customers', 'import', 'Import customers'),
    ('customers', 'rt-invoicing-customers', 'export', 'Export customers'),
    ('items', 'rt-invoicing-items', 'get',    'View products and services'),
    ('items', 'rt-invoicing-items', 'create', 'Add products and services'),
    ('items', 'rt-invoicing-items', 'update', 'Edit products and services'),
    ('items', 'rt-invoicing-items', 'delete', 'Delete products and services'),
    ('taxes', 'rt-invoicing-taxes', 'get',    'View the tax setup'),
    ('taxes', 'rt-invoicing-taxes', 'manage', 'Set up taxes: rates, groups, rules and exemptions'),
    ('settings', 'rt-invoicing-settings', 'get',    'View invoicing settings'),
    ('settings', 'rt-invoicing-settings', 'manage', 'Change branding, numbering, templates and payment ways'),
    ('reports', 'rt-invoicing-reports', 'get',    'View reports'),
    ('reports', 'rt-invoicing-reports', 'export', 'Export reports'),
    ('logs', 'rt-invoicing-logs', 'get', 'View the Invoicing audit trail')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-invoicing-' || spec.resource_key || '-' || spec.action,
       'Invoicing ' || initcap(replace(spec.resource_key, '-', ' ')) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

-- The pair every package checks: invoicing|<resource>|<action>||any.
UPDATE core_platform.cp_permissions p
   SET app_prefix = 'invoicing',
       resource_key = substring(p.id FROM '^permission-invoicing-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-invoicing-%'
   AND (p.app_prefix IS DISTINCT FROM 'invoicing' OR p.action IS NULL);

-- ========================================================================== roles
INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-subscribed-app-invoicing-admin', 'system-tenant-id', 'Invoicing Admin', 'Administrator of Invoicing: every Invoicing permission', 'rt-subscribed-app-invoicing', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-invoicing-manager',    'system-tenant-id', 'Billing Manager', 'Runs billing: invoices, quotes, payments, customers, items, taxes and settings, deleting and voiding included', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-invoicing-clerk',      'system-tenant-id', 'Billing Clerk',   'Makes and sends invoices and quotes, records payments, keeps customers and items; deletes and voids nothing', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-invoicing-accountant', 'system-tenant-id', 'Accountant',      'Reads all billing, records and refunds payments, sets up taxes and exports reports', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-invoicing-viewer',     'system-tenant-id', 'Billing Viewer',  'Reads invoices, quotes, payments, customers and reports; changes nothing', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name        = EXCLUDED.role_name,
                               description      = EXCLUDED.description,
                               resource_type_id = EXCLUDED.resource_type_id,
                               is_system        = EXCLUDED.is_system,
                               is_active        = EXCLUDED.is_active;

-- The manager holds every Invoicing permission; the others a chosen set.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-invoicing-manager' AS role_id, p2.resource_key, p2.action
      FROM core_platform.cp_permissions p2 WHERE p2.app_prefix = 'invoicing'
    UNION ALL
    SELECT 'role-invoicing-clerk', k, a FROM (VALUES
        ('invoices', 'get'), ('invoices', 'create'), ('invoices', 'update'), ('invoices', 'send'),
        ('quotes', 'get'), ('quotes', 'create'), ('quotes', 'update'), ('quotes', 'send'),
        ('payments', 'get'), ('payments', 'create'),
        ('customers', 'get'), ('customers', 'create'), ('customers', 'update'),
        ('items', 'get'), ('items', 'create'), ('items', 'update'),
        ('taxes', 'get'), ('settings', 'get')) AS c(k, a)
    UNION ALL
    SELECT 'role-invoicing-accountant', k, a FROM (VALUES
        ('invoices', 'get'), ('invoices', 'export'), ('quotes', 'get'),
        ('payments', 'get'), ('payments', 'create'), ('payments', 'refund'),
        ('customers', 'get'), ('customers', 'export'), ('items', 'get'),
        ('taxes', 'get'), ('taxes', 'manage'), ('settings', 'get'),
        ('reports', 'get'), ('reports', 'export'), ('logs', 'get')) AS ac(k, a)
    UNION ALL
    SELECT 'role-invoicing-viewer', k, a FROM (VALUES
        ('invoices', 'get'), ('quotes', 'get'), ('payments', 'get'), ('customers', 'get'),
        ('items', 'get'), ('taxes', 'get'), ('reports', 'get')) AS v(k, a)
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'invoicing' AND p.resource_key = spec.resource_key AND p.action = spec.action
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
 WHERE r.id IN ('role-subscribed-app-invoicing-admin', 'role-invoicing-manager', 'role-invoicing-clerk',
                'role-invoicing-accountant', 'role-invoicing-viewer')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ================================================================ label and routes
INSERT INTO control_plane.ctl_reserved_labels (label, reason, created_by)
SELECT v.label, v.reason, 'migration:20261019-01'
  FROM (VALUES ('invoicing', 'a product: invoicing.dev.trovesuite.com, invoices and payments')) AS v(label, reason)
 WHERE NOT EXISTS (SELECT 1 FROM control_plane.ctl_reserved_labels r WHERE r.label = v.label);

-- The container app's own address is already claimed by the CRM's migration (one container).
INSERT INTO control_plane.ctl_tenant_routes (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT h.host, NULL, 'POOLED', h.cell, 'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261019-01'
  FROM (VALUES ('invoicing.dev.trovesuite.com', 'uksouth-dev')) AS h(host, cell)
 WHERE EXISTS (SELECT 1 FROM control_plane.ctl_cells c WHERE c.cell_key = h.cell)
ON CONFLICT (host) DO NOTHING;

-- ===================================================================== invariants
DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions
     WHERE id LIKE 'permission-invoicing-%' AND (app_prefix <> 'invoicing' OR resource_key IS NULL OR action IS NULL);
    IF n > 0 THEN
        RAISE EXCEPTION '% Invoicing permission(s) have no pair; nothing would match them', n;
    END IF;
    -- A viewer changes nothing.
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-invoicing-viewer' AND p.app_prefix = 'invoicing' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-invoicing-viewer holds % Invoicing permission(s) that change data', n;
    END IF;
    -- A clerk neither deletes, voids nor refunds, and leaves taxes and settings alone.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-invoicing-clerk' AND p.app_prefix = 'invoicing'
                  AND (p.action IN ('delete', 'void', 'refund', 'manage'))) THEN
        RAISE EXCEPTION 'role-invoicing-clerk holds a delete, void, refund or manage permission';
    END IF;
    -- The manager lacks nothing.
    SELECT count(*) INTO n FROM core_platform.cp_permissions p
     WHERE p.app_prefix = 'invoicing' AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                        WHERE rp.role_id = 'role-invoicing-manager' AND rp.permission_id = p.id);
    IF n > 0 THEN
        RAISE EXCEPTION 'role-invoicing-manager lacks % Invoicing permission(s)', n;
    END IF;
    -- Invoicing Admin is allowed by being the role and holds no Invoicing rows.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-invoicing-admin' AND permission_id LIKE 'permission-invoicing-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-invoicing-admin holds Invoicing permission rows';
    END IF;
    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host = 'invoicing.dev.trovesuite.com' AND tenant_id IS NOT NULL) THEN
        RAISE EXCEPTION 'the Invoicing address has been given to a tenant';
    END IF;
END $$;

COMMIT;
