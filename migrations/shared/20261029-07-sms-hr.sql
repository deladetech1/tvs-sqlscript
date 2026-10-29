-- MyEduGuard 16: human resources -- the full staff lifecycle.
--
--   sms_hr_settings              each school's staff day (start, late after), who is told of a
--                                late arrival, and the leave year
--   sms_departments              departments and their heads (who endorse their staff's leave)
--   sms_staff                    the staff record: bio data, employment, status (active,
--                                inactive, terminated); a staff account (user_id) is optional --
--                                a cleaner or a driver need not sign in
--   sms_staff_history            what changed in their employment, and when
--   sms_staff_qualifications     degrees, diplomas and certificates, verified or not
--   sms_staff_documents          contracts, work permits, visas, teaching licences (NTC, state,
--                                QTS) and certifications, with their expiry
--   sms_staff_checks             safer recruitment: police clearance, DBS, references, identity,
--                                right to work -- the single central record
--   sms_vacancies, _job_applications, _interviews
--                                recruitment: vacancies on the school's careers page,
--                                applications, interviews, offers and hiring
--   sms_staff_tasks, _equipment  onboarding and offboarding checklists, equipment issued and
--                                returned, exit clearance
--   sms_leave_types, _leave_entitlements, _staff_leave
--                                leave types, each year's entitlement, applications endorsed by the
--                                department head and approved by HR
--   sms_payslips                 payslips HR publishes, read by the member of staff
--   sms_appraisal_cycles, _appraisals, _lesson_observations
--                                goals, self and appraiser reviews and ratings; lesson observations
--
-- Staff attendance stays in sms_staff_checkins (20261028-07), which gains a half day.
-- Permissions sms|hr|get/mark/manage; the role MyEduGuard HR Manager. Idempotent.

BEGIN;

CREATE TABLE IF NOT EXISTS sms.sms_hr_settings (
    profile_id           text PRIMARY KEY REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    staff_starts_at      time NOT NULL DEFAULT '07:30',
    staff_late_after_min integer NOT NULL DEFAULT 15,
    late_sms             boolean NOT NULL DEFAULT false,
    late_notify_hr       boolean NOT NULL DEFAULT true,
    leave_year_starts    integer NOT NULL DEFAULT 1,
    staff_number_prefix  text NOT NULL DEFAULT 'STF',
    next_staff_number    integer NOT NULL DEFAULT 1,
    offer_letter         text,
    updated_at           timestamptz NOT NULL DEFAULT now(),
    CHECK (staff_late_after_min BETWEEN 0 AND 240 AND leave_year_starts BETWEEN 1 AND 12)
);

CREATE TABLE IF NOT EXISTS sms.sms_departments (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name          text NOT NULL,
    kind          text NOT NULL DEFAULT 'academic',
    head_staff_id text,
    description   text,
    archived_at   timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_departments DROP CONSTRAINT IF EXISTS sms_departments_kind_check;
ALTER TABLE sms.sms_departments ADD CONSTRAINT sms_departments_kind_check CHECK (kind IN ('academic', 'administration', 'support', 'boarding', 'other'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_departments_name_uq ON sms.sms_departments (profile_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_staff (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    bus_id              text NOT NULL,
    profile_id          text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    user_id             text,
    staff_number        text NOT NULL,
    title               text,
    first_name          text NOT NULL,
    last_name           text NOT NULL,
    other_names         text,
    gender              text,
    date_of_birth       date,
    nationality         text,
    national_id         text,
    phone               text,
    email               text,
    address             text,
    marital_status      text,
    emergency_name      text,
    emergency_phone     text,
    emergency_relation  text,
    job_title           text NOT NULL,
    category            text NOT NULL DEFAULT 'teaching',
    department_id       text REFERENCES sms.sms_departments(id) ON DELETE SET NULL,
    employment_type     text NOT NULL DEFAULT 'permanent',
    starts_on           date NOT NULL,
    probation_ends_on   date,
    ends_on             date,
    status              text NOT NULL DEFAULT 'active',
    exit_reason         text,
    exit_note           text,
    social_security_no  text,
    tax_id              text,
    bank_name           text,
    bank_account        text,
    bank_branch         text,
    notes               text,
    created_by          text,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_staff DROP CONSTRAINT IF EXISTS sms_staff_check2;
ALTER TABLE sms.sms_staff ADD CONSTRAINT sms_staff_check2
    CHECK (category IN ('teaching', 'non_teaching') AND status IN ('onboarding', 'active', 'inactive', 'offboarding', 'terminated')
           AND employment_type IN ('permanent', 'contract', 'part_time', 'temporary', 'volunteer', 'intern', 'national_service')
           AND (gender IS NULL OR gender IN ('male', 'female'))
           AND (exit_reason IS NULL OR exit_reason IN ('resigned', 'retired', 'dismissed', 'contract_ended', 'redundancy', 'deceased', 'transferred', 'other')));
CREATE UNIQUE INDEX IF NOT EXISTS sms_staff_number_uq ON sms.sms_staff (profile_id, upper(staff_number));
CREATE UNIQUE INDEX IF NOT EXISTS sms_staff_user_uq ON sms.sms_staff (profile_id, user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS sms_staff_idx ON sms.sms_staff (profile_id, status, last_name);

ALTER TABLE sms.sms_departments DROP CONSTRAINT IF EXISTS sms_departments_head_fk;
ALTER TABLE sms.sms_departments ADD CONSTRAINT sms_departments_head_fk FOREIGN KEY (head_staff_id) REFERENCES sms.sms_staff(id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS sms.sms_staff_history (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    staff_id      text NOT NULL REFERENCES sms.sms_staff(id) ON DELETE CASCADE,
    kind          text NOT NULL,
    summary       text NOT NULL,
    effective_on  date NOT NULL DEFAULT CURRENT_DATE,
    by_user       text,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_staff_history DROP CONSTRAINT IF EXISTS sms_staff_history_kind_check;
ALTER TABLE sms.sms_staff_history ADD CONSTRAINT sms_staff_history_kind_check
    CHECK (kind IN ('joined', 'job', 'department', 'employment', 'status', 'exit', 'note'));
CREATE INDEX IF NOT EXISTS sms_staff_history_idx ON sms.sms_staff_history (staff_id, effective_on DESC);

CREATE TABLE IF NOT EXISTS sms.sms_staff_qualifications (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    staff_id     text NOT NULL REFERENCES sms.sms_staff(id) ON DELETE CASCADE,
    level        text NOT NULL,
    title        text NOT NULL,
    institution  text,
    year         integer,
    verified     boolean NOT NULL DEFAULT false,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    CHECK (year IS NULL OR year BETWEEN 1940 AND 2100)
);
ALTER TABLE sms.sms_staff_qualifications DROP CONSTRAINT IF EXISTS sms_staff_qualifications_level_check;
ALTER TABLE sms.sms_staff_qualifications ADD CONSTRAINT sms_staff_qualifications_level_check
    CHECK (level IN ('certificate', 'diploma', 'degree', 'postgraduate', 'masters', 'doctorate', 'professional', 'other'));

CREATE TABLE IF NOT EXISTS sms.sms_staff_documents (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    staff_id    text NOT NULL REFERENCES sms.sms_staff(id) ON DELETE CASCADE,
    kind        text NOT NULL,
    title       text NOT NULL,
    number      text,
    issuer      text,
    issued_on   date,
    expires_on  date,
    note        text,
    alerted_on  date,
    added_by    text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    CHECK (expires_on IS NULL OR issued_on IS NULL OR expires_on >= issued_on)
);
ALTER TABLE sms.sms_staff_documents DROP CONSTRAINT IF EXISTS sms_staff_documents_kind_check;
ALTER TABLE sms.sms_staff_documents ADD CONSTRAINT sms_staff_documents_kind_check
    CHECK (kind IN ('contract', 'work_permit', 'visa', 'passport', 'teaching_licence', 'certification', 'other'));
CREATE INDEX IF NOT EXISTS sms_staff_documents_idx ON sms.sms_staff_documents (staff_id);
CREATE INDEX IF NOT EXISTS sms_staff_documents_expiry_idx ON sms.sms_staff_documents (expires_on) WHERE expires_on IS NOT NULL;

CREATE TABLE IF NOT EXISTS sms.sms_staff_checks (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    staff_id      text NOT NULL REFERENCES sms.sms_staff(id) ON DELETE CASCADE,
    kind          text NOT NULL,
    reference_no  text,
    checked_on    date,
    result        text NOT NULL DEFAULT 'pending',
    expires_on    date,
    checked_by    text,
    note          text,
    added_by      text,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_staff_checks ADD COLUMN IF NOT EXISTS alerted_on date;
ALTER TABLE sms.sms_staff_checks DROP CONSTRAINT IF EXISTS sms_staff_checks_check2;
ALTER TABLE sms.sms_staff_checks ADD CONSTRAINT sms_staff_checks_check2
    CHECK (kind IN ('police_clearance', 'dbs', 'references', 'identity', 'right_to_work', 'qualifications', 'medical', 'child_protection_training', 'prohibition', 'other')
           AND result IN ('pending', 'clear', 'concerns'));
CREATE INDEX IF NOT EXISTS sms_staff_checks_idx ON sms.sms_staff_checks (staff_id);

CREATE TABLE IF NOT EXISTS sms.sms_vacancies (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    profile_id       text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    title            text NOT NULL,
    department_id    text REFERENCES sms.sms_departments(id) ON DELETE SET NULL,
    category         text NOT NULL DEFAULT 'teaching',
    employment_type  text NOT NULL DEFAULT 'permanent',
    description      text,
    requirements     text,
    salary_range     text,
    positions        integer NOT NULL DEFAULT 1,
    closes_on        date,
    status           text NOT NULL DEFAULT 'draft',
    token            text NOT NULL DEFAULT replace(gen_random_uuid()::text, '-', ''),
    created_by       text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    CHECK (positions BETWEEN 1 AND 100)
);
ALTER TABLE sms.sms_vacancies DROP CONSTRAINT IF EXISTS sms_vacancies_status_check;
ALTER TABLE sms.sms_vacancies ADD CONSTRAINT sms_vacancies_status_check CHECK (status IN ('draft', 'open', 'closed', 'filled'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_vacancies_token_uq ON sms.sms_vacancies (token);

CREATE TABLE IF NOT EXISTS sms.sms_job_applications (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    vacancy_id     text NOT NULL REFERENCES sms.sms_vacancies(id) ON DELETE CASCADE,
    full_name      text NOT NULL,
    email          text NOT NULL,
    phone          text,
    cover_note     text,
    source         text NOT NULL DEFAULT 'careers_page',
    status         text NOT NULL DEFAULT 'new',
    rating         integer,
    notes          text,
    offer_salary   text,
    offer_start    date,
    offered_at     timestamptz,
    staff_id       text REFERENCES sms.sms_staff(id) ON DELETE SET NULL,
    ip             text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    CHECK (rating IS NULL OR rating BETWEEN 1 AND 5)
);
ALTER TABLE sms.sms_job_applications DROP CONSTRAINT IF EXISTS sms_job_applications_check2;
ALTER TABLE sms.sms_job_applications ADD CONSTRAINT sms_job_applications_check2
    CHECK (status IN ('new', 'shortlisted', 'interview', 'offered', 'hired', 'rejected', 'withdrawn') AND source IN ('careers_page', 'added'));
CREATE INDEX IF NOT EXISTS sms_job_applications_idx ON sms.sms_job_applications (vacancy_id, status);

CREATE TABLE IF NOT EXISTS sms.sms_interviews (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    application_id  text NOT NULL REFERENCES sms.sms_job_applications(id) ON DELETE CASCADE,
    at              timestamptz NOT NULL,
    place           text,
    panel           text[] NOT NULL DEFAULT '{}',
    outcome         text NOT NULL DEFAULT 'pending',
    score           integer,
    notes           text,
    by_user         text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    CHECK (score IS NULL OR score BETWEEN 0 AND 100)
);
ALTER TABLE sms.sms_interviews DROP CONSTRAINT IF EXISTS sms_interviews_outcome_check;
ALTER TABLE sms.sms_interviews ADD CONSTRAINT sms_interviews_outcome_check CHECK (outcome IN ('pending', 'passed', 'failed', 'no_show'));

CREATE TABLE IF NOT EXISTS sms.sms_staff_tasks (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    staff_id    text NOT NULL REFERENCES sms.sms_staff(id) ON DELETE CASCADE,
    kind        text NOT NULL,
    title       text NOT NULL,
    sort_order  integer NOT NULL DEFAULT 0,
    done_at     timestamptz,
    done_by     text,
    note        text
);
ALTER TABLE sms.sms_staff_tasks DROP CONSTRAINT IF EXISTS sms_staff_tasks_kind_check;
ALTER TABLE sms.sms_staff_tasks ADD CONSTRAINT sms_staff_tasks_kind_check CHECK (kind IN ('onboarding', 'offboarding'));
CREATE INDEX IF NOT EXISTS sms_staff_tasks_idx ON sms.sms_staff_tasks (staff_id, kind, sort_order);

CREATE TABLE IF NOT EXISTS sms.sms_staff_equipment (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    staff_id     text NOT NULL REFERENCES sms.sms_staff(id) ON DELETE CASCADE,
    item         text NOT NULL,
    serial       text,
    issued_on    date NOT NULL DEFAULT CURRENT_DATE,
    returned_on  date,
    condition    text,
    note         text,
    issued_by    text
);
CREATE INDEX IF NOT EXISTS sms_staff_equipment_idx ON sms.sms_staff_equipment (staff_id);

CREATE TABLE IF NOT EXISTS sms.sms_leave_types (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name            text NOT NULL,
    days_per_year   numeric(5,1) NOT NULL,
    paid            boolean NOT NULL DEFAULT true,
    needs_document  boolean NOT NULL DEFAULT false,
    carry_over_max  numeric(5,1) NOT NULL DEFAULT 0,
    gender          text,
    archived_at     timestamptz,
    CHECK (days_per_year >= 0 AND carry_over_max >= 0 AND (gender IS NULL OR gender IN ('male', 'female')))
);
CREATE UNIQUE INDEX IF NOT EXISTS sms_leave_types_name_uq ON sms.sms_leave_types (profile_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_leave_entitlements (
    staff_id    text NOT NULL REFERENCES sms.sms_staff(id) ON DELETE CASCADE,
    type_id     text NOT NULL REFERENCES sms.sms_leave_types(id) ON DELETE CASCADE,
    year        integer NOT NULL,
    days        numeric(5,1) NOT NULL,
    carried     numeric(5,1) NOT NULL DEFAULT 0,
    PRIMARY KEY (staff_id, type_id, year),
    CHECK (days >= 0 AND carried >= 0)
);

CREATE TABLE IF NOT EXISTS sms.sms_staff_leave (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    staff_id      text NOT NULL REFERENCES sms.sms_staff(id) ON DELETE CASCADE,
    type_id       text NOT NULL REFERENCES sms.sms_leave_types(id) ON DELETE CASCADE,
    starts_on     date NOT NULL,
    ends_on       date NOT NULL,
    half_day      boolean NOT NULL DEFAULT false,
    days          numeric(5,1) NOT NULL,
    leave_year    integer NOT NULL,
    reason        text,
    cover_note    text,
    status        text NOT NULL DEFAULT 'pending',
    endorsed_by   text,
    endorsed_at   timestamptz,
    decided_by    text,
    decided_at    timestamptz,
    decision_note text,
    applied_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    CHECK (ends_on >= starts_on AND days > 0)
);
ALTER TABLE sms.sms_staff_leave DROP CONSTRAINT IF EXISTS sms_staff_leave_status_check;
ALTER TABLE sms.sms_staff_leave ADD CONSTRAINT sms_staff_leave_status_check CHECK (status IN ('pending', 'endorsed', 'approved', 'declined', 'cancelled'));
CREATE INDEX IF NOT EXISTS sms_staff_leave_idx ON sms.sms_staff_leave (profile_id, status, starts_on);
CREATE INDEX IF NOT EXISTS sms_staff_leave_staff_idx ON sms.sms_staff_leave (staff_id, leave_year);

CREATE TABLE IF NOT EXISTS sms.sms_payslips (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    staff_id      text NOT NULL REFERENCES sms.sms_staff(id) ON DELETE CASCADE,
    period        text NOT NULL,
    gross         numeric(12,2),
    net           numeric(12,2),
    note          text,
    published_by  text,
    published_at  timestamptz NOT NULL DEFAULT now(),
    viewed_at     timestamptz,
    CHECK (period ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
    UNIQUE (staff_id, period)
);

CREATE TABLE IF NOT EXISTS sms.sms_appraisal_cycles (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name        text NOT NULL,
    starts_on   date NOT NULL,
    ends_on     date NOT NULL,
    status      text NOT NULL DEFAULT 'open',
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    CHECK (ends_on >= starts_on)
);
ALTER TABLE sms.sms_appraisal_cycles DROP CONSTRAINT IF EXISTS sms_appraisal_cycles_status_check;
ALTER TABLE sms.sms_appraisal_cycles ADD CONSTRAINT sms_appraisal_cycles_status_check CHECK (status IN ('open', 'closed'));

CREATE TABLE IF NOT EXISTS sms.sms_appraisals (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    cycle_id          text NOT NULL REFERENCES sms.sms_appraisal_cycles(id) ON DELETE CASCADE,
    staff_id          text NOT NULL REFERENCES sms.sms_staff(id) ON DELETE CASCADE,
    appraiser_user    text,
    goals             jsonb NOT NULL DEFAULT '[]',
    self_review       text,
    self_submitted_at timestamptz,
    appraiser_review  text,
    rating            integer,
    status            text NOT NULL DEFAULT 'goals',
    completed_at      timestamptz,
    acknowledged_at   timestamptz,
    staff_comment     text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    CHECK (rating IS NULL OR rating BETWEEN 1 AND 5),
    UNIQUE (cycle_id, staff_id)
);
ALTER TABLE sms.sms_appraisals DROP CONSTRAINT IF EXISTS sms_appraisals_status_check;
ALTER TABLE sms.sms_appraisals ADD CONSTRAINT sms_appraisals_status_check CHECK (status IN ('goals', 'self_review', 'review', 'completed'));

CREATE TABLE IF NOT EXISTS sms.sms_lesson_observations (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    profile_id     text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    staff_id       text NOT NULL REFERENCES sms.sms_staff(id) ON DELETE CASCADE,
    observer_user  text,
    observed_on    date NOT NULL,
    class_id       text,
    subject_id     text,
    focus          text,
    strengths      text,
    improvements   text,
    rating         integer,
    shared_at      timestamptz,
    staff_comment  text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    CHECK (rating IS NULL OR rating BETWEEN 1 AND 4)
);
CREATE INDEX IF NOT EXISTS sms_lesson_observations_idx ON sms.sms_lesson_observations (staff_id, observed_on DESC);

-- Staff attendance gains a half day.
ALTER TABLE sms.sms_staff_checkins DROP CONSTRAINT IF EXISTS sms_staff_checkins_status_check;
ALTER TABLE sms.sms_staff_checkins ADD CONSTRAINT sms_staff_checkins_status_check
    CHECK (status IN ('present', 'late', 'half_day', 'absent', 'sick', 'leave', 'duty') AND (in_at IS NOT NULL OR status IN ('absent', 'sick', 'leave', 'duty')));

-- The file manager's records: activities' (20261029-04, which left them out) and HR's.
ALTER TABLE sms.sms_files DROP CONSTRAINT IF EXISTS sms_files_entity_check;
ALTER TABLE sms.sms_files ADD CONSTRAINT sms_files_entity_check CHECK (entity_type IS NULL OR entity_type IN
    ('profile', 'application', 'enquiry', 'family', 'student', 'leave_request', 'assignment', 'submission', 'class_resource', 'pickup_person', 'incident',
     'safeguarding', 'achievement', 'service_hours', 'trip', 'staff', 'staff_document', 'staff_check', 'job_application', 'staff_leave', 'payslip'));

-- HR is a module a school can turn off (Settings, Modules).
ALTER TABLE sms.sms_profiles DROP CONSTRAINT IF EXISTS sms_profiles_modules_check;
ALTER TABLE sms.sms_profiles ADD CONSTRAINT sms_profiles_modules_check CHECK (modules IS NULL OR (cardinality(modules) > 0 AND modules <@ ARRAY[
    'admissions', 'teaching', 'scheduling', 'attendance', 'grading', 'learning', 'welfare', 'inclusion', 'boarding', 'library', 'activities', 'transport',
    'catering', 'hr']::text[]));

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-hr', 'MyEduGuard HR', 'Staff records, departments, recruitment, onboarding and offboarding, leave, contracts and checks, payslips and appraisals', 'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, action, label) AS (VALUES
    ('hr', 'get',    'View staff records, departments, recruitment, leave, contracts, checks and appraisals'),
    ('hr', 'mark',   'Observe lessons and appraise the staff one is given to appraise'),
    ('hr', 'manage', 'Keep staff records, recruit and hire, run onboarding and offboarding, approve leave, keep contracts and checks, publish payslips and run appraisals')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-sms-' || spec.resource_key || '-' || spec.action,
       'MyEduGuard ' || upper(spec.resource_key) || ' ' || initcap(spec.action),
       'rt-sms-hr', spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'sms',
       resource_key = substring(p.id FROM '^permission-sms-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-sms-%'
   AND (p.app_prefix IS DISTINCT FROM 'sms' OR p.action IS NULL);

INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-sms-hr', 'system-tenant-id', 'MyEduGuard HR Manager', 'Runs HR: staff records, departments, recruitment, onboarding and offboarding, leave, contracts and safer recruitment checks, payslips and appraisals', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name        = EXCLUDED.role_name,
                               description      = EXCLUDED.description,
                               resource_type_id = EXCLUDED.resource_type_id,
                               is_system        = EXCLUDED.is_system,
                               is_active        = EXCLUDED.is_active;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-sms-head' AS role_id, p2.resource_key, p2.action
      FROM core_platform.cp_permissions p2 WHERE p2.app_prefix = 'sms'
    UNION ALL
    SELECT 'role-sms-hr', k, a FROM (VALUES ('hr', 'get'), ('hr', 'mark'), ('hr', 'manage'), ('profiles', 'get'), ('structure', 'get'), ('attendance', 'get'),
        ('attendance', 'manage')) AS g(k, a)
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'sms' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- Staff records are confidential: the viewer, who reads everything else, reads no HR.
DELETE FROM core_platform.cp_role_permissions WHERE role_id = 'role-sms-viewer' AND permission_id LIKE 'permission-sms-hr-%';

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', 'role-sms-hr', p.id
  FROM core_platform.cp_permissions p
 WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.staff-records',   'app-sms', 'Staff Bio Data & Employment Records', 1, 'Active, inactive and terminated staff with documents and history'),
('sms.departments',     'app-sms', 'Departments, Roles & Privileges',     1, 'Departments, staff roles, user privileges, access restrictions and activity logs'),
('sms.recruitment',     'app-sms', 'Recruitment',                         2, 'Vacancies, applications, interviews and offer letters'),
('sms.onboarding',      'app-sms', 'Onboarding & Offboarding',            2, 'Checklists, equipment issue and exit clearance'),
('sms.staff-leave',     'app-sms', 'Leave Management',                    1, 'Leave types, entitlements, balances, applications and approval workflow'),
('sms.staff-documents', 'app-sms', 'Contracts, Licences & Safer Recruitment', 2, 'Contracts, work permits, visas, teaching licences and certifications with expiry alerts; police clearances and checks'),
('sms.payslips',        'app-sms', 'Staff Self Service & Payslips',       2, 'Payslips, leave balances, personal details and documents'),
('sms.appraisals',      'app-sms', 'Appraisals & Performance Reviews',    3, 'Goals, lesson observations, reviews and ratings')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id = EXCLUDED.app_id, title = EXCLUDED.title, min_tier_rank = EXCLUDED.min_tier_rank,
    description = EXCLUDED.description, is_active = true;

-- =================================================================== invariants
DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions p
     WHERE p.app_prefix = 'sms' AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                        WHERE rp.role_id = 'role-sms-head' AND rp.permission_id = p.id);
    IF n > 0 THEN
        RAISE EXCEPTION 'role-sms-head lacks % SMS permission(s)', n;
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id NOT IN ('role-sms-head', 'role-sms-hr') AND p.app_prefix = 'sms' AND p.resource_key = 'hr'
                  AND rp.role_id LIKE 'role-sms-%') THEN
        RAISE EXCEPTION 'staff records are for HR and the head';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-sms-hr' AND p.app_prefix = 'sms' AND p.resource_key IN ('counselling', 'safeguarding')) THEN
        RAISE EXCEPTION 'counselling records and safeguarding cases are for counsellors, safeguarding leads and the head';
    END IF;
END $$;

COMMIT;
