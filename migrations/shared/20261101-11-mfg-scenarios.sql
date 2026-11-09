-- Manufacturing: what-if scenarios (design: docs/mfg/02-domain-model.md §4; 03-database-model.md
-- §3.5 Scenarios; contract R4a.md E1-E4, E24 (1)).
--
--   mfg_scenarios           a what-if for one plant: name, description, horizon_days (default 90,
--                           at most 180), schedule_days (default 14, at most 31), status draft ->
--                           ready -> applied, archived from any; current_run_id (the run that
--                           describes it), source_exception_id (the exception "Open a scenario"
--                           made it from), changes_hash (of its changes; a run stores the hash it
--                           ran, so an edited scenario shows its run as stale), version (the lock)
--   mfg_scenario_changes    the changes, in seq order: kind (E1's list), params (jsonb, checked by
--                           the API against the plant's live records), note, base_version (the
--                           target record's version when the change was written; apply passes it),
--                           target_id (the record the change names, for "data changed" and apply),
--                           applied_at, applied_by, applied_result (the apply's result for it)
--   mfg_scenario_runs       one run: completed | failed, the changes_hash it ran, started_at,
--                           finished_at, duration_ms, error, detail (late orders, planned-order
--                           diff, overloads, shortages, unplaceable; each list at most 200) and
--                           schedule (the scenario pass's operations, conflicts and buckets in R3's
--                           GET /schedule shape)
--   mfg_scenario_outcomes   one metric of a run against the baseline: value, baseline;
--                           UNIQUE (run_id, metric)
--
-- A run is a sandbox transaction that is always rolled back (E2), so no live table carries a
-- scenario_id: mfg_schedules.scenario_id (R3) stays NULL, and says so. The CHECK lists live in
-- 20261101-14. No product or party column (params are jsonb), so nothing to register for merges. No
-- grants. Idempotent; safe to re-run.

BEGIN;

-- ======================================================================== scenarios
CREATE TABLE IF NOT EXISTS mfg.mfg_scenarios (
    id                   text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id            text NOT NULL,
    org_id               text,
    bus_id               text NOT NULL,
    plant_id             text NOT NULL REFERENCES mfg.mfg_plants (id),
    name                 text NOT NULL,
    description          text,
    horizon_days         integer NOT NULL DEFAULT 90,
    schedule_days        integer NOT NULL DEFAULT 14,
    status               text NOT NULL DEFAULT 'draft',
    current_run_id       text,                       -- mfg_scenario_runs.id (foreign key below)
    source_exception_id  text,                       -- mfg_exceptions.id it was opened from
    copied_from_id       text REFERENCES mfg.mfg_scenarios (id) ON DELETE SET NULL,
    changes_hash         text,                       -- of its changes as they are now
    applied_at           timestamptz,
    applied_by           text,
    archived_at          timestamptz,
    archived_by          text,
    version              integer NOT NULL DEFAULT 1,
    cdatetime            timestamptz NOT NULL DEFAULT now(),
    created_by           text,
    updated_at           timestamptz NOT NULL DEFAULT now(),
    updated_by           text
);
CREATE INDEX IF NOT EXISTS mfg_scenarios_list_idx ON mfg.mfg_scenarios (bus_id, plant_id, status, cdatetime DESC);
CREATE INDEX IF NOT EXISTS mfg_scenarios_name_idx ON mfg.mfg_scenarios (bus_id, lower(name) text_pattern_ops);
CREATE INDEX IF NOT EXISTS mfg_scenarios_exception_idx ON mfg.mfg_scenarios (source_exception_id) WHERE source_exception_id IS NOT NULL;
ALTER TABLE mfg.mfg_scenarios DROP CONSTRAINT IF EXISTS mfg_scenarios_rules_check;
ALTER TABLE mfg.mfg_scenarios ADD CONSTRAINT mfg_scenarios_rules_check
    CHECK (btrim(name) <> ''
           AND horizon_days BETWEEN 1 AND 180
           AND schedule_days BETWEEN 1 AND 31
           AND copied_from_id IS DISTINCT FROM id);

-- ========================================================================== changes
CREATE TABLE IF NOT EXISTS mfg.mfg_scenario_changes (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    scenario_id       text NOT NULL REFERENCES mfg.mfg_scenarios (id) ON DELETE CASCADE,
    seq               integer NOT NULL,
    kind              text NOT NULL,
    params            jsonb NOT NULL,
    note              text,
    target_id         text,                       -- the demand, order, item, buy order ... it names
    base_version      integer,                    -- the target's version when written (E1)
    applied_at        timestamptz,
    applied_by        text,
    applied_result    jsonb,                      -- {status, target {type, id, label}, error {code, message}}
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_scenario_changes_seq_uq ON mfg.mfg_scenario_changes (scenario_id, seq);
CREATE INDEX IF NOT EXISTS mfg_scenario_changes_target_idx ON mfg.mfg_scenario_changes (bus_id, target_id) WHERE target_id IS NOT NULL;
ALTER TABLE mfg.mfg_scenario_changes DROP CONSTRAINT IF EXISTS mfg_scenario_changes_rules_check;
ALTER TABLE mfg.mfg_scenario_changes ADD CONSTRAINT mfg_scenario_changes_rules_check
    CHECK (seq >= 1
           AND jsonb_typeof(params) = 'object'
           AND (applied_result IS NULL OR jsonb_typeof(applied_result) = 'object')
           AND (applied_at IS NULL OR applied_result IS NOT NULL));

-- ============================================================================= runs
CREATE TABLE IF NOT EXISTS mfg.mfg_scenario_runs (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    scenario_id       text NOT NULL REFERENCES mfg.mfg_scenarios (id) ON DELETE CASCADE,
    status            text NOT NULL,              -- completed | failed (written after the rollback)
    changes_hash      text,                       -- the scenario's changes_hash it ran
    started_at        timestamptz NOT NULL,
    finished_at       timestamptz NOT NULL,
    duration_ms       integer NOT NULL DEFAULT 0,
    error             text,                       -- e.g. "Timed out after 30 s: N items, M operations"
    detail            jsonb NOT NULL DEFAULT '{}',
    schedule          jsonb NOT NULL DEFAULT '{}',
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text
);
CREATE INDEX IF NOT EXISTS mfg_scenario_runs_scenario_idx ON mfg.mfg_scenario_runs (scenario_id, started_at DESC);
ALTER TABLE mfg.mfg_scenario_runs DROP CONSTRAINT IF EXISTS mfg_scenario_runs_rules_check;
ALTER TABLE mfg.mfg_scenario_runs ADD CONSTRAINT mfg_scenario_runs_rules_check
    CHECK (finished_at >= started_at AND duration_ms >= 0
           AND jsonb_typeof(detail) = 'object' AND jsonb_typeof(schedule) = 'object'
           AND (status <> 'failed' OR nullif(btrim(error), '') IS NOT NULL));

-- The scenario's current run (the tables refer to each other, so the key is added here).
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'mfg_scenarios_current_run_fk'
                      AND conrelid = 'mfg.mfg_scenarios'::regclass) THEN
        ALTER TABLE mfg.mfg_scenarios ADD CONSTRAINT mfg_scenarios_current_run_fk
            FOREIGN KEY (current_run_id) REFERENCES mfg.mfg_scenario_runs (id) ON DELETE SET NULL;
    END IF;
END $$;

-- ========================================================================= outcomes
CREATE TABLE IF NOT EXISTS mfg.mfg_scenario_outcomes (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    run_id            text NOT NULL REFERENCES mfg.mfg_scenario_runs (id) ON DELETE CASCADE,
    metric            text NOT NULL,
    value             numeric(20,4) NOT NULL,     -- the scenario pass (M1)
    baseline          numeric(20,4) NOT NULL,     -- the base pass (M0); delta = value - baseline
    cdatetime         timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_scenario_outcomes_metric_uq ON mfg.mfg_scenario_outcomes (run_id, metric);

-- ======================================================================== schedules
COMMENT ON COLUMN mfg.mfg_schedules.scenario_id IS
    'unused: scenario schedules are stored on mfg_scenario_runs, R4a E2';

-- ===================================================================== invariants
DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['mfg_scenario_changes_seq_uq', 'mfg_scenario_outcomes_metric_uq'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'mfg' AND indexname = t) THEN
            RAISE EXCEPTION 'mfg unique index % is missing', t;
        END IF;
    END LOOP;
    -- Runs are rolled-back sandboxes (E2): no live schedule belongs to a scenario.
    IF EXISTS (SELECT 1 FROM mfg.mfg_schedules WHERE scenario_id IS NOT NULL) THEN
        RAISE NOTICE 'some mfg_schedules rows carry a scenario_id; R4a stores scenario schedules on mfg_scenario_runs';
    END IF;
    -- A scenario's current run is its own.
    IF EXISTS (SELECT 1 FROM mfg.mfg_scenarios s JOIN mfg.mfg_scenario_runs r ON r.id = s.current_run_id
                WHERE r.scenario_id <> s.id) THEN
        RAISE NOTICE 'some Manufacturing scenarios name another scenario''s run as their current run';
    END IF;
END $$;

COMMIT;
