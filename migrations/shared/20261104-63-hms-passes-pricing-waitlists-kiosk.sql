-- HMS, part 3: what rounds the new kinds of business out.
--
--   hms_client_refs        a till's own reference for something it did offline (items added to
--                          an order, an order settled), so sending it twice does it once
--   hms_pass_products      packages and class passes: 10 sessions of yoga, 5 massages, a
--                          month of classes -- the services they cover, how many, how long valid
--   hms_passes             one sold: whose, sessions left, until when; each appointment it pays
--                          for takes a session (hms_appointments.pass_id)
--   hms_bookables.commission_percent   a therapist's or stylist's share of what they do
--   hms_rate_rules         rates that follow demand: up when the property is filling, down when
--                          it is empty, a last-minute price close to the day
--   hms_waitlist           a slot or an event that is full: who wants in; offered the place
--                          when one comes free
--   hms_membership_plans.event_access  members' and season-ticket plans that let the member
--                          into events at the door; hms_member_visits.event_id the event
--   hms_properties.kiosk_token   the self-service kiosk's link (ordering at the counter, and
--                          finding a booking to check in)
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS hms.hms_client_refs (
    bus_id     text NOT NULL,
    ref        text NOT NULL,
    action     text NOT NULL,
    cdatetime  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (bus_id, ref)
);

-- ===================================================================== passes
CREATE TABLE IF NOT EXISTS hms.hms_pass_products (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    name             text NOT NULL,
    service_ids      text[] NOT NULL DEFAULT '{}',
    sessions         int NOT NULL DEFAULT 10 CHECK (sessions BETWEEN 1 AND 1000),
    price            numeric(14,2) NOT NULL DEFAULT 0 CHECK (price >= 0),
    valid_days       int CHECK (valid_days IS NULL OR valid_days > 0),
    description      text,
    active           boolean NOT NULL DEFAULT true,
    archived_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS hms.hms_passes (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    product_id       text NOT NULL REFERENCES hms.hms_pass_products (id),
    code             text NOT NULL,
    holder_name      text NOT NULL,
    phone            text,
    member_id        text REFERENCES hms.hms_members (id),
    sessions         int NOT NULL,
    sessions_left    int NOT NULL CHECK (sessions_left >= 0),
    expires_on       date,
    amount           numeric(14,2) NOT NULL DEFAULT 0,
    paid_method      text NOT NULL,
    reference        text,
    status           text NOT NULL DEFAULT 'active',
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
ALTER TABLE hms.hms_passes DROP CONSTRAINT IF EXISTS hms_passes_status_check;
ALTER TABLE hms.hms_passes ADD CONSTRAINT hms_passes_status_check CHECK (status IN ('active', 'void'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_passes_code_uq ON hms.hms_passes (bus_id, code);
ALTER TABLE hms.hms_appointments ADD COLUMN IF NOT EXISTS pass_id text REFERENCES hms.hms_passes (id);

ALTER TABLE hms.hms_bookables ADD COLUMN IF NOT EXISTS commission_percent numeric(5,2) NOT NULL DEFAULT 0;
ALTER TABLE hms.hms_bookables DROP CONSTRAINT IF EXISTS hms_bookables_commission_check;
ALTER TABLE hms.hms_bookables ADD CONSTRAINT hms_bookables_commission_check CHECK (commission_percent BETWEEN 0 AND 100);

-- ============================================================= rates by demand
CREATE TABLE IF NOT EXISTS hms.hms_rate_rules (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    unit_type_id     text REFERENCES hms.hms_unit_types (id),
    name             text NOT NULL,
    min_occupancy    int NOT NULL DEFAULT 0 CHECK (min_occupancy BETWEEN 0 AND 100),
    max_occupancy    int NOT NULL DEFAULT 100 CHECK (max_occupancy BETWEEN 0 AND 100),
    within_days      int CHECK (within_days IS NULL OR within_days >= 0),
    adjust_percent   numeric(6,2) NOT NULL CHECK (adjust_percent BETWEEN -90 AND 300),
    active           boolean NOT NULL DEFAULT true,
    archived_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);

-- ================================================================== waitlists
CREATE TABLE IF NOT EXISTS hms.hms_waitlist (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    kind             text NOT NULL DEFAULT 'appointment',
    service_id       text REFERENCES hms.hms_services (id),
    event_id         text REFERENCES hms.hms_ticket_events (id),
    on_date          date,
    from_time        time,
    to_time          time,
    name             text NOT NULL,
    phone            text,
    email            text,
    party_size       int NOT NULL DEFAULT 1 CHECK (party_size >= 1),
    status           text NOT NULL DEFAULT 'waiting',
    offered_at       timestamptz,
    notes            text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
ALTER TABLE hms.hms_waitlist DROP CONSTRAINT IF EXISTS hms_waitlist_kind_check;
ALTER TABLE hms.hms_waitlist ADD CONSTRAINT hms_waitlist_kind_check CHECK (kind IN ('appointment', 'tickets'));
ALTER TABLE hms.hms_waitlist DROP CONSTRAINT IF EXISTS hms_waitlist_status_check;
ALTER TABLE hms.hms_waitlist ADD CONSTRAINT hms_waitlist_status_check CHECK (status IN ('waiting', 'offered', 'booked', 'cancelled'));
CREATE INDEX IF NOT EXISTS hms_waitlist_open_idx ON hms.hms_waitlist (bus_id, status, on_date);

-- ======================================================== members at the door
ALTER TABLE hms.hms_membership_plans ADD COLUMN IF NOT EXISTS event_access boolean NOT NULL DEFAULT false;
ALTER TABLE hms.hms_member_visits ADD COLUMN IF NOT EXISTS event_id text REFERENCES hms.hms_ticket_events (id);

-- ===================================================================== kiosk
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS kiosk_token text;
CREATE UNIQUE INDEX IF NOT EXISTS hms_properties_kiosk_uq ON hms.hms_properties (kiosk_token) WHERE kiosk_token IS NOT NULL;

INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('hms.dynamic-pricing', 'app-hms', 'Rates by Demand',  3, 'Room rates that rise as you fill and fall when you are empty, and last-minute prices'),
('hms.kiosk',           'app-hms', 'Self-service Kiosk', 2, 'Guests order at the counter and find their booking on a tablet')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

COMMIT;
