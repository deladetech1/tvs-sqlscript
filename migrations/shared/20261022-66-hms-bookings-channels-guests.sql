-- HMS, the rest of bookings and guests: rate plans and promotions, holds and deposits, company
-- accounts and agents, channels (Airbnb, Booking.com, Expedia, Vrbo) by iCal, one inbox and
-- message templates, loyalty, campaigns, reviews, events and bookable activities.
--
--   hms_rate_plans            seasonal, weekend and length-of-stay prices; minimum stays and
--                             closed-to-arrival days
--   hms_promo_codes           discount codes, with limits
--   hms_company_rates         a company's negotiated discount (the company is a cp_parties
--                             customer: the suite keeps one record of it)
--   hms_agents                travel agents, referrers and influencers, and their commission
--   hms_channels              where bookings come from, with commission and markup
--   hms_channel_feeds         a unit's calendar shared with a channel: the export address and
--                             the channel's own iCal to import
--   hms_messages              one inbox: every message to or from a guest or tenant
--   hms_message_templates     the words sent before arrival, on arrival, after departure...
--   hms_loyalty_ledger        points earned and spent
--   hms_campaigns             a message sent to a chosen group of guests
--   hms_reviews               the guest's rating after a stay, through a link
--   hms_events                conferences, weddings and banquets, from enquiry to the day
--   hms_activities            tours, spa treatments, excursions...
--   hms_activity_sessions     an activity at a time, with its places
--   hms_activity_bookings     somebody's places on a session, charged to their room or paid
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

-- ------------------------------------------------------------------- rate plans
CREATE TABLE IF NOT EXISTS hms.hms_rate_plans (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    bus_id             text NOT NULL,
    property_id        text NOT NULL REFERENCES hms.hms_properties (id),
    unit_type_id       text REFERENCES hms.hms_unit_types (id),
    name               text NOT NULL,
    -- price: a night's price; adjust: up or down by percent; los: a percent off stays of min_nights or more.
    kind               text NOT NULL DEFAULT 'price',
    starts_on          date,
    ends_on            date,
    -- Days of the week it applies to (0 Sunday ... 6 Saturday); empty is every day.
    weekdays           int[] NOT NULL DEFAULT '{}',
    value              numeric(14,2) NOT NULL DEFAULT 0,
    min_nights         int NOT NULL DEFAULT 1 CHECK (min_nights BETWEEN 1 AND 365),
    closed_to_arrival  boolean NOT NULL DEFAULT false,
    priority           int NOT NULL DEFAULT 0,
    active             boolean NOT NULL DEFAULT true,
    archived_at        timestamptz,
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    created_by         text,
    CONSTRAINT hms_rate_plans_dates_check CHECK (ends_on IS NULL OR starts_on IS NULL OR ends_on >= starts_on)
);
ALTER TABLE hms.hms_rate_plans DROP CONSTRAINT IF EXISTS hms_rate_plans_kind_check;
ALTER TABLE hms.hms_rate_plans ADD CONSTRAINT hms_rate_plans_kind_check CHECK (kind IN ('price', 'adjust', 'los'));
CREATE INDEX IF NOT EXISTS hms_rate_plans_property_idx ON hms.hms_rate_plans (property_id, active);

CREATE TABLE IF NOT EXISTS hms.hms_promo_codes (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    code           text NOT NULL,
    description    text,
    percent_off    numeric(5,2) CHECK (percent_off IS NULL OR percent_off BETWEEN 0 AND 100),
    amount_off     numeric(14,2) CHECK (amount_off IS NULL OR amount_off >= 0),
    valid_from     date,
    valid_to       date,
    max_uses       int CHECK (max_uses IS NULL OR max_uses > 0),
    used_count     int NOT NULL DEFAULT 0,
    active         boolean NOT NULL DEFAULT true,
    archived_at    timestamptz,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_promo_codes_code_uq ON hms.hms_promo_codes (bus_id, upper(code)) WHERE archived_at IS NULL;

-- --------------------------------------------------------------- companies and agents
CREATE TABLE IF NOT EXISTS hms.hms_company_rates (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    party_id       text NOT NULL,
    unit_type_id   text REFERENCES hms.hms_unit_types (id),
    percent_off    numeric(5,2) NOT NULL DEFAULT 0 CHECK (percent_off BETWEEN 0 AND 100),
    credit_limit   numeric(14,2) CHECK (credit_limit IS NULL OR credit_limit >= 0),
    notes          text,
    archived_at    timestamptz,
    cdatetime      timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_company_rates_uq ON hms.hms_company_rates (party_id, coalesce(unit_type_id, '')) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS hms.hms_agents (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    bus_id              text NOT NULL,
    name                text NOT NULL,
    kind                text NOT NULL DEFAULT 'travel_agent',
    commission_percent  numeric(5,2) NOT NULL DEFAULT 0 CHECK (commission_percent BETWEEN 0 AND 100),
    email               text,
    phone               text,
    notes               text,
    archived_at         timestamptz,
    cdatetime           timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hms.hms_agents DROP CONSTRAINT IF EXISTS hms_agents_kind_check;
ALTER TABLE hms.hms_agents ADD CONSTRAINT hms_agents_kind_check CHECK (kind IN ('travel_agent', 'referrer', 'influencer', 'corporate_booker'));

-- -------------------------------------------------------------------- channels
CREATE TABLE IF NOT EXISTS hms.hms_channels (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    bus_id              text NOT NULL,
    name                text NOT NULL,
    kind                text NOT NULL,
    commission_percent  numeric(5,2) NOT NULL DEFAULT 0 CHECK (commission_percent BETWEEN 0 AND 100),
    -- Prices sent to (or quoted for) this channel are the house price plus this much.
    markup_percent      numeric(5,2) NOT NULL DEFAULT 0 CHECK (markup_percent BETWEEN -50 AND 100),
    min_nights          int NOT NULL DEFAULT 1 CHECK (min_nights BETWEEN 1 AND 365),
    active              boolean NOT NULL DEFAULT true,
    archived_at         timestamptz,
    cdatetime           timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hms.hms_channels DROP CONSTRAINT IF EXISTS hms_channels_kind_check;
ALTER TABLE hms.hms_channels ADD CONSTRAINT hms_channels_kind_check CHECK (kind IN ('airbnb', 'booking_com', 'expedia', 'vrbo', 'other'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_channels_kind_uq ON hms.hms_channels (bus_id, kind, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS hms.hms_channel_feeds (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    channel_id       text NOT NULL REFERENCES hms.hms_channels (id),
    unit_id          text NOT NULL REFERENCES hms.hms_units (id),
    -- The address the channel reads this unit's calendar from (ours), and the channel's own
    -- calendar we read its bookings from.
    export_token     text NOT NULL,
    import_url       text,
    last_synced_at   timestamptz,
    last_error       text,
    imported_count   int NOT NULL DEFAULT 0,
    active           boolean NOT NULL DEFAULT true,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_channel_feeds_token_uq ON hms.hms_channel_feeds (export_token);
CREATE UNIQUE INDEX IF NOT EXISTS hms_channel_feeds_unit_uq ON hms.hms_channel_feeds (channel_id, unit_id);

-- ------------------------------------------------------------ the rest of a booking
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS promo_code_id text REFERENCES hms.hms_promo_codes (id);
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS discount_amount numeric(14,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0);
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS company_id text;
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS agent_id text REFERENCES hms.hms_agents (id);
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS channel_id text REFERENCES hms.hms_channels (id);
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS group_name text;
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS hold_until timestamptz;
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS external_uid text;
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS arrival_time text;
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS special_requests text;
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS signed_name text;
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS signed_at timestamptz;
CREATE UNIQUE INDEX IF NOT EXISTS hms_reservations_external_uq ON hms.hms_reservations (channel_id, external_uid) WHERE external_uid IS NOT NULL;
CREATE INDEX IF NOT EXISTS hms_reservations_hold_idx ON hms.hms_reservations (hold_until) WHERE status = 'tentative' AND hold_until IS NOT NULL;

-- The stay's price for each unit, night by night: amount is the exact total (rate plans make
-- nights differ), rate the average; a key or card issued at check-in.
ALTER TABLE hms.hms_reservation_units ADD COLUMN IF NOT EXISTS amount numeric(14,2) CHECK (amount IS NULL OR amount >= 0);
ALTER TABLE hms.hms_reservation_units ADD COLUMN IF NOT EXISTS nightly jsonb NOT NULL DEFAULT '[]';
ALTER TABLE hms.hms_reservation_units ADD COLUMN IF NOT EXISTS key_ref text;
-- A rate typed in by hand is kept when the dates change; a priced one is priced again.
ALTER TABLE hms.hms_reservation_units ADD COLUMN IF NOT EXISTS rate_locked boolean NOT NULL DEFAULT false;

-- A bill sent to a company (city ledger) instead of the guest.
ALTER TABLE hms.hms_folios ADD COLUMN IF NOT EXISTS company_id text;

-- -------------------------------------------------------------- messages and inbox
CREATE TABLE IF NOT EXISTS hms.hms_message_templates (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    bus_id              text NOT NULL,
    trigger_key         text NOT NULL,
    channel             text NOT NULL DEFAULT 'email',
    subject             text,
    body                text NOT NULL,
    -- For timed messages: hours before arrival (negative) or after departure (positive).
    offset_hours        int NOT NULL DEFAULT 0,
    active              boolean NOT NULL DEFAULT true,
    cdatetime           timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hms.hms_message_templates DROP CONSTRAINT IF EXISTS hms_message_templates_trigger_check;
ALTER TABLE hms.hms_message_templates ADD CONSTRAINT hms_message_templates_trigger_check CHECK (trigger_key IN
    ('booking_confirmed', 'pre_arrival', 'check_in', 'check_out', 'review_request', 'rent_due', 'rent_overdue', 'rent_receipt', 'custom'));
ALTER TABLE hms.hms_message_templates DROP CONSTRAINT IF EXISTS hms_message_templates_channel_check;
ALTER TABLE hms.hms_message_templates ADD CONSTRAINT hms_message_templates_channel_check CHECK (channel IN ('email', 'sms', 'whatsapp'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_message_templates_uq ON hms.hms_message_templates (bus_id, trigger_key, channel);

CREATE TABLE IF NOT EXISTS hms.hms_messages (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    reservation_id   text REFERENCES hms.hms_reservations (id),
    guest_id         text REFERENCES hms.hms_guests (id),
    renter_id        text REFERENCES hms.hms_renters (id),
    lease_id         text REFERENCES hms.hms_leases (id),
    channel          text NOT NULL,
    direction        text NOT NULL DEFAULT 'out',
    to_address       text,
    subject          text,
    body             text NOT NULL,
    trigger_key      text,
    status           text NOT NULL DEFAULT 'sent',
    error            text,
    provider_ref     text,
    read_at          timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
ALTER TABLE hms.hms_messages DROP CONSTRAINT IF EXISTS hms_messages_channel_check;
ALTER TABLE hms.hms_messages ADD CONSTRAINT hms_messages_channel_check CHECK (channel IN ('email', 'sms', 'whatsapp', 'airbnb', 'booking_com', 'expedia', 'vrbo', 'phone', 'note'));
ALTER TABLE hms.hms_messages DROP CONSTRAINT IF EXISTS hms_messages_direction_check;
ALTER TABLE hms.hms_messages ADD CONSTRAINT hms_messages_direction_check CHECK (direction IN ('in', 'out'));
ALTER TABLE hms.hms_messages DROP CONSTRAINT IF EXISTS hms_messages_status_check;
ALTER TABLE hms.hms_messages ADD CONSTRAINT hms_messages_status_check CHECK (status IN ('sent', 'failed', 'received', 'logged'));
CREATE INDEX IF NOT EXISTS hms_messages_bus_idx ON hms.hms_messages (bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS hms_messages_reservation_idx ON hms.hms_messages (reservation_id);
-- A timed message goes once per booking (or lease) and trigger.
CREATE UNIQUE INDEX IF NOT EXISTS hms_messages_once_uq ON hms.hms_messages (coalesce(reservation_id, lease_id), trigger_key, channel)
    WHERE trigger_key IS NOT NULL AND trigger_key NOT IN ('custom', 'rent_receipt', 'rent_due', 'rent_overdue');

-- ------------------------------------------------------------- loyalty and marketing
ALTER TABLE hms.hms_guests ADD COLUMN IF NOT EXISTS loyalty_points int NOT NULL DEFAULT 0;
ALTER TABLE hms.hms_guests ADD COLUMN IF NOT EXISTS marketing_consent boolean NOT NULL DEFAULT false;
ALTER TABLE hms.hms_guests ADD COLUMN IF NOT EXISTS birthday date;
ALTER TABLE hms.hms_guests ADD COLUMN IF NOT EXISTS tags text[] NOT NULL DEFAULT '{}';
ALTER TABLE hms.hms_guests ADD COLUMN IF NOT EXISTS company_id text;

CREATE TABLE IF NOT EXISTS hms.hms_loyalty_ledger (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    guest_id         text NOT NULL REFERENCES hms.hms_guests (id),
    points           int NOT NULL CHECK (points <> 0),
    reason           text NOT NULL,
    reservation_id   text REFERENCES hms.hms_reservations (id),
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
-- A stay earns once.
CREATE UNIQUE INDEX IF NOT EXISTS hms_loyalty_earn_uq ON hms.hms_loyalty_ledger (reservation_id) WHERE reservation_id IS NOT NULL AND points > 0;

CREATE TABLE IF NOT EXISTS hms.hms_campaigns (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    name             text NOT NULL,
    channel          text NOT NULL DEFAULT 'email',
    segment          jsonb NOT NULL DEFAULT '{}',
    subject          text,
    body             text NOT NULL,
    status           text NOT NULL DEFAULT 'draft',
    recipients       int NOT NULL DEFAULT 0,
    delivered        int NOT NULL DEFAULT 0,
    sent_at          timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
ALTER TABLE hms.hms_campaigns DROP CONSTRAINT IF EXISTS hms_campaigns_status_check;
ALTER TABLE hms.hms_campaigns ADD CONSTRAINT hms_campaigns_status_check CHECK (status IN ('draft', 'sending', 'sent'));
ALTER TABLE hms.hms_campaigns DROP CONSTRAINT IF EXISTS hms_campaigns_channel_check;
ALTER TABLE hms.hms_campaigns ADD CONSTRAINT hms_campaigns_channel_check CHECK (channel IN ('email', 'sms'));

CREATE TABLE IF NOT EXISTS hms.hms_reviews (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    property_id      text REFERENCES hms.hms_properties (id),
    reservation_id   text REFERENCES hms.hms_reservations (id),
    guest_id         text REFERENCES hms.hms_guests (id),
    token            text NOT NULL,
    rating           int CHECK (rating IS NULL OR rating BETWEEN 1 AND 5),
    cleanliness      int CHECK (cleanliness IS NULL OR cleanliness BETWEEN 1 AND 5),
    service          int CHECK (service IS NULL OR service BETWEEN 1 AND 5),
    comment          text,
    reply            text,
    source           text NOT NULL DEFAULT 'direct',
    requested_at     timestamptz NOT NULL DEFAULT now(),
    submitted_at     timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_reviews_token_uq ON hms.hms_reviews (token);
CREATE UNIQUE INDEX IF NOT EXISTS hms_reviews_reservation_uq ON hms.hms_reviews (reservation_id) WHERE reservation_id IS NOT NULL;

-- ----------------------------------------------------------------------- events
CREATE TABLE IF NOT EXISTS hms.hms_events (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    property_id       text NOT NULL REFERENCES hms.hms_properties (id),
    venue_unit_id     text REFERENCES hms.hms_units (id),
    name              text NOT NULL,
    kind              text NOT NULL DEFAULT 'conference',
    client_name       text NOT NULL,
    client_phone      text,
    client_email      text,
    company_id        text,
    event_date        date NOT NULL,
    start_time        time,
    end_time          time,
    guests            int NOT NULL DEFAULT 0 CHECK (guests >= 0),
    status            text NOT NULL DEFAULT 'inquiry',
    package           text,
    quote_amount      numeric(14,2) NOT NULL DEFAULT 0 CHECK (quote_amount >= 0),
    deposit_amount    numeric(14,2) NOT NULL DEFAULT 0 CHECK (deposit_amount >= 0),
    folio_id          text REFERENCES hms.hms_folios (id),
    notes             text,
    lost_reason       text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hms.hms_events DROP CONSTRAINT IF EXISTS hms_events_status_check;
ALTER TABLE hms.hms_events ADD CONSTRAINT hms_events_status_check CHECK (status IN ('inquiry', 'proposal', 'tentative', 'confirmed', 'completed', 'cancelled', 'lost'));
ALTER TABLE hms.hms_events DROP CONSTRAINT IF EXISTS hms_events_kind_check;
ALTER TABLE hms.hms_events ADD CONSTRAINT hms_events_kind_check CHECK (kind IN ('conference', 'wedding', 'banquet', 'party', 'meeting', 'funeral', 'other'));
CREATE INDEX IF NOT EXISTS hms_events_bus_idx ON hms.hms_events (bus_id, event_date);

-- ------------------------------------------------------------------- activities
CREATE TABLE IF NOT EXISTS hms.hms_activities (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    property_id       text NOT NULL REFERENCES hms.hms_properties (id),
    name              text NOT NULL,
    category          text NOT NULL DEFAULT 'tour',
    description       text,
    duration_minutes  int NOT NULL DEFAULT 60 CHECK (duration_minutes BETWEEN 5 AND 10080),
    price             numeric(14,2) NOT NULL DEFAULT 0 CHECK (price >= 0),
    capacity          int NOT NULL DEFAULT 10 CHECK (capacity BETWEEN 1 AND 10000),
    active            boolean NOT NULL DEFAULT true,
    archived_at       timestamptz,
    cdatetime         timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hms.hms_activities DROP CONSTRAINT IF EXISTS hms_activities_category_check;
ALTER TABLE hms.hms_activities ADD CONSTRAINT hms_activities_category_check CHECK (category IN ('tour', 'spa', 'excursion', 'sport', 'class', 'transport', 'dining', 'other'));

CREATE TABLE IF NOT EXISTS hms.hms_activity_sessions (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    activity_id       text NOT NULL REFERENCES hms.hms_activities (id),
    starts_at         timestamptz NOT NULL,
    capacity          int CHECK (capacity IS NULL OR capacity > 0),
    guide_id          text,
    status            text NOT NULL DEFAULT 'scheduled',
    notes             text,
    cdatetime         timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hms.hms_activity_sessions DROP CONSTRAINT IF EXISTS hms_activity_sessions_status_check;
ALTER TABLE hms.hms_activity_sessions ADD CONSTRAINT hms_activity_sessions_status_check CHECK (status IN ('scheduled', 'completed', 'cancelled'));
CREATE INDEX IF NOT EXISTS hms_activity_sessions_when_idx ON hms.hms_activity_sessions (bus_id, starts_at);

CREATE TABLE IF NOT EXISTS hms.hms_activity_bookings (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    session_id        text NOT NULL REFERENCES hms.hms_activity_sessions (id),
    guest_id          text REFERENCES hms.hms_guests (id),
    reservation_id    text REFERENCES hms.hms_reservations (id),
    name              text NOT NULL,
    phone             text,
    party_size        int NOT NULL DEFAULT 1 CHECK (party_size > 0),
    amount            numeric(14,2) NOT NULL DEFAULT 0 CHECK (amount >= 0),
    status            text NOT NULL DEFAULT 'booked',
    paid_method       text,
    folio_line_id     text REFERENCES hms.hms_folio_lines (id),
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text
);
ALTER TABLE hms.hms_activity_bookings DROP CONSTRAINT IF EXISTS hms_activity_bookings_status_check;
ALTER TABLE hms.hms_activity_bookings ADD CONSTRAINT hms_activity_bookings_status_check CHECK (status IN ('booked', 'attended', 'no_show', 'cancelled'));
CREATE INDEX IF NOT EXISTS hms_activity_bookings_session_idx ON hms.hms_activity_bookings (session_id);

-- Activity and event charges reach the guest bill like the restaurant's.
ALTER TABLE hms.hms_folio_lines DROP CONSTRAINT IF EXISTS hms_folio_lines_category_check;
ALTER TABLE hms.hms_folio_lines ADD CONSTRAINT hms_folio_lines_category_check CHECK (category IN
    ('room', 'restaurant', 'bar', 'minibar', 'laundry', 'service', 'damage', 'late_checkout', 'early_checkin',
     'tax', 'deposit', 'payment', 'refund', 'activity', 'event', 'discount', 'other'));

COMMIT;
