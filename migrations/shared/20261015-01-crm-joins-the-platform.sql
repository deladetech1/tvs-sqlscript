-- The CRM joins the platform.
--
-- The CRM is served by the shared apps backend (deladetech1/tvs-shared-apps-bk, one Go
-- container that will also host invoicing, expenses and projects) and the frontend
-- deladetech1/tvs-crm-ft. Its cp_apps row and tier prices live in the CorePlatform seed
-- (04_others.sql), which owns every app row. This file holds the rest:
--
--   * the crm schema. Empty for now -- the CRM has no tables yet. tvs-iac's db-app-group
--     also creates it and grants the app group on it (common.hcl app_schemas); creating
--     it here as well means the schema exists wherever migrations run, including silos
--     and enterprise databases that tvs-iac does not reach.
--   * its cp_app_schemas row, so activity-log retention finds crm.*_audit_logs.
--   * the resource type and the CRM admin role. role-subscribed-app-crm-admin carries no
--     CRM permission rows: an app admin is allowed by BEING the role, in every auth
--     package (tvs-package-go appAdminRoles). It does get the six core-platform
--     navigation permissions every app role seeds for itself.
--   * the reserved label "crm", so no client can be given crm.<anything>.
--   * route rows. With tenancy enforced, an address no row claims is a 404 before
--     sign-in: the CRM frontend, and the container app's own address (probes and
--     server-to-server calls arrive with no Origin).
--
-- CRM permissions (crm|contacts|get||any, ...) arrive with the features that check them.
--
-- Nothing here asserts on rows a module seed creates: a shared file runs on deploys that
-- did not run the CorePlatform seed. The navigation grant joins cp_permissions, so a
-- permission that does not exist is simply not granted.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE SCHEMA IF NOT EXISTS crm;

INSERT INTO core_platform.cp_app_schemas (app_id, schema_name, description)
VALUES ('app-crm', 'crm', 'CRM audit logs')
ON CONFLICT (app_id) DO UPDATE SET schema_name = EXCLUDED.schema_name,
                                   description = EXCLUDED.description;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-subscribed-app-crm', 'CRM APP', 'CRM Subscribed APP', NULL)
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description;

INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-subscribed-app-crm-admin', 'system-tenant-id', 'CRM Admin', 'Administrator of the CRM: every CRM permission', 'rt-subscribed-app-crm', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name        = EXCLUDED.role_name,
                               description      = EXCLUDED.description,
                               resource_type_id = EXCLUDED.resource_type_id,
                               is_system        = EXCLUDED.is_system,
                               is_active        = EXCLUDED.is_active;

-- The core-platform navigation block every app role seeds for itself (CorePlatform grants it
-- only to non-app roles). Without it the CRM admin cannot list the businesses and locations
-- the CRM frontend switches between.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', 'role-subscribed-app-crm-admin', p.id
  FROM core_platform.cp_permissions p
 WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations',
                'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

INSERT INTO control_plane.ctl_reserved_labels (label, reason, created_by)
SELECT v.label, v.reason, 'migration:20261015-01'
  FROM (VALUES ('crm', 'a product: crm.dev.trovesuite.com, the CRM')) AS v(label, reason)
 WHERE NOT EXISTS (SELECT 1 FROM control_plane.ctl_reserved_labels r WHERE r.label = v.label);

INSERT INTO control_plane.ctl_tenant_routes (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT h.host, NULL, 'POOLED', h.cell, 'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261015-01'
  FROM (VALUES
    ('crm.dev.trovesuite.com', 'uksouth-dev'),
    ('tvs-dev-shared-apps-ca.victoriousmeadow-176f82b8.uksouth.azurecontainerapps.io', 'uksouth-dev')
  ) AS h(host, cell)
 WHERE EXISTS (SELECT 1 FROM control_plane.ctl_cells c WHERE c.cell_key = h.cell)
ON CONFLICT (host) DO NOTHING;

-- Invariants, not counts: whatever else is in these tables, these must hold.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM core_platform.cp_roles
                    WHERE id = 'role-subscribed-app-crm-admin'
                      AND resource_type_id = 'rt-subscribed-app-crm' AND is_system) THEN
        RAISE EXCEPTION 'role-subscribed-app-crm-admin is missing or not a system role of rt-subscribed-app-crm';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-crm-admin'
                  AND permission_id LIKE 'permission-crm-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-crm-admin holds CRM permission rows; an app admin is allowed by being the role';
    END IF;
    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host IN ('crm.dev.trovesuite.com',
                               'tvs-dev-shared-apps-ca.victoriousmeadow-176f82b8.uksouth.azurecontainerapps.io')
                  AND tenant_id IS NOT NULL) THEN
        RAISE EXCEPTION 'a CRM platform address has been given to a tenant';
    END IF;
END $$;

COMMIT;
