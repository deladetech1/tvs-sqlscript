-- Manufacturing joins the platform: plants, engineering (items, BOMs, routings, work instructions),
-- production orders and the shop floor, then planning, quality, traceability, maintenance and OEE in
-- later releases.
--
-- Served by the shared apps backend (deladetech1/tvs-shared-apps-bk, module "mfg") like the CRM,
-- Projects, Invoicing, Expenses, HMS and SCM; frontend tvs-mfg-ft. Manufacturing posts stock into
-- SCM's ledger (internal/platform/stock), so its material features need an SCM subscription too.
-- Its cp_apps row, tier prices and the role-cp-admin exclusion live in the CorePlatform seed
-- (04_others.sql), which owns every app row. This file holds the rest:
--
--   * the mfg schema and its audit trail (mfg_audit_logs, append-only); the feature tables come in
--     the files after this one;
--   * its cp_app_schemas row, so activity-log retention finds mfg.mfg_audit_logs;
--   * resource types, permissions (mfg|<resource>|<action>||any) for Release 1 and the roles:
--     Manufacturing Admin is allowed by BEING the role and holds no mfg rows; the job roles carry
--     grants. Later releases add their resources and grants in their own files;
--   * which features each subscription tier includes (cp_app_feature_catalog);
--   * the reserved label "mfg" and the route rows for the website and the API.
--
-- Design: tvs-shared-apps-bk docs/mfg/ (05-api-contracts.md §2, 07-security-and-tenancy.md §4).
-- Nothing here asserts on rows a module seed creates. Idempotent; safe to re-run.

BEGIN;

CREATE SCHEMA IF NOT EXISTS mfg;

INSERT INTO core_platform.cp_app_schemas (app_id, schema_name, description)
VALUES ('app-mfg', 'mfg', 'Manufacturing audit logs')
ON CONFLICT (app_id) DO UPDATE SET schema_name = EXCLUDED.schema_name,
                                   description = EXCLUDED.description;

-- Who changed what, when, why, from where. Never updated or deleted, except by activity-log
-- retention (which deletes old rows by tenant_id and cdatetime, as a superuser-owned job).
CREATE TABLE IF NOT EXISTS mfg.mfg_audit_logs (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    org_id       text,
    bus_id       text,
    entity_type  text NOT NULL,
    entity_id    text NOT NULL,
    action       text NOT NULL,
    changes      jsonb NOT NULL DEFAULT '{}',
    reason       text,
    source       text NOT NULL DEFAULT 'ui',
    actor_id     text,
    device_id    text,
    request_id   text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS mfg_audit_entity_idx
    ON mfg.mfg_audit_logs (tenant_id, entity_type, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS mfg_audit_business_idx
    ON mfg.mfg_audit_logs (bus_id, cdatetime DESC);

CREATE OR REPLACE FUNCTION mfg.mfg_audit_logs_append_only() RETURNS trigger
LANGUAGE plpgsql AS $f$
BEGIN
    RAISE EXCEPTION 'mfg_audit_logs is append-only: % is not allowed', TG_OP
        USING ERRCODE = 'integrity_constraint_violation';
END
$f$;
DROP TRIGGER IF EXISTS mfg_audit_logs_append_only ON mfg.mfg_audit_logs;
CREATE TRIGGER mfg_audit_logs_append_only BEFORE UPDATE ON mfg.mfg_audit_logs
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_audit_logs_append_only();

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-subscribed-app-mfg', 'MANUFACTURING APP', 'Manufacturing Subscribed APP', NULL)
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-mfg-plants',            'Manufacturing Plants',            'Plants, areas, lines, work centers, resources, calendars, shifts and reason codes', 'rt-subscribed-app-mfg'),
('rt-mfg-stations',          'Manufacturing Stations',          'Shop-floor tablets enrolled as stations, operator badges and PINs',                'rt-subscribed-app-mfg'),
('rt-mfg-items',             'Manufacturing Items',             'Manufacturing settings of products, revisions and unit conversions',               'rt-subscribed-app-mfg'),
('rt-mfg-boms',              'Manufacturing BOMs',              'Bills of materials',                                                               'rt-subscribed-app-mfg'),
('rt-mfg-routings',          'Manufacturing Routings',          'Routings and their operations',                                                    'rt-subscribed-app-mfg'),
('rt-mfg-instructions',      'Manufacturing Instructions',      'Digital work instructions',                                                        'rt-subscribed-app-mfg'),
('rt-mfg-documents',         'Manufacturing Documents',         'Drawings, specifications, certificates and other files',                           'rt-subscribed-app-mfg'),
('rt-mfg-production-orders', 'Manufacturing Production Orders', 'Production orders from planning to close',                                         'rt-subscribed-app-mfg'),
('rt-mfg-materials',         'Manufacturing Materials',         'Issuing, returning and backflushing material against orders',                      'rt-subscribed-app-mfg'),
('rt-mfg-confirmations',     'Manufacturing Confirmations',     'Quantities and times reported from the shop floor',                                'rt-subscribed-app-mfg'),
('rt-mfg-downtime',          'Manufacturing Downtime',          'Machine and line stops and their reasons',                                         'rt-subscribed-app-mfg'),
('rt-mfg-settings',          'Manufacturing Settings',          'Number series, defaults and policies',                                             'rt-subscribed-app-mfg'),
('rt-mfg-logs',              'Manufacturing Logs',              'The audit trail of Manufacturing',                                                 'rt-subscribed-app-mfg')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

-- Verbs other apps may not have brought yet; asserted here so this file stands on its own.
INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('export',   'Export',   true,  false),
('release',  'Release',  false, false),
('execute',  'Execute',  false, false),
('complete', 'Complete', false, false),
('close',    'Close',    false, false),
('issue',    'Issue',    false, false),
('post',     'Post',     false, false),
('reverse',  'Reverse',  false, false)
ON CONFLICT (action) DO NOTHING;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('plants',            'rt-mfg-plants',            'get',      'View plants, lines, work centers, resources and calendars'),
    ('plants',            'rt-mfg-plants',            'manage',   'Set up plants, lines, work centers, resources, calendars and reason codes'),
    ('stations',          'rt-mfg-stations',          'get',      'View shop-floor stations'),
    ('stations',          'rt-mfg-stations',          'manage',   'Enrol and revoke shop-floor tablets and operator badges'),
    ('items',             'rt-mfg-items',             'get',      'View manufacturing item settings and revisions'),
    ('items',             'rt-mfg-items',             'manage',   'Set manufacturing item settings, revisions and unit conversions'),
    ('boms',              'rt-mfg-boms',              'get',      'View bills of materials and where-used'),
    ('boms',              'rt-mfg-boms',              'manage',   'Draft and change bills of materials'),
    ('boms',              'rt-mfg-boms',              'release',  'Release a bill of materials for production'),
    ('routings',          'rt-mfg-routings',          'get',      'View routings and operations'),
    ('routings',          'rt-mfg-routings',          'manage',   'Draft and change routings'),
    ('routings',          'rt-mfg-routings',          'release',  'Release a routing for production'),
    ('instructions',      'rt-mfg-instructions',      'get',      'View work instructions'),
    ('instructions',      'rt-mfg-instructions',      'manage',   'Draft and change work instructions'),
    ('instructions',      'rt-mfg-instructions',      'release',  'Release a work instruction to the shop floor'),
    ('documents',         'rt-mfg-documents',         'get',      'View and download documents'),
    ('documents',         'rt-mfg-documents',         'manage',   'Upload, revise and retire documents'),
    ('production_orders', 'rt-mfg-production-orders', 'get',      'View production orders'),
    ('production_orders', 'rt-mfg-production-orders', 'create',   'Create production orders'),
    ('production_orders', 'rt-mfg-production-orders', 'update',   'Change production orders before they start'),
    ('production_orders', 'rt-mfg-production-orders', 'release',  'Release production orders to the floor'),
    ('production_orders', 'rt-mfg-production-orders', 'execute',  'Start, pause and resume operations'),
    ('production_orders', 'rt-mfg-production-orders', 'complete', 'Complete production orders'),
    ('production_orders', 'rt-mfg-production-orders', 'close',    'Close production orders for costing'),
    ('production_orders', 'rt-mfg-production-orders', 'cancel',   'Cancel production orders'),
    ('materials',         'rt-mfg-materials',         'issue',    'Issue, return and backflush material against orders'),
    ('confirmations',     'rt-mfg-confirmations',     'get',      'View shop-floor confirmations'),
    ('confirmations',     'rt-mfg-confirmations',     'post',     'Report quantities, scrap and times'),
    ('confirmations',     'rt-mfg-confirmations',     'reverse',  'Reverse a confirmation'),
    ('downtime',          'rt-mfg-downtime',          'get',      'View downtime'),
    ('downtime',          'rt-mfg-downtime',          'post',     'Record downtime'),
    ('downtime',          'rt-mfg-downtime',          'manage',   'Reclassify and close downtime others recorded'),
    ('settings',          'rt-mfg-settings',          'get',      'View Manufacturing settings'),
    ('settings',          'rt-mfg-settings',          'manage',   'Change number series, defaults and policies'),
    ('logs',              'rt-mfg-logs',              'get',      'View the Manufacturing audit trail'),
    ('logs',              'rt-mfg-logs',              'export',   'Export the Manufacturing audit trail')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-mfg-' || spec.resource_key || '-' || spec.action,
       'Manufacturing ' || initcap(replace(spec.resource_key, '_', ' ')) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

-- resource_key may hold an underscore (production_orders); the action never does.
UPDATE core_platform.cp_permissions p
   SET app_prefix = 'mfg',
       resource_key = substring(p.id FROM '^permission-mfg-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-mfg-%'
   AND (p.app_prefix IS DISTINCT FROM 'mfg' OR p.action IS NULL);

-- ========================================================================== roles
INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-subscribed-app-mfg-admin', 'system-tenant-id', 'Manufacturing Admin', 'Administrator of Manufacturing: every Manufacturing permission', 'rt-subscribed-app-mfg', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-mfg-plant-manager', 'system-tenant-id', 'Manufacturing Plant Manager', 'Runs the plant: orders end to end, plant set-up, settings and the audit trail', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-mfg-planner',       'system-tenant-id', 'Manufacturing Planner',       'Creates, releases and reschedules production orders', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-mfg-supervisor',    'system-tenant-id', 'Manufacturing Supervisor',    'Runs the floor: starts and completes work, corrects reports, manages stations and downtime', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-mfg-operator',      'system-tenant-id', 'Manufacturing Operator',      'Runs jobs at a station: reports quantities, scrap and downtime, issues material', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-mfg-engineer',      'system-tenant-id', 'Manufacturing Engineer',      'Owns items, BOMs, routings and work instructions, and releases them', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-mfg-quality',       'system-tenant-id', 'Manufacturing Quality Engineer', 'Reads production and engineering, manages quality documents', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-mfg-maintenance',   'system-tenant-id', 'Manufacturing Maintenance Technician', 'Records and closes downtime, manages equipment documents', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-mfg-viewer',        'system-tenant-id', 'Manufacturing Viewer',        'Reads everything in Manufacturing; changes nothing', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name        = EXCLUDED.role_name,
                               description      = EXCLUDED.description,
                               resource_type_id = EXCLUDED.resource_type_id,
                               is_system        = EXCLUDED.is_system,
                               is_active        = EXCLUDED.is_active;

-- The grant matrix of 05-api-contracts.md §2.2, Release 1 resources.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-mfg-plant-manager' AS role_id, k AS resource_key, a AS action FROM (VALUES
        ('plants', 'get'), ('plants', 'manage'), ('stations', 'get'), ('stations', 'manage'), ('items', 'get'),
        ('boms', 'get'), ('routings', 'get'), ('instructions', 'get'), ('documents', 'get'), ('documents', 'manage'),
        ('production_orders', 'get'), ('production_orders', 'create'), ('production_orders', 'update'),
        ('production_orders', 'release'), ('production_orders', 'execute'), ('production_orders', 'complete'),
        ('production_orders', 'close'), ('production_orders', 'cancel'), ('materials', 'issue'),
        ('confirmations', 'get'), ('confirmations', 'reverse'), ('downtime', 'get'), ('downtime', 'post'),
        ('downtime', 'manage'), ('settings', 'get'), ('settings', 'manage'), ('logs', 'get'), ('logs', 'export')) AS pm(k, a)
    UNION ALL
    SELECT 'role-mfg-planner', k, a FROM (VALUES
        ('plants', 'get'), ('stations', 'get'), ('items', 'get'), ('boms', 'get'), ('routings', 'get'),
        ('instructions', 'get'), ('documents', 'get'), ('production_orders', 'get'), ('production_orders', 'create'),
        ('production_orders', 'update'), ('production_orders', 'release'), ('production_orders', 'cancel'),
        ('confirmations', 'get'), ('downtime', 'get'), ('settings', 'get')) AS pl(k, a)
    UNION ALL
    SELECT 'role-mfg-supervisor', k, a FROM (VALUES
        ('plants', 'get'), ('stations', 'get'), ('stations', 'manage'), ('items', 'get'), ('boms', 'get'),
        ('routings', 'get'), ('instructions', 'get'), ('documents', 'get'), ('production_orders', 'get'),
        ('production_orders', 'execute'), ('production_orders', 'complete'), ('materials', 'issue'),
        ('confirmations', 'get'), ('confirmations', 'post'), ('confirmations', 'reverse'), ('downtime', 'get'),
        ('downtime', 'post'), ('downtime', 'manage'), ('settings', 'get'), ('logs', 'get')) AS su(k, a)
    UNION ALL
    SELECT 'role-mfg-operator', k, a FROM (VALUES
        ('plants', 'get'), ('stations', 'get'), ('items', 'get'), ('instructions', 'get'), ('documents', 'get'),
        ('production_orders', 'get'), ('production_orders', 'execute'), ('materials', 'issue'),
        ('confirmations', 'get'), ('confirmations', 'post'), ('downtime', 'get'), ('downtime', 'post')) AS op(k, a)
    UNION ALL
    SELECT 'role-mfg-engineer', k, a FROM (VALUES
        ('plants', 'get'), ('plants', 'manage'), ('stations', 'get'), ('items', 'get'), ('items', 'manage'),
        ('boms', 'get'), ('boms', 'manage'), ('boms', 'release'), ('routings', 'get'), ('routings', 'manage'),
        ('routings', 'release'), ('instructions', 'get'), ('instructions', 'manage'), ('instructions', 'release'),
        ('documents', 'get'), ('documents', 'manage'), ('production_orders', 'get'), ('confirmations', 'get'),
        ('downtime', 'get'), ('settings', 'get')) AS en(k, a)
    UNION ALL
    SELECT 'role-mfg-quality', k, a FROM (VALUES
        ('plants', 'get'), ('stations', 'get'), ('items', 'get'), ('boms', 'get'), ('routings', 'get'),
        ('instructions', 'get'), ('documents', 'get'), ('documents', 'manage'), ('production_orders', 'get'),
        ('confirmations', 'get'), ('downtime', 'get'), ('settings', 'get'), ('logs', 'get')) AS qa(k, a)
    UNION ALL
    SELECT 'role-mfg-maintenance', k, a FROM (VALUES
        ('plants', 'get'), ('stations', 'get'), ('items', 'get'), ('instructions', 'get'), ('documents', 'get'),
        ('documents', 'manage'), ('production_orders', 'get'), ('downtime', 'get'), ('downtime', 'post'),
        ('downtime', 'manage'), ('settings', 'get')) AS mt(k, a)
    UNION ALL
    SELECT 'role-mfg-viewer', p3.resource_key, p3.action
      FROM core_platform.cp_permissions p3
      JOIN core_platform.cp_actions a ON a.action = p3.action AND a.is_read_only AND p3.action <> 'export'
     WHERE p3.app_prefix = 'mfg' AND p3.resource_key <> 'settings'
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'mfg' AND p.resource_key = spec.resource_key AND p.action = spec.action
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
 WHERE r.id IN ('role-subscribed-app-mfg-admin', 'role-mfg-plant-manager', 'role-mfg-planner', 'role-mfg-supervisor',
                'role-mfg-operator', 'role-mfg-engineer', 'role-mfg-quality', 'role-mfg-maintenance', 'role-mfg-viewer')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ========================================================== features per tier
-- Tiers are cumulative (20260821-02): a business on rank R has every feature whose
-- min_tier_rank <= R. 1=BASIC 2=ADVANCE 3=PREMIUM 4=ENTERPRISE (never gated: it means
-- self-hosted). feature_key is the contract between this file, the API
-- (internal/apps/mfg/plan.go) and the UI. Placement is the design's proposal
-- (07-security-and-tenancy.md §4); the owner sets prices and may move features.
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
-- ---- BASIC: make things ------------------------------------------------------------
('mfg.core',        'app-mfg', 'Production',            1, 'Plants, items, BOMs, routings, production orders, readiness'),
('mfg.shop-floor',  'app-mfg', 'Shop Floor',            1, 'Offline tablet stations, work instructions, quantities, scrap and downtime'),
('mfg.scheduling',  'app-mfg', 'Finite Scheduling',     1, 'A planning board that checks capacity, calendars and conflicts'),
-- ---- ADVANCE: plan and control ----------------------------------------------------
('mfg.planning',    'app-mfg', 'MRP',                   2, 'Net-change MRP, pegging, exceptions and planned orders'),
('mfg.quality',     'app-mfg', 'Quality',               2, 'Inspections, holds, non-conformances and CAPA'),
('mfg.trace',       'app-mfg', 'Traceability',          2, 'Lot and serial genealogy and recall'),
('mfg.maintenance', 'app-mfg', 'Maintenance',           2, 'Assets, preventive maintenance and work orders that move the schedule'),
('mfg.oee',         'app-mfg', 'OEE',                   2, 'Availability, performance, quality and the loss tree'),
('mfg.costing',     'app-mfg', 'Costing',               2, 'Cost roll-ups, actual cost and variances'),
-- ---- PREMIUM: see ahead -----------------------------------------------------------
('mfg.scenarios',   'app-mfg', 'What-if Scenarios',     3, 'Plan branches compared side by side'),
('mfg.iot',         'app-mfg', 'Machine Connectivity',  3, 'Edge gateway: OPC-UA, MQTT and Modbus machines'),
('mfg.workflow',    'app-mfg', 'Workflow Builder',      3, 'Your own rules, approvals and notifications'),
('mfg.copilot',     'app-mfg', 'Copilot',               3, 'Questions answered from your own data, anomaly explanations'),
('mfg.multi-plant', 'app-mfg', 'Multi-plant',           3, 'More than one plant per business, cross-plant planning')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

-- ================================================================ label and routes
INSERT INTO control_plane.ctl_reserved_labels (label, reason, created_by)
SELECT v.label, v.reason, 'migration:20261029-30'
  FROM (VALUES ('mfg', 'a product: mfg.dev.trovesuite.com, manufacturing')) AS v(label, reason)
 WHERE NOT EXISTS (SELECT 1 FROM control_plane.ctl_reserved_labels r WHERE r.label = v.label);

-- BOTH the website and the API host (TRAPS.md #8).
INSERT INTO control_plane.ctl_tenant_routes (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT h.host, NULL, 'POOLED', h.cell, 'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261029-30'
  FROM (VALUES ('mfg.dev.trovesuite.com',     'uksouth-dev'),
               ('api.mfg.dev.trovesuite.com', 'uksouth-dev')) AS h(host, cell)
 WHERE EXISTS (SELECT 1 FROM control_plane.ctl_cells c WHERE c.cell_key = h.cell)
ON CONFLICT (host) DO NOTHING;

-- ============================================================ billing, add-on, data
-- Manufacturing posts stock into SCM's ledger, so it is an add-on to SCM: a business may only
-- subscribe while it holds SCM (cp_apps.requires_app_id, 20261028-50; design decision D1). Billed
-- per business like SCM until the owner prices plants and stations. On unsubscribe its own schema
-- is purged after the grace period (20261028-60); the stock it posted is SCM's and stays with SCM.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'core_platform' AND table_name = 'cp_apps' AND column_name = 'billing_unit') THEN
        UPDATE core_platform.cp_apps SET billing_unit = 'BUSINESS'
         WHERE id = 'app-mfg' AND billing_unit IS DISTINCT FROM 'BUSINESS';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'core_platform' AND table_name = 'cp_apps' AND column_name = 'requires_app_id') THEN
        UPDATE core_platform.cp_apps SET requires_app_id = 'app-scm'
         WHERE id = 'app-mfg' AND requires_app_id IS DISTINCT FROM 'app-scm';
    END IF;
    IF to_regclass('core_platform.cp_app_data_owners') IS NOT NULL THEN
        INSERT INTO core_platform.cp_app_data_owners (app_id, schema_name, fate, note)
        VALUES ('app-mfg', 'mfg', 'PURGE', 'Stock Manufacturing posted lives in SCM''s ledger and stays with SCM.')
        ON CONFLICT (app_id) DO UPDATE SET schema_name = EXCLUDED.schema_name, fate = EXCLUDED.fate, note = EXCLUDED.note;
    END IF;
END $$;

-- ===================================================================== invariants
DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions
     WHERE id LIKE 'permission-mfg-%' AND (app_prefix <> 'mfg' OR resource_key IS NULL OR action IS NULL);
    IF n > 0 THEN
        RAISE EXCEPTION '% Manufacturing permission(s) have no pair; nothing would match them', n;
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-mfg-viewer' AND p.app_prefix = 'mfg' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-mfg-viewer holds % Manufacturing permission(s) that change data', n;
    END IF;
    -- Only the plant manager and supervisor may undo what the floor reported.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id NOT IN ('role-mfg-plant-manager', 'role-mfg-supervisor')
                  AND p.app_prefix = 'mfg' AND p.resource_key = 'confirmations' AND p.action = 'reverse') THEN
        RAISE EXCEPTION 'a role other than Manufacturing Plant Manager or Supervisor may reverse confirmations';
    END IF;
    -- Engineering releases belong to the engineer: nobody else releases a BOM, routing or instruction.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id <> 'role-mfg-engineer' AND p.app_prefix = 'mfg'
                  AND p.resource_key IN ('boms', 'routings', 'instructions') AND p.action = 'release') THEN
        RAISE EXCEPTION 'a role other than Manufacturing Engineer may release engineering data';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id LIKE 'role-mfg-%' AND p.app_prefix = 'mfg' AND p.resource_key = 'settings' AND p.action = 'manage'
                  AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp2 JOIN core_platform.cp_permissions p2 ON p2.id = rp2.permission_id
                                   WHERE rp2.role_id = rp.role_id AND p2.app_prefix = 'mfg' AND p2.resource_key = 'plants' AND p2.action = 'manage')) THEN
        RAISE EXCEPTION 'a Manufacturing role may change settings without managing plants';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-mfg-admin' AND permission_id LIKE 'permission-mfg-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-mfg-admin holds Manufacturing permission rows';
    END IF;
    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host IN ('mfg.dev.trovesuite.com', 'api.mfg.dev.trovesuite.com')
                  AND (tenant_id IS NOT NULL OR is_wildcard)) THEN
        RAISE EXCEPTION 'a Manufacturing address has been given to a tenant or made a wildcard';
    END IF;
END $$;

COMMIT;
