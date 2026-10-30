-- Manufacturing: the lists of maintenance (20261031-11). The lists live only here: to change one,
-- edit this file.
--
--   asset status            in_service | down | under_maintenance | retired
--   asset criticality       A | B | C (02 §8)
--   meter                   runtime_h | cycles | custom:<name> (lower case, digits, _; up to 40)
--                           (asset meter readings and meter PM plans)
--   failure-code kind       problem | cause | remedy
--   PM trigger              calendar | meter (condition is R4)
--   PM basis                due | completion
--   PM plan status          draft | active | paused
--   MWO type                preventive | corrective | inspection (predictive is R4)
--   MWO status              requested | approved | scheduled | in_progress | completed | closed | cancelled
--   MWO priority            low | medium | high | critical
--   task kind               check | value | photo
--   task result             pass | fail | na
--   parts kind              issue | return
--
-- Idempotent; safe to re-run.

BEGIN;

ALTER TABLE mfg.mfg_assets DROP CONSTRAINT IF EXISTS mfg_assets_status_check;
ALTER TABLE mfg.mfg_assets ADD CONSTRAINT mfg_assets_status_check CHECK (status IN
    ('in_service', 'down', 'under_maintenance', 'retired'));

ALTER TABLE mfg.mfg_assets DROP CONSTRAINT IF EXISTS mfg_assets_criticality_check;
ALTER TABLE mfg.mfg_assets ADD CONSTRAINT mfg_assets_criticality_check CHECK (criticality IN
    ('A', 'B', 'C'));

ALTER TABLE mfg.mfg_asset_meters DROP CONSTRAINT IF EXISTS mfg_asset_meters_meter_check;
ALTER TABLE mfg.mfg_asset_meters ADD CONSTRAINT mfg_asset_meters_meter_check CHECK (meter IN
    ('runtime_h', 'cycles') OR meter ~ '^custom:[a-z0-9_]{1,40}$');

ALTER TABLE mfg.mfg_failure_codes DROP CONSTRAINT IF EXISTS mfg_failure_codes_kind_check;
ALTER TABLE mfg.mfg_failure_codes ADD CONSTRAINT mfg_failure_codes_kind_check CHECK (kind IN
    ('problem', 'cause', 'remedy'));

ALTER TABLE mfg.mfg_pm_plans DROP CONSTRAINT IF EXISTS mfg_pm_plans_trigger_check;
ALTER TABLE mfg.mfg_pm_plans ADD CONSTRAINT mfg_pm_plans_trigger_check CHECK (trigger IN
    ('calendar', 'meter'));

ALTER TABLE mfg.mfg_pm_plans DROP CONSTRAINT IF EXISTS mfg_pm_plans_basis_check;
ALTER TABLE mfg.mfg_pm_plans ADD CONSTRAINT mfg_pm_plans_basis_check CHECK (basis IN
    ('due', 'completion'));

ALTER TABLE mfg.mfg_pm_plans DROP CONSTRAINT IF EXISTS mfg_pm_plans_meter_check;
ALTER TABLE mfg.mfg_pm_plans ADD CONSTRAINT mfg_pm_plans_meter_check CHECK (meter IN
    ('runtime_h', 'cycles') OR meter ~ '^custom:[a-z0-9_]{1,40}$');

ALTER TABLE mfg.mfg_pm_plans DROP CONSTRAINT IF EXISTS mfg_pm_plans_status_check;
ALTER TABLE mfg.mfg_pm_plans ADD CONSTRAINT mfg_pm_plans_status_check CHECK (status IN
    ('draft', 'active', 'paused'));

ALTER TABLE mfg.mfg_maintenance_orders DROP CONSTRAINT IF EXISTS mfg_maintenance_orders_type_check;
ALTER TABLE mfg.mfg_maintenance_orders ADD CONSTRAINT mfg_maintenance_orders_type_check CHECK (type IN
    ('preventive', 'corrective', 'inspection'));

ALTER TABLE mfg.mfg_maintenance_orders DROP CONSTRAINT IF EXISTS mfg_maintenance_orders_status_check;
ALTER TABLE mfg.mfg_maintenance_orders ADD CONSTRAINT mfg_maintenance_orders_status_check CHECK (status IN
    ('requested', 'approved', 'scheduled', 'in_progress', 'completed', 'closed', 'cancelled'));

ALTER TABLE mfg.mfg_maintenance_orders DROP CONSTRAINT IF EXISTS mfg_maintenance_orders_priority_check;
ALTER TABLE mfg.mfg_maintenance_orders ADD CONSTRAINT mfg_maintenance_orders_priority_check CHECK (priority IN
    ('low', 'medium', 'high', 'critical'));

ALTER TABLE mfg.mfg_maintenance_tasks DROP CONSTRAINT IF EXISTS mfg_maintenance_tasks_kind_check;
ALTER TABLE mfg.mfg_maintenance_tasks ADD CONSTRAINT mfg_maintenance_tasks_kind_check CHECK (kind IN
    ('check', 'value', 'photo'));

ALTER TABLE mfg.mfg_maintenance_tasks DROP CONSTRAINT IF EXISTS mfg_maintenance_tasks_result_check;
ALTER TABLE mfg.mfg_maintenance_tasks ADD CONSTRAINT mfg_maintenance_tasks_result_check CHECK (result IN
    ('pass', 'fail', 'na'));

ALTER TABLE mfg.mfg_maintenance_parts DROP CONSTRAINT IF EXISTS mfg_maintenance_parts_kind_check;
ALTER TABLE mfg.mfg_maintenance_parts ADD CONSTRAINT mfg_maintenance_parts_kind_check CHECK (kind IN
    ('issue', 'return'));

COMMIT;
