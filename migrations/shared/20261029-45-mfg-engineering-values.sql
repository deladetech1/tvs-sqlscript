-- Manufacturing: the lists of engineering (20261029-42), and the ones production orders copy from
-- it (20261029-43: an order component's issue method and line type, an order operation's control
-- key). The lists live only here: to change one, edit this file.
--
--   item type          raw | component | subassembly | finished | consumable | packaging | spare |
--                      tool | service | by_product | co_product
--   procurement        make | buy | subcontract | transfer
--   lot-size rule      lot_for_lot | fixed | min_max | period_of_supply
--   tracking           none | lot | serial (item settings)
--   revision status    draft | in_review | released | superseded | obsolete (item revisions, BOMs,
--                      routings, work instructions; released and later are frozen, 20261029-40)
--   BOM type / usage   engineering | manufacturing | planning;  production | costing
--   routing usage      production | rework
--   BOM line type      component | co_product | by_product | text (a text line has no component)
--   issue method       manual | backflush | pick_list
--   control key        count_point | inspect | subcontract | optional | milestone
--   document kind      drawing | cad_reference | spec | certificate | sds | procedure | photo | other
--   document status    pending (until the file is uploaded) | active | archived
--   checkpoint type    check | number | text | photo
--
-- Idempotent; safe to re-run.

BEGIN;

ALTER TABLE mfg.mfg_item_settings DROP CONSTRAINT IF EXISTS mfg_item_settings_item_type_check;
ALTER TABLE mfg.mfg_item_settings ADD CONSTRAINT mfg_item_settings_item_type_check CHECK (item_type IN
    ('raw', 'component', 'subassembly', 'finished', 'consumable', 'packaging', 'spare', 'tool', 'service',
     'by_product', 'co_product'));

ALTER TABLE mfg.mfg_item_settings DROP CONSTRAINT IF EXISTS mfg_item_settings_procurement_check;
ALTER TABLE mfg.mfg_item_settings ADD CONSTRAINT mfg_item_settings_procurement_check CHECK (procurement IN
    ('make', 'buy', 'subcontract', 'transfer'));

ALTER TABLE mfg.mfg_item_settings DROP CONSTRAINT IF EXISTS mfg_item_settings_lot_size_rule_check;
ALTER TABLE mfg.mfg_item_settings ADD CONSTRAINT mfg_item_settings_lot_size_rule_check CHECK (lot_size_rule IN
    ('lot_for_lot', 'fixed', 'min_max', 'period_of_supply'));

ALTER TABLE mfg.mfg_item_settings DROP CONSTRAINT IF EXISTS mfg_item_settings_tracking_check;
ALTER TABLE mfg.mfg_item_settings ADD CONSTRAINT mfg_item_settings_tracking_check CHECK (tracking IN
    ('none', 'lot', 'serial'));

-- One revision status list for every revisioned table.
ALTER TABLE mfg.mfg_item_revisions DROP CONSTRAINT IF EXISTS mfg_item_revisions_status_check;
ALTER TABLE mfg.mfg_item_revisions ADD CONSTRAINT mfg_item_revisions_status_check CHECK (status IN
    ('draft', 'in_review', 'released', 'superseded', 'obsolete'));
ALTER TABLE mfg.mfg_boms DROP CONSTRAINT IF EXISTS mfg_boms_status_check;
ALTER TABLE mfg.mfg_boms ADD CONSTRAINT mfg_boms_status_check CHECK (status IN
    ('draft', 'in_review', 'released', 'superseded', 'obsolete'));
ALTER TABLE mfg.mfg_routings DROP CONSTRAINT IF EXISTS mfg_routings_status_check;
ALTER TABLE mfg.mfg_routings ADD CONSTRAINT mfg_routings_status_check CHECK (status IN
    ('draft', 'in_review', 'released', 'superseded', 'obsolete'));
ALTER TABLE mfg.mfg_work_instructions DROP CONSTRAINT IF EXISTS mfg_work_instructions_status_check;
ALTER TABLE mfg.mfg_work_instructions ADD CONSTRAINT mfg_work_instructions_status_check CHECK (status IN
    ('draft', 'in_review', 'released', 'superseded', 'obsolete'));

ALTER TABLE mfg.mfg_boms DROP CONSTRAINT IF EXISTS mfg_boms_bom_type_check;
ALTER TABLE mfg.mfg_boms ADD CONSTRAINT mfg_boms_bom_type_check CHECK (bom_type IN
    ('engineering', 'manufacturing', 'planning'));
ALTER TABLE mfg.mfg_boms DROP CONSTRAINT IF EXISTS mfg_boms_usage_check;
ALTER TABLE mfg.mfg_boms ADD CONSTRAINT mfg_boms_usage_check CHECK (usage IN
    ('production', 'costing'));
ALTER TABLE mfg.mfg_routings DROP CONSTRAINT IF EXISTS mfg_routings_usage_check;
ALTER TABLE mfg.mfg_routings ADD CONSTRAINT mfg_routings_usage_check CHECK (usage IN
    ('production', 'rework'));

ALTER TABLE mfg.mfg_bom_lines DROP CONSTRAINT IF EXISTS mfg_bom_lines_line_type_check;
ALTER TABLE mfg.mfg_bom_lines ADD CONSTRAINT mfg_bom_lines_line_type_check CHECK (line_type IN
    ('component', 'co_product', 'by_product', 'text'));
ALTER TABLE mfg.mfg_bom_lines DROP CONSTRAINT IF EXISTS mfg_bom_lines_text_check;
ALTER TABLE mfg.mfg_bom_lines ADD CONSTRAINT mfg_bom_lines_text_check CHECK ((line_type = 'text') = (component_id IS NULL));
ALTER TABLE mfg.mfg_order_components DROP CONSTRAINT IF EXISTS mfg_order_components_line_type_check;
ALTER TABLE mfg.mfg_order_components ADD CONSTRAINT mfg_order_components_line_type_check CHECK (line_type IN
    ('component', 'co_product', 'by_product'));

ALTER TABLE mfg.mfg_bom_lines DROP CONSTRAINT IF EXISTS mfg_bom_lines_issue_method_check;
ALTER TABLE mfg.mfg_bom_lines ADD CONSTRAINT mfg_bom_lines_issue_method_check CHECK (issue_method IN
    ('manual', 'backflush', 'pick_list'));
ALTER TABLE mfg.mfg_order_components DROP CONSTRAINT IF EXISTS mfg_order_components_issue_method_check;
ALTER TABLE mfg.mfg_order_components ADD CONSTRAINT mfg_order_components_issue_method_check CHECK (issue_method IN
    ('manual', 'backflush', 'pick_list'));

ALTER TABLE mfg.mfg_operations DROP CONSTRAINT IF EXISTS mfg_operations_control_key_check;
ALTER TABLE mfg.mfg_operations ADD CONSTRAINT mfg_operations_control_key_check CHECK (control_key IN
    ('count_point', 'inspect', 'subcontract', 'optional', 'milestone'));
ALTER TABLE mfg.mfg_order_operations DROP CONSTRAINT IF EXISTS mfg_order_operations_control_key_check;
ALTER TABLE mfg.mfg_order_operations ADD CONSTRAINT mfg_order_operations_control_key_check CHECK (control_key IN
    ('count_point', 'inspect', 'subcontract', 'optional', 'milestone'));

ALTER TABLE mfg.mfg_documents DROP CONSTRAINT IF EXISTS mfg_documents_kind_check;
ALTER TABLE mfg.mfg_documents ADD CONSTRAINT mfg_documents_kind_check CHECK (kind IN
    ('drawing', 'cad_reference', 'spec', 'certificate', 'sds', 'procedure', 'photo', 'other'));
ALTER TABLE mfg.mfg_documents DROP CONSTRAINT IF EXISTS mfg_documents_status_check;
ALTER TABLE mfg.mfg_documents ADD CONSTRAINT mfg_documents_status_check CHECK (status IN
    ('pending', 'active', 'archived'));

ALTER TABLE mfg.mfg_instruction_checkpoints DROP CONSTRAINT IF EXISTS mfg_instruction_checkpoints_type_check;
ALTER TABLE mfg.mfg_instruction_checkpoints ADD CONSTRAINT mfg_instruction_checkpoints_type_check CHECK (type IN
    ('check', 'number', 'text', 'photo'));

COMMIT;
