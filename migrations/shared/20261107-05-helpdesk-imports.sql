-- Help Desk R5: CSV imports, with mapping, preview, validation, history and rollback.
--
--   hd_imports      one uploaded file: what it imports, the column mapping and options, its state
--                   and counts
--   hd_import_rows  each row as uploaded, what was done with it, and the record it created or
--                   updated (rollback works from these)
--
-- CSV only: no spreadsheet library is vendored (R5.md). CHECK lists are defined here, inline; a
-- later change goes in a newer file. No grants.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R5.md §2, §6 BE-4. Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS helpdesk.hd_imports (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    entity         text NOT NULL CONSTRAINT hd_imports_entity_check CHECK (entity IN ('contacts', 'assets', 'cis', 'articles', 'tickets')),
    file_name      text,
    row_count      int NOT NULL DEFAULT 0 CONSTRAINT hd_imports_row_count_check CHECK (row_count >= 0),
    mapping        jsonb NOT NULL DEFAULT '{}',
    options        jsonb NOT NULL DEFAULT '{}',
    state          text NOT NULL DEFAULT 'uploaded'
                   CONSTRAINT hd_imports_state_check CHECK (state IN ('uploaded', 'validated', 'importing', 'completed', 'failed', 'rolled_back')),
    created_count  int NOT NULL DEFAULT 0,
    updated_count  int NOT NULL DEFAULT 0,
    error_count    int NOT NULL DEFAULT 0,
    started_at     timestamptz,
    ended_at       timestamptz,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text,
    updated_at     timestamptz,
    updated_by     text
);
CREATE INDEX IF NOT EXISTS hd_imports_business_idx ON helpdesk.hd_imports (tenant_id, bus_id, cdatetime DESC);

CREATE TABLE IF NOT EXISTS helpdesk.hd_import_rows (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    import_id   text NOT NULL REFERENCES helpdesk.hd_imports (id),
    row_number  int NOT NULL CONSTRAINT hd_import_rows_row_number_check CHECK (row_number >= 1),
    raw         jsonb NOT NULL,
    outcome     text NOT NULL DEFAULT 'pending'
                CONSTRAINT hd_import_rows_outcome_check CHECK (outcome IN ('pending', 'created', 'updated', 'skipped', 'error')),
    error       text,
    record_id   text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text
);
CREATE INDEX IF NOT EXISTS hd_import_rows_import_idx ON helpdesk.hd_import_rows (import_id, row_number);

-- ===================================================================== invariants
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM helpdesk.hd_import_rows r JOIN helpdesk.hd_imports i ON i.id = r.import_id
                WHERE i.tenant_id <> r.tenant_id OR i.bus_id <> r.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk import row belongs to an import of another business';
    END IF;
END $$;

COMMIT;
