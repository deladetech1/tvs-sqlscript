-- Manufacturing: the lists of scheduling (20261031-12) and forecasts (20261031-13). The lists live
-- only here: to change one, edit this file.
--
--   scheduled-operation source   auto | manual
--   forecast bucket              week | month
--   forecast method              manual | moving_average | exp_smoothing
--   forecast status              draft | published | archived
--
-- Idempotent; safe to re-run.

BEGIN;

ALTER TABLE mfg.mfg_scheduled_operations DROP CONSTRAINT IF EXISTS mfg_scheduled_operations_source_check;
ALTER TABLE mfg.mfg_scheduled_operations ADD CONSTRAINT mfg_scheduled_operations_source_check CHECK (source IN
    ('auto', 'manual'));

ALTER TABLE mfg.mfg_forecast_versions DROP CONSTRAINT IF EXISTS mfg_forecast_versions_bucket_check;
ALTER TABLE mfg.mfg_forecast_versions ADD CONSTRAINT mfg_forecast_versions_bucket_check CHECK (bucket IN
    ('week', 'month'));

ALTER TABLE mfg.mfg_forecast_versions DROP CONSTRAINT IF EXISTS mfg_forecast_versions_method_check;
ALTER TABLE mfg.mfg_forecast_versions ADD CONSTRAINT mfg_forecast_versions_method_check CHECK (method IN
    ('manual', 'moving_average', 'exp_smoothing'));

ALTER TABLE mfg.mfg_forecast_versions DROP CONSTRAINT IF EXISTS mfg_forecast_versions_status_check;
ALTER TABLE mfg.mfg_forecast_versions ADD CONSTRAINT mfg_forecast_versions_status_check CHECK (status IN
    ('draft', 'published', 'archived'));

COMMIT;
