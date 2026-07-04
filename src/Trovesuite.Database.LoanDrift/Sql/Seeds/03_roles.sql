-- =====================================================
-- Loan Drift Database Schema
-- =====================================================

-- Set the search path to loandrift schema for this session
SET search_path TO core_platform;

-- Insert default role into core_platform schema (shared across all modules)
INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-subscribed-app-loandrift-admin', 'system-tenant-id', 'Loandrift Admin', 'The administrator of the Loan Management system, can manage all operations including loan management', 'rt-subscribed-app-loandrift', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-approval-admin', 'system-tenant-id', 'Loandrift Approval Admin', 'Administrator for Approval', 'rt-approval', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-calender-admin', 'system-tenant-id', 'Loandrift Calender Admin', 'Administrator for Calender', 'rt-calender', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-capturing-admin', 'system-tenant-id', 'Loandrift Capturing Admin', 'Loandrift Capturing Admin can manage all aspects of capturing a loan', 'rt-capturing', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-disbursement-admin', 'system-tenant-id', 'Loandrift Disbursement Admin', 'Administrator for Disbursement', 'rt-disbursement', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-settings-admin', 'system-tenant-id', 'Loandrift Settings Admin', 'Administrator for Settings', 'rt-settings', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-expense-admin', 'system-tenant-id', 'Loandrift Expense Admin', 'Administrator for Expense', 'rt-expenses', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-repayment-admin', 'system-tenant-id', 'Loandrift Repayment Admin', 'Administrator for Repayment', 'rt-repayment', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-client-admin', 'system-tenant-id', 'Loandrift Client Admin', 'Administrator for Client', 'rt-client', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-loan-registration-admin', 'system-tenant-id', 'Loandrift Loan Registration Admin', 'Administrator for Loan Registration', 'rt-loan-registration', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-file-admin', 'system-tenant-id', 'Loandrift File Admin', 'Administrator for File Management', 'rt-file', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-dashboard-admin', 'system-tenant-id', 'Loandrift Dashboard Admin', 'Administrator for Dashboard', 'rt-dashboard', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-reports-admin', 'system-tenant-id', 'Loandrift Reports Admin', 'Administrator for Reports', 'rt-reports', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-savings-admin', 'system-tenant-id', 'Loandrift Savings Admin', 'Administrator for Savings', 'rt-savings', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-investment-admin', 'system-tenant-id', 'Loandrift Investment Admin', 'Administrator for Investment', 'rt-investment', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-credit-score-admin', 'system-tenant-id', 'Loandrift Credit Score Admin', 'Administrator for Credit Scoring', 'rt-credit-score', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Viewer Admin Role (read-only access to all Loandrift resources)
('role-loandrift-viewer-admin', 'system-tenant-id', 'Loandrift Viewer Admin', 'Viewer Admin for Loandrift - can view all Loandrift resources with GET permissions only', 'rt-subscribed-app-loandrift', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET
    role_name        = EXCLUDED.role_name,
    description      = EXCLUDED.description,
    resource_type_id = EXCLUDED.resource_type_id,
    is_system        = EXCLUDED.is_system,
    is_active        = EXCLUDED.is_active;