-- =====================================================================
-- HMS is billed per room, bed, rental unit and outlet, with a minimum
-- ---------------------------------------------------------------------
-- The owner decided (2026-10-26, "fix this once and for all", then the
-- market-compared structure the same day) that HMS is charged per business
-- per month on FOUR METERS instead of per location (USD per month):
--
--   meter    what is counted                                Basic  Advance  Premium
--   room     stay units that are rooms, suites, apartments   2.00    3.50     5.50
--   bed      stay units that are dormitory / hostel beds     1.00    1.75     2.75
--   rental   units let on a lease (usage 'rental')           1.00    1.50     2.00
--   outlet   properties whose profile runs the restaurant   15.00   25.00    40.00
--
--   - rooms beyond the first 50 of a business cost 25% less (the volume
--     rule, cp_apps.volume_threshold / volume_discount); beds, rentals and
--     outlets have no volume discount. Above 150 rooms is Enterprise by quote
--     -- a sales note, not enforced;
--   - the month is never billed below min_units (10) x the tier's room price:
--     20 / 35 / 55;
--   - Enterprise stays a quote (no meter prices).
--
-- Nobody uses HMS in production yet, so no live bill changes.
--
-- cp_apps.billing_unit = 'UNIT' for app-hms is set in shared/20261022-70,
-- which owns that column and its CHECK. cp_app_tier_configs.min_units and
-- cp_price_list_changes.old/new_min_units come from shared/20261026-10; the
-- price-list-change kinds are owned by shared/20261023-30.
--
-- This file adds:
--
-- 1. core_platform.cp_app_tier_meter_prices: one price per (tier config,
--    meter). cp_app_tier_configs.price stays the ROOM price, so everything
--    that reads one price still has something sensible.
-- 2. cp_apps.volume_threshold / volume_discount: the ONE place the volume
--    rule lives (50 rooms, 25% off the rooms beyond). The console edits it.
-- 3. cp_price_list_changes.meter_key and old/new volume columns, so the
--    history records meter prices (kind APP_METER) and the volume rule (kind
--    APP_VOLUME, config_id = the app id, subscription_id '*').
-- 4. core_platform.fn_hms_billable_meters(tenant, business, from, to): the
--    ONE counting rule, returning (rooms, beds, rentals, outlets) for ONE
--    business -- HMS rows carry bus_id, so each business's subscription
--    counts its own (there is no one-subscription-per-organisation rule as
--    ZelosHR has). The amount (meters x prices, volume, minimum) is worked
--    out in ONE place in the backend (billing_unit.meter_amount) and ONE
--    place in the console.
-- 5. The price decision, applied ONCE per database (decision_key
--    '2026-10-26-hms-per-unit', history rows, source MIGRATION). After that
--    the console owns the prices, the minimum and the volume rule: a re-run
--    never overwrites a later console edit.
--
-- Idempotent; safe to re-run on every deploy.
-- =====================================================================
BEGIN;

-- ----------------------------------------------------- 1. meter prices
CREATE TABLE IF NOT EXISTS core_platform.cp_app_tier_meter_prices (
    id              text PRIMARY KEY
                    DEFAULT ('tmp_' || replace(gen_random_uuid()::text, '-', '')),
    tier_config_id  text NOT NULL
                    REFERENCES core_platform.cp_app_tier_configs (id) ON DELETE CASCADE,
    meter_key       text NOT NULL,
    price           numeric(12,2) NOT NULL,
    is_active       boolean NOT NULL DEFAULT true,
    delete_status   text NOT NULL DEFAULT 'NOT_DELETED',
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text,
    udatetime       timestamptz,
    updated_by      text
);

-- The meters a price can be set for (HMS's four). The list lives here.
ALTER TABLE core_platform.cp_app_tier_meter_prices
    DROP CONSTRAINT IF EXISTS ck_cp_app_tier_meter_prices_meter_key;
ALTER TABLE core_platform.cp_app_tier_meter_prices
    ADD CONSTRAINT ck_cp_app_tier_meter_prices_meter_key
    CHECK (meter_key IN ('room', 'bed', 'rental', 'outlet'));
ALTER TABLE core_platform.cp_app_tier_meter_prices
    DROP CONSTRAINT IF EXISTS ck_cp_app_tier_meter_prices_price;
ALTER TABLE core_platform.cp_app_tier_meter_prices
    ADD CONSTRAINT ck_cp_app_tier_meter_prices_price CHECK (price >= 0);
ALTER TABLE core_platform.cp_app_tier_meter_prices
    DROP CONSTRAINT IF EXISTS ck_cp_app_tier_meter_prices_delete_status;
ALTER TABLE core_platform.cp_app_tier_meter_prices
    ADD CONSTRAINT ck_cp_app_tier_meter_prices_delete_status
    CHECK (delete_status IN ('PENDING', 'DELETED', 'NOT_DELETED'));
CREATE UNIQUE INDEX IF NOT EXISTS uq_cp_app_tier_meter_prices_tier_meter
    ON core_platform.cp_app_tier_meter_prices (tier_config_id, meter_key);

COMMENT ON TABLE core_platform.cp_app_tier_meter_prices IS
    'USD per month per counted item, per (tier config, meter), for an app billed per UNIT (HMS: room, bed, rental, outlet). cp_app_tier_configs.price stays the room price. Owned by the Deladetech console after shared/20261026-11 first set it; every change is recorded in cp_price_list_changes (kind APP_METER).';

-- ------------------------------------------------------ 2. volume rule
ALTER TABLE core_platform.cp_apps
    ADD COLUMN IF NOT EXISTS volume_threshold integer NULL;
ALTER TABLE core_platform.cp_apps
    ADD COLUMN IF NOT EXISTS volume_discount numeric(5,4) NULL;
ALTER TABLE core_platform.cp_apps DROP CONSTRAINT IF EXISTS ck_cp_apps_volume;
ALTER TABLE core_platform.cp_apps
    ADD CONSTRAINT ck_cp_apps_volume CHECK (
        (volume_threshold IS NULL AND volume_discount IS NULL)
        OR (volume_threshold > 0 AND volume_discount > 0 AND volume_discount < 1));

COMMENT ON COLUMN core_platform.cp_apps.volume_threshold IS
    'An app billed per UNIT: the room meter is charged at full price up to this many rooms a month, and at (1 - volume_discount) of it beyond. NULL = no volume rule. Owned by the Deladetech console after shared/20261026-11.';
COMMENT ON COLUMN core_platform.cp_apps.volume_discount IS
    'The share taken off the room price beyond volume_threshold rooms (0.25 = 25% off). NULL with volume_threshold.';

-- --------------------------------------------------------- 3. history
ALTER TABLE core_platform.cp_price_list_changes ADD COLUMN IF NOT EXISTS meter_key text;
ALTER TABLE core_platform.cp_price_list_changes ADD COLUMN IF NOT EXISTS old_volume_threshold integer;
ALTER TABLE core_platform.cp_price_list_changes ADD COLUMN IF NOT EXISTS new_volume_threshold integer;
ALTER TABLE core_platform.cp_price_list_changes ADD COLUMN IF NOT EXISTS old_volume_discount numeric(5,4);
ALTER TABLE core_platform.cp_price_list_changes ADD COLUMN IF NOT EXISTS new_volume_discount numeric(5,4);

-- ------------------------------------------------- 4. what is counted
-- plpgsql with dynamic SQL, so it creates (and answers zeros) on a database
-- that has no hms schema, and works whether or not profiles exist yet.
--
-- For (tenant, business) over [p_from, p_to], a unit or property counts when
-- it existed during the period: created on or before p_to and not archived
-- before p_from. A unit's property must have existed during the period too:
-- deleting an HMS profile archives its properties but leaves their units as
-- they are, and those units cannot be used any more.
--
--   rooms    units with usage 'stay' whose unit type's category is anything
--            but a bed: room, suite, apartment, studio, house, shop, office,
--            hall, other -- and any category not listed here (unknown = room);
--   beds     units with usage 'stay' whose unit type's category is 'bed'
--            (the only bed category hms_unit_types allows today; 'dorm',
--            'dormitory' and 'bunk' are mapped to bed too, should they come);
--   rentals  units with usage 'rental' (flats, houses, shops on a lease),
--            whatever their category;
--   outlets  properties of the business whose profile has the restaurant
--            module switched on -- what the HMS app itself shows
--            (tvs-shared-apps-bk hms/profiles.go, withProfile): the modules of
--            the property's profile, else of the business's default profile
--            (is_default) when it has none, else of the business's
--            hms_settings (the first profile is created from it and kept in
--            step with it). The module covers restaurants, bars and cafes
--            alike ("Restaurant, bar or cafe").
CREATE OR REPLACE FUNCTION core_platform.fn_hms_billable_meters(
    p_tenant_id text, p_bus_id text, p_from date, p_to date)
RETURNS TABLE (rooms integer, beds integer, rentals integer, outlets integer)
LANGUAGE plpgsql STABLE AS $fn$
DECLARE
    modules_of text;
BEGIN
    rooms := 0; beds := 0; rentals := 0; outlets := 0;
    IF to_regclass('hms.hms_units') IS NULL OR to_regclass('hms.hms_properties') IS NULL
       OR to_regclass('hms.hms_unit_types') IS NULL
       OR p_tenant_id IS NULL OR p_bus_id IS NULL OR p_from IS NULL OR p_to IS NULL THEN
        RETURN NEXT;
        RETURN;
    END IF;

    EXECUTE $q$
        SELECT count(*) FILTER (WHERE u.usage = 'stay' AND NOT c.is_bed)::integer,
               count(*) FILTER (WHERE u.usage = 'stay' AND c.is_bed)::integer,
               count(*) FILTER (WHERE u.usage = 'rental')::integer
          FROM hms.hms_units u
          JOIN hms.hms_properties pr
            ON pr.id = u.property_id AND pr.tenant_id = u.tenant_id
          LEFT JOIN hms.hms_unit_types t ON t.id = u.unit_type_id
          CROSS JOIN LATERAL (SELECT lower(COALESCE(t.category, ''))
                                     IN ('bed', 'dorm', 'dormitory', 'bunk') AS is_bed) c
         WHERE u.tenant_id = $1
           AND u.bus_id = $2
           AND u.cdatetime::date <= $4
           AND (u.archived_at IS NULL OR u.archived_at::date >= $3)
           AND pr.cdatetime::date <= $4
           AND (pr.archived_at IS NULL OR pr.archived_at::date >= $3)
    $q$
    INTO rooms, beds, rentals
    USING p_tenant_id, p_bus_id, p_from, p_to;

    -- (hms_properties.profile_id arrives with hms_profiles, shared/20261023-62,
    -- so the profile lookups are only written when that table exists.)
    modules_of := 'COALESCE('
        || CASE WHEN to_regclass('hms.hms_profiles') IS NOT NULL THEN
               '(SELECT p.modules FROM hms.hms_profiles p WHERE p.id = pr.profile_id AND p.tenant_id = pr.tenant_id), '
            || '(SELECT d.modules FROM hms.hms_profiles d WHERE d.bus_id = pr.bus_id AND d.tenant_id = pr.tenant_id AND d.is_default LIMIT 1), '
           ELSE '' END
        || CASE WHEN to_regclass('hms.hms_settings') IS NOT NULL THEN
               '(SELECT st.modules FROM hms.hms_settings st WHERE st.bus_id = pr.bus_id AND st.tenant_id = pr.tenant_id), '
           ELSE '' END
        || '''{}''::text[])';

    EXECUTE format($q$
        SELECT count(*)::integer
          FROM hms.hms_properties pr
         WHERE pr.tenant_id = $1
           AND pr.bus_id = $2
           AND pr.cdatetime::date <= $4
           AND (pr.archived_at IS NULL OR pr.archived_at::date >= $3)
           AND 'restaurant' = ANY(%s)
    $q$, modules_of)
    INTO outlets
    USING p_tenant_id, p_bus_id, p_from, p_to;

    rooms := COALESCE(rooms, 0); beds := COALESCE(beds, 0);
    rentals := COALESCE(rentals, 0); outlets := COALESCE(outlets, 0);
    RETURN NEXT;
END
$fn$;

COMMENT ON FUNCTION core_platform.fn_hms_billable_meters(text, text, date, date) IS
    'What HMS bills (tenant, business) for over [from, to]: rooms and beds (stay units, told apart by unit type category: bed/dorm/dormitory/bunk = bed, anything else = room), rentals (usage rental) and outlets (properties whose profile runs the restaurant module), each counted when it existed in the period. The one counting rule behind per-unit billing (shared/20261026-11).';

-- Granted like fn_zeloshr_billable_employees: callable by every role, and
-- SECURITY INVOKER, so it reads only what the caller may read.
GRANT EXECUTE ON FUNCTION core_platform.fn_hms_billable_meters(text, text, date, date) TO PUBLIC;

-- --------------------------------- 5. the 2026-10-26 decision, once
DO $$
DECLARE
    applied int := 0;
    meters int := 0;
BEGIN
    IF EXISTS (SELECT 1 FROM core_platform.cp_price_list_changes
                WHERE decision_key = '2026-10-26-hms-per-unit') THEN
        RAISE NOTICE '20261026-11: the 2026-10-26 HMS prices were applied here already; the console owns them now';
        RETURN;
    END IF;

    -- The tiers: the room price is cp_app_tier_configs.price. price NULL =
    -- leave it as it is (Enterprise is a quote).
    CREATE TEMP TABLE _hms_prices (id text PRIMARY KEY, price numeric, min_units integer)
        ON COMMIT DROP;
    INSERT INTO _hms_prices VALUES
        ('tier-cfg-hms-basic',      2.00, 10),
        ('tier-cfg-hms-advance',    3.50, 10),
        ('tier-cfg-hms-premium',    5.50, 10),
        ('tier-cfg-hms-enterprise', NULL, 10);

    INSERT INTO core_platform.cp_price_list_changes
        (kind, config_id, app_id, subscription_id, old_price, new_price, old_rate, new_rate,
         old_max_login_users, new_max_login_users, old_min_units, new_min_units,
         reason, changed_by, source, decision_key)
    SELECT 'APP_TIER', c.id, c.app_id, c.subscription_id,
           c.price, COALESCE(v.price, c.price), c.rate, c.rate,
           c.max_login_users, c.max_login_users, c.min_units, v.min_units,
           'Owner decision 2026-10-26: HMS priced per room, bed, rental unit and outlet; minimum 10 rooms'' worth',
           'migration:20261026-11', 'MIGRATION', '2026-10-26-hms-per-unit'
      FROM core_platform.cp_app_tier_configs c
      JOIN _hms_prices v ON v.id = c.id;

    UPDATE core_platform.cp_app_tier_configs c
       SET price = COALESCE(v.price, c.price), min_units = v.min_units
      FROM _hms_prices v
     WHERE v.id = c.id
       AND (c.price, c.min_units) IS DISTINCT FROM (COALESCE(v.price, c.price), v.min_units);
    GET DIAGNOSTICS applied = ROW_COUNT;

    -- The four meters of each paid tier.
    CREATE TEMP TABLE _hms_meters (tier_config_id text, meter_key text, price numeric)
        ON COMMIT DROP;
    INSERT INTO _hms_meters VALUES
        ('tier-cfg-hms-basic',   'room',    2.00), ('tier-cfg-hms-basic',   'bed', 1.00),
        ('tier-cfg-hms-basic',   'rental',  1.00), ('tier-cfg-hms-basic',   'outlet', 15.00),
        ('tier-cfg-hms-advance', 'room',    3.50), ('tier-cfg-hms-advance', 'bed', 1.75),
        ('tier-cfg-hms-advance', 'rental',  1.50), ('tier-cfg-hms-advance', 'outlet', 25.00),
        ('tier-cfg-hms-premium', 'room',    5.50), ('tier-cfg-hms-premium', 'bed', 2.75),
        ('tier-cfg-hms-premium', 'rental',  2.00), ('tier-cfg-hms-premium', 'outlet', 40.00);

    INSERT INTO core_platform.cp_price_list_changes
        (kind, config_id, app_id, subscription_id, meter_key, old_price, new_price,
         reason, changed_by, source, decision_key)
    SELECT 'APP_METER', c.id, c.app_id, c.subscription_id, v.meter_key, mp.price, v.price,
           'Owner decision 2026-10-26: HMS meter price',
           'migration:20261026-11', 'MIGRATION', '2026-10-26-hms-per-unit'
      FROM _hms_meters v
      JOIN core_platform.cp_app_tier_configs c ON c.id = v.tier_config_id
      LEFT JOIN core_platform.cp_app_tier_meter_prices mp
             ON mp.tier_config_id = v.tier_config_id AND mp.meter_key = v.meter_key;

    INSERT INTO core_platform.cp_app_tier_meter_prices (tier_config_id, meter_key, price, created_by)
    SELECT v.tier_config_id, v.meter_key, v.price, 'migration:20261026-11'
      FROM _hms_meters v
      JOIN core_platform.cp_app_tier_configs c ON c.id = v.tier_config_id
    ON CONFLICT (tier_config_id, meter_key)
    DO UPDATE SET price = EXCLUDED.price, udatetime = now(), updated_by = EXCLUDED.created_by;
    GET DIAGNOSTICS meters = ROW_COUNT;

    -- The volume rule: rooms beyond 50 at 25% off.
    INSERT INTO core_platform.cp_price_list_changes
        (kind, config_id, app_id, subscription_id,
         old_volume_threshold, new_volume_threshold, old_volume_discount, new_volume_discount,
         reason, changed_by, source, decision_key)
    SELECT 'APP_VOLUME', a.id, a.id, '*',
           a.volume_threshold, 50, a.volume_discount, 0.25,
           'Owner decision 2026-10-26: HMS rooms beyond the first 50 cost 25% less',
           'migration:20261026-11', 'MIGRATION', '2026-10-26-hms-per-unit'
      FROM core_platform.cp_apps a WHERE a.id = 'app-hms';
    UPDATE core_platform.cp_apps
       SET volume_threshold = 50, volume_discount = 0.25
     WHERE id = 'app-hms';

    RAISE NOTICE '20261026-11: recorded the 2026-10-26 HMS prices (% tier row(s) changed, % meter price(s) set)', applied, meters;
END $$;

-- ----------------------------------------------------------- invariants
DO $$
DECLARE
    r record;
BEGIN
    -- The function answers on any database: zeros for a business with nothing.
    SELECT * INTO r FROM core_platform.fn_hms_billable_meters('-', '-', current_date, current_date);
    IF (r.rooms, r.beds, r.rentals, r.outlets) IS DISTINCT FROM (0, 0, 0, 0) THEN
        RAISE EXCEPTION 'fn_hms_billable_meters counted units of a tenant that does not exist';
    END IF;

    -- (No assertion over the prices: the console owns them after the
    -- decision, and a row seeded after it is legitimately untouched.)
END $$;

COMMIT;
