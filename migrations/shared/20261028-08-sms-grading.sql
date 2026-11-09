-- SMS: assessment, grading and reporting -- measuring progress the way each school needs.
--
--   sms_grading_scales, _bands     grading scales -- national, Cambridge, IB 1-7, American GPA,
--                                  GCSE 9-1, A Level, CBSE, early years, mastery, or the school's
--                                  own -- each band with its range, points and pass mark
--   sms_scale_rules                which scale a year group, class or subject uses
--   sms_assessment_schemes,
--   _components                    the weighting of classwork, homework, tests, projects and the
--                                  examination (SBA, CA, coursework) for year groups
--   sms_gradebook_items, _scores      the gradebook: each piece of assessed work and every score,
--                                  tagged with the standards it measures
--   sms_term_results               each student's computed result per subject and term: component
--                                  percentages, total, grade, points, position
--   sms_report_templates           report card layouts (standard, standards-based, narrative)
--   sms_report_cards               a student's report for a term: comments, signatures, GPA,
--                                  position, attendance, frozen when published
--   sms_outcome_ratings            ratings by learning outcome or skill (primary, early years)
--   sms_comment_bank               reusable comments, suggested by performance
--   sms_issued_documents           every report and transcript issued, with its verification code
--   sms_subjects.gpa_bonus         honours / AP weighting for weighted GPA
--
-- Permissions sms|grades|get/enter/manage, sms|reports|get/approve; plan features. Idempotent.

BEGIN;

-- =================================================================== scales
CREATE TABLE IF NOT EXISTS sms.sms_grading_scales (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles (id),
    name        text NOT NULL,
    kind        text NOT NULL DEFAULT 'letter',
    preset      text,
    is_default  boolean NOT NULL DEFAULT false,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    archived_at timestamptz
);
ALTER TABLE sms.sms_grading_scales DROP CONSTRAINT IF EXISTS sms_grading_scales_kind_check;
ALTER TABLE sms.sms_grading_scales ADD CONSTRAINT sms_grading_scales_kind_check CHECK (kind IN ('letter', 'numeric', 'descriptor'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_grading_scales_name_idx ON sms.sms_grading_scales (profile_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_grade_bands (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    scale_id    text NOT NULL REFERENCES sms.sms_grading_scales (id) ON DELETE CASCADE,
    label       text NOT NULL,
    min_pct     numeric(5,2) NOT NULL CHECK (min_pct BETWEEN 0 AND 100),
    points      numeric(4,2),
    description text,
    is_pass     boolean NOT NULL DEFAULT true,
    sort_order  int NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS sms_grade_bands_scale_idx ON sms.sms_grade_bands (scale_id, min_pct DESC);

CREATE TABLE IF NOT EXISTS sms.sms_scale_rules (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    scale_id      text NOT NULL REFERENCES sms.sms_grading_scales (id) ON DELETE CASCADE,
    year_group_id text REFERENCES sms.sms_year_groups (id),
    class_id      text REFERENCES sms.sms_classes (id),
    subject_id    text REFERENCES sms.sms_subjects (id),
    CHECK (year_group_id IS NOT NULL OR class_id IS NOT NULL OR subject_id IS NOT NULL)
);

-- =================================================================== continuous assessment
CREATE TABLE IF NOT EXISTS sms.sms_assessment_schemes (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    profile_id     text NOT NULL REFERENCES sms.sms_profiles (id),
    name           text NOT NULL,
    year_group_ids text[] NOT NULL DEFAULT '{}',
    subject_ids    text[] NOT NULL DEFAULT '{}',
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    archived_at    timestamptz
);

CREATE TABLE IF NOT EXISTS sms.sms_assessment_components (
    id         text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    scheme_id  text NOT NULL REFERENCES sms.sms_assessment_schemes (id) ON DELETE CASCADE,
    name       text NOT NULL,
    kind       text NOT NULL DEFAULT 'ca',
    weight     numeric(5,2) NOT NULL CHECK (weight > 0 AND weight <= 100),
    sort_order int NOT NULL DEFAULT 0
);
ALTER TABLE sms.sms_assessment_components DROP CONSTRAINT IF EXISTS sms_assessment_components_kind_check;
ALTER TABLE sms.sms_assessment_components ADD CONSTRAINT sms_assessment_components_kind_check CHECK (kind IN ('ca', 'coursework', 'exam'));

CREATE TABLE IF NOT EXISTS sms.sms_gradebook_items (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles (id),
    class_id     text NOT NULL REFERENCES sms.sms_classes (id),
    subject_id   text NOT NULL REFERENCES sms.sms_subjects (id),
    term_id      text NOT NULL REFERENCES sms.sms_terms (id),
    component_id text NOT NULL REFERENCES sms.sms_assessment_components (id),
    title        text NOT NULL,
    max_score    numeric(7,2) NOT NULL CHECK (max_score > 0),
    assessed_on  date,
    standard_ids text[] NOT NULL DEFAULT '{}',
    created_by   text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sms_gradebook_items_class_idx ON sms.sms_gradebook_items (class_id, subject_id, term_id);

CREATE TABLE IF NOT EXISTS sms.sms_gradebook_scores (
    assessment_id text NOT NULL REFERENCES sms.sms_gradebook_items (id) ON DELETE CASCADE,
    student_id    text NOT NULL REFERENCES sms.sms_students (id),
    score         numeric(7,2) CHECK (score IS NULL OR score >= 0),
    absent        boolean NOT NULL DEFAULT false,
    excused       boolean NOT NULL DEFAULT false,
    comment       text,
    entered_by    text,
    entered_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (assessment_id, student_id)
);
CREATE INDEX IF NOT EXISTS sms_gradebook_scores_student_idx ON sms.sms_gradebook_scores (student_id);

-- =================================================================== results and reports
CREATE TABLE IF NOT EXISTS sms.sms_term_results (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles (id),
    student_id    text NOT NULL REFERENCES sms.sms_students (id),
    class_id      text NOT NULL REFERENCES sms.sms_classes (id),
    subject_id    text NOT NULL REFERENCES sms.sms_subjects (id),
    term_id       text NOT NULL REFERENCES sms.sms_terms (id),
    academic_year text NOT NULL,
    components    jsonb NOT NULL DEFAULT '[]',
    total_pct     numeric(5,2),
    grade         text,
    points        numeric(4,2),
    is_pass       boolean,
    credits       numeric(5,2),
    position      int,
    out_of        int,
    complete      boolean NOT NULL DEFAULT true,
    computed_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (student_id, subject_id, term_id)
);
CREATE INDEX IF NOT EXISTS sms_term_results_class_idx ON sms.sms_term_results (class_id, term_id);

CREATE TABLE IF NOT EXISTS sms.sms_report_templates (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    profile_id     text NOT NULL REFERENCES sms.sms_profiles (id),
    name           text NOT NULL,
    kind           text NOT NULL DEFAULT 'standard',
    year_group_ids text[] NOT NULL DEFAULT '{}',
    options        jsonb NOT NULL DEFAULT '{}',
    sections       jsonb NOT NULL DEFAULT '[]',
    outcome_scale_id text REFERENCES sms.sms_grading_scales (id),
    is_default     boolean NOT NULL DEFAULT false,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    archived_at    timestamptz
);
ALTER TABLE sms.sms_report_templates DROP CONSTRAINT IF EXISTS sms_report_templates_kind_check;
ALTER TABLE sms.sms_report_templates ADD CONSTRAINT sms_report_templates_kind_check CHECK (kind IN ('standard', 'standards', 'narrative'));

CREATE TABLE IF NOT EXISTS sms.sms_report_cards (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles (id),
    student_id      text NOT NULL REFERENCES sms.sms_students (id),
    class_id        text NOT NULL REFERENCES sms.sms_classes (id),
    term_id         text NOT NULL REFERENCES sms.sms_terms (id),
    template_id     text REFERENCES sms.sms_report_templates (id),
    status          text NOT NULL DEFAULT 'draft',
    average_pct     numeric(5,2),
    position        int,
    out_of          int,
    gpa             numeric(4,2),
    weighted_gpa    numeric(4,2),
    attendance_rate numeric(5,2),
    teacher_comment text,
    head_comment    text,
    narrative       jsonb NOT NULL DEFAULT '{}',
    teacher_signed_by text,
    teacher_signed_at timestamptz,
    head_signed_by  text,
    head_signed_at  timestamptz,
    snapshot        jsonb,
    published_at    timestamptz,
    published_by    text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz,
    UNIQUE (student_id, term_id)
);
ALTER TABLE sms.sms_report_cards DROP CONSTRAINT IF EXISTS sms_report_cards_status_check;
ALTER TABLE sms.sms_report_cards ADD CONSTRAINT sms_report_cards_status_check CHECK (status IN ('draft', 'published'));
CREATE INDEX IF NOT EXISTS sms_report_cards_class_idx ON sms.sms_report_cards (class_id, term_id);

CREATE TABLE IF NOT EXISTS sms.sms_outcome_ratings (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    student_id  text NOT NULL REFERENCES sms.sms_students (id),
    term_id     text NOT NULL REFERENCES sms.sms_terms (id),
    subject_id  text REFERENCES sms.sms_subjects (id),
    standard_id text REFERENCES sms.sms_standards (id),
    skill       text,
    band_id     text NOT NULL REFERENCES sms.sms_grade_bands (id),
    comment     text,
    rated_by    text,
    rated_at    timestamptz NOT NULL DEFAULT now(),
    CHECK (standard_id IS NOT NULL OR skill IS NOT NULL)
);
CREATE UNIQUE INDEX IF NOT EXISTS sms_outcome_ratings_one_idx ON sms.sms_outcome_ratings
    (student_id, term_id, coalesce(subject_id, ''), coalesce(standard_id, ''), coalesce(lower(skill), ''));

CREATE TABLE IF NOT EXISTS sms.sms_comment_bank (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles (id),
    audience    text NOT NULL DEFAULT 'teacher',
    body        text NOT NULL,
    min_pct     numeric(5,2) NOT NULL DEFAULT 0,
    max_pct     numeric(5,2) NOT NULL DEFAULT 100,
    subject_id  text REFERENCES sms.sms_subjects (id),
    created_by  text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    archived_at timestamptz,
    CHECK (min_pct <= max_pct)
);
ALTER TABLE sms.sms_comment_bank DROP CONSTRAINT IF EXISTS sms_comment_bank_audience_check;
ALTER TABLE sms.sms_comment_bank ADD CONSTRAINT sms_comment_bank_audience_check CHECK (audience IN ('teacher', 'head', 'subject'));

CREATE TABLE IF NOT EXISTS sms.sms_issued_documents (
    code           text PRIMARY KEY,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    profile_id     text NOT NULL REFERENCES sms.sms_profiles (id),
    kind           text NOT NULL,
    student_id     text NOT NULL REFERENCES sms.sms_students (id),
    report_card_id text REFERENCES sms.sms_report_cards (id),
    summary        jsonb NOT NULL DEFAULT '{}',
    issued_by      text,
    issued_at      timestamptz NOT NULL DEFAULT now(),
    revoked_at     timestamptz,
    revoked_reason text
);
ALTER TABLE sms.sms_issued_documents DROP CONSTRAINT IF EXISTS sms_issued_documents_kind_check;
ALTER TABLE sms.sms_issued_documents ADD CONSTRAINT sms_issued_documents_kind_check CHECK (kind IN ('report', 'transcript', 'certificate'));
CREATE INDEX IF NOT EXISTS sms_issued_documents_student_idx ON sms.sms_issued_documents (student_id, kind);

ALTER TABLE sms.sms_subjects ADD COLUMN IF NOT EXISTS gpa_bonus numeric(3,2) NOT NULL DEFAULT 0;
ALTER TABLE sms.sms_subjects DROP CONSTRAINT IF EXISTS sms_subjects_gpa_bonus_check;
ALTER TABLE sms.sms_subjects ADD CONSTRAINT sms_subjects_gpa_bonus_check CHECK (gpa_bonus BETWEEN 0 AND 2);

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-grades',  'SMS Grades',  'The gradebook, assessment schemes, grading scales and comment bank', 'rt-subscribed-app-sms'),
('rt-sms-reports', 'SMS Reports', 'Report cards, transcripts and their verification',                 'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('enter', 'Enter', false, false)
ON CONFLICT (action) DO NOTHING;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('grades',  'rt-sms-grades',  'get',     'View the gradebook, results and their analytics'),
    ('grades',  'rt-sms-grades',  'enter',   'Add assessments, enter scores and write report comments'),
    ('grades',  'rt-sms-grades',  'manage',  'Set up assessment schemes, grading scales, report templates and the comment bank, and compute results'),
    ('reports', 'rt-sms-reports', 'get',     'View report cards and transcripts'),
    ('reports', 'rt-sms-reports', 'approve', 'Sign and publish report cards, issue transcripts and revoke documents')
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

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-sms-head' AS role_id, p2.resource_key, p2.action
      FROM core_platform.cp_permissions p2 WHERE p2.app_prefix = 'sms'
    UNION ALL
    SELECT 'role-sms-teacher', k, a FROM (VALUES ('grades', 'get'), ('grades', 'enter'), ('reports', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-registrar', k, a FROM (VALUES ('grades', 'get'), ('grades', 'manage'), ('reports', 'get')) AS g(k, a)
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

-- =================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.gradebook',            'app-sms', 'Continuous Assessment',     1, 'Classwork, homework, tests and examination weightings (SBA, CA, coursework)'),
('sms.grading-scales',       'app-sms', 'Grading Scales',            1, 'National, Cambridge, IB, American GPA, GCSE, A Level, CBSE, early years, mastery and custom scales per class or subject'),
('sms.report-cards',         'app-sms', 'Progress Report Cards',     1, 'Report templates with teacher and head comments, signatures and school branding'),
('sms.comment-bank',         'app-sms', 'Comment Banks',             1, 'Reusable comments suggested by performance'),
('sms.standards-reports',    'app-sms', 'Standards & Narrative Reports', 2, 'Reports by learning outcome, skills or narrative for primary and early years'),
('sms.gpa',                  'app-sms', 'GPA & Class Ranking',       2, 'Weighted and unweighted GPA, cumulative GPA and optional ranking'),
('sms.transcripts',          'app-sms', 'Transcripts',               2, 'Multi-year transcripts for university applications'),
('sms.report-verification',  'app-sms', 'Report Verification',       2, 'A QR code on reports and transcripts for authenticity checks'),
('sms.gradebook-analytics',  'app-sms', 'Gradebook Analytics',       2, 'Subject performance, grade distribution and teacher comparison')
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
                WHERE rp.role_id = 'role-sms-teacher' AND p.app_prefix = 'sms' AND p.action IN ('manage', 'approve')) THEN
        RAISE EXCEPTION 'an SMS Teacher manages and approves nothing';
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
