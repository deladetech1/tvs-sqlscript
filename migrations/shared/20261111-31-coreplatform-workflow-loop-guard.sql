-- Core Platform: workflows stop loops, and Core publishes its own events
-- (tvs-coreplatform-bk docs/workflows/DESIGN.md §12 "Loops").
--
-- A workflow that starts on "User created" and creates a user starts itself again, forever. Three
-- layers stop that; this file holds what the first two keep in the database.
--
--   cp_events.caused_by        CAUSATION: the workflow run whose action made this event, as
--                              {run_id, workflow_id, chain: [workflow ids], depth}. NULL = a
--                              person (or a job) did it. Filled by cp_event_publish from the
--                              transaction-local setting trovesuite.caused_by, which an app sets
--                              when it acts for a workflow (its request carried X-Workflow-Run /
--                              X-Workflow-Chain / X-Workflow-Depth, or its inbox took in a
--                              workflow.* request). Events published from triggers get it too: the
--                              setting is read in the same transaction. Core's intake: an event
--                              never starts a workflow already in its chain (unless the workflow
--                              opts in), and one whose depth reached the limit starts nothing.
--   cp_workflows               + pause_reason / paused_at / paused_auto: the CIRCUIT BREAKER
--                              paused it (started too often in a short time); the builder shows
--                              the reason with "Switch on again". loop_reset_at: when it was
--                              switched on again (starts before that do not count).
--   cp_workflow_guard          the tenant-wide safety valve: per tenant, until when new starts are
--                              held and when admins were last told. One row per tenant.
--   cp_event_marks             "told once": a key per tenant (sub-expiring:<sub>:<days>:<end date>,
--                              sign-in-failures:<user>:<window>) so a daily job or a repeated
--                              failure publishes its event once. Kept 120 days.
--
-- Core's own events use the prefix core. (core.user_added, core.subscription_expiring...): the
-- kind check (^[a-z_]+\.[a-z_]+$) already allows them.
--
-- Idempotent; re-runs every deploy. The backend tolerates every object here being missing (a silo
-- the shared SQL has not reached yet): there it counts and pauses from the runs table alone.

BEGIN;

-- ===================================================================== causation on events
ALTER TABLE core_platform.cp_events ADD COLUMN IF NOT EXISTS caused_by jsonb;

-- The cause the current transaction acts for: trovesuite.caused_by when it holds a JSON object
-- naming a run, else NULL. Never raises: a bad setting is a person's action, not a failed write.
CREATE OR REPLACE FUNCTION core_platform.cp_event_cause()
RETURNS jsonb LANGUAGE plpgsql STABLE AS $f$
DECLARE raw text; j jsonb;
BEGIN
    raw := nullif(btrim(coalesce(current_setting('trovesuite.caused_by', true), '')), '');
    IF raw IS NULL OR length(raw) > 4000 THEN
        RETURN NULL;
    END IF;
    BEGIN
        j := raw::jsonb;
    EXCEPTION WHEN others THEN
        RETURN NULL;
    END;
    IF jsonb_typeof(j) <> 'object' OR coalesce(j ->> 'run_id', '') = '' THEN
        RETURN NULL;
    END IF;
    RETURN jsonb_build_object(
        'run_id', left(j ->> 'run_id', 100),
        'workflow_id', left(coalesce(j ->> 'workflow_id', ''), 100),
        'chain', CASE WHEN jsonb_typeof(j -> 'chain') = 'array' THEN j -> 'chain' ELSE '[]'::jsonb END,
        'depth', CASE WHEN (j ->> 'depth') ~ '^[0-9]{1,3}$' THEN (j ->> 'depth')::int ELSE 1 END);
END
$f$;

-- publish: an event, in the caller's transaction, with the cause it acts for (if any). Same
-- signature as 20261019-33 (which re-creates the old body first on every deploy; this, later,
-- wins).
CREATE OR REPLACE FUNCTION core_platform.cp_event_publish(p_tenant text, p_bus text, p_source text, p_kind text, p_subject text, p_payload jsonb DEFAULT '{}')
RETURNS bigint LANGUAGE sql AS $f$
    INSERT INTO core_platform.cp_events (tenant_id, bus_id, source_app, kind, subject_id, payload, caused_by)
    VALUES (p_tenant, p_bus, coalesce(p_source, ''), p_kind, p_subject, coalesce(p_payload, '{}'),
            core_platform.cp_event_cause())
    RETURNING id
$f$;

-- after: unchanged, re-made so its row type carries caused_by.
CREATE OR REPLACE FUNCTION core_platform.cp_events_after(p_reader text, p_limit integer DEFAULT 500, p_kinds text[] DEFAULT NULL)
RETURNS SETOF core_platform.cp_events LANGUAGE sql STABLE AS $f$
    SELECT e.* FROM core_platform.cp_events e
     WHERE e.id > coalesce((SELECT last_id FROM core_platform.cp_event_cursors WHERE reader = p_reader), 0)
       AND e.txid < pg_snapshot_xmin(pg_current_snapshot())
       AND (p_kinds IS NULL OR e.kind = ANY (p_kinds))
     ORDER BY e.id
     LIMIT greatest(1, least(coalesce(p_limit, 500), 5000))
$f$;

-- ===================================================================== the circuit breaker
DO $$
BEGIN
    IF to_regclass('core_platform.cp_workflows') IS NULL THEN
        RAISE NOTICE 'workflow-loop-guard: no cp_workflows here (20261109-81 not applied); skipping';
        RETURN;
    END IF;
    ALTER TABLE core_platform.cp_workflows ADD COLUMN IF NOT EXISTS pause_reason text;
    ALTER TABLE core_platform.cp_workflows ADD COLUMN IF NOT EXISTS paused_at timestamptz;
    ALTER TABLE core_platform.cp_workflows ADD COLUMN IF NOT EXISTS paused_auto boolean NOT NULL DEFAULT false;
    ALTER TABLE core_platform.cp_workflows ADD COLUMN IF NOT EXISTS loop_reset_at timestamptz;
END $$;

CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_guard (
    tenant_id      text        PRIMARY KEY,
    held_until     timestamptz,
    reason         text,
    last_alert_at  timestamptz,
    updated_at     timestamptz NOT NULL DEFAULT now()
);

-- ===================================================================== told once
CREATE TABLE IF NOT EXISTS core_platform.cp_event_marks (
    tenant_id  text        NOT NULL,
    mark       text        NOT NULL CHECK (length(mark) BETWEEN 1 AND 300),
    event_id   bigint,
    cdatetime  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, mark)
);
CREATE INDEX IF NOT EXISTS cp_event_marks_cdatetime_idx ON core_platform.cp_event_marks (cdatetime);
DELETE FROM core_platform.cp_event_marks WHERE cdatetime < now() - interval '120 days';

-- ===================================================================== invariants
DO $$
DECLARE got jsonb;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'core_platform'
                    AND table_name = 'cp_events' AND column_name = 'caused_by') THEN
        RAISE EXCEPTION 'cp_events.caused_by is missing';
    END IF;
    -- The cause is read from the transaction's own setting, and only a well-formed one.
    PERFORM set_config('trovesuite.caused_by', '{"run_id":"wfr-x","workflow_id":"wf-x","chain":["wf-x"],"depth":2}', true);
    got := core_platform.cp_event_cause();
    IF got IS NULL OR got ->> 'run_id' <> 'wfr-x' OR (got ->> 'depth')::int <> 2 THEN
        RAISE EXCEPTION 'cp_event_cause does not read trovesuite.caused_by (%)', got;
    END IF;
    PERFORM set_config('trovesuite.caused_by', 'not json', true);
    IF core_platform.cp_event_cause() IS NOT NULL THEN
        RAISE EXCEPTION 'cp_event_cause must ignore a malformed setting';
    END IF;
    PERFORM set_config('trovesuite.caused_by', '', true);
    IF core_platform.cp_event_cause() IS NOT NULL THEN
        RAISE EXCEPTION 'cp_event_cause must be NULL with no setting';
    END IF;
END $$;

COMMIT;
