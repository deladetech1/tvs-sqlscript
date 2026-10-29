-- Manufacturing Release 2 (plan and control): its resource types, verbs, permissions and the job
-- roles' grants (design: tvs-shared-apps-bk docs/mfg/05-api-contracts.md §2; contract
-- docs/mfg/contracts/R2.md C13, C14).
--
--   resources   mrp, planned_orders, demands, inspections, ncrs, capas, holds, trace, ecos, costing,
--               exceptions (mfg|<resource>|<verb>||any, permission-mfg-<resource>-<verb>)
--   grants      planner: mrp, planned_orders, demands, exceptions
--               quality engineer: inspections, ncrs, capas, holds, trace
--               operator: inspections|record, holds|get
--               engineer: ecos get, create, implement; costing get
--               plant manager: every R2 get, plus exceptions (all), ecos approve, costing manage
--               viewer: every R2 get (the read-only verbs, as the join file's viewer rule)
--   features    mfg.planning, mfg.quality, mfg.trace, mfg.costing come from the join file
--               (20261029-30); asserted here, not re-seeded.
--
-- Manufacturing Admin (role-subscribed-app-mfg-admin) is allowed by BEING the role and holds no mfg
-- rows; the roles and the navigation block are the join file's. The roles named here are the join
-- file's job roles, so this file runs after it. Nothing here asserts on rows a module seed creates.
-- Idempotent; safe to re-run.

BEGIN;

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-mfg-mrp',            'Manufacturing MRP',            'Material requirements planning: runs, requirements, pegging, messages and freshness', 'rt-subscribed-app-mfg'),
('rt-mfg-planned-orders', 'Manufacturing Planned Orders', 'What MRP proposes to make and buy; firming and converting it',                          'rt-subscribed-app-mfg'),
('rt-mfg-demands',        'Manufacturing Demands',        'Customer orders and demand lines entered in Manufacturing, and safety stock',          'rt-subscribed-app-mfg'),
('rt-mfg-inspections',    'Manufacturing Inspections',    'Inspection plans, inspections and their results',                                      'rt-subscribed-app-mfg'),
('rt-mfg-ncrs',           'Manufacturing NCRs',           'Non-conformance reports and their dispositions',                                       'rt-subscribed-app-mfg'),
('rt-mfg-capas',          'Manufacturing CAPAs',          'Corrective and preventive actions, 8D',                                                'rt-subscribed-app-mfg'),
('rt-mfg-holds',          'Manufacturing Holds',          'Quality holds on lots, serials, orders and suppliers',                                 'rt-subscribed-app-mfg'),
('rt-mfg-trace',          'Manufacturing Traceability',   'Lot and serial genealogy, backward and forward, and recalls',                          'rt-subscribed-app-mfg'),
('rt-mfg-ecos',           'Manufacturing ECOs',           'Engineering change requests and orders',                                               'rt-subscribed-app-mfg'),
('rt-mfg-costing',        'Manufacturing Costing',        'Cost roll-ups, cost sets and order variances',                                         'rt-subscribed-app-mfg'),
('rt-mfg-exceptions',     'Manufacturing Exceptions',     'Exceptions rolled up by root cause, and their playbooks',                              'rt-subscribed-app-mfg')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

-- Verbs other apps may not have brought yet; asserted here so this file stands on its own.
INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('run',         'Run',         false, false),
('firm',        'Firm',        false, false),
('convert',     'Convert',     false, false),
('record',      'Record',      false, false),
('waive',       'Waive',       false, false),
('disposition', 'Disposition', false, false),
('place',       'Place',       false, false),
('release',     'Release',     false, false),
('approve',     'Approve',     false, false),
('implement',   'Implement',   false, false),
('assign',      'Assign',      false, false),
('resolve',     'Resolve',     false, false),
('close',       'Close',       false, false)
ON CONFLICT (action) DO NOTHING;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('mrp',            'rt-mfg-mrp',            'get',         'View MRP requirements, pegging, messages and plan freshness'),
    ('mrp',            'rt-mfg-mrp',            'run',         'Run a full MRP regeneration'),
    ('planned_orders', 'rt-mfg-planned-orders', 'get',         'View planned orders and purchase suggestions'),
    ('planned_orders', 'rt-mfg-planned-orders', 'firm',        'Change and firm planned orders'),
    ('planned_orders', 'rt-mfg-planned-orders', 'convert',     'Convert planned orders into production orders and requisitions'),
    ('demands',        'rt-mfg-demands',        'get',         'View demands entered in Manufacturing'),
    ('demands',        'rt-mfg-demands',        'manage',      'Enter, change and cancel demands, and set safety stock'),
    ('inspections',    'rt-mfg-inspections',    'get',         'View inspection plans, inspections and results'),
    ('inspections',    'rt-mfg-inspections',    'record',      'Record inspection results and complete inspections'),
    ('inspections',    'rt-mfg-inspections',    'waive',       'Waive an inspection, and draft and release inspection plans'),
    ('ncrs',           'rt-mfg-ncrs',           'get',         'View non-conformance reports'),
    ('ncrs',           'rt-mfg-ncrs',           'manage',      'Raise and change non-conformance reports'),
    ('ncrs',           'rt-mfg-ncrs',           'disposition', 'Disposition non-conforming quantities, which moves stock'),
    ('ncrs',           'rt-mfg-ncrs',           'close',       'Close non-conformance reports'),
    ('capas',          'rt-mfg-capas',          'get',         'View CAPAs and 8D reports'),
    ('capas',          'rt-mfg-capas',          'manage',      'Open and work CAPAs and 8D reports'),
    ('capas',          'rt-mfg-capas',          'close',       'Close CAPAs after verifying their effectiveness'),
    ('holds',          'rt-mfg-holds',          'get',         'View quality holds'),
    ('holds',          'rt-mfg-holds',          'place',       'Place quality holds on lots, serials, orders and suppliers'),
    ('holds',          'rt-mfg-holds',          'release',     'Release quality holds'),
    ('trace',          'rt-mfg-trace',          'get',         'Trace lots and serials backward and forward, and snapshot recalls'),
    ('ecos',           'rt-mfg-ecos',           'get',         'View engineering changes and their impact'),
    ('ecos',           'rt-mfg-ecos',           'create',      'Raise, change and submit engineering changes'),
    ('ecos',           'rt-mfg-ecos',           'approve',     'Approve or reject engineering changes'),
    ('ecos',           'rt-mfg-ecos',           'implement',   'Implement approved engineering changes as new released revisions'),
    ('costing',        'rt-mfg-costing',        'get',         'View item costs, cost sets and order variances'),
    ('costing',        'rt-mfg-costing',        'manage',      'Roll up costs and freeze cost sets'),
    ('exceptions',     'rt-mfg-exceptions',     'get',         'View exceptions and their playbooks'),
    ('exceptions',     'rt-mfg-exceptions',     'assign',      'Acknowledge and assign exceptions'),
    ('exceptions',     'rt-mfg-exceptions',     'resolve',     'Resolve and dismiss exceptions')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-mfg-' || spec.resource_key || '-' || spec.action,
       'Manufacturing ' || initcap(replace(spec.resource_key, '_', ' ')) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

-- resource_key may hold an underscore (planned_orders); the action never does.
UPDATE core_platform.cp_permissions p
   SET app_prefix = 'mfg',
       resource_key = substring(p.id FROM '^permission-mfg-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-mfg-%'
   AND (p.app_prefix IS DISTINCT FROM 'mfg' OR p.action IS NULL);

-- ========================================================================== grants
-- C13 of the R2 contract. The roles come from the join file (20261029-30).
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-mfg-plant-manager' AS role_id, k AS resource_key, a AS action FROM (VALUES
        ('mrp', 'get'), ('planned_orders', 'get'), ('demands', 'get'), ('inspections', 'get'), ('ncrs', 'get'),
        ('capas', 'get'), ('holds', 'get'), ('trace', 'get'), ('ecos', 'get'), ('ecos', 'approve'),
        ('costing', 'get'), ('costing', 'manage'),
        ('exceptions', 'get'), ('exceptions', 'assign'), ('exceptions', 'resolve')) AS pm(k, a)
    UNION ALL
    SELECT 'role-mfg-planner', k, a FROM (VALUES
        ('mrp', 'get'), ('mrp', 'run'), ('planned_orders', 'get'), ('planned_orders', 'firm'),
        ('planned_orders', 'convert'), ('demands', 'get'), ('demands', 'manage'),
        ('exceptions', 'get'), ('exceptions', 'assign'), ('exceptions', 'resolve')) AS pl(k, a)
    UNION ALL
    SELECT 'role-mfg-quality', k, a FROM (VALUES
        ('inspections', 'get'), ('inspections', 'record'), ('inspections', 'waive'),
        ('ncrs', 'get'), ('ncrs', 'manage'), ('ncrs', 'disposition'), ('ncrs', 'close'),
        ('capas', 'get'), ('capas', 'manage'), ('capas', 'close'),
        ('holds', 'get'), ('holds', 'place'), ('holds', 'release'), ('trace', 'get')) AS qa(k, a)
    UNION ALL
    SELECT 'role-mfg-operator', k, a FROM (VALUES
        ('inspections', 'record'), ('holds', 'get')) AS op(k, a)
    UNION ALL
    SELECT 'role-mfg-engineer', k, a FROM (VALUES
        ('ecos', 'get'), ('ecos', 'create'), ('ecos', 'implement'), ('costing', 'get')) AS en(k, a)
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
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions
     WHERE id LIKE 'permission-mfg-%' AND (app_prefix <> 'mfg' OR resource_key IS NULL OR action IS NULL
                                          OR coalesce(target, '') <> '' OR scope IS DISTINCT FROM 'any');
    IF n > 0 THEN
        RAISE EXCEPTION '% Manufacturing permission(s) have no pair; nothing would match them', n;
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
    -- At the floor an operator records results and sees holds; nothing more of R2.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-mfg-operator' AND p.app_prefix = 'mfg'
                  AND p.resource_key IN ('mrp', 'planned_orders', 'demands', 'inspections', 'ncrs', 'capas', 'holds',
                                         'trace', 'ecos', 'costing', 'exceptions')
                  AND (p.resource_key, p.action) NOT IN (('inspections', 'record'), ('holds', 'get'))) THEN
        RAISE EXCEPTION 'role-mfg-operator holds an R2 Manufacturing permission beyond inspections|record and holds|get';
    END IF;
    -- The one who raises an engineering change does not approve it.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id LIKE 'role-mfg-%' AND p.app_prefix = 'mfg' AND p.resource_key = 'ecos' AND p.action = 'approve'
                  AND EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp2 JOIN core_platform.cp_permissions p2 ON p2.id = rp2.permission_id
                               WHERE rp2.role_id = rp.role_id AND p2.app_prefix = 'mfg' AND p2.resource_key = 'ecos' AND p2.action = 'create')) THEN
        RAISE EXCEPTION 'a Manufacturing job role may both raise and approve engineering changes';
    END IF;
    -- The R2 plan features exist (20261029-30), so plan.go's gates have rows to read.
    FOREACH f IN ARRAY ARRAY['mfg.core', 'mfg.planning', 'mfg.quality', 'mfg.trace', 'mfg.costing'] LOOP
        IF NOT EXISTS (SELECT 1 FROM core_platform.cp_app_feature_catalog
                        WHERE feature_key = f AND app_id = 'app-mfg' AND is_active) THEN
            RAISE EXCEPTION 'Manufacturing plan feature % is missing from cp_app_feature_catalog', f;
        END IF;
    END LOOP;
END $$;

COMMIT;
