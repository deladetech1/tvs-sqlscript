-- Manufacturing: the lists of the plant model (20261029-41). The lists live only here: to change
-- one, edit this file (every file re-runs on every deploy).
--
--   work center kind           machine | labour | mixed | subcontract
--   resource kind              machine | tool | fixture | labour_pool
--   resource status            available | running | idle | down | maintenance | unknown | retired
--                              (unknown: its only data source is offline; OEE counts it as no data)
--   reason kind                downtime | scrap | rework
--   loss category              the OEE loss tree a reason feeds
--   calendar exception kind    holiday | shutdown | extra_shift, and what it applies to
--
-- Idempotent; safe to re-run.

BEGIN;

ALTER TABLE mfg.mfg_work_centers DROP CONSTRAINT IF EXISTS mfg_work_centers_kind_check;
ALTER TABLE mfg.mfg_work_centers ADD CONSTRAINT mfg_work_centers_kind_check CHECK (kind IN
    ('machine', 'labour', 'mixed', 'subcontract'));

ALTER TABLE mfg.mfg_resources DROP CONSTRAINT IF EXISTS mfg_resources_kind_check;
ALTER TABLE mfg.mfg_resources ADD CONSTRAINT mfg_resources_kind_check CHECK (kind IN
    ('machine', 'tool', 'fixture', 'labour_pool'));

ALTER TABLE mfg.mfg_resources DROP CONSTRAINT IF EXISTS mfg_resources_status_check;
ALTER TABLE mfg.mfg_resources ADD CONSTRAINT mfg_resources_status_check CHECK (status IN
    ('available', 'running', 'idle', 'down', 'maintenance', 'unknown', 'retired'));

ALTER TABLE mfg.mfg_reason_codes DROP CONSTRAINT IF EXISTS mfg_reason_codes_kind_check;
ALTER TABLE mfg.mfg_reason_codes ADD CONSTRAINT mfg_reason_codes_kind_check CHECK (kind IN
    ('downtime', 'scrap', 'rework'));

ALTER TABLE mfg.mfg_reason_codes DROP CONSTRAINT IF EXISTS mfg_reason_codes_loss_category_check;
ALTER TABLE mfg.mfg_reason_codes ADD CONSTRAINT mfg_reason_codes_loss_category_check CHECK (loss_category IN
    ('breakdown', 'setup', 'waiting', 'material_shortage', 'minor_stop', 'speed', 'quality', 'rework', 'planned'));

ALTER TABLE mfg.mfg_calendar_exceptions DROP CONSTRAINT IF EXISTS mfg_calendar_exceptions_kind_check;
ALTER TABLE mfg.mfg_calendar_exceptions ADD CONSTRAINT mfg_calendar_exceptions_kind_check CHECK (kind IN
    ('holiday', 'shutdown', 'extra_shift'));

ALTER TABLE mfg.mfg_calendar_exceptions DROP CONSTRAINT IF EXISTS mfg_calendar_exceptions_scope_type_check;
ALTER TABLE mfg.mfg_calendar_exceptions ADD CONSTRAINT mfg_calendar_exceptions_scope_type_check CHECK (scope_type IN
    ('work_center', 'resource'));

COMMIT;
