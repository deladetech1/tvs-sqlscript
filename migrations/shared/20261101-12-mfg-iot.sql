-- Manufacturing: machine connectivity, anomaly baselines and condition-based maintenance (design:
-- docs/mfg/01-architecture.md §5; 02-domain-model.md §8, §12; 03-database-model.md §3.5 IoT and
-- Insight; contract R4a.md E5-E10, E22, E24 (2), (3), (6)).
--
--   mfg_iot_devices          a device of a plant: code (unique per plant), name, active | revoked;
--                            its key mfgd_<key_id>_<secret>: key_id (12 characters, unique in the
--                            database: ingest finds the device by it) and only the SHA-256 of the
--                            secret (key_hash); after a rotation the old hash keeps working until
--                            prev_key_expires_at (24 h). heartbeat_sec 60..3600; online,
--                            last_seen_at, offline_since; contiguous_seq (every seq up to it is
--                            stored) and max_seq; the rate window (rate_window_start, rate_count:
--                            6,000 events a minute). The row is locked FOR UPDATE per batch
--   mfg_iot_signal_maps      how a device's signal becomes a fact: meter (an asset's meter,
--                            cumulative | delta, min_step, scale), state (value_map raw -> run |
--                            idle | down, down_reason_code_id), count (good | scrap) or measure;
--                            anomaly {enabled, window, threshold, consecutive, min_samples} on
--                            measure and count maps. One active map per device and signal; one
--                            active state map per resource. last_value/last_at: the running meter
--                            value (delta maps add to it) and the last reading applied
--   mfg_iot_readings         the edge-reduced readings, UNIQUE (device_id, seq): num_value or
--                            text_value, the map it went through and what the fact did
--                            (fact_status applied | skipped | unmapped | failed, fact_note). UPDATE
--                            is refused (mfg_refuse_change): the fact's result is written with the
--                            row. DELETE is the retention job's (35 days). Not partitioned (E22)
--   mfg_iot_resource_state   per mapped resource: run | idle | down | unknown, since, last_at, the
--                            device and map, and the downtime IoT opened (downtime_id)
--   mfg_iot_baselines        per measure/count map: an exponentially weighted mean and variance (n,
--                            mean, var), the last value, and the breach / normal run counters
--   mfg_anomalies            a reading run far outside its baseline: direction high | low,
--                            observed, mean, sd, z, peak_z, the one-line explanation; open |
--                            cleared, one open per map
--   mfg_asset_meters         (R3) gains source manual | iot (default manual) and device_id
--   mfg_pm_plans             (R3) gains condition {signal_map_id, op, value, sustain_min} or
--                            {signal_map_id, on: anomaly}, condition_since, condition_armed
--
-- downtime_id names a mfg_downtime_events row (partitioned, so no foreign key). Readings carry no
-- uuid: a bigint identity keeps the busiest table small. No product or party column. The CHECK
-- lists live in 20261101-15 (and the PM trigger in 20261031-18). No grants. Idempotent; safe to
-- re-run.

BEGIN;

-- ========================================================================== devices
CREATE TABLE IF NOT EXISTS mfg.mfg_iot_devices (
    id                   text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id            text NOT NULL,
    org_id               text,
    bus_id               text NOT NULL,
    plant_id             text NOT NULL REFERENCES mfg.mfg_plants (id),
    code                 text NOT NULL,
    name                 text NOT NULL,
    description          text,
    status               text NOT NULL DEFAULT 'active',
    key_id               text NOT NULL,              -- the 12-character id in mfgd_<key_id>_<secret>
    key_hash             text NOT NULL,              -- SHA-256 of the secret (hex); the key is shown once
    prev_key_hash        text,                       -- the key before the last rotation ...
    prev_key_expires_at  timestamptz,                -- ... valid until then (24 h)
    key_rotated_at       timestamptz,
    heartbeat_sec        integer NOT NULL DEFAULT 300,
    online               boolean NOT NULL DEFAULT false,
    last_seen_at         timestamptz,
    offline_since        timestamptz,
    contiguous_seq       bigint NOT NULL DEFAULT 0,
    max_seq              bigint NOT NULL DEFAULT 0,
    rate_window_start    timestamptz,
    rate_count           integer NOT NULL DEFAULT 0,
    revoked_at           timestamptz,
    revoked_by           text,
    revoked_reason       text,
    version              integer NOT NULL DEFAULT 1,
    cdatetime            timestamptz NOT NULL DEFAULT now(),
    created_by           text,
    updated_at           timestamptz NOT NULL DEFAULT now(),
    updated_by           text
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_iot_devices_key_uq ON mfg.mfg_iot_devices (key_id);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_iot_devices_code_uq ON mfg.mfg_iot_devices (plant_id, code);
CREATE INDEX IF NOT EXISTS mfg_iot_devices_list_idx ON mfg.mfg_iot_devices (bus_id, plant_id, status);
-- iotWatch: active devices that are online, by when they were last seen.
CREATE INDEX IF NOT EXISTS mfg_iot_devices_watch_idx ON mfg.mfg_iot_devices (bus_id, last_seen_at) WHERE status = 'active' AND online;
ALTER TABLE mfg.mfg_iot_devices DROP CONSTRAINT IF EXISTS mfg_iot_devices_rules_check;
ALTER TABLE mfg.mfg_iot_devices ADD CONSTRAINT mfg_iot_devices_rules_check
    CHECK (btrim(code) <> '' AND btrim(name) <> ''
           AND length(key_id) = 12 AND key_hash <> ''
           AND ((prev_key_hash IS NULL) = (prev_key_expires_at IS NULL))
           AND heartbeat_sec BETWEEN 60 AND 3600
           AND contiguous_seq >= 0 AND max_seq >= contiguous_seq
           AND rate_count >= 0
           AND (status <> 'revoked' OR revoked_at IS NOT NULL));

-- ====================================================================== signal maps
CREATE TABLE IF NOT EXISTS mfg.mfg_iot_signal_maps (
    id                   text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id            text NOT NULL,
    org_id               text,
    bus_id               text NOT NULL,
    plant_id             text NOT NULL REFERENCES mfg.mfg_plants (id),   -- the device's
    device_id            text NOT NULL REFERENCES mfg.mfg_iot_devices (id),
    signal               text NOT NULL,
    kind                 text NOT NULL,              -- meter | state | count | measure
    resource_id          text REFERENCES mfg.mfg_resources (id),
    asset_id             text REFERENCES mfg.mfg_assets (id),
    meter                text,                       -- meter: R3's list (runtime_h | cycles | custom:<name>)
    meter_mode           text,                       -- meter: cumulative | delta
    min_step             numeric(18,3) NOT NULL DEFAULT 1,
    value_map            jsonb NOT NULL DEFAULT '{}', -- state: {"<raw value as text>": "run" | "idle" | "down"}
    down_reason_code_id  text REFERENCES mfg.mfg_reason_codes (id),       -- state: required
    count_kind           text,                       -- count: good | scrap
    unit                 text,
    scale                numeric(18,6) NOT NULL DEFAULT 1,
    anomaly              jsonb NOT NULL DEFAULT '{}', -- {enabled, window, threshold, consecutive, min_samples}
    last_value           numeric(18,3),              -- meter: the running reading (delta adds to it)
    last_at              timestamptz,                -- the last reading this map applied
    archived_at          timestamptz,
    version              integer NOT NULL DEFAULT 1,
    cdatetime            timestamptz NOT NULL DEFAULT now(),
    created_by           text,
    updated_at           timestamptz NOT NULL DEFAULT now(),
    updated_by           text
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_iot_signal_maps_signal_uq
    ON mfg.mfg_iot_signal_maps (device_id, signal) WHERE archived_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS mfg_iot_signal_maps_state_uq
    ON mfg.mfg_iot_signal_maps (resource_id) WHERE kind = 'state' AND archived_at IS NULL;
CREATE INDEX IF NOT EXISTS mfg_iot_signal_maps_list_idx ON mfg.mfg_iot_signal_maps (bus_id, plant_id, kind) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS mfg_iot_signal_maps_resource_idx ON mfg.mfg_iot_signal_maps (resource_id) WHERE resource_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS mfg_iot_signal_maps_asset_idx ON mfg.mfg_iot_signal_maps (asset_id) WHERE asset_id IS NOT NULL;
ALTER TABLE mfg.mfg_iot_signal_maps DROP CONSTRAINT IF EXISTS mfg_iot_signal_maps_rules_check;
ALTER TABLE mfg.mfg_iot_signal_maps ADD CONSTRAINT mfg_iot_signal_maps_rules_check
    CHECK (signal ~ '^[a-z0-9_.:-]{1,64}$'
           AND min_step > 0 AND scale <> 0
           AND jsonb_typeof(value_map) = 'object' AND jsonb_typeof(anomaly) = 'object'
           AND (kind <> 'meter' OR (asset_id IS NOT NULL AND meter IS NOT NULL AND meter_mode IS NOT NULL))
           AND (kind <> 'state' OR (resource_id IS NOT NULL AND down_reason_code_id IS NOT NULL))
           AND (kind <> 'count' OR count_kind IS NOT NULL)
           AND (kind IN ('measure', 'count') OR anomaly->>'enabled' IS DISTINCT FROM 'true'));

-- ========================================================================= readings
CREATE TABLE IF NOT EXISTS mfg.mfg_iot_readings (
    id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    device_id         text NOT NULL REFERENCES mfg.mfg_iot_devices (id),
    seq               bigint NOT NULL,
    at                timestamptz NOT NULL,       -- the device's time of the event
    signal            text NOT NULL,
    num_value         double precision,
    text_value        text,
    map_id            text REFERENCES mfg.mfg_iot_signal_maps (id),
    fact_status       text NOT NULL DEFAULT 'unmapped',
    fact_note         text,                       -- e.g. "meter went backwards"
    received_at       timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_iot_readings_seq_uq ON mfg.mfg_iot_readings (device_id, seq);
CREATE INDEX IF NOT EXISTS mfg_iot_readings_signal_idx ON mfg.mfg_iot_readings (device_id, signal, at);
CREATE INDEX IF NOT EXISTS mfg_iot_readings_map_idx ON mfg.mfg_iot_readings (map_id, at DESC) WHERE map_id IS NOT NULL;
-- mfg-iot-retention: readings older than 35 days, per business.
CREATE INDEX IF NOT EXISTS mfg_iot_readings_retention_idx ON mfg.mfg_iot_readings (bus_id, at);
ALTER TABLE mfg.mfg_iot_readings DROP CONSTRAINT IF EXISTS mfg_iot_readings_rules_check;
ALTER TABLE mfg.mfg_iot_readings ADD CONSTRAINT mfg_iot_readings_rules_check
    CHECK (seq >= 1
           AND signal ~ '^[a-z0-9_.:-]{1,64}$'
           AND (num_value IS NOT NULL OR text_value IS NOT NULL)
           AND (text_value IS NULL OR length(text_value) <= 64));

DROP TRIGGER IF EXISTS mfg_iot_readings_no_update ON mfg.mfg_iot_readings;
CREATE TRIGGER mfg_iot_readings_no_update BEFORE UPDATE ON mfg.mfg_iot_readings
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_refuse_change();

-- =================================================================== resource state
CREATE TABLE IF NOT EXISTS mfg.mfg_iot_resource_state (
    resource_id       text PRIMARY KEY REFERENCES mfg.mfg_resources (id),
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    plant_id          text NOT NULL REFERENCES mfg.mfg_plants (id),
    state             text NOT NULL,              -- run | idle | down | unknown
    since             timestamptz NOT NULL,       -- when it entered this state
    last_at           timestamptz,                -- the newest state reading (older events are skipped)
    device_id         text REFERENCES mfg.mfg_iot_devices (id),
    map_id            text REFERENCES mfg.mfg_iot_signal_maps (id),
    downtime_id       text,                       -- the stop IoT opened and may close
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS mfg_iot_resource_state_plant_idx ON mfg.mfg_iot_resource_state (bus_id, plant_id);
CREATE INDEX IF NOT EXISTS mfg_iot_resource_state_device_idx ON mfg.mfg_iot_resource_state (device_id) WHERE device_id IS NOT NULL;

-- ======================================================================== baselines
CREATE TABLE IF NOT EXISTS mfg.mfg_iot_baselines (
    map_id            text PRIMARY KEY REFERENCES mfg.mfg_iot_signal_maps (id) ON DELETE CASCADE,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    n                 bigint NOT NULL DEFAULT 0,  -- normal readings folded in
    mean              double precision,
    var               double precision,
    last_value        double precision,
    last_at           timestamptz,
    breach_count      integer NOT NULL DEFAULT 0, -- consecutive readings with |z| >= threshold
    normal_count      integer NOT NULL DEFAULT 0, -- consecutive readings with |z| < threshold / 2
    reset_at          timestamptz,
    reset_by          text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE mfg.mfg_iot_baselines DROP CONSTRAINT IF EXISTS mfg_iot_baselines_rules_check;
ALTER TABLE mfg.mfg_iot_baselines ADD CONSTRAINT mfg_iot_baselines_rules_check
    CHECK (n >= 0 AND (var IS NULL OR var >= 0) AND breach_count >= 0 AND normal_count >= 0
           AND (n = 0 OR mean IS NOT NULL));

-- ======================================================================== anomalies
CREATE TABLE IF NOT EXISTS mfg.mfg_anomalies (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    plant_id          text NOT NULL REFERENCES mfg.mfg_plants (id),
    map_id            text NOT NULL REFERENCES mfg.mfg_iot_signal_maps (id),
    device_id         text NOT NULL REFERENCES mfg.mfg_iot_devices (id),
    resource_id       text REFERENCES mfg.mfg_resources (id),
    asset_id          text REFERENCES mfg.mfg_assets (id),
    signal            text NOT NULL,
    direction         text NOT NULL,              -- high | low
    opened_at         timestamptz NOT NULL,
    observed          double precision NOT NULL,
    mean              double precision NOT NULL,
    sd                double precision NOT NULL,
    z                 double precision NOT NULL,
    peak_z            double precision NOT NULL,  -- the largest |z| while open
    explanation       text NOT NULL,
    status            text NOT NULL DEFAULT 'open',
    cleared_at        timestamptz,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_anomalies_open_uq ON mfg.mfg_anomalies (map_id) WHERE status = 'open';
CREATE INDEX IF NOT EXISTS mfg_anomalies_list_idx ON mfg.mfg_anomalies (bus_id, status, opened_at DESC);
CREATE INDEX IF NOT EXISTS mfg_anomalies_resource_idx ON mfg.mfg_anomalies (resource_id, opened_at DESC) WHERE resource_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS mfg_anomalies_asset_idx ON mfg.mfg_anomalies (asset_id, opened_at DESC) WHERE asset_id IS NOT NULL;
ALTER TABLE mfg.mfg_anomalies DROP CONSTRAINT IF EXISTS mfg_anomalies_rules_check;
ALTER TABLE mfg.mfg_anomalies ADD CONSTRAINT mfg_anomalies_rules_check
    CHECK (sd >= 0 AND btrim(explanation) <> ''
           AND ((status = 'cleared') = (cleared_at IS NOT NULL))
           AND (cleared_at IS NULL OR cleared_at >= opened_at));

-- ======================================================== asset meters (R3): source
ALTER TABLE mfg.mfg_asset_meters ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'manual';
ALTER TABLE mfg.mfg_asset_meters ADD COLUMN IF NOT EXISTS device_id text;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'mfg_asset_meters_device_fk'
                      AND conrelid = 'mfg.mfg_asset_meters'::regclass) THEN
        ALTER TABLE mfg.mfg_asset_meters ADD CONSTRAINT mfg_asset_meters_device_fk
            FOREIGN KEY (device_id) REFERENCES mfg.mfg_iot_devices (id);
    END IF;
END $$;
ALTER TABLE mfg.mfg_asset_meters DROP CONSTRAINT IF EXISTS mfg_asset_meters_iot_rules_check;
ALTER TABLE mfg.mfg_asset_meters ADD CONSTRAINT mfg_asset_meters_iot_rules_check
    CHECK ((source = 'iot') = (device_id IS NOT NULL));
CREATE INDEX IF NOT EXISTS mfg_asset_meters_device_idx ON mfg.mfg_asset_meters (device_id) WHERE device_id IS NOT NULL;

-- ========================================================= PM plans (R3): condition
ALTER TABLE mfg.mfg_pm_plans ADD COLUMN IF NOT EXISTS condition jsonb;
ALTER TABLE mfg.mfg_pm_plans ADD COLUMN IF NOT EXISTS condition_since timestamptz;
ALTER TABLE mfg.mfg_pm_plans ADD COLUMN IF NOT EXISTS condition_armed boolean NOT NULL DEFAULT true;
ALTER TABLE mfg.mfg_pm_plans DROP CONSTRAINT IF EXISTS mfg_pm_plans_condition_rules_check;
ALTER TABLE mfg.mfg_pm_plans ADD CONSTRAINT mfg_pm_plans_condition_rules_check
    CHECK ((trigger = 'condition') = (condition IS NOT NULL)
           AND (condition IS NULL OR (jsonb_typeof(condition) = 'object'
                                      AND nullif(condition->>'signal_map_id', '') IS NOT NULL)));
-- Ingest evaluates the active condition plans of the map a reading went through.
CREATE INDEX IF NOT EXISTS mfg_pm_plans_condition_idx
    ON mfg.mfg_pm_plans ((condition->>'signal_map_id')) WHERE trigger = 'condition' AND status = 'active';

-- ===================================================================== invariants
DO $$
DECLARE t text;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                    WHERE g.tgrelid = 'mfg.mfg_iot_readings'::regclass AND p.proname = 'mfg_refuse_change' AND NOT g.tgisinternal) THEN
        RAISE EXCEPTION 'mfg.mfg_iot_readings accepts UPDATE: its mfg_refuse_change trigger is missing';
    END IF;
    FOREACH t IN ARRAY ARRAY['mfg_iot_devices_key_uq', 'mfg_iot_devices_code_uq', 'mfg_iot_signal_maps_signal_uq',
                             'mfg_iot_signal_maps_state_uq', 'mfg_iot_readings_seq_uq', 'mfg_anomalies_open_uq'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'mfg' AND indexname = t) THEN
            RAISE EXCEPTION 'mfg unique index % is missing', t;
        END IF;
    END LOOP;
    -- A signal map sits in its device's plant and business (the API checks; noticed, not refused).
    IF EXISTS (SELECT 1 FROM mfg.mfg_iot_signal_maps m JOIN mfg.mfg_iot_devices d ON d.id = m.device_id
                WHERE m.plant_id <> d.plant_id OR m.bus_id <> d.bus_id) THEN
        RAISE NOTICE 'some Manufacturing signal maps are in a different plant or business from their device';
    END IF;
END $$;

COMMIT;
