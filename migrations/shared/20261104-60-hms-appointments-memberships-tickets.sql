-- HMS for every kind of hospitality business, part 1: what is booked by the slot, what is
-- joined, and what is sold at the door.
--
--   hms_services           what is booked by the slot: a massage, a haircut, a personal
--                          training session, a meeting room, a tennis court, a tee time, an
--                          airport pick-up, a tour; how long, how much (a booking, an hour or
--                          a person), and whether guests book it online
--   hms_bookables          who or what it is booked with: a therapist, a stylist, a trainer,
--                          a treatment room, a meeting room, a court, a vehicle, a driver;
--                          the services each does, and the hours and days it works
--   hms_appointments       a slot booked: the service, with whom, when, for whom (a walk-in,
--                          a guest in house, a member), the price, how it was paid or the room
--                          it was charged to; a transfer's pick-up and drop-off
--   hms_membership_plans   gyms, spas, members' clubs: a plan's dues and how often, a joining
--                          fee, visits included, the member discount
--   hms_members            a member: their number, plan, paid-up-to date and status
--   hms_member_payments    dues paid, each extending paid_until
--   hms_member_visits      check-ins at the door or the desk
--   hms_ticket_events      events and club nights tickets are sold for
--   hms_ticket_types       an event's tickets: early bird, regular, VIP table (with its
--                          minimum spend), how many, admitting how many
--   hms_tickets            one ticket each, with a code scanned at the door; the tickets
--                          bought together share a sale_id (one payment, one receipt)
--   hms_guest_lists        names on the door, with plus-ones
--   hms_table_bookings.min_spend   bottle service: the table's minimum spend
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

-- ==================================================================== appointments
CREATE TABLE IF NOT EXISTS hms.hms_services (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    name             text NOT NULL,
    category         text NOT NULL DEFAULT 'spa',
    description      text,
    duration_minutes int NOT NULL DEFAULT 60 CHECK (duration_minutes BETWEEN 5 AND 1440),
    buffer_minutes   int NOT NULL DEFAULT 0 CHECK (buffer_minutes BETWEEN 0 AND 240),
    price            numeric(14,2) NOT NULL DEFAULT 0 CHECK (price >= 0),
    price_per        text NOT NULL DEFAULT 'booking',
    capacity         int NOT NULL DEFAULT 1 CHECK (capacity BETWEEN 1 AND 1000),
    online           boolean NOT NULL DEFAULT true,
    active           boolean NOT NULL DEFAULT true,
    sort_order       int NOT NULL DEFAULT 0,
    archived_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hms.hms_services DROP CONSTRAINT IF EXISTS hms_services_category_check;
ALTER TABLE hms.hms_services ADD CONSTRAINT hms_services_category_check CHECK (category IN
    ('spa', 'salon', 'fitness', 'wellness', 'meeting_room', 'coworking', 'court', 'golf', 'transport', 'tour', 'other'));
ALTER TABLE hms.hms_services DROP CONSTRAINT IF EXISTS hms_services_price_per_check;
ALTER TABLE hms.hms_services ADD CONSTRAINT hms_services_price_per_check CHECK (price_per IN ('booking', 'hour', 'person'));
CREATE INDEX IF NOT EXISTS hms_services_property_idx ON hms.hms_services (bus_id, property_id);

CREATE TABLE IF NOT EXISTS hms.hms_bookables (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    name             text NOT NULL,
    kind             text NOT NULL DEFAULT 'therapist',
    user_id          text,
    service_ids      text[] NOT NULL DEFAULT '{}',
    opens_at         time NOT NULL DEFAULT '08:00',
    closes_at        time NOT NULL DEFAULT '20:00',
    days             int[] NOT NULL DEFAULT '{1,2,3,4,5,6,7}',
    active           boolean NOT NULL DEFAULT true,
    sort_order       int NOT NULL DEFAULT 0,
    archived_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hms.hms_bookables DROP CONSTRAINT IF EXISTS hms_bookables_kind_check;
ALTER TABLE hms.hms_bookables ADD CONSTRAINT hms_bookables_kind_check CHECK (kind IN
    ('therapist', 'stylist', 'trainer', 'instructor', 'treatment_room', 'meeting_room', 'desk', 'court', 'course', 'vehicle', 'driver', 'guide', 'other'));
ALTER TABLE hms.hms_bookables DROP CONSTRAINT IF EXISTS hms_bookables_hours_check;
ALTER TABLE hms.hms_bookables ADD CONSTRAINT hms_bookables_hours_check CHECK (closes_at > opens_at);
CREATE INDEX IF NOT EXISTS hms_bookables_property_idx ON hms.hms_bookables (bus_id, property_id);

CREATE TABLE IF NOT EXISTS hms.hms_appointments (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    service_id       text NOT NULL REFERENCES hms.hms_services (id),
    bookable_id      text NOT NULL REFERENCES hms.hms_bookables (id),
    code             text NOT NULL,
    starts_at        timestamptz NOT NULL,
    ends_at          timestamptz NOT NULL,
    party_size       int NOT NULL DEFAULT 1 CHECK (party_size >= 1),
    name             text NOT NULL,
    phone            text,
    email            text,
    guest_id         text REFERENCES hms.hms_guests (id),
    reservation_id   text REFERENCES hms.hms_reservations (id),
    member_id        text,
    status           text NOT NULL DEFAULT 'booked',
    price            numeric(14,2) NOT NULL DEFAULT 0 CHECK (price >= 0),
    discount         numeric(14,2) NOT NULL DEFAULT 0 CHECK (discount >= 0),
    amount           numeric(14,2) NOT NULL DEFAULT 0 CHECK (amount >= 0),
    paid_method      text,
    paid_at          timestamptz,
    reference        text,
    folio_line_id    text,
    pickup           text,
    dropoff          text,
    flight           text,
    notes            text,
    source           text NOT NULL DEFAULT 'desk',
    reminded_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT hms_appointments_times_check CHECK (ends_at > starts_at)
);
ALTER TABLE hms.hms_appointments DROP CONSTRAINT IF EXISTS hms_appointments_status_check;
ALTER TABLE hms.hms_appointments ADD CONSTRAINT hms_appointments_status_check CHECK (status IN
    ('booked', 'confirmed', 'arrived', 'completed', 'cancelled', 'no_show'));
ALTER TABLE hms.hms_appointments DROP CONSTRAINT IF EXISTS hms_appointments_source_check;
ALTER TABLE hms.hms_appointments ADD CONSTRAINT hms_appointments_source_check CHECK (source IN ('desk', 'phone', 'website', 'walk_in', 'whatsapp', 'stay'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_appointments_code_uq ON hms.hms_appointments (bus_id, code);
CREATE INDEX IF NOT EXISTS hms_appointments_bookable_idx ON hms.hms_appointments (bookable_id, starts_at);
CREATE INDEX IF NOT EXISTS hms_appointments_day_idx ON hms.hms_appointments (bus_id, property_id, starts_at);

-- ===================================================================== memberships
CREATE TABLE IF NOT EXISTS hms.hms_membership_plans (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    bus_id             text NOT NULL,
    property_id        text NOT NULL REFERENCES hms.hms_properties (id),
    name               text NOT NULL,
    price              numeric(14,2) NOT NULL DEFAULT 0 CHECK (price >= 0),
    period             text NOT NULL DEFAULT 'month',
    joining_fee        numeric(14,2) NOT NULL DEFAULT 0 CHECK (joining_fee >= 0),
    visits_per_period  int CHECK (visits_per_period IS NULL OR visits_per_period > 0),
    discount_percent   numeric(5,2) NOT NULL DEFAULT 0 CHECK (discount_percent BETWEEN 0 AND 100),
    benefits           text,
    active             boolean NOT NULL DEFAULT true,
    archived_at        timestamptz,
    cdatetime          timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hms.hms_membership_plans DROP CONSTRAINT IF EXISTS hms_membership_plans_period_check;
ALTER TABLE hms.hms_membership_plans ADD CONSTRAINT hms_membership_plans_period_check CHECK (period IN ('week', 'month', 'quarter', 'year', 'once'));

CREATE TABLE IF NOT EXISTS hms.hms_members (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    plan_id          text NOT NULL REFERENCES hms.hms_membership_plans (id),
    member_no        text,
    full_name        text NOT NULL,
    phone            text,
    email            text,
    guest_id         text REFERENCES hms.hms_guests (id),
    starts_on        date NOT NULL DEFAULT CURRENT_DATE,
    paid_until       date,
    status           text NOT NULL DEFAULT 'active',
    notes            text,
    archived_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
ALTER TABLE hms.hms_members DROP CONSTRAINT IF EXISTS hms_members_status_check;
ALTER TABLE hms.hms_members ADD CONSTRAINT hms_members_status_check CHECK (status IN ('active', 'paused', 'cancelled'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_members_no_uq ON hms.hms_members (bus_id, member_no);
CREATE INDEX IF NOT EXISTS hms_members_name_idx ON hms.hms_members (bus_id, lower(full_name));

CREATE TABLE IF NOT EXISTS hms.hms_member_payments (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    member_id        text NOT NULL REFERENCES hms.hms_members (id),
    amount           numeric(14,2) NOT NULL CHECK (amount >= 0),
    method           text NOT NULL,
    reference        text,
    period_from      date NOT NULL,
    period_to        date NOT NULL,
    voided_at        timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
CREATE INDEX IF NOT EXISTS hms_member_payments_member_idx ON hms.hms_member_payments (member_id);

CREATE TABLE IF NOT EXISTS hms.hms_member_visits (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    member_id        text NOT NULL REFERENCES hms.hms_members (id),
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    note             text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
CREATE INDEX IF NOT EXISTS hms_member_visits_member_idx ON hms.hms_member_visits (member_id, cdatetime);

-- ========================================================================= tickets
CREATE TABLE IF NOT EXISTS hms.hms_ticket_events (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    name             text NOT NULL,
    kind             text NOT NULL DEFAULT 'event',
    starts_at        timestamptz NOT NULL,
    ends_at          timestamptz,
    venue            text,
    description      text,
    capacity         int CHECK (capacity IS NULL OR capacity > 0),
    published        boolean NOT NULL DEFAULT false,
    sales_open       boolean NOT NULL DEFAULT true,
    archived_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
ALTER TABLE hms.hms_ticket_events DROP CONSTRAINT IF EXISTS hms_ticket_events_kind_check;
ALTER TABLE hms.hms_ticket_events ADD CONSTRAINT hms_ticket_events_kind_check CHECK (kind IN
    ('event', 'club_night', 'concert', 'brunch', 'party', 'conference', 'sport', 'other'));

CREATE TABLE IF NOT EXISTS hms.hms_ticket_types (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    event_id         text NOT NULL REFERENCES hms.hms_ticket_events (id),
    name             text NOT NULL,
    price            numeric(14,2) NOT NULL DEFAULT 0 CHECK (price >= 0),
    quantity         int CHECK (quantity IS NULL OR quantity > 0),
    admits           int NOT NULL DEFAULT 1 CHECK (admits BETWEEN 1 AND 50),
    min_spend        numeric(14,2) NOT NULL DEFAULT 0 CHECK (min_spend >= 0),
    sales_end        timestamptz,
    sort_order       int NOT NULL DEFAULT 0,
    active           boolean NOT NULL DEFAULT true,
    archived_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS hms.hms_tickets (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    event_id         text NOT NULL REFERENCES hms.hms_ticket_events (id),
    type_id          text NOT NULL REFERENCES hms.hms_ticket_types (id),
    sale_id          text NOT NULL,
    code             text NOT NULL,
    holder_name      text NOT NULL,
    phone            text,
    email            text,
    admits           int NOT NULL DEFAULT 1,
    price            numeric(14,2) NOT NULL DEFAULT 0,
    paid_method      text,
    reference        text,
    online_reference text,
    status           text NOT NULL DEFAULT 'valid',
    sold_via         text NOT NULL DEFAULT 'desk',
    used_at          timestamptz,
    used_by          text,
    voided_at        timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
ALTER TABLE hms.hms_tickets DROP CONSTRAINT IF EXISTS hms_tickets_status_check;
ALTER TABLE hms.hms_tickets ADD CONSTRAINT hms_tickets_status_check CHECK (status IN ('pending', 'valid', 'used', 'void'));
ALTER TABLE hms.hms_tickets DROP CONSTRAINT IF EXISTS hms_tickets_via_check;
ALTER TABLE hms.hms_tickets ADD CONSTRAINT hms_tickets_via_check CHECK (sold_via IN ('desk', 'door', 'website'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_tickets_code_uq ON hms.hms_tickets (code);
CREATE INDEX IF NOT EXISTS hms_tickets_event_idx ON hms.hms_tickets (event_id, status);
CREATE INDEX IF NOT EXISTS hms_tickets_sale_idx ON hms.hms_tickets (sale_id);

CREATE TABLE IF NOT EXISTS hms.hms_guest_lists (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    event_id         text NOT NULL REFERENCES hms.hms_ticket_events (id),
    name             text NOT NULL,
    phone            text,
    plus_ones        int NOT NULL DEFAULT 0 CHECK (plus_ones BETWEEN 0 AND 50),
    host             text,
    notes            text,
    arrived          int NOT NULL DEFAULT 0 CHECK (arrived >= 0),
    arrived_at       timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
CREATE INDEX IF NOT EXISTS hms_guest_lists_event_idx ON hms.hms_guest_lists (event_id);

ALTER TABLE hms.hms_table_bookings ADD COLUMN IF NOT EXISTS min_spend numeric(14,2) NOT NULL DEFAULT 0;
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS min_spend numeric(14,2) NOT NULL DEFAULT 0;

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-hms-appointments', 'HMS Appointments', 'Spa, salon, gym, meeting rooms, courts, transfers: booked by the slot', 'rt-subscribed-app-hms'),
('rt-hms-memberships',  'HMS Memberships',  'Membership plans, members, dues and check-ins',                       'rt-subscribed-app-hms'),
('rt-hms-tickets',      'HMS Tickets',      'Ticketed events and club nights, the door and guest lists',          'rt-subscribed-app-hms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('appointments', 'rt-hms-appointments', 'get',    'View appointments'),
    ('appointments', 'rt-hms-appointments', 'create', 'Book, move and take payment for appointments'),
    ('appointments', 'rt-hms-appointments', 'manage', 'Set up services, staff, rooms and hours'),
    ('memberships',  'rt-hms-memberships',  'get',    'View members'),
    ('memberships',  'rt-hms-memberships',  'create', 'Add members, take dues and check members in'),
    ('memberships',  'rt-hms-memberships',  'manage', 'Set up membership plans'),
    ('tickets',      'rt-hms-tickets',      'get',    'View ticket sales and guest lists'),
    ('tickets',      'rt-hms-tickets',      'create', 'Sell tickets, scan them at the door, run the guest list'),
    ('tickets',      'rt-hms-tickets',      'manage', 'Set up events and their tickets; void tickets')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-hms-' || spec.resource_key || '-' || spec.action,
       'HMS ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'hms',
       resource_key = substring(p.id FROM '^permission-hms-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-hms-%'
   AND (p.app_prefix IS DISTINCT FROM 'hms' OR p.action IS NULL);

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-hms-manager' AS role_id, p2.resource_key, p2.action
      FROM core_platform.cp_permissions p2 WHERE p2.app_prefix = 'hms'
    UNION ALL
    SELECT 'role-hms-viewer', p3.resource_key, p3.action
      FROM core_platform.cp_permissions p3 JOIN core_platform.cp_actions a ON a.action = p3.action AND a.is_read_only AND p3.action <> 'export'
     WHERE p3.app_prefix = 'hms'
    UNION ALL
    SELECT r2, k, a FROM (VALUES
        ('role-hms-frontdesk', 'appointments', 'get'), ('role-hms-frontdesk', 'appointments', 'create'),
        ('role-hms-frontdesk', 'memberships', 'get'), ('role-hms-frontdesk', 'memberships', 'create'),
        ('role-hms-frontdesk', 'tickets', 'get'), ('role-hms-frontdesk', 'tickets', 'create'),
        ('role-hms-cashier', 'appointments', 'get'), ('role-hms-cashier', 'appointments', 'create'),
        ('role-hms-cashier', 'memberships', 'get'), ('role-hms-cashier', 'memberships', 'create'),
        ('role-hms-cashier', 'tickets', 'get'), ('role-hms-cashier', 'tickets', 'create'),
        ('role-hms-finance', 'appointments', 'get'), ('role-hms-finance', 'memberships', 'get'), ('role-hms-finance', 'tickets', 'get')) AS x(r2, k, a)
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'hms' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =================================================================== plan features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('hms.appointments', 'app-hms', 'Appointments',     2, 'Spa, salon, gym, meeting rooms, courts and transfers booked by the slot, at the desk and online'),
('hms.memberships',  'app-hms', 'Memberships',      2, 'Membership plans, dues, member cards and check-ins'),
('hms.tickets',      'app-hms', 'Tickets & Door',   2, 'Sell tickets online and at the door, scan them, run guest lists and table minimums')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

COMMIT;
