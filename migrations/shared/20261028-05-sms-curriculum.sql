-- SMS: academic structure and curriculum -- supporting any curriculum, in any country.
--
--   sms_academic_years, sms_terms   flexible calendars: terms, trimesters, semesters or quarters,
--                                   for Northern or Southern hemisphere years (a year from
--                                   September, or from January)
--   sms_curricula                   national, Cambridge, IB, American, British and other
--                                   curricula side by side in one school; classes and subjects
--                                   say which they follow
--   sms_standards                   standards and learning outcomes (Common Core, IB criteria,
--                                   national standards) that topics and lessons are tagged with
--   sms_scheme_units, _topics       the scheme of work: units and topics with their learning
--                                   objectives, mapped to year groups (so classes), terms and weeks
--   sms_lesson_plans                lessons teachers create, submit and get approved
--   sms_option_blocks, _subjects,
--   sms_option_choices              electives and pathways students choose, with capacity and
--                                   prerequisites
--   sms_student_subjects            what each student takes each year, and what they completed
--   sms_graduation_requirements     credits required by category, for American-style high schools
--   sms_subjects (more columns)     curriculum, department, category and credit hours
--
-- Permissions sms|curriculum|get/manage, sms|lessons|get/create/approve, sms|options|get/manage;
-- the SMS Teacher role; plan features. Idempotent.

BEGIN;

-- =================================================================== calendar
CREATE TABLE IF NOT EXISTS sms.sms_academic_years (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles (id),
    name        text NOT NULL,
    starts_on   date NOT NULL,
    ends_on     date NOT NULL,
    hemisphere  text NOT NULL DEFAULT 'north',
    calendar    text NOT NULL DEFAULT 'terms',
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    CHECK (ends_on > starts_on)
);
ALTER TABLE sms.sms_academic_years DROP CONSTRAINT IF EXISTS sms_academic_years_hemisphere_check;
ALTER TABLE sms.sms_academic_years ADD CONSTRAINT sms_academic_years_hemisphere_check CHECK (hemisphere IN ('north', 'south'));
ALTER TABLE sms.sms_academic_years DROP CONSTRAINT IF EXISTS sms_academic_years_calendar_check;
ALTER TABLE sms.sms_academic_years ADD CONSTRAINT sms_academic_years_calendar_check CHECK (calendar IN ('terms', 'trimesters', 'semesters', 'quarters', 'custom'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_academic_years_name_uq ON sms.sms_academic_years (profile_id, name);

CREATE TABLE IF NOT EXISTS sms.sms_terms (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    year_id     text NOT NULL REFERENCES sms.sms_academic_years (id) ON DELETE CASCADE,
    name        text NOT NULL,
    starts_on   date NOT NULL,
    ends_on     date NOT NULL,
    sort_order  int NOT NULL DEFAULT 0,
    break_from  date,
    break_to    date,
    CHECK (ends_on > starts_on)
);
CREATE UNIQUE INDEX IF NOT EXISTS sms_terms_name_uq ON sms.sms_terms (year_id, lower(name));

-- =================================================================== curricula and standards
CREATE TABLE IF NOT EXISTS sms.sms_curricula (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles (id),
    name         text NOT NULL,
    framework    text NOT NULL DEFAULT 'national',
    description  text,
    is_default   boolean NOT NULL DEFAULT false,
    archived_at  timestamptz,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_curricula DROP CONSTRAINT IF EXISTS sms_curricula_framework_check;
ALTER TABLE sms.sms_curricula ADD CONSTRAINT sms_curricula_framework_check
    CHECK (framework IN ('national', 'cambridge', 'ib', 'american', 'british', 'french', 'montessori', 'other'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_curricula_name_uq ON sms.sms_curricula (profile_id, lower(name)) WHERE archived_at IS NULL;

ALTER TABLE sms.sms_classes ADD COLUMN IF NOT EXISTS curriculum_id text REFERENCES sms.sms_curricula (id);
ALTER TABLE sms.sms_subjects ADD COLUMN IF NOT EXISTS curriculum_id text REFERENCES sms.sms_curricula (id);
ALTER TABLE sms.sms_subjects ADD COLUMN IF NOT EXISTS department text;
ALTER TABLE sms.sms_subjects ADD COLUMN IF NOT EXISTS category text;
ALTER TABLE sms.sms_subjects ADD COLUMN IF NOT EXISTS credit_hours numeric(5,2) CHECK (credit_hours IS NULL OR credit_hours >= 0);

CREATE TABLE IF NOT EXISTS sms.sms_standards (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    profile_id     text NOT NULL REFERENCES sms.sms_profiles (id),
    framework      text NOT NULL,
    code           text NOT NULL,
    description    text NOT NULL,
    curriculum_id  text REFERENCES sms.sms_curricula (id),
    subject_id     text REFERENCES sms.sms_subjects (id),
    year_group_id  text REFERENCES sms.sms_year_groups (id),
    archived_at    timestamptz,
    cdatetime      timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS sms_standards_code_uq ON sms.sms_standards (profile_id, lower(framework), lower(code)) WHERE archived_at IS NULL;

-- =================================================================== scheme of work
CREATE TABLE IF NOT EXISTS sms.sms_scheme_units (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    profile_id     text NOT NULL REFERENCES sms.sms_profiles (id),
    academic_year  text NOT NULL,
    subject_id     text NOT NULL REFERENCES sms.sms_subjects (id),
    year_group_id  text NOT NULL REFERENCES sms.sms_year_groups (id),
    term_id        text REFERENCES sms.sms_terms (id) ON DELETE SET NULL,
    title          text NOT NULL,
    summary        text,
    week_from      int CHECK (week_from IS NULL OR week_from BETWEEN 1 AND 60),
    week_to        int CHECK (week_to IS NULL OR week_to BETWEEN 1 AND 60),
    sort_order     int NOT NULL DEFAULT 0,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text
);
CREATE INDEX IF NOT EXISTS sms_scheme_units_idx ON sms.sms_scheme_units (profile_id, academic_year, subject_id, year_group_id);

CREATE TABLE IF NOT EXISTS sms.sms_scheme_topics (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    unit_id       text NOT NULL REFERENCES sms.sms_scheme_units (id) ON DELETE CASCADE,
    title         text NOT NULL,
    week          int CHECK (week IS NULL OR week BETWEEN 1 AND 60),
    objectives    text[] NOT NULL DEFAULT '{}',
    standard_ids  text[] NOT NULL DEFAULT '{}',
    resources     text,
    sort_order    int NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS sms_scheme_topics_idx ON sms.sms_scheme_topics (unit_id, sort_order);

-- =================================================================== lesson plans
CREATE TABLE IF NOT EXISTS sms.sms_lesson_plans (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    profile_id       text NOT NULL REFERENCES sms.sms_profiles (id),
    class_id         text NOT NULL REFERENCES sms.sms_classes (id),
    subject_id       text NOT NULL REFERENCES sms.sms_subjects (id),
    topic_id         text REFERENCES sms.sms_scheme_topics (id) ON DELETE SET NULL,
    teacher_id       text NOT NULL,
    lesson_date      date NOT NULL,
    period           text,
    duration_min     int NOT NULL DEFAULT 40 CHECK (duration_min BETWEEN 5 AND 480),
    title            text NOT NULL,
    objectives       text,
    activities       text,
    resources        text,
    assessment       text,
    homework         text,
    differentiation  text,
    standard_ids     text[] NOT NULL DEFAULT '{}',
    status           text NOT NULL DEFAULT 'draft',
    submitted_at     timestamptz,
    reviewed_by      text,
    reviewed_at      timestamptz,
    review_note      text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz
);
ALTER TABLE sms.sms_lesson_plans DROP CONSTRAINT IF EXISTS sms_lesson_plans_status_check;
ALTER TABLE sms.sms_lesson_plans ADD CONSTRAINT sms_lesson_plans_status_check CHECK (status IN ('draft', 'submitted', 'approved', 'returned'));
CREATE INDEX IF NOT EXISTS sms_lesson_plans_idx ON sms.sms_lesson_plans (profile_id, lesson_date, status);
CREATE INDEX IF NOT EXISTS sms_lesson_plans_teacher_idx ON sms.sms_lesson_plans (teacher_id, lesson_date);

-- =================================================================== options and electives
CREATE TABLE IF NOT EXISTS sms.sms_option_blocks (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles (id),
    academic_year   text NOT NULL,
    name            text NOT NULL,
    description     text,
    year_group_ids  text[] NOT NULL DEFAULT '{}',
    min_choices     int NOT NULL DEFAULT 1 CHECK (min_choices >= 0),
    max_choices     int NOT NULL DEFAULT 1 CHECK (max_choices >= 1),
    opens_on        date,
    closes_on       date,
    status          text NOT NULL DEFAULT 'draft',
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    CHECK (max_choices >= min_choices)
);
ALTER TABLE sms.sms_option_blocks DROP CONSTRAINT IF EXISTS sms_option_blocks_status_check;
ALTER TABLE sms.sms_option_blocks ADD CONSTRAINT sms_option_blocks_status_check CHECK (status IN ('draft', 'open', 'closed', 'allocated'));

CREATE TABLE IF NOT EXISTS sms.sms_option_subjects (
    id                    text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    block_id              text NOT NULL REFERENCES sms.sms_option_blocks (id) ON DELETE CASCADE,
    subject_id            text NOT NULL REFERENCES sms.sms_subjects (id),
    pathway               text,
    capacity              int CHECK (capacity IS NULL OR capacity >= 0),
    prerequisite_ids      text[] NOT NULL DEFAULT '{}'
);
CREATE UNIQUE INDEX IF NOT EXISTS sms_option_subjects_uq ON sms.sms_option_subjects (block_id, subject_id);

CREATE TABLE IF NOT EXISTS sms.sms_option_choices (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    block_id           text NOT NULL REFERENCES sms.sms_option_blocks (id) ON DELETE CASCADE,
    option_subject_id  text NOT NULL REFERENCES sms.sms_option_subjects (id) ON DELETE CASCADE,
    student_id         text NOT NULL REFERENCES sms.sms_students (id),
    preference         int NOT NULL DEFAULT 1,
    status             text NOT NULL DEFAULT 'requested',
    note               text,
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    decided_at         timestamptz
);
ALTER TABLE sms.sms_option_choices DROP CONSTRAINT IF EXISTS sms_option_choices_status_check;
ALTER TABLE sms.sms_option_choices ADD CONSTRAINT sms_option_choices_status_check CHECK (status IN ('requested', 'allocated', 'waitlisted', 'refused'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_option_choices_uq ON sms.sms_option_choices (option_subject_id, student_id);
CREATE INDEX IF NOT EXISTS sms_option_choices_block_idx ON sms.sms_option_choices (block_id, student_id);

-- =================================================================== subjects taken and credits
CREATE TABLE IF NOT EXISTS sms.sms_student_subjects (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    student_id      text NOT NULL REFERENCES sms.sms_students (id) ON DELETE CASCADE,
    subject_id      text NOT NULL REFERENCES sms.sms_subjects (id),
    academic_year   text NOT NULL,
    source          text NOT NULL DEFAULT 'manual',
    status          text NOT NULL DEFAULT 'enrolled',
    credits_earned  numeric(5,2),
    grade           text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz
);
ALTER TABLE sms.sms_student_subjects DROP CONSTRAINT IF EXISTS sms_student_subjects_source_check;
ALTER TABLE sms.sms_student_subjects ADD CONSTRAINT sms_student_subjects_source_check CHECK (source IN ('core', 'elective', 'manual', 'transfer'));
ALTER TABLE sms.sms_student_subjects DROP CONSTRAINT IF EXISTS sms_student_subjects_status_check;
ALTER TABLE sms.sms_student_subjects ADD CONSTRAINT sms_student_subjects_status_check CHECK (status IN ('enrolled', 'completed', 'failed', 'dropped'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_student_subjects_uq ON sms.sms_student_subjects (student_id, subject_id, academic_year);

CREATE TABLE IF NOT EXISTS sms.sms_graduation_requirements (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    profile_id        text NOT NULL REFERENCES sms.sms_profiles (id),
    curriculum_id     text REFERENCES sms.sms_curricula (id),
    name              text NOT NULL,
    category          text,
    credits_required  numeric(6,2) NOT NULL CHECK (credits_required > 0),
    sort_order        int NOT NULL DEFAULT 0,
    archived_at       timestamptz
);

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-curriculum', 'SMS Curriculum',   'The calendar, curricula, standards, scheme of work and credit requirements', 'rt-subscribed-app-sms'),
('rt-sms-lessons',    'SMS Lesson Plans', 'Lesson plans created, submitted and approved',                              'rt-subscribed-app-sms'),
('rt-sms-options',    'SMS Options',      'Subject options, electives and pathways',                                    'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('approve', 'Approve', false, false)
ON CONFLICT (action) DO NOTHING;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('curriculum', 'rt-sms-curriculum', 'get',     'View the calendar, curricula, standards, scheme of work and credits'),
    ('curriculum', 'rt-sms-curriculum', 'manage',  'Set up the calendar, curricula, standards, scheme of work and credit requirements'),
    ('lessons',    'rt-sms-lessons',    'get',     'View every lesson plan'),
    ('lessons',    'rt-sms-lessons',    'create',  'Write and submit lesson plans'),
    ('lessons',    'rt-sms-lessons',    'approve', 'Approve or return lesson plans'),
    ('options',    'rt-sms-options',    'get',     'View subject options and choices'),
    ('options',    'rt-sms-options',    'manage',  'Set up subject options, record choices and allocate places')
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
('role-sms-teacher', 'system-tenant-id', 'SMS Teacher', 'Reads the structure, curriculum and students, and writes and submits lesson plans', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name = EXCLUDED.role_name, description = EXCLUDED.description,
                               resource_type_id = EXCLUDED.resource_type_id, is_system = EXCLUDED.is_system, is_active = EXCLUDED.is_active;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-sms-head' AS role_id, p2.resource_key, p2.action
      FROM core_platform.cp_permissions p2 WHERE p2.app_prefix = 'sms'
    UNION ALL
    SELECT 'role-sms-teacher', k, a FROM (VALUES
        ('structure', 'get'), ('curriculum', 'get'), ('lessons', 'create'), ('students', 'get'), ('profiles', 'get'), ('options', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-registrar', k, a FROM (VALUES ('curriculum', 'get'), ('options', 'get'), ('options', 'manage')) AS g(k, a)
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
SELECT 'system-tenant-id', 'role-sms-teacher', p.id
  FROM core_platform.cp_permissions p
 WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.calendar',         'app-sms', 'Academic Calendar',        1, 'Academic years with terms, trimesters, semesters or quarters, Northern or Southern hemisphere'),
('sms.scheme-of-work',   'app-sms', 'Scheme of Work',           1, 'Units, topics and learning objectives mapped to year groups, terms and weeks'),
('sms.lesson-plans',     'app-sms', 'Lesson Plans',             1, 'Teachers create and submit lesson plans for approval'),
('sms.multi-curriculum', 'app-sms', 'Multi-curriculum',         2, 'National, Cambridge, IB, American, British and other curricula side by side'),
('sms.standards',        'app-sms', 'Standards & Outcomes',     2, 'Tag topics and lessons to standards and learning outcomes, with coverage'),
('sms.options',          'app-sms', 'Options & Electives',      2, 'Electives and pathways with capacity and prerequisites'),
('sms.credits',          'app-sms', 'Credit Tracking',          2, 'Credit hours and graduation requirements, American-style')
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
                WHERE rp.role_id = 'role-sms-teacher' AND p.app_prefix = 'sms' AND p.resource_key = 'lessons' AND p.action = 'approve') THEN
        RAISE EXCEPTION 'an SMS Teacher may not approve lesson plans';
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
