-- SMS: timetabling and scheduling -- building and running the school week.
--
--   sms_resources                  rooms (classrooms, labs, halls, sports facilities) and
--                                  equipment, with their seats or quantity
--   sms_timetables, sms_periods    a timetable for a year (or term): its school days and its
--                                  bell schedule of lessons and breaks; drafted, then published
--   sms_timetable_requirements     what each class is taught: subject, teacher, periods a week,
--                                  double lessons, the room or kind of room it needs
--   sms_timetable_slots            the lessons placed: day, period, class, subject, teacher, room
--   sms_teacher_limits             each teacher's limits per day and week, and the periods they
--                                  are not available
--   sms_teacher_absences,
--   sms_cover                      absences and the cover teacher for each lesson missed
--   sms_notifications              in-app notices (cover assigned, a booking cancelled)
--   sms_bookings                   rooms and equipment booked for a day and time
--   sms_exam_sessions, _papers,
--   _paper_rooms, _seats,
--   _invigilators                  exam timetables, rooms, seating plans and invigilator rosters
--   sms_families.portal_token      a family's link to its children's timetables
--
-- Permissions sms|timetable|get/manage, sms|bookings|get/create/manage, sms|exams|get/manage; plan
-- features. Idempotent.

BEGIN;

-- =================================================================== rooms and equipment
CREATE TABLE IF NOT EXISTS sms.sms_resources (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles (id),
    name        text NOT NULL,
    kind        text NOT NULL DEFAULT 'classroom',
    capacity    int CHECK (capacity IS NULL OR capacity >= 0),
    bookable    boolean NOT NULL DEFAULT true,
    notes       text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    archived_at timestamptz
);
-- Widened later (20261030-35 adds fields, pools and chapels): never narrowed here.
SELECT sms.widen_check('sms.sms_resources', 'sms_resources_kind_check', $q$'equipment'$q$,
    $q$CHECK (kind IN ('classroom', 'lab', 'ict', 'hall', 'sports', 'library', 'other', 'equipment'))$q$);
CREATE UNIQUE INDEX IF NOT EXISTS sms_resources_name_idx ON sms.sms_resources (profile_id, lower(name)) WHERE archived_at IS NULL;

-- =================================================================== timetables
CREATE TABLE IF NOT EXISTS sms.sms_timetables (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles (id),
    name          text NOT NULL,
    academic_year text NOT NULL,
    term_id       text REFERENCES sms.sms_terms (id) ON DELETE SET NULL,
    days          int[] NOT NULL DEFAULT '{1,2,3,4,5}',
    status        text NOT NULL DEFAULT 'draft',
    published_at  timestamptz,
    generated_at  timestamptz,
    generation    jsonb,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz
);
ALTER TABLE sms.sms_timetables DROP CONSTRAINT IF EXISTS sms_timetables_status_check;
ALTER TABLE sms.sms_timetables ADD CONSTRAINT sms_timetables_status_check CHECK (status IN ('draft', 'published', 'archived'));
CREATE INDEX IF NOT EXISTS sms_timetables_profile_idx ON sms.sms_timetables (profile_id, academic_year, status);

CREATE TABLE IF NOT EXISTS sms.sms_periods (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    timetable_id text NOT NULL REFERENCES sms.sms_timetables (id) ON DELETE CASCADE,
    name         text NOT NULL,
    starts_at    time NOT NULL,
    ends_at      time NOT NULL,
    sort_order   int NOT NULL DEFAULT 0,
    kind         text NOT NULL DEFAULT 'lesson',
    CHECK (ends_at > starts_at)
);
ALTER TABLE sms.sms_periods DROP CONSTRAINT IF EXISTS sms_periods_kind_check;
ALTER TABLE sms.sms_periods ADD CONSTRAINT sms_periods_kind_check CHECK (kind IN ('lesson', 'break'));
CREATE INDEX IF NOT EXISTS sms_periods_timetable_idx ON sms.sms_periods (timetable_id, sort_order);

CREATE TABLE IF NOT EXISTS sms.sms_timetable_requirements (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    timetable_id     text NOT NULL REFERENCES sms.sms_timetables (id) ON DELETE CASCADE,
    class_id         text NOT NULL REFERENCES sms.sms_classes (id),
    subject_id       text NOT NULL REFERENCES sms.sms_subjects (id),
    teacher_id       text,
    periods_per_week int NOT NULL CHECK (periods_per_week BETWEEN 1 AND 40),
    doubles          int NOT NULL DEFAULT 0 CHECK (doubles >= 0),
    room_kind        text,
    room_id          text REFERENCES sms.sms_resources (id),
    UNIQUE (timetable_id, class_id, subject_id),
    CHECK (doubles * 2 <= periods_per_week)
);

CREATE TABLE IF NOT EXISTS sms.sms_timetable_slots (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    timetable_id   text NOT NULL REFERENCES sms.sms_timetables (id) ON DELETE CASCADE,
    day            smallint NOT NULL CHECK (day BETWEEN 1 AND 7),
    period_id      text NOT NULL REFERENCES sms.sms_periods (id) ON DELETE CASCADE,
    class_id       text NOT NULL REFERENCES sms.sms_classes (id),
    subject_id     text NOT NULL REFERENCES sms.sms_subjects (id),
    teacher_id     text,
    room_id        text REFERENCES sms.sms_resources (id),
    requirement_id text REFERENCES sms.sms_timetable_requirements (id) ON DELETE SET NULL,
    locked         boolean NOT NULL DEFAULT false,
    UNIQUE (timetable_id, day, period_id, class_id)
);
CREATE INDEX IF NOT EXISTS sms_timetable_slots_teacher_idx ON sms.sms_timetable_slots (timetable_id, teacher_id, day);
CREATE INDEX IF NOT EXISTS sms_timetable_slots_room_idx ON sms.sms_timetable_slots (timetable_id, room_id, day);

-- =================================================================== workload
CREATE TABLE IF NOT EXISTS sms.sms_teacher_limits (
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles (id),
    teacher_id   text NOT NULL,
    max_per_day  int CHECK (max_per_day IS NULL OR max_per_day BETWEEN 0 AND 20),
    max_per_week int CHECK (max_per_week IS NULL OR max_per_week BETWEEN 0 AND 100),
    -- [{"day": 1, "period": 3}]: the day and the lesson period's place (1 = the first lesson).
    unavailable  jsonb NOT NULL DEFAULT '[]',
    updated_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (profile_id, teacher_id)
);

-- =================================================================== cover
CREATE TABLE IF NOT EXISTS sms.sms_teacher_absences (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles (id),
    teacher_id   text NOT NULL,
    starts_on    date NOT NULL,
    ends_on      date NOT NULL,
    reason       text NOT NULL DEFAULT 'sick',
    note         text,
    created_by   text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    cancelled_at timestamptz,
    CHECK (ends_on >= starts_on)
);
ALTER TABLE sms.sms_teacher_absences DROP CONSTRAINT IF EXISTS sms_teacher_absences_reason_check;
ALTER TABLE sms.sms_teacher_absences ADD CONSTRAINT sms_teacher_absences_reason_check
    CHECK (reason IN ('sick', 'leave', 'training', 'trip', 'personal', 'other'));
CREATE INDEX IF NOT EXISTS sms_teacher_absences_idx ON sms.sms_teacher_absences (profile_id, starts_on, ends_on);

CREATE TABLE IF NOT EXISTS sms.sms_cover (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    absence_id       text NOT NULL REFERENCES sms.sms_teacher_absences (id) ON DELETE CASCADE,
    slot_id          text NOT NULL REFERENCES sms.sms_timetable_slots (id) ON DELETE CASCADE,
    cover_date       date NOT NULL,
    cover_teacher_id text,
    status           text NOT NULL DEFAULT 'assigned',
    note             text,
    notified_at      timestamptz,
    responded_at     timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    UNIQUE (absence_id, slot_id, cover_date)
);
ALTER TABLE sms.sms_cover DROP CONSTRAINT IF EXISTS sms_cover_status_check;
ALTER TABLE sms.sms_cover ADD CONSTRAINT sms_cover_status_check CHECK (status IN ('assigned', 'accepted', 'declined'));
CREATE INDEX IF NOT EXISTS sms_cover_teacher_idx ON sms.sms_cover (cover_teacher_id, cover_date);

CREATE TABLE IF NOT EXISTS sms.sms_notifications (
    id         text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id  text NOT NULL,
    bus_id     text NOT NULL,
    profile_id text REFERENCES sms.sms_profiles (id),
    user_id    text NOT NULL,
    title      text NOT NULL,
    body       text,
    link       text,
    read_at    timestamptz,
    cdatetime  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sms_notifications_user_idx ON sms.sms_notifications (bus_id, user_id, cdatetime DESC);

-- =================================================================== bookings
CREATE TABLE IF NOT EXISTS sms.sms_bookings (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles (id),
    resource_id text NOT NULL REFERENCES sms.sms_resources (id),
    booked_by   text NOT NULL,
    booked_on   date NOT NULL,
    starts_at   time NOT NULL,
    ends_at     time NOT NULL,
    quantity    int NOT NULL DEFAULT 1 CHECK (quantity >= 1),
    purpose     text NOT NULL,
    class_id    text REFERENCES sms.sms_classes (id),
    status      text NOT NULL DEFAULT 'confirmed',
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    cancelled_at timestamptz,
    CHECK (ends_at > starts_at)
);
-- Widened later (20261030-35: external hire waits pending, or is declined): never narrowed here.
SELECT sms.widen_check('sms.sms_bookings', 'sms_bookings_status_check', $q$'cancelled'$q$, $q$CHECK (status IN ('confirmed', 'cancelled'))$q$);
CREATE INDEX IF NOT EXISTS sms_bookings_resource_idx ON sms.sms_bookings (resource_id, booked_on) WHERE status = 'confirmed';

-- =================================================================== exams
CREATE TABLE IF NOT EXISTS sms.sms_exam_sessions (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles (id),
    name          text NOT NULL,
    academic_year text NOT NULL,
    term_id       text REFERENCES sms.sms_terms (id) ON DELETE SET NULL,
    starts_on     date NOT NULL,
    ends_on       date NOT NULL,
    status        text NOT NULL DEFAULT 'draft',
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    CHECK (ends_on >= starts_on)
);
ALTER TABLE sms.sms_exam_sessions DROP CONSTRAINT IF EXISTS sms_exam_sessions_status_check;
ALTER TABLE sms.sms_exam_sessions ADD CONSTRAINT sms_exam_sessions_status_check CHECK (status IN ('draft', 'published'));

CREATE TABLE IF NOT EXISTS sms.sms_exam_papers (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    session_id    text NOT NULL REFERENCES sms.sms_exam_sessions (id) ON DELETE CASCADE,
    subject_id    text NOT NULL REFERENCES sms.sms_subjects (id),
    year_group_id text NOT NULL REFERENCES sms.sms_year_groups (id),
    title         text NOT NULL,
    exam_date     date NOT NULL,
    starts_at     time NOT NULL,
    duration_min  int NOT NULL CHECK (duration_min BETWEEN 5 AND 600),
    notes         text
);
CREATE INDEX IF NOT EXISTS sms_exam_papers_session_idx ON sms.sms_exam_papers (session_id, exam_date, starts_at);

CREATE TABLE IF NOT EXISTS sms.sms_exam_paper_rooms (
    paper_id text NOT NULL REFERENCES sms.sms_exam_papers (id) ON DELETE CASCADE,
    room_id  text NOT NULL REFERENCES sms.sms_resources (id),
    PRIMARY KEY (paper_id, room_id)
);

CREATE TABLE IF NOT EXISTS sms.sms_exam_seats (
    paper_id   text NOT NULL REFERENCES sms.sms_exam_papers (id) ON DELETE CASCADE,
    student_id text NOT NULL REFERENCES sms.sms_students (id),
    room_id    text NOT NULL REFERENCES sms.sms_resources (id),
    seat_no    int NOT NULL CHECK (seat_no >= 1),
    PRIMARY KEY (paper_id, student_id),
    UNIQUE (paper_id, room_id, seat_no)
);

CREATE TABLE IF NOT EXISTS sms.sms_exam_invigilators (
    paper_id   text NOT NULL REFERENCES sms.sms_exam_papers (id) ON DELETE CASCADE,
    room_id    text NOT NULL REFERENCES sms.sms_resources (id),
    teacher_id text NOT NULL,
    PRIMARY KEY (paper_id, room_id, teacher_id)
);

-- =================================================================== a family's timetable link
ALTER TABLE sms.sms_families ADD COLUMN IF NOT EXISTS portal_token text;
CREATE UNIQUE INDEX IF NOT EXISTS sms_families_portal_token_idx ON sms.sms_families (portal_token) WHERE portal_token IS NOT NULL;

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-timetable', 'SMS Timetable', 'Timetables, the bell schedule, teacher limits, absences and cover', 'rt-subscribed-app-sms'),
('rt-sms-bookings',  'SMS Bookings',  'Rooms, labs, halls, sports facilities and equipment, and their bookings', 'rt-subscribed-app-sms'),
('rt-sms-exams',     'SMS Exams',     'Exam timetables, rooms, seating plans and invigilators', 'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('timetable', 'rt-sms-timetable', 'get',    'View the timetables, teacher workload and cover'),
    ('timetable', 'rt-sms-timetable', 'manage', 'Build, generate and publish timetables, set teacher limits and arrange cover'),
    ('bookings',  'rt-sms-bookings',  'get',    'View rooms, equipment and their bookings'),
    ('bookings',  'rt-sms-bookings',  'create', 'Book rooms and equipment'),
    ('bookings',  'rt-sms-bookings',  'manage', 'Set up rooms and equipment and cancel anyone''s booking'),
    ('exams',     'rt-sms-exams',     'get',    'View exam timetables, seating plans and invigilator rosters'),
    ('exams',     'rt-sms-exams',     'manage', 'Schedule exams, allocate rooms and seats, and roster invigilators')
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
    SELECT 'role-sms-teacher', k, a FROM (VALUES ('timetable', 'get'), ('bookings', 'get'), ('bookings', 'create'), ('exams', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-registrar', k, a FROM (VALUES ('timetable', 'get'), ('bookings', 'get'), ('bookings', 'create'), ('exams', 'get'), ('exams', 'manage')) AS g(k, a)
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
('sms.timetable',           'app-sms', 'Timetables',                1, 'Build the school week by hand with clash detection, and personal timetables'),
('sms.timetable-generator', 'app-sms', 'Automatic Timetable',       2, 'Generate timetables from teacher availability, rooms, periods per subject and double lessons'),
('sms.workload',            'app-sms', 'Teacher Workload',          2, 'Limits on periods per day and per week for each teacher'),
('sms.cover',               'app-sms', 'Substitution & Cover',      2, 'Cover teachers for absences, notified at once'),
('sms.bookings',            'app-sms', 'Room & Resource Booking',   1, 'Book labs, halls, sports facilities and equipment'),
('sms.exams',               'app-sms', 'Exam Scheduling',           2, 'Exam timetables, room allocation, seating plans and invigilator rosters')
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
                WHERE rp.role_id = 'role-sms-teacher' AND p.app_prefix = 'sms' AND p.action = 'manage') THEN
        RAISE EXCEPTION 'an SMS Teacher manages nothing';
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
