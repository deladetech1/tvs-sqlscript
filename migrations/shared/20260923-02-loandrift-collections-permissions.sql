-- Permissions for the collections module and the two-step disbursement.
-- Safe to rerun.

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id)
VALUES ('rt-loandrift-collections', 'LoanDrift Collections',
        'Arrears worklist, contact attempts, promises to pay and their outcomes',
        'rt-subscribed-app-loandrift')
ON CONFLICT (id) DO UPDATE SET resource_type_name=EXCLUDED.resource_type_name,
    description=EXCLUDED.description, parent_resource_id=EXCLUDED.parent_resource_id;

INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime) VALUES
('permission-loandrift-collections-get', 'Loandrift Collections Get', 'rt-loandrift-collections',
 'Can see the arrears worklist and the history of contact attempts', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-collections-create', 'Loandrift Collections Create', 'rt-loandrift-collections',
 'Can log a call, visit, promise to pay or other contact attempt', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-collections-update', 'Loandrift Collections Update', 'rt-loandrift-collections',
 'Can correct a logged activity and settle a promise as kept, broken or cancelled', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-collections-delete', 'Loandrift Collections Delete', 'rt-loandrift-collections',
 'Can remove a logged activity', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET permission_name=EXCLUDED.permission_name,
    resource_type_id=EXCLUDED.resource_type_id, description=EXCLUDED.description;

-- disbursement-update already existed but nothing checked it. It is now the
-- prepare step: stage a payment for someone else to authorise. The release
-- stays on disbursement-disburse, so the two cannot be the same person.
UPDATE core_platform.cp_permissions
   SET description = 'Can prepare a disbursement for authorisation; releasing the money needs the disburse permission'
 WHERE id = 'permission-loandrift-disbursement-update';
UPDATE core_platform.cp_permissions
   SET description = 'Can authorise and release a prepared disbursement'
 WHERE id = 'permission-loandrift-disbursement-disburse';

INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime)
VALUES ('role-loandrift-collections-admin', 'system-tenant-id', 'Loandrift Collections Admin',
        'Work the arrears book: log contact attempts and settle promises to pay',
        'rt-loandrift-collections', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name=EXCLUDED.role_name, description=EXCLUDED.description,
    resource_type_id=EXCLUDED.resource_type_id;

-- Grant the new permissions to the roles that already carry app-wide access,
-- matching how the accounting catalogue was reconciled. Custom roles, explicit
-- denials and viewer-only roles are left alone.
-- role-owner and role-subscribed-app-loandrift-admin are deliberately absent from the
-- grant below. Both are allowed by being the role (tvs-package 1.0.42 / 1.0.43), and
-- listing them meant every deploy quietly re-granted rows that 20260929-03 removes --
-- which is how Owner drifted back from 0 to 29 rows overnight.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT r.tenant_id, r.id, p.id, r.role_name || ' can ' || lower(p.permission_name),
       CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
FROM core_platform.cp_roles r
JOIN core_platform.cp_permissions p ON p.id IN (
  'permission-loandrift-collections-get', 'permission-loandrift-collections-create',
  'permission-loandrift-collections-update', 'permission-loandrift-collections-delete')
WHERE r.is_system = true
  AND r.id IN ('role-admin', 'role-loandrift-collections-admin')
ON CONFLICT DO NOTHING;

-- A viewer sees the worklist and the history, and logs nothing.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT r.tenant_id, r.id, 'permission-loandrift-collections-get',
       r.role_name || ' can read collections', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
FROM core_platform.cp_roles r
WHERE r.is_system = true AND r.id = 'role-loandrift-viewer-admin'
ON CONFLICT DO NOTHING;
