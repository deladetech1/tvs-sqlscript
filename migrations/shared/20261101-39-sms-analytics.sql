-- MyEduGuard: analytics and business intelligence -- decisions based on data.
--
--   sms_risk_settings     what makes a student at risk at this school: the attendance, grades,
--                         behaviour and fees thresholds, and who is told
--   sms_risk_cases        the students flagged (one case each), followed up until resolved,
--   sms_risk_notes        with what was done
--   sms_risk_snapshots    how many were at risk each day, for the trend
--   sms_custom_reports    reports built from the school's data (columns, filters, grouping),
--                         kept, shared, and sent on a schedule as CSV or Excel
--   sms_returns           government, EMIS, census and accreditation returns: generated from
--                         the records on a census day, checked, and marked submitted
--
-- The executive dashboard, collection forecasting and performance analytics read what the other
-- modules keep and store nothing. Idempotent; safe to re-run.

BEGIN;

-- =================================================================== at risk students
CREATE TABLE IF NOT EXISTS sms.sms_risk_settings (
    profile_id          text PRIMARY KEY REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    attendance_watch    numeric(5,2) NOT NULL DEFAULT 92,
    attendance_concern  numeric(5,2) NOT NULL DEFAULT 85,
    grade_watch         numeric(5,2) NOT NULL DEFAULT 55,
    grade_concern       numeric(5,2) NOT NULL DEFAULT 45,
    failed_concern      integer NOT NULL DEFAULT 3,
    drop_watch          numeric(5,2) NOT NULL DEFAULT 10,
    behaviour_watch     integer NOT NULL DEFAULT 5,
    behaviour_concern   integer NOT NULL DEFAULT 15,
    incidents_concern   integer NOT NULL DEFAULT 2,
    use_fees            boolean NOT NULL DEFAULT true,
    fees_watch_days     integer NOT NULL DEFAULT 30,
    fees_concern_days   integer NOT NULL DEFAULT 60,
    notify              boolean NOT NULL DEFAULT true,
    updated_at          timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_risk_settings', 'sms_risk_settings_check', $q$fees_concern_days$q$, $q$CHECK (
    attendance_concern <= attendance_watch AND attendance_watch <= 100 AND attendance_concern >= 0
    AND grade_concern <= grade_watch AND grade_watch <= 100 AND grade_concern >= 0 AND failed_concern >= 1 AND drop_watch > 0
    AND behaviour_watch >= 1 AND behaviour_concern >= behaviour_watch AND incidents_concern >= 1
    AND fees_watch_days >= 0 AND fees_concern_days >= fees_watch_days)$q$);

-- A level's rank, to tell when a student's risk rose.
CREATE OR REPLACE FUNCTION sms.risk_rank(level text) RETURNS integer LANGUAGE sql IMMUTABLE AS
$f$ SELECT CASE level WHEN 'high' THEN 3 WHEN 'medium' THEN 2 WHEN 'low' THEN 1 ELSE 0 END $f$;

CREATE TABLE IF NOT EXISTS sms.sms_risk_cases (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    profile_id       text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id       text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    level            text NOT NULL,
    score            integer NOT NULL DEFAULT 0,
    reasons          jsonb NOT NULL DEFAULT '[]',
    status           text NOT NULL DEFAULT 'open',
    owner_id         text,
    first_flagged_on date NOT NULL DEFAULT CURRENT_DATE,
    last_seen_on     date NOT NULL DEFAULT CURRENT_DATE,
    alerted_level    text,
    resolved_at      timestamptz,
    resolved_by      text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_risk_cases', 'sms_risk_cases_check', $q$'monitoring'$q$, $q$CHECK (
    level IN ('low', 'medium', 'high') AND status IN ('open', 'monitoring', 'resolved'))$q$);
CREATE UNIQUE INDEX IF NOT EXISTS sms_risk_cases_student_uq ON sms.sms_risk_cases (profile_id, student_id);

CREATE TABLE IF NOT EXISTS sms.sms_risk_notes (
    id         text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    case_id    text NOT NULL REFERENCES sms.sms_risk_cases(id) ON DELETE CASCADE,
    action     text NOT NULL DEFAULT 'note',
    note       text NOT NULL,
    by_user    text,
    cdatetime  timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_risk_notes', 'sms_risk_notes_check', $q$'mentoring'$q$, $q$CHECK (
    action IN ('note', 'call_home', 'meeting', 'mentoring', 'referral', 'support_plan', 'fees_plan', 'other'))$q$);
CREATE INDEX IF NOT EXISTS sms_risk_notes_case_idx ON sms.sms_risk_notes (case_id, cdatetime DESC);

CREATE TABLE IF NOT EXISTS sms.sms_risk_snapshots (
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    taken_on    date NOT NULL,
    high        integer NOT NULL DEFAULT 0,
    medium      integer NOT NULL DEFAULT 0,
    low         integer NOT NULL DEFAULT 0,
    students    integer NOT NULL DEFAULT 0,
    PRIMARY KEY (profile_id, taken_on)
);

-- =================================================================== the report builder
CREATE TABLE IF NOT EXISTS sms.sms_custom_reports (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    profile_id     text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name           text NOT NULL,
    description    text,
    dataset        text NOT NULL,
    definition     jsonb NOT NULL DEFAULT '{}',
    owner_id       text,
    shared         boolean NOT NULL DEFAULT false,
    schedule       text NOT NULL DEFAULT 'none',
    schedule_day   integer,
    schedule_hour  integer NOT NULL DEFAULT 7,
    recipients     text[] NOT NULL DEFAULT '{}',
    format         text NOT NULL DEFAULT 'xlsx',
    next_run_at    timestamptz,
    last_run_at    timestamptz,
    last_status    text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_custom_reports', 'sms_custom_reports_check', $q$'monthly'$q$, $q$CHECK (
    schedule IN ('none', 'daily', 'weekly', 'monthly') AND format IN ('csv', 'xlsx') AND schedule_hour BETWEEN 0 AND 23
    AND (schedule_day IS NULL OR schedule_day BETWEEN 1 AND 28))$q$);
CREATE INDEX IF NOT EXISTS sms_custom_reports_profile_idx ON sms.sms_custom_reports (profile_id);
CREATE INDEX IF NOT EXISTS sms_custom_reports_due_idx ON sms.sms_custom_reports (next_run_at) WHERE schedule <> 'none';

-- =================================================================== returns
CREATE TABLE IF NOT EXISTS sms.sms_returns (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    profile_id     text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    template       text NOT NULL,
    title          text NOT NULL,
    academic_year  text,
    term_id        text REFERENCES sms.sms_terms(id) ON DELETE SET NULL,
    census_on      date NOT NULL,
    status         text NOT NULL DEFAULT 'draft',
    data           jsonb NOT NULL DEFAULT '{}',
    issues         jsonb NOT NULL DEFAULT '[]',
    generated_at   timestamptz,
    generated_by   text,
    submitted_on   date,
    submitted_to   text,
    reference      text,
    notes          text,
    created_by     text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_returns', 'sms_returns_check', $q$'submitted'$q$, $q$CHECK (status IN ('draft', 'final', 'submitted'))$q$);
CREATE INDEX IF NOT EXISTS sms_returns_profile_idx ON sms.sms_returns (profile_id, census_on DESC);

-- Analytics is a module a school can turn off (Settings, Modules).
SELECT sms.widen_check('sms.sms_profiles', 'sms_profiles_modules_check', $q$'analytics'$q$, $q$CHECK (modules IS NULL OR (cardinality(modules) > 0 AND modules <@ ARRAY[
    'admissions', 'teaching', 'scheduling', 'attendance', 'grading', 'learning', 'welfare', 'inclusion', 'boarding', 'library', 'activities', 'transport',
    'catering', 'hr', 'fees', 'finance', 'procurement', 'campus', 'communication', 'alumni', 'analytics']::text[]))$q$);

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-analytics', 'MyEduGuard Analytics & Reporting', 'The executive dashboard, at risk students, collection forecasting, performance analytics, custom reports and government returns', 'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, action, label) AS (VALUES
    ('analytics', 'get',    'See the executive dashboard, at risk students, collection forecasts and performance analytics, and build and run reports'),
    ('analytics', 'manage', 'Set what makes a student at risk and follow students up, schedule report exports, and prepare and submit government returns')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-sms-' || spec.resource_key || '-' || spec.action,
       'MyEduGuard ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       'rt-sms-analytics', spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
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
('role-sms-analyst', 'system-tenant-id', 'MyEduGuard Data & Reporting Officer', 'Reads the school''s analytics, follows up students at risk, builds and schedules reports, and prepares government and accreditation returns', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
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
    SELECT 'role-sms-analyst', k, a FROM (VALUES ('analytics', 'get'), ('analytics', 'manage'), ('students', 'get'), ('structure', 'get'), ('profiles', 'get'),
        ('attendance', 'get'), ('grades', 'get'), ('reports', 'get'), ('behaviour', 'get'), ('fees', 'get'), ('admissions', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-viewer', 'analytics', 'get'
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'sms' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', 'role-sms-analyst', p.id
  FROM core_platform.cp_permissions p
 WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.executive-dashboard',   'app-sms', 'Executive Dashboard',                   2, 'Enrollment, revenue, collections, attendance and performance at a glance'),
('sms.at-risk-alerts',        'app-sms', 'At Risk Student Alerts',                2, 'Early warning from attendance, grades, behaviour and fees'),
('sms.collection-forecast',   'app-sms', 'Collection Forecasting',                2, 'Projected income and arrears trends'),
('sms.performance-analytics', 'app-sms', 'Academic Performance Analytics',        2, 'Trends by subject, class, teacher and cohort'),
('sms.report-builder',        'app-sms', 'Custom Report Builder',                 3, 'Drag and drop reports and scheduled exports'),
('sms.statutory-returns',     'app-sms', 'Government & Accreditation Returns',    2, 'Exports for ministries, EMIS, census and accreditation bodies')
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
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-sms-viewer' AND p.app_prefix = 'sms' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-sms-viewer holds % SMS permission(s) that change data', n;
    END IF;
END $$;

COMMIT;
