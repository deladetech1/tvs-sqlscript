SET search_path TO core_platform;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id) VALUES
('system-tenant-id', 'role-attendance-admin', 'permission-app-get'),
('system-tenant-id', 'role-attendance-admin', 'permission-business-get'),
('system-tenant-id', 'role-attendance-admin', 'permission-organization-get'),
('system-tenant-id', 'role-attendance-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-attendance-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-attendance-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-attendance-admin', 'permission-user-get-locations'),
('system-tenant-id', 'role-attendance-admin', 'permission-attendance-records-create'),
('system-tenant-id', 'role-attendance-admin', 'permission-attendance-records-get'),
('system-tenant-id', 'role-attendance-admin', 'permission-attendance-records-update'),
('system-tenant-id', 'role-attendance-admin', 'permission-attendance-records-delete'),
('system-tenant-id', 'role-attendance-admin', 'permission-attendance-employees-create'),
('system-tenant-id', 'role-attendance-admin', 'permission-attendance-employees-get'),
('system-tenant-id', 'role-attendance-admin', 'permission-attendance-employees-update'),
('system-tenant-id', 'role-attendance-admin', 'permission-attendance-employees-delete'),
('system-tenant-id', 'role-attendance-admin', 'permission-attendance-clock-create'),
('system-tenant-id', 'role-attendance-admin', 'permission-attendance-clock-get'),
('system-tenant-id', 'role-attendance-admin', 'permission-attendance-timesheet-get'),
('system-tenant-id', 'role-attendance-admin', 'permission-attendance-team-get'),
('system-tenant-id', 'role-attendance-admin', 'permission-attendance-adjustments-create'),
('system-tenant-id', 'role-attendance-admin', 'permission-attendance-adjustments-get'),
('system-tenant-id', 'role-attendance-admin', 'permission-attendance-devices-create'),
('system-tenant-id', 'role-attendance-admin', 'permission-attendance-devices-get'),
('system-tenant-id', 'role-attendance-admin', 'permission-attendance-devices-delete')
ON CONFLICT DO NOTHING;
