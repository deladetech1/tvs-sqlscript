-- MyEduGuard: campus operations and facilities -- running a safe, well maintained campus.
--
--   sms_campus_settings      numbering (visitor badges, maintenance jobs, gate passes, bookings)
--                            and who is told what
--   sms_campus_visitors      visitors signed in and out at reception (or expected), with a badge,
--                            their host told they are here
--   sms_maintenance          repairs logged by anyone on the staff, assigned (a member of staff or a
--   sms_maintenance_updates  supplier), tracked to done, with the cost
--   sms_bookings             (Timetable's room bookings) now also external hire: a hirer, a fee, a
--   sms_booking_payments     pending booking approved or declined, and the fee paid
--   sms_gate_passes          students leaving early (who collects them, out and back) and arriving
--                            late (marked late, the family told)
--   sms_hs_records           fire and other drills, inspections (with the next one due) and health
--   sms_hs_actions           and safety incidents, each with its corrective actions
--
-- The school calendar is the academic calendar's terms and days, with PTA meetings and parents'
-- evenings, exams and events, shown together and published as a calendar families can subscribe to.
-- Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS sms.sms_campus_settings (
    profile_id         text PRIMARY KEY REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    badge_prefix       text NOT NULL DEFAULT 'V',
    next_badge         integer NOT NULL DEFAULT 1,
    job_prefix         text NOT NULL DEFAULT 'MR',
    next_job           integer NOT NULL DEFAULT 1,
    pass_prefix        text NOT NULL DEFAULT 'GP',
    next_pass          integer NOT NULL DEFAULT 1,
    booking_prefix     text NOT NULL DEFAULT 'BK',
    next_booking       integer NOT NULL DEFAULT 1,
    hs_prefix          text NOT NULL DEFAULT 'HS',
    next_hs            integer NOT NULL DEFAULT 1,
    notify_host        boolean NOT NULL DEFAULT true,
    notify_family_pass boolean NOT NULL DEFAULT true,
    hire_terms         text,
    publish_calendar   boolean NOT NULL DEFAULT true,
    updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sms.sms_campus_visitors (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    badge           text,
    name            text NOT NULL,
    phone           text,
    email           text,
    organisation    text,
    purpose         text NOT NULL DEFAULT 'meeting',
    detail          text,
    host_staff_id   text REFERENCES sms.sms_staff(id) ON DELETE SET NULL,
    host_name       text,
    id_type         text,
    id_number       text,
    vehicle_reg     text,
    expected_on     date,
    expected_at     time,
    status          text NOT NULL DEFAULT 'in',
    arrived_at      timestamptz,
    left_at         timestamptz,
    signed_in_by    text,
    signed_out_by   text,
    host_told_at    timestamptz,
    note            text,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_campus_visitors', 'sms_campus_visitors_check', $q$'contractor'$q$, $q$CHECK (
    status IN ('expected', 'in', 'out', 'cancelled')
    AND purpose IN ('meeting', 'parent', 'delivery', 'contractor', 'interview', 'official', 'event', 'other'))$q$);
CREATE INDEX IF NOT EXISTS sms_campus_visitors_idx ON sms.sms_campus_visitors (profile_id, status, arrived_at DESC);

CREATE TABLE IF NOT EXISTS sms.sms_maintenance (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id          text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    number              text NOT NULL,
    title               text NOT NULL,
    description         text,
    category            text NOT NULL DEFAULT 'other',
    priority            text NOT NULL DEFAULT 'normal',
    resource_id         text REFERENCES sms.sms_resources(id) ON DELETE SET NULL,
    location            text,
    asset_id            text REFERENCES sms.sms_proc_assets(id) ON DELETE SET NULL,
    reported_by         text,
    status              text NOT NULL DEFAULT 'open',
    assigned_staff_id   text REFERENCES sms.sms_staff(id) ON DELETE SET NULL,
    supplier_id         text REFERENCES sms.sms_proc_suppliers(id) ON DELETE SET NULL,
    due_on              date,
    cost                numeric(14,2),
    resolution          text,
    completed_at        timestamptz,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    UNIQUE (profile_id, number)
);
SELECT sms.widen_check('sms.sms_maintenance', 'sms_maintenance_check', $q$'on_hold'$q$, $q$CHECK (
    category IN ('electrical', 'plumbing', 'carpentry', 'building', 'ict', 'cleaning', 'grounds', 'painting', 'security', 'furniture', 'other')
    AND priority IN ('low', 'normal', 'high', 'urgent')
    AND status IN ('open', 'assigned', 'in_progress', 'on_hold', 'done', 'cancelled')
    AND (cost IS NULL OR cost >= 0))$q$);
CREATE INDEX IF NOT EXISTS sms_maintenance_status_idx ON sms.sms_maintenance (profile_id, status, cdatetime DESC);

CREATE TABLE IF NOT EXISTS sms.sms_maintenance_updates (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    job_id      text NOT NULL REFERENCES sms.sms_maintenance(id) ON DELETE CASCADE,
    status      text,
    note        text,
    by_user     text,
    at          timestamptz NOT NULL DEFAULT now()
);

-- Facility booking: a room booking may be for an outside hirer, with a fee, waiting for approval.
ALTER TABLE sms.sms_bookings ADD COLUMN IF NOT EXISTS number text;
ALTER TABLE sms.sms_bookings ADD COLUMN IF NOT EXISTS external boolean NOT NULL DEFAULT false;
ALTER TABLE sms.sms_bookings ADD COLUMN IF NOT EXISTS event_title text;
ALTER TABLE sms.sms_bookings ADD COLUMN IF NOT EXISTS hirer_name text;
ALTER TABLE sms.sms_bookings ADD COLUMN IF NOT EXISTS hirer_phone text;
ALTER TABLE sms.sms_bookings ADD COLUMN IF NOT EXISTS hirer_email text;
ALTER TABLE sms.sms_bookings ADD COLUMN IF NOT EXISTS organisation text;
ALTER TABLE sms.sms_bookings ADD COLUMN IF NOT EXISTS attendees integer;
ALTER TABLE sms.sms_bookings ADD COLUMN IF NOT EXISTS fee numeric(14,2) NOT NULL DEFAULT 0;
ALTER TABLE sms.sms_bookings ADD COLUMN IF NOT EXISTS notes text;
ALTER TABLE sms.sms_bookings ADD COLUMN IF NOT EXISTS on_calendar boolean NOT NULL DEFAULT false;
ALTER TABLE sms.sms_bookings ADD COLUMN IF NOT EXISTS decided_by text;
ALTER TABLE sms.sms_bookings ADD COLUMN IF NOT EXISTS decided_at timestamptz;
ALTER TABLE sms.sms_bookings ADD COLUMN IF NOT EXISTS decline_reason text;
SELECT sms.widen_check('sms.sms_bookings', 'sms_bookings_status_check', $q$'pending'$q$, $q$CHECK (status IN ('confirmed', 'cancelled', 'pending', 'declined'))$q$);
SELECT sms.widen_check('sms.sms_resources', 'sms_resources_kind_check', $q$'field'$q$, $q$CHECK (kind IN ('classroom', 'lab', 'ict', 'hall', 'sports', 'library', 'other', 'equipment', 'field', 'pool', 'chapel'))$q$);

CREATE TABLE IF NOT EXISTS sms.sms_booking_payments (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    booking_id    text NOT NULL REFERENCES sms.sms_bookings(id) ON DELETE CASCADE,
    amount        numeric(14,2) NOT NULL,
    method        text NOT NULL DEFAULT 'cash',
    reference     text,
    paid_on       date NOT NULL,
    journal_id    text REFERENCES sms.sms_gl_journals(id),
    by_user       text,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_booking_payments', 'sms_booking_payments_check', $q$amount > 0$q$, $q$CHECK (amount > 0)$q$);

CREATE TABLE IF NOT EXISTS sms.sms_gate_passes (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id         text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    number             text NOT NULL,
    kind               text NOT NULL,
    student_id         text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    reason_kind        text NOT NULL DEFAULT 'other',
    reason             text,
    issued_at          timestamptz NOT NULL DEFAULT now(),
    leave_at           timestamptz,
    collected_by       text,
    relationship       text,
    collector_id       text,
    coming_back        boolean NOT NULL DEFAULT false,
    left_at            timestamptz,
    returned_at        timestamptz,
    minutes_late       integer,
    status             text NOT NULL DEFAULT 'issued',
    authorized_by      text,
    family_told        text,
    note               text,
    UNIQUE (profile_id, number)
);
SELECT sms.widen_check('sms.sms_gate_passes', 'sms_gate_passes_check', $q$'transport'$q$, $q$CHECK (
    kind IN ('early_exit', 'late_arrival') AND status IN ('issued', 'left', 'returned', 'cancelled', 'recorded')
    AND reason_kind IN ('medical', 'family', 'appointment', 'disciplinary', 'transport', 'sports', 'other'))$q$);
CREATE INDEX IF NOT EXISTS sms_gate_passes_idx ON sms.sms_gate_passes (profile_id, issued_at DESC);

CREATE TABLE IF NOT EXISTS sms.sms_hs_records (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    number        text NOT NULL,
    kind          text NOT NULL,
    subtype       text,
    title         text NOT NULL,
    occurred_on   date NOT NULL,
    occurred_at   time,
    resource_id   text REFERENCES sms.sms_resources(id) ON DELETE SET NULL,
    location      text,
    details       jsonb NOT NULL DEFAULT '{}',
    findings      text,
    severity      text,
    result        text,
    next_due_on   date,
    status        text NOT NULL DEFAULT 'open',
    reported_by   text,
    closed_at     timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    UNIQUE (profile_id, number)
);
SELECT sms.widen_check('sms.sms_hs_records', 'sms_hs_records_check', $q$'advisory'$q$, $q$CHECK (
    kind IN ('drill', 'inspection', 'incident') AND status IN ('open', 'closed')
    AND (severity IS NULL OR severity IN ('near_miss', 'minor', 'moderate', 'serious'))
    AND (result IS NULL OR result IN ('pass', 'fail', 'advisory')))$q$);
CREATE INDEX IF NOT EXISTS sms_hs_records_idx ON sms.sms_hs_records (profile_id, kind, occurred_on DESC);

CREATE TABLE IF NOT EXISTS sms.sms_hs_actions (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    record_id       text NOT NULL REFERENCES sms.sms_hs_records(id) ON DELETE CASCADE,
    action          text NOT NULL,
    owner_staff_id  text REFERENCES sms.sms_staff(id) ON DELETE SET NULL,
    due_on          date,
    done_at         timestamptz,
    done_by         text,
    note            text,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);

-- Photos of a repair; a safety record's evidence.
SELECT sms.widen_check('sms.sms_files', 'sms_files_entity_check', $q$'hs_record'$q$, $q$CHECK (entity_type IS NULL OR entity_type IN
    ('profile', 'application', 'enquiry', 'family', 'student', 'leave_request', 'assignment', 'submission', 'class_resource', 'pickup_person', 'incident',
     'safeguarding', 'achievement', 'service_hours', 'trip', 'staff', 'staff_document', 'staff_check', 'job_application', 'staff_leave', 'payslip',
     'staff_cpd', 'gl_expense', 'gl_asset', 'maintenance', 'hs_record'))$q$);

-- The school calendar: PTA meetings and parents' evenings, beside holidays, closures, events,
-- meetings, exams and sports.
SELECT sms.widen_check('sms.sms_calendar_events', 'sms_calendar_events_kind_check', $q$'pta'$q$, $q$CHECK (kind IN ('holiday', 'closure', 'event', 'meeting', 'exam', 'sports', 'pta', 'parents', 'trip'))$q$);

-- Campus operations is a module a school can turn off (Settings, Modules).
SELECT sms.widen_check('sms.sms_profiles', 'sms_profiles_modules_check', $q$'campus'$q$, $q$CHECK (modules IS NULL OR (cardinality(modules) > 0 AND modules <@ ARRAY[
    'admissions', 'teaching', 'scheduling', 'attendance', 'grading', 'learning', 'welfare', 'inclusion', 'boarding', 'library', 'activities', 'transport',
    'catering', 'hr', 'fees', 'finance', 'procurement', 'campus']::text[]))$q$);

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-campus', 'MyEduGuard Campus', 'Visitors, maintenance, facility bookings and hire, gate and late passes, and health and safety records', 'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, action, label) AS (VALUES
    ('campus', 'get',      'View visitors, maintenance jobs, facility bookings, gate passes and health and safety records'),
    ('campus', 'transact', 'Sign visitors in and out, issue gate and late passes, and log and work on maintenance jobs'),
    ('campus', 'manage',   'Assign maintenance, approve facility hire and take its fees, record drills, inspections and incidents, and set up campus operations')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-sms-' || spec.resource_key || '-' || spec.action,
       'MyEduGuard ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       'rt-sms-campus', spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
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
('role-sms-facilities', 'system-tenant-id', 'MyEduGuard Facilities Manager', 'Runs the campus: maintenance, facility bookings and hire, visitors and gate passes, and health and safety', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-sms-reception', 'system-tenant-id', 'MyEduGuard Receptionist', 'Signs visitors in and out with their badges, tells their hosts, and issues gate and late passes', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
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
    SELECT 'role-sms-facilities', k, a FROM (VALUES ('campus', 'get'), ('campus', 'transact'), ('campus', 'manage'), ('students', 'get'), ('structure', 'get'),
        ('profiles', 'get'), ('procurement', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-reception', k, a FROM (VALUES ('campus', 'get'), ('campus', 'transact'), ('students', 'get'), ('structure', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-security', k, a FROM (VALUES ('campus', 'get'), ('campus', 'transact')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-viewer', 'campus', 'get'
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'sms' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', r.id, p.id
  FROM core_platform.cp_permissions p CROSS JOIN (VALUES ('role-sms-facilities'), ('role-sms-reception')) AS r(id)
 WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.campus-visitors',  'app-sms', 'Visitor Management',           1, 'Visitor sign in, badges and host notifications'),
('sms.maintenance',      'app-sms', 'Maintenance Requests',         1, 'Log, assign and track repairs'),
('sms.facility-booking', 'app-sms', 'Facility & Event Booking',     2, 'Halls, fields and rooms for internal and external bookings'),
('sms.gate-passes',      'app-sms', 'Gate Pass & Late Pass',        1, 'Passes for students leaving early or arriving late'),
('sms.health-safety',    'app-sms', 'Health & Safety Records',      2, 'Fire drills, inspections and incident reports'),
('sms.school-calendar',  'app-sms', 'School Calendar',              1, 'Terms, holidays, exams, PTA meetings and events')
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
                WHERE rp.role_id IN ('role-sms-facilities', 'role-sms-reception') AND p.app_prefix = 'sms'
                  AND p.resource_key IN ('counselling', 'safeguarding', 'hr', 'finance', 'fees')) THEN
        RAISE EXCEPTION 'counselling, safeguarding, staff records and money are not reception''s';
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
