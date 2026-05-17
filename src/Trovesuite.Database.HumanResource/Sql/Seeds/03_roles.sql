-- =====================================================
-- Human Resources Database Schema
-- =====================================================

-- CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE SCHEMA IF NOT EXISTS human_resource;

-- Set the search path to human_resource schema for this session
SET search_path TO human_resource;

-- Insert default role
INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-subscribed-app-hr-admin', 'system-tenant-id', 'HR Admin', 'The administrator of the Human Resources system, can manage all operations including log management', 'rt-subscribed-app-hr', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET
    role_name        = EXCLUDED.role_name,
    description      = EXCLUDED.description,
    resource_type_id = EXCLUDED.resource_type_id,
    is_system        = EXCLUDED.is_system,
    is_active        = EXCLUDED.is_active;