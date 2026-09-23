-- =====================================================
-- Loan Drift Database Schema
-- =====================================================

-- Set the search path to loandrift schema for this session
SET search_path TO core_platform;

-- =====================================================
-- Initial Data
-- =====================================================

-- Insert resource types into core_platform schema (shared across all modules)
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES

('rt-subscribed-app-loandrift', 'Loandrift APP', 'Loandrift Subscribed APP', null),
('rt-capturing', 'Capturing', 'Loandrift Capturing', 'rt-subscribed-app-loandrift'),
('rt-registration', 'Registration', 'Loandrift Registration', 'rt-subscribed-app-loandrift'),
('rt-disbursement', 'Disbursement', 'Disbursement management for Loandrift', 'rt-subscribed-app-loandrift'),
('rt-interest-rate', 'Interest Rate', 'Interest Rate management for Loandrift', 'rt-subscribed-app-loandrift'),
('rt-approval', 'Approval', 'Approval management for Loandrift', 'rt-subscribed-app-loandrift'),
('rt-loan-type', 'Loan Type', 'Loan Type management for Loandrift', 'rt-subscribed-app-loandrift'),
('rt-loan-registration', 'Loan Registration', 'Loan Registration management for Loandrift', 'rt-subscribed-app-loandrift'),
('rt-sector', 'Sector', 'Sector management for Loandrift', 'rt-subscribed-app-loandrift'),
('rt-client', 'Client', 'Client management for Loandrift', 'rt-subscribed-app-loandrift'),
('rt-settings', 'Settings', 'Settings management for Loandrift', 'rt-subscribed-app-loandrift'),
-- LoanDrift's own expenses, not a claim on the Core Platform resource type. rt-expenses
-- belongs to core, and this app and MyStoreGuard both used to re-parent it under themselves,
-- so all three shared one permission set and granting expenses in one app granted it in both.
('rt-loandrift-expenses', 'Expense', 'Expense management for Loandrift', 'rt-subscribed-app-loandrift'),
('rt-calender', 'Calender', 'Calender management for Loandrift', 'rt-subscribed-app-loandrift'),
('rt-repayment', 'Repayment', 'Repayment management for Loandrift', 'rt-subscribed-app-loandrift'),
('rt-file', 'File', 'File management', 'rt-subscribed-app-loandrift'),
('rt-dashboard', 'Dashboard', 'Dashboard management for Loandrift', 'rt-subscribed-app-loandrift'),
('rt-reports', 'Loandrift Reports', 'Centralized reporting and analytics module for Loandrift', 'rt-subscribed-app-loandrift')
ON CONFLICT (id) DO UPDATE SET
    resource_type_name = EXCLUDED.resource_type_name,
    description        = EXCLUDED.description,
    parent_resource_id = EXCLUDED.parent_resource_id;
-- =====================================================
-- Savings & Investment resource types
-- =====================================================
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-savings', 'Savings', 'Savings account management for Loandrift', 'rt-subscribed-app-loandrift'),
('rt-investment', 'Investment', 'Investment management for Loandrift', 'rt-subscribed-app-loandrift')
ON CONFLICT (id) DO UPDATE SET
    resource_type_name = EXCLUDED.resource_type_name,
    description        = EXCLUDED.description,
    parent_resource_id = EXCLUDED.parent_resource_id;

-- =====================================================
-- Credit scoring resource type
-- =====================================================
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-credit-score', 'Credit Score', 'Credit scoring and score settings for Loandrift', 'rt-subscribed-app-loandrift')
ON CONFLICT (id) DO UPDATE SET
    resource_type_name = EXCLUDED.resource_type_name,
    description        = EXCLUDED.description,
    parent_resource_id = EXCLUDED.parent_resource_id;

-- =====================================================
-- Loan penalty resource type
-- =====================================================
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-penalty', 'Penalty', 'Loan penalty ledger, waivers and penalty settings for Loandrift', 'rt-subscribed-app-loandrift')
ON CONFLICT (id) DO UPDATE SET
    resource_type_name = EXCLUDED.resource_type_name,
    description        = EXCLUDED.description,
    parent_resource_id = EXCLUDED.parent_resource_id;

-- Accounting belongs to LoanDrift, independently of other applications.
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id)
VALUES ('rt-loandrift-accounting', 'LoanDrift Accounting', 'Accounts, journals, fixed assets and accounting reports', 'rt-subscribed-app-loandrift')
ON CONFLICT (id) DO UPDATE SET resource_type_name=EXCLUDED.resource_type_name, description=EXCLUDED.description, parent_resource_id=EXCLUDED.parent_resource_id;

-- =====================================================
-- Job roles
-- =====================================================
-- The resource type the named job roles (Loan Officer, Cashier, Credit Manager …)
-- hang off. Deliberately owns no permissions of its own: the role-insert and
-- permission-insert triggers in core_platform grant a role every permission of its
-- resource type and of that type's children, which is exactly wrong for a job role
-- whose whole point is a hand-picked set. With nothing parented here and no
-- permission pointing at it, neither trigger can find anything to hand out, so the
-- grants in 04_others.sql stay the only source. Parented under the app so the type
-- still reads as LoanDrift's.
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id)
VALUES ('rt-loandrift-job-roles', 'LoanDrift Job Roles', 'Grouping for LoanDrift''s named job roles; holds no permissions itself', 'rt-subscribed-app-loandrift')
ON CONFLICT (id) DO UPDATE SET
    resource_type_name = EXCLUDED.resource_type_name,
    description        = EXCLUDED.description,
    parent_resource_id = EXCLUDED.parent_resource_id;
