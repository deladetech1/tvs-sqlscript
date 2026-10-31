-- Manufacturing: imports and the sample plant (design: research R-14; contract R3.md D17, D18).
--
--   mfg_imports          one uploaded file for one entity (items | boms | routings | work_centers |
--                        assets | demands): the column mapping, counts per action, previewed ->
--                        committed (or failed). A preview older than 24 h is refused at commit
--                        (409 IMPORT_STALE, the API's rule)
--   mfg_import_rows      each parsed row: its row number, the action it would take (create | update
--                        | skip | error), the record key, the parsed values, errors [{"column",
--                        "message"}], and for an update the target row and the version it had at
--                        preview (target_id, target_version), so commit can refuse a changed record
--   mfg_sample_records   every row the sample plant created (D18): record type and id, so removing
--                        the sample deletes or archives exactly those
--
-- target_id and record_id are ids by type (a product among them), not registered for merges: the
-- import is a one-off and the sample removal archives products, never deletes them. The CHECK lists
-- live in 20261031-20. No grants. Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS mfg.mfg_imports (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    plant_id          text REFERENCES mfg.mfg_plants (id),
    entity            text NOT NULL,
    status            text NOT NULL DEFAULT 'previewed',
    file_name         text,
    file_format       text,                       -- csv | xlsx (the first sheet)
    file_sha256       text,
    mapping           jsonb NOT NULL DEFAULT '{}',   -- {"<file column>": "<template column>"}
    row_count         integer NOT NULL DEFAULT 0,
    counts            jsonb NOT NULL DEFAULT '{}',   -- {"create", "update", "skip", "error"}
    previewed_at      timestamptz NOT NULL DEFAULT now(),
    committed_at      timestamptz,
    committed_by      text,
    error             text,
    version           integer NOT NULL DEFAULT 1,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text
);
CREATE INDEX IF NOT EXISTS mfg_imports_list_idx ON mfg.mfg_imports (bus_id, cdatetime DESC);
ALTER TABLE mfg.mfg_imports DROP CONSTRAINT IF EXISTS mfg_imports_rules_check;
ALTER TABLE mfg.mfg_imports ADD CONSTRAINT mfg_imports_rules_check
    CHECK (row_count BETWEEN 0 AND 5000 AND jsonb_typeof(mapping) = 'object'
           AND (status <> 'committed' OR committed_at IS NOT NULL));

CREATE TABLE IF NOT EXISTS mfg.mfg_import_rows (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    import_id         text NOT NULL REFERENCES mfg.mfg_imports (id) ON DELETE CASCADE,
    row_no            integer NOT NULL,           -- the file's row number (1 = first data row)
    action            text NOT NULL,
    key               text,                       -- the record's key: item code, BOM product, asset code, ...
    data              jsonb NOT NULL DEFAULT '{}',   -- the parsed, mapped values
    errors            jsonb NOT NULL DEFAULT '[]',   -- [{"column", "message"}]
    target_id         text,                       -- update: the record it changes; create: what commit made
    target_version    integer,                    -- update: the target's version at preview
    cdatetime         timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_import_rows_row_uq ON mfg.mfg_import_rows (import_id, row_no);
CREATE INDEX IF NOT EXISTS mfg_import_rows_action_idx ON mfg.mfg_import_rows (import_id, action);
ALTER TABLE mfg.mfg_import_rows DROP CONSTRAINT IF EXISTS mfg_import_rows_rules_check;
ALTER TABLE mfg.mfg_import_rows ADD CONSTRAINT mfg_import_rows_rules_check
    CHECK (row_no >= 1 AND jsonb_typeof(errors) = 'array'
           AND ((action = 'error') = (jsonb_array_length(errors) > 0)));

CREATE TABLE IF NOT EXISTS mfg.mfg_sample_records (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    template          text NOT NULL,              -- discrete_mto | batch_process
    record_type       text NOT NULL,              -- plant | calendar | work_center | resource | product | bom | routing | asset | pm_plan | planned_order | ...
    record_id         text NOT NULL,
    position          integer NOT NULL DEFAULT 0, -- creation order; removal runs it backwards
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_sample_records_record_uq ON mfg.mfg_sample_records (bus_id, record_type, record_id);
CREATE INDEX IF NOT EXISTS mfg_sample_records_business_idx ON mfg.mfg_sample_records (bus_id, position);

COMMIT;
