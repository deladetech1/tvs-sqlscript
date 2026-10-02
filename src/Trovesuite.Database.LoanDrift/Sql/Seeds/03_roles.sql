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
('role-loandrift-expense-admin', 'system-tenant-id', 'Loandrift Expense Admin', 'Administrator for Expense', 'rt-loandrift-expenses', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-repayment-admin', 'system-tenant-id', 'Loandrift Repayment Admin', 'Administrator for Repayment', 'rt-repayment', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-client-admin', 'system-tenant-id', 'Loandrift Client Admin', 'Administrator for Client', 'rt-client', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-loan-registration-admin', 'system-tenant-id', 'Loandrift Loan Registration Admin', 'Administrator for Loan Registration', 'rt-loan-registration', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-file-admin', 'system-tenant-id', 'Loandrift File Admin', 'Administrator for File Management', 'rt-file', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-dashboard-admin', 'system-tenant-id', 'Loandrift Dashboard Admin', 'Administrator for Dashboard', 'rt-dashboard', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-reports-admin', 'system-tenant-id', 'Loandrift Reports Admin', 'Administrator for Reports', 'rt-reports', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-savings-admin', 'system-tenant-id', 'Loandrift Savings Admin', 'Administrator for Savings', 'rt-savings', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-investment-admin', 'system-tenant-id', 'Loandrift Investment Admin', 'Administrator for Investment', 'rt-investment', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-credit-score-admin', 'system-tenant-id', 'Loandrift Credit Score Admin', 'Administrator for Credit Scoring', 'rt-credit-score', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-penalty-admin', 'system-tenant-id', 'Loandrift Penalty Admin', 'Administrator for Loan Penalties', 'rt-penalty', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Viewer Admin Role (read-only access to all Loandrift resources)
('role-loandrift-viewer-admin', 'system-tenant-id', 'Loandrift Viewer Admin', 'Viewer Admin for Loandrift - can view all Loandrift resources with GET permissions only', 'rt-subscribed-app-loandrift', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
-- role_name is deliberately NOT re-asserted below.
--
-- 20260929-11-roles-named-after-jobs owns these names now, and this seed runs
-- at step 1 of a deploy while that migration runs at step 5. Handing the old
-- name back here means every deploy reverts it and then renames it again --
-- harmless when a deploy finishes, and wrong the moment one does not. On
-- 2026-09-30 a module seed started failing at step 3, step 5 stopped being
-- reached, and 49 role names sat reverted for a day while anything matching on
-- the new names quietly did nothing.
--
-- The INSERT above still supplies a name, because a brand new database has to
-- get one from somewhere; the migration renames it there, once.
ON CONFLICT (id) DO UPDATE SET
    description      = EXCLUDED.description,
    resource_type_id = EXCLUDED.resource_type_id,
    is_system        = EXCLUDED.is_system,
    is_active        = EXCLUDED.is_active;
INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime)
VALUES ('role-loandrift-accounting-admin', 'system-tenant-id', 'Loandrift Accounting Admin', 'Manage LoanDrift accounting subject to owner-only configuration restrictions', 'rt-loandrift-accounting', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
-- role_name is deliberately NOT re-asserted below.
--
-- 20260929-11-roles-named-after-jobs owns these names now, and this seed runs
-- at step 1 of a deploy while that migration runs at step 5. Handing the old
-- name back here means every deploy reverts it and then renames it again --
-- harmless when a deploy finishes, and wrong the moment one does not. On
-- 2026-09-30 a module seed started failing at step 3, step 5 stopped being
-- reached, and 49 role names sat reverted for a day while anything matching on
-- the new names quietly did nothing.
--
-- The INSERT above still supplies a name, because a brand new database has to
-- get one from somewhere; the migration renames it there, once.
ON CONFLICT (id) DO UPDATE SET description=EXCLUDED.description, resource_type_id=EXCLUDED.resource_type_id;

-- Core Platform resource types can be shared/reparented. App-wide roles must
-- also receive this app's explicitly namespaced permissions, including locations.
-- Currency is a shared read dependency, never currency administration.
INSERT INTO core_platform.cp_role_permissions
  (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT r.tenant_id, r.id, p.id, r.role_name || ' can ' || lower(p.permission_name),
       CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
FROM core_platform.cp_roles r
CROSS JOIN core_platform.cp_permissions p
WHERE r.id IN ('role-subscribed-app-loandrift-admin', 'role-loandrift-viewer-admin')
  AND r.is_system AND r.is_active AND r.delete_status='NOT_DELETED'
  AND (p.id LIKE 'permission-loandrift-%' OR p.id='permission-currency-get')
  AND (r.id='role-subscribed-app-loandrift-admin' OR p.id ~ '-get($|-)')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =====================================================
-- Job roles
-- =====================================================
-- The roles a lending business actually staffs, as opposed to the per-module
-- "X Admin" roles above. Each one is a hand-picked permission set in
-- 04_others.sql, so they all hang off rt-loandrift-job-roles, which owns no
-- permissions and therefore keeps the auto-assign triggers out of them.
--
-- The shape: Call Center and Sales bring people in, the Loan Officer builds the
-- case, the Analyst and the Credit Manager judge it, the Branch Manager
-- supervises locally, Finance and the Cashier handle money in both directions,
-- Collections recovers what slips, and Compliance and Audit watch all of it.
-- Every pair that could mark its own homework is split: the officer prepares,
-- the manager decides.
INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-loandrift-call-center-agent', 'system-tenant-id', 'Loandrift Call Center Agent', 'Answers inbound calls and enquiries: looks up a client''s loan status, balance and next payment date, captures new leads, and routes anything needing a decision to a Loan Officer. Talks to customers; does not move money or change records.', 'rt-loandrift-job-roles', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-sales-executive', 'system-tenant-id', 'Loandrift Sales Executive', 'Brings in business: sources and onboards new clients, collects their documents, and submits loan applications into the pipeline. Owns targets and conversion, not credit quality.', 'rt-loandrift-job-roles', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-loan-officer', 'system-tenant-id', 'Loandrift Loan Officer', 'Owns the client relationship end to end: completes the application file, verifies the client and their documents, visits if needed, and writes the recommendation. Prepares the case; cannot approve it.', 'rt-loandrift-job-roles', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-credit-risk-analyst', 'system-tenant-id', 'Loandrift Credit Risk Analyst', 'Assesses whether the loan is safe to write: runs the credit score, checks affordability and exposure, and produces the risk opinion. Advises the decision-maker; does not make the call.', 'rt-loandrift-job-roles', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-credit-manager', 'system-tenant-id', 'Loandrift Credit Manager', 'The approval authority: approves or declines applications, overrides or adjusts credit scores where justified, and owns the scoring rules and credit policy.', 'rt-loandrift-job-roles', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-branch-manager', 'system-tenant-id', 'Loandrift Branch Manager', 'Runs a branch: approves loans within a delegated limit, supervises the officers and cashiers at that location, and answers for the branch''s portfolio quality and targets.', 'rt-loandrift-job-roles', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-finance-officer', 'system-tenant-id', 'Loandrift Finance Officer', 'Prepares the money side: readies disbursements for authorisation, posts expenses, and reconciles receipts against the ledger. Prepares payments; cannot release them.', 'rt-loandrift-job-roles', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-finance-manager', 'system-tenant-id', 'Loandrift Finance Manager', 'Authorises money out: releases disbursements, signs off reconciliations, owns the chart of accounts and financial reporting. The second pair of eyes on every payment.', 'rt-loandrift-job-roles', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-cashier', 'system-tenant-id', 'Loandrift Cashier', 'Handles cash at the counter: receipts repayments, records savings deposits and withdrawals, issues receipts. Takes money in; cannot pay money out or unmake a receipt.', 'rt-loandrift-job-roles', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-collections-officer', 'system-tenant-id', 'Loandrift Collections Officer', 'Works the arrears list: contacts clients in default, records promises to pay, logs field visits and outcomes, and escalates hard cases. Chases; does not forgive.', 'rt-loandrift-job-roles', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-collections-manager', 'system-tenant-id', 'Loandrift Collections Manager', 'Owns the arrears book: approves or rejects collection actions, waives penalties where warranted, agrees restructures, and recommends write-offs.', 'rt-loandrift-job-roles', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-compliance-officer', 'system-tenant-id', 'Loandrift Compliance Officer', 'Keeps the business inside the rules: runs KYC/AML checks, prepares regulatory returns including the Bank of Ghana credit bureau submission, approves client data-erasure requests, and reviews activity logs for policy breaches.', 'rt-loandrift-job-roles', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-internal-auditor', 'system-tenant-id', 'Loandrift Internal Auditor', 'Independent assurance: reviews every transaction, approval and log to confirm controls held and nothing was circumvented. Sees everything, changes nothing.', 'rt-loandrift-job-roles', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
-- role_name is deliberately NOT re-asserted below.
--
-- 20260929-11-roles-named-after-jobs owns these names now, and this seed runs
-- at step 1 of a deploy while that migration runs at step 5. Handing the old
-- name back here means every deploy reverts it and then renames it again --
-- harmless when a deploy finishes, and wrong the moment one does not. On
-- 2026-09-30 a module seed started failing at step 3, step 5 stopped being
-- reached, and 49 role names sat reverted for a day while anything matching on
-- the new names quietly did nothing.
--
-- The INSERT above still supplies a name, because a brand new database has to
-- get one from somewhere; the migration renames it there, once.
ON CONFLICT (id) DO UPDATE SET
    description      = EXCLUDED.description,
    resource_type_id = EXCLUDED.resource_type_id,
    is_system        = EXCLUDED.is_system,
    is_active        = EXCLUDED.is_active;
