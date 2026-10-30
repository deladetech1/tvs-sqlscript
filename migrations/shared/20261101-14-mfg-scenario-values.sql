-- Manufacturing: the lists of scenarios (20261101-11). The lists live only here: to change one, edit
-- this file.
--
--   scenario status         draft | ready | applied | archived
--   change kind             demand_qty | demand_date | demand_new | demand_pct | extra_shift |
--                           resource_down | order_priority | order_due | item_param | buy_delay (E1)
--   run status              completed | failed
--   outcome metric          late_orders | days_late | max_days_late | unplaceable_ops |
--                           overload_buckets | overload_min | scheduled_load_min | shortage_items |
--                           planned_buys | planned_buy_value | planned_makes | planned_make_min |
--                           mrp_messages (E3)
--
-- Idempotent; safe to re-run.

BEGIN;

ALTER TABLE mfg.mfg_scenarios DROP CONSTRAINT IF EXISTS mfg_scenarios_status_check;
ALTER TABLE mfg.mfg_scenarios ADD CONSTRAINT mfg_scenarios_status_check CHECK (status IN
    ('draft', 'ready', 'applied', 'archived'));

ALTER TABLE mfg.mfg_scenario_changes DROP CONSTRAINT IF EXISTS mfg_scenario_changes_kind_check;
ALTER TABLE mfg.mfg_scenario_changes ADD CONSTRAINT mfg_scenario_changes_kind_check CHECK (kind IN
    ('demand_qty', 'demand_date', 'demand_new', 'demand_pct', 'extra_shift', 'resource_down', 'order_priority',
     'order_due', 'item_param', 'buy_delay'));

ALTER TABLE mfg.mfg_scenario_runs DROP CONSTRAINT IF EXISTS mfg_scenario_runs_status_check;
ALTER TABLE mfg.mfg_scenario_runs ADD CONSTRAINT mfg_scenario_runs_status_check CHECK (status IN
    ('completed', 'failed'));

ALTER TABLE mfg.mfg_scenario_outcomes DROP CONSTRAINT IF EXISTS mfg_scenario_outcomes_metric_check;
ALTER TABLE mfg.mfg_scenario_outcomes ADD CONSTRAINT mfg_scenario_outcomes_metric_check CHECK (metric IN
    ('late_orders', 'days_late', 'max_days_late', 'unplaceable_ops', 'overload_buckets', 'overload_min',
     'scheduled_load_min', 'shortage_items', 'planned_buys', 'planned_buy_value', 'planned_makes',
     'planned_make_min', 'mrp_messages'));

COMMIT;
