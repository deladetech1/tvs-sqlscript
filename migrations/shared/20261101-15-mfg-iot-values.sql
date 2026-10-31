-- Manufacturing: the lists of machine connectivity (20261101-12). The lists live only here: to change
-- one, edit this file.
--
--   device status           active | revoked
--   signal map kind         meter | state | count | measure
--   signal map meter        runtime_h | cycles | custom:<name> (R3's meter list, 20261031-18)
--   meter mode              cumulative | delta
--   count kind              good | scrap
--   IoT resource state      run | idle | down | unknown
--   reading fact status     applied | skipped | unmapped | failed
--   anomaly status          open | cleared
--   anomaly direction       high | low
--   asset meter source      manual | iot (R3's mfg_asset_meters)
--
-- Idempotent; safe to re-run.

BEGIN;

ALTER TABLE mfg.mfg_iot_devices DROP CONSTRAINT IF EXISTS mfg_iot_devices_status_check;
ALTER TABLE mfg.mfg_iot_devices ADD CONSTRAINT mfg_iot_devices_status_check CHECK (status IN
    ('active', 'revoked'));

ALTER TABLE mfg.mfg_iot_signal_maps DROP CONSTRAINT IF EXISTS mfg_iot_signal_maps_kind_check;
ALTER TABLE mfg.mfg_iot_signal_maps ADD CONSTRAINT mfg_iot_signal_maps_kind_check CHECK (kind IN
    ('meter', 'state', 'count', 'measure'));

ALTER TABLE mfg.mfg_iot_signal_maps DROP CONSTRAINT IF EXISTS mfg_iot_signal_maps_meter_check;
ALTER TABLE mfg.mfg_iot_signal_maps ADD CONSTRAINT mfg_iot_signal_maps_meter_check CHECK (meter IN
    ('runtime_h', 'cycles') OR meter ~ '^custom:[a-z0-9_]{1,40}$');

ALTER TABLE mfg.mfg_iot_signal_maps DROP CONSTRAINT IF EXISTS mfg_iot_signal_maps_meter_mode_check;
ALTER TABLE mfg.mfg_iot_signal_maps ADD CONSTRAINT mfg_iot_signal_maps_meter_mode_check CHECK (meter_mode IN
    ('cumulative', 'delta'));

ALTER TABLE mfg.mfg_iot_signal_maps DROP CONSTRAINT IF EXISTS mfg_iot_signal_maps_count_kind_check;
ALTER TABLE mfg.mfg_iot_signal_maps ADD CONSTRAINT mfg_iot_signal_maps_count_kind_check CHECK (count_kind IN
    ('good', 'scrap'));

ALTER TABLE mfg.mfg_iot_resource_state DROP CONSTRAINT IF EXISTS mfg_iot_resource_state_state_check;
ALTER TABLE mfg.mfg_iot_resource_state ADD CONSTRAINT mfg_iot_resource_state_state_check CHECK (state IN
    ('run', 'idle', 'down', 'unknown'));

ALTER TABLE mfg.mfg_iot_readings DROP CONSTRAINT IF EXISTS mfg_iot_readings_fact_status_check;
ALTER TABLE mfg.mfg_iot_readings ADD CONSTRAINT mfg_iot_readings_fact_status_check CHECK (fact_status IN
    ('applied', 'skipped', 'unmapped', 'failed'));

ALTER TABLE mfg.mfg_anomalies DROP CONSTRAINT IF EXISTS mfg_anomalies_status_check;
ALTER TABLE mfg.mfg_anomalies ADD CONSTRAINT mfg_anomalies_status_check CHECK (status IN
    ('open', 'cleared'));

ALTER TABLE mfg.mfg_anomalies DROP CONSTRAINT IF EXISTS mfg_anomalies_direction_check;
ALTER TABLE mfg.mfg_anomalies ADD CONSTRAINT mfg_anomalies_direction_check CHECK (direction IN
    ('high', 'low'));

ALTER TABLE mfg.mfg_asset_meters DROP CONSTRAINT IF EXISTS mfg_asset_meters_source_check;
ALTER TABLE mfg.mfg_asset_meters ADD CONSTRAINT mfg_asset_meters_source_check CHECK (source IN
    ('manual', 'iot'));

COMMIT;
