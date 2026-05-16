-- =====================================================
-- Loan Drift Database Schema
-- =====================================================

-- CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE SCHEMA IF NOT EXISTS loandrift;

-- Set the search path to loandrift schema for this session
SET search_path TO loandrift;

-- =============================================
-- ROLE-PERMISSION MAPPINGS
-- =============================================

-- =============================================
-- CORE PLATFORM PERMISSIONS FOR ALL LOANDRIFT ROLES
-- These permissions are required for navigation: apps, businesses, organizations, subscribed apps, and app deployment management
-- =============================================

-- All Loandrift roles need these core platform permissions to navigate the system
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id) VALUES
-- Core platform navigation permissions for all roles
('system-tenant-id', 'role-subscribed-app-loandrift-admin', 'permission-app-get'),
('system-tenant-id', 'role-subscribed-app-loandrift-admin', 'permission-business-get'),
('system-tenant-id', 'role-subscribed-app-loandrift-admin', 'permission-organization-get'),
('system-tenant-id', 'role-subscribed-app-loandrift-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-subscribed-app-loandrift-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-subscribed-app-loandrift-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-subscribed-app-loandrift-admin', 'permission-user-get-locations'),

-- Loandrift Admin: explicit permissions for Reports, Logs, and Expenses (resource types have parent null in DB, so trigger does not assign these)
('system-tenant-id', 'role-subscribed-app-loandrift-admin', 'permission-loandrift-reports-get'),
('system-tenant-id', 'role-subscribed-app-loandrift-admin', 'permission-loandrift-logs-get'),
('system-tenant-id', 'role-subscribed-app-loandrift-admin', 'permission-loandrift-logs-delete'),
('system-tenant-id', 'role-subscribed-app-loandrift-admin', 'permission-expense-create'),
('system-tenant-id', 'role-subscribed-app-loandrift-admin', 'permission-expense-get'),
('system-tenant-id', 'role-subscribed-app-loandrift-admin', 'permission-expense-update'),
('system-tenant-id', 'role-subscribed-app-loandrift-admin', 'permission-expense-delete'),
('system-tenant-id', 'role-subscribed-app-loandrift-admin', 'permission-expense-get-statistics'),

('system-tenant-id', 'role-loandrift-approval-admin', 'permission-app-get'),
('system-tenant-id', 'role-loandrift-approval-admin', 'permission-business-get'),
('system-tenant-id', 'role-loandrift-approval-admin', 'permission-organization-get'),
('system-tenant-id', 'role-loandrift-approval-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-loandrift-approval-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-loandrift-approval-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-loandrift-approval-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-loandrift-calender-admin', 'permission-app-get'),
('system-tenant-id', 'role-loandrift-calender-admin', 'permission-business-get'),
('system-tenant-id', 'role-loandrift-calender-admin', 'permission-organization-get'),
('system-tenant-id', 'role-loandrift-calender-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-loandrift-calender-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-loandrift-calender-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-loandrift-calender-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-loandrift-capturing-admin', 'permission-app-get'),
('system-tenant-id', 'role-loandrift-capturing-admin', 'permission-business-get'),
('system-tenant-id', 'role-loandrift-capturing-admin', 'permission-organization-get'),
('system-tenant-id', 'role-loandrift-capturing-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-loandrift-capturing-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-loandrift-capturing-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-loandrift-capturing-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-loandrift-disbursement-admin', 'permission-app-get'),
('system-tenant-id', 'role-loandrift-disbursement-admin', 'permission-business-get'),
('system-tenant-id', 'role-loandrift-disbursement-admin', 'permission-organization-get'),
('system-tenant-id', 'role-loandrift-disbursement-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-loandrift-disbursement-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-loandrift-disbursement-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-loandrift-disbursement-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-loandrift-settings-admin', 'permission-app-get'),
('system-tenant-id', 'role-loandrift-settings-admin', 'permission-business-get'),
('system-tenant-id', 'role-loandrift-settings-admin', 'permission-organization-get'),
('system-tenant-id', 'role-loandrift-settings-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-loandrift-settings-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-loandrift-settings-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-loandrift-settings-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-loandrift-expense-admin', 'permission-app-get'),
('system-tenant-id', 'role-loandrift-expense-admin', 'permission-business-get'),
('system-tenant-id', 'role-loandrift-expense-admin', 'permission-organization-get'),
('system-tenant-id', 'role-loandrift-expense-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-loandrift-expense-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-loandrift-expense-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-loandrift-expense-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-loandrift-repayment-admin', 'permission-app-get'),
('system-tenant-id', 'role-loandrift-repayment-admin', 'permission-business-get'),
('system-tenant-id', 'role-loandrift-repayment-admin', 'permission-organization-get'),
('system-tenant-id', 'role-loandrift-repayment-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-loandrift-repayment-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-loandrift-repayment-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-loandrift-repayment-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-loandrift-client-admin', 'permission-app-get'),
('system-tenant-id', 'role-loandrift-client-admin', 'permission-business-get'),
('system-tenant-id', 'role-loandrift-client-admin', 'permission-organization-get'),
('system-tenant-id', 'role-loandrift-client-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-loandrift-client-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-loandrift-client-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-loandrift-client-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-loandrift-loan-registration-admin', 'permission-app-get'),
('system-tenant-id', 'role-loandrift-loan-registration-admin', 'permission-business-get'),
('system-tenant-id', 'role-loandrift-loan-registration-admin', 'permission-organization-get'),
('system-tenant-id', 'role-loandrift-loan-registration-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-loandrift-loan-registration-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-loandrift-loan-registration-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-loandrift-loan-registration-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-loandrift-file-admin', 'permission-app-get'),
('system-tenant-id', 'role-loandrift-file-admin', 'permission-business-get'),
('system-tenant-id', 'role-loandrift-file-admin', 'permission-organization-get'),
('system-tenant-id', 'role-loandrift-file-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-loandrift-file-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-loandrift-file-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-loandrift-file-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-loandrift-dashboard-admin', 'permission-app-get'),
('system-tenant-id', 'role-loandrift-dashboard-admin', 'permission-business-get'),
('system-tenant-id', 'role-loandrift-dashboard-admin', 'permission-organization-get'),
('system-tenant-id', 'role-loandrift-dashboard-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-loandrift-dashboard-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-loandrift-dashboard-admin', 'permission-business-app-get-locations'),

('system-tenant-id', 'role-loandrift-reports-admin', 'permission-app-get'),
('system-tenant-id', 'role-loandrift-reports-admin', 'permission-business-get'),
('system-tenant-id', 'role-loandrift-reports-admin', 'permission-organization-get'),
('system-tenant-id', 'role-loandrift-reports-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-loandrift-reports-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-loandrift-reports-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-loandrift-reports-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-loandrift-viewer-admin', 'permission-app-get'),
('system-tenant-id', 'role-loandrift-viewer-admin', 'permission-business-get'),
('system-tenant-id', 'role-loandrift-viewer-admin', 'permission-organization-get'),
('system-tenant-id', 'role-loandrift-viewer-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-loandrift-viewer-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-loandrift-viewer-admin', 'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =============================================
-- SECTORS
-- =============================================
INSERT INTO ld_sectors (id, tenant_id, sector_name, description, is_active, is_system)
VALUES
    ('sec-agri-forest', 'system-tenant-id', 'Agriculture Forest', 'Agriculture and forestry sector', true, true),
    ('sec-agri-fish', 'system-tenant-id', 'Agriculture Fishing', 'Agriculture and fishing sector', true, true),
    ('sec-mining', 'system-tenant-id', 'Mining and Quarrying', 'Mining and quarrying sector', true, true),
    ('sec-manuf', 'system-tenant-id', 'Manufacturing', 'Manufacturing sector', true, true),
    ('sec-const', 'system-tenant-id', 'Construction', 'Construction sector', true, true)
ON CONFLICT (id) DO NOTHING;

-- =============================================
-- LOAN TYPES
-- =============================================
INSERT INTO ld_loan_types (id, tenant_id, type_name, description, is_active, is_system)
VALUES
    ('lt-daily', 'system-tenant-id', 'Daily Loans', 'Loans with daily repayment schedule', true, true),
    ('lt-salary', 'system-tenant-id', 'Salary Loans', 'Loans tied to salary payments', true, true),
    ('lt-weekly', 'system-tenant-id', 'Weekly Loans', 'Loans with weekly repayment schedule', true, true),
    ('lt-staff', 'system-tenant-id', 'Staff Loans', 'Loans for staff members', true, true),
    ('lt-monthly', 'system-tenant-id', 'Monthly Loans', 'Loans with monthly repayment schedule', true, true)
ON CONFLICT (id) DO NOTHING;

-- =============================================
-- INTEREST TYPES
-- =============================================
INSERT INTO ld_interest_types (id, tenant_id, interest_type_name, description, is_active, is_system)
VALUES
    ('it-fix', 'system-tenant-id', 'Fixed', 'Fixed interest rate', true, true),
    ('it-flat', 'system-tenant-id', 'Flat Rate', 'Flat rate interest calculation', true, true),
    ('it-reducing', 'system-tenant-id', 'Reducing Balance', 'Interest calculated on reducing balance', true, true),
    ('it-direct', 'system-tenant-id', 'Direct Rate', 'Direct rate interest calculation', true, true),
    ('it-reducing-fixed', 'system-tenant-id', 'Reducing Balance Fixed Payment', 'Reducing balance with fixed payment schedule', true, true)
ON CONFLICT (id) DO NOTHING;
