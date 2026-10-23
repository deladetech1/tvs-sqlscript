-- HMS, the rest of property and operations: per-property policies and taxes, photos and
-- documents, owners and management contracts, assets, preventive maintenance, vendors on
-- tickets, lost and found, checklists, staff shifts, cash drawers and the night audit.
--
--   hms_files                    photos and documents (property, unit type, guest ID, signature, lease)
--   hms_owners                   people or companies who own the properties a business manages
--   hms_owner_contracts          who owns what, on what terms (management fee, owner's share)
--   hms_assets                   equipment and fixtures, for maintenance and its costs
--   hms_maintenance_schedules    preventive work that opens a ticket every so many days
--   hms_lost_items               things guests left behind, until claimed or disposed of
--   hms_checklists               what an inspection or a clean checks, by task kind
--   hms_shifts                   who works when (ZelosHR's people when the business has it)
--   hms_cash_sessions            a till or front-desk drawer: float, what came in, the count
--   hms_night_audits             a business day closed: no-shows, figures, and the date locked
--
-- Currencies, time zones and taxes are Core Platform's (cp_currencies, cp_timezone_settings,
-- cp_tax_rates); suppliers are its shared parties (cp_parties). HMS keeps references only.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

-- ---------------------------------------------------------------- per-property policies
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS check_in_time time;
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS check_out_time time;
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS cancellation_policy text;
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS house_rules text;
-- A booking needs this share of its total paid within hold_hours, or it is cancelled.
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS deposit_percent numeric(5,2) NOT NULL DEFAULT 0;
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS hold_hours int NOT NULL DEFAULT 0;
-- Which of Core Platform's taxes apply to rooms and to food and drink here.
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS room_tax_ids text[] NOT NULL DEFAULT '{}';
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS fnb_tax_ids text[] NOT NULL DEFAULT '{}';
-- The booking widget: its address is public_key; nothing is bookable until booking_enabled.
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS public_key text;
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS booking_enabled boolean NOT NULL DEFAULT false;
ALTER TABLE hms.hms_properties DROP CONSTRAINT IF EXISTS hms_properties_deposit_check;
ALTER TABLE hms.hms_properties ADD CONSTRAINT hms_properties_deposit_check CHECK (deposit_percent BETWEEN 0 AND 100 AND hold_hours BETWEEN 0 AND 720);
CREATE UNIQUE INDEX IF NOT EXISTS hms_properties_public_key_uq ON hms.hms_properties (public_key) WHERE public_key IS NOT NULL;

ALTER TABLE hms.hms_settings ADD COLUMN IF NOT EXISTS language text NOT NULL DEFAULT 'en';
-- Loyalty: points earned per unit of currency spent, and the tiers by points.
ALTER TABLE hms.hms_settings ADD COLUMN IF NOT EXISTS points_per_unit numeric(10,4) NOT NULL DEFAULT 0;
ALTER TABLE hms.hms_settings ADD COLUMN IF NOT EXISTS loyalty_tiers jsonb NOT NULL DEFAULT '[]';
-- The last business day closed by the night audit; postings before it are locked.
ALTER TABLE hms.hms_settings ADD COLUMN IF NOT EXISTS audited_through date;

-- ---------------------------------------------------------------------------- files
CREATE TABLE IF NOT EXISTS hms.hms_files (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    entity_type   text NOT NULL,
    entity_id     text NOT NULL,
    purpose       text NOT NULL DEFAULT 'photo',
    path          text NOT NULL,
    file_name     text NOT NULL,
    content_type  text NOT NULL,
    size_bytes    bigint NOT NULL DEFAULT 0,
    sort_order    int NOT NULL DEFAULT 0,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text
);
ALTER TABLE hms.hms_files DROP CONSTRAINT IF EXISTS hms_files_entity_check;
ALTER TABLE hms.hms_files ADD CONSTRAINT hms_files_entity_check CHECK (entity_type IN
    ('property', 'unit_type', 'guest', 'reservation', 'lease', 'renter', 'ticket', 'lost_item', 'asset', 'event'));
ALTER TABLE hms.hms_files DROP CONSTRAINT IF EXISTS hms_files_purpose_check;
ALTER TABLE hms.hms_files ADD CONSTRAINT hms_files_purpose_check CHECK (purpose IN ('photo', 'id_document', 'signature', 'document'));
CREATE INDEX IF NOT EXISTS hms_files_entity_idx ON hms.hms_files (bus_id, entity_type, entity_id, sort_order);

-- -------------------------------------------------------------------- owners
CREATE TABLE IF NOT EXISTS hms.hms_owners (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    name          text NOT NULL,
    email         text,
    phone         text,
    bank_details  text,
    tax_number    text,
    notes         text,
    archived_at   timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text
);
CREATE INDEX IF NOT EXISTS hms_owners_bus_idx ON hms.hms_owners (bus_id, lower(name));

CREATE TABLE IF NOT EXISTS hms.hms_owner_contracts (
    id                     text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text NOT NULL,
    bus_id                 text NOT NULL,
    property_id            text NOT NULL REFERENCES hms.hms_properties (id),
    owner_id               text NOT NULL REFERENCES hms.hms_owners (id),
    starts_on              date NOT NULL,
    ends_on                date,
    -- The manager keeps this share of the property's income, plus a fixed monthly fee.
    management_fee_percent numeric(5,2) NOT NULL DEFAULT 0 CHECK (management_fee_percent BETWEEN 0 AND 100),
    fixed_fee              numeric(14,2) NOT NULL DEFAULT 0 CHECK (fixed_fee >= 0),
    -- Of what is left, the owner's share (co-owners split a property).
    owner_share_percent    numeric(5,2) NOT NULL DEFAULT 100 CHECK (owner_share_percent BETWEEN 0 AND 100),
    notes                  text,
    archived_at            timestamptz,
    cdatetime              timestamptz NOT NULL DEFAULT now(),
    created_by             text,
    CONSTRAINT hms_owner_contracts_dates_check CHECK (ends_on IS NULL OR ends_on > starts_on)
);
CREATE INDEX IF NOT EXISTS hms_owner_contracts_property_idx ON hms.hms_owner_contracts (property_id);

-- ------------------------------------------------------------- assets and upkeep
CREATE TABLE IF NOT EXISTS hms.hms_assets (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    property_id     text NOT NULL REFERENCES hms.hms_properties (id),
    unit_id         text REFERENCES hms.hms_units (id),
    name            text NOT NULL,
    category        text NOT NULL DEFAULT 'other',
    serial_number   text,
    purchased_on    date,
    cost            numeric(14,2) CHECK (cost IS NULL OR cost >= 0),
    warranty_until  date,
    notes           text,
    archived_at     timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
CREATE INDEX IF NOT EXISTS hms_assets_property_idx ON hms.hms_assets (bus_id, property_id);

CREATE TABLE IF NOT EXISTS hms.hms_maintenance_schedules (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    property_id     text NOT NULL REFERENCES hms.hms_properties (id),
    unit_id         text REFERENCES hms.hms_units (id),
    asset_id        text REFERENCES hms.hms_assets (id),
    title           text NOT NULL,
    category        text NOT NULL DEFAULT 'other',
    every_days      int NOT NULL CHECK (every_days BETWEEN 1 AND 3660),
    next_due_on     date NOT NULL,
    assigned_to     text,
    vendor_id       text,
    active          boolean NOT NULL DEFAULT true,
    archived_at     timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
CREATE INDEX IF NOT EXISTS hms_maintenance_schedules_due_idx ON hms.hms_maintenance_schedules (bus_id, next_due_on) WHERE active AND archived_at IS NULL;

ALTER TABLE hms.hms_maintenance_tickets ADD COLUMN IF NOT EXISTS asset_id text REFERENCES hms.hms_assets (id);
ALTER TABLE hms.hms_maintenance_tickets ADD COLUMN IF NOT EXISTS schedule_id text REFERENCES hms.hms_maintenance_schedules (id);
-- The contractor: one of the business's suppliers in Core Platform (cp_parties).
ALTER TABLE hms.hms_maintenance_tickets ADD COLUMN IF NOT EXISTS vendor_id text;
ALTER TABLE hms.hms_maintenance_tickets ADD COLUMN IF NOT EXISTS vendor_invoice_ref text;
ALTER TABLE hms.hms_maintenance_tickets ADD COLUMN IF NOT EXISTS due_on date;
ALTER TABLE hms.hms_maintenance_tickets ADD COLUMN IF NOT EXISTS lease_id text;
ALTER TABLE hms.hms_maintenance_tickets ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'staff';
ALTER TABLE hms.hms_maintenance_tickets DROP CONSTRAINT IF EXISTS hms_maintenance_tickets_source_check;
ALTER TABLE hms.hms_maintenance_tickets ADD CONSTRAINT hms_maintenance_tickets_source_check CHECK (source IN ('staff', 'schedule', 'tenant_portal', 'guest'));
-- A schedule opens one ticket per due date, however often it runs.
CREATE UNIQUE INDEX IF NOT EXISTS hms_maintenance_tickets_schedule_uq ON hms.hms_maintenance_tickets (schedule_id, due_on) WHERE schedule_id IS NOT NULL;

-- ------------------------------------------------------------------ lost and found
CREATE TABLE IF NOT EXISTS hms.hms_lost_items (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    unit_id          text REFERENCES hms.hms_units (id),
    reservation_id   text REFERENCES hms.hms_reservations (id),
    description      text NOT NULL,
    found_on         date NOT NULL,
    found_by         text,
    stored_at        text,
    status           text NOT NULL DEFAULT 'found',
    claimed_by_name  text,
    claimed_at       timestamptz,
    notes            text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
ALTER TABLE hms.hms_lost_items DROP CONSTRAINT IF EXISTS hms_lost_items_status_check;
ALTER TABLE hms.hms_lost_items ADD CONSTRAINT hms_lost_items_status_check CHECK (status IN ('found', 'claimed', 'returned', 'disposed'));
CREATE INDEX IF NOT EXISTS hms_lost_items_bus_idx ON hms.hms_lost_items (bus_id, status, found_on DESC);

-- ---------------------------------------------------------- checklists and shifts
CREATE TABLE IF NOT EXISTS hms.hms_checklists (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    task_kind     text NOT NULL,
    name          text NOT NULL,
    items         text[] NOT NULL DEFAULT '{}',
    archived_at   timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_checklists_kind_uq ON hms.hms_checklists (bus_id, task_kind) WHERE archived_at IS NULL;
ALTER TABLE hms.hms_housekeeping_tasks ADD COLUMN IF NOT EXISTS checklist jsonb NOT NULL DEFAULT '[]';

CREATE TABLE IF NOT EXISTS hms.hms_shifts (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    property_id   text REFERENCES hms.hms_properties (id),
    user_id       text NOT NULL,
    department    text NOT NULL DEFAULT 'housekeeping',
    starts_at     timestamptz NOT NULL,
    ends_at       timestamptz NOT NULL,
    notes         text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text,
    CONSTRAINT hms_shifts_time_check CHECK (ends_at > starts_at)
);
ALTER TABLE hms.hms_shifts DROP CONSTRAINT IF EXISTS hms_shifts_department_check;
ALTER TABLE hms.hms_shifts ADD CONSTRAINT hms_shifts_department_check CHECK (department IN
    ('front_desk', 'housekeeping', 'maintenance', 'kitchen', 'restaurant', 'bar', 'security', 'management', 'other'));
CREATE INDEX IF NOT EXISTS hms_shifts_when_idx ON hms.hms_shifts (bus_id, starts_at);

-- ------------------------------------------------------------------- cash drawers
CREATE TABLE IF NOT EXISTS hms.hms_cash_sessions (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    property_id     text NOT NULL REFERENCES hms.hms_properties (id),
    user_id         text NOT NULL,
    point           text NOT NULL DEFAULT 'front_desk',
    opening_float   numeric(14,2) NOT NULL DEFAULT 0 CHECK (opening_float >= 0),
    opened_at       timestamptz NOT NULL DEFAULT now(),
    closed_at       timestamptz,
    counted_cash    numeric(14,2),
    expected_cash   numeric(14,2),
    variance        numeric(14,2),
    notes           text
);
ALTER TABLE hms.hms_cash_sessions DROP CONSTRAINT IF EXISTS hms_cash_sessions_point_check;
ALTER TABLE hms.hms_cash_sessions ADD CONSTRAINT hms_cash_sessions_point_check CHECK (point IN ('front_desk', 'restaurant', 'bar', 'rentals'));
-- One open drawer per person at a time.
CREATE UNIQUE INDEX IF NOT EXISTS hms_cash_sessions_open_uq ON hms.hms_cash_sessions (bus_id, user_id) WHERE closed_at IS NULL;

CREATE TABLE IF NOT EXISTS hms.hms_cash_movements (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    session_id      text NOT NULL REFERENCES hms.hms_cash_sessions (id),
    kind            text NOT NULL,
    amount          numeric(14,2) NOT NULL CHECK (amount > 0),
    reason          text NOT NULL,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
ALTER TABLE hms.hms_cash_movements DROP CONSTRAINT IF EXISTS hms_cash_movements_kind_check;
ALTER TABLE hms.hms_cash_movements ADD CONSTRAINT hms_cash_movements_kind_check CHECK (kind IN ('drop', 'paid_out', 'paid_in'));

ALTER TABLE hms.hms_folio_lines ADD COLUMN IF NOT EXISTS cash_session_id text REFERENCES hms.hms_cash_sessions (id);
ALTER TABLE hms.hms_rent_payments ADD COLUMN IF NOT EXISTS cash_session_id text REFERENCES hms.hms_cash_sessions (id);

-- ------------------------------------------------------------------- night audit
CREATE TABLE IF NOT EXISTS hms.hms_night_audits (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    business_date   date NOT NULL,
    summary         jsonb NOT NULL DEFAULT '{}',
    run_at          timestamptz NOT NULL DEFAULT now(),
    run_by          text,
    source          text NOT NULL DEFAULT 'manual'
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_night_audits_day_uq ON hms.hms_night_audits (bus_id, business_date);

COMMIT;
