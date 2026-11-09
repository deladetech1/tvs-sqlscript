-- Core Platform: Workflows -- one place a business automates across every TroveSuite app.
--
-- Settings > Workflows in Core: a trigger (a suite event from core_platform.cp_events, a schedule,
-- or a manual start), conditions, then steps (email, SMS, an in-app notice, a wait that keeps to
-- working hours, an approval, a signed webhook), with if/else branches. Design and roadmap:
-- tvs-coreplatform-bk docs/workflows/DESIGN.md.
--
--   cp_workflows               one per automation, per business: the DRAFT the builder edits, its
--                              status (DRAFT | ACTIVE | PAUSED) and the live version
--   cp_workflow_versions       what was published, frozen: the builder's definition and the graph
--                              the runtime walks ({nodes, edges}, the shape Help Desk's Workflow
--                              Studio uses). Runs always name the version they started on, so
--                              editing a workflow never changes a run in flight.
--   cp_workflow_runs           one per (version, trigger): the event id, a schedule slot or a manual
--                              start is the dedupe_key, unique per version -- an event is acted on
--                              once per version however often the runtime sees it
--   cp_workflow_steps          every attempt at every step, append-only: the run history
--   cp_workflow_approvals      an approval step waiting for (or decided by) a named person
--   cp_workflow_notifications  in-app notices a workflow sent; Core's bell reads them
--
-- The runtime is Core's own loop (src/entities/workflows/wf_runtime.py). It reads events with
-- cp_events_after('core-workflows', ...) and moves its place with cp_event_ack. A fresh database
-- starts the reader at the newest event (the runtime does that, not this file), so publishing the
-- first workflow never replays ninety days of history.
--
-- Plan: workflows.designer at ADVANCE (rank 2). Never rank 4: ENTERPRISE is the same product
-- self-hosted, not a larger plan.
--
-- Idempotent; re-runs on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS core_platform.cp_workflows (
    tenant_id        text        NOT NULL,
    id               text        NOT NULL,
    bus_id           text        NOT NULL,
    name             text        NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 120),
    description      text        NOT NULL DEFAULT '',
    status           text        NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'ACTIVE', 'PAUSED')),
    draft            jsonb       NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(draft) = 'object'),
    live_version_id  text,
    -- The webhook signing secret, Fernet-encrypted by Core (secret_crypto); never returned whole.
    signing_secret   text,
    created_by       text,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_by       text,
    updated_at       timestamptz NOT NULL DEFAULT now(),
    deleted_at       timestamptz,
    PRIMARY KEY (tenant_id, id)
);
CREATE INDEX IF NOT EXISTS ix_cp_workflows_bus
    ON core_platform.cp_workflows (tenant_id, bus_id) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_versions (
    tenant_id     text        NOT NULL,
    id            text        NOT NULL,
    workflow_id   text        NOT NULL,
    version       integer     NOT NULL CHECK (version >= 1),
    definition    jsonb       NOT NULL,
    graph         jsonb       NOT NULL,
    trigger_type  text        NOT NULL CHECK (trigger_type IN ('event', 'schedule', 'manual')),
    trigger_kind  text,
    -- Schedules: the next slot the runtime starts a run for.
    next_fire_at  timestamptz,
    -- Runs act as this person: their name is on what the workflow sends.
    published_by  text        NOT NULL,
    published_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, id),
    UNIQUE (tenant_id, workflow_id, version)
);
CREATE INDEX IF NOT EXISTS ix_cp_workflow_versions_kind
    ON core_platform.cp_workflow_versions (trigger_kind) WHERE trigger_type = 'event';
CREATE INDEX IF NOT EXISTS ix_cp_workflow_versions_due
    ON core_platform.cp_workflow_versions (next_fire_at) WHERE trigger_type = 'schedule';

CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_runs (
    tenant_id     text        NOT NULL,
    id            text        NOT NULL,
    bus_id        text        NOT NULL,
    workflow_id   text        NOT NULL,
    version_id    text        NOT NULL,
    trigger_type  text        NOT NULL CHECK (trigger_type IN ('event', 'schedule', 'manual')),
    -- evt:<cp_events.id> | sched:<slot> | manual:<uuid>: one run per version per key.
    dedupe_key    text        NOT NULL,
    event_id      bigint,
    -- The event (or the schedule slot / manual input) as the run saw it: steps read it, and it
    -- stays readable after cp_events purges it at 90 days.
    event         jsonb       NOT NULL DEFAULT '{}'::jsonb,
    state         text        NOT NULL DEFAULT 'PENDING'
                  CHECK (state IN ('PENDING', 'RUNNING', 'WAITING', 'SUCCEEDED', 'FAILED', 'CANCELLED')),
    -- Where the run is: the node to run next (PENDING) or the one it waits on (WAITING).
    node_id       text,
    attempt       integer     NOT NULL DEFAULT 0,
    next_at       timestamptz,
    -- A runtime replica holding the run; another may take it once this passes.
    lease_until   timestamptz,
    -- An approval's outcome (approved | rejected), set when the person decides.
    resume_label  text,
    run_as        text        NOT NULL,
    started_by    text,
    error         text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    finished_at   timestamptz,
    PRIMARY KEY (tenant_id, id),
    UNIQUE (tenant_id, version_id, dedupe_key)
);
CREATE INDEX IF NOT EXISTS ix_cp_workflow_runs_due
    ON core_platform.cp_workflow_runs (next_at) WHERE state IN ('PENDING', 'RUNNING', 'WAITING');
CREATE INDEX IF NOT EXISTS ix_cp_workflow_runs_workflow
    ON core_platform.cp_workflow_runs (tenant_id, workflow_id, cdatetime DESC);

CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_steps (
    id          bigint      GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    tenant_id   text        NOT NULL,
    run_id      text        NOT NULL,
    node_id     text        NOT NULL,
    node_type   text        NOT NULL,
    label       text        NOT NULL DEFAULT '',
    attempt     integer     NOT NULL DEFAULT 1,
    state       text        NOT NULL CHECK (state IN ('SUCCEEDED', 'FAILED', 'RETRYING', 'WAITING', 'SKIPPED')),
    -- The branch it took (true | false | approved | rejected), when it branched.
    outcome     text,
    detail      jsonb       NOT NULL DEFAULT '{}'::jsonb,
    error       text,
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_cp_workflow_steps_run
    ON core_platform.cp_workflow_steps (tenant_id, run_id, id);

CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_approvals (
    tenant_id    text        NOT NULL,
    id           text        NOT NULL,
    bus_id       text        NOT NULL,
    workflow_id  text        NOT NULL,
    run_id       text        NOT NULL,
    node_id      text        NOT NULL,
    approver_id  text        NOT NULL,
    title        text        NOT NULL,
    message      text        NOT NULL DEFAULT '',
    status       text        NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED')),
    decided_by   text,
    decided_at   timestamptz,
    comment      text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, id),
    UNIQUE (tenant_id, run_id, node_id)
);
CREATE INDEX IF NOT EXISTS ix_cp_workflow_approvals_waiting
    ON core_platform.cp_workflow_approvals (tenant_id, approver_id) WHERE status = 'PENDING';

CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_notifications (
    tenant_id    text        NOT NULL,
    id           text        NOT NULL,
    user_id      text        NOT NULL,
    workflow_id  text        NOT NULL,
    run_id       text        NOT NULL,
    node_id      text        NOT NULL,
    title        text        NOT NULL,
    message      text        NOT NULL DEFAULT '',
    href         text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, id),
    -- A retried step never tells the same person twice.
    UNIQUE (tenant_id, run_id, node_id, user_id)
);
CREATE INDEX IF NOT EXISTS ix_cp_workflow_notifications_user
    ON core_platform.cp_workflow_notifications (tenant_id, user_id, cdatetime DESC);

-- ===================================================================== the plan
DO $$
BEGIN
    IF to_regclass('core_platform.cp_platform_feature_catalog') IS NOT NULL THEN
        INSERT INTO core_platform.cp_platform_feature_catalog (feature_key, title, min_tier_rank, description)
        VALUES ('workflows.designer', 'Workflows', 2,
                'Automate across your apps: triggers, conditions, email, SMS, approvals, waits and webhooks')
        ON CONFLICT (feature_key) DO UPDATE SET
            title = EXCLUDED.title, min_tier_rank = EXCLUDED.min_tier_rank,
            description = EXCLUDED.description, is_active = true;
    END IF;
END $$;

-- ===================================================================== invariants
DO $$
BEGIN
    IF to_regclass('core_platform.cp_platform_feature_catalog') IS NOT NULL AND EXISTS (
        SELECT 1 FROM core_platform.cp_platform_feature_catalog
         WHERE feature_key = 'workflows.designer' AND min_tier_rank > 3) THEN
        RAISE EXCEPTION 'workflows.designer must never be gated at rank 4 (ENTERPRISE is self-hosted, not a bigger plan)';
    END IF;
END $$;

COMMIT;
