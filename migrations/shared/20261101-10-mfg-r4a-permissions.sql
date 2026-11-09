-- Manufacturing Release 4a (see ahead, connect machines and systems): its resource types, verbs,
-- permissions and the job roles' grants (design: tvs-shared-apps-bk docs/mfg/05-api-contracts.md §2;
-- contract docs/mfg/contracts/R4a.md E18, E19).
--
--   resources   scenarios, iot, webhooks (mfg|<resource>|<verb>||any, permission-mfg-<resource>-<verb>)
--   grants      planner: scenarios (all), iot get
--               plant manager: scenarios (all), iot get, webhooks get
--               supervisor: scenarios get, iot get
--               engineer: iot (all), scenarios get
--               maintenance technician: iot get
--               quality engineer: iot get
--               viewer: scenarios get, iot get
--               operator: nothing new
--   webhooks    webhooks|manage is Manufacturing Admin's alone (by being the role). webhooks|get is
--               a read-only verb, so the viewer rules of the join file (20261029-30) and of R2/R3
--               (20261030-10, 20261031-10), which grant the viewer every read-only mfg permission,
--               pick it up from the second deploy on; this file runs after them and takes it away
--               again, so the viewer never keeps it (E18: the viewer gets scenarios get, iot get).
--   features    mfg.scenarios and mfg.iot (E19's plan gates) come from the join file
--               (20261029-30); asserted here, not re-seeded.
--
-- Manufacturing Admin (role-subscribed-app-mfg-admin) holds no mfg rows; the roles and the
-- navigation block are the join file's, so this file runs after it. Nothing here asserts on rows a
-- module seed creates. Idempotent; safe to re-run.

BEGIN;

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-mfg-scenarios', 'Manufacturing Scenarios', 'What-if scenarios: changes, runs against the live plan, outcomes, compare and apply', 'rt-subscribed-app-mfg'),
('rt-mfg-iot',       'Manufacturing IoT',       'Machine connectivity: devices and keys, signal maps, readings, machine states and counts, anomalies', 'rt-subscribed-app-mfg'),
('rt-mfg-webhooks',  'Manufacturing Webhooks',  'Webhook subscriptions, their deliveries and replays, the event catalogue and the pull API', 'rt-subscribed-app-mfg')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

-- Verbs other apps may not have brought yet; asserted here so this file stands on its own.
INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('manage', 'Manage', false, false)
ON CONFLICT (action) DO NOTHING;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('scenarios', 'rt-mfg-scenarios', 'get',    'View what-if scenarios, their outcomes and comparisons'),
    ('scenarios', 'rt-mfg-scenarios', 'manage', 'Create, change, run, copy, archive and apply what-if scenarios'),
    ('iot',       'rt-mfg-iot',       'get',    'View devices, signal maps, readings, machine states and counts, and anomalies'),
    ('iot',       'rt-mfg-iot',       'manage', 'Register, rotate and revoke devices, and manage signal maps and baselines'),
    ('webhooks',  'rt-mfg-webhooks',  'get',    'View webhook subscriptions, deliveries, the event catalogue and the pull API'),
    ('webhooks',  'rt-mfg-webhooks',  'manage', 'Create, change, pause, test and rotate webhook subscriptions, and replay deliveries')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-mfg-' || spec.resource_key || '-' || spec.action,
       'Manufacturing ' || CASE spec.resource_key WHEN 'iot' THEN 'IoT' ELSE initcap(spec.resource_key) END
                        || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'mfg',
       resource_key = substring(p.id FROM '^permission-mfg-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-mfg-%'
   AND (p.app_prefix IS DISTINCT FROM 'mfg' OR p.action IS NULL);

-- ========================================================================== grants
-- E18 of the R4a contract. The roles come from the join file (20261029-30).
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (VALUES
        ('role-mfg-planner',       'scenarios', 'get'), ('role-mfg-planner',       'scenarios', 'manage'),
        ('role-mfg-planner',       'iot',       'get'),
        ('role-mfg-plant-manager', 'scenarios', 'get'), ('role-mfg-plant-manager', 'scenarios', 'manage'),
        ('role-mfg-plant-manager', 'iot',       'get'), ('role-mfg-plant-manager', 'webhooks',  'get'),
        ('role-mfg-supervisor',    'scenarios', 'get'), ('role-mfg-supervisor',    'iot',       'get'),
        ('role-mfg-engineer',      'iot',       'get'), ('role-mfg-engineer',      'iot',       'manage'),
        ('role-mfg-engineer',      'scenarios', 'get'),
        ('role-mfg-maintenance',   'iot',       'get'),
        ('role-mfg-quality',       'iot',       'get'),
        ('role-mfg-viewer',        'scenarios', 'get'), ('role-mfg-viewer',        'iot',       'get')
  ) AS spec(role_id, resource_key, action)
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'mfg' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- The earlier files' viewer rules grant every read-only mfg permission, webhooks|get included once
-- it exists (the second deploy on). The webhook log is not the viewer's (E18).
DELETE FROM core_platform.cp_role_permissions
 WHERE role_id = 'role-mfg-viewer' AND permission_id = 'permission-mfg-webhooks-get';

-- ===================================================================== invariants
DO $$
DECLARE
    n int;
    f text;
    r4a constant text[] := ARRAY['scenarios', 'iot', 'webhooks'];
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions
     WHERE id LIKE 'permission-mfg-%' AND (app_prefix <> 'mfg' OR resource_key IS NULL OR action IS NULL
                                          OR coalesce(target, '') <> '' OR scope IS DISTINCT FROM 'any');
    IF n > 0 THEN
        RAISE EXCEPTION '% Manufacturing permission(s) have no pair; nothing would match them', n;
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_permissions p
                WHERE p.app_prefix = 'mfg' AND p.resource_key = ANY (r4a)
                  AND NOT EXISTS (SELECT 1 FROM core_platform.cp_actions a WHERE a.action = p.action)) THEN
        RAISE EXCEPTION 'an R4a Manufacturing permission names a verb missing from cp_actions';
    END IF;
    -- Viewers read only, and not the webhook log.
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-mfg-viewer' AND p.app_prefix = 'mfg' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-mfg-viewer holds % Manufacturing permission(s) that change data', n;
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-mfg-viewer' AND p.app_prefix = 'mfg' AND p.resource_key = 'webhooks') THEN
        RAISE EXCEPTION 'role-mfg-viewer holds a Manufacturing webhooks permission';
    END IF;
    -- The admin is allowed by being the role.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-mfg-admin' AND permission_id LIKE 'permission-mfg-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-mfg-admin holds Manufacturing permission rows';
    END IF;
    -- Operators get nothing new in R4a.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-mfg-operator' AND p.app_prefix = 'mfg' AND p.resource_key = ANY (r4a)) THEN
        RAISE EXCEPTION 'role-mfg-operator holds an R4a Manufacturing permission';
    END IF;
    -- webhooks|manage sends the business's events to outside URLs: Manufacturing Admin's alone.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id LIKE 'role-mfg-%' AND p.app_prefix = 'mfg' AND p.resource_key = 'webhooks'
                  AND p.action = 'manage') THEN
        RAISE EXCEPTION 'a Manufacturing job role may manage webhooks; that is Manufacturing Admin''s alone';
    END IF;
    -- Of the job roles only the plant manager reads the webhook log.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id LIKE 'role-mfg-%' AND rp.role_id <> 'role-mfg-plant-manager'
                  AND p.app_prefix = 'mfg' AND p.resource_key = 'webhooks') THEN
        RAISE EXCEPTION 'a Manufacturing job role other than Plant Manager holds a webhooks permission';
    END IF;
    -- E19: the plan features the R4a gates read exist (20261029-30).
    FOREACH f IN ARRAY ARRAY['mfg.scenarios', 'mfg.iot', 'mfg.workflow', 'mfg.maintenance'] LOOP
        IF NOT EXISTS (SELECT 1 FROM core_platform.cp_app_feature_catalog
                        WHERE feature_key = f AND app_id = 'app-mfg' AND is_active) THEN
            RAISE EXCEPTION 'Manufacturing plan feature % is missing from cp_app_feature_catalog', f;
        END IF;
    END LOOP;
END $$;

COMMIT;
