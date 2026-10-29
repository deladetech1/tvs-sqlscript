-- SMS joins the platform: school management -- creches and nurseries, primary, basic, junior and
-- senior high schools, sixth form colleges, universities and colleges, technical and vocational
-- institutes, and other places of learning (language schools, tutorial centres, academies).
--
-- Served by the shared apps backend (deladetech1/tvs-shared-apps-bk, module "sms") like the
-- CRM, Projects, Invoicing, Expenses, HMS and SCM; frontend tvs-sms-ft. Its cp_apps row, tier
-- prices and the role-cp-admin exclusion live in the CorePlatform seed (04_others.sql), which
-- owns every app row. Billed per LOCATION (the default in 20261022-70): one school profile is
-- one Core Platform location. This file holds the rest:
--
--   * the sms schema and its audit trail (sms_audit_logs); the school profiles and the file
--     manager come in the file after this one (20261028-02);
--   * its cp_app_schemas row, so activity-log retention finds sms.sms_audit_logs;
--   * resource types, permissions (sms|<resource>|<action>||any) and the roles: SMS Admin is
--     allowed by BEING the role and holds no SMS rows; the job roles carry grants. Only what the
--     app checks today is granted -- academics, students, fees and staff join with their screens;
--   * which features each subscription tier includes (cp_app_feature_catalog);
--   * the reserved label "sms" and the route rows for the website and the API (api.sms.dev:
--     without it, a call with no browser Origin -- curl, webhooks -- is 404 "not configured").
--
-- Not to be confused with SMS the text message (sms-providers, the CRM's sms channel): app-sms
-- is the School Management System. Nothing here asserts on rows a module seed creates.
-- Idempotent; safe to re-run.

BEGIN;

CREATE SCHEMA IF NOT EXISTS sms;

-- widen_check: (re)defines a CHECK constraint, unless it already holds `token` -- the value the
-- calling migration introduced. Every migration re-runs on each deploy, oldest first, so a
-- constraint that later migrations widened must not be put back to an older, narrower list:
-- a row using a newer value would fail it and stop the deploy there, and nothing after it
-- would ever run. Each migration names its newest value; an older one then leaves a newer
-- definition alone.
CREATE OR REPLACE FUNCTION sms.widen_check(tbl regclass, name text, token text, def text) RETURNS void
LANGUAGE plpgsql AS $f$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint c WHERE c.conrelid = tbl AND c.conname = name
                AND position(token IN pg_get_constraintdef(c.oid)) > 0) THEN
        RETURN;
    END IF;
    EXECUTE format('ALTER TABLE %s DROP CONSTRAINT IF EXISTS %I', tbl, name);
    EXECUTE format('ALTER TABLE %s ADD CONSTRAINT %I %s', tbl, name, def);
END
$f$;

INSERT INTO core_platform.cp_app_schemas (app_id, schema_name, description)
VALUES ('app-sms', 'sms', 'SMS (school management) audit logs')
ON CONFLICT (app_id) DO UPDATE SET schema_name = EXCLUDED.schema_name,
                                   description = EXCLUDED.description;

CREATE TABLE IF NOT EXISTS sms.sms_audit_logs (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    org_id       text,
    bus_id       text,
    profile_id   text,
    entity_type  text NOT NULL,
    entity_id    text NOT NULL,
    action       text NOT NULL,
    changes      jsonb NOT NULL DEFAULT '{}',
    actor_id     text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sms_audit_entity_idx
    ON sms.sms_audit_logs (tenant_id, entity_type, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS sms_audit_business_idx
    ON sms.sms_audit_logs (bus_id, cdatetime DESC);

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-subscribed-app-sms', 'SMS APP', 'SMS (School Management) Subscribed APP', NULL)
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-profiles', 'SMS School Profiles', 'Each school''s identity, institution type, levels, location and contacts', 'rt-subscribed-app-sms'),
('rt-sms-settings', 'SMS Settings',        'How the school management system is set up',                             'rt-subscribed-app-sms'),
('rt-sms-logs',     'SMS Logs',            'The audit trail of the school management system',                         'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('profiles', 'rt-sms-profiles', 'get',    'View school profiles'),
    ('profiles', 'rt-sms-profiles', 'manage', 'Set up, change and delete school profiles'),
    ('settings', 'rt-sms-settings', 'get',    'View the school management settings'),
    ('settings', 'rt-sms-settings', 'manage', 'Change the school management settings'),
    ('logs',     'rt-sms-logs',     'get',    'View the school management audit trail')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-sms-' || spec.resource_key || '-' || spec.action,
       'SMS ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'sms',
       resource_key = substring(p.id FROM '^permission-sms-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-sms-%'
   AND (p.app_prefix IS DISTINCT FROM 'sms' OR p.action IS NULL);

-- ========================================================================== roles
INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-subscribed-app-sms-admin', 'system-tenant-id', 'SMS Admin', 'Administrator of the school management system: every SMS permission', 'rt-subscribed-app-sms', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-sms-head',      'system-tenant-id', 'SMS Head of School',   'Runs the school: every SMS permission, its profile, settings and audit trail included', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-sms-registrar', 'system-tenant-id', 'SMS School Registrar', 'Keeps the school''s profile and records up to date', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-sms-viewer',    'system-tenant-id', 'SMS Viewer',           'Reads everything in the school management system; changes nothing', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name        = EXCLUDED.role_name,
                               description      = EXCLUDED.description,
                               resource_type_id = EXCLUDED.resource_type_id,
                               is_system        = EXCLUDED.is_system,
                               is_active        = EXCLUDED.is_active;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-sms-head' AS role_id, p2.resource_key, p2.action
      FROM core_platform.cp_permissions p2 WHERE p2.app_prefix = 'sms'
    UNION ALL
    SELECT 'role-sms-registrar', k, a FROM (VALUES
        ('profiles', 'get'), ('profiles', 'manage'), ('settings', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-viewer', p3.resource_key, p3.action
      FROM core_platform.cp_permissions p3
      JOIN core_platform.cp_actions a ON a.action = p3.action AND a.is_read_only AND p3.action <> 'export'
     WHERE p3.app_prefix = 'sms'
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'sms' AND p.resource_key = spec.resource_key AND p.action = spec.action
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
 WHERE r.id IN ('role-subscribed-app-sms-admin', 'role-sms-head', 'role-sms-registrar', 'role-sms-viewer')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ========================================================== features per tier
-- Tiers are cumulative (20260821-02): a business on rank R has every feature whose
-- min_tier_rank <= R. 1=BASIC 2=ADVANCE 3=PREMIUM 4=ENTERPRISE. feature_key is the contract
-- between this file, the SMS API (internal/apps/sms/plan.go) and the UI (src/data/plan.ts).
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
-- ---- BASIC: run one school --------------------------------------------------------
('sms.dashboard',    'app-sms', 'Dashboard',       1, 'The school at a glance and what is left to set up'),
('sms.profile',      'app-sms', 'School Profile',  1, 'Identity, institution type, levels, classification, location and contacts'),
('sms.settings',     'app-sms', 'Settings',        1, 'How the school management system is set up'),
-- ---- ADVANCE: run several schools --------------------------------------------------
('sms.multi-school', 'app-sms', 'Several Schools', 2, 'More than one school profile, one per location, switched between in the app'),
-- ---- PREMIUM: governance ------------------------------------------------------------
('sms.audit-logs',   'app-sms', 'Audit Trail',     3, 'Who changed what, and when')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

-- ================================================================ label and routes
INSERT INTO control_plane.ctl_reserved_labels (label, reason, created_by)
SELECT v.label, v.reason, 'migration:20261028-01'
  FROM (VALUES ('sms', 'a product: sms.dev.trovesuite.com, school management')) AS v(label, reason)
 WHERE NOT EXISTS (SELECT 1 FROM control_plane.ctl_reserved_labels r WHERE r.label = v.label);

-- Both the website and the API host, dev only (the WHERE EXISTS on the dev cell keeps these
-- rows out of production; the prod hosts come in a later file with cell uksouth-prod).
INSERT INTO control_plane.ctl_tenant_routes (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT h.host, NULL, 'POOLED', h.cell, 'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261028-01'
  FROM (VALUES ('sms.dev.trovesuite.com',     'uksouth-dev'),
               ('api.sms.dev.trovesuite.com', 'uksouth-dev')) AS h(host, cell)
 WHERE EXISTS (SELECT 1 FROM control_plane.ctl_cells c WHERE c.cell_key = h.cell)
ON CONFLICT (host) DO NOTHING;

-- ===================================================================== invariants
-- Properties, never counts: a later file may add permissions, roles or features.
DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions
     WHERE id LIKE 'permission-sms-%'
       AND (app_prefix IS DISTINCT FROM 'sms' OR resource_key IS NULL OR action IS NULL
            OR coalesce(target, '') <> '' OR scope IS DISTINCT FROM 'any');
    IF n > 0 THEN
        RAISE EXCEPTION '% SMS permission(s) have no pair; nothing would match them', n;
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-sms-viewer' AND p.app_prefix = 'sms' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-sms-viewer holds % SMS permission(s) that change data', n;
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_permissions p
     WHERE p.app_prefix = 'sms' AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                        WHERE rp.role_id = 'role-sms-head' AND rp.permission_id = p.id);
    IF n > 0 THEN
        RAISE EXCEPTION 'role-sms-head lacks % SMS permission(s)', n;
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-sms-admin' AND permission_id LIKE 'permission-sms-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-sms-admin holds SMS permission rows';
    END IF;
    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host IN ('sms.dev.trovesuite.com', 'api.sms.dev.trovesuite.com') AND tenant_id IS NOT NULL) THEN
        RAISE EXCEPTION 'an SMS address has been given to a tenant';
    END IF;
END $$;

COMMIT;
