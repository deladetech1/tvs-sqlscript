-- SCM joins the platform: supply chain management -- items, suppliers, purchasing and
-- receiving, a full inventory ledger, sales orders, shipments and an exceptions control tower.
--
-- Served by the shared apps backend (deladetech1/tvs-shared-apps-bk, module "scm") like the
-- CRM, Projects, Invoicing, Expenses and HMS; frontend tvs-scm-ft. Its cp_apps row, tier
-- prices and the role-cp-admin exclusion live in the CorePlatform seed (04_others.sql), which
-- owns every app row; its billing unit (BUSINESS) is pinned in 20261022-70. This file holds
-- the rest:
--
--   * the scm schema and its audit trail (scm_audit_logs); master data, procurement, the
--     ledger, orders and the control tower come in the files after this one (20261026-02..06);
--   * its cp_app_schemas row, so activity-log retention finds scm.scm_audit_logs;
--   * the verbs it adds (export, confirm, allocate), its resource types, permissions
--     (scm|<resource>|<verb>||any) and roles: SCM Admin is allowed by BEING the role and holds
--     no SCM rows; the seven job roles carry explicit grants;
--   * which features each subscription tier includes (cp_app_feature_catalog);
--   * the reserved label "scm" and the route rows for the website AND the API
--     (api.scm.dev: without it a call with no browser Origin -- curl, webhooks -- is 404).
--
-- Suppliers and customers are core_platform.cp_parties and products are
-- core_platform.cp_products; SCM keeps only its own fields beside them (20261026-02).
-- Nothing here asserts on rows a module seed creates. Idempotent; safe to re-run.

BEGIN;

CREATE SCHEMA IF NOT EXISTS scm;

INSERT INTO core_platform.cp_app_schemas (app_id, schema_name, description)
VALUES ('app-scm', 'scm', 'SCM audit logs')
ON CONFLICT (app_id) DO UPDATE SET schema_name = EXCLUDED.schema_name,
                                   description = EXCLUDED.description;

CREATE TABLE IF NOT EXISTS scm.scm_audit_logs (
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
CREATE INDEX IF NOT EXISTS scm_audit_entity_idx
    ON scm.scm_audit_logs (tenant_id, entity_type, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS scm_audit_business_idx
    ON scm.scm_audit_logs (bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS scm_audit_actor_idx
    ON scm.scm_audit_logs (bus_id, actor_id, cdatetime DESC);

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-subscribed-app-scm', 'SCM APP', 'SCM Subscribed APP', NULL)
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-scm-items',           'SCM Items',           'Items: the products SCM stocks and their reorder settings',    'rt-subscribed-app-scm'),
('rt-scm-warehouses',      'SCM Warehouses',      'Warehouses and bins',                                           'rt-subscribed-app-scm'),
('rt-scm-suppliers',       'SCM Suppliers',       'Suppliers, their profiles and price lists',                     'rt-subscribed-app-scm'),
('rt-scm-requisitions',    'SCM Requisitions',    'Purchase requisitions and their approval',                      'rt-subscribed-app-scm'),
('rt-scm-purchase_orders', 'SCM Purchase Orders', 'Purchase orders: approval, sending and supplier confirmation',   'rt-subscribed-app-scm'),
('rt-scm-receipts',        'SCM Receipts',        'Goods received against purchase orders',                        'rt-subscribed-app-scm'),
('rt-scm-inventory',       'SCM Inventory',       'The stock ledger, balances, adjustments and transfers',         'rt-subscribed-app-scm'),
('rt-scm-sales_orders',    'SCM Sales Orders',    'Sales orders and stock allocation',                             'rt-subscribed-app-scm'),
('rt-scm-shipments',       'SCM Shipments',       'Shipments against sales orders',                                'rt-subscribed-app-scm'),
('rt-scm-exceptions',      'SCM Exceptions',      'The control tower: stockouts, overdue orders, expiring lots',   'rt-subscribed-app-scm'),
('rt-scm-settings',        'SCM Settings',        'Currency, approval policy, numbering and stock rules',          'rt-subscribed-app-scm'),
('rt-scm-logs',            'SCM Logs',            'The audit trail of SCM',                                        'rt-subscribed-app-scm')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

-- The verbs SCM needs that 00_actions.sql does not seed. "export" came with the CRM
-- (20261015-02) and HMS; asserted here too so this file stands on its own. Every verb is one
-- lowercase word: the metadata UPDATE below reads it off the id with [a-z]+.
INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('export',   'Export',   true,  false),
('confirm',  'Confirm',  false, false),
('allocate', 'Allocate', false, false)
ON CONFLICT (action) DO NOTHING;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('items',           'rt-scm-items',           'get',      'View items and their stock settings'),
    ('items',           'rt-scm-items',           'manage',   'Add items, change their stock settings and archive them'),
    ('warehouses',      'rt-scm-warehouses',      'get',      'View warehouses and bins'),
    ('warehouses',      'rt-scm-warehouses',      'manage',   'Set up warehouses and bins'),
    ('suppliers',       'rt-scm-suppliers',       'get',      'View suppliers and their price lists'),
    ('suppliers',       'rt-scm-suppliers',       'manage',   'Add suppliers and keep their profiles and price lists'),
    ('requisitions',    'rt-scm-requisitions',    'get',      'View purchase requisitions'),
    ('requisitions',    'rt-scm-requisitions',    'create',   'Raise purchase requisitions'),
    ('requisitions',    'rt-scm-requisitions',    'update',   'Change and submit purchase requisitions'),
    ('requisitions',    'rt-scm-requisitions',    'approve',  'Approve or reject purchase requisitions'),
    ('requisitions',    'rt-scm-requisitions',    'cancel',   'Cancel purchase requisitions'),
    ('purchase_orders', 'rt-scm-purchase_orders', 'get',      'View purchase orders'),
    ('purchase_orders', 'rt-scm-purchase_orders', 'create',   'Raise purchase orders'),
    ('purchase_orders', 'rt-scm-purchase_orders', 'update',   'Change, submit and send purchase orders'),
    ('purchase_orders', 'rt-scm-purchase_orders', 'approve',  'Approve purchase orders'),
    ('purchase_orders', 'rt-scm-purchase_orders', 'confirm',  'Record the supplier''s confirmation of a purchase order'),
    ('purchase_orders', 'rt-scm-purchase_orders', 'cancel',   'Cancel purchase orders'),
    ('receipts',        'rt-scm-receipts',        'get',      'View goods receipts'),
    ('receipts',        'rt-scm-receipts',        'post',     'Receive goods against a purchase order into stock'),
    ('inventory',       'rt-scm-inventory',       'get',      'View stock balances, the ledger, lots, adjustments and transfers'),
    ('inventory',       'rt-scm-inventory',       'adjust',   'Post stock adjustments'),
    ('inventory',       'rt-scm-inventory',       'transfer', 'Move stock between warehouses'),
    ('sales_orders',    'rt-scm-sales_orders',    'get',      'View sales orders'),
    ('sales_orders',    'rt-scm-sales_orders',    'create',   'Take sales orders'),
    ('sales_orders',    'rt-scm-sales_orders',    'update',   'Change and confirm sales orders'),
    ('sales_orders',    'rt-scm-sales_orders',    'allocate', 'Reserve stock for sales orders'),
    ('sales_orders',    'rt-scm-sales_orders',    'cancel',   'Cancel sales orders'),
    ('shipments',       'rt-scm-shipments',       'get',      'View shipments'),
    ('shipments',       'rt-scm-shipments',       'create',   'Prepare shipments for sales orders'),
    ('shipments',       'rt-scm-shipments',       'update',   'Change and pack shipments'),
    ('shipments',       'rt-scm-shipments',       'complete', 'Ship: issue the stock and complete the shipment'),
    ('shipments',       'rt-scm-shipments',       'cancel',   'Cancel shipments'),
    ('exceptions',      'rt-scm-exceptions',      'get',      'View the control tower'),
    ('exceptions',      'rt-scm-exceptions',      'assign',   'Acknowledge exceptions and assign them to people'),
    ('exceptions',      'rt-scm-exceptions',      'resolve',  'Resolve or dismiss exceptions'),
    ('settings',        'rt-scm-settings',        'get',      'View SCM settings'),
    ('settings',        'rt-scm-settings',        'manage',   'Set the currency, approval policy, numbering and stock rules'),
    ('logs',            'rt-scm-logs',            'get',      'View the SCM audit trail'),
    ('logs',            'rt-scm-logs',            'export',   'Export the SCM audit trail')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-scm-' || spec.resource_key || '-' || spec.action,
       'SCM ' || initcap(replace(spec.resource_key, '_', ' ')) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

-- The pair the code checks: scm|<resource>|<verb>||any. Resource keys may hold underscores
-- (purchase_orders); the verb is the last single word after the last hyphen.
UPDATE core_platform.cp_permissions p
   SET app_prefix = 'scm',
       resource_key = substring(p.id FROM '^permission-scm-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-scm-%'
   AND (p.app_prefix IS DISTINCT FROM 'scm' OR p.resource_key IS NULL OR p.action IS NULL);

-- ========================================================================== roles
-- role_name is unique per tenant across every app, so every name starts with "SCM".
INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-subscribed-app-scm-admin', 'system-tenant-id', 'SCM Admin', 'Administrator of SCM: every SCM permission', 'rt-subscribed-app-scm', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-scm-manager',   'system-tenant-id', 'SCM Supply Chain Manager', 'Runs the supply chain: every SCM permission, settings and the audit trail included', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-scm-buyer',     'system-tenant-id', 'SCM Buyer',                'Keeps suppliers, raises requisitions and purchase orders and records supplier confirmations', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-scm-approver',  'system-tenant-id', 'SCM Procurement Approver', 'Approves or rejects requisitions and purchase orders', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-scm-warehouse', 'system-tenant-id', 'SCM Warehouse Operator',   'Receives goods, adjusts and moves stock, packs and ships', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-scm-orderdesk', 'system-tenant-id', 'SCM Order Desk',           'Takes sales orders and reserves stock for them', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-scm-planner',   'system-tenant-id', 'SCM Planner',              'Reads everything, works the control tower and exports the audit trail', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-scm-viewer',    'system-tenant-id', 'SCM Viewer',               'Reads everything in SCM; changes nothing', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name        = EXCLUDED.role_name,
                               description      = EXCLUDED.description,
                               resource_type_id = EXCLUDED.resource_type_id,
                               is_system        = EXCLUDED.is_system,
                               is_active        = EXCLUDED.is_active;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-scm-manager' AS role_id, p2.resource_key, p2.action
      FROM core_platform.cp_permissions p2 WHERE p2.app_prefix = 'scm'
    UNION ALL
    SELECT 'role-scm-buyer', k, a FROM (VALUES
        ('items', 'get'), ('warehouses', 'get'), ('suppliers', 'get'), ('suppliers', 'manage'),
        ('requisitions', 'get'), ('requisitions', 'create'), ('requisitions', 'update'), ('requisitions', 'cancel'),
        ('purchase_orders', 'get'), ('purchase_orders', 'create'), ('purchase_orders', 'update'),
        ('purchase_orders', 'confirm'), ('purchase_orders', 'cancel'),
        ('receipts', 'get'), ('inventory', 'get'), ('sales_orders', 'get'),
        ('exceptions', 'get'), ('exceptions', 'assign'), ('exceptions', 'resolve'),
        ('settings', 'get'), ('logs', 'get')) AS b(k, a)
    UNION ALL
    SELECT 'role-scm-approver', k, a FROM (VALUES
        ('items', 'get'), ('suppliers', 'get'), ('requisitions', 'get'), ('requisitions', 'approve'),
        ('purchase_orders', 'get'), ('purchase_orders', 'approve'), ('receipts', 'get'), ('inventory', 'get'),
        ('exceptions', 'get'), ('settings', 'get')) AS ap(k, a)
    UNION ALL
    SELECT 'role-scm-warehouse', k, a FROM (VALUES
        ('items', 'get'), ('warehouses', 'get'), ('purchase_orders', 'get'), ('receipts', 'get'), ('receipts', 'post'),
        ('inventory', 'get'), ('inventory', 'adjust'), ('inventory', 'transfer'), ('sales_orders', 'get'),
        ('shipments', 'get'), ('shipments', 'create'), ('shipments', 'update'), ('shipments', 'complete'),
        ('exceptions', 'get')) AS w(k, a)
    UNION ALL
    SELECT 'role-scm-orderdesk', k, a FROM (VALUES
        ('items', 'get'), ('warehouses', 'get'), ('inventory', 'get'),
        ('sales_orders', 'get'), ('sales_orders', 'create'), ('sales_orders', 'update'), ('sales_orders', 'allocate'),
        ('sales_orders', 'cancel'), ('shipments', 'get'), ('exceptions', 'get')) AS o(k, a)
    UNION ALL
    -- The planner reads everything, works the control tower and exports the trail.
    SELECT 'role-scm-planner', p4.resource_key, p4.action
      FROM core_platform.cp_permissions p4 WHERE p4.app_prefix = 'scm' AND p4.action = 'get'
    UNION ALL
    SELECT 'role-scm-planner', k, a FROM (VALUES
        ('exceptions', 'assign'), ('exceptions', 'resolve'), ('logs', 'export')) AS pl(k, a)
    UNION ALL
    SELECT 'role-scm-viewer', p3.resource_key, p3.action
      FROM core_platform.cp_permissions p3
      JOIN core_platform.cp_actions a ON a.action = p3.action AND a.is_read_only AND p3.action <> 'export'
     WHERE p3.app_prefix = 'scm'
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'scm' AND p.resource_key = spec.resource_key AND p.action = spec.action
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
 WHERE r.id IN ('role-subscribed-app-scm-admin', 'role-scm-manager', 'role-scm-buyer', 'role-scm-approver',
                'role-scm-warehouse', 'role-scm-orderdesk', 'role-scm-planner', 'role-scm-viewer')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ========================================================== features per tier
-- Tiers are cumulative (20260821-02): a business on rank R has every feature whose
-- min_tier_rank <= R. 1=BASIC 2=ADVANCE 3=PREMIUM; nothing is gated at 4, ENTERPRISE means
-- self-hosted, not a bigger plan. feature_key is the contract between this file, the SCM API
-- (internal/apps/scm, entitle.NewGate("app-scm")) and the UI (usePlan).
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
-- ---- BASIC: buy, stock and sell ---------------------------------------------------
('scm.dashboard',            'app-scm', 'Dashboard',              1, 'Open exceptions, orders awaiting approval, overdue and due this week, stock below reorder, inventory value'),
('scm.items',                'app-scm', 'Items',                  1, 'The products SCM stocks, their units, reorder points and standard costs'),
('scm.warehouses',           'app-scm', 'Warehouses',             1, 'Warehouses and their addresses'),
('scm.suppliers',            'app-scm', 'Suppliers',              1, 'Suppliers, lead times, terms and ratings'),
('scm.requisitions',         'app-scm', 'Requisitions',           1, 'Purchase requisitions with a single approval step'),
('scm.purchase_orders',      'app-scm', 'Purchase Orders',        1, 'Purchase orders: approval, sending and supplier confirmation'),
('scm.receiving',            'app-scm', 'Receiving',              1, 'Goods receipts against purchase orders'),
('scm.inventory',            'app-scm', 'Inventory',              1, 'Stock balances, the movement ledger and adjustments'),
('scm.sales_orders',         'app-scm', 'Sales Orders',           1, 'Sales orders and stock allocation'),
('scm.shipments',            'app-scm', 'Shipments',              1, 'Packing, shipping and delivery against sales orders'),
('scm.settings',             'app-scm', 'Settings',               1, 'Currency, approval policy, numbering and stock rules'),
-- ---- ADVANCE: run a real warehouse ------------------------------------------------
('scm.exceptions',           'app-scm', 'Control Tower',          2, 'Stockout risk, overdue orders, unallocated demand and expiring lots, explained and assigned'),
('scm.bins',                 'app-scm', 'Bins',                   2, 'Directed storage locations inside a warehouse'),
('scm.lots',                 'app-scm', 'Lots & Expiry',          2, 'Lot numbers and expiry dates on received stock'),
('scm.transfers',            'app-scm', 'Transfers',              2, 'Stock moved between warehouses, in transit until received'),
('scm.report_export',        'app-scm', 'Report Export',          2, 'CSV downloads of balances, movements and orders'),
-- ---- PREMIUM: traceability and negotiated prices ----------------------------------
('scm.audit_logs',           'app-scm', 'Audit Trail',            3, 'Who changed what, and when'),
('scm.serials',              'app-scm', 'Serial Tracking',        3, 'Serial numbers on individual units (tables ready; screens later)'),
('scm.supplier_pricelists',  'app-scm', 'Supplier Price Lists',   3, 'Negotiated prices, lead times and minimums per supplier and item')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

-- ================================================================ label and routes
INSERT INTO control_plane.ctl_reserved_labels (label, reason, created_by)
SELECT v.label, v.reason, 'migration:20261026-01'
  FROM (VALUES ('scm', 'a product: scm.dev.trovesuite.com, supply chain management')) AS v(label, reason)
 WHERE NOT EXISTS (SELECT 1 FROM control_plane.ctl_reserved_labels r WHERE r.label = v.label);

-- Both the website and the API host, dev only (the WHERE EXISTS on the dev cell keeps these
-- rows out of production; the prod hosts come in a later file with cell uksouth-prod).
INSERT INTO control_plane.ctl_tenant_routes (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT h.host, NULL, 'POOLED', h.cell, 'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261026-01'
  FROM (VALUES ('scm.dev.trovesuite.com',     'uksouth-dev'),
               ('api.scm.dev.trovesuite.com', 'uksouth-dev')) AS h(host, cell)
 WHERE EXISTS (SELECT 1 FROM control_plane.ctl_cells c WHERE c.cell_key = h.cell)
ON CONFLICT (host) DO NOTHING;

-- ===================================================================== invariants
-- Properties, never counts: a later file may add permissions, roles or features.
DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions
     WHERE id LIKE 'permission-scm-%'
       AND (app_prefix IS DISTINCT FROM 'scm' OR resource_key IS NULL OR action IS NULL
            OR coalesce(target, '') <> '' OR scope IS DISTINCT FROM 'any');
    IF n > 0 THEN
        RAISE EXCEPTION '% SCM permission(s) have no pair; nothing would match them', n;
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-scm-viewer' AND p.app_prefix = 'scm' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-scm-viewer holds % SCM permission(s) that change data', n;
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_permissions p
     WHERE p.app_prefix = 'scm' AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                        WHERE rp.role_id = 'role-scm-manager' AND rp.permission_id = p.id);
    IF n > 0 THEN
        RAISE EXCEPTION 'role-scm-manager lacks % SCM permission(s)', n;
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-scm-admin' AND permission_id LIKE 'permission-scm-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-scm-admin holds SCM permission rows';
    END IF;
    -- Spending is approved only by the approver and the manager; settings are the manager's.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id NOT IN ('role-scm-manager', 'role-scm-approver')
                  AND p.app_prefix = 'scm' AND p.action = 'approve') THEN
        RAISE EXCEPTION 'a role other than SCM Supply Chain Manager or Procurement Approver may approve';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id <> 'role-scm-manager'
                  AND p.app_prefix = 'scm' AND p.resource_key = 'settings' AND p.action = 'manage') THEN
        RAISE EXCEPTION 'a role other than SCM Supply Chain Manager may change SCM settings';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_roles
                WHERE (id LIKE 'role-scm-%' OR id = 'role-subscribed-app-scm-admin') AND role_name NOT LIKE 'SCM %') THEN
        RAISE EXCEPTION 'an SCM role is not named "SCM ..."; role names are unique across apps';
    END IF;
    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host IN ('scm.dev.trovesuite.com', 'api.scm.dev.trovesuite.com')
                  AND (tenant_id IS NOT NULL OR silo_key IS NOT NULL OR is_wildcard)) THEN
        RAISE EXCEPTION 'an SCM address has been given to a tenant, a silo or a wildcard';
    END IF;
    RAISE NOTICE 'scm: % permission(s), % role(s), % feature(s)',
        (SELECT count(*) FROM core_platform.cp_permissions WHERE app_prefix = 'scm'),
        (SELECT count(*) FROM core_platform.cp_roles WHERE id LIKE 'role-scm-%' OR id = 'role-subscribed-app-scm-admin'),
        (SELECT count(*) FROM core_platform.cp_app_feature_catalog WHERE app_id = 'app-scm');
END $$;

COMMIT;
