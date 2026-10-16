SET search_path TO core_platform;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id) VALUES
('system-tenant-id', 'role-accounting-admin', 'permission-app-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-business-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-organization-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-accounting-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-accounting-admin', 'permission-user-get-locations'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-organisation-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-organisation-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-organisation-setup'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-accounts-create'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-accounts-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-accounts-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-periods-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-periods-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journals-create'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journals-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journals-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journals-submit'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journals-approve'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journals-reverse'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journals-delete'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-audit-get')
ON CONFLICT DO NOTHING;
