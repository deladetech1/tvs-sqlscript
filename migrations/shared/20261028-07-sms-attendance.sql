-- SMS: attendance -- daily and period attendance for students.
--
--   sms_attendance_settings      per school: daily, by lesson or both; when a student is late;
--                                who is told and how; the check-in geofence; the persistent
--                                absence threshold
--   sms_attendance_codes         the school's codes (P, L, E, U, S, M ...), each present, late,
--                                excused or unexcused
--   sms_attendance_registers     a register taken: a class on a day (daily), or a lesson
--   sms_attendance               each student's mark in a register, with how it was taken
--                                (by hand, biometric device, QR scan, approved leave)
--   sms_attendance_devices       fingerprint, face and card readers, each with its own key
--   sms_attendance_identities    a student's card number or biometric id on those devices
--   sms_attendance_alerts        every absence or lateness message sent to a family
--   sms_leave_requests           absence requests and medical notes from parents
--   sms_staff_checkins           staff checking in and out: QR at reception, geofenced phone,
--                                device
--
-- Permissions sms|attendance|get/mark/manage; plan features. Idempotent.

BEGIN;

CREATE TABLE IF NOT EXISTS sms.sms_attendance_settings (
    profile_id         text PRIMARY KEY REFERENCES sms.sms_profiles (id),
    tenant_id          text NOT NULL,
    bus_id             text NOT NULL,
    mode               text NOT NULL DEFAULT 'daily',
    school_starts_at   time NOT NULL DEFAULT '07:30',
    late_after_min     int NOT NULL DEFAULT 15 CHECK (late_after_min BETWEEN 0 AND 240),
    notify_absent      boolean NOT NULL DEFAULT true,
    notify_late        boolean NOT NULL DEFAULT false,
    notify_sms         boolean NOT NULL DEFAULT true,
    notify_email       boolean NOT NULL DEFAULT true,
    persistent_below   numeric(5,2) NOT NULL DEFAULT 90 CHECK (persistent_below BETWEEN 1 AND 100),
    geofence_lat       numeric(9,6),
    geofence_lng       numeric(9,6),
    geofence_radius_m  int CHECK (geofence_radius_m IS NULL OR geofence_radius_m BETWEEN 20 AND 5000),
    qr_secret          text NOT NULL DEFAULT replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
    updated_at         timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_attendance_settings DROP CONSTRAINT IF EXISTS sms_attendance_settings_mode_check;
ALTER TABLE sms.sms_attendance_settings ADD CONSTRAINT sms_attendance_settings_mode_check CHECK (mode IN ('daily', 'period', 'both'));

CREATE TABLE IF NOT EXISTS sms.sms_attendance_codes (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles (id),
    code        text NOT NULL,
    label       text NOT NULL,
    kind        text NOT NULL,
    sort_order  int NOT NULL DEFAULT 0,
    archived_at timestamptz
);
ALTER TABLE sms.sms_attendance_codes DROP CONSTRAINT IF EXISTS sms_attendance_codes_kind_check;
ALTER TABLE sms.sms_attendance_codes ADD CONSTRAINT sms_attendance_codes_kind_check CHECK (kind IN ('present', 'late', 'excused', 'unexcused'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_attendance_codes_code_idx ON sms.sms_attendance_codes (profile_id, upper(code)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_attendance_registers (
    id         text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id  text NOT NULL,
    bus_id     text NOT NULL,
    profile_id text NOT NULL REFERENCES sms.sms_profiles (id),
    class_id   text NOT NULL REFERENCES sms.sms_classes (id),
    taken_on   date NOT NULL,
    -- A lesson's register: the timetable lesson and its period. Null for the day's register.
    slot_id    text REFERENCES sms.sms_timetable_slots (id) ON DELETE SET NULL,
    period_id  text REFERENCES sms.sms_periods (id) ON DELETE SET NULL,
    subject_id text REFERENCES sms.sms_subjects (id),
    taken_by   text,
    taken_at   timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS sms_attendance_registers_one_idx ON sms.sms_attendance_registers (class_id, taken_on, coalesce(period_id, ''));
CREATE INDEX IF NOT EXISTS sms_attendance_registers_day_idx ON sms.sms_attendance_registers (profile_id, taken_on);

CREATE TABLE IF NOT EXISTS sms.sms_attendance (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    register_id  text NOT NULL REFERENCES sms.sms_attendance_registers (id) ON DELETE CASCADE,
    student_id   text NOT NULL REFERENCES sms.sms_students (id),
    code_id      text NOT NULL REFERENCES sms.sms_attendance_codes (id),
    kind         text NOT NULL,
    minutes_late int CHECK (minutes_late IS NULL OR minutes_late BETWEEN 0 AND 600),
    note         text,
    source       text NOT NULL DEFAULT 'manual',
    marked_by    text,
    marked_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (register_id, student_id)
);
ALTER TABLE sms.sms_attendance DROP CONSTRAINT IF EXISTS sms_attendance_source_check;
ALTER TABLE sms.sms_attendance ADD CONSTRAINT sms_attendance_source_check CHECK (source IN ('manual', 'biometric', 'qr', 'mobile', 'leave'));
CREATE INDEX IF NOT EXISTS sms_attendance_student_idx ON sms.sms_attendance (student_id);

CREATE TABLE IF NOT EXISTS sms.sms_attendance_devices (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles (id),
    name        text NOT NULL,
    kind        text NOT NULL,
    place       text,
    key_hash    text NOT NULL,
    key_hint    text NOT NULL,
    last_seen   timestamptz,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    archived_at timestamptz
);
ALTER TABLE sms.sms_attendance_devices DROP CONSTRAINT IF EXISTS sms_attendance_devices_kind_check;
ALTER TABLE sms.sms_attendance_devices ADD CONSTRAINT sms_attendance_devices_kind_check CHECK (kind IN ('fingerprint', 'face', 'card'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_attendance_devices_key_idx ON sms.sms_attendance_devices (key_hash);

CREATE TABLE IF NOT EXISTS sms.sms_attendance_identities (
    profile_id text NOT NULL REFERENCES sms.sms_profiles (id),
    kind       text NOT NULL,
    ref        text NOT NULL,
    student_id text REFERENCES sms.sms_students (id) ON DELETE CASCADE,
    user_id    text,
    PRIMARY KEY (profile_id, kind, ref),
    CHECK ((student_id IS NULL) <> (user_id IS NULL))
);
ALTER TABLE sms.sms_attendance_identities DROP CONSTRAINT IF EXISTS sms_attendance_identities_kind_check;
ALTER TABLE sms.sms_attendance_identities ADD CONSTRAINT sms_attendance_identities_kind_check CHECK (kind IN ('fingerprint', 'face', 'card'));

CREATE TABLE IF NOT EXISTS sms.sms_attendance_alerts (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles (id),
    student_id  text NOT NULL REFERENCES sms.sms_students (id),
    alert_on    date NOT NULL,
    kind        text NOT NULL,
    channel     text NOT NULL,
    to_address  text NOT NULL,
    body        text NOT NULL,
    status      text NOT NULL DEFAULT 'queued',
    error       text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (student_id, alert_on, kind, channel)
);
ALTER TABLE sms.sms_attendance_alerts DROP CONSTRAINT IF EXISTS sms_attendance_alerts_check;
ALTER TABLE sms.sms_attendance_alerts ADD CONSTRAINT sms_attendance_alerts_check
    CHECK (kind IN ('absent', 'late') AND channel IN ('sms', 'email') AND status IN ('queued', 'sent', 'failed'));
CREATE INDEX IF NOT EXISTS sms_attendance_alerts_day_idx ON sms.sms_attendance_alerts (profile_id, alert_on);

CREATE TABLE IF NOT EXISTS sms.sms_leave_requests (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles (id),
    student_id    text NOT NULL REFERENCES sms.sms_students (id),
    starts_on     date NOT NULL,
    ends_on       date NOT NULL,
    reason        text NOT NULL,
    details       text,
    requested_by  text NOT NULL,
    via           text NOT NULL DEFAULT 'portal',
    status        text NOT NULL DEFAULT 'pending',
    decided_by    text,
    decided_at    timestamptz,
    decision_note text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    CHECK (ends_on >= starts_on)
);
ALTER TABLE sms.sms_leave_requests DROP CONSTRAINT IF EXISTS sms_leave_requests_check2;
ALTER TABLE sms.sms_leave_requests ADD CONSTRAINT sms_leave_requests_check2
    CHECK (reason IN ('sick', 'medical', 'family', 'religious', 'travel', 'other') AND via IN ('portal', 'staff')
           AND status IN ('pending', 'approved', 'declined', 'withdrawn'));
CREATE INDEX IF NOT EXISTS sms_leave_requests_idx ON sms.sms_leave_requests (profile_id, status, starts_on);

CREATE TABLE IF NOT EXISTS sms.sms_staff_checkins (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles (id),
    user_id     text NOT NULL,
    checkin_on  date NOT NULL,
    in_at       timestamptz NOT NULL DEFAULT now(),
    out_at      timestamptz,
    method      text NOT NULL,
    lat         numeric(9,6),
    lng         numeric(9,6),
    distance_m  int,
    UNIQUE (profile_id, user_id, checkin_on)
);
ALTER TABLE sms.sms_staff_checkins DROP CONSTRAINT IF EXISTS sms_staff_checkins_method_check;
ALTER TABLE sms.sms_staff_checkins ADD CONSTRAINT sms_staff_checkins_method_check CHECK (method IN ('qr', 'mobile', 'biometric'));

-- A leave request's medical notes go through the file manager like every other record's.
ALTER TABLE sms.sms_files DROP CONSTRAINT IF EXISTS sms_files_entity_check;
ALTER TABLE sms.sms_files ADD CONSTRAINT sms_files_entity_check CHECK (entity_type IS NULL OR entity_type IN
    ('profile', 'application', 'enquiry', 'family', 'student', 'leave_request'));

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-attendance', 'SMS Attendance', 'Registers, attendance codes, devices, leave requests and staff check-in', 'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('mark', 'Mark', false, false)
ON CONFLICT (action) DO NOTHING;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('attendance', 'rt-sms-attendance', 'get',    'View registers, attendance and its analytics'),
    ('attendance', 'rt-sms-attendance', 'mark',   'Take registers: mark students present, late or absent'),
    ('attendance', 'rt-sms-attendance', 'manage', 'Set up attendance, devices and alerts, decide leave requests and correct any register')
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
    SELECT 'role-sms-teacher', k, a FROM (VALUES ('attendance', 'get'), ('attendance', 'mark')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-registrar', k, a FROM (VALUES ('attendance', 'get'), ('attendance', 'mark'), ('attendance', 'manage')) AS g(k, a)
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
('sms.attendance',              'app-sms', 'Daily & Period Attendance', 1, 'Mark by day or by lesson with late, excused and unexcused codes'),
('sms.leave-requests',          'app-sms', 'Leave Requests',            1, 'Parents submit absence requests and medical notes through the portal'),
('sms.attendance-alerts',       'app-sms', 'Absence Notifications',     2, 'Automatic SMS and email to parents when a child is absent or late'),
('sms.attendance-analytics',    'app-sms', 'Attendance Analytics',      2, 'Persistent absence, trends and attendance percentage per student and class'),
('sms.qr-checkin',              'app-sms', 'QR & Mobile Check-in',      2, 'Students check in by their ID card QR; staff by QR or geofenced phone'),
('sms.biometric',               'app-sms', 'Biometric Attendance',      3, 'Fingerprint, facial recognition and card devices')
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
