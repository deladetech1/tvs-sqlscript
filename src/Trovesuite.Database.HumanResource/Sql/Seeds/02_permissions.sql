SET search_path TO core_platform;

INSERT INTO cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime) VALUES
('permission-zeloshr-dashboard-get', 'ZelosHR Dashboard Get', 'rt-zeloshr-dashboard', 'Can view dashboard summary and KPIs', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-employee-get', 'ZelosHR Employee Get', 'rt-zeloshr-employee', 'Can list and read employees and directory', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-employee-create', 'ZelosHR Employee Create', 'rt-zeloshr-employee', 'Can create employee records', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-employee-update', 'ZelosHR Employee Update', 'rt-zeloshr-employee', 'Can update employee records', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-org-get', 'ZelosHR Org Get', 'rt-zeloshr-org', 'Can view departments, branches, and org chart', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-org-manage', 'ZelosHR Org Manage', 'rt-zeloshr-org', 'Can create and update org structure', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-lifecycle-get', 'ZelosHR Lifecycle Get', 'rt-zeloshr-lifecycle', 'Can list lifecycle events', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-lifecycle-manage', 'ZelosHR Lifecycle Manage', 'rt-zeloshr-lifecycle', 'Can create and update lifecycle events', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-audit-get', 'ZelosHR Audit Get', 'rt-zeloshr-audit', 'Can list and read audit logs', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-attendance-get', 'ZelosHR Attendance Get', 'rt-zeloshr-attendance', 'Can list attendance records', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-attendance-manage', 'ZelosHR Attendance Manage', 'rt-zeloshr-attendance', 'Can record and update attendance', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-leave-get', 'ZelosHR Leave Get', 'rt-zeloshr-leave', 'Can list leave requests and balances', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-leave-manage', 'ZelosHR Leave Manage', 'rt-zeloshr-leave', 'Can submit and approve leave', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-recruitment-get', 'ZelosHR Recruitment Get', 'rt-zeloshr-recruitment', 'Can list job postings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-recruitment-manage', 'ZelosHR Recruitment Manage', 'rt-zeloshr-recruitment', 'Can create and update job postings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-onboarding-get', 'ZelosHR Onboarding Get', 'rt-zeloshr-onboarding', 'Can list onboarding tasks', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-onboarding-manage', 'ZelosHR Onboarding Manage', 'rt-zeloshr-onboarding', 'Can assign and complete onboarding tasks', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-performance-get', 'ZelosHR Performance Get', 'rt-zeloshr-performance', 'Can list performance reviews', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-performance-manage', 'ZelosHR Performance Manage', 'rt-zeloshr-performance', 'Can create and complete performance reviews', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-disciplinary-get', 'ZelosHR Disciplinary Get', 'rt-zeloshr-disciplinary', 'Can list disciplinary cases', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-disciplinary-manage', 'ZelosHR Disciplinary Manage', 'rt-zeloshr-disciplinary', 'Can open and update disciplinary cases', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-documents-get', 'ZelosHR Documents Get', 'rt-zeloshr-documents', 'Can list employee documents', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-documents-manage', 'ZelosHR Documents Manage', 'rt-zeloshr-documents', 'Can upload and update document metadata', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET
    permission_name   = EXCLUDED.permission_name,
    resource_type_id  = EXCLUDED.resource_type_id,
    description       = EXCLUDED.description;
