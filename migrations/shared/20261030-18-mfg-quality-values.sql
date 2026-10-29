-- Manufacturing: the lists of quality and recall (20261030-12). The lists live only here: to change
-- one, edit this file.
--
--   inspection plan point     receipt | in_process | final | periodic
--   inspection plan status    draft | in_review | released | superseded | obsolete (as every
--                             revisioned record; released and later are frozen, 20261029-40)
--   sampling                  full | fixed_n | percent | aql | skip_lot
--   characteristic type       variable | attribute | count
--   inspection trigger        receipt | operation | completion | manual
--   inspection status         open | in_progress | passed | failed | waived
--   receipt type              mfg_stock_receipt | scm_receipt
--   result                    pass | fail
--   hold subject              lot | serial | order | supplier;  source  manual | inspection | ncr | recall
--   hold status               active | released
--   NCR source                inspection | operator_report | customer_complaint | supplier | audit | other
--   NCR severity              minor | major | critical
--   NCR status                open | contained | dispositioned | closed
--   disposition               use_as_is | rework | repair | return_to_supplier | scrap | regrade |
--                             needs_engineering_change
--   CAPA kind                 capa | 8d;  discipline  D1 .. D8
--   CAPA status               open | in_progress | verification | closed | cancelled
--   CAPA action kind          containment | corrective | preventive;  status  open | done | cancelled
--   recall root / direction   lot | serial;  forward | backward
--
-- Idempotent; safe to re-run.

BEGIN;

ALTER TABLE mfg.mfg_inspection_plans DROP CONSTRAINT IF EXISTS mfg_inspection_plans_point_check;
ALTER TABLE mfg.mfg_inspection_plans ADD CONSTRAINT mfg_inspection_plans_point_check CHECK (point IN
    ('receipt', 'in_process', 'final', 'periodic'));

ALTER TABLE mfg.mfg_inspection_plans DROP CONSTRAINT IF EXISTS mfg_inspection_plans_status_check;
ALTER TABLE mfg.mfg_inspection_plans ADD CONSTRAINT mfg_inspection_plans_status_check CHECK (status IN
    ('draft', 'in_review', 'released', 'superseded', 'obsolete'));

ALTER TABLE mfg.mfg_inspection_plans DROP CONSTRAINT IF EXISTS mfg_inspection_plans_sampling_check;
ALTER TABLE mfg.mfg_inspection_plans ADD CONSTRAINT mfg_inspection_plans_sampling_check CHECK (sampling IN
    ('full', 'fixed_n', 'percent', 'aql', 'skip_lot'));

ALTER TABLE mfg.mfg_inspection_characteristics DROP CONSTRAINT IF EXISTS mfg_inspection_characteristics_type_check;
ALTER TABLE mfg.mfg_inspection_characteristics ADD CONSTRAINT mfg_inspection_characteristics_type_check CHECK (type IN
    ('variable', 'attribute', 'count'));

ALTER TABLE mfg.mfg_inspections DROP CONSTRAINT IF EXISTS mfg_inspections_point_check;
ALTER TABLE mfg.mfg_inspections ADD CONSTRAINT mfg_inspections_point_check CHECK (point IN
    ('receipt', 'in_process', 'final', 'periodic'));

ALTER TABLE mfg.mfg_inspections DROP CONSTRAINT IF EXISTS mfg_inspections_trigger_check;
ALTER TABLE mfg.mfg_inspections ADD CONSTRAINT mfg_inspections_trigger_check CHECK (trigger IN
    ('receipt', 'operation', 'completion', 'manual'));

ALTER TABLE mfg.mfg_inspections DROP CONSTRAINT IF EXISTS mfg_inspections_status_check;
ALTER TABLE mfg.mfg_inspections ADD CONSTRAINT mfg_inspections_status_check CHECK (status IN
    ('open', 'in_progress', 'passed', 'failed', 'waived'));

ALTER TABLE mfg.mfg_inspections DROP CONSTRAINT IF EXISTS mfg_inspections_receipt_type_check;
ALTER TABLE mfg.mfg_inspections ADD CONSTRAINT mfg_inspections_receipt_type_check CHECK (receipt_type IN
    ('mfg_stock_receipt', 'scm_receipt'));

ALTER TABLE mfg.mfg_inspection_results DROP CONSTRAINT IF EXISTS mfg_inspection_results_result_check;
ALTER TABLE mfg.mfg_inspection_results ADD CONSTRAINT mfg_inspection_results_result_check CHECK (result IN
    ('pass', 'fail'));

ALTER TABLE mfg.mfg_holds DROP CONSTRAINT IF EXISTS mfg_holds_subject_type_check;
ALTER TABLE mfg.mfg_holds ADD CONSTRAINT mfg_holds_subject_type_check CHECK (subject_type IN
    ('lot', 'serial', 'order', 'supplier'));

ALTER TABLE mfg.mfg_holds DROP CONSTRAINT IF EXISTS mfg_holds_source_check;
ALTER TABLE mfg.mfg_holds ADD CONSTRAINT mfg_holds_source_check CHECK (source IN
    ('manual', 'inspection', 'ncr', 'recall'));

ALTER TABLE mfg.mfg_holds DROP CONSTRAINT IF EXISTS mfg_holds_status_check;
ALTER TABLE mfg.mfg_holds ADD CONSTRAINT mfg_holds_status_check CHECK (status IN
    ('active', 'released'));

ALTER TABLE mfg.mfg_ncrs DROP CONSTRAINT IF EXISTS mfg_ncrs_source_check;
ALTER TABLE mfg.mfg_ncrs ADD CONSTRAINT mfg_ncrs_source_check CHECK (source IN
    ('inspection', 'operator_report', 'customer_complaint', 'supplier', 'audit', 'other'));

ALTER TABLE mfg.mfg_ncrs DROP CONSTRAINT IF EXISTS mfg_ncrs_severity_check;
ALTER TABLE mfg.mfg_ncrs ADD CONSTRAINT mfg_ncrs_severity_check CHECK (severity IN
    ('minor', 'major', 'critical'));

ALTER TABLE mfg.mfg_ncrs DROP CONSTRAINT IF EXISTS mfg_ncrs_status_check;
ALTER TABLE mfg.mfg_ncrs ADD CONSTRAINT mfg_ncrs_status_check CHECK (status IN
    ('open', 'contained', 'dispositioned', 'closed'));

ALTER TABLE mfg.mfg_ncr_lines DROP CONSTRAINT IF EXISTS mfg_ncr_lines_disposition_check;
ALTER TABLE mfg.mfg_ncr_lines ADD CONSTRAINT mfg_ncr_lines_disposition_check CHECK (disposition IN
    ('use_as_is', 'rework', 'repair', 'return_to_supplier', 'scrap', 'regrade', 'needs_engineering_change'));

ALTER TABLE mfg.mfg_capas DROP CONSTRAINT IF EXISTS mfg_capas_kind_check;
ALTER TABLE mfg.mfg_capas ADD CONSTRAINT mfg_capas_kind_check CHECK (kind IN
    ('capa', '8d'));

ALTER TABLE mfg.mfg_capas DROP CONSTRAINT IF EXISTS mfg_capas_discipline_check;
ALTER TABLE mfg.mfg_capas ADD CONSTRAINT mfg_capas_discipline_check CHECK (discipline IN
    ('D1', 'D2', 'D3', 'D4', 'D5', 'D6', 'D7', 'D8'));

ALTER TABLE mfg.mfg_capas DROP CONSTRAINT IF EXISTS mfg_capas_status_check;
ALTER TABLE mfg.mfg_capas ADD CONSTRAINT mfg_capas_status_check CHECK (status IN
    ('open', 'in_progress', 'verification', 'closed', 'cancelled'));

ALTER TABLE mfg.mfg_capa_actions DROP CONSTRAINT IF EXISTS mfg_capa_actions_kind_check;
ALTER TABLE mfg.mfg_capa_actions ADD CONSTRAINT mfg_capa_actions_kind_check CHECK (kind IN
    ('containment', 'corrective', 'preventive'));

ALTER TABLE mfg.mfg_capa_actions DROP CONSTRAINT IF EXISTS mfg_capa_actions_status_check;
ALTER TABLE mfg.mfg_capa_actions ADD CONSTRAINT mfg_capa_actions_status_check CHECK (status IN
    ('open', 'done', 'cancelled'));

ALTER TABLE mfg.mfg_recall_runs DROP CONSTRAINT IF EXISTS mfg_recall_runs_root_kind_check;
ALTER TABLE mfg.mfg_recall_runs ADD CONSTRAINT mfg_recall_runs_root_kind_check CHECK (root_kind IN
    ('lot', 'serial'));

ALTER TABLE mfg.mfg_recall_runs DROP CONSTRAINT IF EXISTS mfg_recall_runs_direction_check;
ALTER TABLE mfg.mfg_recall_runs ADD CONSTRAINT mfg_recall_runs_direction_check CHECK (direction IN
    ('forward', 'backward'));

COMMIT;
