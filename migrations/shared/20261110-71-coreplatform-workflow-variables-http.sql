-- Core Platform: workflows get typed variables, an HTTP request step, step tests, loops, error
-- handling, parallel branches, more triggers, sub-workflows, waits and run operations
-- (tvs-coreplatform-bk docs/workflows/DESIGN.md §11, VARIABLES.md).
--
--   cp_workflow_variables   ORGANISATION variables and constants (a base URL, an API key) that
--                           every workflow of the tenant reads as {{org.<name>}}. A secret's value
--                           is Fernet-encrypted by Core ("enc::...") into value_enc and is never
--                           returned by the API; other values are JSON in value.
--   cp_workflow_waits       a run parked on "wait for a callback": the unguessable token in the
--                           callback URL, until when it waits, and what was posted to it.
--   cp_workflows            + samples (what "Test this step" last answered, per step, for the
--                           builder's autocomplete; secrets scrubbed by Core), hook_token and
--                           hook_secret (the incoming-webhook trigger's URL token and its HMAC
--                           secret, encrypted).
--   cp_workflow_versions    trigger_type may also be 'webhook'.
--   cp_workflow_runs        trigger_type may also be 'webhook' | 'list' | 'sub' | 'replay';
--                           + vars (the run's variables, secrets encrypted), frames (loop and
--                           try state), parent_run_id / parent_node_id / depth (sub-workflows),
--                           dedupe_value (a workflow's own de-duplication key), replay_of.
--
-- Idempotent; re-runs on every deploy. Nothing is narrowed: the trigger checks only widen.

BEGIN;

DO $$
BEGIN
    IF to_regclass('core_platform.cp_workflows') IS NULL THEN
        RAISE NOTICE 'workflow-variables: no cp_workflows here (20261109-81 not applied); skipping';
        RETURN;
    END IF;

    -- ================================================================= workflows
    ALTER TABLE core_platform.cp_workflows ADD COLUMN IF NOT EXISTS samples jsonb NOT NULL DEFAULT '{}'::jsonb;
    ALTER TABLE core_platform.cp_workflows ADD COLUMN IF NOT EXISTS hook_token text;
    ALTER TABLE core_platform.cp_workflows ADD COLUMN IF NOT EXISTS hook_secret text;

    -- ================================================================= versions: the webhook trigger
    ALTER TABLE core_platform.cp_workflow_versions DROP CONSTRAINT IF EXISTS cp_workflow_versions_trigger_type_check;
    ALTER TABLE core_platform.cp_workflow_versions DROP CONSTRAINT IF EXISTS cp_workflow_versions_trigger_type_ck;
    ALTER TABLE core_platform.cp_workflow_versions ADD CONSTRAINT cp_workflow_versions_trigger_type_ck
        CHECK (trigger_type IN ('event', 'schedule', 'manual', 'webhook'));

    -- ================================================================= runs
    ALTER TABLE core_platform.cp_workflow_runs DROP CONSTRAINT IF EXISTS cp_workflow_runs_trigger_type_check;
    ALTER TABLE core_platform.cp_workflow_runs DROP CONSTRAINT IF EXISTS cp_workflow_runs_trigger_type_ck;
    ALTER TABLE core_platform.cp_workflow_runs ADD CONSTRAINT cp_workflow_runs_trigger_type_ck
        CHECK (trigger_type IN ('event', 'schedule', 'manual', 'webhook', 'list', 'sub', 'replay'));
    ALTER TABLE core_platform.cp_workflow_runs ADD COLUMN IF NOT EXISTS vars jsonb NOT NULL DEFAULT '{}'::jsonb;
    ALTER TABLE core_platform.cp_workflow_runs ADD COLUMN IF NOT EXISTS frames jsonb NOT NULL DEFAULT '{}'::jsonb;
    ALTER TABLE core_platform.cp_workflow_runs ADD COLUMN IF NOT EXISTS parent_run_id text;
    ALTER TABLE core_platform.cp_workflow_runs ADD COLUMN IF NOT EXISTS parent_node_id text;
    ALTER TABLE core_platform.cp_workflow_runs ADD COLUMN IF NOT EXISTS depth integer NOT NULL DEFAULT 0;
    ALTER TABLE core_platform.cp_workflow_runs ADD COLUMN IF NOT EXISTS dedupe_value text;
    ALTER TABLE core_platform.cp_workflow_runs ADD COLUMN IF NOT EXISTS replay_of text;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS cp_workflows_hook_token_uq
    ON core_platform.cp_workflows (hook_token) WHERE hook_token IS NOT NULL;
CREATE INDEX IF NOT EXISTS cp_workflow_runs_dedupe_value_idx
    ON core_platform.cp_workflow_runs (tenant_id, workflow_id, dedupe_value, cdatetime DESC) WHERE dedupe_value IS NOT NULL;
CREATE INDEX IF NOT EXISTS cp_workflow_runs_parent_idx
    ON core_platform.cp_workflow_runs (tenant_id, parent_run_id) WHERE parent_run_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS cp_workflow_runs_inflight_idx
    ON core_platform.cp_workflow_runs (tenant_id, workflow_id) WHERE state IN ('RUNNING', 'WAITING');

-- ===================================================================== organisation variables
CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_variables (
    tenant_id    text        NOT NULL,
    id           text        NOT NULL,
    name         text        NOT NULL,
    type         text        NOT NULL,
    value        jsonb,                      -- every type but secret
    value_enc    text,                       -- secret only: "enc::<Fernet token>", never returned
    description  text        NOT NULL DEFAULT '',
    created_by   text,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_by   text,
    updated_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, id),
    CONSTRAINT cp_workflow_variables_name_ck CHECK (name ~ '^[A-Za-z_][A-Za-z0-9_]{0,59}$'),
    CONSTRAINT cp_workflow_variables_type_ck
        CHECK (type IN ('string', 'number', 'boolean', 'date', 'datetime', 'json', 'list', 'secret')),
    -- A secret is never stored in the clear: only its encrypted form, and nothing in value.
    CONSTRAINT cp_workflow_variables_secret_ck CHECK (
        (type = 'secret' AND value IS NULL AND (value_enc IS NULL OR value_enc LIKE 'enc::%'))
        OR (type <> 'secret' AND value_enc IS NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS cp_workflow_variables_name_uq
    ON core_platform.cp_workflow_variables (tenant_id, lower(name));

-- ===================================================================== callback waits
CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_waits (
    token        text        PRIMARY KEY,
    tenant_id    text        NOT NULL,
    run_id       text        NOT NULL,
    node_id      text        NOT NULL,
    workflow_id  text        NOT NULL,
    state        text        NOT NULL DEFAULT 'WAITING',
    expires_at   timestamptz NOT NULL,
    received_at  timestamptz,
    body         jsonb,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT cp_workflow_waits_state_ck CHECK (state IN ('WAITING', 'RECEIVED', 'EXPIRED', 'CANCELLED'))
);
CREATE INDEX IF NOT EXISTS cp_workflow_waits_run_idx ON core_platform.cp_workflow_waits (tenant_id, run_id);

COMMIT;
