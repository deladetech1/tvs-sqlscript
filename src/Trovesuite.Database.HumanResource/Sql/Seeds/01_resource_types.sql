-- =====================================================
-- ZelosHR (Human Resource) RBAC seed — resource types
-- Reference data lives in core_platform (shared across modules).
-- Idempotent: re-run safe via ON CONFLICT. Runs every deploy.
-- Permission->role assignment is handled by the core_platform
-- auto-assign triggers (by resource-type hierarchy), same as loandrift/msg.
-- =====================================================

SET search_path TO core_platform;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-subscribed-app-zeloshr', 'HR APP', 'HR Subscribed APP', null),
('rt-zeloshr-dashboard', 'ZelosHR Dashboard', 'Executive HR dashboard', 'rt-subscribed-app-zeloshr'),
('rt-zeloshr-employee', 'ZelosHR Employee', 'Employee directory and profiles', 'rt-subscribed-app-zeloshr'),
('rt-zeloshr-org', 'ZelosHR Org Structure', 'Org chart and organisation summary', 'rt-subscribed-app-zeloshr'),
('rt-zeloshr-departments', 'ZelosHR Departments', 'Department management', 'rt-subscribed-app-zeloshr'),
('rt-zeloshr-branches', 'ZelosHR Branches', 'Branch management', 'rt-subscribed-app-zeloshr'),
('rt-zeloshr-lifecycle', 'ZelosHR Lifecycle', 'Lifecycle events and workflows', 'rt-subscribed-app-zeloshr'),
('rt-zeloshr-audit', 'ZelosHR Audit', 'Audit logs', 'rt-subscribed-app-zeloshr'),
('rt-zeloshr-attendance', 'ZelosHR Attendance', 'Attendance records', 'rt-subscribed-app-zeloshr'),
('rt-zeloshr-leave', 'ZelosHR Leave', 'Leave requests and balances', 'rt-subscribed-app-zeloshr'),
('rt-zeloshr-recruitment', 'ZelosHR Recruitment', 'Job postings', 'rt-subscribed-app-zeloshr'),
('rt-zeloshr-onboarding', 'ZelosHR Onboarding', 'Onboarding tasks', 'rt-subscribed-app-zeloshr'),
('rt-zeloshr-performance', 'ZelosHR Performance', 'Performance reviews', 'rt-subscribed-app-zeloshr'),
('rt-zeloshr-disciplinary', 'ZelosHR Disciplinary', 'Disciplinary cases', 'rt-subscribed-app-zeloshr'),
('rt-zeloshr-documents', 'ZelosHR Documents', 'Employee document metadata', 'rt-subscribed-app-zeloshr'),
('rt-zeloshr-custom-fields', 'ZelosHR Custom Fields', 'Tenant-defined fields and values', 'rt-subscribed-app-zeloshr')
ON CONFLICT (id) DO UPDATE SET
    resource_type_name = EXCLUDED.resource_type_name,
    description        = EXCLUDED.description,
    parent_resource_id = EXCLUDED.parent_resource_id;
