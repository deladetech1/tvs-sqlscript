-- HMS joins the platform: hospitality and property management -- hotels, guest houses,
-- short stays, serviced apartments, hostels, restaurants, landlords and property managers.
--
-- Served by the shared apps backend (deladetech1/tvs-shared-apps-bk, module "hms") like the
-- CRM, Projects, Invoicing and Expenses; frontend tvs-hms-ft. Its cp_apps row, tier prices
-- and the role-cp-admin exclusion live in the CorePlatform seed (04_others.sql), which owns
-- every app row. This file holds the rest:
--
--   * the hms schema and its audit trail (hms_audit_logs); properties, stays, rentals and the
--     restaurant come in the files after this one;
--   * its cp_app_schemas row, so activity-log retention finds hms.hms_audit_logs;
--   * resource types, permissions (hms|<resource>|<action>||any) and the roles: HMS Admin is
--     allowed by BEING the role and holds no HMS rows; the job roles carry grants;
--   * which features each subscription tier includes (cp_app_feature_catalog);
--   * the reserved label "hms" and the route rows for the website and the API (api.hms.dev:
--     without it, a call with no browser Origin -- curl, webhooks -- is 404 "not configured").
--
-- Not to be confused with app-hams (a hospital system, coming soon): a different product.
-- Nothing here asserts on rows a module seed creates. Idempotent; safe to re-run.

BEGIN;

CREATE SCHEMA IF NOT EXISTS hms;

INSERT INTO core_platform.cp_app_schemas (app_id, schema_name, description)
VALUES ('app-hms', 'hms', 'HMS audit logs')
ON CONFLICT (app_id) DO UPDATE SET schema_name = EXCLUDED.schema_name,
                                   description = EXCLUDED.description;

CREATE TABLE IF NOT EXISTS hms.hms_audit_logs (
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
CREATE INDEX IF NOT EXISTS hms_audit_entity_idx
    ON hms.hms_audit_logs (tenant_id, entity_type, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS hms_audit_business_idx
    ON hms.hms_audit_logs (bus_id, cdatetime DESC);

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-subscribed-app-hms', 'HMS APP', 'HMS Subscribed APP', NULL)
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-hms-properties',   'HMS Properties',   'Properties, units, unit types and rates',              'rt-subscribed-app-hms'),
('rt-hms-reservations', 'HMS Reservations', 'Bookings, guests and availability',                    'rt-subscribed-app-hms'),
('rt-hms-frontdesk',    'HMS Front Desk',   'Checking guests in and out, moving rooms',              'rt-subscribed-app-hms'),
('rt-hms-folios',       'HMS Folios',       'Guest bills: charges, payments, refunds and reversals', 'rt-subscribed-app-hms'),
('rt-hms-housekeeping', 'HMS Housekeeping', 'Cleaning tasks and room status',                       'rt-subscribed-app-hms'),
('rt-hms-maintenance',  'HMS Maintenance',  'Maintenance tickets and work orders',                  'rt-subscribed-app-hms'),
('rt-hms-restaurant',   'HMS Restaurant',   'Menus, tables, orders and room charges',               'rt-subscribed-app-hms'),
('rt-hms-rentals',      'HMS Rentals',      'Tenants, leases, rent and arrears',                    'rt-subscribed-app-hms'),
('rt-hms-settings',     'HMS Settings',     'Business type, modules and policies',                  'rt-subscribed-app-hms'),
('rt-hms-reports',      'HMS Reports',      'Occupancy, revenue, collections and operations',       'rt-subscribed-app-hms'),
('rt-hms-logs',         'HMS Logs',         'The audit trail of HMS',                               'rt-subscribed-app-hms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

-- The CRM brought "export" (20261015-02); asserted here too so this file stands on its own.
INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('export', 'Export', true, false)
ON CONFLICT (action) DO NOTHING;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('properties',   'rt-hms-properties',   'get',     'View properties, units and rates'),
    ('properties',   'rt-hms-properties',   'manage',  'Set up properties, units, unit types and rates'),
    ('reservations', 'rt-hms-reservations', 'get',     'View reservations, guests and availability'),
    ('reservations', 'rt-hms-reservations', 'create',  'Take reservations and add guests'),
    ('reservations', 'rt-hms-reservations', 'update',  'Change reservations and guest details'),
    ('reservations', 'rt-hms-reservations', 'cancel',  'Cancel reservations and mark no-shows'),
    ('frontdesk',    'rt-hms-frontdesk',    'manage',  'Check guests in and out and move rooms'),
    ('folios',       'rt-hms-folios',       'get',     'View guest bills'),
    ('folios',       'rt-hms-folios',       'post',    'Post charges to a guest bill'),
    ('folios',       'rt-hms-folios',       'pay',     'Take payments on a guest bill'),
    ('folios',       'rt-hms-folios',       'reverse', 'Reverse a posted charge or payment'),
    ('folios',       'rt-hms-folios',       'refund',  'Refund a guest'),
    ('housekeeping', 'rt-hms-housekeeping', 'get',     'View cleaning tasks and room status'),
    ('housekeeping', 'rt-hms-housekeeping', 'manage',  'Assign and complete cleaning, set room status'),
    ('maintenance',  'rt-hms-maintenance',  'get',     'View maintenance tickets'),
    ('maintenance',  'rt-hms-maintenance',  'create',  'Report a maintenance issue'),
    ('maintenance',  'rt-hms-maintenance',  'manage',  'Assign, work and close maintenance tickets'),
    ('restaurant',   'rt-hms-restaurant',   'get',     'View menus, tables and orders'),
    ('restaurant',   'rt-hms-restaurant',   'create',  'Take orders, settle them or charge them to a room'),
    ('restaurant',   'rt-hms-restaurant',   'void',    'Void an order or an item on it'),
    ('restaurant',   'rt-hms-restaurant',   'manage',  'Set up menus, prices and tables'),
    ('rentals',      'rt-hms-rentals',      'get',     'View tenants, leases, rent and arrears'),
    ('rentals',      'rt-hms-rentals',      'manage',  'Add tenants and set up, renew and end leases'),
    ('rentals',      'rt-hms-rentals',      'pay',     'Record rent payments'),
    ('settings',     'rt-hms-settings',     'get',     'View HMS settings'),
    ('settings',     'rt-hms-settings',     'manage',  'Choose the business type, modules and policies'),
    ('reports',      'rt-hms-reports',      'get',     'View occupancy, revenue and collection reports'),
    ('reports',      'rt-hms-reports',      'export',  'Export reports'),
    ('logs',         'rt-hms-logs',         'get',     'View the HMS audit trail')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-hms-' || spec.resource_key || '-' || spec.action,
       'HMS ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'hms',
       resource_key = substring(p.id FROM '^permission-hms-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-hms-%'
   AND (p.app_prefix IS DISTINCT FROM 'hms' OR p.action IS NULL);

-- ========================================================================== roles
INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-subscribed-app-hms-admin', 'system-tenant-id', 'HMS Admin', 'Administrator of HMS: every HMS permission', 'rt-subscribed-app-hms', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-hms-manager',      'system-tenant-id', 'HMS General Manager', 'Runs the property: every HMS permission, settings and reports included', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-hms-frontdesk',    'system-tenant-id', 'HMS Front Desk',      'Takes reservations, checks guests in and out, posts charges and takes payments', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-hms-housekeeper',  'system-tenant-id', 'HMS Housekeeper',     'Cleans and inspects units and reports maintenance issues', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-hms-maintenance',  'system-tenant-id', 'HMS Maintenance Technician', 'Works and closes maintenance tickets', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-hms-cashier',      'system-tenant-id', 'HMS Restaurant Cashier', 'Takes restaurant orders, settles them or charges them to a room', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-hms-rentals',      'system-tenant-id', 'HMS Rentals Officer', 'Manages tenants and leases and records rent', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-hms-finance',      'system-tenant-id', 'HMS Finance Officer', 'Takes and refunds payments, reverses lines, reads and exports every report', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-hms-viewer',       'system-tenant-id', 'HMS Viewer',          'Reads everything in HMS; changes nothing', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name        = EXCLUDED.role_name,
                               description      = EXCLUDED.description,
                               resource_type_id = EXCLUDED.resource_type_id,
                               is_system        = EXCLUDED.is_system,
                               is_active        = EXCLUDED.is_active;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-hms-manager' AS role_id, p2.resource_key, p2.action
      FROM core_platform.cp_permissions p2 WHERE p2.app_prefix = 'hms'
    UNION ALL
    SELECT 'role-hms-frontdesk', k, a FROM (VALUES
        ('properties', 'get'), ('reservations', 'get'), ('reservations', 'create'), ('reservations', 'update'),
        ('reservations', 'cancel'), ('frontdesk', 'manage'), ('folios', 'get'), ('folios', 'post'), ('folios', 'pay'),
        ('housekeeping', 'get'), ('maintenance', 'get'), ('maintenance', 'create'), ('restaurant', 'get'),
        ('settings', 'get')) AS f(k, a)
    UNION ALL
    SELECT 'role-hms-housekeeper', k, a FROM (VALUES
        ('properties', 'get'), ('housekeeping', 'get'), ('housekeeping', 'manage'), ('maintenance', 'get'),
        ('maintenance', 'create'), ('settings', 'get')) AS h(k, a)
    UNION ALL
    SELECT 'role-hms-maintenance', k, a FROM (VALUES
        ('properties', 'get'), ('housekeeping', 'get'), ('maintenance', 'get'), ('maintenance', 'create'),
        ('maintenance', 'manage'), ('settings', 'get')) AS m(k, a)
    UNION ALL
    SELECT 'role-hms-cashier', k, a FROM (VALUES
        ('properties', 'get'), ('restaurant', 'get'), ('restaurant', 'create'), ('settings', 'get')) AS c(k, a)
    UNION ALL
    SELECT 'role-hms-rentals', k, a FROM (VALUES
        ('properties', 'get'), ('rentals', 'get'), ('rentals', 'manage'), ('rentals', 'pay'), ('maintenance', 'get'),
        ('maintenance', 'create'), ('reports', 'get'), ('settings', 'get')) AS l(k, a)
    UNION ALL
    SELECT 'role-hms-finance', k, a FROM (VALUES
        ('properties', 'get'), ('reservations', 'get'), ('folios', 'get'), ('folios', 'pay'), ('folios', 'reverse'),
        ('folios', 'refund'), ('restaurant', 'get'), ('rentals', 'get'), ('rentals', 'pay'), ('reports', 'get'),
        ('reports', 'export'), ('logs', 'get'), ('settings', 'get')) AS fi(k, a)
    UNION ALL
    SELECT 'role-hms-viewer', p3.resource_key, p3.action
      FROM core_platform.cp_permissions p3
      JOIN core_platform.cp_actions a ON a.action = p3.action AND a.is_read_only AND p3.action <> 'export'
     WHERE p3.app_prefix = 'hms'
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'hms' AND p.resource_key = spec.resource_key AND p.action = spec.action
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
 WHERE r.id IN ('role-subscribed-app-hms-admin', 'role-hms-manager', 'role-hms-frontdesk', 'role-hms-housekeeper',
                'role-hms-maintenance', 'role-hms-cashier', 'role-hms-rentals', 'role-hms-finance', 'role-hms-viewer')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ========================================================== features per tier
-- Tiers are cumulative (20260821-02): a business on rank R has every feature whose
-- min_tier_rank <= R. 1=BASIC 2=ADVANCE 3=PREMIUM 4=ENTERPRISE. feature_key is the contract
-- between this file, the HMS API (internal/apps/hms/plan.go) and the UI (src/data/modules.ts).
-- Which of these a business SEES is also its business type (hms_settings.modules): a landlord
-- on PREMIUM is entitled to the restaurant but is never shown it unless they turn it on.
-- How many units a property may hold per tier is in plan.go, not here: it is a number, not a flag.
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
-- ---- BASIC: run one property ------------------------------------------------------
('hms.dashboard',        'app-hms', 'Dashboard',              1, 'Today at a glance: arrivals, departures, in-house, rooms to clean, rent due'),
('hms.properties',       'app-hms', 'Properties & Units',     1, 'Properties, unit types, units and base rates'),
('hms.reservations',     'app-hms', 'Reservations',           1, 'Bookings, availability calendar, walk-ins and phone bookings'),
('hms.frontdesk',        'app-hms', 'Front Desk',             1, 'Check-in, check-out, room moves and guest folios'),
('hms.guests',           'app-hms', 'Guests',                 1, 'Guest profiles and stay history'),
('hms.housekeeping',     'app-hms', 'Housekeeping',           1, 'Room status, cleaning tasks and inspections'),
('hms.rentals',          'app-hms', 'Rentals',                1, 'Tenants, leases, rent schedules, payments and arrears'),
('hms.reports',          'app-hms', 'Reports',                1, 'Occupancy, ADR, RevPAR, revenue and collections'),
('hms.settings',         'app-hms', 'Settings',               1, 'Business type, modules and policies'),
-- ---- ADVANCE: run every outlet ----------------------------------------------------
('hms.restaurant',       'app-hms', 'Restaurant & Bar POS',   2, 'Menus, tables, orders, kitchen tickets and room charges'),
('hms.maintenance',      'app-hms', 'Maintenance',            2, 'Tickets, priorities, assignments and costs'),
('hms.rate-plans',       'app-hms', 'Seasonal Rates',         2, 'Rates that change by date, weekends and length of stay'),
('hms.report-export',    'app-hms', 'Report Export',          2, 'CSV downloads of every report'),
-- ---- PREMIUM: run a portfolio -----------------------------------------------------
('hms.multi-property',   'app-hms', 'Portfolio Reports',      3, 'Every property side by side and consolidated'),
('hms.owner-statements', 'app-hms', 'Owner Statements',       3, 'Statements and management fees for property owners'),
('hms.audit-logs',       'app-hms', 'Audit Trail',            3, 'Who changed what, and when')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

-- ================================================================ label and routes
INSERT INTO control_plane.ctl_reserved_labels (label, reason, created_by)
SELECT v.label, v.reason, 'migration:20261022-61'
  FROM (VALUES ('hms', 'a product: hms.dev.trovesuite.com, hospitality and property management')) AS v(label, reason)
 WHERE NOT EXISTS (SELECT 1 FROM control_plane.ctl_reserved_labels r WHERE r.label = v.label);

INSERT INTO control_plane.ctl_tenant_routes (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT h.host, NULL, 'POOLED', h.cell, 'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261022-61'
  FROM (VALUES ('hms.dev.trovesuite.com',     'uksouth-dev'),
               ('api.hms.dev.trovesuite.com', 'uksouth-dev')) AS h(host, cell)
 WHERE EXISTS (SELECT 1 FROM control_plane.ctl_cells c WHERE c.cell_key = h.cell)
ON CONFLICT (host) DO NOTHING;

-- ===================================================================== invariants
DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions
     WHERE id LIKE 'permission-hms-%' AND (app_prefix <> 'hms' OR resource_key IS NULL OR action IS NULL);
    IF n > 0 THEN
        RAISE EXCEPTION '% HMS permission(s) have no pair; nothing would match them', n;
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-hms-viewer' AND p.app_prefix = 'hms' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-hms-viewer holds % HMS permission(s) that change data', n;
    END IF;
    -- Money leaves only through finance and the manager: nobody else refunds or reverses.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id NOT IN ('role-hms-manager', 'role-hms-finance')
                  AND p.app_prefix = 'hms' AND p.resource_key = 'folios' AND p.action IN ('refund', 'reverse')) THEN
        RAISE EXCEPTION 'a role other than HMS General Manager or Finance Officer may refund or reverse';
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_permissions p
     WHERE p.app_prefix = 'hms' AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                        WHERE rp.role_id = 'role-hms-manager' AND rp.permission_id = p.id);
    IF n > 0 THEN
        RAISE EXCEPTION 'role-hms-manager lacks % HMS permission(s)', n;
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-hms-admin' AND permission_id LIKE 'permission-hms-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-hms-admin holds HMS permission rows';
    END IF;
    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host IN ('hms.dev.trovesuite.com', 'api.hms.dev.trovesuite.com') AND tenant_id IS NOT NULL) THEN
        RAISE EXCEPTION 'an HMS address has been given to a tenant';
    END IF;
END $$;

COMMIT;
