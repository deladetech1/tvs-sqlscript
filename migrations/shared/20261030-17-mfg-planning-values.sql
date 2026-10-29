-- Manufacturing: the lists of planning (20261030-11) and of exceptions (20261030-15). The lists
-- live only here: to change one, edit this file.
--
--   demand status           open | fulfilled | cancelled
--   MRP run mode            regenerative | net_change;  triggered by  user | job
--   MRP run status          running | completed | failed
--   netted by               regenerative | net_change (item plan state, planned orders)
--   item plan state         fresh | pending | failed
--   planned order type      make | buy | transfer | subcontract
--   planned order status    planned | firmed | converted | deleted
--   converted to            production_order | scm_requisition | scm_transfer
--   pegging supply          planned_order | production_order | on_hand | scm_po_line | scm_transfer_line
--   pegging demand          mfg_demand | scm_so_line | safety_stock | planned_order | production_order
--                           (the last two: dependent demand of a parent's components)
--   MRP message kind        expedite | delay | cancel | increase | decrease | shortage | past_due |
--                           below_safety | lead_time_violated
--   MRP message subject     planned_order | production_order | scm_po_line | demand | item
--   MRP message status      open | accepted | dismissed | resolved
--   exception kind          shortage | mrp_action | late_order | quality_failure | ncr_overdue |
--                           resource_down | supplier_late
--   exception severity      low | medium | high | critical
--   exception status        open | acknowledged | in_resolution | resolved | dismissed
--   exception root type     product | resource | inspection | ncr | planned_order |
--                           production_order | scm_po_line | supplier
--   exception event kind    opened | updated | acknowledged | assigned | resolved | dismissed |
--                           reopened | playbook_run
--
-- Idempotent; safe to re-run.

BEGIN;

ALTER TABLE mfg.mfg_demands DROP CONSTRAINT IF EXISTS mfg_demands_status_check;
ALTER TABLE mfg.mfg_demands ADD CONSTRAINT mfg_demands_status_check CHECK (status IN
    ('open', 'fulfilled', 'cancelled'));

ALTER TABLE mfg.mfg_mrp_runs DROP CONSTRAINT IF EXISTS mfg_mrp_runs_mode_check;
ALTER TABLE mfg.mfg_mrp_runs ADD CONSTRAINT mfg_mrp_runs_mode_check CHECK (mode IN
    ('regenerative', 'net_change'));

ALTER TABLE mfg.mfg_mrp_runs DROP CONSTRAINT IF EXISTS mfg_mrp_runs_triggered_by_check;
ALTER TABLE mfg.mfg_mrp_runs ADD CONSTRAINT mfg_mrp_runs_triggered_by_check CHECK (triggered_by IN
    ('user', 'job'));

ALTER TABLE mfg.mfg_mrp_runs DROP CONSTRAINT IF EXISTS mfg_mrp_runs_status_check;
ALTER TABLE mfg.mfg_mrp_runs ADD CONSTRAINT mfg_mrp_runs_status_check CHECK (status IN
    ('running', 'completed', 'failed'));

ALTER TABLE mfg.mfg_item_plan_state DROP CONSTRAINT IF EXISTS mfg_item_plan_state_netted_by_check;
ALTER TABLE mfg.mfg_item_plan_state ADD CONSTRAINT mfg_item_plan_state_netted_by_check CHECK (netted_by IN
    ('regenerative', 'net_change'));

ALTER TABLE mfg.mfg_item_plan_state DROP CONSTRAINT IF EXISTS mfg_item_plan_state_status_check;
ALTER TABLE mfg.mfg_item_plan_state ADD CONSTRAINT mfg_item_plan_state_status_check CHECK (status IN
    ('fresh', 'pending', 'failed'));

ALTER TABLE mfg.mfg_planned_orders DROP CONSTRAINT IF EXISTS mfg_planned_orders_netted_by_check;
ALTER TABLE mfg.mfg_planned_orders ADD CONSTRAINT mfg_planned_orders_netted_by_check CHECK (netted_by IN
    ('regenerative', 'net_change'));

ALTER TABLE mfg.mfg_planned_orders DROP CONSTRAINT IF EXISTS mfg_planned_orders_type_check;
ALTER TABLE mfg.mfg_planned_orders ADD CONSTRAINT mfg_planned_orders_type_check CHECK (type IN
    ('make', 'buy', 'transfer', 'subcontract'));

ALTER TABLE mfg.mfg_planned_orders DROP CONSTRAINT IF EXISTS mfg_planned_orders_status_check;
ALTER TABLE mfg.mfg_planned_orders ADD CONSTRAINT mfg_planned_orders_status_check CHECK (status IN
    ('planned', 'firmed', 'converted', 'deleted'));

ALTER TABLE mfg.mfg_planned_orders DROP CONSTRAINT IF EXISTS mfg_planned_orders_converted_to_type_check;
ALTER TABLE mfg.mfg_planned_orders ADD CONSTRAINT mfg_planned_orders_converted_to_type_check CHECK (converted_to_type IN
    ('production_order', 'scm_requisition', 'scm_transfer'));

ALTER TABLE mfg.mfg_pegging DROP CONSTRAINT IF EXISTS mfg_pegging_supply_type_check;
ALTER TABLE mfg.mfg_pegging ADD CONSTRAINT mfg_pegging_supply_type_check CHECK (supply_type IN
    ('planned_order', 'production_order', 'on_hand', 'scm_po_line', 'scm_transfer_line'));

ALTER TABLE mfg.mfg_pegging DROP CONSTRAINT IF EXISTS mfg_pegging_demand_type_check;
ALTER TABLE mfg.mfg_pegging ADD CONSTRAINT mfg_pegging_demand_type_check CHECK (demand_type IN
    ('mfg_demand', 'scm_so_line', 'safety_stock', 'planned_order', 'production_order'));

ALTER TABLE mfg.mfg_pegging DROP CONSTRAINT IF EXISTS mfg_pegging_top_demand_type_check;
ALTER TABLE mfg.mfg_pegging ADD CONSTRAINT mfg_pegging_top_demand_type_check CHECK (top_demand_type IN
    ('mfg_demand', 'scm_so_line', 'safety_stock'));

ALTER TABLE mfg.mfg_mrp_messages DROP CONSTRAINT IF EXISTS mfg_mrp_messages_kind_check;
ALTER TABLE mfg.mfg_mrp_messages ADD CONSTRAINT mfg_mrp_messages_kind_check CHECK (kind IN
    ('expedite', 'delay', 'cancel', 'increase', 'decrease', 'shortage', 'past_due', 'below_safety', 'lead_time_violated'));

ALTER TABLE mfg.mfg_mrp_messages DROP CONSTRAINT IF EXISTS mfg_mrp_messages_subject_type_check;
ALTER TABLE mfg.mfg_mrp_messages ADD CONSTRAINT mfg_mrp_messages_subject_type_check CHECK (subject_type IN
    ('planned_order', 'production_order', 'scm_po_line', 'demand', 'item'));

ALTER TABLE mfg.mfg_mrp_messages DROP CONSTRAINT IF EXISTS mfg_mrp_messages_status_check;
ALTER TABLE mfg.mfg_mrp_messages ADD CONSTRAINT mfg_mrp_messages_status_check CHECK (status IN
    ('open', 'accepted', 'dismissed', 'resolved'));

ALTER TABLE mfg.mfg_exceptions DROP CONSTRAINT IF EXISTS mfg_exceptions_kind_check;
ALTER TABLE mfg.mfg_exceptions ADD CONSTRAINT mfg_exceptions_kind_check CHECK (kind IN
    ('shortage', 'mrp_action', 'late_order', 'quality_failure', 'ncr_overdue', 'resource_down', 'supplier_late'));

ALTER TABLE mfg.mfg_exceptions DROP CONSTRAINT IF EXISTS mfg_exceptions_severity_check;
ALTER TABLE mfg.mfg_exceptions ADD CONSTRAINT mfg_exceptions_severity_check CHECK (severity IN
    ('low', 'medium', 'high', 'critical'));

ALTER TABLE mfg.mfg_exceptions DROP CONSTRAINT IF EXISTS mfg_exceptions_status_check;
ALTER TABLE mfg.mfg_exceptions ADD CONSTRAINT mfg_exceptions_status_check CHECK (status IN
    ('open', 'acknowledged', 'in_resolution', 'resolved', 'dismissed'));

ALTER TABLE mfg.mfg_exceptions DROP CONSTRAINT IF EXISTS mfg_exceptions_root_type_check;
ALTER TABLE mfg.mfg_exceptions ADD CONSTRAINT mfg_exceptions_root_type_check CHECK (root_type IN
    ('product', 'resource', 'inspection', 'ncr', 'planned_order', 'production_order', 'scm_po_line', 'supplier'));

ALTER TABLE mfg.mfg_exception_events DROP CONSTRAINT IF EXISTS mfg_exception_events_kind_check;
ALTER TABLE mfg.mfg_exception_events ADD CONSTRAINT mfg_exception_events_kind_check CHECK (kind IN
    ('opened', 'updated', 'acknowledged', 'assigned', 'resolved', 'dismissed', 'reopened', 'playbook_run'));

COMMIT;
