-- =====================================================
-- ZelosHR (Human Resource) RBAC seed — roles
-- Reference data lives in core_platform (shared across modules).
-- Idempotent: re-run safe via ON CONFLICT. Runs every deploy.
-- Permission->role assignment is handled by the core_platform
-- auto-assign triggers (by resource-type hierarchy), same as loandrift/msg.
-- =====================================================

SET search_path TO core_platform;

INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-subscribed-app-zeloshr-admin', 'system-tenant-id', 'HR Admin', 'Administrator of the Human Resources system', 'rt-subscribed-app-zeloshr', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-zeloshr-dashboard-admin', 'system-tenant-id', 'ZelosHR Dashboard Admin', 'Administrator for HR dashboard', 'rt-zeloshr-dashboard', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-zeloshr-employee-admin', 'system-tenant-id', 'ZelosHR Employee Admin', 'Administrator for employee management', 'rt-zeloshr-employee', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-zeloshr-org-admin', 'system-tenant-id', 'ZelosHR Org Admin', 'Administrator for org chart and summary', 'rt-zeloshr-org', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-zeloshr-departments-admin', 'system-tenant-id', 'ZelosHR Departments Admin', 'Administrator for departments', 'rt-zeloshr-departments', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-zeloshr-branches-admin', 'system-tenant-id', 'ZelosHR Branches Admin', 'Administrator for branches', 'rt-zeloshr-branches', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-zeloshr-lifecycle-admin', 'system-tenant-id', 'ZelosHR Lifecycle Admin', 'Administrator for lifecycle events', 'rt-zeloshr-lifecycle', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-zeloshr-audit-admin', 'system-tenant-id', 'ZelosHR Audit Admin', 'Administrator for audit logs', 'rt-zeloshr-audit', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-zeloshr-attendance-admin', 'system-tenant-id', 'ZelosHR Attendance Admin', 'Administrator for attendance', 'rt-zeloshr-attendance', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-zeloshr-leave-admin', 'system-tenant-id', 'ZelosHR Leave Admin', 'Administrator for leave', 'rt-zeloshr-leave', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-zeloshr-recruitment-admin', 'system-tenant-id', 'ZelosHR Recruitment Admin', 'Administrator for recruitment', 'rt-zeloshr-recruitment', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-zeloshr-onboarding-admin', 'system-tenant-id', 'ZelosHR Onboarding Admin', 'Administrator for onboarding', 'rt-zeloshr-onboarding', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-zeloshr-performance-admin', 'system-tenant-id', 'ZelosHR Performance Admin', 'Administrator for performance reviews', 'rt-zeloshr-performance', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-zeloshr-disciplinary-admin', 'system-tenant-id', 'ZelosHR Disciplinary Admin', 'Administrator for disciplinary cases', 'rt-zeloshr-disciplinary', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-zeloshr-documents-admin', 'system-tenant-id', 'ZelosHR Documents Admin', 'Administrator for employee documents', 'rt-zeloshr-documents', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-zeloshr-custom-fields-admin', 'system-tenant-id', 'ZelosHR Custom Fields Admin', 'Administrator for custom fields', 'rt-zeloshr-custom-fields', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET
    role_name        = EXCLUDED.role_name,
    description      = EXCLUDED.description,
    resource_type_id = EXCLUDED.resource_type_id,
    is_system        = EXCLUDED.is_system,
    is_active        = EXCLUDED.is_active;
