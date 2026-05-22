-- =====================================================
-- Human Resources Database Schema
-- =====================================================

-- CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE SCHEMA IF NOT EXISTS human_resource;
SET search_path TO human_resource;

-- =====================================================
-- HR permissions (shared across all tenants via core_platform.cp_permissions)
-- =====================================================

INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime) VALUES

-- Employees
('permission-hr-employees-create',             'HR Employees Create',             'rt-hr-employees', 'Create employees (onboarding mega-endpoint)',                          CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-employees-get',                'HR Employees Get',                'rt-hr-employees', 'View / list / read employees, view statistics',                        CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-employees-update',             'HR Employees Update',             'rt-hr-employees', 'Update non-sensitive employee fields, reporting line, emergency contacts, documents', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-employees-delete',             'HR Employees Delete',             'rt-hr-employees', 'Soft / permanent delete + restore employees',                          CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-employees-reveal-sensitive',   'HR Employees Reveal Sensitive',   'rt-hr-employees', 'View unmasked SSNIT, TIN, national-ID and bank account numbers',       CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-employees-manage-salary',      'HR Employees Manage Salary',      'rt-hr-employees', 'Append / update salary history (raises, promotions, corrections)',     CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Lookups
('permission-hr-departments-manage',           'HR Departments Manage',           'rt-hr-departments', 'Create / update / delete departments',                               CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-banks-manage',                 'HR Banks Manage',                 'rt-hr-banks',       'Create / update / delete banks and bank branches',                   CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-pension-providers-manage',     'HR Pension Providers Manage',     'rt-hr-pension',     'Create / update / delete Tier 2 and Tier 3 pension providers',       CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Files
('permission-hr-file-upload',                  'HR File Upload',                  'rt-hr-files',       'Upload / delete employee documents (contracts, IDs, certificates)',  CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)

ON CONFLICT (id) DO UPDATE SET
    permission_name  = EXCLUDED.permission_name,
    resource_type_id = EXCLUDED.resource_type_id,
    description      = EXCLUDED.description;
