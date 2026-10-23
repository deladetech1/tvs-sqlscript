-- HMS: the business, its properties and units, and the short-stay side -- guests,
-- reservations, folios, housekeeping and maintenance.
--
--   hms_settings            one per business: its business type and the modules it uses
--   hms_properties          a hotel, guest house, block of flats, house or restaurant
--   hms_unit_types          a kind of room or unit with its base rate
--   hms_units               a room, apartment, bed or house that can be stayed in or let
--   hms_guests              people who stay
--   hms_reservations        a booking: who, where, when, how it came in
--   hms_reservation_units   the units a booking holds and at what rate
--   hms_folios              a guest's bill, opened at booking or check-in
--   hms_folio_lines         charges, payments and refunds on it; corrected by reversal, never edited
--   hms_housekeeping_tasks  cleaning and inspections
--   hms_maintenance_tickets things to fix, which may take a unit out of order
--
-- Every row belongs to a business (bus_id) of a tenant; the API limits every query to the
-- caller's business. Money is numeric(14,2). A booking is not a payment and a payment is not
-- revenue: reservations, folio charges and payments stay separate records.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS hms.hms_settings (
    bus_id          text PRIMARY KEY,
    tenant_id       text NOT NULL,
    org_id          text,
    business_type   text,
    modules         text[] NOT NULL DEFAULT '{}',
    currency        text NOT NULL DEFAULT 'GHS',
    timezone        text NOT NULL DEFAULT 'Africa/Accra',
    check_in_time   time NOT NULL DEFAULT '14:00',
    check_out_time  time NOT NULL DEFAULT '11:00',
    onboarded_at    timestamptz,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    updated_by      text
);
ALTER TABLE hms.hms_settings DROP CONSTRAINT IF EXISTS hms_settings_business_type_check;
ALTER TABLE hms.hms_settings ADD CONSTRAINT hms_settings_business_type_check CHECK (business_type IS NULL OR business_type IN
    ('hotel', 'guest_house', 'resort', 'hostel', 'short_stay', 'serviced_apartment', 'restaurant',
     'landlord', 'property_manager', 'event_venue'));

CREATE TABLE IF NOT EXISTS hms.hms_properties (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    org_id          text,
    bus_id          text NOT NULL,
    name            text NOT NULL,
    kind            text NOT NULL DEFAULT 'hotel',
    address         text,
    city            text,
    region          text,
    country         text NOT NULL DEFAULT 'GH',
    phone           text,
    email           text,
    location_id     text,
    archived_at     timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
ALTER TABLE hms.hms_properties DROP CONSTRAINT IF EXISTS hms_properties_kind_check;
ALTER TABLE hms.hms_properties ADD CONSTRAINT hms_properties_kind_check CHECK (kind IN
    ('hotel', 'guest_house', 'resort', 'hostel', 'apartments', 'house', 'restaurant', 'commercial', 'event_venue', 'other'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_properties_name_uq
    ON hms.hms_properties (bus_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS hms.hms_unit_types (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    org_id          text,
    bus_id          text NOT NULL,
    property_id     text NOT NULL REFERENCES hms.hms_properties (id),
    name            text NOT NULL,
    category        text NOT NULL DEFAULT 'room',
    base_rate       numeric(14,2) NOT NULL DEFAULT 0 CHECK (base_rate >= 0),
    rate_period     text NOT NULL DEFAULT 'night',
    max_guests      int NOT NULL DEFAULT 2 CHECK (max_guests > 0),
    bedrooms        int CHECK (bedrooms IS NULL OR bedrooms >= 0),
    description     text,
    amenities       text[] NOT NULL DEFAULT '{}',
    archived_at     timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
ALTER TABLE hms.hms_unit_types DROP CONSTRAINT IF EXISTS hms_unit_types_category_check;
ALTER TABLE hms.hms_unit_types ADD CONSTRAINT hms_unit_types_category_check CHECK (category IN
    ('room', 'suite', 'apartment', 'studio', 'bed', 'house', 'shop', 'office', 'hall', 'other'));
ALTER TABLE hms.hms_unit_types DROP CONSTRAINT IF EXISTS hms_unit_types_rate_period_check;
ALTER TABLE hms.hms_unit_types ADD CONSTRAINT hms_unit_types_rate_period_check CHECK (rate_period IN ('hour', 'night', 'week', 'month'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_unit_types_name_uq
    ON hms.hms_unit_types (property_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS hms.hms_units (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    org_id              text,
    bus_id              text NOT NULL,
    property_id         text NOT NULL REFERENCES hms.hms_properties (id),
    unit_type_id        text NOT NULL REFERENCES hms.hms_unit_types (id),
    name                text NOT NULL,
    floor               text,
    -- stay: booked by the night (or hour, week); rental: let on a lease.
    usage               text NOT NULL DEFAULT 'stay',
    housekeeping_status text NOT NULL DEFAULT 'clean',
    notes               text,
    archived_at         timestamptz,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    created_by          text
);
ALTER TABLE hms.hms_units DROP CONSTRAINT IF EXISTS hms_units_usage_check;
ALTER TABLE hms.hms_units ADD CONSTRAINT hms_units_usage_check CHECK (usage IN ('stay', 'rental'));
ALTER TABLE hms.hms_units DROP CONSTRAINT IF EXISTS hms_units_housekeeping_status_check;
ALTER TABLE hms.hms_units ADD CONSTRAINT hms_units_housekeeping_status_check CHECK (housekeeping_status IN
    ('clean', 'dirty', 'inspected', 'out_of_order'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_units_name_uq
    ON hms.hms_units (property_id, lower(name)) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS hms_units_business_idx ON hms.hms_units (bus_id, property_id);

CREATE TABLE IF NOT EXISTS hms.hms_guests (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    org_id          text,
    bus_id          text NOT NULL,
    full_name       text NOT NULL,
    email           text,
    phone           text,
    nationality     text,
    id_type         text,
    id_number       text,
    address         text,
    notes           text,
    is_vip          boolean NOT NULL DEFAULT false,
    archived_at     timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
CREATE INDEX IF NOT EXISTS hms_guests_business_idx ON hms.hms_guests (bus_id, lower(full_name));

CREATE TABLE IF NOT EXISTS hms.hms_reservations (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    guest_id         text NOT NULL REFERENCES hms.hms_guests (id),
    code             text NOT NULL,
    status           text NOT NULL DEFAULT 'confirmed',
    source           text NOT NULL DEFAULT 'direct',
    arrive_on        date NOT NULL,
    depart_on        date NOT NULL,
    adults           int NOT NULL DEFAULT 1 CHECK (adults >= 0),
    children         int NOT NULL DEFAULT 0 CHECK (children >= 0),
    currency         text NOT NULL DEFAULT 'GHS',
    notes            text,
    cancel_reason    text,
    checked_in_at    timestamptz,
    checked_out_at   timestamptz,
    cancelled_at     timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT hms_reservations_dates_check CHECK (depart_on > arrive_on)
);
ALTER TABLE hms.hms_reservations DROP CONSTRAINT IF EXISTS hms_reservations_status_check;
ALTER TABLE hms.hms_reservations ADD CONSTRAINT hms_reservations_status_check CHECK (status IN
    ('tentative', 'confirmed', 'checked_in', 'checked_out', 'cancelled', 'no_show'));
ALTER TABLE hms.hms_reservations DROP CONSTRAINT IF EXISTS hms_reservations_source_check;
ALTER TABLE hms.hms_reservations ADD CONSTRAINT hms_reservations_source_check CHECK (source IN
    ('direct', 'walk_in', 'phone', 'website', 'booking_com', 'airbnb', 'expedia', 'agent', 'corporate', 'other'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_reservations_code_uq ON hms.hms_reservations (bus_id, code);
CREATE INDEX IF NOT EXISTS hms_reservations_dates_idx ON hms.hms_reservations (bus_id, property_id, arrive_on, depart_on);

CREATE TABLE IF NOT EXISTS hms.hms_reservation_units (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    reservation_id   text NOT NULL REFERENCES hms.hms_reservations (id) ON DELETE CASCADE,
    unit_id          text NOT NULL REFERENCES hms.hms_units (id),
    arrive_on        date NOT NULL,
    depart_on        date NOT NULL,
    rate             numeric(14,2) NOT NULL CHECK (rate >= 0),
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT hms_reservation_units_dates_check CHECK (depart_on > arrive_on)
);
CREATE INDEX IF NOT EXISTS hms_reservation_units_unit_idx ON hms.hms_reservation_units (unit_id, arrive_on, depart_on);
CREATE INDEX IF NOT EXISTS hms_reservation_units_res_idx ON hms.hms_reservation_units (reservation_id);

CREATE TABLE IF NOT EXISTS hms.hms_folios (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    reservation_id   text REFERENCES hms.hms_reservations (id),
    guest_id         text REFERENCES hms.hms_guests (id),
    label            text NOT NULL,
    status           text NOT NULL DEFAULT 'open',
    currency         text NOT NULL DEFAULT 'GHS',
    closed_at        timestamptz,
    closed_by        text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
ALTER TABLE hms.hms_folios DROP CONSTRAINT IF EXISTS hms_folios_status_check;
ALTER TABLE hms.hms_folios ADD CONSTRAINT hms_folios_status_check CHECK (status IN ('open', 'closed'));
-- One bill per booking.
CREATE UNIQUE INDEX IF NOT EXISTS hms_folios_reservation_uq ON hms.hms_folios (reservation_id) WHERE reservation_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS hms.hms_folio_lines (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    folio_id         text NOT NULL REFERENCES hms.hms_folios (id),
    kind             text NOT NULL,
    category         text NOT NULL DEFAULT 'other',
    description      text NOT NULL,
    amount           numeric(14,2) NOT NULL CHECK (amount > 0),
    method           text,
    reference        text,
    -- Where the line came from: a restaurant order charged to the room, the room itself.
    source_type      text,
    source_id        text,
    -- A reversal names the line it undoes; both then drop out of the balance.
    reverses_line_id text REFERENCES hms.hms_folio_lines (id),
    -- A retried request (a payment callback, a double click) posts once.
    idempotency_key  text,
    posted_on        date NOT NULL DEFAULT CURRENT_DATE,
    posted_at        timestamptz NOT NULL DEFAULT now(),
    posted_by        text
);
ALTER TABLE hms.hms_folio_lines DROP CONSTRAINT IF EXISTS hms_folio_lines_kind_check;
ALTER TABLE hms.hms_folio_lines ADD CONSTRAINT hms_folio_lines_kind_check CHECK (kind IN ('charge', 'payment', 'refund'));
ALTER TABLE hms.hms_folio_lines DROP CONSTRAINT IF EXISTS hms_folio_lines_category_check;
ALTER TABLE hms.hms_folio_lines ADD CONSTRAINT hms_folio_lines_category_check CHECK (category IN
    ('room', 'restaurant', 'bar', 'minibar', 'laundry', 'service', 'damage', 'late_checkout', 'early_checkin',
     'tax', 'deposit', 'payment', 'refund', 'other'));
ALTER TABLE hms.hms_folio_lines DROP CONSTRAINT IF EXISTS hms_folio_lines_method_check;
ALTER TABLE hms.hms_folio_lines ADD CONSTRAINT hms_folio_lines_method_check CHECK (method IS NULL OR method IN
    ('cash', 'card', 'momo', 'bank', 'cheque', 'other'));
CREATE INDEX IF NOT EXISTS hms_folio_lines_folio_idx ON hms.hms_folio_lines (folio_id, posted_at);
CREATE UNIQUE INDEX IF NOT EXISTS hms_folio_lines_reverses_uq ON hms.hms_folio_lines (reverses_line_id) WHERE reverses_line_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS hms_folio_lines_idem_uq ON hms.hms_folio_lines (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
-- A restaurant order reaches a bill once (a room's charge is re-posted when a stay changes,
-- after the old one is reversed, so it is not held to this).
DROP INDEX IF EXISTS hms.hms_folio_lines_source_uq;
CREATE UNIQUE INDEX IF NOT EXISTS hms_folio_lines_order_uq ON hms.hms_folio_lines (source_id)
    WHERE source_type = 'restaurant_order' AND reverses_line_id IS NULL;

CREATE TABLE IF NOT EXISTS hms.hms_housekeeping_tasks (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    unit_id          text NOT NULL REFERENCES hms.hms_units (id),
    reservation_id   text REFERENCES hms.hms_reservations (id),
    kind             text NOT NULL DEFAULT 'checkout',
    status           text NOT NULL DEFAULT 'open',
    priority         text NOT NULL DEFAULT 'normal',
    assigned_to      text,
    due_on           date NOT NULL DEFAULT CURRENT_DATE,
    notes            text,
    completed_at     timestamptz,
    completed_by     text,
    inspected_at     timestamptz,
    inspected_by     text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
ALTER TABLE hms.hms_housekeeping_tasks DROP CONSTRAINT IF EXISTS hms_housekeeping_tasks_kind_check;
ALTER TABLE hms.hms_housekeeping_tasks ADD CONSTRAINT hms_housekeeping_tasks_kind_check CHECK (kind IN
    ('checkout', 'stayover', 'deep_clean', 'inspection', 'turnover'));
ALTER TABLE hms.hms_housekeeping_tasks DROP CONSTRAINT IF EXISTS hms_housekeeping_tasks_status_check;
ALTER TABLE hms.hms_housekeeping_tasks ADD CONSTRAINT hms_housekeeping_tasks_status_check CHECK (status IN
    ('open', 'in_progress', 'done', 'inspected', 'cancelled'));
ALTER TABLE hms.hms_housekeeping_tasks DROP CONSTRAINT IF EXISTS hms_housekeeping_tasks_priority_check;
ALTER TABLE hms.hms_housekeeping_tasks ADD CONSTRAINT hms_housekeeping_tasks_priority_check CHECK (priority IN ('low', 'normal', 'high'));
CREATE INDEX IF NOT EXISTS hms_housekeeping_tasks_board_idx ON hms.hms_housekeeping_tasks (bus_id, property_id, status, due_on);
-- A checkout makes one cleaning task per unit, however often it is retried.
CREATE UNIQUE INDEX IF NOT EXISTS hms_housekeeping_tasks_checkout_uq
    ON hms.hms_housekeeping_tasks (reservation_id, unit_id) WHERE reservation_id IS NOT NULL AND kind = 'checkout';

CREATE TABLE IF NOT EXISTS hms.hms_maintenance_tickets (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    unit_id          text REFERENCES hms.hms_units (id),
    title            text NOT NULL,
    description      text,
    category         text NOT NULL DEFAULT 'other',
    priority         text NOT NULL DEFAULT 'normal',
    status           text NOT NULL DEFAULT 'open',
    -- While open, the unit cannot be booked or let.
    takes_unit_out   boolean NOT NULL DEFAULT false,
    assigned_to      text,
    reported_by      text,
    cost             numeric(14,2) CHECK (cost IS NULL OR cost >= 0),
    resolution       text,
    resolved_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hms.hms_maintenance_tickets DROP CONSTRAINT IF EXISTS hms_maintenance_tickets_category_check;
ALTER TABLE hms.hms_maintenance_tickets ADD CONSTRAINT hms_maintenance_tickets_category_check CHECK (category IN
    ('plumbing', 'electrical', 'air_conditioning', 'furniture', 'appliance', 'structural', 'cleaning', 'security', 'internet', 'other'));
ALTER TABLE hms.hms_maintenance_tickets DROP CONSTRAINT IF EXISTS hms_maintenance_tickets_priority_check;
ALTER TABLE hms.hms_maintenance_tickets ADD CONSTRAINT hms_maintenance_tickets_priority_check CHECK (priority IN ('low', 'normal', 'high', 'urgent'));
ALTER TABLE hms.hms_maintenance_tickets DROP CONSTRAINT IF EXISTS hms_maintenance_tickets_status_check;
ALTER TABLE hms.hms_maintenance_tickets ADD CONSTRAINT hms_maintenance_tickets_status_check CHECK (status IN
    ('open', 'in_progress', 'on_hold', 'resolved', 'closed'));
CREATE INDEX IF NOT EXISTS hms_maintenance_tickets_board_idx ON hms.hms_maintenance_tickets (bus_id, property_id, status);

COMMIT;
