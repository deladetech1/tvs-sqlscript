-- Manufacturing: the lists of production and the shop floor (20261029-43), and of the shared
-- helpers (20261029-40). The lists live only here: to change one, edit this file.
--
--   order status          planned | firmed | released | in_progress | paused | completed | closed |
--                         cancelled (holds are flags, not states)
--   order mode            discrete | batch | repetitive | kanban (R-1). R1's API accepts discrete and
--                         batch only and answers 400 MODE_NOT_AVAILABLE for the others (A3)
--   readiness             green | amber | red | unknown, per signal, on orders and operations (R-3)
--   operation status      waiting | ready | setup | running | paused | done
--   confirmation kind     start | pause | resume | report | finish | reversal
--   downtime kind         open | close | reclassify;  downtime source  operator | iot | maintenance
--   genealogy             lot | serial;  link type  consume | split | merge | rework
--   floor request         kind quality_alert | maintenance_request; status open | acknowledged | closed;
--                         what it became: ncr (R2) | maintenance_order (R3)
--   costing method        standard | actual (mfg_settings)
--   custom field type     text | long_text | number | date | boolean | select | multi_select
--
-- Idempotent; safe to re-run.

BEGIN;

ALTER TABLE mfg.mfg_production_orders DROP CONSTRAINT IF EXISTS mfg_production_orders_status_check;
ALTER TABLE mfg.mfg_production_orders ADD CONSTRAINT mfg_production_orders_status_check CHECK (status IN
    ('planned', 'firmed', 'released', 'in_progress', 'paused', 'completed', 'closed', 'cancelled'));

ALTER TABLE mfg.mfg_production_orders DROP CONSTRAINT IF EXISTS mfg_production_orders_mode_check;
ALTER TABLE mfg.mfg_production_orders ADD CONSTRAINT mfg_production_orders_mode_check CHECK (mode IN
    ('discrete', 'batch', 'repetitive', 'kanban'));

ALTER TABLE mfg.mfg_production_orders DROP CONSTRAINT IF EXISTS mfg_production_orders_readiness_check;
ALTER TABLE mfg.mfg_production_orders ADD CONSTRAINT mfg_production_orders_readiness_check CHECK (
    ready_material    IN ('green', 'amber', 'red', 'unknown') AND
    ready_capacity    IN ('green', 'amber', 'red', 'unknown') AND
    ready_maintenance IN ('green', 'amber', 'red', 'unknown') AND
    ready_quality     IN ('green', 'amber', 'red', 'unknown'));
ALTER TABLE mfg.mfg_order_operations DROP CONSTRAINT IF EXISTS mfg_order_operations_readiness_check;
ALTER TABLE mfg.mfg_order_operations ADD CONSTRAINT mfg_order_operations_readiness_check CHECK (
    ready_material    IN ('green', 'amber', 'red', 'unknown') AND
    ready_capacity    IN ('green', 'amber', 'red', 'unknown') AND
    ready_maintenance IN ('green', 'amber', 'red', 'unknown') AND
    ready_quality     IN ('green', 'amber', 'red', 'unknown'));

ALTER TABLE mfg.mfg_order_operations DROP CONSTRAINT IF EXISTS mfg_order_operations_status_check;
ALTER TABLE mfg.mfg_order_operations ADD CONSTRAINT mfg_order_operations_status_check CHECK (status IN
    ('waiting', 'ready', 'setup', 'running', 'paused', 'done'));

ALTER TABLE mfg.mfg_confirmations DROP CONSTRAINT IF EXISTS mfg_confirmations_kind_check;
ALTER TABLE mfg.mfg_confirmations ADD CONSTRAINT mfg_confirmations_kind_check CHECK (kind IN
    ('start', 'pause', 'resume', 'report', 'finish', 'reversal'));

ALTER TABLE mfg.mfg_downtime_events DROP CONSTRAINT IF EXISTS mfg_downtime_events_kind_check;
ALTER TABLE mfg.mfg_downtime_events ADD CONSTRAINT mfg_downtime_events_kind_check CHECK (kind IN
    ('open', 'close', 'reclassify'));
ALTER TABLE mfg.mfg_downtime_events DROP CONSTRAINT IF EXISTS mfg_downtime_events_source_check;
ALTER TABLE mfg.mfg_downtime_events ADD CONSTRAINT mfg_downtime_events_source_check CHECK (source IN
    ('operator', 'iot', 'maintenance'));
ALTER TABLE mfg.mfg_downtime_current DROP CONSTRAINT IF EXISTS mfg_downtime_current_source_check;
ALTER TABLE mfg.mfg_downtime_current ADD CONSTRAINT mfg_downtime_current_source_check CHECK (source IN
    ('operator', 'iot', 'maintenance'));

ALTER TABLE mfg.mfg_genealogy_links DROP CONSTRAINT IF EXISTS mfg_genealogy_links_kind_check;
ALTER TABLE mfg.mfg_genealogy_links ADD CONSTRAINT mfg_genealogy_links_kind_check CHECK (
    parent_kind IN ('lot', 'serial') AND child_kind IN ('lot', 'serial'));
ALTER TABLE mfg.mfg_genealogy_links DROP CONSTRAINT IF EXISTS mfg_genealogy_links_link_type_check;
ALTER TABLE mfg.mfg_genealogy_links ADD CONSTRAINT mfg_genealogy_links_link_type_check CHECK (link_type IN
    ('consume', 'split', 'merge', 'rework'));

ALTER TABLE mfg.mfg_floor_requests DROP CONSTRAINT IF EXISTS mfg_floor_requests_kind_check;
ALTER TABLE mfg.mfg_floor_requests ADD CONSTRAINT mfg_floor_requests_kind_check CHECK (kind IN
    ('quality_alert', 'maintenance_request'));
ALTER TABLE mfg.mfg_floor_requests DROP CONSTRAINT IF EXISTS mfg_floor_requests_status_check;
ALTER TABLE mfg.mfg_floor_requests ADD CONSTRAINT mfg_floor_requests_status_check CHECK (status IN
    ('open', 'acknowledged', 'closed'));
ALTER TABLE mfg.mfg_floor_requests DROP CONSTRAINT IF EXISTS mfg_floor_requests_became_type_check;
ALTER TABLE mfg.mfg_floor_requests ADD CONSTRAINT mfg_floor_requests_became_type_check CHECK (became_type IN
    ('ncr', 'maintenance_order'));

ALTER TABLE mfg.mfg_settings DROP CONSTRAINT IF EXISTS mfg_settings_costing_method_check;
ALTER TABLE mfg.mfg_settings ADD CONSTRAINT mfg_settings_costing_method_check CHECK (costing_method IN
    ('standard', 'actual'));

ALTER TABLE mfg.mfg_custom_fields DROP CONSTRAINT IF EXISTS mfg_custom_fields_type_check;
ALTER TABLE mfg.mfg_custom_fields ADD CONSTRAINT mfg_custom_fields_type_check CHECK (type IN
    ('text', 'long_text', 'number', 'date', 'boolean', 'select', 'multi_select'));

COMMIT;
