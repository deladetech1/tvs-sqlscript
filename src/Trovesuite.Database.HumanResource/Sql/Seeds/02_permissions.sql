CREATE SCHEMA IF NOT EXISTS human_resource;
SET search_path TO human_resource;

-- =====================================================
-- HR permissions — enterprise HR (master) + ZelosHR API (feature/uplift)
-- Pattern: create | get | update | delete | admin per resource type (MystoreGuard-style)
-- =====================================================

INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime) VALUES

-- Enterprise HR (master) — employees
('permission-hr-employees-create', 'HR Employees Create', 'rt-hr-employees', 'Create employees (onboarding mega-endpoint)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-employees-get', 'HR Employees Get', 'rt-hr-employees', 'View / list / read employees, view statistics', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-employees-update', 'HR Employees Update', 'rt-hr-employees', 'Update non-sensitive employee fields, reporting line, emergency contacts, documents', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-employees-delete', 'HR Employees Delete', 'rt-hr-employees', 'Soft / permanent delete + restore employees', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-employees-admin', 'HR Employees Admin', 'rt-hr-employees', 'Full employee administration including lifecycle overrides', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-employees-reveal-sensitive', 'HR Employees Reveal Sensitive', 'rt-hr-employees', 'View unmasked SSNIT, TIN, national-ID and bank account numbers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-employees-manage-salary', 'HR Employees Manage Salary', 'rt-hr-employees', 'Append / update salary history (raises, promotions, corrections)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Enterprise HR — departments
('permission-hr-departments-create', 'HR Departments Create', 'rt-hr-departments', 'Create departments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-departments-get', 'HR Departments Get', 'rt-hr-departments', 'View and list departments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-departments-update', 'HR Departments Update', 'rt-hr-departments', 'Update departments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-departments-delete', 'HR Departments Delete', 'rt-hr-departments', 'Archive or delete departments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-departments-admin', 'HR Departments Admin', 'rt-hr-departments', 'Full department administration', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Enterprise HR — banks
('permission-hr-banks-create', 'HR Banks Create', 'rt-hr-banks', 'Create banks and bank branches', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-banks-get', 'HR Banks Get', 'rt-hr-banks', 'View and list banks and branches', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-banks-update', 'HR Banks Update', 'rt-hr-banks', 'Update banks and bank branches', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-banks-delete', 'HR Banks Delete', 'rt-hr-banks', 'Delete banks and bank branches', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-banks-admin', 'HR Banks Admin', 'rt-hr-banks', 'Full bank administration', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Enterprise HR — pension providers
('permission-hr-pension-providers-create', 'HR Pension Providers Create', 'rt-hr-pension', 'Create Tier 2 and Tier 3 pension providers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-pension-providers-get', 'HR Pension Providers Get', 'rt-hr-pension', 'View and list pension providers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-pension-providers-update', 'HR Pension Providers Update', 'rt-hr-pension', 'Update pension providers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-pension-providers-delete', 'HR Pension Providers Delete', 'rt-hr-pension', 'Delete pension providers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-pension-providers-admin', 'HR Pension Providers Admin', 'rt-hr-pension', 'Full pension provider administration', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Enterprise HR — files
('permission-hr-files-create', 'HR Files Create', 'rt-hr-files', 'Upload employee documents', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-files-get', 'HR Files Get', 'rt-hr-files', 'View and list employee documents', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-files-update', 'HR Files Update', 'rt-hr-files', 'Update employee document metadata', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-files-delete', 'HR Files Delete', 'rt-hr-files', 'Delete employee documents', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-hr-files-admin', 'HR Files Admin', 'rt-hr-files', 'Full employee file administration', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- ZelosHR — dashboard
('permission-zeloshr-dashboard-create', 'ZelosHR Dashboard Create', 'rt-zeloshr-dashboard', 'Create dashboard widgets and layouts', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-dashboard-get', 'ZelosHR Dashboard Get', 'rt-zeloshr-dashboard', 'View dashboard summary and KPIs', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-dashboard-update', 'ZelosHR Dashboard Update', 'rt-zeloshr-dashboard', 'Update dashboard widgets and layouts', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-dashboard-delete', 'ZelosHR Dashboard Delete', 'rt-zeloshr-dashboard', 'Delete dashboard widgets and layouts', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-dashboard-admin', 'ZelosHR Dashboard Admin', 'rt-zeloshr-dashboard', 'Full dashboard administration', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- ZelosHR — employee
('permission-zeloshr-employee-create', 'ZelosHR Employee Create', 'rt-zeloshr-employee', 'Create employee records', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-employee-get', 'ZelosHR Employee Get', 'rt-zeloshr-employee', 'List and read employees and directory', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-employee-update', 'ZelosHR Employee Update', 'rt-zeloshr-employee', 'Update employee records', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-employee-delete', 'ZelosHR Employee Delete', 'rt-zeloshr-employee', 'Soft-delete employee records', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-employee-admin', 'ZelosHR Employee Admin', 'rt-zeloshr-employee', 'Full employee administration', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- ZelosHR — org (chart / summary)
('permission-zeloshr-org-create', 'ZelosHR Org Create', 'rt-zeloshr-org', 'Create org structure aggregates', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-org-get', 'ZelosHR Org Get', 'rt-zeloshr-org', 'View org chart and organisation summary', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-org-update', 'ZelosHR Org Update', 'rt-zeloshr-org', 'Update org structure aggregates', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-org-delete', 'ZelosHR Org Delete', 'rt-zeloshr-org', 'Delete org structure aggregates', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-org-admin', 'ZelosHR Org Admin', 'rt-zeloshr-org', 'Full org structure administration', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- ZelosHR — departments
('permission-zeloshr-departments-create', 'ZelosHR Departments Create', 'rt-zeloshr-departments', 'Create departments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-departments-get', 'ZelosHR Departments Get', 'rt-zeloshr-departments', 'List and read departments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-departments-update', 'ZelosHR Departments Update', 'rt-zeloshr-departments', 'Update departments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-departments-delete', 'ZelosHR Departments Delete', 'rt-zeloshr-departments', 'Archive departments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-departments-admin', 'ZelosHR Departments Admin', 'rt-zeloshr-departments', 'Full department administration', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- ZelosHR — branches
('permission-zeloshr-branches-create', 'ZelosHR Branches Create', 'rt-zeloshr-branches', 'Create branches', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-branches-get', 'ZelosHR Branches Get', 'rt-zeloshr-branches', 'List and read branches', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-branches-update', 'ZelosHR Branches Update', 'rt-zeloshr-branches', 'Update branches', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-branches-delete', 'ZelosHR Branches Delete', 'rt-zeloshr-branches', 'Archive branches', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-branches-admin', 'ZelosHR Branches Admin', 'rt-zeloshr-branches', 'Full branch administration', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- ZelosHR — lifecycle
('permission-zeloshr-lifecycle-create', 'ZelosHR Lifecycle Create', 'rt-zeloshr-lifecycle', 'Create lifecycle events', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-lifecycle-get', 'ZelosHR Lifecycle Get', 'rt-zeloshr-lifecycle', 'List and read lifecycle events', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-lifecycle-update', 'ZelosHR Lifecycle Update', 'rt-zeloshr-lifecycle', 'Update lifecycle events', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-lifecycle-delete', 'ZelosHR Lifecycle Delete', 'rt-zeloshr-lifecycle', 'Delete lifecycle events', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-lifecycle-admin', 'ZelosHR Lifecycle Admin', 'rt-zeloshr-lifecycle', 'Full lifecycle administration', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- ZelosHR — audit
('permission-zeloshr-audit-create', 'ZelosHR Audit Create', 'rt-zeloshr-audit', 'Create audit log entries', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-audit-get', 'ZelosHR Audit Get', 'rt-zeloshr-audit', 'List and read audit logs', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-audit-update', 'ZelosHR Audit Update', 'rt-zeloshr-audit', 'Update audit log entries', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-audit-delete', 'ZelosHR Audit Delete', 'rt-zeloshr-audit', 'Delete audit log entries', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-audit-admin', 'ZelosHR Audit Admin', 'rt-zeloshr-audit', 'Full audit log administration', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- ZelosHR — attendance
('permission-zeloshr-attendance-create', 'ZelosHR Attendance Create', 'rt-zeloshr-attendance', 'Record attendance', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-attendance-get', 'ZelosHR Attendance Get', 'rt-zeloshr-attendance', 'List and read attendance records', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-attendance-update', 'ZelosHR Attendance Update', 'rt-zeloshr-attendance', 'Update attendance records', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-attendance-delete', 'ZelosHR Attendance Delete', 'rt-zeloshr-attendance', 'Delete attendance records', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-attendance-admin', 'ZelosHR Attendance Admin', 'rt-zeloshr-attendance', 'Full attendance administration', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- ZelosHR — leave
('permission-zeloshr-leave-create', 'ZelosHR Leave Create', 'rt-zeloshr-leave', 'Submit leave requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-leave-get', 'ZelosHR Leave Get', 'rt-zeloshr-leave', 'List leave requests and balances', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-leave-update', 'ZelosHR Leave Update', 'rt-zeloshr-leave', 'Update and approve leave requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-leave-delete', 'ZelosHR Leave Delete', 'rt-zeloshr-leave', 'Delete leave requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-leave-admin', 'ZelosHR Leave Admin', 'rt-zeloshr-leave', 'Full leave administration', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- ZelosHR — recruitment
('permission-zeloshr-recruitment-create', 'ZelosHR Recruitment Create', 'rt-zeloshr-recruitment', 'Create job postings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-recruitment-get', 'ZelosHR Recruitment Get', 'rt-zeloshr-recruitment', 'List and read job postings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-recruitment-update', 'ZelosHR Recruitment Update', 'rt-zeloshr-recruitment', 'Update job postings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-recruitment-delete', 'ZelosHR Recruitment Delete', 'rt-zeloshr-recruitment', 'Delete job postings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-recruitment-admin', 'ZelosHR Recruitment Admin', 'rt-zeloshr-recruitment', 'Full recruitment administration', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- ZelosHR — onboarding
('permission-zeloshr-onboarding-create', 'ZelosHR Onboarding Create', 'rt-zeloshr-onboarding', 'Assign onboarding tasks', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-onboarding-get', 'ZelosHR Onboarding Get', 'rt-zeloshr-onboarding', 'List onboarding tasks', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-onboarding-update', 'ZelosHR Onboarding Update', 'rt-zeloshr-onboarding', 'Update and complete onboarding tasks', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-onboarding-delete', 'ZelosHR Onboarding Delete', 'rt-zeloshr-onboarding', 'Delete onboarding tasks', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-onboarding-admin', 'ZelosHR Onboarding Admin', 'rt-zeloshr-onboarding', 'Full onboarding administration', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- ZelosHR — performance
('permission-zeloshr-performance-create', 'ZelosHR Performance Create', 'rt-zeloshr-performance', 'Create performance reviews', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-performance-get', 'ZelosHR Performance Get', 'rt-zeloshr-performance', 'List performance reviews', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-performance-update', 'ZelosHR Performance Update', 'rt-zeloshr-performance', 'Update and complete performance reviews', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-performance-delete', 'ZelosHR Performance Delete', 'rt-zeloshr-performance', 'Delete performance reviews', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-performance-admin', 'ZelosHR Performance Admin', 'rt-zeloshr-performance', 'Full performance administration', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- ZelosHR — disciplinary
('permission-zeloshr-disciplinary-create', 'ZelosHR Disciplinary Create', 'rt-zeloshr-disciplinary', 'Open disciplinary cases', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-disciplinary-get', 'ZelosHR Disciplinary Get', 'rt-zeloshr-disciplinary', 'List disciplinary cases', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-disciplinary-update', 'ZelosHR Disciplinary Update', 'rt-zeloshr-disciplinary', 'Update disciplinary cases', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-disciplinary-delete', 'ZelosHR Disciplinary Delete', 'rt-zeloshr-disciplinary', 'Delete disciplinary cases', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-disciplinary-admin', 'ZelosHR Disciplinary Admin', 'rt-zeloshr-disciplinary', 'Full disciplinary administration', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- ZelosHR — documents
('permission-zeloshr-documents-create', 'ZelosHR Documents Create', 'rt-zeloshr-documents', 'Upload document metadata', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-documents-get', 'ZelosHR Documents Get', 'rt-zeloshr-documents', 'List employee documents', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-documents-update', 'ZelosHR Documents Update', 'rt-zeloshr-documents', 'Update document metadata', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-documents-delete', 'ZelosHR Documents Delete', 'rt-zeloshr-documents', 'Delete document metadata', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-documents-admin', 'ZelosHR Documents Admin', 'rt-zeloshr-documents', 'Full document administration', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- ZelosHR — custom fields (definitions)
('permission-zeloshr-custom-fields-create', 'ZelosHR Custom Fields Create', 'rt-zeloshr-custom-fields', 'Create custom field definitions', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-custom-fields-get', 'ZelosHR Custom Fields Get', 'rt-zeloshr-custom-fields', 'View custom field definitions and form schema', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-custom-fields-update', 'ZelosHR Custom Fields Update', 'rt-zeloshr-custom-fields', 'Update custom field definitions', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-custom-fields-delete', 'ZelosHR Custom Fields Delete', 'rt-zeloshr-custom-fields', 'Soft-delete custom field definitions', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-custom-fields-admin', 'ZelosHR Custom Fields Admin', 'rt-zeloshr-custom-fields', 'Reorder and administer custom field definitions', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- ZelosHR — custom field values (same resource type)
('permission-zeloshr-custom-field-values-create', 'ZelosHR Custom Field Values Create', 'rt-zeloshr-custom-fields', 'Create custom field values on entities', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-custom-field-values-get', 'ZelosHR Custom Field Values Get', 'rt-zeloshr-custom-fields', 'Read custom field values on entities', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-custom-field-values-update', 'ZelosHR Custom Field Values Update', 'rt-zeloshr-custom-fields', 'Write custom field values on entities', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-custom-field-values-delete', 'ZelosHR Custom Field Values Delete', 'rt-zeloshr-custom-fields', 'Clear custom field values on entities', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-custom-field-values-admin', 'ZelosHR Custom Field Values Admin', 'rt-zeloshr-custom-fields', 'Full custom field value administration', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-zeloshr-sensitive-fields-reveal', 'ZelosHR Sensitive Fields Reveal', 'rt-zeloshr-custom-fields', 'Reveal masked sensitive custom field values', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)

ON CONFLICT (id) DO UPDATE SET
    permission_name  = EXCLUDED.permission_name,
    resource_type_id = EXCLUDED.resource_type_id,
    description      = EXCLUDED.description;
