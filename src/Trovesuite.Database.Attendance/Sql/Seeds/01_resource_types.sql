SET search_path TO core_platform;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-subscribed-app-attendance', 'Attendance APP', 'Attendance Subscribed APP', null),
('rt-attendance-records', 'Attendance Records', 'Daily attendance records', 'rt-subscribed-app-attendance'),
('rt-attendance-employees', 'Attendance Employees', 'Employee roster for attendance', 'rt-subscribed-app-attendance'),
('rt-attendance-clock', 'Attendance Clock', 'Clock in and clock out', 'rt-subscribed-app-attendance'),
('rt-attendance-timesheet', 'Attendance Timesheet', 'Personal timesheet', 'rt-subscribed-app-attendance'),
('rt-attendance-team', 'Attendance Team', 'Line manager and HoD team views', 'rt-subscribed-app-attendance'),
('rt-attendance-adjustments', 'Attendance Adjustments', 'Manual punch adjustments', 'rt-subscribed-app-attendance'),
('rt-attendance-devices', 'Attendance Devices', 'Time-clock devices', 'rt-subscribed-app-attendance')
ON CONFLICT (id) DO UPDATE SET
    resource_type_name = EXCLUDED.resource_type_name,
    description        = EXCLUDED.description,
    parent_resource_id = EXCLUDED.parent_resource_id;
