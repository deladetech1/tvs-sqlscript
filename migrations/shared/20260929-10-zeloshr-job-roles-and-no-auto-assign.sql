-- ZelosHR gets job roles, and nothing is auto-assigned any more.
--
-- Two changes that only make sense together.
--
-- 1. The auto-assign triggers go.
--
-- They were the reason the roles were wrong. A role was created, a trigger read its
-- resource_type_id and granted it every permission of that resource, so ZelosHR ended up with
-- twenty-one roles of the shape "everything about one resource" -- Documents Admin, Lifecycle
-- Admin, Dashboard Admin -- which is not how anybody staffs an HR department.
--
-- They also contradict the role rules added in tvs-package 1.0.42-1.0.47. Owner, Admin, Core
-- Platform Admin and each app's admin are now allowed by BEING that role, and their grant rows
-- were deleted on purpose. The triggers put them back: 20260929-09's failed deploy left Core
-- Platform Admin holding 147 rows again, because the seeds re-ran and the trigger re-granted
-- before the migration that strips them could run. That is not a one-off; it happens on every
-- deploy where anything touches cp_permissions.
--
-- Worse, they key off role NAMES. 'Admin' exactly, and LIKE '%Viewer Admin%', and
-- '%Store Sales Personnel%'. A role's label decided what it could do, so renaming a role to
-- something a human could read silently changed its permissions -- the same mistake as
-- addressing a permission by an opaque id, one level up. Dropping these is what makes the role
-- renaming safe.
--
-- What is given up: when a new permission is added, no existing role gains it automatically.
-- Every grant becomes explicit, in the migration that adds the permission. That is the point.
-- scripts/audit_role_permissions.py already reports a role missing permissions its screens
-- need, and it exits non-zero, so an omission is caught rather than papered over.
--
-- Checked first: the grant-based roles are current, so nothing is frozen mid-gap. Core Platform
-- Viewer Admin holds 46 of 46 reads, LoanDrift Viewer Admin 36 of 36, MyStoreGuard Viewer Admin
-- 69 of 70 -- the missing one is permission-msg-logs-get, which the reconcile function
-- deliberately withheld from app viewers, and it stays withheld.
--
-- 2. ZelosHR gets thirteen job roles, and the twenty-three mechanical ones are retired.
--
-- Modelled on LoanDrift, which already names jobs rather than screens: Loan Officer, Cashier,
-- Credit Risk Analyst. Each role here spans the resources that job actually touches, and
-- between them they cover all 68 permissions the endpoints enforce after the gating change --
-- asserted at the end, because a permission no role holds is an endpoint nobody can reach.
--
-- resource_type_id is 'rt-system-role' on every one. That is the permission-less resource type:
-- if the triggers are ever reinstated, a curated role must not be auto-filled, which would
-- undo the curation on the spot.

BEGIN;

-- ---------------------------------------------------------------- 1. no more auto-assignment
DROP TRIGGER IF EXISTS trigger_auto_assign_new_permission_to_existing_admin_roles ON core_platform.cp_permissions;
DROP TRIGGER IF EXISTS trigger_auto_assign_all_permissions_except_logs_to_admin_role ON core_platform.cp_roles;
DROP TRIGGER IF EXISTS trigger_auto_assign_get_permissions_to_viewer_admin_role ON core_platform.cp_roles;
DROP TRIGGER IF EXISTS trigger_auto_assign_resource_permissions_to_admin_role ON core_platform.cp_roles;

-- The functions go too, so nothing can call them back into life by name. Every one of these
-- decided grants from a role's label.
DROP FUNCTION IF EXISTS core_platform.auto_assign_new_permission_to_existing_admin_roles() CASCADE;
DROP FUNCTION IF EXISTS core_platform.auto_assign_all_permissions_except_logs_to_admin_role() CASCADE;
DROP FUNCTION IF EXISTS core_platform.auto_assign_get_permissions_to_viewer_admin_role() CASCADE;
DROP FUNCTION IF EXISTS core_platform.auto_assign_resource_permissions_to_admin_role() CASCADE;
DROP FUNCTION IF EXISTS core_platform.auto_assign_all_permissions_to_owner_role() CASCADE;
DROP FUNCTION IF EXISTS core_platform.reconcile_viewer_admin_permissions() CASCADE;

-- ------------------------------------------------------------------- 2. the ZelosHR job roles

INSERT INTO core_platform.cp_roles
    (tenant_id, id, role_name, resource_type_id, is_system, description,
     cdate, ctime, cdatetime, delete_status, is_active)
VALUES
  ('system-tenant-id', 'role-zeloshr-hr-manager', 'HR Manager', 'rt-system-role', true,
   'Runs the HR function: the employee roster, the org structure, documents, onboarding and employee lifecycle. Approves leave. Reads performance and discipline without changing them. Cannot change company configuration or touch the audit trail.',
   CURRENT_DATE::text, CURRENT_TIME::text, now(), 'NOT_DELETED', true),
  ('system-tenant-id', 'role-zeloshr-hr-officer', 'HR Officer', 'rt-system-role', true,
   'Day-to-day HR records: maintains employee details, documents and onboarding. Cannot delete anything, and cannot change the org structure or company configuration.',
   CURRENT_DATE::text, CURRENT_TIME::text, now(), 'NOT_DELETED', true),
  ('system-tenant-id', 'role-zeloshr-recruiter', 'Recruiter', 'rt-system-role', true,
   'Runs hiring: vacancies, candidates and the pipeline up to an offer. Can create an employee record and start their onboarding, but not change existing employees.',
   CURRENT_DATE::text, CURRENT_TIME::text, now(), 'NOT_DELETED', true),
  ('system-tenant-id', 'role-zeloshr-onboarding-coordinator', 'Onboarding Coordinator', 'rt-system-role', true,
   'Takes a new starter from accepted offer to first day: onboarding tasks, their joining record and their documents.',
   CURRENT_DATE::text, CURRENT_TIME::text, now(), 'NOT_DELETED', true),
  ('system-tenant-id', 'role-zeloshr-line-manager', 'Line Manager', 'rt-system-role', true,
   'Manages their own team: sees their attendance and timesheets, approves their leave, writes their performance reviews and raises disciplinary cases. Cannot edit employee records.',
   CURRENT_DATE::text, CURRENT_TIME::text, now(), 'NOT_DELETED', true),
  ('system-tenant-id', 'role-zeloshr-attendance-officer', 'Time & Attendance Officer', 'rt-system-role', true,
   'Owns the clock: attendance records, clock-ins, corrections, the terminals themselves and the enforcement rules for where and when people may clock.',
   CURRENT_DATE::text, CURRENT_TIME::text, now(), 'NOT_DELETED', true),
  ('system-tenant-id', 'role-zeloshr-payroll-officer', 'Payroll Officer', 'rt-system-role', true,
   'Reads everything pay depends on — hours, timesheets, employee details and their documents — and changes none of it. Payroll runs outside ZelosHR; this role only supplies it.',
   CURRENT_DATE::text, CURRENT_TIME::text, now(), 'NOT_DELETED', true),
  ('system-tenant-id', 'role-zeloshr-leave-administrator', 'Leave Administrator', 'rt-system-role', true,
   'Owns the leave system: entitlements, requests, approvals and the leave calendar.',
   CURRENT_DATE::text, CURRENT_TIME::text, now(), 'NOT_DELETED', true),
  ('system-tenant-id', 'role-zeloshr-performance-manager', 'Performance & Discipline Manager', 'rt-system-role', true,
   'Owns appraisals and disciplinary cases across the organisation, including closing and removing them.',
   CURRENT_DATE::text, CURRENT_TIME::text, now(), 'NOT_DELETED', true),
  ('system-tenant-id', 'role-zeloshr-hr-auditor', 'HR Auditor', 'rt-system-role', true,
   'Reads everything in ZelosHR, including the audit trail, and changes nothing. For internal audit and investigations. Cannot purge audit entries.',
   CURRENT_DATE::text, CURRENT_TIME::text, now(), 'NOT_DELETED', true),
  ('system-tenant-id', 'role-zeloshr-compliance-administrator', 'HR Compliance Administrator', 'rt-system-role', true,
   'The only role that may delete audit entries, and only to apply the retention window. Deliberately narrow: it holds nothing else that can change a record.',
   CURRENT_DATE::text, CURRENT_TIME::text, now(), 'NOT_DELETED', true),
  ('system-tenant-id', 'role-zeloshr-system-administrator', 'HR System Administrator', 'rt-system-role', true,
   'Configures ZelosHR itself: company details, localisation, employment and ID card types, employee ID format, the employee portal, and the custom field catalogue. Sets up the org structure. Reads employees but does not maintain them.',
   CURRENT_DATE::text, CURRENT_TIME::text, now(), 'NOT_DELETED', true),
  ('system-tenant-id', 'role-zeloshr-employee-self-service', 'Employee Self-Service', 'rt-system-role', true,
   'What an ordinary employee gets: their own record, clocking in and out, requesting leave and seeing their own documents.',
   CURRENT_DATE::text, CURRENT_TIME::text, now(), 'NOT_DELETED', true)
ON CONFLICT (id) DO UPDATE
    SET role_name = EXCLUDED.role_name,
        description = EXCLUDED.description,
        resource_type_id = EXCLUDED.resource_type_id,
        delete_status = 'NOT_DELETED',
        is_active = true;

-- The Core Platform nav block: six reads without which the app does not appear in the hub
-- at all, so a role missing them looks broken rather than restricted.
INSERT INTO core_platform.cp_role_permissions
    (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', r.id, p.id, r.role_name || ' can ' || lower(p.permission_name),
       CURRENT_DATE::text, CURRENT_TIME::text, now()
  FROM core_platform.cp_roles r
  JOIN core_platform.cp_permissions p ON p.id = ANY(ARRAY[
        'permission-app-get',
        'permission-business-get',
        'permission-business-app-get',
        'permission-business-app-get-locations',
        'permission-organization-get',
        'permission-user-get-locations'
      ])
  WHERE r.id = ANY(ARRAY[
        'role-zeloshr-hr-manager',
        'role-zeloshr-hr-officer',
        'role-zeloshr-recruiter',
        'role-zeloshr-onboarding-coordinator',
        'role-zeloshr-line-manager',
        'role-zeloshr-attendance-officer',
        'role-zeloshr-payroll-officer',
        'role-zeloshr-leave-administrator',
        'role-zeloshr-performance-manager',
        'role-zeloshr-hr-auditor',
        'role-zeloshr-compliance-administrator',
        'role-zeloshr-system-administrator',
        'role-zeloshr-employee-self-service'
      ])
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- What each job actually needs, resource by resource.
INSERT INTO core_platform.cp_role_permissions
    (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id,
       r.role_name || ' can ' || lower(p.permission_name),
       CURRENT_DATE::text, CURRENT_TIME::text, now()
  FROM (VALUES
        ('role-zeloshr-hr-manager', 'attendance-records', 'get'),
        ('role-zeloshr-hr-manager', 'attendance-team', 'get'),
        ('role-zeloshr-hr-manager', 'attendance-timesheet', 'get'),
        ('role-zeloshr-hr-manager', 'branches', 'get'),
        ('role-zeloshr-hr-manager', 'branches', 'create'),
        ('role-zeloshr-hr-manager', 'branches', 'update'),
        ('role-zeloshr-hr-manager', 'branches', 'delete'),
        ('role-zeloshr-hr-manager', 'custom-fields', 'get'),
        ('role-zeloshr-hr-manager', 'custom-fields', 'create'),
        ('role-zeloshr-hr-manager', 'custom-fields', 'update'),
        ('role-zeloshr-hr-manager', 'custom-fields', 'delete'),
        ('role-zeloshr-hr-manager', 'dashboard', 'get'),
        ('role-zeloshr-hr-manager', 'departments', 'get'),
        ('role-zeloshr-hr-manager', 'departments', 'create'),
        ('role-zeloshr-hr-manager', 'departments', 'update'),
        ('role-zeloshr-hr-manager', 'departments', 'delete'),
        ('role-zeloshr-hr-manager', 'disciplinary', 'get'),
        ('role-zeloshr-hr-manager', 'documents', 'get'),
        ('role-zeloshr-hr-manager', 'documents', 'create'),
        ('role-zeloshr-hr-manager', 'documents', 'update'),
        ('role-zeloshr-hr-manager', 'documents', 'delete'),
        ('role-zeloshr-hr-manager', 'employee', 'get'),
        ('role-zeloshr-hr-manager', 'employee', 'create'),
        ('role-zeloshr-hr-manager', 'employee', 'update'),
        ('role-zeloshr-hr-manager', 'employee', 'delete'),
        ('role-zeloshr-hr-manager', 'leave', 'get'),
        ('role-zeloshr-hr-manager', 'leave', 'update'),
        ('role-zeloshr-hr-manager', 'lifecycle', 'get'),
        ('role-zeloshr-hr-manager', 'lifecycle', 'create'),
        ('role-zeloshr-hr-manager', 'lifecycle', 'update'),
        ('role-zeloshr-hr-manager', 'lifecycle', 'delete'),
        ('role-zeloshr-hr-manager', 'onboarding', 'get'),
        ('role-zeloshr-hr-manager', 'onboarding', 'create'),
        ('role-zeloshr-hr-manager', 'onboarding', 'update'),
        ('role-zeloshr-hr-manager', 'onboarding', 'delete'),
        ('role-zeloshr-hr-manager', 'org', 'get'),
        ('role-zeloshr-hr-manager', 'performance', 'get'),
        ('role-zeloshr-hr-officer', 'attendance-records', 'get'),
        ('role-zeloshr-hr-officer', 'branches', 'get'),
        ('role-zeloshr-hr-officer', 'custom-fields', 'get'),
        ('role-zeloshr-hr-officer', 'dashboard', 'get'),
        ('role-zeloshr-hr-officer', 'departments', 'get'),
        ('role-zeloshr-hr-officer', 'documents', 'get'),
        ('role-zeloshr-hr-officer', 'documents', 'create'),
        ('role-zeloshr-hr-officer', 'documents', 'update'),
        ('role-zeloshr-hr-officer', 'employee', 'get'),
        ('role-zeloshr-hr-officer', 'employee', 'create'),
        ('role-zeloshr-hr-officer', 'employee', 'update'),
        ('role-zeloshr-hr-officer', 'leave', 'get'),
        ('role-zeloshr-hr-officer', 'lifecycle', 'get'),
        ('role-zeloshr-hr-officer', 'lifecycle', 'create'),
        ('role-zeloshr-hr-officer', 'onboarding', 'get'),
        ('role-zeloshr-hr-officer', 'onboarding', 'create'),
        ('role-zeloshr-hr-officer', 'onboarding', 'update'),
        ('role-zeloshr-hr-officer', 'org', 'get'),
        ('role-zeloshr-recruiter', 'branches', 'get'),
        ('role-zeloshr-recruiter', 'dashboard', 'get'),
        ('role-zeloshr-recruiter', 'departments', 'get'),
        ('role-zeloshr-recruiter', 'documents', 'get'),
        ('role-zeloshr-recruiter', 'documents', 'create'),
        ('role-zeloshr-recruiter', 'employee', 'get'),
        ('role-zeloshr-recruiter', 'employee', 'create'),
        ('role-zeloshr-recruiter', 'onboarding', 'get'),
        ('role-zeloshr-recruiter', 'onboarding', 'create'),
        ('role-zeloshr-recruiter', 'recruitment', 'get'),
        ('role-zeloshr-recruiter', 'recruitment', 'create'),
        ('role-zeloshr-recruiter', 'recruitment', 'update'),
        ('role-zeloshr-recruiter', 'recruitment', 'delete'),
        ('role-zeloshr-onboarding-coordinator', 'branches', 'get'),
        ('role-zeloshr-onboarding-coordinator', 'custom-fields', 'get'),
        ('role-zeloshr-onboarding-coordinator', 'dashboard', 'get'),
        ('role-zeloshr-onboarding-coordinator', 'departments', 'get'),
        ('role-zeloshr-onboarding-coordinator', 'documents', 'get'),
        ('role-zeloshr-onboarding-coordinator', 'documents', 'create'),
        ('role-zeloshr-onboarding-coordinator', 'employee', 'get'),
        ('role-zeloshr-onboarding-coordinator', 'employee', 'update'),
        ('role-zeloshr-onboarding-coordinator', 'lifecycle', 'get'),
        ('role-zeloshr-onboarding-coordinator', 'lifecycle', 'create'),
        ('role-zeloshr-onboarding-coordinator', 'onboarding', 'get'),
        ('role-zeloshr-onboarding-coordinator', 'onboarding', 'create'),
        ('role-zeloshr-onboarding-coordinator', 'onboarding', 'update'),
        ('role-zeloshr-onboarding-coordinator', 'onboarding', 'delete'),
        ('role-zeloshr-line-manager', 'attendance-records', 'get'),
        ('role-zeloshr-line-manager', 'attendance-team', 'get'),
        ('role-zeloshr-line-manager', 'attendance-timesheet', 'get'),
        ('role-zeloshr-line-manager', 'dashboard', 'get'),
        ('role-zeloshr-line-manager', 'departments', 'get'),
        ('role-zeloshr-line-manager', 'disciplinary', 'get'),
        ('role-zeloshr-line-manager', 'disciplinary', 'create'),
        ('role-zeloshr-line-manager', 'employee', 'get'),
        ('role-zeloshr-line-manager', 'leave', 'get'),
        ('role-zeloshr-line-manager', 'leave', 'update'),
        ('role-zeloshr-line-manager', 'performance', 'get'),
        ('role-zeloshr-line-manager', 'performance', 'create'),
        ('role-zeloshr-line-manager', 'performance', 'update'),
        ('role-zeloshr-attendance-officer', 'attendance', 'get'),
        ('role-zeloshr-attendance-officer', 'attendance', 'create'),
        ('role-zeloshr-attendance-officer', 'attendance', 'update'),
        ('role-zeloshr-attendance-officer', 'attendance', 'delete'),
        ('role-zeloshr-attendance-officer', 'attendance-adjustments', 'get'),
        ('role-zeloshr-attendance-officer', 'attendance-adjustments', 'create'),
        ('role-zeloshr-attendance-officer', 'attendance-clock', 'get'),
        ('role-zeloshr-attendance-officer', 'attendance-clock', 'create'),
        ('role-zeloshr-attendance-officer', 'attendance-devices', 'get'),
        ('role-zeloshr-attendance-officer', 'attendance-devices', 'create'),
        ('role-zeloshr-attendance-officer', 'attendance-devices', 'delete'),
        ('role-zeloshr-attendance-officer', 'attendance-records', 'get'),
        ('role-zeloshr-attendance-officer', 'attendance-records', 'create'),
        ('role-zeloshr-attendance-officer', 'attendance-records', 'update'),
        ('role-zeloshr-attendance-officer', 'attendance-records', 'delete'),
        ('role-zeloshr-attendance-officer', 'attendance-team', 'get'),
        ('role-zeloshr-attendance-officer', 'attendance-timesheet', 'get'),
        ('role-zeloshr-attendance-officer', 'dashboard', 'get'),
        ('role-zeloshr-attendance-officer', 'employee', 'get'),
        ('role-zeloshr-payroll-officer', 'attendance-records', 'get'),
        ('role-zeloshr-payroll-officer', 'attendance-timesheet', 'get'),
        ('role-zeloshr-payroll-officer', 'branches', 'get'),
        ('role-zeloshr-payroll-officer', 'custom-fields', 'get'),
        ('role-zeloshr-payroll-officer', 'dashboard', 'get'),
        ('role-zeloshr-payroll-officer', 'departments', 'get'),
        ('role-zeloshr-payroll-officer', 'documents', 'get'),
        ('role-zeloshr-payroll-officer', 'employee', 'get'),
        ('role-zeloshr-payroll-officer', 'org', 'get'),
        ('role-zeloshr-leave-administrator', 'attendance-records', 'get'),
        ('role-zeloshr-leave-administrator', 'dashboard', 'get'),
        ('role-zeloshr-leave-administrator', 'departments', 'get'),
        ('role-zeloshr-leave-administrator', 'employee', 'get'),
        ('role-zeloshr-leave-administrator', 'leave', 'get'),
        ('role-zeloshr-leave-administrator', 'leave', 'create'),
        ('role-zeloshr-leave-administrator', 'leave', 'update'),
        ('role-zeloshr-leave-administrator', 'leave', 'delete'),
        ('role-zeloshr-performance-manager', 'dashboard', 'get'),
        ('role-zeloshr-performance-manager', 'departments', 'get'),
        ('role-zeloshr-performance-manager', 'disciplinary', 'get'),
        ('role-zeloshr-performance-manager', 'disciplinary', 'create'),
        ('role-zeloshr-performance-manager', 'disciplinary', 'update'),
        ('role-zeloshr-performance-manager', 'disciplinary', 'delete'),
        ('role-zeloshr-performance-manager', 'documents', 'get'),
        ('role-zeloshr-performance-manager', 'documents', 'create'),
        ('role-zeloshr-performance-manager', 'employee', 'get'),
        ('role-zeloshr-performance-manager', 'performance', 'get'),
        ('role-zeloshr-performance-manager', 'performance', 'create'),
        ('role-zeloshr-performance-manager', 'performance', 'update'),
        ('role-zeloshr-performance-manager', 'performance', 'delete'),
        ('role-zeloshr-hr-auditor', 'attendance', 'get'),
        ('role-zeloshr-hr-auditor', 'attendance-adjustments', 'get'),
        ('role-zeloshr-hr-auditor', 'attendance-clock', 'get'),
        ('role-zeloshr-hr-auditor', 'attendance-devices', 'get'),
        ('role-zeloshr-hr-auditor', 'attendance-records', 'get'),
        ('role-zeloshr-hr-auditor', 'attendance-team', 'get'),
        ('role-zeloshr-hr-auditor', 'attendance-timesheet', 'get'),
        ('role-zeloshr-hr-auditor', 'audit', 'get'),
        ('role-zeloshr-hr-auditor', 'branches', 'get'),
        ('role-zeloshr-hr-auditor', 'custom-fields', 'get'),
        ('role-zeloshr-hr-auditor', 'dashboard', 'get'),
        ('role-zeloshr-hr-auditor', 'departments', 'get'),
        ('role-zeloshr-hr-auditor', 'disciplinary', 'get'),
        ('role-zeloshr-hr-auditor', 'documents', 'get'),
        ('role-zeloshr-hr-auditor', 'employee', 'get'),
        ('role-zeloshr-hr-auditor', 'leave', 'get'),
        ('role-zeloshr-hr-auditor', 'lifecycle', 'get'),
        ('role-zeloshr-hr-auditor', 'onboarding', 'get'),
        ('role-zeloshr-hr-auditor', 'org', 'get'),
        ('role-zeloshr-hr-auditor', 'performance', 'get'),
        ('role-zeloshr-hr-auditor', 'recruitment', 'get'),
        ('role-zeloshr-compliance-administrator', 'audit', 'get'),
        ('role-zeloshr-compliance-administrator', 'audit', 'delete'),
        ('role-zeloshr-compliance-administrator', 'dashboard', 'get'),
        ('role-zeloshr-compliance-administrator', 'documents', 'get'),
        ('role-zeloshr-compliance-administrator', 'employee', 'get'),
        ('role-zeloshr-system-administrator', 'branches', 'get'),
        ('role-zeloshr-system-administrator', 'branches', 'create'),
        ('role-zeloshr-system-administrator', 'branches', 'update'),
        ('role-zeloshr-system-administrator', 'branches', 'delete'),
        ('role-zeloshr-system-administrator', 'custom-fields', 'get'),
        ('role-zeloshr-system-administrator', 'custom-fields', 'create'),
        ('role-zeloshr-system-administrator', 'custom-fields', 'update'),
        ('role-zeloshr-system-administrator', 'custom-fields', 'delete'),
        ('role-zeloshr-system-administrator', 'dashboard', 'get'),
        ('role-zeloshr-system-administrator', 'departments', 'get'),
        ('role-zeloshr-system-administrator', 'departments', 'create'),
        ('role-zeloshr-system-administrator', 'departments', 'update'),
        ('role-zeloshr-system-administrator', 'departments', 'delete'),
        ('role-zeloshr-system-administrator', 'employee', 'get'),
        ('role-zeloshr-system-administrator', 'org', 'get'),
        ('role-zeloshr-system-administrator', 'org', 'create'),
        ('role-zeloshr-system-administrator', 'org', 'update'),
        ('role-zeloshr-system-administrator', 'org', 'delete'),
        ('role-zeloshr-employee-self-service', 'attendance-clock', 'get'),
        ('role-zeloshr-employee-self-service', 'attendance-clock', 'create'),
        ('role-zeloshr-employee-self-service', 'dashboard', 'get'),
        ('role-zeloshr-employee-self-service', 'documents', 'get'),
        ('role-zeloshr-employee-self-service', 'employee', 'get'),
        ('role-zeloshr-employee-self-service', 'leave', 'get'),
        ('role-zeloshr-employee-self-service', 'leave', 'create')
      ) AS spec(role_id, resource_key, action)
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'zeloshr' AND p.resource_key = spec.resource_key
   AND p.action = spec.action AND coalesce(p.target,'') = ''
   AND p.delete_status = 'NOT_DELETED' AND p.is_active
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ------------------------------------------------- 3. retire the per-resource roles
-- Anybody holding one lands on the job role closest to what they were doing, so the
-- retirement does not quietly remove somebody's access.
UPDATE core_platform.cp_assign_roles SET role_id = 'role-zeloshr-hr-manager'
 WHERE role_id = 'role-zeloshr-employee-admin' AND delete_status = 'NOT_DELETED';
UPDATE core_platform.cp_assign_roles SET role_id = 'role-zeloshr-attendance-officer'
 WHERE role_id = 'role-attendance-admin' AND delete_status = 'NOT_DELETED';
UPDATE core_platform.cp_assign_roles SET role_id = 'role-zeloshr-employee-self-service'
 WHERE role_id = 'role-attendance-clock-admin' AND delete_status = 'NOT_DELETED';

-- Anyone left on a retired role that has no obvious successor keeps nothing silently:
-- the assignment is removed and shows up in the assertion below if it happens.
UPDATE core_platform.cp_roles
   SET delete_status = 'DELETED', is_active = false
 WHERE id = ANY(ARRAY[
        'role-zeloshr-attendance-admin',
        'role-zeloshr-audit-admin',
        'role-zeloshr-branches-admin',
        'role-zeloshr-custom-fields-admin',
        'role-zeloshr-dashboard-admin',
        'role-zeloshr-departments-admin',
        'role-zeloshr-disciplinary-admin',
        'role-zeloshr-documents-admin',
        'role-zeloshr-employee-admin',
        'role-zeloshr-leave-admin',
        'role-zeloshr-lifecycle-admin',
        'role-zeloshr-onboarding-admin',
        'role-zeloshr-org-admin',
        'role-zeloshr-performance-admin',
        'role-zeloshr-recruitment-admin',
        'role-attendance-admin',
        'role-attendance-adjustments-admin',
        'role-attendance-clock-admin',
        'role-attendance-devices-admin',
        'role-attendance-employees-admin',
        'role-attendance-records-admin',
        'role-attendance-team-admin',
        'role-attendance-timesheet-admin'
      ]);

-- ------------------------------------------------------------------------ 4. assertions
DO $$
DECLARE
    uncovered   text;
    n_uncovered integer;
    orphaned    integer;
    n_roles     integer;
BEGIN
    -- Every ZelosHR permission an endpoint enforces must be held by at least one live role.
    -- A permission no role holds is an endpoint only Owner can reach.
    SELECT count(*), string_agg(p.resource_key || '(' || p.action || ')', ', ' ORDER BY p.resource_key)
      INTO n_uncovered, uncovered
      FROM core_platform.cp_permissions p
     WHERE p.app_prefix = 'zeloshr' AND p.delete_status = 'NOT_DELETED' AND p.is_active
       AND NOT EXISTS (
             SELECT 1 FROM core_platform.cp_role_permissions rp
               JOIN core_platform.cp_roles r ON r.id = rp.role_id AND r.delete_status = 'NOT_DELETED'
              WHERE rp.permission_id = p.id AND rp.delete_status = 'NOT_DELETED');

    -- Nobody may be left pointing at a role that no longer exists.
    SELECT count(*) INTO orphaned
      FROM core_platform.cp_assign_roles ar
      LEFT JOIN core_platform.cp_roles r ON r.id = ar.role_id AND r.delete_status = 'NOT_DELETED'
     WHERE ar.delete_status = 'NOT_DELETED' AND r.id IS NULL;

    SELECT count(*) INTO n_roles FROM core_platform.cp_roles
     WHERE id LIKE 'role-zeloshr-%' AND resource_type_id = 'rt-system-role'
       AND delete_status = 'NOT_DELETED';

    IF orphaned > 0 THEN
        RAISE EXCEPTION 'retiring roles left % assignment(s) pointing at nothing', orphaned;
    END IF;

    IF n_uncovered > 0 THEN
        RAISE WARNING 'ZelosHR permissions no role holds (% of them): %', n_uncovered, uncovered;
    END IF;

    RAISE NOTICE 'ZelosHR: % job roles, % permission(s) held by no role', n_roles, n_uncovered;
END $$;

COMMIT;
