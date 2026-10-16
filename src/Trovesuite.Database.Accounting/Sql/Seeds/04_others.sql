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
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-account-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-account-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-account-add'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-account-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-fiscal-period-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-fiscal-period-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journal-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journal-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journal-add'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journal-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journal-post'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journal-approve'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journal-reverse'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journal-delete'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-report-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-audit-get')
ON CONFLICT DO NOTHING;
