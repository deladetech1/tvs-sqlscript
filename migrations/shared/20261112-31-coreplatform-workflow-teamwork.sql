-- Core Platform: Workflows teamwork, control and sharing.
--
--   cp_workflow_projects        + restricted       a restricted project is seen only by the people and
--                                                  groups shared on it (and Owner / Admin); otherwise
--                                                  everyone with Workflows access in the business, as
--                                                  before. The default project ("General") is never
--                                                  restricted: every new workflow lands there.
--                               + review_required  publishing any of its workflows needs a second person
--   cp_workflows                + review_required  the same, for one workflow
--   cp_workflow_project_shares  who a project is shared with: a person or a group, at view | run | edit
--   cp_workflow_change_requests "publish this draft" waiting for someone other than its author (four eyes);
--                               cancelled when the draft changes after it was asked
--   cp_workflow_scheduled_publishes   "publish at 18:00"; cancelled when the draft changes
--   cp_workflow_versions        + release_note, change_request_id, approved_by
--   cp_workflow_comments        threaded comments on a workflow or one of its steps, with @mentions
--   cp_workflow_audit_logs      who did what to workflows, projects, folders, shares, connections,
--                               variables, automation accounts, templates and API tokens. The suite's
--                               audit-log shape (tenant_id + cdatetime): retention purges it by itself
--                               (20260731-01, the app-coreplatform sentinel).
--   cp_workflow_org_templates   the organisation's own templates (secrets, connections and people removed)
--   cp_workflow_api_tokens      organisation API tokens for Workflows' public API: hashed, scoped, per
--                               business, optional expiry
--   cp_workflow_api_audit_logs  one row per public API request (the audit entry, and what the rate limit
--                               counts); the same audit shape, so retention purges it too
--
-- Idempotent; re-runs every deploy. Every object is new here (no CHECK list of an older file is widened),
-- and the backend tolerates all of it being missing (a silo the shared SQL has not reached yet): no
-- project is restricted, nothing needs review, and the new screens say they are not set up yet.

BEGIN;

-- ===================================================================== sharing and review switches
DO $$
BEGIN
    IF to_regclass('core_platform.cp_workflow_projects') IS NOT NULL THEN
        ALTER TABLE core_platform.cp_workflow_projects ADD COLUMN IF NOT EXISTS restricted boolean NOT NULL DEFAULT false;
        ALTER TABLE core_platform.cp_workflow_projects ADD COLUMN IF NOT EXISTS review_required boolean NOT NULL DEFAULT false;
        -- The default project is never restricted (a new workflow always lands there).
        UPDATE core_platform.cp_workflow_projects SET restricted = false WHERE is_default AND restricted;
    END IF;
END $$;

ALTER TABLE core_platform.cp_workflows ADD COLUMN IF NOT EXISTS review_required boolean NOT NULL DEFAULT false;
ALTER TABLE core_platform.cp_workflow_versions ADD COLUMN IF NOT EXISTS release_note text;
ALTER TABLE core_platform.cp_workflow_versions ADD COLUMN IF NOT EXISTS change_request_id text;
ALTER TABLE core_platform.cp_workflow_versions ADD COLUMN IF NOT EXISTS approved_by text;

CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_project_shares (
    tenant_id       text        NOT NULL,
    id              text        NOT NULL,
    bus_id          text        NOT NULL,
    project_id      text        NOT NULL,
    principal_type  text        NOT NULL CHECK (principal_type IN ('user', 'group')),
    principal_id    text        NOT NULL,
    level           text        NOT NULL CHECK (level IN ('view', 'run', 'edit')),
    created_by      text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_by      text,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, id),
    UNIQUE (tenant_id, project_id, principal_type, principal_id)
);
CREATE INDEX IF NOT EXISTS ix_cp_workflow_project_shares_principal
    ON core_platform.cp_workflow_project_shares (tenant_id, principal_type, principal_id);

-- ===================================================================== review before publish
CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_change_requests (
    tenant_id         text        NOT NULL,
    id                text        NOT NULL,
    bus_id            text        NOT NULL,
    workflow_id       text        NOT NULL,
    project_id        text,
    status            text        NOT NULL DEFAULT 'PENDING'
                      CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED', 'BYPASSED')),
    -- sha256 of the draft as asked (its canvas layout aside): a different draft cancels the request.
    draft_hash        text        NOT NULL,
    definition        jsonb       NOT NULL DEFAULT '{}'::jsonb,
    base_version_id   text,
    release_note      text,
    publish_at        timestamptz,
    requested_by      text        NOT NULL,
    -- Who last saved the draft when it was asked: they cannot approve it either.
    draft_by          text,
    reviewers         jsonb       NOT NULL DEFAULT '[]'::jsonb,
    requested_at      timestamptz NOT NULL DEFAULT now(),
    decided_by        text,
    decided_at        timestamptz,
    decision_comment  text,
    cancel_reason     text,
    bypass_reason     text,
    version_id        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, id)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_workflow_change_requests_pending
    ON core_platform.cp_workflow_change_requests (tenant_id, workflow_id) WHERE status = 'PENDING';
CREATE INDEX IF NOT EXISTS ix_cp_workflow_change_requests_bus
    ON core_platform.cp_workflow_change_requests (tenant_id, bus_id, status, requested_at DESC);
CREATE INDEX IF NOT EXISTS ix_cp_workflow_change_requests_workflow
    ON core_platform.cp_workflow_change_requests (tenant_id, workflow_id, requested_at DESC);

-- ===================================================================== scheduled publish
CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_scheduled_publishes (
    tenant_id          text        NOT NULL,
    id                 text        NOT NULL,
    bus_id             text        NOT NULL,
    workflow_id        text        NOT NULL,
    publish_at         timestamptz NOT NULL,
    draft_hash         text        NOT NULL,
    release_note       text,
    change_request_id  text,
    approved_by        text,
    scheduled_by       text        NOT NULL,
    -- The version is published as this person (runs act as the publisher).
    publish_as         text        NOT NULL,
    status             text        NOT NULL DEFAULT 'PENDING'
                       CHECK (status IN ('PENDING', 'DONE', 'CANCELLED', 'FAILED')),
    cancel_reason      text,
    error              text,
    version_id         text,
    created_at         timestamptz NOT NULL DEFAULT now(),
    done_at            timestamptz,
    PRIMARY KEY (tenant_id, id)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_workflow_scheduled_publishes_pending
    ON core_platform.cp_workflow_scheduled_publishes (tenant_id, workflow_id) WHERE status = 'PENDING';
CREATE INDEX IF NOT EXISTS ix_cp_workflow_scheduled_publishes_due
    ON core_platform.cp_workflow_scheduled_publishes (publish_at) WHERE status = 'PENDING';

-- ===================================================================== comments
CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_comments (
    tenant_id    text        NOT NULL,
    id           text        NOT NULL,
    bus_id       text        NOT NULL,
    workflow_id  text        NOT NULL,
    parent_id    text,
    step_id      text,
    body         text        NOT NULL CHECK (length(btrim(body)) BETWEEN 1 AND 5000),
    mentions     jsonb       NOT NULL DEFAULT '[]'::jsonb,
    author_id    text        NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),
    edited_at    timestamptz,
    deleted_at   timestamptz,
    resolved_at  timestamptz,
    resolved_by  text,
    PRIMARY KEY (tenant_id, id)
);
CREATE INDEX IF NOT EXISTS ix_cp_workflow_comments_workflow
    ON core_platform.cp_workflow_comments (tenant_id, workflow_id, created_at);

-- ===================================================================== the activity log
CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,
    bus_id                 text,
    entity_type            text        NOT NULL,
    entity_id              text        NOT NULL,
    entity_name            text,
    action                 text        NOT NULL,
    workflow_id            text,
    project_id             text,
    old_data               jsonb,
    new_data               jsonb,
    changes                jsonb       NOT NULL DEFAULT '[]'::jsonb,
    description            text,
    performed_by           text,
    performed_by_email     text,
    performed_by_contact   text,
    performed_by_fullname  text,
    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_cp_workflow_audit_logs_when
    ON core_platform.cp_workflow_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS ix_cp_workflow_audit_logs_workflow
    ON core_platform.cp_workflow_audit_logs (tenant_id, workflow_id, cdatetime DESC) WHERE workflow_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_cp_workflow_audit_logs_entity
    ON core_platform.cp_workflow_audit_logs (tenant_id, entity_type, entity_id);

-- ===================================================================== organisation templates
CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_org_templates (
    tenant_id           text        NOT NULL,
    id                  text        NOT NULL,
    name                text        NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 120),
    description         text        NOT NULL DEFAULT '',
    category            text        NOT NULL DEFAULT 'integrations',
    tags                jsonb       NOT NULL DEFAULT '[]'::jsonb,
    definition          jsonb       NOT NULL CHECK (jsonb_typeof(definition) = 'object'),
    fill_ins            jsonb       NOT NULL DEFAULT '[]'::jsonb,
    source_workflow_id  text,
    created_by          text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_by          text,
    updated_at          timestamptz NOT NULL DEFAULT now(),
    deleted_at          timestamptz,
    PRIMARY KEY (tenant_id, id)
);
CREATE INDEX IF NOT EXISTS ix_cp_workflow_org_templates_live
    ON core_platform.cp_workflow_org_templates (tenant_id) WHERE deleted_at IS NULL;

-- ===================================================================== the public API
CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_api_tokens (
    tenant_id     text        NOT NULL,
    id            text        NOT NULL,
    bus_id        text        NOT NULL,
    name          text        NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 80),
    -- The first characters in clear, to tell tokens apart; the token itself is only ever hashed.
    prefix        text        NOT NULL,
    token_hash    text        NOT NULL,
    scopes        jsonb       NOT NULL DEFAULT '[]'::jsonb,
    expires_at    timestamptz,
    created_by    text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    last_used_at  timestamptz,
    last_used_ip  text,
    revoked_at    timestamptz,
    revoked_by    text,
    PRIMARY KEY (tenant_id, id)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_workflow_api_tokens_hash
    ON core_platform.cp_workflow_api_tokens (token_hash);

CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_api_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,
    bus_id                 text,
    entity_id              text        NOT NULL,           -- the token
    entity_name            text,
    action                 text        NOT NULL,           -- runs.start | runs.read | workflows.read
    old_data               jsonb,
    new_data               jsonb,
    description            text,
    performed_by           text,
    performed_by_fullname  text,
    workflow_id            text,
    run_id                 text,
    status_code            integer,
    ip_address             text,
    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_cp_workflow_api_audit_logs_token
    ON core_platform.cp_workflow_api_audit_logs (tenant_id, entity_id, cdatetime DESC);

-- ===================================================================== invariants
DO $$
BEGIN
    -- Nested, not "IS NOT NULL AND EXISTS (...)": the whole condition is planned at once, so a
    -- database without the projects table would fail on the name even though it is never read.
    IF to_regclass('core_platform.cp_workflow_projects') IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM core_platform.cp_workflow_projects WHERE is_default AND restricted) THEN
            RAISE EXCEPTION 'a default Workflows project must never be restricted';
        END IF;
    END IF;
    -- Retention finds audit tables by their shape: both must keep tenant_id and cdatetime.
    IF (SELECT count(*) FROM information_schema.columns
         WHERE table_schema = 'core_platform'
           AND table_name IN ('cp_workflow_audit_logs', 'cp_workflow_api_audit_logs')
           AND column_name IN ('tenant_id', 'cdatetime')) <> 4 THEN
        RAISE EXCEPTION 'Workflows audit tables must carry tenant_id and cdatetime (activity-log retention)';
    END IF;
END $$;

COMMIT;
