-- =====================================================
-- Core Platform Database Schema
-- =====================================================

-- CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE SCHEMA IF NOT EXISTS core_platform;

-- Set the search path to core_platform schema for this session
SET search_path TO core_platform;

-- Insert system tenant (required before roles)
INSERT INTO cp_tenants (id, delete_status, is_active, cdate, ctime, cdatetime, description, is_verified, is_system) VALUES
('system-tenant-id', 'NOT_DELETED', true, null, null, CURRENT_TIMESTAMP, 'Default System Tenant', true, true)
ON CONFLICT (id) DO NOTHING;

-- Insert default roles
-- Note: cp_roles now has tenant_id - system roles use 'system-tenant-id'
INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES

-- High Level Role
('role-owner', 'system-tenant-id', 'Owner', 'The Owner of the system, can do anything including full log management', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-admin', 'system-tenant-id', 'Admin', 'The administrator of the system, can do anything except log modification (can view all logs)', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Resource-specific admin roles
('role-organization-admin', 'system-tenant-id', 'Organization Admin', 'Administrator for organization management', 'rt-organization', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-business-admin', 'system-tenant-id', 'Business Admin', 'Administrator for business management', 'rt-business', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-app-admin', 'system-tenant-id', 'App Admin', 'Administrator for application management', 'rt-app', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-location-admin', 'system-tenant-id', 'Location Admin', 'Administrator for location management', 'rt-location', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-user-admin', 'system-tenant-id', 'User Admin', 'Administrator for user management', 'rt-user', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-role-admin', 'system-tenant-id', 'Role Admin', 'Administrator for role management', 'rt-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-permission-admin', 'system-tenant-id', 'Permission Admin', 'Administrator for permission management', 'rt-permission', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-group-admin', 'system-tenant-id', 'Group Admin', 'Administrator for group management', 'rt-group', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-reports-admin', 'system-tenant-id', 'Reports Admin', 'Administrator for reporting system', 'rt-reports', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-attendance-admin', 'system-tenant-id', 'Attendance Admin', 'Administrator for attendance management', 'rt-attendance', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-settings-admin', 'system-tenant-id', 'Settings Admin', 'Administrator for core platform settings management (unit of measure, currency, password policy, MFA settings)', 'rt-setting', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-business-app-admin', 'system-tenant-id', 'Business App Admin', 'Administrator for business app subscription management', 'rt-business-app', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-expense-admin', 'system-tenant-id', 'Expense Admin', 'Administrator for expense management', 'rt-expenses', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-file-admin', 'system-tenant-id', 'File Admin', 'Administrator for file management', 'rt-file', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-billing-admin', 'system-tenant-id', 'Billing Admin', 'Administrator for billing and billing logs management', 'rt-billing', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- System Role for Default User Profile Access (Hidden from users)
('role-default-group', 'system-tenant-id', 'Default Role', 'Default system role for user profile management - allows users to view and update their own details', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Viewer Admin Role (read-only access to all Core Platform resources)
('role-cp-viewer-admin', 'system-tenant-id', 'Core Platform Viewer Admin', 'Viewer Admin for Core Platform - can view all Core Platform resources with GET permissions only', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO NOTHING;