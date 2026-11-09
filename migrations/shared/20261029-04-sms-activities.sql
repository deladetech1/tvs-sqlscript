-- MyEduGuard 13: co-curricular activities -- life beyond the classroom.
--
--   sms_activity_settings        each school's service hours target, and whether it keeps IB CAS
--   sms_clubs                    clubs, societies and sports teams: leaders, when they meet,
--                                who may join, how many
--   sms_club_members             who is in each, waiting for a place, or asking to join
--   sms_club_sessions, _marks    each meeting and who came
--   sms_fixtures, _players       a team's matches: opponent, venue, result, the squad
--   sms_house_events, _results   house competitions (sports day, quiz, debate): the houses'
--                                placings and the points they win, on the houses' leaderboard
--                                with merits and demerits
--   sms_trips                    trips and excursions: plan, cost, staff, the risk assessment
--                                and who approved it
--   sms_trip_students            who is invited; the family's consent, medical notes, what is
--                                paid; who went
--   sms_trip_payments            payments: at the school, from the family's page (confirmed
--                                when the money is in), or from the boarding wallet
--   sms_achievements             awards and certificates, on the student's profile
--   sms_service_hours            community service and IB CAS hours, logged by the student or
--                                staff, verified by staff
--
-- Permissions sms|activities|get/mark/manage; the role MyEduGuard Activities Coordinator.
-- Idempotent.

BEGIN;

CREATE TABLE IF NOT EXISTS sms.sms_activity_settings (
    profile_id      text PRIMARY KEY REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    service_target  numeric(6,1),
    cas             boolean NOT NULL DEFAULT false,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CHECK (service_target IS NULL OR service_target BETWEEN 0 AND 1000)
);

CREATE TABLE IF NOT EXISTS sms.sms_clubs (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    kind            text NOT NULL DEFAULT 'club',
    name            text NOT NULL,
    description     text,
    sport           text,
    age_group       text,
    gender          text NOT NULL DEFAULT 'mixed',
    leader_ids      text[] NOT NULL DEFAULT '{}',
    capacity        integer,
    meets_on        integer[] NOT NULL DEFAULT '{}',
    starts_at       time,
    ends_at         time,
    venue           text,
    year_group_ids  text[] NOT NULL DEFAULT '{}',
    join_mode       text NOT NULL DEFAULT 'open',
    cost            numeric(10,2),
    archived_at     timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    CHECK (capacity IS NULL OR capacity BETWEEN 1 AND 2000),
    CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at),
    CHECK (meets_on <@ ARRAY[1,2,3,4,5,6,7])
);
ALTER TABLE sms.sms_clubs DROP CONSTRAINT IF EXISTS sms_clubs_check2;
ALTER TABLE sms.sms_clubs ADD CONSTRAINT sms_clubs_check2
    CHECK (kind IN ('club', 'society', 'team') AND gender IN ('boys', 'girls', 'mixed') AND join_mode IN ('open', 'approval', 'invite'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_clubs_name_uq ON sms.sms_clubs (profile_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_club_members (
    club_id     text NOT NULL REFERENCES sms.sms_clubs(id) ON DELETE CASCADE,
    student_id  text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    status      text NOT NULL DEFAULT 'active',
    role        text,
    joined_on   date NOT NULL DEFAULT CURRENT_DATE,
    left_on     date,
    added_by    text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (club_id, student_id)
);
ALTER TABLE sms.sms_club_members DROP CONSTRAINT IF EXISTS sms_club_members_status_check;
ALTER TABLE sms.sms_club_members ADD CONSTRAINT sms_club_members_status_check CHECK (status IN ('active', 'waitlist', 'requested', 'left'));
CREATE INDEX IF NOT EXISTS sms_club_members_student_idx ON sms.sms_club_members (student_id);

CREATE TABLE IF NOT EXISTS sms.sms_club_sessions (
    id         text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    club_id    text NOT NULL REFERENCES sms.sms_clubs(id) ON DELETE CASCADE,
    held_on    date NOT NULL,
    note       text,
    taken_by   text,
    cdatetime  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (club_id, held_on)
);

CREATE TABLE IF NOT EXISTS sms.sms_club_marks (
    session_id  text NOT NULL REFERENCES sms.sms_club_sessions(id) ON DELETE CASCADE,
    student_id  text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    status      text NOT NULL,
    PRIMARY KEY (session_id, student_id)
);
ALTER TABLE sms.sms_club_marks DROP CONSTRAINT IF EXISTS sms_club_marks_status_check;
ALTER TABLE sms.sms_club_marks ADD CONSTRAINT sms_club_marks_status_check CHECK (status IN ('present', 'absent', 'excused'));

CREATE TABLE IF NOT EXISTS sms.sms_fixtures (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    team_id       text NOT NULL REFERENCES sms.sms_clubs(id) ON DELETE CASCADE,
    opponent      text NOT NULL,
    competition   text,
    kind          text NOT NULL DEFAULT 'friendly',
    home          boolean NOT NULL DEFAULT true,
    venue         text,
    starts_at     timestamptz NOT NULL,
    status        text NOT NULL DEFAULT 'scheduled',
    our_score     integer,
    their_score   integer,
    result        text,
    report        text,
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    CHECK (our_score IS NULL OR our_score BETWEEN 0 AND 1000),
    CHECK (their_score IS NULL OR their_score BETWEEN 0 AND 1000)
);
ALTER TABLE sms.sms_fixtures DROP CONSTRAINT IF EXISTS sms_fixtures_check2;
ALTER TABLE sms.sms_fixtures ADD CONSTRAINT sms_fixtures_check2
    CHECK (kind IN ('league', 'cup', 'friendly', 'tournament') AND status IN ('scheduled', 'played', 'postponed', 'cancelled')
           AND (result IS NULL OR result IN ('win', 'draw', 'loss')));
CREATE INDEX IF NOT EXISTS sms_fixtures_idx ON sms.sms_fixtures (team_id, starts_at);

CREATE TABLE IF NOT EXISTS sms.sms_fixture_players (
    fixture_id  text NOT NULL REFERENCES sms.sms_fixtures(id) ON DELETE CASCADE,
    student_id  text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    role        text NOT NULL DEFAULT 'squad',
    note        text,
    PRIMARY KEY (fixture_id, student_id)
);
ALTER TABLE sms.sms_fixture_players DROP CONSTRAINT IF EXISTS sms_fixture_players_role_check;
ALTER TABLE sms.sms_fixture_players ADD CONSTRAINT sms_fixture_players_role_check CHECK (role IN ('starter', 'substitute', 'squad', 'captain'));

CREATE TABLE IF NOT EXISTS sms.sms_house_events (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    title        text NOT NULL,
    category     text NOT NULL DEFAULT 'sport',
    held_on      date NOT NULL,
    description  text,
    points       integer[] NOT NULL DEFAULT '{10,7,5,3}',
    status       text NOT NULL DEFAULT 'planned',
    created_by   text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_house_events DROP CONSTRAINT IF EXISTS sms_house_events_check2;
ALTER TABLE sms.sms_house_events ADD CONSTRAINT sms_house_events_check2
    CHECK (category IN ('sport', 'academic', 'arts', 'music', 'debate', 'other') AND status IN ('planned', 'done', 'cancelled'));
CREATE INDEX IF NOT EXISTS sms_house_events_idx ON sms.sms_house_events (profile_id, held_on DESC);

CREATE TABLE IF NOT EXISTS sms.sms_house_event_results (
    event_id  text NOT NULL REFERENCES sms.sms_house_events(id) ON DELETE CASCADE,
    house_id  text NOT NULL REFERENCES sms.sms_houses(id) ON DELETE CASCADE,
    position  integer NOT NULL,
    points    integer NOT NULL,
    PRIMARY KEY (event_id, house_id),
    CHECK (position BETWEEN 1 AND 50 AND points BETWEEN -100 AND 1000)
);

CREATE TABLE IF NOT EXISTS sms.sms_trips (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    bus_id             text NOT NULL,
    profile_id         text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    title              text NOT NULL,
    destination        text NOT NULL,
    purpose            text,
    departs_at         timestamptz NOT NULL,
    returns_at         timestamptz NOT NULL,
    transport          text,
    cost               numeric(10,2) NOT NULL DEFAULT 0,
    capacity           integer,
    leader_id          text,
    staff_ids          text[] NOT NULL DEFAULT '{}',
    consent_by         date,
    pay_by             date,
    status             text NOT NULL DEFAULT 'draft',
    hazards            jsonb NOT NULL DEFAULT '[]',
    emergency_plan     text,
    risk_approved_by   text,
    risk_approved_at   timestamptz,
    created_by         text,
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    CHECK (returns_at > departs_at),
    CHECK (cost >= 0 AND (capacity IS NULL OR capacity BETWEEN 1 AND 2000))
);
ALTER TABLE sms.sms_trips DROP CONSTRAINT IF EXISTS sms_trips_status_check;
ALTER TABLE sms.sms_trips ADD CONSTRAINT sms_trips_status_check CHECK (status IN ('draft', 'open', 'closed', 'done', 'cancelled'));
CREATE INDEX IF NOT EXISTS sms_trips_idx ON sms.sms_trips (profile_id, departs_at DESC);

CREATE TABLE IF NOT EXISTS sms.sms_trip_students (
    trip_id         text NOT NULL REFERENCES sms.sms_trips(id) ON DELETE CASCADE,
    student_id      text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    consent         text NOT NULL DEFAULT 'pending',
    consent_name    text,
    consent_at      timestamptz,
    consent_ip      text,
    medical_note    text,
    emergency_phone text,
    exempt          boolean NOT NULL DEFAULT false,
    attended        boolean,
    invited_by      text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (trip_id, student_id)
);
ALTER TABLE sms.sms_trip_students DROP CONSTRAINT IF EXISTS sms_trip_students_consent_check;
ALTER TABLE sms.sms_trip_students ADD CONSTRAINT sms_trip_students_consent_check CHECK (consent IN ('pending', 'given', 'declined'));
CREATE INDEX IF NOT EXISTS sms_trip_students_student_idx ON sms.sms_trip_students (student_id);

CREATE TABLE IF NOT EXISTS sms.sms_trip_payments (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    trip_id       text NOT NULL REFERENCES sms.sms_trips(id) ON DELETE CASCADE,
    student_id    text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    amount        numeric(10,2) NOT NULL,
    method        text NOT NULL,
    reference     text,
    status        text NOT NULL DEFAULT 'posted',
    by_user       text,
    by_family     text,
    confirmed_by  text,
    confirmed_at  timestamptz,
    note          text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    CHECK (amount > 0)
);
ALTER TABLE sms.sms_trip_payments DROP CONSTRAINT IF EXISTS sms_trip_payments_check2;
ALTER TABLE sms.sms_trip_payments ADD CONSTRAINT sms_trip_payments_check2
    CHECK (method IN ('cash', 'mobile_money', 'bank', 'card', 'cheque', 'wallet') AND status IN ('pending', 'posted', 'rejected', 'refunded'));
CREATE INDEX IF NOT EXISTS sms_trip_payments_idx ON sms.sms_trip_payments (trip_id, student_id);

CREATE TABLE IF NOT EXISTS sms.sms_achievements (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id   text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    title        text NOT NULL,
    category     text NOT NULL DEFAULT 'other',
    level        text NOT NULL DEFAULT 'school',
    position     text,
    awarded_on   date NOT NULL,
    awarded_by   text,
    description  text,
    club_id      text REFERENCES sms.sms_clubs(id) ON DELETE SET NULL,
    fixture_id   text REFERENCES sms.sms_fixtures(id) ON DELETE SET NULL,
    event_id     text REFERENCES sms.sms_house_events(id) ON DELETE SET NULL,
    on_profile   boolean NOT NULL DEFAULT true,
    recorded_by  text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_achievements DROP CONSTRAINT IF EXISTS sms_achievements_check2;
ALTER TABLE sms.sms_achievements ADD CONSTRAINT sms_achievements_check2
    CHECK (category IN ('academic', 'sport', 'arts', 'music', 'leadership', 'service', 'citizenship', 'other')
           AND level IN ('class', 'school', 'district', 'regional', 'national', 'international'));
CREATE INDEX IF NOT EXISTS sms_achievements_student_idx ON sms.sms_achievements (student_id, awarded_on DESC);
CREATE INDEX IF NOT EXISTS sms_achievements_idx ON sms.sms_achievements (profile_id, awarded_on DESC);

CREATE TABLE IF NOT EXISTS sms.sms_service_hours (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    profile_id       text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id       text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    activity         text NOT NULL,
    organisation     text,
    strand           text NOT NULL DEFAULT 'service',
    outcomes         integer[] NOT NULL DEFAULT '{}',
    hours            numeric(5,1) NOT NULL,
    served_on        date NOT NULL,
    supervisor       text,
    supervisor_phone text,
    reflection       text,
    status           text NOT NULL DEFAULT 'submitted',
    review_note      text,
    reviewed_by      text,
    reviewed_at      timestamptz,
    logged_by        text NOT NULL,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    CHECK (hours > 0 AND hours <= 24),
    CHECK (outcomes <@ ARRAY[1,2,3,4,5,6,7])
);
ALTER TABLE sms.sms_service_hours DROP CONSTRAINT IF EXISTS sms_service_hours_check2;
ALTER TABLE sms.sms_service_hours ADD CONSTRAINT sms_service_hours_check2
    CHECK (strand IN ('service', 'creativity', 'activity') AND status IN ('submitted', 'approved', 'rejected') AND logged_by IN ('student', 'staff'));
CREATE INDEX IF NOT EXISTS sms_service_hours_student_idx ON sms.sms_service_hours (student_id, served_on DESC);
CREATE INDEX IF NOT EXISTS sms_service_hours_idx ON sms.sms_service_hours (profile_id, status, served_on DESC);

-- Co-curricular activities are a module a school can turn off (Settings, Modules).
SELECT sms.widen_check('sms.sms_profiles', 'sms_profiles_modules_check', $q$'activities'$q$, $q$CHECK (modules IS NULL OR (cardinality(modules) > 0 AND modules <@ ARRAY[
    'admissions', 'teaching', 'scheduling', 'attendance', 'grading', 'learning', 'welfare', 'inclusion', 'boarding', 'library', 'activities']::text[]))$q$);

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-activities', 'MyEduGuard Activities', 'Clubs and societies, sports teams and fixtures, house competitions, trips, achievements and service hours', 'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, action, label) AS (VALUES
    ('activities', 'get',    'View clubs, teams and fixtures, house competitions, trips, achievements and service hours'),
    ('activities', 'mark',   'Run the clubs and teams one leads: members, attendance and results; the trips one leads; record achievements and verify service hours'),
    ('activities', 'manage', 'Set up clubs, teams, house competitions and trips, approve trips'' risk assessments, and set the service hours target')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-sms-' || spec.resource_key || '-' || spec.action,
       'MyEduGuard ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       'rt-sms-activities', spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
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
('role-sms-coordinator', 'system-tenant-id', 'MyEduGuard Activities Coordinator', 'Runs co-curricular life: clubs, teams and fixtures, house competitions, trips and their risk assessments, achievements and service hours', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
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
    SELECT 'role-sms-coordinator', k, a FROM (VALUES ('activities', 'get'), ('activities', 'mark'), ('activities', 'manage'), ('students', 'get'), ('structure', 'get'),
        ('profiles', 'get'), ('health', 'get'), ('behaviour', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-teacher', k, a FROM (VALUES ('activities', 'get'), ('activities', 'mark')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-registrar', k, a FROM (VALUES ('activities', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-housemaster', k, a FROM (VALUES ('activities', 'get')) AS g(k, a)
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

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', 'role-sms-coordinator', p.id
  FROM core_platform.cp_permissions p
 WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.clubs',              'app-sms', 'Clubs & Societies',          1, 'Enrollment, attendance and capacity per club'),
('sms.sports',             'app-sms', 'Sports Teams & Fixtures',    2, 'Teams, fixtures, results and achievements'),
('sms.house-competitions', 'app-sms', 'Houses & Competitions',      1, 'House points, events and leaderboards'),
('sms.trips',              'app-sms', 'Trips & Excursions',         2, 'Trip planning, consent forms, payments and risk assessments'),
('sms.achievements',       'app-sms', 'Achievements & Awards',      1, 'Record awards and certificates on the student profile'),
('sms.service-hours',      'app-sms', 'Service Hours Tracking',     2, 'Community service and CAS hours (IB)')
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
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-sms-coordinator' AND p.app_prefix = 'sms' AND p.resource_key IN ('counselling', 'safeguarding')) THEN
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
