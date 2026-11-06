-- HMS for every kind of hospitality business, part 2.
--
--   Hostels       hms_units.room_name (the dorm a bed is in) and gender (mixed, female,
--                 male); hms_guests.gender. Beds are units, so a booking of four beds holds
--                 four units, preferably in one dorm.
--   Short lets    hms_reservations.access_code (a door or lockbox code, sent to the guest),
--                 id_verified_at/by (ID checked before arrival, from the photo the guest
--                 uploads at online check-in).
--   The register  of guests' arrivals the police and immigration ask for: hms_guests.
--                 id_country, id_expires_on, visa_number, entered_country_on,
--                 port_of_entry, occupation; hms_reservations.purpose, coming_from,
--                 going_to.
--   Catering      hms_catering_packages (a menu priced per head) and hms_event_items (the
--                 lines of an event's quote); hms_events.off_site, location,
--                 service_style, quote_token, quote_accepted_at.
--   The guest's   stay app: on the online check-in link, after arrival -- room service,
--   stay app      requests, messages, the bill, express check-out.
--                 hms_properties.wifi_name, wifi_password, guest_info;
--                 hms_reservations.checkout_requested_at; hms_maintenance_tickets and
--                 hms_housekeeping_tasks .from_guest.
--   Utilities     hms_utility_logs: generator fuel, power, water and gas used, and what
--                 they cost.
--   Offline till  hms_orders.client_ref: a sale made with the internet down is sent once
--                 it is back, at most once.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

-- ========================================================================= hostels
ALTER TABLE hms.hms_units ADD COLUMN IF NOT EXISTS room_name text;
ALTER TABLE hms.hms_units ADD COLUMN IF NOT EXISTS gender text NOT NULL DEFAULT 'mixed';
ALTER TABLE hms.hms_units DROP CONSTRAINT IF EXISTS hms_units_gender_check;
ALTER TABLE hms.hms_units ADD CONSTRAINT hms_units_gender_check CHECK (gender IN ('mixed', 'female', 'male'));

ALTER TABLE hms.hms_guests ADD COLUMN IF NOT EXISTS gender text;
ALTER TABLE hms.hms_guests DROP CONSTRAINT IF EXISTS hms_guests_gender_check;
ALTER TABLE hms.hms_guests ADD CONSTRAINT hms_guests_gender_check CHECK (gender IS NULL OR gender IN ('female', 'male', 'other'));

-- ===================================================================== the register
ALTER TABLE hms.hms_guests ADD COLUMN IF NOT EXISTS id_country text;
ALTER TABLE hms.hms_guests ADD COLUMN IF NOT EXISTS id_expires_on date;
ALTER TABLE hms.hms_guests ADD COLUMN IF NOT EXISTS visa_number text;
ALTER TABLE hms.hms_guests ADD COLUMN IF NOT EXISTS entered_country_on date;
ALTER TABLE hms.hms_guests ADD COLUMN IF NOT EXISTS port_of_entry text;
ALTER TABLE hms.hms_guests ADD COLUMN IF NOT EXISTS occupation text;
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS purpose text;
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS coming_from text;
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS going_to text;

-- ===================================================================== short lets
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS access_code text;
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS access_note text;
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS access_sent_at timestamptz;
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS id_verified_at timestamptz;
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS id_verified_by text;
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS require_id boolean NOT NULL DEFAULT false;

-- ======================================================================== catering
CREATE TABLE IF NOT EXISTS hms.hms_catering_packages (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    name             text NOT NULL,
    price_per_head   numeric(14,2) NOT NULL DEFAULT 0 CHECK (price_per_head >= 0),
    min_guests       int NOT NULL DEFAULT 1 CHECK (min_guests >= 1),
    menu             text,
    active           boolean NOT NULL DEFAULT true,
    archived_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS hms.hms_event_items (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    event_id         text NOT NULL REFERENCES hms.hms_events (id) ON DELETE CASCADE,
    package_id       text REFERENCES hms.hms_catering_packages (id),
    description      text NOT NULL,
    per_head         boolean NOT NULL DEFAULT false,
    quantity         numeric(12,2) NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_price       numeric(14,2) NOT NULL DEFAULT 0 CHECK (unit_price >= 0),
    sort_order       int NOT NULL DEFAULT 0,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS hms_event_items_event_idx ON hms.hms_event_items (event_id, sort_order);

ALTER TABLE hms.hms_events ADD COLUMN IF NOT EXISTS off_site boolean NOT NULL DEFAULT false;
ALTER TABLE hms.hms_events ADD COLUMN IF NOT EXISTS location text;
ALTER TABLE hms.hms_events ADD COLUMN IF NOT EXISTS service_style text;
ALTER TABLE hms.hms_events ADD COLUMN IF NOT EXISTS quote_token text;
ALTER TABLE hms.hms_events ADD COLUMN IF NOT EXISTS quote_sent_at timestamptz;
ALTER TABLE hms.hms_events ADD COLUMN IF NOT EXISTS quote_accepted_at timestamptz;
ALTER TABLE hms.hms_events ADD COLUMN IF NOT EXISTS quote_accepted_by text;
CREATE UNIQUE INDEX IF NOT EXISTS hms_events_quote_token_uq ON hms.hms_events (quote_token) WHERE quote_token IS NOT NULL;

-- ================================================================== guest stay app
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS wifi_name text;
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS wifi_password text;
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS guest_info text;
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS checkout_requested_at timestamptz;
ALTER TABLE hms.hms_maintenance_tickets ADD COLUMN IF NOT EXISTS from_guest boolean NOT NULL DEFAULT false;
ALTER TABLE hms.hms_housekeeping_tasks ADD COLUMN IF NOT EXISTS from_guest boolean NOT NULL DEFAULT false;
ALTER TABLE hms.hms_housekeeping_tasks ADD COLUMN IF NOT EXISTS guest_note text;

-- ======================================================================= utilities
CREATE TABLE IF NOT EXISTS hms.hms_utility_logs (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    kind             text NOT NULL DEFAULT 'generator_fuel',
    on_date          date NOT NULL DEFAULT CURRENT_DATE,
    quantity         numeric(14,3),
    measure          text,
    cost             numeric(14,2) NOT NULL DEFAULT 0 CHECK (cost >= 0),
    reading          numeric(14,3),
    run_hours        numeric(10,2),
    supplier         text,
    reference        text,
    notes            text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
ALTER TABLE hms.hms_utility_logs DROP CONSTRAINT IF EXISTS hms_utility_logs_kind_check;
ALTER TABLE hms.hms_utility_logs ADD CONSTRAINT hms_utility_logs_kind_check CHECK (kind IN
    ('generator_fuel', 'electricity', 'water', 'gas', 'solar', 'internet', 'waste', 'other'));
CREATE INDEX IF NOT EXISTS hms_utility_logs_day_idx ON hms.hms_utility_logs (bus_id, property_id, on_date);

-- ==================================================================== offline till
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS client_ref text;
CREATE UNIQUE INDEX IF NOT EXISTS hms_orders_client_ref_uq ON hms.hms_orders (bus_id, client_ref) WHERE client_ref IS NOT NULL;

-- =================================================================== plan features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('hms.guest-app', 'app-hms', 'Guest Stay App', 2, 'One link for the stay: room service, requests, messages, the bill and express check-out'),
('hms.utilities', 'app-hms', 'Utilities Log',  1, 'Generator fuel, power, water and gas used per property, and what they cost'),
('hms.catering',  'app-hms', 'Catering',       2, 'Per-head menus, quotes the client accepts online, prep lists and off-site events')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

COMMIT;
