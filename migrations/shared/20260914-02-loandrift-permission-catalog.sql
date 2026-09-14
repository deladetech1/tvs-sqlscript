-- Reconcile permissions used by the LoanDrift application. Safe to rerun.

-- Accounting belongs to LoanDrift, independently of other applications.
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id)
VALUES ('rt-loandrift-accounting', 'LoanDrift Accounting', 'Accounts, journals, fixed assets and accounting reports', 'rt-subscribed-app-loandrift')
ON CONFLICT (id) DO UPDATE SET resource_type_name=EXCLUDED.resource_type_name, description=EXCLUDED.description, parent_resource_id=EXCLUDED.parent_resource_id;

-- Permissions checked by the accounting and credit bureau endpoints.
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime) VALUES
('permission-loandrift-accounting-get', 'Loandrift Accounting Get', 'rt-loandrift-accounting', 'Can read accounts, journals, assets and financial statements', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-accounting-create', 'Loandrift Accounting Create', 'rt-loandrift-accounting', 'Can create journals and assets and run depreciation; administrator restrictions still apply where required', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-accounting-update', 'Loandrift Accounting Update', 'rt-loandrift-accounting', 'Can update accounting records; administrator restrictions still apply where required', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-accounting-delete', 'Loandrift Accounting Delete', 'rt-loandrift-accounting', 'Can delete accounting records; administrator restrictions still apply where required', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-credit-score-create', 'Loandrift Credit Score Create', 'rt-credit-score', 'Can request credit bureau enquiries', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET permission_name=EXCLUDED.permission_name, resource_type_id=EXCLUDED.resource_type_id, description=EXCLUDED.description;

INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime)
VALUES ('role-loandrift-accounting-admin', 'system-tenant-id', 'Loandrift Accounting Admin', 'Manage LoanDrift accounting subject to owner-only configuration restrictions', 'rt-loandrift-accounting', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name=EXCLUDED.role_name, description=EXCLUDED.description, resource_type_id=EXCLUDED.resource_type_id;

-- Existing system roles may predate these permissions. Repair only the new
-- catalogue entries; preserve custom roles, explicit denials and viewer access.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT r.tenant_id, r.id, p.id, r.role_name || ' can ' || lower(p.permission_name), CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
FROM core_platform.cp_roles r
JOIN core_platform.cp_permissions p ON p.id IN (
  'permission-loandrift-accounting-get', 'permission-loandrift-accounting-create',
  'permission-loandrift-accounting-update', 'permission-loandrift-accounting-delete',
  'permission-loandrift-credit-score-create')
JOIN core_platform.cp_resource_types rt ON rt.id=p.resource_type_id
WHERE r.is_system AND r.is_active AND r.delete_status='NOT_DELETED'
  AND (r.resource_type_id IN (p.resource_type_id, rt.parent_resource_id)
       OR r.id IN ('role-owner','role-admin'))
  AND (r.role_name NOT LIKE '%Viewer Admin%' OR p.id LIKE '%-get')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- Core Platform resource types can be shared/reparented. App-wide roles must
-- also receive this app's explicitly namespaced permissions, including locations.
-- Currency is a shared read dependency, never currency administration.
INSERT INTO core_platform.cp_role_permissions
  (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT r.tenant_id, r.id, p.id, r.role_name || ' can ' || lower(p.permission_name),
       CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
FROM core_platform.cp_roles r
CROSS JOIN core_platform.cp_permissions p
WHERE r.id IN ('role-subscribed-app-loandrift-admin', 'role-loandrift-viewer-admin')
  AND r.is_system AND r.is_active AND r.delete_status='NOT_DELETED'
  AND (p.id LIKE 'permission-loandrift-%' OR p.id='permission-currency-get')
  AND (r.id='role-subscribed-app-loandrift-admin' OR p.id ~ '-get($|-)')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;
