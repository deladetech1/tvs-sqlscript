-- Manufacturing: the lists of costing (20261030-13) and engineering change (20261030-14). The
-- lists live only here: to change one, edit this file.
--
--   cost set kind          current | standard | simulated
--   cost set status        open | frozen | superseded (frozen and superseded are frozen)
--   cost element           material | labour | machine | energy | overhead | subcontract | scrap
--   item cost source       rollup | receipt | standard_cost | manual
--   roll-up status         running | completed | failed
--   roll-up input          component | operation | receipt | standard_cost | manual
--   variance kind          material_price | material_usage | labour_rate | labour_efficiency |
--                          machine | overhead | yield | subcontract
--   ECO kind               ecr | eco
--   ECO urgency            low | normal | high | emergency
--   ECO effectivity        date | serial | lot | use_up
--   ECO status             draft | submitted | approved | rejected | implemented | cancelled
--   ECO item object        item_revision | bom | routing | work_instruction | inspection_plan
--   stock disposition      use_up | scrap | rework | return | none
--   order disposition      none | update_open | finish_on_old | cancel
--   approval decision      approve | reject
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
    ('component', 'operation', 'receipt', 'standard_cost', 'manual'));

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
    ('low', 'normal', 'high', 'emergency'));

ALTER TABLE mfg.mfg_ecos DROP CONSTRAINT IF EXISTS mfg_ecos_effectivity_check;
ALTER TABLE mfg.mfg_ecos ADD CONSTRAINT mfg_ecos_effectivity_check CHECK (effectivity IN
    ('date', 'serial', 'lot', 'use_up'));

ALTER TABLE mfg.mfg_ecos DROP CONSTRAINT IF EXISTS mfg_ecos_status_check;
ALTER TABLE mfg.mfg_ecos ADD CONSTRAINT mfg_ecos_status_check CHECK (status IN
    ('draft', 'submitted', 'approved', 'rejected', 'implemented', 'cancelled'));

ALTER TABLE mfg.mfg_eco_items DROP CONSTRAINT IF EXISTS mfg_eco_items_object_type_check;
ALTER TABLE mfg.mfg_eco_items ADD CONSTRAINT mfg_eco_items_object_type_check CHECK (object_type IN
    ('item_revision', 'bom', 'routing', 'work_instruction', 'inspection_plan'));

ALTER TABLE mfg.mfg_eco_items DROP CONSTRAINT IF EXISTS mfg_eco_items_stock_disposition_check;
ALTER TABLE mfg.mfg_eco_items ADD CONSTRAINT mfg_eco_items_stock_disposition_check CHECK (stock_disposition IN
    ('use_up', 'scrap', 'rework', 'return', 'none'));

ALTER TABLE mfg.mfg_eco_items DROP CONSTRAINT IF EXISTS mfg_eco_items_order_disposition_check;
ALTER TABLE mfg.mfg_eco_items ADD CONSTRAINT mfg_eco_items_order_disposition_check CHECK (order_disposition IN
    ('none', 'update_open', 'finish_on_old', 'cancel'));

ALTER TABLE mfg.mfg_eco_approvals DROP CONSTRAINT IF EXISTS mfg_eco_approvals_decision_check;
ALTER TABLE mfg.mfg_eco_approvals ADD CONSTRAINT mfg_eco_approvals_decision_check CHECK (decision IN
    ('approve', 'reject'));

COMMIT;
