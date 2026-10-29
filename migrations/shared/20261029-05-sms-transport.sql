-- MyEduGuard 14: transport -- safe and efficient student transport.
--
--   sms_transport_settings       each school's alerts (boarding, getting off; text, email) and the
--                                speed estimated arrivals assume
--   sms_vehicles                 the fleet: seats, insurance and roadworthiness, mileage, and the
--                                token a GPS tracker reports with
--   sms_vehicle_services         maintenance: what is due and when, what was done and its cost
--   sms_drivers                  drivers and attendants: licence and its expiry, checks; a staff
--                                account (user_id) to run the bus from the portal
--   sms_transport_routes, _stops routes with their bus, driver and attendant, morning and
--                                afternoon times, the term fee, and pickup points on the map
--   sms_transport_riders         which students ride which route, from which stop, which legs
--   sms_transport_charges        transport fees billed per term, paid at the office or from the
--                                boarding wallet, or waived
--   sms_bus_runs                 a route's morning or afternoon run on a day: started, done
--   sms_bus_positions            where the bus was, from the driver's phone or a tracker
--   sms_rider_events             a student boarding or getting off, by card scan, the app or by hand
--   sms_transport_alerts         the messages sent to families, each once
--
-- Permissions sms|transport|get/mark/manage; the roles MyEduGuard Transport Manager and
-- MyEduGuard Driver. Idempotent.

BEGIN;

CREATE TABLE IF NOT EXISTS sms.sms_transport_settings (
    profile_id      text PRIMARY KEY REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    notify_board    boolean NOT NULL DEFAULT true,
    notify_alight   boolean NOT NULL DEFAULT true,
    notify_sms      boolean NOT NULL DEFAULT true,
    notify_email    boolean NOT NULL DEFAULT false,
    speed_kmh       integer NOT NULL DEFAULT 25,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CHECK (speed_kmh BETWEEN 5 AND 100)
);

CREATE TABLE IF NOT EXISTS sms.sms_vehicles (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    bus_id              text NOT NULL,
    profile_id          text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name                text NOT NULL,
    plate               text NOT NULL,
    make_model          text,
    seats               integer NOT NULL,
    insurer             text,
    insurance_no        text,
    insurance_expires   date,
    roadworthy_expires  date,
    mileage             integer,
    service_every_km    integer,
    service_every_days  integer,
    status              text NOT NULL DEFAULT 'active',
    tracker_token       text NOT NULL DEFAULT replace(gen_random_uuid()::text, '-', ''),
    notes               text,
    archived_at         timestamptz,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    CHECK (seats BETWEEN 1 AND 120),
    CHECK (mileage IS NULL OR mileage >= 0)
);
ALTER TABLE sms.sms_vehicles DROP CONSTRAINT IF EXISTS sms_vehicles_status_check;
ALTER TABLE sms.sms_vehicles ADD CONSTRAINT sms_vehicles_status_check CHECK (status IN ('active', 'maintenance', 'retired'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_vehicles_plate_uq ON sms.sms_vehicles (profile_id, upper(plate)) WHERE archived_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS sms_vehicles_tracker_uq ON sms.sms_vehicles (tracker_token);

CREATE TABLE IF NOT EXISTS sms.sms_vehicle_services (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    vehicle_id  text NOT NULL REFERENCES sms.sms_vehicles(id) ON DELETE CASCADE,
    kind        text NOT NULL DEFAULT 'service',
    title       text NOT NULL,
    due_on      date,
    due_km      integer,
    done_on     date,
    mileage     integer,
    cost        numeric(12,2),
    garage      text,
    note        text,
    recorded_by text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    CHECK (due_on IS NOT NULL OR due_km IS NOT NULL OR done_on IS NOT NULL),
    CHECK (cost IS NULL OR cost >= 0)
);
ALTER TABLE sms.sms_vehicle_services DROP CONSTRAINT IF EXISTS sms_vehicle_services_kind_check;
ALTER TABLE sms.sms_vehicle_services ADD CONSTRAINT sms_vehicle_services_kind_check CHECK (kind IN ('service', 'repair', 'inspection', 'tyres', 'other'));
CREATE INDEX IF NOT EXISTS sms_vehicle_services_idx ON sms.sms_vehicle_services (vehicle_id, coalesce(done_on, due_on) DESC);

CREATE TABLE IF NOT EXISTS sms.sms_drivers (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    profile_id       text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    kind             text NOT NULL DEFAULT 'driver',
    full_name        text NOT NULL,
    phone            text NOT NULL,
    user_id          text,
    licence_no       text,
    licence_class    text,
    licence_expires  date,
    police_check_on  date,
    medical_on       date,
    status           text NOT NULL DEFAULT 'active',
    notes            text,
    archived_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_drivers DROP CONSTRAINT IF EXISTS sms_drivers_check2;
ALTER TABLE sms.sms_drivers ADD CONSTRAINT sms_drivers_check2 CHECK (kind IN ('driver', 'attendant') AND status IN ('active', 'leave', 'left'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_drivers_user_uq ON sms.sms_drivers (profile_id, user_id) WHERE user_id IS NOT NULL AND archived_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_transport_routes (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name          text NOT NULL,
    code          text,
    vehicle_id    text REFERENCES sms.sms_vehicles(id) ON DELETE SET NULL,
    driver_id     text REFERENCES sms.sms_drivers(id) ON DELETE SET NULL,
    attendant_id  text REFERENCES sms.sms_drivers(id) ON DELETE SET NULL,
    am_departs    time,
    pm_departs    time,
    fee           numeric(12,2) NOT NULL DEFAULT 0,
    notes         text,
    archived_at   timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    CHECK (fee >= 0)
);
CREATE UNIQUE INDEX IF NOT EXISTS sms_transport_routes_name_uq ON sms.sms_transport_routes (profile_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_transport_stops (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    route_id    text NOT NULL REFERENCES sms.sms_transport_routes(id) ON DELETE CASCADE,
    name        text NOT NULL,
    landmark    text,
    lat         double precision,
    lng         double precision,
    am_time     time,
    pm_time     time,
    sort_order  integer NOT NULL DEFAULT 0,
    CHECK ((lat IS NULL) = (lng IS NULL) AND (lat IS NULL OR (lat BETWEEN -90 AND 90 AND lng BETWEEN -180 AND 180)))
);
CREATE INDEX IF NOT EXISTS sms_transport_stops_idx ON sms.sms_transport_stops (route_id, sort_order);

CREATE TABLE IF NOT EXISTS sms.sms_transport_riders (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    student_id  text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    route_id    text NOT NULL REFERENCES sms.sms_transport_routes(id) ON DELETE CASCADE,
    stop_id     text REFERENCES sms.sms_transport_stops(id) ON DELETE SET NULL,
    legs        text NOT NULL DEFAULT 'both',
    fee         numeric(12,2),
    starts_on   date NOT NULL DEFAULT CURRENT_DATE,
    ends_on     date,
    added_by    text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    CHECK (fee IS NULL OR fee >= 0),
    CHECK (ends_on IS NULL OR ends_on >= starts_on)
);
ALTER TABLE sms.sms_transport_riders DROP CONSTRAINT IF EXISTS sms_transport_riders_legs_check;
ALTER TABLE sms.sms_transport_riders ADD CONSTRAINT sms_transport_riders_legs_check CHECK (legs IN ('both', 'am', 'pm'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_transport_riders_one ON sms.sms_transport_riders (student_id) WHERE ends_on IS NULL;
CREATE INDEX IF NOT EXISTS sms_transport_riders_route_idx ON sms.sms_transport_riders (route_id);

CREATE TABLE IF NOT EXISTS sms.sms_transport_charges (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id   text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    route_id     text REFERENCES sms.sms_transport_routes(id) ON DELETE SET NULL,
    term_id      text NOT NULL REFERENCES sms.sms_terms(id) ON DELETE CASCADE,
    amount       numeric(12,2) NOT NULL,
    status       text NOT NULL DEFAULT 'unpaid',
    paid_at      timestamptz,
    method       text,
    reference    text,
    settled_by   text,
    note         text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    CHECK (amount > 0),
    UNIQUE (student_id, term_id)
);
ALTER TABLE sms.sms_transport_charges DROP CONSTRAINT IF EXISTS sms_transport_charges_check2;
ALTER TABLE sms.sms_transport_charges ADD CONSTRAINT sms_transport_charges_check2
    CHECK (status IN ('unpaid', 'paid', 'waived') AND (method IS NULL OR method IN ('cash', 'mobile_money', 'bank', 'card', 'cheque', 'wallet')));
CREATE INDEX IF NOT EXISTS sms_transport_charges_idx ON sms.sms_transport_charges (profile_id, term_id, status);

CREATE TABLE IF NOT EXISTS sms.sms_bus_runs (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    route_id     text NOT NULL REFERENCES sms.sms_transport_routes(id) ON DELETE CASCADE,
    run_on       date NOT NULL,
    leg          text NOT NULL,
    vehicle_id   text REFERENCES sms.sms_vehicles(id) ON DELETE SET NULL,
    driver_id    text REFERENCES sms.sms_drivers(id) ON DELETE SET NULL,
    started_by   text,
    started_at   timestamptz NOT NULL DEFAULT now(),
    ended_at     timestamptz,
    UNIQUE (route_id, run_on, leg)
);
ALTER TABLE sms.sms_bus_runs DROP CONSTRAINT IF EXISTS sms_bus_runs_leg_check;
ALTER TABLE sms.sms_bus_runs ADD CONSTRAINT sms_bus_runs_leg_check CHECK (leg IN ('am', 'pm'));
CREATE INDEX IF NOT EXISTS sms_bus_runs_idx ON sms.sms_bus_runs (run_on, route_id);

CREATE TABLE IF NOT EXISTS sms.sms_bus_positions (
    run_id    text REFERENCES sms.sms_bus_runs(id) ON DELETE CASCADE,
    vehicle_id text NOT NULL REFERENCES sms.sms_vehicles(id) ON DELETE CASCADE,
    lat       double precision NOT NULL,
    lng       double precision NOT NULL,
    speed_kmh double precision,
    heading   double precision,
    source    text NOT NULL DEFAULT 'app',
    at        timestamptz NOT NULL DEFAULT now(),
    CHECK (lat BETWEEN -90 AND 90 AND lng BETWEEN -180 AND 180)
);
ALTER TABLE sms.sms_bus_positions DROP CONSTRAINT IF EXISTS sms_bus_positions_source_check;
ALTER TABLE sms.sms_bus_positions ADD CONSTRAINT sms_bus_positions_source_check CHECK (source IN ('app', 'tracker'));
CREATE INDEX IF NOT EXISTS sms_bus_positions_vehicle_idx ON sms.sms_bus_positions (vehicle_id, at DESC);
CREATE INDEX IF NOT EXISTS sms_bus_positions_run_idx ON sms.sms_bus_positions (run_id, at DESC);

CREATE TABLE IF NOT EXISTS sms.sms_rider_events (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    run_id      text NOT NULL REFERENCES sms.sms_bus_runs(id) ON DELETE CASCADE,
    student_id  text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    kind        text NOT NULL,
    method      text NOT NULL DEFAULT 'card',
    stop_id     text REFERENCES sms.sms_transport_stops(id) ON DELETE SET NULL,
    lat         double precision,
    lng         double precision,
    by_user     text,
    at          timestamptz NOT NULL DEFAULT now(),
    UNIQUE (run_id, student_id, kind)
);
ALTER TABLE sms.sms_rider_events DROP CONSTRAINT IF EXISTS sms_rider_events_check2;
ALTER TABLE sms.sms_rider_events ADD CONSTRAINT sms_rider_events_check2 CHECK (kind IN ('board', 'alight') AND method IN ('card', 'app', 'manual'));
CREATE INDEX IF NOT EXISTS sms_rider_events_student_idx ON sms.sms_rider_events (student_id, at DESC);

CREATE TABLE IF NOT EXISTS sms.sms_transport_alerts (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    event_id    text NOT NULL REFERENCES sms.sms_rider_events(id) ON DELETE CASCADE,
    channel     text NOT NULL,
    to_address  text,
    body        text NOT NULL,
    status      text NOT NULL DEFAULT 'queued',
    error       text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (event_id, channel)
);
ALTER TABLE sms.sms_transport_alerts DROP CONSTRAINT IF EXISTS sms_transport_alerts_check2;
ALTER TABLE sms.sms_transport_alerts ADD CONSTRAINT sms_transport_alerts_check2 CHECK (channel IN ('sms', 'email') AND status IN ('queued', 'sent', 'failed'));
CREATE INDEX IF NOT EXISTS sms_transport_alerts_idx ON sms.sms_transport_alerts (profile_id, cdatetime DESC);

-- Transport is a module a school can turn off (Settings, Modules).
ALTER TABLE sms.sms_profiles DROP CONSTRAINT IF EXISTS sms_profiles_modules_check;
ALTER TABLE sms.sms_profiles ADD CONSTRAINT sms_profiles_modules_check CHECK (modules IS NULL OR (cardinality(modules) > 0 AND modules <@ ARRAY[
    'admissions', 'teaching', 'scheduling', 'attendance', 'grading', 'learning', 'welfare', 'inclusion', 'boarding', 'library', 'activities', 'transport']::text[]));

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-transport', 'MyEduGuard Transport', 'Routes and stops, riders and transport fees, drivers and vehicles, live tracking and boarding alerts', 'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, action, label) AS (VALUES
    ('transport', 'get',    'View routes, riders, the fleet, buses on the road and who is on them'),
    ('transport', 'mark',   'Run a bus: start and end a run, share its location, and scan students on and off'),
    ('transport', 'manage', 'Set up routes, stops, vehicles and drivers, allocate students, and bill and settle transport fees')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-sms-' || spec.resource_key || '-' || spec.action,
       'MyEduGuard ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       'rt-sms-transport', spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
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
('role-sms-transport', 'system-tenant-id', 'MyEduGuard Transport Manager', 'Runs school transport: routes and stops, riders and fees, drivers and vehicles, and the buses on the road', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-sms-driver',    'system-tenant-id', 'MyEduGuard Driver', 'Drives or attends a school bus: runs it from the portal, shares its location and scans students on and off', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
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
    SELECT 'role-sms-transport', k, a FROM (VALUES ('transport', 'get'), ('transport', 'mark'), ('transport', 'manage'), ('students', 'get'), ('structure', 'get'),
        ('profiles', 'get'), ('pickup', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-driver', k, a FROM (VALUES ('transport', 'get'), ('transport', 'mark')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-registrar', k, a FROM (VALUES ('transport', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-security', k, a FROM (VALUES ('transport', 'get')) AS g(k, a)
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
  FROM core_platform.cp_permissions p, (VALUES ('role-sms-transport'), ('role-sms-driver')) AS r(id)
 WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.transport-routes',  'app-sms', 'Routes & Stops',               2, 'Routes, pickup points, buses and capacity'),
('sms.transport-riders',  'app-sms', 'Student Transport Allocation', 2, 'Assign students to routes and bill transport fees'),
('sms.fleet',             'app-sms', 'Drivers & Vehicles',           2, 'Driver records, licences, vehicle insurance and maintenance schedules'),
('sms.gps-tracking',      'app-sms', 'Live GPS Tracking',            3, 'Parents see bus location and estimated arrival'),
('sms.boarding-alerts',   'app-sms', 'Boarding & Alighting Alerts',  3, 'Card or app scan when students board and leave the bus')
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
                WHERE rp.role_id = 'role-sms-driver' AND p.app_prefix = 'sms' AND (p.resource_key <> 'transport' OR p.action = 'manage')) THEN
        RAISE EXCEPTION 'a driver runs the bus and nothing else';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-sms-transport' AND p.app_prefix = 'sms' AND p.resource_key IN ('counselling', 'safeguarding')) THEN
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
