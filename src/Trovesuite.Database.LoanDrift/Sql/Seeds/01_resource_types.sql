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
('rt-expenses', 'Expense', 'Expense management for Loandrift', 'rt-subscribed-app-loandrift'),
('rt-calender', 'Calender', 'Calender management for Loandrift', 'rt-subscribed-app-loandrift'),
('rt-repayment', 'Repayment', 'Repayment management for Loandrift', 'rt-subscribed-app-loandrift'),
('rt-file', 'File', 'File management', 'rt-subscribed-app-loandrift'),
('rt-dashboard', 'Dashboard', 'Dashboard management for Loandrift', 'rt-subscribed-app-loandrift'),
('rt-reports', 'Loandrift Reports', 'Centralized reporting and analytics module for Loandrift', 'rt-subscribed-app-loandrift')
ON CONFLICT (id) DO UPDATE SET
    resource_type_name = EXCLUDED.resource_type_name,
    description        = EXCLUDED.description,
    parent_resource_id = EXCLUDED.parent_resource_id;