SET search_path TO core_platform;

INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_active, is_system, cdate, ctime, cdatetime) VALUES
('role-attendance-admin', 'system-tenant-id', 'Attendance Admin', 'Administrator for Attendance app', 'rt-subscribed-app-attendance', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-attendance-records-admin', 'system-tenant-id', 'Attendance Records Admin', 'Administrator for attendance records', 'rt-attendance-records', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-attendance-employees-admin', 'system-tenant-id', 'Attendance Employees Admin', 'Administrator for attendance employee roster', 'rt-attendance-employees', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-attendance-clock-admin', 'system-tenant-id', 'Attendance Clock Admin', 'Clock in and out', 'rt-attendance-clock', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-attendance-timesheet-admin', 'system-tenant-id', 'Attendance Timesheet Admin', 'Personal timesheet', 'rt-attendance-timesheet', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-attendance-team-admin', 'system-tenant-id', 'Attendance Team Admin', 'Team attendance views', 'rt-attendance-team', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-attendance-adjustments-admin', 'system-tenant-id', 'Attendance Adjustments Admin', 'Punch adjustments', 'rt-attendance-adjustments', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-attendance-devices-admin', 'system-tenant-id', 'Attendance Devices Admin', 'Time-clock devices', 'rt-attendance-devices', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET
    role_name        = EXCLUDED.role_name,
    description      = EXCLUDED.description,
    resource_type_id = EXCLUDED.resource_type_id,
    is_active        = EXCLUDED.is_active,
    is_system        = EXCLUDED.is_system;
