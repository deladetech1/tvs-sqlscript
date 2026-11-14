-- Office: AI settings per business (Administration › AI).
--
--   of_ai_settings  one row per business: Office's own AI switch, a monthly request cap and
--                   whether a file's text or a selection may be sent to AI. A business with no
--                   row reads as the defaults: AI off, no cap, file content not allowed
--
-- The organisation connects AI once, in Core Platform › Settings › AI (Core's gateway applies the
-- organisation's policy, caps and metering). This is Office's own layer on top, as Help Desk has
-- hd_ai_settings (20261107-06): both must say yes. The cap counts the business's ok calls in
-- of_ai_runs (20261114-01) in the calendar month (UTC); failed and refused calls do not count.
--
-- No new permission: the settings are managed by whoever holds office|library|manage (Office
-- Admin by being the role), the gate Administration already uses.
-- No grants: the app group's default privileges cover new tables (01-database.md §8).
-- Design: tvs-shared-apps-bk docs/office-apps/contracts/R4-create.md §12. Idempotent; safe to
-- re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS office.of_ai_settings (
    tenant_id            text NOT NULL,
    bus_id               text NOT NULL,
    enabled              boolean NOT NULL DEFAULT false,
    monthly_request_cap  int        -- NULL: no cap
                         CONSTRAINT of_ai_settings_cap_check CHECK (monthly_request_cap >= 0),
    allow_file_content   boolean NOT NULL DEFAULT false,
    cdatetime            timestamptz NOT NULL DEFAULT now(),
    created_by           text,
    updated_at           timestamptz,
    updated_by           text,
    PRIMARY KEY (tenant_id, bus_id)
);

-- The cap: a business's ok runs this month (of_ai_runs has no index on its time or status).
CREATE INDEX IF NOT EXISTS of_ai_runs_month_idx
    ON office.of_ai_runs (tenant_id, bus_id, cdatetime)
    WHERE status = 'ok';

-- ===================================================================== invariants
DO $$
BEGIN
    -- 1. The table has the shape the backend reads (ai_settings.go).
    IF (SELECT count(*) FROM information_schema.columns
         WHERE table_schema = 'office' AND table_name = 'of_ai_settings'
           AND column_name IN ('tenant_id', 'bus_id', 'enabled', 'monthly_request_cap', 'allow_file_content',
                               'cdatetime', 'created_by', 'updated_at', 'updated_by')) <> 9 THEN
        RAISE EXCEPTION 'office: of_ai_settings is missing a column';
    END IF;
    -- 2. Off by default, file content not allowed by default.
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'office' AND table_name = 'of_ai_settings'
                  AND column_name IN ('enabled', 'allow_file_content')
                  AND (is_nullable <> 'NO' OR column_default IS DISTINCT FROM 'false')) THEN
        RAISE EXCEPTION 'office: of_ai_settings.enabled and allow_file_content must be NOT NULL DEFAULT false';
    END IF;
    -- 3. One row per business, and a cap cannot be negative.
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                    WHERE conrelid = 'office.of_ai_settings'::regclass AND contype = 'p') THEN
        RAISE EXCEPTION 'office: of_ai_settings has no primary key';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                    WHERE conrelid = 'office.of_ai_settings'::regclass AND conname = 'of_ai_settings_cap_check') THEN
        RAISE EXCEPTION 'office: of_ai_settings has no cap check';
    END IF;
    -- 4. The runs the cap counts are there (20261114-01 runs first).
    IF to_regclass('office.of_ai_runs') IS NULL THEN
        RAISE EXCEPTION 'office: of_ai_runs is missing (20261114-01)';
    END IF;
END $$;

COMMIT;
