-- MyEduGuard 09: student welfare, health and safeguarding -- keeping every child safe and well.
--
--   sms_health_records          a student's conditions, doctor, clinic and health insurance (NHIS)
--                               beside the allergies and blood group the record already holds
--   sms_medications             what a student takes, the dose, and whether the school gives it
--   sms_vaccinations            vaccines given and the next dose due
--   sms_clinic_visits           sick bay visits: the complaint, what was seen and given, the outcome,
--                               and when the family was told
--   sms_incidents, _students    disciplinary incidents: what happened, who was involved, the action
--                               taken and the outcome for each student
--   sms_houses, students.house  the school's houses
--   sms_behaviour_points        merits and demerits, with house totals
--   sms_counselling_sessions    confidential counselling notes; a private note is its author's alone
--   sms_safeguarding_concerns,  concerns any member of staff reports, which the designated
--   _actions                    safeguarding leads review, escalate, refer and close
--   sms_pickup_persons, _log    who may collect a child, with their photo, and each collection
--                               checked at the gate
--   sms_roll_calls, _marks      emergency and drill roll calls with a live headcount
--
-- Permissions sms|health, clinic, behaviour, counselling, safeguarding, pickup, emergency; the roles
-- MyEduGuard School Nurse, Counsellor, Safeguarding Lead and Gate & Security. Counselling and
-- safeguarding are not read-only for the Viewer: a later migration that grants the Viewer every
-- read-only SMS permission must leave them out (the invariant below says so). Idempotent.

BEGIN;

-- =================================================================== health
CREATE TABLE IF NOT EXISTS sms.sms_health_records (
    student_id        text PRIMARY KEY REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    conditions        text,
    disabilities      text,
    dietary_needs     text,
    doctor_name       text,
    doctor_phone      text,
    clinic_name       text,
    insurance_provider text,
    insurance_number  text,
    emergency_plan    text,
    consent_first_aid boolean NOT NULL DEFAULT true,
    consent_paracetamol boolean NOT NULL DEFAULT false,
    updated_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sms.sms_medications (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    student_id    text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    name          text NOT NULL,
    dose          text,
    schedule      text,
    at_school     boolean NOT NULL DEFAULT false,
    starts_on     date,
    ends_on       date,
    notes         text,
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    CHECK (ends_on IS NULL OR starts_on IS NULL OR ends_on >= starts_on)
);
CREATE INDEX IF NOT EXISTS sms_medications_student_idx ON sms.sms_medications (student_id);

CREATE TABLE IF NOT EXISTS sms.sms_vaccinations (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    student_id  text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    vaccine     text NOT NULL,
    dose        text,
    given_on    date,
    next_due_on date,
    notes       text,
    created_by  text,
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sms_vaccinations_student_idx ON sms.sms_vaccinations (student_id);

CREATE TABLE IF NOT EXISTS sms.sms_clinic_visits (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    bus_id             text NOT NULL,
    profile_id         text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id         text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    seen_at            timestamptz NOT NULL DEFAULT now(),
    left_at            timestamptz,
    complaint          text NOT NULL,
    temperature_c      numeric(4,1),
    observations       text,
    treatment          text,
    medication_given   text,
    outcome            text NOT NULL DEFAULT 'returned',
    seen_by            text,
    notify_family      boolean NOT NULL DEFAULT true,
    family_told_at     timestamptz,
    family_told_via    text,
    family_told_error  text,
    cdatetime          timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_clinic_visits DROP CONSTRAINT IF EXISTS sms_clinic_visits_outcome_check;
ALTER TABLE sms.sms_clinic_visits ADD CONSTRAINT sms_clinic_visits_outcome_check
    CHECK (outcome IN ('returned', 'rested', 'sent_home', 'collected', 'referred', 'hospital'));
ALTER TABLE sms.sms_clinic_visits DROP CONSTRAINT IF EXISTS sms_clinic_visits_temp_check;
ALTER TABLE sms.sms_clinic_visits ADD CONSTRAINT sms_clinic_visits_temp_check CHECK (temperature_c IS NULL OR temperature_c BETWEEN 30 AND 45);
CREATE INDEX IF NOT EXISTS sms_clinic_visits_idx ON sms.sms_clinic_visits (profile_id, seen_at DESC);
CREATE INDEX IF NOT EXISTS sms_clinic_visits_student_idx ON sms.sms_clinic_visits (student_id, seen_at DESC);

-- =================================================================== behaviour
CREATE TABLE IF NOT EXISTS sms.sms_houses (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name        text NOT NULL,
    colour      text,
    archived_at timestamptz,
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS sms_houses_name_uq ON sms.sms_houses (profile_id, lower(name)) WHERE archived_at IS NULL;
ALTER TABLE sms.sms_students ADD COLUMN IF NOT EXISTS house_id text REFERENCES sms.sms_houses(id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS sms.sms_incidents (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    occurred_at  timestamptz NOT NULL,
    place        text,
    category     text NOT NULL,
    severity     text NOT NULL DEFAULT 'minor',
    description  text NOT NULL,
    status       text NOT NULL DEFAULT 'open',
    reported_by  text,
    closed_by    text,
    closed_at    timestamptz,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_incidents DROP CONSTRAINT IF EXISTS sms_incidents_check2;
ALTER TABLE sms.sms_incidents ADD CONSTRAINT sms_incidents_check2
    CHECK (severity IN ('minor', 'moderate', 'serious') AND status IN ('open', 'closed')
           AND category IN ('disruption', 'lateness', 'uniform', 'homework', 'disrespect', 'bullying', 'fighting', 'damage',
                            'theft', 'truancy', 'cheating', 'substance', 'phone', 'other'));
CREATE INDEX IF NOT EXISTS sms_incidents_idx ON sms.sms_incidents (profile_id, occurred_at DESC);

CREATE TABLE IF NOT EXISTS sms.sms_incident_students (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    incident_id  text NOT NULL REFERENCES sms.sms_incidents(id) ON DELETE CASCADE,
    student_id   text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    role         text NOT NULL DEFAULT 'responsible',
    action       text,
    action_on    date,
    action_until date,
    outcome      text,
    family_told  boolean NOT NULL DEFAULT false,
    UNIQUE (incident_id, student_id)
);
ALTER TABLE sms.sms_incident_students DROP CONSTRAINT IF EXISTS sms_incident_students_check2;
ALTER TABLE sms.sms_incident_students ADD CONSTRAINT sms_incident_students_check2
    CHECK (role IN ('responsible', 'involved', 'affected', 'witness')
           AND (action IS NULL OR action IN ('warning', 'detention', 'parent_meeting', 'community_service', 'counselling', 'suspension',
                                             'exclusion', 'restorative', 'other'))
           AND (action_until IS NULL OR action_on IS NULL OR action_until >= action_on));
CREATE INDEX IF NOT EXISTS sms_incident_students_student_idx ON sms.sms_incident_students (student_id);

CREATE TABLE IF NOT EXISTS sms.sms_behaviour_points (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id  text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    house_id    text REFERENCES sms.sms_houses(id) ON DELETE SET NULL,
    points      integer NOT NULL,
    reason      text NOT NULL,
    note        text,
    incident_id text REFERENCES sms.sms_incidents(id) ON DELETE SET NULL,
    awarded_by  text,
    awarded_on  date NOT NULL DEFAULT CURRENT_DATE,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    CHECK (points <> 0 AND points BETWEEN -50 AND 50)
);
CREATE INDEX IF NOT EXISTS sms_behaviour_points_idx ON sms.sms_behaviour_points (profile_id, awarded_on DESC);
CREATE INDEX IF NOT EXISTS sms_behaviour_points_student_idx ON sms.sms_behaviour_points (student_id);

-- =================================================================== counselling
CREATE TABLE IF NOT EXISTS sms.sms_counselling_sessions (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id    text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    counsellor_id text NOT NULL,
    held_at       timestamptz NOT NULL,
    kind          text NOT NULL DEFAULT 'individual',
    referred_by   text,
    concern       text NOT NULL,
    notes         text,
    plan          text,
    follow_up_on  date,
    private       boolean NOT NULL DEFAULT false,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz
);
ALTER TABLE sms.sms_counselling_sessions DROP CONSTRAINT IF EXISTS sms_counselling_kind_check;
ALTER TABLE sms.sms_counselling_sessions ADD CONSTRAINT sms_counselling_kind_check CHECK (kind IN ('individual', 'group', 'family', 'check_in'));
CREATE INDEX IF NOT EXISTS sms_counselling_student_idx ON sms.sms_counselling_sessions (student_id, held_at DESC);

-- =================================================================== safeguarding
CREATE TABLE IF NOT EXISTS sms.sms_safeguarding_concerns (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    reference       text NOT NULL,
    student_id      text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    category        text NOT NULL,
    risk            text NOT NULL DEFAULT 'medium',
    noticed_at      timestamptz NOT NULL,
    description     text NOT NULL,
    child_said      text,
    action_taken    text,
    reported_by     text NOT NULL,
    status          text NOT NULL DEFAULT 'new',
    assigned_to     text,
    referred_to     text,
    referral_ref    text,
    closed_at       timestamptz,
    outcome         text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (profile_id, reference)
);
ALTER TABLE sms.sms_safeguarding_concerns DROP CONSTRAINT IF EXISTS sms_safeguarding_check2;
ALTER TABLE sms.sms_safeguarding_concerns ADD CONSTRAINT sms_safeguarding_check2
    CHECK (category IN ('physical', 'emotional', 'sexual', 'neglect', 'bullying', 'online', 'self_harm', 'domestic', 'child_labour',
                        'early_marriage', 'missing', 'other')
           AND risk IN ('low', 'medium', 'high', 'immediate') AND status IN ('new', 'reviewing', 'monitoring', 'referred', 'closed'));
CREATE INDEX IF NOT EXISTS sms_safeguarding_idx ON sms.sms_safeguarding_concerns (profile_id, status, cdatetime DESC);
CREATE INDEX IF NOT EXISTS sms_safeguarding_student_idx ON sms.sms_safeguarding_concerns (student_id);

CREATE TABLE IF NOT EXISTS sms.sms_safeguarding_actions (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    concern_id  text NOT NULL REFERENCES sms.sms_safeguarding_concerns(id) ON DELETE CASCADE,
    kind        text NOT NULL,
    body        text NOT NULL,
    by_user     text,
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_safeguarding_actions DROP CONSTRAINT IF EXISTS sms_safeguarding_actions_kind_check;
ALTER TABLE sms.sms_safeguarding_actions ADD CONSTRAINT sms_safeguarding_actions_kind_check
    CHECK (kind IN ('note', 'status', 'assigned', 'escalated', 'referred', 'family_contacted', 'meeting', 'closed', 'reopened', 'viewed'));
CREATE INDEX IF NOT EXISTS sms_safeguarding_actions_idx ON sms.sms_safeguarding_actions (concern_id, cdatetime);

-- =================================================================== pickup
CREATE TABLE IF NOT EXISTS sms.sms_pickup_persons (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    family_id     text NOT NULL REFERENCES sms.sms_families(id) ON DELETE CASCADE,
    student_ids   text[] NOT NULL DEFAULT '{}',
    full_name     text NOT NULL,
    relationship  text NOT NULL,
    phone         text,
    id_type       text,
    id_number     text,
    notes         text,
    active        boolean NOT NULL DEFAULT true,
    valid_until   date,
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sms_pickup_persons_family_idx ON sms.sms_pickup_persons (family_id);

CREATE TABLE IF NOT EXISTS sms.sms_pickup_log (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id   text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    person_id    text REFERENCES sms.sms_pickup_persons(id) ON DELETE SET NULL,
    person_name  text NOT NULL,
    result       text NOT NULL,
    note         text,
    checked_by   text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_pickup_log DROP CONSTRAINT IF EXISTS sms_pickup_log_result_check;
ALTER TABLE sms.sms_pickup_log ADD CONSTRAINT sms_pickup_log_result_check CHECK (result IN ('released', 'refused'));
CREATE INDEX IF NOT EXISTS sms_pickup_log_idx ON sms.sms_pickup_log (profile_id, cdatetime DESC);

-- =================================================================== roll call
CREATE TABLE IF NOT EXISTS sms.sms_roll_calls (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    kind         text NOT NULL,
    is_drill     boolean NOT NULL DEFAULT true,
    assembly_point text,
    note         text,
    started_by   text,
    started_at   timestamptz NOT NULL DEFAULT now(),
    ended_at     timestamptz,
    ended_by     text
);
ALTER TABLE sms.sms_roll_calls DROP CONSTRAINT IF EXISTS sms_roll_calls_kind_check;
ALTER TABLE sms.sms_roll_calls ADD CONSTRAINT sms_roll_calls_kind_check CHECK (kind IN ('fire', 'earthquake', 'flood', 'lockdown', 'intruder', 'medical', 'other'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_roll_calls_one_open ON sms.sms_roll_calls (profile_id) WHERE ended_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_roll_call_marks (
    roll_call_id text NOT NULL REFERENCES sms.sms_roll_calls(id) ON DELETE CASCADE,
    person_kind  text NOT NULL,
    person_id    text NOT NULL,
    status       text NOT NULL,
    note         text,
    marked_by    text,
    marked_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (roll_call_id, person_kind, person_id)
);
ALTER TABLE sms.sms_roll_call_marks DROP CONSTRAINT IF EXISTS sms_roll_call_marks_check2;
ALTER TABLE sms.sms_roll_call_marks ADD CONSTRAINT sms_roll_call_marks_check2
    CHECK (person_kind IN ('student', 'staff') AND status IN ('safe', 'missing', 'injured', 'off_site'));

-- Files: a pickup person's photo, an incident's evidence, a safeguarding case's papers.
SELECT sms.widen_check('sms.sms_files', 'sms_files_entity_check', $q$'safeguarding'$q$, $q$CHECK (entity_type IS NULL OR entity_type IN
    ('profile', 'application', 'enquiry', 'family', 'student', 'leave_request', 'assignment', 'submission', 'class_resource',
     'pickup_person', 'incident', 'safeguarding'))$q$);

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-welfare', 'MyEduGuard Welfare', 'Health records, the sick bay, behaviour, counselling, safeguarding, pickup and roll call', 'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, action, label) AS (VALUES
    ('health',       'get',    'View students'' health records: allergies, conditions, medication, vaccinations and doctors'),
    ('health',       'manage', 'Keep students'' health records'),
    ('clinic',       'get',    'View sick bay visits'),
    ('clinic',       'create', 'Log sick bay visits, treatment and medication given, and tell the family'),
    ('behaviour',    'get',    'View incidents, merits and demerits, and house totals'),
    ('behaviour',    'create', 'Report incidents and award merits and demerits'),
    ('behaviour',    'manage', 'Decide actions and outcomes for incidents, close them, and set up houses'),
    ('counselling',  'get',    'Read counselling records that are not private'),
    ('counselling',  'manage', 'Write confidential counselling records'),
    ('safeguarding', 'create', 'Report a safeguarding concern'),
    ('safeguarding', 'manage', 'Review, escalate, refer and close safeguarding cases (designated safeguarding leads)'),
    ('pickup',       'get',    'Check who may collect a child at the gate, and record the collection'),
    ('pickup',       'manage', 'Keep the list of people who may collect each child'),
    ('emergency',    'get',    'See emergency and drill roll calls'),
    ('emergency',    'mark',   'Mark students and staff safe during a roll call'),
    ('emergency',    'manage', 'Start and end emergency and drill roll calls')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-sms-' || spec.resource_key || '-' || spec.action,
       'MyEduGuard ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       'rt-sms-welfare', spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
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
('role-sms-nurse',      'system-tenant-id', 'MyEduGuard School Nurse', 'Keeps health records and runs the sick bay: visits, treatment, medication given, the family told', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-sms-counsellor', 'system-tenant-id', 'MyEduGuard Counsellor', 'Writes confidential counselling records and reads behaviour and health', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-sms-dsl',        'system-tenant-id', 'MyEduGuard Safeguarding Lead', 'The designated safeguarding lead: reviews every concern, escalates, refers and closes cases', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-sms-security',   'system-tenant-id', 'MyEduGuard Gate & Security', 'Checks who collects each child at the gate and takes the headcount in a roll call', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
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
    SELECT 'role-sms-teacher', k, a FROM (VALUES ('health', 'get'), ('clinic', 'get'), ('behaviour', 'get'), ('behaviour', 'create'),
        ('safeguarding', 'create'), ('pickup', 'get'), ('emergency', 'get'), ('emergency', 'mark')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-registrar', k, a FROM (VALUES ('health', 'get'), ('health', 'manage'), ('behaviour', 'get'), ('safeguarding', 'create'),
        ('pickup', 'get'), ('pickup', 'manage'), ('emergency', 'get'), ('emergency', 'mark'), ('emergency', 'manage')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-admissions', k, a FROM (VALUES ('safeguarding', 'create')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-nurse', k, a FROM (VALUES ('health', 'get'), ('health', 'manage'), ('clinic', 'get'), ('clinic', 'create'),
        ('students', 'get'), ('structure', 'get'), ('profiles', 'get'), ('safeguarding', 'create'), ('pickup', 'get'),
        ('emergency', 'get'), ('emergency', 'mark')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-counsellor', k, a FROM (VALUES ('counselling', 'get'), ('counselling', 'manage'), ('health', 'get'), ('clinic', 'get'),
        ('behaviour', 'get'), ('students', 'get'), ('structure', 'get'), ('profiles', 'get'), ('safeguarding', 'create')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-dsl', k, a FROM (VALUES ('safeguarding', 'create'), ('safeguarding', 'manage'), ('counselling', 'get'), ('health', 'get'),
        ('clinic', 'get'), ('behaviour', 'get'), ('attendance', 'get'), ('students', 'get'), ('structure', 'get'), ('profiles', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-security', k, a FROM (VALUES ('pickup', 'get'), ('emergency', 'get'), ('emergency', 'mark'), ('profiles', 'get'),
        ('safeguarding', 'create')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-viewer', p3.resource_key, p3.action
      FROM core_platform.cp_permissions p3
      JOIN core_platform.cp_actions a ON a.action = p3.action AND a.is_read_only AND p3.action <> 'export'
     WHERE p3.app_prefix = 'sms' AND p3.resource_key NOT IN ('counselling', 'safeguarding')
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'sms' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- The new roles open the app as the teacher does.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', r.id, p.id
  FROM core_platform.cp_permissions p, (VALUES ('role-sms-nurse'), ('role-sms-counsellor'), ('role-sms-dsl'), ('role-sms-security')) AS r(id)
 WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.health-records', 'app-sms', 'Health Records',                 1, 'Allergies, conditions, medication, vaccinations and doctor details'),
('sms.sick-bay',       'app-sms', 'Sick Bay & Clinic Visits',       1, 'Nurse visits, treatment and medication given, with parent notification'),
('sms.discipline',     'app-sms', 'Disciplinary Incident Tracking', 1, 'Incidents, actions and outcomes per student'),
('sms.safeguarding',   'app-sms', 'Safeguarding & Child Protection Log', 1, 'Secure concern reporting, escalation and case management for designated safeguarding leads'),
('sms.merit-points',   'app-sms', 'Merit & Demerit Points',         2, 'Positive and negative behaviour points with house totals'),
('sms.counselling',    'app-sms', 'Counselling Notes',              2, 'Confidential counselling records with restricted access'),
('sms.pickup',         'app-sms', 'Authorized Pickup',              2, 'Approved pickup persons with photos and gate verification'),
('sms.roll-call',      'app-sms', 'Emergency & Evacuation Roll Call', 3, 'Live headcount during drills and emergencies')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id = EXCLUDED.app_id, title = EXCLUDED.title, min_tier_rank = EXCLUDED.min_tier_rank,
    description = EXCLUDED.description, is_active = true;

-- Earlier files re-run first on every deploy, and 01 gives the viewer (and others) every
-- read-only SMS permission -- which, once this file has made them, includes counselling and
-- safeguarding reads. Take those back here so the rule below holds on every re-run.
DELETE FROM core_platform.cp_role_permissions rp
 USING core_platform.cp_permissions p
 WHERE p.id = rp.permission_id
   AND rp.role_id IN ('role-sms-viewer', 'role-sms-teacher', 'role-sms-registrar', 'role-sms-admissions', 'role-sms-nurse', 'role-sms-security')
   AND p.app_prefix = 'sms'
   AND (p.resource_key = 'counselling' OR (p.resource_key = 'safeguarding' AND p.action <> 'create'));

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
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id IN ('role-sms-viewer', 'role-sms-teacher', 'role-sms-registrar', 'role-sms-admissions', 'role-sms-nurse', 'role-sms-security')
                  AND p.app_prefix = 'sms' AND (p.resource_key = 'counselling' OR (p.resource_key = 'safeguarding' AND p.action <> 'create'))) THEN
        RAISE EXCEPTION 'counselling records and safeguarding cases are for counsellors, safeguarding leads and the head';
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
