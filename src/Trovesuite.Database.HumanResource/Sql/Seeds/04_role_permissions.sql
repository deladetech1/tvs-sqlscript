-- =====================================================
-- Human Resources Database Schema
-- =====================================================

CREATE SCHEMA IF NOT EXISTS human_resource;
SET search_path TO human_resource;

-- =====================================================
-- Bind all HR + ZelosHR permissions to the HR Admin role.
-- New permissions are also auto-assigned via core_platform triggers when inserted.
-- =====================================================

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', 'role-subscribed-app-hr-admin', p.id
FROM core_platform.cp_permissions p
WHERE p.id LIKE 'permission-hr-%'
   OR p.id LIKE 'permission-zeloshr-%'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;
