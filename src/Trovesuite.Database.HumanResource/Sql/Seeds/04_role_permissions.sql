-- =====================================================
-- Human Resources Database Schema
-- =====================================================

CREATE SCHEMA IF NOT EXISTS human_resource;
SET search_path TO human_resource;

-- =====================================================
-- Bind every HR permission to the HR Admin role
-- (role-subscribed-app-hr-admin was created in 03_roles.sql)
-- =====================================================

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', 'role-subscribed-app-hr-admin', p.permission_id
FROM (VALUES
    ('permission-hr-employees-create'),
    ('permission-hr-employees-get'),
    ('permission-hr-employees-update'),
    ('permission-hr-employees-delete'),
    ('permission-hr-employees-reveal-sensitive'),
    ('permission-hr-employees-manage-salary'),
    ('permission-hr-departments-manage'),
    ('permission-hr-banks-manage'),
    ('permission-hr-pension-providers-manage'),
    ('permission-hr-file-upload')
) AS p(permission_id)
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;
