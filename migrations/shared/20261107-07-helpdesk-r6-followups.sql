-- Help Desk R6: schema follow-ups of R3–R5.
--
--   hd_dashboards.version        the dashboard's own version (R5 kept it inside the layout document);
--                                backfilled from layout.version, which is then removed from the layout
--   hd_tickets.external_ref      a reference from another system (imports dedupe on it); unique per
--                                business among live tickets, at most 200 characters; backfilled for
--                                tickets earlier imports created, from the import rows
--   hd_reports.archived_at       a report or schedule with history is archived instead of deleted;
--   hd_report_schedules.archived_at  an archived schedule never runs
--
-- CHECK lists are defined here, inline; a later change goes in a newer file. No grants.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R6.md §1. Idempotent; safe to re-run.

BEGIN;

-- ===================================================================== dashboards: version
ALTER TABLE helpdesk.hd_dashboards ADD COLUMN IF NOT EXISTS version int NOT NULL DEFAULT 1;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                    WHERE conrelid = 'helpdesk.hd_dashboards'::regclass AND conname = 'hd_dashboards_version_check') THEN
        ALTER TABLE helpdesk.hd_dashboards ADD CONSTRAINT hd_dashboards_version_check CHECK (version >= 1);
    END IF;
END $$;
-- R5 stored {version, widgets}: take the larger version and drop the key. A layout without the key
-- is left alone, so a re-run changes nothing.
UPDATE helpdesk.hd_dashboards
   SET version = GREATEST(version, CASE WHEN jsonb_typeof(layout -> 'version') = 'number'
                                        THEN LEAST(GREATEST(floor((layout ->> 'version')::numeric), 1), 2147483647)::int
                                        ELSE 1 END),
       layout  = layout - 'version'
 WHERE jsonb_typeof(layout) = 'object' AND layout ? 'version';

-- ===================================================================== tickets: external_ref
ALTER TABLE helpdesk.hd_tickets ADD COLUMN IF NOT EXISTS external_ref text;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                    WHERE conrelid = 'helpdesk.hd_tickets'::regclass AND conname = 'hd_tickets_external_ref_check') THEN
        ALTER TABLE helpdesk.hd_tickets ADD CONSTRAINT hd_tickets_external_ref_check
            CHECK (external_ref IS NULL OR (char_length(external_ref) BETWEEN 1 AND 200 AND external_ref = btrim(external_ref)));
    END IF;
END $$;
-- R5 imports kept the reference in the import rows only (through each import's mapping). Give each
-- live ticket an import created or updated its reference: the earliest row per reference, and never
-- a reference a live ticket of the business already carries.
WITH src AS (
    SELECT DISTINCT ON (r.tenant_id, r.bus_id, btrim(r.raw ->> mp.key))
           r.record_id, r.tenant_id, r.bus_id, btrim(r.raw ->> mp.key) AS ref
      FROM helpdesk.hd_import_rows r
      JOIN helpdesk.hd_imports i ON i.id = r.import_id AND i.tenant_id = r.tenant_id AND i.bus_id = r.bus_id
      JOIN helpdesk.hd_tickets t ON t.id = r.record_id AND t.tenant_id = r.tenant_id AND t.bus_id = r.bus_id AND t.deleted_at IS NULL
      CROSS JOIN LATERAL jsonb_each_text(i.mapping) mp
     WHERE i.entity = 'tickets' AND r.outcome IN ('created', 'updated') AND mp.value = 'external_ref'
       AND char_length(btrim(coalesce(r.raw ->> mp.key, ''))) BETWEEN 1 AND 200
     ORDER BY r.tenant_id, r.bus_id, btrim(r.raw ->> mp.key), r.cdatetime, r.row_number
)
UPDATE helpdesk.hd_tickets t
   SET external_ref = src.ref
  FROM src
 WHERE t.id = src.record_id AND t.tenant_id = src.tenant_id AND t.bus_id = src.bus_id
   AND t.external_ref IS NULL AND t.deleted_at IS NULL
   AND NOT EXISTS (SELECT 1 FROM helpdesk.hd_tickets o
                    WHERE o.tenant_id = t.tenant_id AND o.bus_id = t.bus_id AND o.external_ref = src.ref AND o.deleted_at IS NULL);
-- Unique among live tickets: an import that is rolled back (tickets soft-deleted) can run again.
CREATE UNIQUE INDEX IF NOT EXISTS hd_tickets_external_ref_uq ON helpdesk.hd_tickets (tenant_id, bus_id, external_ref)
    WHERE external_ref IS NOT NULL AND deleted_at IS NULL;

-- ===================================================================== reports: archived_at
ALTER TABLE helpdesk.hd_reports ADD COLUMN IF NOT EXISTS archived_at timestamptz;
ALTER TABLE helpdesk.hd_report_schedules ADD COLUMN IF NOT EXISTS archived_at timestamptz;
-- The schedule job reads due, live schedules across businesses.
CREATE INDEX IF NOT EXISTS hd_report_schedules_due_live_idx ON helpdesk.hd_report_schedules (next_run_at)
    WHERE is_active AND archived_at IS NULL;

-- ===================================================================== invariants
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                    WHERE conrelid = 'helpdesk.hd_dashboards'::regclass AND conname = 'hd_dashboards_version_check') THEN
        RAISE EXCEPTION 'helpdesk.hd_dashboards has no version check';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                    WHERE conrelid = 'helpdesk.hd_tickets'::regclass AND conname = 'hd_tickets_external_ref_check') THEN
        RAISE EXCEPTION 'helpdesk.hd_tickets has no external_ref check';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_index x JOIN pg_class c ON c.oid = x.indexrelid
                    WHERE x.indrelid = 'helpdesk.hd_tickets'::regclass AND c.relname = 'hd_tickets_external_ref_uq' AND x.indisunique) THEN
        RAISE EXCEPTION 'helpdesk.hd_tickets has no unique index on external_ref';
    END IF;
END $$;

COMMIT;
