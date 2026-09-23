SET search_path TO core_platform;

INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime) VALUES
('permission-attendance-records-create', 'Attendance Records Create', 'rt-attendance-records', 'Record attendance', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-attendance-records-get', 'Attendance Records Get', 'rt-attendance-records', 'List and read attendance', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-attendance-records-update', 'Attendance Records Update', 'rt-attendance-records', 'Update attendance', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-attendance-records-delete', 'Attendance Records Delete', 'rt-attendance-records', 'Delete attendance', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-attendance-employees-create', 'Attendance Employees Create', 'rt-attendance-employees', 'Add roster employees', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-attendance-employees-get', 'Attendance Employees Get', 'rt-attendance-employees', 'List roster employees', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-attendance-employees-update', 'Attendance Employees Update', 'rt-attendance-employees', 'Update roster employees', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-attendance-employees-delete', 'Attendance Employees Delete', 'rt-attendance-employees', 'Remove roster employees', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-attendance-clock-create', 'Attendance Clock Create', 'rt-attendance-clock', 'Clock in and clock out', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-attendance-clock-get', 'Attendance Clock Get', 'rt-attendance-clock', 'Read today clock state', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-attendance-timesheet-get', 'Attendance Timesheet Get', 'rt-attendance-timesheet', 'Read personal timesheet', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-attendance-team-get', 'Attendance Team Get', 'rt-attendance-team', 'Read team attendance', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-attendance-adjustments-create', 'Attendance Adjustments Create', 'rt-attendance-adjustments', 'Add punch adjustments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-attendance-adjustments-get', 'Attendance Adjustments Get', 'rt-attendance-adjustments', 'List punch adjustments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-attendance-devices-create', 'Attendance Devices Create', 'rt-attendance-devices', 'Register devices', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-attendance-devices-get', 'Attendance Devices Get', 'rt-attendance-devices', 'List devices', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-attendance-devices-delete', 'Attendance Devices Delete', 'rt-attendance-devices', 'Remove devices', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET
    permission_name  = EXCLUDED.permission_name,
    resource_type_id = EXCLUDED.resource_type_id,
    description      = EXCLUDED.description;
