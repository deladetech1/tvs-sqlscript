-- Manufacturing: the lists of costing (20261030-13) and engineering change (20261030-14). The
-- lists live only here: to change one, edit this file.
--
--   cost set kind          current | standard | simulated
--   cost set status        open | frozen | superseded (frozen and superseded are frozen)
--   cost element           material | labour | machine | energy | overhead | subcontract | scrap
--   item cost source       rollup | receipt | standard_cost | manual
--   roll-up status         running | completed | failed
--   roll-up input          receipt_cost | standard_cost | component | routing | subcontract | overhead
--   variance kind          material_price | material_usage | labour_rate | labour_efficiency |
--                          machine | overhead | yield | subcontract
--   ECO kind               ecr | eco
--   ECO urgency            low | normal | high | critical
--   ECO effectivity        date | serial | lot | use_up
--   ECO status             draft | impact_review | approval | approved | implemented | rejected |
--                          cancelled
--   ECO item object        item_revision | bom | routing | work_instruction | inspection_plan
--   stock disposition      use_up | rework | scrap | keep
--   order disposition      finish_on_old | switch_to_new | hold
--   approval decision      approved | rejected
--
-- The ECO, cost set kind, cost element and roll-up input lists are the FC screens' types
-- (tvs-mfg-ft src/models/response/ecos.ts, costing.ts; R1 B17).
--
-- Idempotent; safe to re-run.

BEGIN;

ALTER TABLE mfg.mfg_cost_sets DROP CONSTRAINT IF EXISTS mfg_cost_sets_kind_check;
ALTER TABLE mfg.mfg_cost_sets ADD CONSTRAINT mfg_cost_sets_kind_check CHECK (kind IN
    ('current', 'standard', 'simulated'));

ALTER TABLE mfg.mfg_cost_sets DROP CONSTRAINT IF EXISTS mfg_cost_sets_status_check;
ALTER TABLE mfg.mfg_cost_sets ADD CONSTRAINT mfg_cost_sets_status_check CHECK (status IN
    ('open', 'frozen', 'superseded'));

ALTER TABLE mfg.mfg_item_costs DROP CONSTRAINT IF EXISTS mfg_item_costs_element_check;
ALTER TABLE mfg.mfg_item_costs ADD CONSTRAINT mfg_item_costs_element_check CHECK (element IN
    ('material', 'labour', 'machine', 'energy', 'overhead', 'subcontract', 'scrap'));

ALTER TABLE mfg.mfg_item_costs DROP CONSTRAINT IF EXISTS mfg_item_costs_source_check;
ALTER TABLE mfg.mfg_item_costs ADD CONSTRAINT mfg_item_costs_source_check CHECK (source IN
    ('rollup', 'receipt', 'standard_cost', 'manual'));

ALTER TABLE mfg.mfg_cost_rollups DROP CONSTRAINT IF EXISTS mfg_cost_rollups_status_check;
ALTER TABLE mfg.mfg_cost_rollups ADD CONSTRAINT mfg_cost_rollups_status_check CHECK (status IN
    ('running', 'completed', 'failed'));

ALTER TABLE mfg.mfg_cost_rollup_lines DROP CONSTRAINT IF EXISTS mfg_cost_rollup_lines_element_check;
ALTER TABLE mfg.mfg_cost_rollup_lines ADD CONSTRAINT mfg_cost_rollup_lines_element_check CHECK (element IN
    ('material', 'labour', 'machine', 'energy', 'overhead', 'subcontract', 'scrap'));

ALTER TABLE mfg.mfg_cost_rollup_lines DROP CONSTRAINT IF EXISTS mfg_cost_rollup_lines_input_type_check;
ALTER TABLE mfg.mfg_cost_rollup_lines ADD CONSTRAINT mfg_cost_rollup_lines_input_type_check CHECK (input_type IN
    ('receipt_cost', 'standard_cost', 'component', 'routing', 'subcontract', 'overhead'));

ALTER TABLE mfg.mfg_order_costs DROP CONSTRAINT IF EXISTS mfg_order_costs_element_check;
ALTER TABLE mfg.mfg_order_costs ADD CONSTRAINT mfg_order_costs_element_check CHECK (element IN
    ('material', 'labour', 'machine', 'energy', 'overhead', 'subcontract', 'scrap'));

ALTER TABLE mfg.mfg_order_variances DROP CONSTRAINT IF EXISTS mfg_order_variances_kind_check;
ALTER TABLE mfg.mfg_order_variances ADD CONSTRAINT mfg_order_variances_kind_check CHECK (kind IN
    ('material_price', 'material_usage', 'labour_rate', 'labour_efficiency', 'machine', 'overhead', 'yield', 'subcontract'));

ALTER TABLE mfg.mfg_ecos DROP CONSTRAINT IF EXISTS mfg_ecos_kind_check;
ALTER TABLE mfg.mfg_ecos ADD CONSTRAINT mfg_ecos_kind_check CHECK (kind IN
    ('ecr', 'eco'));

ALTER TABLE mfg.mfg_ecos DROP CONSTRAINT IF EXISTS mfg_ecos_urgency_check;
ALTER TABLE mfg.mfg_ecos ADD CONSTRAINT mfg_ecos_urgency_check CHECK (urgency IN
    ('low', 'normal', 'high', 'critical'));

ALTER TABLE mfg.mfg_ecos DROP CONSTRAINT IF EXISTS mfg_ecos_effectivity_check;
ALTER TABLE mfg.mfg_ecos ADD CONSTRAINT mfg_ecos_effectivity_check CHECK (effectivity IN
    ('date', 'serial', 'lot', 'use_up'));

ALTER TABLE mfg.mfg_ecos DROP CONSTRAINT IF EXISTS mfg_ecos_status_check;
ALTER TABLE mfg.mfg_ecos ADD CONSTRAINT mfg_ecos_status_check CHECK (status IN
    ('draft', 'impact_review', 'approval', 'approved', 'implemented', 'rejected', 'cancelled'));

ALTER TABLE mfg.mfg_eco_items DROP CONSTRAINT IF EXISTS mfg_eco_items_object_type_check;
ALTER TABLE mfg.mfg_eco_items ADD CONSTRAINT mfg_eco_items_object_type_check CHECK (object_type IN
    ('item_revision', 'bom', 'routing', 'work_instruction', 'inspection_plan'));

ALTER TABLE mfg.mfg_eco_items DROP CONSTRAINT IF EXISTS mfg_eco_items_stock_disposition_check;
ALTER TABLE mfg.mfg_eco_items ADD CONSTRAINT mfg_eco_items_stock_disposition_check CHECK (stock_disposition IN
    ('use_up', 'rework', 'scrap', 'keep'));

ALTER TABLE mfg.mfg_eco_items DROP CONSTRAINT IF EXISTS mfg_eco_items_order_disposition_check;
ALTER TABLE mfg.mfg_eco_items ADD CONSTRAINT mfg_eco_items_order_disposition_check CHECK (order_disposition IN
    ('finish_on_old', 'switch_to_new', 'hold'));

ALTER TABLE mfg.mfg_eco_approvals DROP CONSTRAINT IF EXISTS mfg_eco_approvals_decision_check;
ALTER TABLE mfg.mfg_eco_approvals ADD CONSTRAINT mfg_eco_approvals_decision_check CHECK (decision IN
    ('approved', 'rejected'));

COMMIT;
