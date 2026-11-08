-- HMS, part 4: what the world's leading hospitality systems have that HMS did not.
--
--   hms_cm_*                a two-way channel manager (Channex): rates, availability and
--                           restrictions sent to Booking.com, Expedia, Airbnb and the GDS;
--                           their bookings, changes and cancellations received with the guest
--   hms_group_blocks        a block of rooms held for a wedding, a tour or a conference: rooms
--                           per type per night, a release date, a rooming list, one master bill
--   hms_folio_routes        charges routed automatically: the room to the company or the
--                           group's master bill, the bar and minibar to the guest
--   hms_card_guarantees     the guest's card kept (by Core Platform's gateway) when they book,
--   hms_card_charges        and charged for a no-show, a late cancellation or the balance
--   hms_lock_* / door_keys  door locks (TTLock, or any lock system by webhook): a code or a
--                           phone key made at check-in for the stay, taken back at check-out
--   hms_exchange_rates      the desk's rates for the currencies it accepts; a payment in
--                           dollars on a cedi bill keeps both amounts and the rate
--   hms_stay_restrictions   minimum stay on arrival, maximum stay, closed to arrival or
--                           departure, stop sell
--   hms_rate_products       rates made from the base price: non-refundable -10%, with
--                           breakfast +80 a night
--   hms_competitor_rates    what the hotels around charge, for the comparison and parity checks
--   hms_agent_contracts     travel agents' and tour operators' net rates and allotments;
--   hms_agent_commission_payments  what was paid them
--   hms_surveys / responses guest surveys with NPS, during and after the stay
--   hms_logbook             the shift logbook: handovers, incidents, complaints, who has read them
--   hms_linen_*             linen in the store, in rooms and at the laundry
--   hms_green_skips         "skip my cleaning tonight", for a credit
--   hms_wifi_*              the Wi-Fi login page that captures guests' details (with consent)
--   hms_guest_consents      what each guest agreed to, when and where; guests can be erased
--   hms_ai_usage            the AI helpers' use, for the business to see
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

-- ============================================================= channel manager
CREATE TABLE IF NOT EXISTS hms.hms_cm_connections (
    id                    text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id             text NOT NULL,
    bus_id                text NOT NULL,
    property_id           text NOT NULL REFERENCES hms.hms_properties (id),
    provider              text NOT NULL DEFAULT 'channex' CHECK (provider IN ('channex')),
    api_key               text,
    base_url              text,
    external_property_id  text,
    push_days             int NOT NULL DEFAULT 365 CHECK (push_days BETWEEN 7 AND 730),
    active                boolean NOT NULL DEFAULT true,
    webhook_token         text NOT NULL,
    last_push_at          timestamptz,
    last_pull_at          timestamptz,
    last_error            text,
    cdatetime             timestamptz NOT NULL DEFAULT now(),
    created_by            text
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_cm_connections_property_uq ON hms.hms_cm_connections (property_id);
CREATE UNIQUE INDEX IF NOT EXISTS hms_cm_connections_token_uq ON hms.hms_cm_connections (webhook_token);

CREATE TABLE IF NOT EXISTS hms.hms_cm_mappings (
    id                     text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text NOT NULL,
    bus_id                 text NOT NULL,
    connection_id          text NOT NULL REFERENCES hms.hms_cm_connections (id) ON DELETE CASCADE,
    unit_type_id           text NOT NULL REFERENCES hms.hms_unit_types (id),
    rate_product_id        text,
    external_room_type_id  text NOT NULL,
    external_rate_plan_id  text NOT NULL,
    active                 boolean NOT NULL DEFAULT true,
    cdatetime              timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_cm_mappings_uq ON hms.hms_cm_mappings (connection_id, unit_type_id, coalesce(rate_product_id, ''));

CREATE TABLE IF NOT EXISTS hms.hms_cm_bookings (
    id                   text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id            text NOT NULL,
    bus_id               text NOT NULL,
    connection_id        text NOT NULL REFERENCES hms.hms_cm_connections (id) ON DELETE CASCADE,
    external_booking_id  text NOT NULL,
    revision_id          text NOT NULL,
    ota_name             text,
    ota_code             text,
    status               text NOT NULL,
    reservation_id       text REFERENCES hms.hms_reservations (id),
    outcome              text NOT NULL DEFAULT 'booked' CHECK (outcome IN ('booked', 'modified', 'cancelled', 'failed', 'ignored')),
    error                text,
    payload              jsonb,
    received_at          timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_cm_bookings_rev_uq ON hms.hms_cm_bookings (connection_id, revision_id);
CREATE INDEX IF NOT EXISTS hms_cm_bookings_ext_idx ON hms.hms_cm_bookings (connection_id, external_booking_id);

ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS ota_name text;
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS ota_code text;
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS cm_booking_id text;

-- ============================================================ revenue: products
CREATE TABLE IF NOT EXISTS hms.hms_rate_products (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    property_id     text NOT NULL REFERENCES hms.hms_properties (id),
    name            text NOT NULL,
    code            text,
    description     text,
    adjust_percent  numeric(7,2) NOT NULL DEFAULT 0 CHECK (adjust_percent BETWEEN -90 AND 300),
    adjust_amount   numeric(14,2) NOT NULL DEFAULT 0,
    refundable      boolean NOT NULL DEFAULT true,
    includes        text,
    min_nights      int CHECK (min_nights IS NULL OR min_nights BETWEEN 1 AND 365),
    sort_order      int NOT NULL DEFAULT 0,
    active          boolean NOT NULL DEFAULT true,
    archived_at     timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
ALTER TABLE hms.hms_cm_mappings DROP CONSTRAINT IF EXISTS hms_cm_mappings_rate_product_fk;
ALTER TABLE hms.hms_cm_mappings ADD CONSTRAINT hms_cm_mappings_rate_product_fk FOREIGN KEY (rate_product_id) REFERENCES hms.hms_rate_products (id);
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS rate_product_id text REFERENCES hms.hms_rate_products (id);

CREATE TABLE IF NOT EXISTS hms.hms_stay_restrictions (
    id                   text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id            text NOT NULL,
    bus_id               text NOT NULL,
    property_id          text NOT NULL REFERENCES hms.hms_properties (id),
    unit_type_id         text REFERENCES hms.hms_unit_types (id),
    name                 text NOT NULL,
    starts_on            date NOT NULL,
    ends_on              date NOT NULL,
    weekdays             int[] NOT NULL DEFAULT '{}',
    min_stay_arrival     int CHECK (min_stay_arrival IS NULL OR min_stay_arrival BETWEEN 1 AND 365),
    max_stay             int CHECK (max_stay IS NULL OR max_stay BETWEEN 1 AND 365),
    closed_to_arrival    boolean NOT NULL DEFAULT false,
    closed_to_departure  boolean NOT NULL DEFAULT false,
    stop_sell            boolean NOT NULL DEFAULT false,
    active               boolean NOT NULL DEFAULT true,
    archived_at          timestamptz,
    cdatetime            timestamptz NOT NULL DEFAULT now(),
    created_by           text,
    CHECK (ends_on >= starts_on)
);
CREATE INDEX IF NOT EXISTS hms_stay_restrictions_idx ON hms.hms_stay_restrictions (property_id, starts_on, ends_on) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS hms.hms_competitor_rates (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    property_id  text NOT NULL REFERENCES hms.hms_properties (id),
    competitor   text NOT NULL,
    unit_kind    text,
    on_date      date NOT NULL,
    price        numeric(14,2) NOT NULL CHECK (price >= 0),
    currency     text,
    source       text NOT NULL DEFAULT 'manual' CHECK (source IN ('manual', 'import', 'channel')),
    notes        text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text
);
CREATE INDEX IF NOT EXISTS hms_competitor_rates_idx ON hms.hms_competitor_rates (property_id, on_date);

-- ================================================================ group blocks
CREATE TABLE IF NOT EXISTS hms.hms_group_blocks (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    code             text NOT NULL,
    name             text NOT NULL,
    company_id       text,
    contact_name     text,
    contact_email    text,
    contact_phone    text,
    arrive_on        date NOT NULL,
    depart_on        date NOT NULL,
    release_on       date,
    rate             numeric(14,2) CHECK (rate IS NULL OR rate >= 0),
    status           text NOT NULL DEFAULT 'tentative' CHECK (status IN ('tentative', 'definite', 'released', 'cancelled')),
    master_folio_id  text REFERENCES hms.hms_folios (id),
    route_rooms      boolean NOT NULL DEFAULT true,
    notes            text,
    released_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz,
    created_by       text,
    CHECK (depart_on > arrive_on)
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_group_blocks_code_uq ON hms.hms_group_blocks (bus_id, code);

CREATE TABLE IF NOT EXISTS hms.hms_group_block_rooms (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    block_id      text NOT NULL REFERENCES hms.hms_group_blocks (id) ON DELETE CASCADE,
    unit_type_id  text NOT NULL REFERENCES hms.hms_unit_types (id),
    night         date NOT NULL,
    rooms         int NOT NULL CHECK (rooms >= 0)
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_group_block_rooms_uq ON hms.hms_group_block_rooms (block_id, unit_type_id, night);
CREATE INDEX IF NOT EXISTS hms_group_block_rooms_night_idx ON hms.hms_group_block_rooms (unit_type_id, night);

ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS group_block_id text REFERENCES hms.hms_group_blocks (id);
CREATE INDEX IF NOT EXISTS hms_reservations_block_idx ON hms.hms_reservations (group_block_id) WHERE group_block_id IS NOT NULL;

-- ================================================================ folio routing
CREATE TABLE IF NOT EXISTS hms.hms_folio_routes (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    reservation_id   text REFERENCES hms.hms_reservations (id),
    group_block_id   text REFERENCES hms.hms_group_blocks (id),
    target_folio_id  text NOT NULL REFERENCES hms.hms_folios (id),
    categories       text[] NOT NULL DEFAULT '{}',
    active           boolean NOT NULL DEFAULT true,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    CHECK ((reservation_id IS NULL) <> (group_block_id IS NULL))
);
CREATE INDEX IF NOT EXISTS hms_folio_routes_res_idx ON hms.hms_folio_routes (reservation_id) WHERE active;
CREATE INDEX IF NOT EXISTS hms_folio_routes_block_idx ON hms.hms_folio_routes (group_block_id) WHERE active;
ALTER TABLE hms.hms_folio_lines ADD COLUMN IF NOT EXISTS routed_from_folio_id text REFERENCES hms.hms_folios (id);

-- ================================================================ multi-currency
ALTER TABLE hms.hms_settings ADD COLUMN IF NOT EXISTS accepted_currencies text[] NOT NULL DEFAULT '{}';
CREATE TABLE IF NOT EXISTS hms.hms_exchange_rates (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    currency      text NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
    rate          numeric(18,8) NOT NULL CHECK (rate > 0),
    effective_on  date NOT NULL,
    notes         text,
    archived_at   timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text
);
CREATE INDEX IF NOT EXISTS hms_exchange_rates_idx ON hms.hms_exchange_rates (bus_id, currency, effective_on DESC) WHERE archived_at IS NULL;
ALTER TABLE hms.hms_folio_lines ADD COLUMN IF NOT EXISTS foreign_currency text;
ALTER TABLE hms.hms_folio_lines ADD COLUMN IF NOT EXISTS foreign_amount numeric(14,2);
ALTER TABLE hms.hms_folio_lines ADD COLUMN IF NOT EXISTS exchange_rate numeric(18,8);

-- ============================================================== card guarantees
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS guarantee_kind text NOT NULL DEFAULT 'none';
ALTER TABLE hms.hms_properties DROP CONSTRAINT IF EXISTS hms_properties_guarantee_kind_check;
ALTER TABLE hms.hms_properties ADD CONSTRAINT hms_properties_guarantee_kind_check CHECK (guarantee_kind IN ('none', 'card', 'deposit'));
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS free_cancel_hours int;
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS late_cancel_fee text NOT NULL DEFAULT 'none';
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS late_cancel_value numeric(14,2);
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS no_show_fee text NOT NULL DEFAULT 'none';
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS no_show_value numeric(14,2);
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS auto_charge_fees boolean NOT NULL DEFAULT false;
ALTER TABLE hms.hms_properties DROP CONSTRAINT IF EXISTS hms_properties_fee_kinds_check;
ALTER TABLE hms.hms_properties ADD CONSTRAINT hms_properties_fee_kinds_check
    CHECK (late_cancel_fee IN ('none', 'first_night', 'percent', 'fixed') AND no_show_fee IN ('none', 'first_night', 'percent', 'fixed'));

CREATE TABLE IF NOT EXISTS hms.hms_card_guarantees (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    bus_id              text NOT NULL,
    reservation_id      text NOT NULL REFERENCES hms.hms_reservations (id),
    guest_id            text REFERENCES hms.hms_guests (id),
    payer_ref           text NOT NULL,
    attempt_reference   text,
    authorization_id    text,
    card_type           text,
    bank                text,
    last4               text,
    exp_month           text,
    exp_year            text,
    status              text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'saved', 'failed', 'removed')),
    saved_at            timestamptz,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    created_by          text
);
CREATE INDEX IF NOT EXISTS hms_card_guarantees_res_idx ON hms.hms_card_guarantees (reservation_id);

CREATE TABLE IF NOT EXISTS hms.hms_card_charges (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    reservation_id  text NOT NULL REFERENCES hms.hms_reservations (id),
    guarantee_id    text NOT NULL REFERENCES hms.hms_card_guarantees (id),
    reason          text NOT NULL CHECK (reason IN ('no_show', 'late_cancel', 'balance', 'incidentals', 'other')),
    amount          numeric(14,2) NOT NULL CHECK (amount > 0),
    currency        text NOT NULL,
    reference       text,
    status          text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'failed')),
    error           text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_card_charges_fee_uq ON hms.hms_card_charges (reservation_id, reason) WHERE reason IN ('no_show', 'late_cancel') AND status <> 'failed';

-- ==================================================================== door locks
CREATE TABLE IF NOT EXISTS hms.hms_lock_connections (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    property_id       text NOT NULL REFERENCES hms.hms_properties (id),
    provider          text NOT NULL CHECK (provider IN ('ttlock', 'webhook')),
    name              text NOT NULL,
    client_id         text,
    client_secret     text,
    username          text,
    password_md5      text,
    access_token      text,
    token_expires_at  timestamptz,
    base_url          text,
    webhook_url       text,
    webhook_secret    text,
    send_to_guest     boolean NOT NULL DEFAULT true,
    active            boolean NOT NULL DEFAULT true,
    last_error        text,
    archived_at       timestamptz,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text
);

CREATE TABLE IF NOT EXISTS hms.hms_unit_locks (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    connection_id     text NOT NULL REFERENCES hms.hms_lock_connections (id),
    unit_id           text NOT NULL REFERENCES hms.hms_units (id),
    external_lock_id  text NOT NULL,
    archived_at       timestamptz,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_unit_locks_unit_uq ON hms.hms_unit_locks (unit_id) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS hms.hms_door_keys (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    reservation_id  text NOT NULL REFERENCES hms.hms_reservations (id),
    unit_id         text NOT NULL REFERENCES hms.hms_units (id),
    connection_id   text NOT NULL REFERENCES hms.hms_lock_connections (id),
    kind            text NOT NULL DEFAULT 'passcode' CHECK (kind IN ('passcode', 'ekey')),
    code            text,
    external_id     text,
    valid_from      timestamptz NOT NULL,
    valid_to        timestamptz NOT NULL,
    status          text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'issued', 'failed', 'revoked')),
    error           text,
    sent_at         timestamptz,
    revoked_at      timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
CREATE INDEX IF NOT EXISTS hms_door_keys_res_idx ON hms.hms_door_keys (reservation_id);
CREATE INDEX IF NOT EXISTS hms_door_keys_open_idx ON hms.hms_door_keys (bus_id, status) WHERE status IN ('pending', 'issued');

-- =========================================================== agents' contracts
CREATE TABLE IF NOT EXISTS hms.hms_agent_contracts (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    bus_id              text NOT NULL,
    agent_id            text NOT NULL REFERENCES hms.hms_agents (id),
    property_id         text NOT NULL REFERENCES hms.hms_properties (id),
    unit_type_id        text REFERENCES hms.hms_unit_types (id),
    name                text NOT NULL,
    starts_on           date NOT NULL,
    ends_on             date NOT NULL,
    net_rate            numeric(14,2) CHECK (net_rate IS NULL OR net_rate >= 0),
    percent_off         numeric(5,2) CHECK (percent_off IS NULL OR percent_off BETWEEN 0 AND 100),
    allotment           int CHECK (allotment IS NULL OR allotment >= 0),
    release_days        int CHECK (release_days IS NULL OR release_days BETWEEN 0 AND 365),
    commission_percent  numeric(5,2) CHECK (commission_percent IS NULL OR commission_percent BETWEEN 0 AND 100),
    notes               text,
    active              boolean NOT NULL DEFAULT true,
    archived_at         timestamptz,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    created_by          text,
    CHECK (ends_on >= starts_on)
);

CREATE TABLE IF NOT EXISTS hms.hms_agent_commission_payments (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    agent_id         text NOT NULL REFERENCES hms.hms_agents (id),
    period_from      date NOT NULL,
    period_to        date NOT NULL,
    amount           numeric(14,2) NOT NULL CHECK (amount >= 0),
    bookings         int NOT NULL DEFAULT 0,
    paid_on          date NOT NULL,
    method           text,
    reference        text,
    notes            text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS commission_payment_id text REFERENCES hms.hms_agent_commission_payments (id);
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS agent_contract_id text REFERENCES hms.hms_agent_contracts (id);

-- ================================================================== surveys
CREATE TABLE IF NOT EXISTS hms.hms_surveys (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    bus_id             text NOT NULL,
    property_id        text REFERENCES hms.hms_properties (id),
    name               text NOT NULL,
    kind               text NOT NULL DEFAULT 'post_stay' CHECK (kind IN ('in_stay', 'post_stay')),
    aspects            text[] NOT NULL DEFAULT '{}',
    send_after_hours   int NOT NULL DEFAULT 2 CHECK (send_after_hours BETWEEN 0 AND 720),
    channel            text NOT NULL DEFAULT 'email' CHECK (channel IN ('email', 'sms')),
    alert_below        int NOT NULL DEFAULT 7 CHECK (alert_below BETWEEN 0 AND 11),
    active             boolean NOT NULL DEFAULT true,
    archived_at        timestamptz,
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    created_by         text
);

CREATE TABLE IF NOT EXISTS hms.hms_survey_responses (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    survey_id       text NOT NULL REFERENCES hms.hms_surveys (id),
    property_id     text REFERENCES hms.hms_properties (id),
    reservation_id  text REFERENCES hms.hms_reservations (id),
    guest_id        text REFERENCES hms.hms_guests (id),
    token           text NOT NULL,
    nps             int CHECK (nps IS NULL OR nps BETWEEN 0 AND 10),
    scores          jsonb NOT NULL DEFAULT '{}',
    comment         text,
    sent_at         timestamptz,
    submitted_at    timestamptz,
    followed_up_at  timestamptz,
    followed_up_by  text,
    follow_up_note  text,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_survey_responses_token_uq ON hms.hms_survey_responses (token);
CREATE UNIQUE INDEX IF NOT EXISTS hms_survey_responses_once_uq ON hms.hms_survey_responses (survey_id, reservation_id) WHERE reservation_id IS NOT NULL;

ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS google_review_url text;
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS tripadvisor_url text;
ALTER TABLE hms.hms_reviews ADD COLUMN IF NOT EXISTS external_id text;
ALTER TABLE hms.hms_reviews ADD COLUMN IF NOT EXISTS author_name text;
ALTER TABLE hms.hms_reviews ADD COLUMN IF NOT EXISTS review_url text;
ALTER TABLE hms.hms_reviews ADD COLUMN IF NOT EXISTS replied_at timestamptz;
CREATE UNIQUE INDEX IF NOT EXISTS hms_reviews_external_uq ON hms.hms_reviews (bus_id, source, external_id) WHERE external_id IS NOT NULL;

-- ================================================================== logbook
CREATE TABLE IF NOT EXISTS hms.hms_logbook (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    property_id     text NOT NULL REFERENCES hms.hms_properties (id),
    department      text NOT NULL DEFAULT 'front_desk',
    kind            text NOT NULL DEFAULT 'note' CHECK (kind IN ('note', 'handover', 'incident', 'complaint', 'request', 'security')),
    title           text NOT NULL,
    body            text,
    priority        text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    severity        text CHECK (severity IS NULL OR severity IN ('minor', 'moderate', 'serious', 'critical')),
    status          text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'resolved')),
    follow_up_on    date,
    assigned_to     text,
    reservation_id  text REFERENCES hms.hms_reservations (id),
    unit_id         text REFERENCES hms.hms_units (id),
    injured         boolean NOT NULL DEFAULT false,
    police_called   boolean NOT NULL DEFAULT false,
    resolution      text,
    resolved_at     timestamptz,
    resolved_by     text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
CREATE INDEX IF NOT EXISTS hms_logbook_idx ON hms.hms_logbook (bus_id, property_id, cdatetime DESC);

CREATE TABLE IF NOT EXISTS hms.hms_logbook_reads (
    entry_id  text NOT NULL REFERENCES hms.hms_logbook (id) ON DELETE CASCADE,
    user_id   text NOT NULL,
    read_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (entry_id, user_id)
);

-- ==================================================================== linen
CREATE TABLE IF NOT EXISTS hms.hms_linen_items (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    property_id    text NOT NULL REFERENCES hms.hms_properties (id),
    name           text NOT NULL,
    par_level      int NOT NULL DEFAULT 0 CHECK (par_level >= 0),
    clean_qty      int NOT NULL DEFAULT 0 CHECK (clean_qty >= 0),
    in_use_qty     int NOT NULL DEFAULT 0 CHECK (in_use_qty >= 0),
    laundry_qty    int NOT NULL DEFAULT 0 CHECK (laundry_qty >= 0),
    discarded_qty  int NOT NULL DEFAULT 0 CHECK (discarded_qty >= 0),
    unit_cost      numeric(14,2),
    laundry_cost   numeric(14,2),
    active         boolean NOT NULL DEFAULT true,
    archived_at    timestamptz,
    cdatetime      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS hms.hms_linen_moves (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    item_id      text NOT NULL REFERENCES hms.hms_linen_items (id),
    kind         text NOT NULL CHECK (kind IN ('issue', 'collect', 'send', 'return', 'discard', 'purchase', 'count')),
    qty          int NOT NULL CHECK (qty >= 0),
    variance     int,
    unit_id      text REFERENCES hms.hms_units (id),
    notes        text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text
);
CREATE INDEX IF NOT EXISTS hms_linen_moves_idx ON hms.hms_linen_moves (item_id, cdatetime DESC);

-- =============================================================== green stays
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS green_credit numeric(14,2);
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS green_points int;
CREATE TABLE IF NOT EXISTS hms.hms_green_skips (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    reservation_id  text NOT NULL REFERENCES hms.hms_reservations (id),
    night           date NOT NULL,
    credit          numeric(14,2),
    points          int,
    folio_line_id   text,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_green_skips_uq ON hms.hms_green_skips (reservation_id, night);

-- ============================================================ sustainability
ALTER TABLE hms.hms_settings ADD COLUMN IF NOT EXISTS co2_per_kwh numeric(8,4) NOT NULL DEFAULT 0.4;
ALTER TABLE hms.hms_settings ADD COLUMN IF NOT EXISTS co2_per_litre_diesel numeric(8,4) NOT NULL DEFAULT 2.68;
ALTER TABLE hms.hms_settings ADD COLUMN IF NOT EXISTS co2_per_kg_gas numeric(8,4) NOT NULL DEFAULT 2.98;

-- ===================================================================== Wi-Fi
CREATE TABLE IF NOT EXISTS hms.hms_wifi_portals (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    property_id  text NOT NULL REFERENCES hms.hms_properties (id),
    name         text NOT NULL,
    token        text NOT NULL,
    controller   text NOT NULL DEFAULT 'generic' CHECK (controller IN ('generic', 'mikrotik', 'unifi', 'omada')),
    ask_email    boolean NOT NULL DEFAULT true,
    ask_phone    boolean NOT NULL DEFAULT false,
    ask_room     boolean NOT NULL DEFAULT false,
    welcome      text,
    terms        text,
    success_url  text,
    active       boolean NOT NULL DEFAULT true,
    archived_at  timestamptz,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_wifi_portals_token_uq ON hms.hms_wifi_portals (token);

CREATE TABLE IF NOT EXISTS hms.hms_wifi_logins (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    portal_id       text NOT NULL REFERENCES hms.hms_wifi_portals (id),
    property_id     text NOT NULL REFERENCES hms.hms_properties (id),
    guest_id        text REFERENCES hms.hms_guests (id),
    reservation_id  text REFERENCES hms.hms_reservations (id),
    name            text,
    email           text,
    phone           text,
    mac             text,
    consent         boolean NOT NULL DEFAULT false,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS hms_wifi_logins_idx ON hms.hms_wifi_logins (portal_id, cdatetime DESC);

-- ================================================================== privacy
ALTER TABLE hms.hms_settings ADD COLUMN IF NOT EXISTS retention_years int CHECK (retention_years IS NULL OR retention_years BETWEEN 1 AND 30);
ALTER TABLE hms.hms_guests ADD COLUMN IF NOT EXISTS erased_at timestamptz;
CREATE TABLE IF NOT EXISTS hms.hms_guest_consents (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    guest_id    text NOT NULL REFERENCES hms.hms_guests (id),
    kind        text NOT NULL CHECK (kind IN ('marketing', 'data_processing', 'photos', 'wifi', 'profiling')),
    granted     boolean NOT NULL,
    source      text NOT NULL DEFAULT 'desk' CHECK (source IN ('desk', 'website', 'wifi', 'precheckin', 'survey', 'guest_request')),
    wording     text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text
);
CREATE INDEX IF NOT EXISTS hms_guest_consents_idx ON hms.hms_guest_consents (guest_id, kind, cdatetime DESC);

ALTER TABLE hms.hms_unit_types ADD COLUMN IF NOT EXISTS accessibility text[] NOT NULL DEFAULT '{}';

-- =========================================================== Google, AI
ALTER TABLE hms.hms_settings ADD COLUMN IF NOT EXISTS google_feed_token text;
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS google_hotel_id text;
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS latitude numeric(9,6);
ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS longitude numeric(9,6);

CREATE TABLE IF NOT EXISTS hms.hms_ai_usage (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    kind          text NOT NULL,
    subject_id    text,
    input_tokens  int NOT NULL DEFAULT 0,
    output_tokens int NOT NULL DEFAULT 0,
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS hms_ai_usage_idx ON hms.hms_ai_usage (bus_id, cdatetime DESC);

-- ================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('hms.channel-manager', 'app-hms', 'Channel Manager',          2, 'Rates, availability and restrictions sent to Booking.com, Expedia, Airbnb and the GDS, and their bookings received'),
('hms.groups',          'app-hms', 'Group Blocks',             2, 'Rooms held for groups with a release date, a rooming list, pick-up and one master bill'),
('hms.folio-routing',   'app-hms', 'Bill Routing',             1, 'Charges sent automatically to the right bill: the room to the company, the bar to the guest'),
('hms.card-guarantee',  'app-hms', 'Card Guarantees',          2, 'The guest''s card kept when they book and charged for no-shows and late cancellations'),
('hms.door-locks',      'app-hms', 'Door Locks and Phone Keys', 2, 'A door code or phone key made at check-in for the stay, and taken back at check-out'),
('hms.multi-currency',  'app-hms', 'Several Currencies',       2, 'Payments and prices in the currencies you accept, at your rates'),
('hms.revenue',         'app-hms', 'Revenue Management',       2, 'Stay restrictions, stop sell, rates made from the base price, and rate parity checks'),
('hms.rate-shopping',   'app-hms', 'Competitor Rates',         3, 'What the hotels around you charge, against your prices'),
('hms.agent-contracts', 'app-hms', 'Agent Contracts and Commission', 2, 'Travel agents'' and tour operators'' net rates and allotments, and the commission owed'),
('hms.surveys',         'app-hms', 'Guest Surveys and NPS',    2, 'Short surveys during and after the stay, with alerts on unhappy guests'),
('hms.logbook',         'app-hms', 'Shift Logbook',            1, 'Handovers, incidents and complaints between shifts, and who has read them'),
('hms.id-scan',         'app-hms', 'Passport Scanning',        1, 'The passport''s machine-readable lines fill the guest''s details in'),
('hms.google-hotels',   'app-hms', 'Google Hotels',            2, 'Your prices and booking link on Google search and Maps'),
('hms.linen',           'app-hms', 'Linen and Laundry',        1, 'Linen in the store, in rooms and at the laundry, against the par level'),
('hms.green-stay',      'app-hms', 'Green Stays',              1, 'Guests skip a cleaning for a credit'),
('hms.sustainability',  'app-hms', 'Sustainability Report',    2, 'Energy, water and carbon per occupied room night'),
('hms.wifi-portal',     'app-hms', 'Wi-Fi Login Page',         2, 'Guests sign in to the Wi-Fi with their details, with consent'),
('hms.privacy',         'app-hms', 'Data Protection',          1, 'Consent records, data export and erasure on request, and how long guests are kept'),
('hms.ai-assist',       'app-hms', 'AI Helpers',               3, 'Suggested replies to guests and reviews, and price suggestions')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

COMMIT;
