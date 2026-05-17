-- =====================================================
-- Core Platform Database Schema
-- =====================================================

-- CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE SCHEMA IF NOT EXISTS core_platform;

-- Set the search path to core_platform schema for this session
SET search_path TO core_platform;

-- =====================================================
-- Initial Data
-- =====================================================

-- Insert resource types
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-all', 'ALL', 'System-wide resource access', null),
('rt-default', 'Default', 'Default system roles and permissions', null),
('rt-system-role', 'System Role', 'System-level roles (Owner, Admin)', 'rt-default'),
('rt-organization', 'Organizaation', 'Organization management', null),
('rt-business', 'Business', 'Business management', null),
('rt-business-app', 'Business Apps', 'Business App', null),
('rt-app', 'APP', 'App', null),
('rt-location', 'Location', 'Location management', null),
('rt-user', 'User', 'User management', null),
('rt-role', 'Role', 'Role management', null),
('rt-permission', 'Permission', 'Permission management', null),
('rt-group', 'Group', 'Group management', null),
('rt-reports', 'Reports', 'Reporting system', null),
('rt-logs', 'Logs', 'Logs management', null),
('rt-subscription', 'Subscription', 'Subscription management', null),
('rt-attendance', 'Attendance', 'Attendance management', null),
('rt-setting', 'Settings', 'Core platform settings management (includes unit of measure, currency, password policy, MFA settings)', null),
('rt-theme', 'Theme', 'THEME management', null),
('rt-expenses', 'Expense', 'Expense management', null),
('rt-file', 'File', 'File management', null),
('rt-billing', 'Billing', 'Billing and billing logs management', null)
ON CONFLICT (id) DO UPDATE SET
    resource_type_name = EXCLUDED.resource_type_name,
    description        = EXCLUDED.description,
    parent_resource_id = EXCLUDED.parent_resource_id;