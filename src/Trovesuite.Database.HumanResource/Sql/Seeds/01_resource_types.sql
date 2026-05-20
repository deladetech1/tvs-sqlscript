SET search_path TO core_platform;

INSERT INTO cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-subscribed-app-hr', 'HR APP', 'ZelosHR subscribed application', null),
('rt-zeloshr-dashboard', 'ZelosHR Dashboard', 'Executive HR dashboard', 'rt-subscribed-app-hr'),
('rt-zeloshr-employee', 'ZelosHR Employee', 'Employee directory and profiles', 'rt-subscribed-app-hr'),
('rt-zeloshr-org', 'ZelosHR Org Structure', 'Departments, branches, org chart', 'rt-subscribed-app-hr'),
('rt-zeloshr-lifecycle', 'ZelosHR Lifecycle', 'Lifecycle events and workflows', 'rt-subscribed-app-hr'),
('rt-zeloshr-audit', 'ZelosHR Audit', 'Audit logs', 'rt-subscribed-app-hr'),
('rt-zeloshr-attendance', 'ZelosHR Attendance', 'Attendance records', 'rt-subscribed-app-hr'),
('rt-zeloshr-leave', 'ZelosHR Leave', 'Leave requests and balances', 'rt-subscribed-app-hr'),
('rt-zeloshr-recruitment', 'ZelosHR Recruitment', 'Job postings', 'rt-subscribed-app-hr'),
('rt-zeloshr-onboarding', 'ZelosHR Onboarding', 'Onboarding tasks', 'rt-subscribed-app-hr'),
('rt-zeloshr-performance', 'ZelosHR Performance', 'Performance reviews', 'rt-subscribed-app-hr'),
('rt-zeloshr-disciplinary', 'ZelosHR Disciplinary', 'Disciplinary cases', 'rt-subscribed-app-hr'),
('rt-zeloshr-documents', 'ZelosHR Documents', 'Employee document metadata', 'rt-subscribed-app-hr')
ON CONFLICT (id) DO UPDATE SET
    resource_type_name = EXCLUDED.resource_type_name,
    description        = EXCLUDED.description,
    parent_resource_id = EXCLUDED.parent_resource_id;
