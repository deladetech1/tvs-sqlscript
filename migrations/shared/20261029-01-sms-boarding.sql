-- MyEduGuard 11: boarding and residential life -- for boarding and residential schools.
--
--   sms_hostels, _boarding_rooms,  boarding houses, their dormitories and rooms, and the beds,
--   _beds                          each with the boarder in it: the occupancy view
--   sms_hostel_staff, _duties      housemasters, housemistresses, matrons and assistants; the
--                                  duty roster
--   sms_exeats                     weekend, term and day leave: asked by the family (or raised by
--                                  the house and approved by the family), approved by the house,
--                                  signed out and signed back in
--   sms_boarding_rollcalls, _marks evening, night and morning roll calls, taken on a phone
--   sms_wallets, _wallet_txns      pocket money: the family tops up, staff record withdrawals and
--                                  purchases; a family's top-up is confirmed when the money is in
--   sms_visiting_days, _visitors   visiting days, and each visitor signed in and out
--   sms_belongings, _laundry       an optional inventory of what a boarder brings, and the laundry
--
-- Permissions sms|boarding|get/mark/manage; the roles MyEduGuard Housemaster and Matron. Idempotent.

BEGIN;

CREATE TABLE IF NOT EXISTS sms.sms_hostels (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name         text NOT NULL,
    gender       text NOT NULL DEFAULT 'mixed',
    notes        text,
    archived_at  timestamptz,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_hostels DROP CONSTRAINT IF EXISTS sms_hostels_gender_check;
ALTER TABLE sms.sms_hostels ADD CONSTRAINT sms_hostels_gender_check CHECK (gender IN ('boys', 'girls', 'mixed'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_hostels_name_uq ON sms.sms_hostels (profile_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_boarding_rooms (
    id         text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    hostel_id  text NOT NULL REFERENCES sms.sms_hostels(id) ON DELETE CASCADE,
    name       text NOT NULL,
    kind       text NOT NULL DEFAULT 'dormitory',
    floor      text,
    sort_order integer NOT NULL DEFAULT 0,
    archived_at timestamptz
);
ALTER TABLE sms.sms_boarding_rooms DROP CONSTRAINT IF EXISTS sms_boarding_rooms_kind_check;
ALTER TABLE sms.sms_boarding_rooms ADD CONSTRAINT sms_boarding_rooms_kind_check CHECK (kind IN ('dormitory', 'room', 'cubicle', 'sick_room'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_boarding_rooms_name_uq ON sms.sms_boarding_rooms (hostel_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_beds (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    room_id       text NOT NULL REFERENCES sms.sms_boarding_rooms(id) ON DELETE CASCADE,
    label         text NOT NULL,
    student_id    text REFERENCES sms.sms_students(id) ON DELETE SET NULL,
    allocated_on  date,
    out_of_use    boolean NOT NULL DEFAULT false,
    sort_order    integer NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX IF NOT EXISTS sms_beds_label_uq ON sms.sms_beds (room_id, lower(label));
CREATE UNIQUE INDEX IF NOT EXISTS sms_beds_one_student ON sms.sms_beds (student_id) WHERE student_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS sms.sms_hostel_staff (
    hostel_id  text NOT NULL REFERENCES sms.sms_hostels(id) ON DELETE CASCADE,
    user_id    text NOT NULL,
    role       text NOT NULL,
    PRIMARY KEY (hostel_id, user_id)
);
ALTER TABLE sms.sms_hostel_staff DROP CONSTRAINT IF EXISTS sms_hostel_staff_role_check;
ALTER TABLE sms.sms_hostel_staff ADD CONSTRAINT sms_hostel_staff_role_check CHECK (role IN ('housemaster', 'housemistress', 'matron', 'assistant', 'tutor'));

CREATE TABLE IF NOT EXISTS sms.sms_boarding_duties (
    id         text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    hostel_id  text NOT NULL REFERENCES sms.sms_hostels(id) ON DELETE CASCADE,
    user_id    text NOT NULL,
    duty_on    date NOT NULL,
    shift      text NOT NULL,
    notes      text,
    UNIQUE (hostel_id, duty_on, shift, user_id)
);
ALTER TABLE sms.sms_boarding_duties DROP CONSTRAINT IF EXISTS sms_boarding_duties_shift_check;
ALTER TABLE sms.sms_boarding_duties ADD CONSTRAINT sms_boarding_duties_shift_check CHECK (shift IN ('morning', 'day', 'evening', 'night'));
CREATE INDEX IF NOT EXISTS sms_boarding_duties_idx ON sms.sms_boarding_duties (duty_on);

CREATE TABLE IF NOT EXISTS sms.sms_exeats (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    bus_id             text NOT NULL,
    profile_id         text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id         text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    kind               text NOT NULL,
    leaves_at          timestamptz NOT NULL,
    returns_at         timestamptz NOT NULL,
    destination        text NOT NULL,
    escort_name        text,
    escort_phone       text,
    reason             text,
    raised_by          text NOT NULL,
    raised_by_user     text,
    parent_approved_at timestamptz,
    parent_name        text,
    status             text NOT NULL,
    decided_by         text,
    decided_at         timestamptz,
    decision_note      text,
    signed_out_at      timestamptz,
    signed_out_by      text,
    signed_in_at       timestamptz,
    signed_in_by       text,
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    CHECK (returns_at > leaves_at)
);
ALTER TABLE sms.sms_exeats DROP CONSTRAINT IF EXISTS sms_exeats_check2;
ALTER TABLE sms.sms_exeats ADD CONSTRAINT sms_exeats_check2
    CHECK (kind IN ('weekend', 'term', 'day', 'medical', 'family', 'other') AND raised_by IN ('family', 'house')
           AND status IN ('awaiting_family', 'awaiting_house', 'approved', 'declined', 'out', 'returned', 'cancelled'));
CREATE INDEX IF NOT EXISTS sms_exeats_idx ON sms.sms_exeats (profile_id, status, leaves_at);
CREATE INDEX IF NOT EXISTS sms_exeats_student_idx ON sms.sms_exeats (student_id, leaves_at DESC);

CREATE TABLE IF NOT EXISTS sms.sms_boarding_rollcalls (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    hostel_id   text NOT NULL REFERENCES sms.sms_hostels(id) ON DELETE CASCADE,
    kind        text NOT NULL,
    taken_on    date NOT NULL,
    started_by  text,
    started_at  timestamptz NOT NULL DEFAULT now(),
    closed_at   timestamptz,
    UNIQUE (hostel_id, taken_on, kind)
);
ALTER TABLE sms.sms_boarding_rollcalls DROP CONSTRAINT IF EXISTS sms_boarding_rollcalls_kind_check;
ALTER TABLE sms.sms_boarding_rollcalls ADD CONSTRAINT sms_boarding_rollcalls_kind_check CHECK (kind IN ('morning', 'evening', 'night'));

CREATE TABLE IF NOT EXISTS sms.sms_boarding_marks (
    rollcall_id text NOT NULL REFERENCES sms.sms_boarding_rollcalls(id) ON DELETE CASCADE,
    student_id  text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    status      text NOT NULL,
    note        text,
    marked_by   text,
    marked_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (rollcall_id, student_id)
);
ALTER TABLE sms.sms_boarding_marks DROP CONSTRAINT IF EXISTS sms_boarding_marks_status_check;
ALTER TABLE sms.sms_boarding_marks ADD CONSTRAINT sms_boarding_marks_status_check CHECK (status IN ('present', 'absent', 'exeat', 'sick_bay', 'excused'));

CREATE TABLE IF NOT EXISTS sms.sms_wallets (
    student_id   text PRIMARY KEY REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    balance      numeric(12,2) NOT NULL DEFAULT 0,
    daily_limit  numeric(12,2),
    low_alert    numeric(12,2),
    frozen       boolean NOT NULL DEFAULT false,
    updated_at   timestamptz NOT NULL DEFAULT now(),
    CHECK (balance >= 0)
);

CREATE TABLE IF NOT EXISTS sms.sms_wallet_txns (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    student_id     text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    kind           text NOT NULL,
    amount         numeric(12,2) NOT NULL,
    balance_after  numeric(12,2),
    status         text NOT NULL DEFAULT 'posted',
    method         text,
    reference      text,
    note           text,
    by_user        text,
    by_family      text,
    confirmed_by   text,
    confirmed_at   timestamptz,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    CHECK (amount > 0)
);
ALTER TABLE sms.sms_wallet_txns DROP CONSTRAINT IF EXISTS sms_wallet_txns_check2;
ALTER TABLE sms.sms_wallet_txns ADD CONSTRAINT sms_wallet_txns_check2
    CHECK (kind IN ('topup', 'withdrawal', 'purchase', 'refund', 'adjustment_in', 'adjustment_out') AND status IN ('pending', 'posted', 'rejected')
           AND (method IS NULL OR method IN ('cash', 'mobile_money', 'bank', 'card', 'cheque')));
CREATE INDEX IF NOT EXISTS sms_wallet_txns_idx ON sms.sms_wallet_txns (student_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS sms_wallet_txns_pending ON sms.sms_wallet_txns (status) WHERE status = 'pending';

CREATE TABLE IF NOT EXISTS sms.sms_visiting_days (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    visit_on    date NOT NULL,
    starts_at   time NOT NULL,
    ends_at     time NOT NULL,
    title       text NOT NULL,
    notes       text,
    hostel_ids  text[] NOT NULL DEFAULT '{}',
    created_by  text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    CHECK (ends_at > starts_at)
);
CREATE INDEX IF NOT EXISTS sms_visiting_days_idx ON sms.sms_visiting_days (profile_id, visit_on);

CREATE TABLE IF NOT EXISTS sms.sms_visitors (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id      text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    visiting_day_id text REFERENCES sms.sms_visiting_days(id) ON DELETE SET NULL,
    visitor_name    text NOT NULL,
    relationship    text NOT NULL,
    phone           text,
    id_number       text,
    known           boolean NOT NULL DEFAULT false,
    arrived_at      timestamptz NOT NULL DEFAULT now(),
    left_at         timestamptz,
    note            text,
    checked_in_by   text,
    checked_out_by  text
);
CREATE INDEX IF NOT EXISTS sms_visitors_idx ON sms.sms_visitors (profile_id, arrived_at DESC);

CREATE TABLE IF NOT EXISTS sms.sms_belongings (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    student_id  text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    item        text NOT NULL,
    quantity    integer NOT NULL DEFAULT 1,
    description text,
    name_marked boolean NOT NULL DEFAULT false,
    status      text NOT NULL DEFAULT 'with_student',
    checked_on  date NOT NULL DEFAULT CURRENT_DATE,
    note        text,
    created_by  text,
    updated_at  timestamptz NOT NULL DEFAULT now(),
    CHECK (quantity BETWEEN 1 AND 500)
);
ALTER TABLE sms.sms_belongings DROP CONSTRAINT IF EXISTS sms_belongings_status_check;
ALTER TABLE sms.sms_belongings ADD CONSTRAINT sms_belongings_status_check CHECK (status IN ('with_student', 'in_laundry', 'lost', 'gone_home', 'confiscated'));
CREATE INDEX IF NOT EXISTS sms_belongings_idx ON sms.sms_belongings (student_id);

CREATE TABLE IF NOT EXISTS sms.sms_laundry (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    student_id  text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    sent_on     date NOT NULL DEFAULT CURRENT_DATE,
    items       integer NOT NULL,
    returned_on date,
    returned    integer,
    note        text,
    by_user     text,
    CHECK (items BETWEEN 1 AND 200 AND (returned IS NULL OR returned BETWEEN 0 AND items))
);
CREATE INDEX IF NOT EXISTS sms_laundry_idx ON sms.sms_laundry (student_id, sent_on DESC);

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-boarding', 'MyEduGuard Boarding', 'Boarding houses, rooms and beds, house staff, exeats, roll calls, pocket money, visitors and belongings', 'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, action, label) AS (VALUES
    ('boarding', 'get',    'View boarding houses, boarders, exeats, roll calls, pocket money and visitors'),
    ('boarding', 'mark',   'Take boarding roll calls, sign boarders out and in, record pocket money withdrawals and purchases, sign visitors in and out'),
    ('boarding', 'manage', 'Set up houses, rooms and beds, allocate beds, keep the duty roster, approve exeats and confirm top-ups')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-sms-' || spec.resource_key || '-' || spec.action,
       'MyEduGuard ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       'rt-sms-boarding', spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
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
('role-sms-housemaster', 'system-tenant-id', 'MyEduGuard Housemaster', 'Runs a boarding house: rooms and beds, the duty roster, exeats, roll calls, pocket money and visitors', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-sms-matron',      'system-tenant-id', 'MyEduGuard Matron', 'Looks after boarders: roll calls, signing out and in, pocket money, visitors, belongings and laundry', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
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
    SELECT 'role-sms-registrar', k, a FROM (VALUES ('boarding', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-security', k, a FROM (VALUES ('boarding', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-housemaster', k, a FROM (VALUES ('boarding', 'get'), ('boarding', 'mark'), ('boarding', 'manage'), ('students', 'get'), ('structure', 'get'),
        ('profiles', 'get'), ('health', 'get'), ('clinic', 'get'), ('behaviour', 'get'), ('behaviour', 'create'), ('pickup', 'get'), ('safeguarding', 'create'),
        ('emergency', 'get'), ('emergency', 'mark')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-matron', k, a FROM (VALUES ('boarding', 'get'), ('boarding', 'mark'), ('students', 'get'), ('structure', 'get'), ('profiles', 'get'),
        ('health', 'get'), ('clinic', 'get'), ('pickup', 'get'), ('safeguarding', 'create'), ('emergency', 'get'), ('emergency', 'mark')) AS g(k, a)
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
SELECT 'system-tenant-id', r.id, p.id
  FROM core_platform.cp_permissions p, (VALUES ('role-sms-housemaster'), ('role-sms-matron')) AS r(id)
 WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.hostels',            'app-sms', 'Hostel & Room Allocation',      2, 'Houses, dormitories, rooms and beds with an occupancy view'),
('sms.house-staff',        'app-sms', 'House Staff Management',        2, 'Housemasters, matrons and duty rosters'),
('sms.exeats',             'app-sms', 'Exeat & Leave Management',      2, 'Weekend and term leave with parent approval, and sign-out and sign-in logs'),
('sms.boarding-rollcalls', 'app-sms', 'Boarding Roll Calls',           2, 'Evening and night roll calls from mobile devices'),
('sms.visitors',           'app-sms', 'Visiting Days & Visitor Logs',  2, 'Schedule visits and record visitors'),
('sms.wallet',             'app-sms', 'Student Wallet & Pocket Money', 3, 'Parents top up; staff record withdrawals and purchases'),
('sms.belongings',         'app-sms', 'Laundry & Belongings Tracking', 3, 'An optional inventory of student belongings')
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
                WHERE rp.role_id IN ('role-sms-viewer', 'role-sms-teacher', 'role-sms-registrar', 'role-sms-admissions', 'role-sms-nurse', 'role-sms-security',
                                     'role-sms-senco', 'role-sms-housemaster', 'role-sms-matron')
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
