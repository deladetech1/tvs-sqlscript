-- HMS, the rest of rentals, money and the platform: meters and utility billing, deposit
-- deductions and interest, lease documents and signatures, the tenant's own page and online
-- payments, automations, scheduled reports, API keys and webhooks.
--
--   hms_meters                electricity, water and gas meters on a unit, with the price per unit
--   hms_meter_readings        each reading, and the charge it made on the lease
--   hms_deposit_deductions    what is kept back from a deposit, and why
--   hms_lease_templates       the lease's words, with {placeholders}
--   hms_payment_attempts      an online payment started through Core Platform's gateway
--   hms_automations           when something happens, send a message or tell somebody
--   hms_report_schedules      a report emailed every day, week or month
--   hms_api_keys              keys for other systems to read HMS (stored hashed)
--   hms_webhooks              addresses told when things happen, signed
--   hms_webhook_deliveries    every attempt, so a failure is retried and visible
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS hms.hms_meters (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    unit_id         text NOT NULL REFERENCES hms.hms_units (id),
    kind            text NOT NULL DEFAULT 'electricity',
    serial_number   text,
    unit_label      text NOT NULL DEFAULT 'kWh',
    rate            numeric(14,4) NOT NULL DEFAULT 0 CHECK (rate >= 0),
    fixed_charge    numeric(14,2) NOT NULL DEFAULT 0 CHECK (fixed_charge >= 0),
    last_reading    numeric(14,3),
    last_read_on    date,
    active          boolean NOT NULL DEFAULT true,
    archived_at     timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hms.hms_meters DROP CONSTRAINT IF EXISTS hms_meters_kind_check;
ALTER TABLE hms.hms_meters ADD CONSTRAINT hms_meters_kind_check CHECK (kind IN ('electricity', 'water', 'gas', 'waste', 'other'));

CREATE TABLE IF NOT EXISTS hms.hms_meter_readings (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    meter_id        text NOT NULL REFERENCES hms.hms_meters (id),
    reading         numeric(14,3) NOT NULL CHECK (reading >= 0),
    read_on         date NOT NULL,
    consumption     numeric(14,3) NOT NULL DEFAULT 0,
    amount          numeric(14,2) NOT NULL DEFAULT 0,
    lease_id        text REFERENCES hms.hms_leases (id),
    charge_id       text REFERENCES hms.hms_rent_charges (id),
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
CREATE INDEX IF NOT EXISTS hms_meter_readings_meter_idx ON hms.hms_meter_readings (meter_id, read_on DESC);

CREATE TABLE IF NOT EXISTS hms.hms_deposit_deductions (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    lease_id        text NOT NULL REFERENCES hms.hms_leases (id),
    description     text NOT NULL,
    amount          numeric(14,2) NOT NULL CHECK (amount > 0),
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);

ALTER TABLE hms.hms_leases ADD COLUMN IF NOT EXISTS deposit_interest_percent numeric(5,2) NOT NULL DEFAULT 0;
ALTER TABLE hms.hms_leases ADD COLUMN IF NOT EXISTS portal_token text;
ALTER TABLE hms.hms_leases ADD COLUMN IF NOT EXISTS document_text text;
ALTER TABLE hms.hms_leases ADD COLUMN IF NOT EXISTS signed_name text;
ALTER TABLE hms.hms_leases ADD COLUMN IF NOT EXISTS signed_at timestamptz;
ALTER TABLE hms.hms_leases ADD COLUMN IF NOT EXISTS template_id text;
ALTER TABLE hms.hms_leases ADD COLUMN IF NOT EXISTS owner_id text REFERENCES hms.hms_owners (id);
CREATE UNIQUE INDEX IF NOT EXISTS hms_leases_portal_uq ON hms.hms_leases (portal_token) WHERE portal_token IS NOT NULL;

CREATE TABLE IF NOT EXISTS hms.hms_lease_templates (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    name            text NOT NULL,
    body            text NOT NULL,
    archived_at     timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------- online payments
CREATE TABLE IF NOT EXISTS hms.hms_payment_attempts (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    subject_type    text NOT NULL,
    subject_id      text NOT NULL,
    reference       text NOT NULL,
    amount_minor    bigint NOT NULL CHECK (amount_minor > 0),
    currency        text NOT NULL,
    status          text NOT NULL DEFAULT 'pending',
    checked_at      timestamptz,
    settled_id      text,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
-- Created here; widened by a later migration, which owns it from then on (every file re-runs on each deploy).
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'hms_payment_attempts_subject_check' AND conrelid = 'hms.hms_payment_attempts'::regclass) THEN
    ALTER TABLE hms.hms_payment_attempts ADD CONSTRAINT hms_payment_attempts_subject_check CHECK (subject_type IN ('lease', 'folio', 'reservation'));
  END IF;
END $$;
ALTER TABLE hms.hms_payment_attempts DROP CONSTRAINT IF EXISTS hms_payment_attempts_status_check;
ALTER TABLE hms.hms_payment_attempts ADD CONSTRAINT hms_payment_attempts_status_check CHECK (status IN ('pending', 'paid', 'failed'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_payment_attempts_ref_uq ON hms.hms_payment_attempts (reference);

-- ------------------------------------------------------------------- automations
CREATE TABLE IF NOT EXISTS hms.hms_automations (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    name            text NOT NULL,
    trigger_key     text NOT NULL,
    action          text NOT NULL,
    template_id     text REFERENCES hms.hms_message_templates (id),
    notify_user_id  text,
    message         text,
    active          boolean NOT NULL DEFAULT true,
    runs            int NOT NULL DEFAULT 0,
    last_run_at     timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
ALTER TABLE hms.hms_automations DROP CONSTRAINT IF EXISTS hms_automations_trigger_check;
ALTER TABLE hms.hms_automations ADD CONSTRAINT hms_automations_trigger_check CHECK (trigger_key IN
    ('booking_created', 'check_in', 'check_out', 'booking_cancelled', 'low_stock', 'rent_overdue', 'ticket_urgent', 'review_low'));
ALTER TABLE hms.hms_automations DROP CONSTRAINT IF EXISTS hms_automations_action_check;
ALTER TABLE hms.hms_automations ADD CONSTRAINT hms_automations_action_check CHECK (action IN ('send_template', 'notify_staff'));

-- In-app notices for staff (an automation's "tell somebody").
CREATE TABLE IF NOT EXISTS hms.hms_notifications (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    user_id         text,
    title           text NOT NULL,
    body            text,
    link            text,
    read_at         timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS hms_notifications_user_idx ON hms.hms_notifications (bus_id, user_id, cdatetime DESC);

CREATE TABLE IF NOT EXISTS hms.hms_report_schedules (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    report          text NOT NULL,
    frequency       text NOT NULL DEFAULT 'daily',
    recipients      text[] NOT NULL DEFAULT '{}',
    property_id     text REFERENCES hms.hms_properties (id),
    active          boolean NOT NULL DEFAULT true,
    last_sent_on    date,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
ALTER TABLE hms.hms_report_schedules DROP CONSTRAINT IF EXISTS hms_report_schedules_report_check;
ALTER TABLE hms.hms_report_schedules ADD CONSTRAINT hms_report_schedules_report_check CHECK (report IN ('daily_summary', 'occupancy', 'revenue', 'arrears', 'night_audit'));
ALTER TABLE hms.hms_report_schedules DROP CONSTRAINT IF EXISTS hms_report_schedules_frequency_check;
ALTER TABLE hms.hms_report_schedules ADD CONSTRAINT hms_report_schedules_frequency_check CHECK (frequency IN ('daily', 'weekly', 'monthly'));

-- ------------------------------------------------------------ API keys and webhooks
CREATE TABLE IF NOT EXISTS hms.hms_api_keys (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    name            text NOT NULL,
    prefix          text NOT NULL,
    key_hash        text NOT NULL,
    scopes          text[] NOT NULL DEFAULT '{}',
    last_used_at    timestamptz,
    revoked_at      timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_api_keys_hash_uq ON hms.hms_api_keys (key_hash);

CREATE TABLE IF NOT EXISTS hms.hms_webhooks (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    url             text NOT NULL,
    events          text[] NOT NULL DEFAULT '{}',
    secret          text NOT NULL,
    active          boolean NOT NULL DEFAULT true,
    archived_at     timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);

CREATE TABLE IF NOT EXISTS hms.hms_webhook_deliveries (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    webhook_id      text NOT NULL REFERENCES hms.hms_webhooks (id),
    event           text NOT NULL,
    payload         jsonb NOT NULL,
    status          text NOT NULL DEFAULT 'pending',
    attempts        int NOT NULL DEFAULT 0,
    response_code   int,
    last_error      text,
    next_attempt_at timestamptz NOT NULL DEFAULT now(),
    delivered_at    timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hms.hms_webhook_deliveries DROP CONSTRAINT IF EXISTS hms_webhook_deliveries_status_check;
ALTER TABLE hms.hms_webhook_deliveries ADD CONSTRAINT hms_webhook_deliveries_status_check CHECK (status IN ('pending', 'delivered', 'failed'));
CREATE INDEX IF NOT EXISTS hms_webhook_deliveries_due_idx ON hms.hms_webhook_deliveries (next_attempt_at) WHERE status = 'pending';

-- --------------------------------------------------------------- tiers and features
-- The new features, by tier (cumulative), as 20261022-61 began.
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('hms.lost-found',        'app-hms', 'Lost & Found',           1, 'Items left behind, until claimed'),
('hms.night-audit',       'app-hms', 'Night Audit',            1, 'Close the business day: no-shows, figures, locked postings'),
('hms.messaging',         'app-hms', 'Guest Messaging',        1, 'Inbox, templates, email and SMS to guests and tenants'),
('hms.cash-drawer',       'app-hms', 'Cash Drawers',           1, 'Floats, drops and counts for every till'),
('hms.booking-engine',    'app-hms', 'Booking Engine',         2, 'Online booking on your own website, with deposits'),
('hms.channels',          'app-hms', 'Channel Sync',           2, 'Airbnb, Booking.com, Expedia and Vrbo calendars by iCal'),
('hms.inventory',         'app-hms', 'Inventory & Purchasing', 2, 'Stores, stock, recipes, purchase orders'),
('hms.activities',        'app-hms', 'Activities',             2, 'Tours, spa and excursions, booked and charged to rooms'),
('hms.events',            'app-hms', 'Events',                 2, 'Conferences, weddings and banquets from enquiry to the day'),
('hms.loyalty',           'app-hms', 'Loyalty & Companies',    2, 'Points, tiers, company rates and travel agents'),
('hms.tenant-portal',     'app-hms', 'Tenant Portal',          2, 'Tenants see their statement, pay online and report issues'),
('hms.online-payments',   'app-hms', 'Online Payments',        2, 'Card and mobile money through your own gateway'),
('hms.automations',       'app-hms', 'Automations',            2, 'Messages and alerts that send themselves'),
('hms.campaigns',         'app-hms', 'Campaigns',              3, 'Email and SMS to chosen groups of guests'),
('hms.forecasting',       'app-hms', 'Forecasting',            3, 'Occupancy on the books and pace'),
('hms.scheduled-reports', 'app-hms', 'Scheduled Reports',      3, 'Reports emailed every day, week or month'),
('hms.finance',           'app-hms', 'Finance Reports',        3, 'Profit and loss by department, receivables, accounting sync'),
('hms.api',               'app-hms', 'API & Webhooks',         3, 'Keys for other systems and signed webhooks')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

COMMIT;
