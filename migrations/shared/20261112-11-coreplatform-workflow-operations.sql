-- Core Platform: Workflows operations and testing -- alert rules, the alerts they raise, connection
-- health, saved test cases, and an index for the business-wide Runs page.
--
--   cp_workflow_alert_rules   per BUSINESS: "when any workflow (or one in a project / folder, or one
--                             workflow) fails / is paused by the loop guard / runs longer than X /
--                             succeeds after a failure, or a saved connection starts failing, tell
--                             these people, groups or roles by Core notice, email, SMS, or Slack /
--                             Teams through a saved connection". throttle_minutes: at most one alert
--                             per workflow per rule in that time. digest: a daily email of what the
--                             rule saw (immediate = false makes it digest-only).
--                             events / recipients / channels are JSON the service validates (no CHECK
--                             list here: a widened list would have to be re-filed in every migration).
--   cp_workflow_alerts        what a rule raised, and an outbox: PENDING -> SENDING -> SENT / FAILED,
--                             or THROTTLED (inside the rule's throttle window), QUEUED (digest-only),
--                             SKIPPED (the business no longer subscribes). (tenant, rule, dedupe_key)
--                             is unique: one event alerts a rule once however often it is seen.
--                             Kept 90 days (the runtime purges).
--   cp_workflow_connection_health   the periodic check of a saved connection (kind 'connection':
--                             cp_workflow_connections; kind 'ai': cp_ai_connections): OK / FAILING
--                             (since when) / EXPIRING (expires_on is near) / UNKNOWN, when it was
--                             checked and when it is next due (at most daily; backs off on failure).
--   cp_workflow_test_cases    a workflow's saved test inputs (the event, variable values, which way
--                             approvals go) and what is expected (starts or not, steps that run or
--                             not, final variable values, no step fails), with the last result.
--                             Kept OUTSIDE the engine definition: a version never carries them.
--
-- The backend (tvs-coreplatform-bk wf_alerts / wf_health / wf_testcases / wf_ops) tolerates every
-- object here being missing (a silo the shared SQL has not reached yet): pages answer empty and the
-- runtime's passes do nothing. Idempotent; re-runs every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_alert_rules (
    tenant_id             text        NOT NULL,
    id                    text        NOT NULL,
    bus_id                text        NOT NULL,
    name                  text        NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 80),
    enabled               boolean     NOT NULL DEFAULT true,
    scope                 text        NOT NULL DEFAULT 'all',
    scope_id              text,
    events                jsonb       NOT NULL DEFAULT '["failed"]'::jsonb CHECK (jsonb_typeof(events) = 'array'),
    long_running_minutes  integer     CHECK (long_running_minutes IS NULL OR long_running_minutes BETWEEN 1 AND 43200),
    recipients            jsonb       NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(recipients) = 'array'),
    channels              jsonb       NOT NULL DEFAULT '{"notice": true}'::jsonb CHECK (jsonb_typeof(channels) = 'object'),
    throttle_minutes      integer     NOT NULL DEFAULT 15 CHECK (throttle_minutes BETWEEN 0 AND 1440),
    immediate             boolean     NOT NULL DEFAULT true,
    digest                boolean     NOT NULL DEFAULT false,
    digest_hour           integer     NOT NULL DEFAULT 8 CHECK (digest_hour BETWEEN 0 AND 23),
    last_digest_at        timestamptz,
    created_by            text,
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_by            text,
    updated_at            timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, id)
);
CREATE INDEX IF NOT EXISTS ix_cp_workflow_alert_rules_bus
    ON core_platform.cp_workflow_alert_rules (tenant_id, bus_id);

CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_alerts (
    tenant_id    text        NOT NULL,
    id           text        NOT NULL,
    rule_id      text        NOT NULL,
    bus_id       text        NOT NULL DEFAULT '',
    workflow_id  text        NOT NULL DEFAULT '',
    run_id       text,
    kind         text        NOT NULL,
    dedupe_key   text        NOT NULL,
    title        text        NOT NULL DEFAULT '',
    message      text        NOT NULL DEFAULT '',
    link         text,
    status       text        NOT NULL DEFAULT 'PENDING',
    results      jsonb       NOT NULL DEFAULT '{}'::jsonb,
    attempts     integer     NOT NULL DEFAULT 0,
    next_at      timestamptz,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    sent_at      timestamptz,
    PRIMARY KEY (tenant_id, id),
    UNIQUE (tenant_id, rule_id, dedupe_key)
);
CREATE INDEX IF NOT EXISTS ix_cp_workflow_alerts_rule
    ON core_platform.cp_workflow_alerts (tenant_id, rule_id, workflow_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS ix_cp_workflow_alerts_bus
    ON core_platform.cp_workflow_alerts (tenant_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS ix_cp_workflow_alerts_outbox
    ON core_platform.cp_workflow_alerts (next_at) WHERE status IN ('PENDING', 'SENDING');

CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_connection_health (
    tenant_id      text        NOT NULL,
    kind           text        NOT NULL DEFAULT 'connection',
    conn_id        text        NOT NULL,
    status         text        NOT NULL DEFAULT 'UNKNOWN',
    message        text        NOT NULL DEFAULT '',
    checked_at     timestamptz,
    next_check_at  timestamptz,
    failures       integer     NOT NULL DEFAULT 0,
    failing_since  timestamptz,
    expires_on     date,
    alerted_at     timestamptz,
    updated_by     text,
    PRIMARY KEY (tenant_id, kind, conn_id)
);
CREATE INDEX IF NOT EXISTS ix_cp_workflow_connection_health_due
    ON core_platform.cp_workflow_connection_health (next_check_at);

CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_test_cases (
    tenant_id    text        NOT NULL,
    id           text        NOT NULL,
    workflow_id  text        NOT NULL,
    bus_id       text        NOT NULL,
    name         text        NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 120),
    event        jsonb       NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(event) = 'object'),
    vars         jsonb       NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(vars) = 'object'),
    approval     text        NOT NULL DEFAULT 'approved',
    expect       jsonb       NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(expect) = 'object'),
    sort_order   integer     NOT NULL DEFAULT 0,
    last_result  jsonb,
    last_run_at  timestamptz,
    created_by   text,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_by   text,
    updated_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, id)
);
CREATE INDEX IF NOT EXISTS ix_cp_workflow_test_cases_workflow
    ON core_platform.cp_workflow_test_cases (tenant_id, workflow_id, sort_order);

-- The Runs page lists every run of a business, newest first.
CREATE INDEX IF NOT EXISTS ix_cp_workflow_runs_bus
    ON core_platform.cp_workflow_runs (tenant_id, bus_id, cdatetime DESC);

COMMIT;
