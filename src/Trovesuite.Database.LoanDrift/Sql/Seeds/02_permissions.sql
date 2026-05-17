-- =====================================================
-- Loan Drift Database Schema
-- =====================================================

-- Set the search path to loandrift schema for this session
SET search_path TO core_platform;

-- Insert permissions

INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime) VALUES

-- Approval permissions
('permission-loandrift-approval-get', 'Loandrift Approval Get', 'rt-approval', 'Can view, list, read approvals, access activity logs, view statistics, view deletion chat history, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-approval-update', 'Loandrift Approval Update', 'rt-approval', 'Can update approvals, restore soft-deleted approvals, approve or reject deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Calender permissions
('permission-loandrift-calender-get', 'Loandrift Calender Get', 'rt-calender', 'Can view calender events', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Capturing permissions
('permission-loandrift-capturing-create-update', 'Loandrift Capturing Create Update', 'rt-capturing', 'Can create or update capturing phase', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-capturing-approve-reject', 'Loandrift Capturing Approve Reject', 'rt-capturing', 'Can approve or reject loans', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-capturing-complete', 'Loandrift Capturing Complete', 'rt-capturing', 'Can complete loans', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-capturing-delete', 'Loandrift Capturing Delete', 'rt-capturing', 'Can permanently delete capturing phase', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-capturing-get-statistics', 'Loandrift Capturing Get Statistics', 'rt-capturing', 'Can get capturing statistics', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-capturing-get-loan-messages', 'Loandrift Capturing Get Loan Messages', 'rt-capturing', 'Can get loan messages', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Disbursement permissions
('permission-loandrift-disbursement-disburse', 'Loandrift Disbursement Disburse', 'rt-disbursement', 'Can disburse loans', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-disbursement-get', 'Loandrift Disbursement Get', 'rt-disbursement', 'Can view, list, read disbursements, access activity logs, view statistics, view deletion chat history, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-disbursement-update', 'Loandrift Disbursement Update', 'rt-disbursement', 'Can update disbursements, restore soft-deleted disbursements, approve or reject deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- File Management permissions
('permission-loandrift-file-upload-multiple', 'Loandrift File Upload Multiple', 'rt-file', 'Can upload multiple files', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-file-update', 'Loandrift File Update', 'rt-file', 'Can update files', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-file-delete', 'Loandrift File Delete', 'rt-file', 'Can delete files', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-file-list-documents', 'Loandrift File List Documents', 'rt-file', 'Can list documents', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Loan Registration permissions (used for both client registration and loan registration)
('permission-loandrift-loan-registration-create-new-client', 'Loandrift Loan Registration Create New Client', 'rt-loan-registration', 'Can create loan registration for new client or register new clients', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-loan-registration-create-existing-client', 'Loandrift Loan Registration Create Existing Client', 'rt-loan-registration', 'Can create loan registration for existing client', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-loan-registration-update', 'Loandrift Loan Registration Update', 'rt-loan-registration', 'Can update loan registration', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-loan-registration-get', 'Loandrift Loan Registration Get', 'rt-loan-registration', 'Can get loan registration details, list loans, list registrations, and get total captured registrations', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-loan-registration-get-statistics', 'Loandrift Loan Registration Get Statistics', 'rt-loan-registration', 'Can get loan registration statistics', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-loan-registration-delete', 'Loandrift Loan Registration Delete', 'rt-loan-registration', 'Can permanently delete loans', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Settings permissions (Reference Data: Sectors, Loan Types, Interest Types)
('permission-loandrift-settings-create', 'Loandrift Settings Create', 'rt-settings', 'Can create settings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-settings-get', 'Loandrift Settings Get', 'rt-settings', 'Can get settings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-settings-update', 'Loandrift Settings Update', 'rt-settings', 'Can update settings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-settings-delete', 'Loandrift Settings Delete', 'rt-settings', 'Can delete settings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Client permissions
('permission-loandrift-client-create', 'Loandrift Client Create', 'rt-client', 'Can create new clients', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-client-update', 'Loandrift Client Update', 'rt-client', 'Can update clients', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-client-get', 'Loandrift Client Get', 'rt-client', 'Can get client details and list clients', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-client-delete', 'Loandrift Client Delete', 'rt-client', 'Can permanently delete clients', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-client-approve-deletion', 'Loandrift Client Approve Deletion', 'rt-client', 'Can approve client deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-client-get-deletion-chat-history', 'Loandrift Client Get Deletion Chat History', 'rt-client', 'Can get client deletion chat history', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-client-get-statistics', 'Loandrift Client Get Statistics', 'rt-client', 'Can get client statistics', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Repayment permissions
('permission-loandrift-repayment-create', 'Loandrift Repayment Create', 'rt-repayment', 'Can create new repayments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-repayment-update', 'Loandrift Repayment Update', 'rt-repayment', 'Can update repayments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-repayment-get', 'Loandrift Repayment Get', 'rt-repayment', 'Can get repayment details and list repayments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-repayment-delete', 'Loandrift Repayment Delete', 'rt-repayment', 'Can permanently delete repayments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-repayment-get-payment-dates', 'Loandrift Repayment Get Payment Dates', 'rt-repayment', 'Can get payment dates', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-repayment-get-statistics', 'Loandrift Repayment Get Statistics', 'rt-repayment', 'Can get repayment statistics', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Dashboard permissions
('permission-loandrift-dashboard-get-statistics', 'Loandrift Dashboard Get Statistics', 'rt-dashboard', 'Can get dashboard statistics', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-dashboard-get-chart-data', 'Loandrift Dashboard Get Chart Data', 'rt-dashboard', 'Can get chart data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Reports permissions
('permission-loandrift-reports-get', 'Loandrift Reports Get', 'rt-reports', 'Can view, list, and read all reports', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Locations permissions
('permission-loandrift-locations-get', 'Loandrift Locations Get', 'rt-location', 'Can view and get locations that the user has access to', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- =====================================================
-- LOGS PERMISSIONS (using core platform rt-logs resource type)
-- Unified logs permissions - replaces individual entity activity log permissions
-- =====================================================
('permission-loandrift-logs-get', 'Loandrift Logs Get', 'rt-logs', 'Can view, list, and read activity logs', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-logs-delete', 'Loandrift Logs Delete', 'rt-logs', 'Can delete activity logs', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)

ON CONFLICT (id) DO UPDATE SET
    permission_name  = EXCLUDED.permission_name,
    resource_type_id = EXCLUDED.resource_type_id,
    description      = EXCLUDED.description;