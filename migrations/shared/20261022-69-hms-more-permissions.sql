-- HMS permissions for the areas added after 20261022-61: inventory, activities, events,
-- channels, marketing (loyalty, companies, agents, campaigns, reviews), finance (owners,
-- statements, cash drawers, reports) and integrations (automations, API keys, webhooks).
-- A storekeeper role runs the stores.
--
-- 20261022-61 re-runs before this file on every deploy and grants every hms permission to the
-- General Manager and every read-only one to the Viewer, so later deploys keep them whole; this
-- file grants them too, for the first deploy.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-hms-inventory',    'HMS Inventory',    'Stores, stock, recipes and purchase orders',           'rt-subscribed-app-hms'),
('rt-hms-activities',   'HMS Activities',   'Tours, spa and excursions and their bookings',         'rt-subscribed-app-hms'),
('rt-hms-events',       'HMS Events',       'Conferences, weddings and banquets',                   'rt-subscribed-app-hms'),
('rt-hms-channels',     'HMS Channels',     'Airbnb, Booking.com and other channels, and the inbox', 'rt-subscribed-app-hms'),
('rt-hms-marketing',    'HMS Marketing',    'Loyalty, companies, agents, campaigns and reviews',    'rt-subscribed-app-hms'),
('rt-hms-finance',      'HMS Finance',      'Owners and statements, cash drawers, finance reports', 'rt-subscribed-app-hms'),
('rt-hms-integrations', 'HMS Integrations', 'Automations, API keys and webhooks',                   'rt-subscribed-app-hms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('inventory',    'rt-hms-inventory',    'get',    'View stock, recipes and purchase orders'),
    ('inventory',    'rt-hms-inventory',    'manage', 'Receive, issue, count and order stock'),
    ('activities',   'rt-hms-activities',   'get',    'View activities and their bookings'),
    ('activities',   'rt-hms-activities',   'create', 'Book guests onto activities'),
    ('activities',   'rt-hms-activities',   'manage', 'Set up activities and their sessions'),
    ('events',       'rt-hms-events',       'get',    'View events'),
    ('events',       'rt-hms-events',       'manage', 'Take and run events'),
    ('channels',     'rt-hms-channels',     'get',    'View channels and the inbox'),
    ('channels',     'rt-hms-channels',     'manage', 'Connect channels and message guests'),
    ('marketing',    'rt-hms-marketing',    'get',    'View loyalty, companies, agents and reviews'),
    ('marketing',    'rt-hms-marketing',    'manage', 'Run loyalty, rates, agents, campaigns and reviews'),
    ('finance',      'rt-hms-finance',      'get',    'View owners, statements and finance reports'),
    ('finance',      'rt-hms-finance',      'manage', 'Manage owners, contracts and cash drawers'),
    ('integrations', 'rt-hms-integrations', 'manage', 'Set up automations, API keys and webhooks')
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

INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-hms-storekeeper', 'system-tenant-id', 'HMS Storekeeper', 'Runs the stores: receives, issues, counts and orders stock', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name = EXCLUDED.role_name, description = EXCLUDED.description,
                               resource_type_id = EXCLUDED.resource_type_id, is_system = EXCLUDED.is_system, is_active = EXCLUDED.is_active;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-hms-manager' AS role_id, p2.resource_key, p2.action
      FROM core_platform.cp_permissions p2 WHERE p2.app_prefix = 'hms'
    UNION ALL
    SELECT 'role-hms-viewer', p3.resource_key, p3.action
      FROM core_platform.cp_permissions p3 JOIN core_platform.cp_actions a ON a.action = p3.action AND a.is_read_only AND p3.action <> 'export'
     WHERE p3.app_prefix = 'hms'
    UNION ALL
    SELECT 'role-hms-frontdesk', k, a FROM (VALUES
        ('activities', 'get'), ('activities', 'create'), ('events', 'get'), ('channels', 'get'), ('channels', 'manage'),
        ('marketing', 'get')) AS f(k, a)
    UNION ALL
    SELECT 'role-hms-cashier', k, a FROM (VALUES ('activities', 'get'), ('activities', 'create'), ('inventory', 'get')) AS c(k, a)
    UNION ALL
    SELECT 'role-hms-housekeeper', k, a FROM (VALUES ('inventory', 'get')) AS h(k, a)
    UNION ALL
    SELECT 'role-hms-maintenance', k, a FROM (VALUES ('inventory', 'get')) AS m(k, a)
    UNION ALL
    SELECT 'role-hms-rentals', k, a FROM (VALUES ('channels', 'get'), ('channels', 'manage'), ('finance', 'get')) AS l(k, a)
    UNION ALL
    SELECT 'role-hms-finance', k, a FROM (VALUES ('finance', 'get'), ('finance', 'manage'), ('inventory', 'get'), ('events', 'get'),
        ('marketing', 'get'), ('activities', 'get')) AS fi(k, a)
    UNION ALL
    SELECT 'role-hms-storekeeper', k, a FROM (VALUES ('properties', 'get'), ('inventory', 'get'), ('inventory', 'manage'),
        ('restaurant', 'get'), ('settings', 'get')) AS sk(k, a)
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'hms' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', 'role-hms-storekeeper', p.id
  FROM core_platform.cp_permissions p
 WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions p
     WHERE p.app_prefix = 'hms' AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                        WHERE rp.role_id = 'role-hms-manager' AND rp.permission_id = p.id);
    IF n > 0 THEN
        RAISE EXCEPTION 'role-hms-manager lacks % HMS permission(s)', n;
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-hms-viewer' AND p.app_prefix = 'hms' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-hms-viewer holds % HMS permission(s) that change data', n;
    END IF;
END $$;

COMMIT;
