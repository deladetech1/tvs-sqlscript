-- Manufacturing Release 3 (run the plant): its resource types, verbs, permissions and the job roles'
-- grants (design: tvs-shared-apps-bk docs/mfg/05-api-contracts.md §2; contract
-- docs/mfg/contracts/R3.md D22, D23).
--
--   resources   assets, maintenance_orders, schedule, oee, forecasts, rules, approvals, imports,
--               buy_orders (mfg|<resource>|<verb>||any, permission-mfg-<resource>-<verb>)
--   grants      maintenance technician: assets (all), maintenance_orders (all), schedule get, oee get
--               planner: schedule (all), forecasts (all), buy_orders (all), assets get,
--               maintenance_orders get, oee get, imports run
--               supervisor: maintenance_orders get + create, schedule get, oee get, assets get,
--               buy_orders receive
--               engineer: assets get, imports run
--               quality engineer: oee get
--               plant manager: every R3 get, plus rules manage, approvals decide,
--               maintenance_orders manage
--               viewer: every R3 get (the read-only verbs, as the join file's viewer rule)
--               operator: nothing new; operators raise maintenance through R1 floor requests
--   features    mfg.maintenance, mfg.oee, mfg.planning, mfg.workflow, mfg.scheduling and mfg.core
--               (D23's plan gates) come from the join file (20261029-30); asserted here, not
--               re-seeded.
--
-- Manufacturing Admin (role-subscribed-app-mfg-admin) is allowed by BEING the role and holds no mfg
-- rows; the roles and the navigation block are the join file's. The roles named here are the join
-- file's job roles, so this file runs after it. Nothing here asserts on rows a module seed creates.
-- Idempotent; safe to re-run.

BEGIN;

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-mfg-assets',             'Manufacturing Assets',             'The asset register, meter readings, failure codes and preventive maintenance plans', 'rt-subscribed-app-mfg'),
('rt-mfg-maintenance-orders', 'Manufacturing Maintenance Orders', 'Maintenance work orders from request to close: tasks, labour and spare parts',       'rt-subscribed-app-mfg'),
('rt-mfg-schedule',           'Manufacturing Schedule',           'The finite planning board: operations on resources, conflicts and capacity',         'rt-subscribed-app-mfg'),
('rt-mfg-oee',                'Manufacturing OEE',                'Overall equipment effectiveness, the loss tree and production analytics',             'rt-subscribed-app-mfg'),
('rt-mfg-forecasts',          'Manufacturing Forecasts',          'Demand forecasts per product and bucket, their versions and accuracy',                'rt-subscribed-app-mfg'),
('rt-mfg-rules',              'Manufacturing Rules',              'Versioned workflow rules, their dry runs, publication and runs',                      'rt-subscribed-app-mfg'),
('rt-mfg-approvals',          'Manufacturing Approvals',          'Approvals requested by rules',                                                        'rt-subscribed-app-mfg'),
('rt-mfg-imports',            'Manufacturing Imports',            'CSV and Excel imports with a preview, and the sample plant',                          'rt-subscribed-app-mfg'),
('rt-mfg-buy-orders',         'Manufacturing Buy Orders',         'Buy orders to suppliers, placed and received into stock',                             'rt-subscribed-app-mfg')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

-- Verbs other apps may not have brought yet; asserted here so this file stands on its own.
INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('manage',   'Manage',   false, false),
('complete', 'Complete', false, false),
('run',      'Run',      false, false),
('decide',   'Decide',   false, false),
('receive',  'Receive',  false, false)
ON CONFLICT (action) DO NOTHING;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('assets',             'rt-mfg-assets',             'get',      'View assets, meter readings, failure codes, preventive maintenance plans and maintenance KPIs'),
    ('assets',             'rt-mfg-assets',             'manage',   'Register and change assets, report them down and up, record meters, and manage failure codes and PM plans'),
    ('maintenance_orders', 'rt-mfg-maintenance-orders', 'get',      'View maintenance work orders'),
    ('maintenance_orders', 'rt-mfg-maintenance-orders', 'create',   'Request maintenance work orders'),
    ('maintenance_orders', 'rt-mfg-maintenance-orders', 'manage',   'Approve, schedule, change, close and cancel maintenance work orders'),
    ('maintenance_orders', 'rt-mfg-maintenance-orders', 'complete', 'Start and complete maintenance work: tasks, labour and spare parts'),
    ('schedule',           'rt-mfg-schedule',           'get',      'View the planning board, its conflicts and capacity'),
    ('schedule',           'rt-mfg-schedule',           'manage',   'Move, lock and auto-schedule operations'),
    ('oee',                'rt-mfg-oee',                'get',      'View OEE, the loss tree and production analytics'),
    ('forecasts',          'rt-mfg-forecasts',          'get',      'View demand forecasts and their accuracy'),
    ('forecasts',          'rt-mfg-forecasts',          'manage',   'Generate, override, publish and copy demand forecasts'),
    ('rules',              'rt-mfg-rules',              'get',      'View workflow rules, presets and their runs'),
    ('rules',              'rt-mfg-rules',              'manage',   'Draft, test, publish, enable and resume workflow rules'),
    ('approvals',          'rt-mfg-approvals',          'decide',   'Decide any approval of the business'),
    ('imports',            'rt-mfg-imports',            'run',      'Import data from CSV or Excel and create the sample plant'),
    ('buy_orders',         'rt-mfg-buy-orders',         'get',      'View buy orders and suppliers'),
    ('buy_orders',         'rt-mfg-buy-orders',         'manage',   'Draft, change, place, close and cancel buy orders'),
    ('buy_orders',         'rt-mfg-buy-orders',         'receive',  'Receive buy orders into stock')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-mfg-' || spec.resource_key || '-' || spec.action,
       'Manufacturing ' || initcap(replace(spec.resource_key, '_', ' ')) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

-- resource_key may hold an underscore (maintenance_orders); the action never does.
UPDATE core_platform.cp_permissions p
   SET app_prefix = 'mfg',
       resource_key = substring(p.id FROM '^permission-mfg-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-mfg-%'
   AND (p.app_prefix IS DISTINCT FROM 'mfg' OR p.action IS NULL);

-- ========================================================================== grants
-- D22 of the R3 contract. The roles come from the join file (20261029-30).
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-mfg-maintenance' AS role_id, k AS resource_key, a AS action FROM (VALUES
        ('assets', 'get'), ('assets', 'manage'),
        ('maintenance_orders', 'get'), ('maintenance_orders', 'create'), ('maintenance_orders', 'manage'),
        ('maintenance_orders', 'complete'),
        ('schedule', 'get'), ('oee', 'get')) AS mt(k, a)
    UNION ALL
    SELECT 'role-mfg-planner', k, a FROM (VALUES
        ('schedule', 'get'), ('schedule', 'manage'), ('forecasts', 'get'), ('forecasts', 'manage'),
        ('buy_orders', 'get'), ('buy_orders', 'manage'), ('buy_orders', 'receive'),
        ('assets', 'get'), ('maintenance_orders', 'get'), ('oee', 'get'), ('imports', 'run')) AS pl(k, a)
    UNION ALL
    SELECT 'role-mfg-supervisor', k, a FROM (VALUES
        ('maintenance_orders', 'get'), ('maintenance_orders', 'create'), ('schedule', 'get'), ('oee', 'get'),
        ('assets', 'get'), ('buy_orders', 'receive')) AS su(k, a)
    UNION ALL
    SELECT 'role-mfg-engineer', k, a FROM (VALUES
        ('assets', 'get'), ('imports', 'run')) AS en(k, a)
    UNION ALL
    SELECT 'role-mfg-quality', k, a FROM (VALUES
        ('oee', 'get')) AS qa(k, a)
    UNION ALL
    SELECT 'role-mfg-plant-manager', k, a FROM (VALUES
        ('assets', 'get'), ('maintenance_orders', 'get'), ('schedule', 'get'), ('oee', 'get'),
        ('forecasts', 'get'), ('rules', 'get'), ('buy_orders', 'get'),
        ('rules', 'manage'), ('approvals', 'decide'), ('maintenance_orders', 'manage')) AS pm(k, a)
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

-- ===================================================================== invariants
DO $$
DECLARE
    n int;
    f text;
    r3 constant text[] := ARRAY['assets', 'maintenance_orders', 'schedule', 'oee', 'forecasts', 'rules',
                                'approvals', 'imports', 'buy_orders'];
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions
     WHERE id LIKE 'permission-mfg-%' AND (app_prefix <> 'mfg' OR resource_key IS NULL OR action IS NULL
                                          OR coalesce(target, '') <> '' OR scope IS DISTINCT FROM 'any');
    IF n > 0 THEN
        RAISE EXCEPTION '% Manufacturing permission(s) have no pair; nothing would match them', n;
    END IF;
    -- Every R3 verb is a known action, so the grant joins above can find it.
    IF EXISTS (SELECT 1 FROM core_platform.cp_permissions p
                WHERE p.app_prefix = 'mfg' AND p.resource_key = ANY (r3)
                  AND NOT EXISTS (SELECT 1 FROM core_platform.cp_actions a WHERE a.action = p.action)) THEN
        RAISE EXCEPTION 'an R3 Manufacturing permission names a verb missing from cp_actions';
    END IF;
    -- Viewers read only.
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-mfg-viewer' AND p.app_prefix = 'mfg' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-mfg-viewer holds % Manufacturing permission(s) that change data', n;
    END IF;
    -- The admin is allowed by being the role.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-mfg-admin' AND permission_id LIKE 'permission-mfg-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-mfg-admin holds Manufacturing permission rows';
    END IF;
    -- Operators raise maintenance through floor requests; they hold no R3 permission.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-mfg-operator' AND p.app_prefix = 'mfg' AND p.resource_key = ANY (r3)) THEN
        RAISE EXCEPTION 'role-mfg-operator holds an R3 Manufacturing permission';
    END IF;
    -- Custom rules act with their publisher's rights, so publishing them stays with the plant manager.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id LIKE 'role-mfg-%' AND rp.role_id <> 'role-mfg-plant-manager'
                  AND p.app_prefix = 'mfg' AND p.resource_key = 'rules' AND p.action = 'manage') THEN
        RAISE EXCEPTION 'a Manufacturing job role other than Plant Manager may manage workflow rules';
    END IF;
    -- D23: the plan features the R3 gates read exist (20261029-30), so plan.go has rows to read.
    FOREACH f IN ARRAY ARRAY['mfg.core', 'mfg.scheduling', 'mfg.planning', 'mfg.maintenance', 'mfg.oee', 'mfg.workflow'] LOOP
        IF NOT EXISTS (SELECT 1 FROM core_platform.cp_app_feature_catalog
                        WHERE feature_key = f AND app_id = 'app-mfg' AND is_active) THEN
            RAISE EXCEPTION 'Manufacturing plan feature % is missing from cp_app_feature_catalog', f;
        END IF;
    END LOOP;
END $$;

COMMIT;
