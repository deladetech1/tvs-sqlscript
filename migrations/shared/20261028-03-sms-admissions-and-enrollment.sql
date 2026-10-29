-- SMS: admissions and enrollment -- everything from first enquiry to a student's first day.
--
--   sms_families, sms_guardians   one family record linking siblings and their guardians, with
--                                  billing shared or not; families are the business's, so a
--                                  family with children at two of its schools is one family
--   sms_enquiries,
--   sms_enquiry_activities         enquiries from the website, walk-ins, calls and campaigns, and
--                                  each follow-up, until they apply or are lost
--   sms_admission_classes          the classes a school admits into for a year, with their seats
--                                  and application fee: what capacity and the waitlist count
--   sms_application_forms          each school's online application: its own questions, the
--                                  documents it asks for, the fee, and the portal's link
--   sms_admission_settings         the offer letter, how long an offer stands, waitlist promotion,
--                                  the student number
--   sms_applications               an applicant through submitted, assessed, offered or waitlisted
--                                  or rejected, accepted and enrolled; the parent follows it on
--                                  their own link
--   sms_assessments                entrance exams and interviews: when, where, who sits on the
--                                  panel, the score and the panel's notes
--   sms_contract_templates,
--   sms_signatures                 enrollment agreements, policies and consents, signed online
--   sms_students                   the enrolled: who they are, their family, class and number
--   sms_reenrollment_campaigns,
--   sms_reenrollments              each year's confirmation from current families, with deposits
--
-- Permissions sms|admissions|get/manage/decide and sms|students|get/manage, the SMS Admissions
-- Officer role, and the plan features. Idempotent; safe to re-run on every deploy.

BEGIN;

-- =================================================================== families
CREATE TABLE IF NOT EXISTS sms.sms_families (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    name            text NOT NULL,
    phone           text,
    email           text,
    address         text,
    shared_billing  boolean NOT NULL DEFAULT true,
    notes           text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz,
    created_by      text
);
CREATE INDEX IF NOT EXISTS sms_families_bus_idx ON sms.sms_families (bus_id, lower(name));

CREATE TABLE IF NOT EXISTS sms.sms_guardians (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    family_id       text NOT NULL REFERENCES sms.sms_families (id) ON DELETE CASCADE,
    full_name       text NOT NULL,
    relationship    text NOT NULL DEFAULT 'parent',
    phone           text,
    email           text,
    occupation      text,
    is_primary      boolean NOT NULL DEFAULT false,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sms_guardians_family_idx ON sms.sms_guardians (family_id);
CREATE INDEX IF NOT EXISTS sms_guardians_phone_idx ON sms.sms_guardians (bus_id, phone);
CREATE INDEX IF NOT EXISTS sms_guardians_email_idx ON sms.sms_guardians (bus_id, lower(email));

-- =================================================================== classes and forms
CREATE TABLE IF NOT EXISTS sms.sms_admission_classes (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    profile_id       text NOT NULL REFERENCES sms.sms_profiles (id),
    academic_year    text NOT NULL,
    name             text NOT NULL,
    level            text,
    seats            int NOT NULL DEFAULT 0 CHECK (seats >= 0),
    application_fee  numeric(14,2) NOT NULL DEFAULT 0 CHECK (application_fee >= 0),
    is_open          boolean NOT NULL DEFAULT true,
    sort_order       int NOT NULL DEFAULT 0,
    archived_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS sms_admission_classes_name_uq
    ON sms.sms_admission_classes (profile_id, academic_year, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_application_forms (
    profile_id       text PRIMARY KEY REFERENCES sms.sms_profiles (id),
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    title            text NOT NULL DEFAULT 'Application for admission',
    intro            text,
    academic_year    text,
    fields           jsonb NOT NULL DEFAULT '[]',
    documents        jsonb NOT NULL DEFAULT '[]',
    public_key       text NOT NULL,
    is_open          boolean NOT NULL DEFAULT false,
    closes_on        date,
    updated_at       timestamptz,
    updated_by       text
);
CREATE UNIQUE INDEX IF NOT EXISTS sms_application_forms_key_uq ON sms.sms_application_forms (public_key);

CREATE TABLE IF NOT EXISTS sms.sms_admission_settings (
    profile_id             text PRIMARY KEY REFERENCES sms.sms_profiles (id),
    tenant_id              text NOT NULL,
    bus_id                 text NOT NULL,
    offer_letter           text,
    offer_days             int NOT NULL DEFAULT 14 CHECK (offer_days BETWEEN 1 AND 365),
    auto_promote_waitlist  boolean NOT NULL DEFAULT true,
    student_prefix         text NOT NULL DEFAULT 'STU',
    next_student_number    int NOT NULL DEFAULT 1,
    updated_at             timestamptz
);

-- =================================================================== enquiries
CREATE TABLE IF NOT EXISTS sms.sms_enquiries (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    bus_id             text NOT NULL,
    profile_id         text NOT NULL REFERENCES sms.sms_profiles (id),
    code               text NOT NULL,
    guardian_name      text NOT NULL,
    phone              text,
    email              text,
    child_name         text,
    child_dob          date,
    child_gender       text,
    class_id           text REFERENCES sms.sms_admission_classes (id),
    academic_year      text,
    source             text NOT NULL DEFAULT 'walk_in',
    campaign           text,
    status             text NOT NULL DEFAULT 'new',
    lost_reason        text,
    assigned_to        text,
    next_follow_up_on  date,
    notes              text,
    family_id          text REFERENCES sms.sms_families (id),
    application_id     text,
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz,
    created_by         text
);
ALTER TABLE sms.sms_enquiries DROP CONSTRAINT IF EXISTS sms_enquiries_source_check;
ALTER TABLE sms.sms_enquiries ADD CONSTRAINT sms_enquiries_source_check
    CHECK (source IN ('website', 'walk_in', 'phone', 'campaign', 'referral', 'social', 'event', 'other'));
ALTER TABLE sms.sms_enquiries DROP CONSTRAINT IF EXISTS sms_enquiries_status_check;
ALTER TABLE sms.sms_enquiries ADD CONSTRAINT sms_enquiries_status_check
    CHECK (status IN ('new', 'contacted', 'visit_booked', 'visited', 'applied', 'lost'));
ALTER TABLE sms.sms_enquiries DROP CONSTRAINT IF EXISTS sms_enquiries_gender_check;
ALTER TABLE sms.sms_enquiries ADD CONSTRAINT sms_enquiries_gender_check CHECK (child_gender IS NULL OR child_gender IN ('male', 'female'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_enquiries_code_uq ON sms.sms_enquiries (bus_id, code);
CREATE INDEX IF NOT EXISTS sms_enquiries_profile_idx ON sms.sms_enquiries (profile_id, status, cdatetime DESC);

CREATE TABLE IF NOT EXISTS sms.sms_enquiry_activities (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    bus_id             text NOT NULL,
    enquiry_id         text NOT NULL REFERENCES sms.sms_enquiries (id) ON DELETE CASCADE,
    kind               text NOT NULL DEFAULT 'note',
    note               text NOT NULL,
    next_follow_up_on  date,
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    created_by         text
);
ALTER TABLE sms.sms_enquiry_activities DROP CONSTRAINT IF EXISTS sms_enquiry_activities_kind_check;
ALTER TABLE sms.sms_enquiry_activities ADD CONSTRAINT sms_enquiry_activities_kind_check
    CHECK (kind IN ('call', 'email', 'sms', 'whatsapp', 'visit', 'meeting', 'note'));
CREATE INDEX IF NOT EXISTS sms_enquiry_activities_idx ON sms.sms_enquiry_activities (enquiry_id, cdatetime DESC);

-- =================================================================== students
CREATE TABLE IF NOT EXISTS sms.sms_students (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    profile_id       text NOT NULL REFERENCES sms.sms_profiles (id),
    family_id        text REFERENCES sms.sms_families (id),
    student_number   text NOT NULL,
    first_name       text NOT NULL,
    last_name        text NOT NULL,
    other_names      text,
    date_of_birth    date,
    gender           text,
    nationality      text,
    class_id         text REFERENCES sms.sms_admission_classes (id),
    class_name       text,
    academic_year    text,
    status           text NOT NULL DEFAULT 'active',
    admitted_on      date NOT NULL DEFAULT CURRENT_DATE,
    application_id   text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz,
    created_by       text
);
SELECT sms.widen_check('sms.sms_students', 'sms_students_status_check', $q$'graduated'$q$, $q$CHECK (status IN ('active', 'withdrawn', 'graduated'))$q$);
ALTER TABLE sms.sms_students DROP CONSTRAINT IF EXISTS sms_students_gender_check;
ALTER TABLE sms.sms_students ADD CONSTRAINT sms_students_gender_check CHECK (gender IS NULL OR gender IN ('male', 'female'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_students_number_uq ON sms.sms_students (bus_id, student_number);
CREATE INDEX IF NOT EXISTS sms_students_profile_idx ON sms.sms_students (profile_id, status);
CREATE INDEX IF NOT EXISTS sms_students_family_idx ON sms.sms_students (family_id);

-- =================================================================== applications
CREATE TABLE IF NOT EXISTS sms.sms_applications (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    profile_id        text NOT NULL REFERENCES sms.sms_profiles (id),
    code              text NOT NULL,
    class_id          text NOT NULL REFERENCES sms.sms_admission_classes (id),
    academic_year     text NOT NULL,
    family_id         text REFERENCES sms.sms_families (id),
    enquiry_id        text REFERENCES sms.sms_enquiries (id),
    first_name        text NOT NULL,
    last_name         text NOT NULL,
    other_names       text,
    date_of_birth     date,
    gender            text,
    nationality       text,
    previous_school   text,
    guardian_name     text NOT NULL,
    guardian_relationship text NOT NULL DEFAULT 'parent',
    guardian_phone    text,
    guardian_email    text,
    answers           jsonb NOT NULL DEFAULT '{}',
    source            text NOT NULL DEFAULT 'walk_in',
    status            text NOT NULL DEFAULT 'submitted',
    fee_amount        numeric(14,2) NOT NULL DEFAULT 0,
    fee_paid_at       timestamptz,
    fee_method        text,
    fee_reference     text,
    decision_note     text,
    decided_by        text,
    decided_at        timestamptz,
    waitlisted_at     timestamptz,
    offered_at        timestamptz,
    offer_expires_on  date,
    offer_letter      text,
    accepted_at       timestamptz,
    accepted_name     text,
    closed_at         timestamptz,
    enrolled_at       timestamptz,
    student_id        text REFERENCES sms.sms_students (id),
    portal_token      text NOT NULL,
    submitted_at      timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz,
    created_by        text
);
ALTER TABLE sms.sms_applications DROP CONSTRAINT IF EXISTS sms_applications_status_check;
ALTER TABLE sms.sms_applications ADD CONSTRAINT sms_applications_status_check
    CHECK (status IN ('submitted', 'under_review', 'assessment', 'offered', 'waitlisted', 'rejected', 'accepted', 'declined', 'withdrawn', 'enrolled'));
ALTER TABLE sms.sms_applications DROP CONSTRAINT IF EXISTS sms_applications_gender_check;
ALTER TABLE sms.sms_applications ADD CONSTRAINT sms_applications_gender_check CHECK (gender IS NULL OR gender IN ('male', 'female'));
ALTER TABLE sms.sms_applications DROP CONSTRAINT IF EXISTS sms_applications_source_check;
ALTER TABLE sms.sms_applications ADD CONSTRAINT sms_applications_source_check
    CHECK (source IN ('website', 'walk_in', 'phone', 'campaign', 'referral', 'social', 'event', 'other'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_applications_code_uq ON sms.sms_applications (bus_id, code);
CREATE UNIQUE INDEX IF NOT EXISTS sms_applications_token_uq ON sms.sms_applications (portal_token);
CREATE INDEX IF NOT EXISTS sms_applications_profile_idx ON sms.sms_applications (profile_id, academic_year, status);
CREATE INDEX IF NOT EXISTS sms_applications_class_idx ON sms.sms_applications (class_id, status, waitlisted_at);
CREATE INDEX IF NOT EXISTS sms_applications_family_idx ON sms.sms_applications (family_id);

CREATE TABLE IF NOT EXISTS sms.sms_assessments (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    application_id  text NOT NULL REFERENCES sms.sms_applications (id) ON DELETE CASCADE,
    kind            text NOT NULL DEFAULT 'exam',
    title           text NOT NULL,
    scheduled_at    timestamptz NOT NULL,
    duration_min    int NOT NULL DEFAULT 60 CHECK (duration_min BETWEEN 5 AND 600),
    venue           text,
    panel           text[] NOT NULL DEFAULT '{}',
    status          text NOT NULL DEFAULT 'scheduled',
    score           numeric(7,2),
    max_score       numeric(7,2),
    result          text,
    notes           text,
    panel_notes     jsonb NOT NULL DEFAULT '[]',
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz,
    created_by      text
);
ALTER TABLE sms.sms_assessments DROP CONSTRAINT IF EXISTS sms_assessments_kind_check;
ALTER TABLE sms.sms_assessments ADD CONSTRAINT sms_assessments_kind_check CHECK (kind IN ('exam', 'interview'));
ALTER TABLE sms.sms_assessments DROP CONSTRAINT IF EXISTS sms_assessments_status_check;
ALTER TABLE sms.sms_assessments ADD CONSTRAINT sms_assessments_status_check CHECK (status IN ('scheduled', 'completed', 'absent', 'cancelled'));
ALTER TABLE sms.sms_assessments DROP CONSTRAINT IF EXISTS sms_assessments_result_check;
ALTER TABLE sms.sms_assessments ADD CONSTRAINT sms_assessments_result_check CHECK (result IS NULL OR result IN ('pass', 'borderline', 'fail'));
CREATE INDEX IF NOT EXISTS sms_assessments_app_idx ON sms.sms_assessments (application_id);
CREATE INDEX IF NOT EXISTS sms_assessments_when_idx ON sms.sms_assessments (bus_id, scheduled_at);

-- =================================================================== contracts
CREATE TABLE IF NOT EXISTS sms.sms_contract_templates (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles (id),
    kind          text NOT NULL DEFAULT 'agreement',
    title         text NOT NULL,
    body          text NOT NULL,
    required      boolean NOT NULL DEFAULT true,
    is_active     boolean NOT NULL DEFAULT true,
    sort_order    int NOT NULL DEFAULT 0,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz
);
ALTER TABLE sms.sms_contract_templates DROP CONSTRAINT IF EXISTS sms_contract_templates_kind_check;
ALTER TABLE sms.sms_contract_templates ADD CONSTRAINT sms_contract_templates_kind_check CHECK (kind IN ('agreement', 'policy', 'consent'));

CREATE TABLE IF NOT EXISTS sms.sms_signatures (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    application_id  text NOT NULL REFERENCES sms.sms_applications (id) ON DELETE CASCADE,
    template_id     text NOT NULL REFERENCES sms.sms_contract_templates (id),
    title           text NOT NULL,
    body            text NOT NULL,
    signed_name     text NOT NULL,
    signed_at       timestamptz NOT NULL DEFAULT now(),
    channel         text NOT NULL DEFAULT 'online',
    ip_address      text,
    user_agent      text,
    recorded_by     text
);
ALTER TABLE sms.sms_signatures DROP CONSTRAINT IF EXISTS sms_signatures_channel_check;
ALTER TABLE sms.sms_signatures ADD CONSTRAINT sms_signatures_channel_check CHECK (channel IN ('online', 'paper'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_signatures_uq ON sms.sms_signatures (application_id, template_id);

-- =================================================================== re-enrollment
CREATE TABLE IF NOT EXISTS sms.sms_reenrollment_campaigns (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles (id),
    title           text NOT NULL,
    academic_year   text NOT NULL,
    opens_on        date NOT NULL,
    closes_on       date NOT NULL,
    deposit_amount  numeric(14,2) NOT NULL DEFAULT 0 CHECK (deposit_amount >= 0),
    message         text,
    status          text NOT NULL DEFAULT 'draft',
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz,
    created_by      text,
    CHECK (closes_on >= opens_on)
);
ALTER TABLE sms.sms_reenrollment_campaigns DROP CONSTRAINT IF EXISTS sms_reenrollment_campaigns_status_check;
ALTER TABLE sms.sms_reenrollment_campaigns ADD CONSTRAINT sms_reenrollment_campaigns_status_check CHECK (status IN ('draft', 'open', 'closed'));

CREATE TABLE IF NOT EXISTS sms.sms_reenrollments (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    bus_id             text NOT NULL,
    campaign_id        text NOT NULL REFERENCES sms.sms_reenrollment_campaigns (id) ON DELETE CASCADE,
    student_id         text NOT NULL REFERENCES sms.sms_students (id),
    token              text NOT NULL,
    status             text NOT NULL DEFAULT 'pending',
    next_class         text,
    response_note      text,
    signed_name        text,
    responded_at       timestamptz,
    deposit_paid       numeric(14,2) NOT NULL DEFAULT 0,
    deposit_method     text,
    deposit_reference  text,
    deposit_paid_at    timestamptz,
    cdatetime          timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_reenrollments DROP CONSTRAINT IF EXISTS sms_reenrollments_status_check;
ALTER TABLE sms.sms_reenrollments ADD CONSTRAINT sms_reenrollments_status_check CHECK (status IN ('pending', 'confirmed', 'declined'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_reenrollments_uq ON sms.sms_reenrollments (campaign_id, student_id);
CREATE UNIQUE INDEX IF NOT EXISTS sms_reenrollments_token_uq ON sms.sms_reenrollments (token);

-- =================================================================== files
-- 20261028-02 created the entity check for profiles only; this file owns it from here on.
SELECT sms.widen_check('sms.sms_files', 'sms_files_entity_check', $q$'student'$q$, $q$CHECK (entity_type IS NULL OR entity_type IN
    ('profile', 'application', 'enquiry', 'family', 'student'))$q$);

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-admissions', 'SMS Admissions', 'Enquiries, applications, assessments, offers, capacity and re-enrollment', 'rt-subscribed-app-sms'),
('rt-sms-students',   'SMS Students',   'Enrolled students and their families',                                   'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

-- "decide" is a verb that changes data.
INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('decide', 'Decide', false, false)
ON CONFLICT (action) DO NOTHING;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('admissions', 'rt-sms-admissions', 'get',    'View enquiries, applications, assessments and admission reports'),
    ('admissions', 'rt-sms-admissions', 'manage', 'Take enquiries and applications, schedule assessments, set up forms, classes and re-enrollment'),
    ('admissions', 'rt-sms-admissions', 'decide', 'Offer, waitlist or reject applicants and enroll them'),
    ('students',   'rt-sms-students',   'get',    'View students and families'),
    ('students',   'rt-sms-students',   'manage', 'Change students and families')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-sms-' || spec.resource_key || '-' || spec.action,
       'SMS ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
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
('role-sms-admissions', 'system-tenant-id', 'SMS Admissions Officer', 'Takes enquiries and applications, schedules assessments and follows families up; offers and enrollment stay with the head', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name = EXCLUDED.role_name, description = EXCLUDED.description,
                               resource_type_id = EXCLUDED.resource_type_id, is_system = EXCLUDED.is_system, is_active = EXCLUDED.is_active;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-sms-head' AS role_id, p2.resource_key, p2.action
      FROM core_platform.cp_permissions p2 WHERE p2.app_prefix = 'sms'
    UNION ALL
    SELECT 'role-sms-admissions', k, a FROM (VALUES
        ('admissions', 'get'), ('admissions', 'manage'), ('students', 'get'), ('profiles', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-registrar', k, a FROM (VALUES
        ('admissions', 'get'), ('students', 'get'), ('students', 'manage')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-viewer', p3.resource_key, p3.action
      FROM core_platform.cp_permissions p3
      JOIN core_platform.cp_actions a ON a.action = p3.action AND a.is_read_only AND p3.action <> 'export'
     WHERE p3.app_prefix = 'sms'
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'sms' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', 'role-sms-admissions', p.id
  FROM core_platform.cp_permissions p
 WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.admissions',        'app-sms', 'Admissions',               1, 'Enquiries and follow-ups, applications, decisions, offer letters, capacity and the waitlist'),
('sms.assessments',       'app-sms', 'Entrance Assessments',     1, 'Entrance exams and interviews with scores and panel notes'),
('sms.families',          'app-sms', 'Families & Students',      1, 'One family record for siblings and guardians, and the enrolled students'),
('sms.admission-reports', 'app-sms', 'Admission Statistics',     1, 'The funnel and enrollment by class, school, gender, nationality and source'),
('sms.online-portal',     'app-sms', 'Online Application Portal',2, 'A public application form with its own questions, documents and fee, and status tracking for parents'),
('sms.contracts',         'app-sms', 'Enrollment Contracts',     2, 'Agreements, policies and consents signed online'),
('sms.reenrollment',      'app-sms', 'Re-enrollment Campaigns',  2, 'Each year''s confirmation from current families, with deposits')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id = EXCLUDED.app_id, title = EXCLUDED.title, min_tier_rank = EXCLUDED.min_tier_rank,
    description = EXCLUDED.description, is_active = true;

-- =================================================================== invariants
DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
     WHERE rp.role_id = 'role-sms-admissions' AND p.app_prefix = 'sms' AND p.resource_key = 'admissions' AND p.action = 'decide';
    IF n > 0 THEN
        RAISE EXCEPTION 'the SMS Admissions Officer may not decide admissions';
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_permissions p
     WHERE p.app_prefix = 'sms' AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                        WHERE rp.role_id = 'role-sms-head' AND rp.permission_id = p.id);
    IF n > 0 THEN
        RAISE EXCEPTION 'role-sms-head lacks % SMS permission(s)', n;
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-sms-viewer' AND p.app_prefix = 'sms' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-sms-viewer holds % SMS permission(s) that change data', n;
    END IF;
END $$;

COMMIT;
