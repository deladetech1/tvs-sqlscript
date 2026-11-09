-- Projects: connect outside tools, the way they connect to Jira.
--
--   prj_api_tokens          Projects' own API tokens, in Core's style and Help Desk's
--                           (prefix tvs_pj_, 32 random bytes, shown once): only the sha256
--                           key_hash is stored, unique everywhere because a request is matched
--                           to its token before the business is known. A token is a service
--                           identity of one business: scopes read and/or write, optionally
--                           limited to some projects (project_ids; empty = every project), and
--                           the permission pairs those scopes stand for (projects|… only).
--   prj_webhooks            signed webhooks (https only) for work, sprint and time events,
--                           optionally limited to some projects. The signing secret is stored
--                           sealed (secret_enc, AES-256-GCM under PROJECTS_WEBHOOK_KEY), never
--                           in clear; secret_hint is its last 4 characters.
--   prj_webhook_deliveries  the outbox: one delivery per event per webhook, retried until
--                           delivered or dead, deduplicated per webhook on idempotency_key.
--   prj_rate_windows        the API tokens' shared rate-limit counters (every replica adds to
--                           one per-minute window), in the app's pooled database.
--
-- Plan: projects.api and projects.webhooks are PREMIUM (rank 3), never Enterprise-only
-- (20261022-75). The API answers 403 plan_required below that; deliveries pause.
--
-- The notification kind 'integration' (a webhook that turned itself off) is in the kind list
-- of 20261018-01, the one file that owns it.
--
-- No grants (the schema's default privileges cover new tables). Idempotent; safe to re-run on
-- every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS projects.prj_api_tokens (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    label         text NOT NULL,
    key_prefix    text NOT NULL,
    key_hash      text NOT NULL,
    scopes        text[] NOT NULL DEFAULT '{}'
                  CONSTRAINT prj_api_tokens_scopes_check CHECK (scopes <@ ARRAY['read', 'write']::text[] AND cardinality(scopes) > 0),
    project_ids   text[] NOT NULL DEFAULT '{}',
    permissions   text[] NOT NULL DEFAULT '{}',
    expires_at    timestamptz,
    last_used_at  timestamptz,
    last_used_ip  text,
    revoked_at    timestamptz,
    revoked_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text,
    updated_at    timestamptz,
    updated_by    text
);
CREATE UNIQUE INDEX IF NOT EXISTS prj_api_tokens_key_hash_uq ON projects.prj_api_tokens (key_hash);
CREATE INDEX IF NOT EXISTS prj_api_tokens_business_idx ON projects.prj_api_tokens (tenant_id, bus_id, cdatetime DESC);

CREATE TABLE IF NOT EXISTS projects.prj_webhooks (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    name             text NOT NULL,
    url              text NOT NULL CONSTRAINT prj_webhooks_url_check CHECK (url ~ '^https://'),
    secret_hint      text,
    secret_enc       text,
    event_types      text[] NOT NULL DEFAULT '{}',
    project_ids      text[] NOT NULL DEFAULT '{}',
    is_active        boolean NOT NULL DEFAULT true,
    failure_count    int NOT NULL DEFAULT 0,
    disabled_reason  text,
    delete_status    text NOT NULL DEFAULT 'NOT_DELETED'
                     CONSTRAINT prj_webhooks_delete_status_check CHECK (delete_status IN ('NOT_DELETED', 'DELETED')),
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz,
    updated_by       text
);
CREATE INDEX IF NOT EXISTS prj_webhooks_business_idx ON projects.prj_webhooks (tenant_id, bus_id)
    WHERE is_active AND delete_status = 'NOT_DELETED';

CREATE TABLE IF NOT EXISTS projects.prj_webhook_deliveries (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    webhook_id       text NOT NULL REFERENCES projects.prj_webhooks (id) ON DELETE CASCADE,
    event_id         text NOT NULL,
    event_type       text NOT NULL,
    payload          jsonb NOT NULL,
    idempotency_key  text NOT NULL,
    state            text NOT NULL DEFAULT 'pending'
                     CONSTRAINT prj_webhook_deliveries_state_check CHECK (state IN ('pending', 'delivered', 'failed', 'dead')),
    attempts         int NOT NULL DEFAULT 0,
    next_attempt_at  timestamptz NOT NULL DEFAULT now(),
    response_status  int,
    response_ms      int,
    last_error       text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz,
    updated_by       text
);
CREATE UNIQUE INDEX IF NOT EXISTS prj_webhook_deliveries_idempotency_uq ON projects.prj_webhook_deliveries (webhook_id, idempotency_key);
CREATE INDEX IF NOT EXISTS prj_webhook_deliveries_webhook_idx ON projects.prj_webhook_deliveries (webhook_id, cdatetime DESC);
-- The delivery job reads pending and failed deliveries by next attempt, across businesses.
CREATE INDEX IF NOT EXISTS prj_webhook_deliveries_due_idx
    ON projects.prj_webhook_deliveries (next_attempt_at) WHERE state IN ('pending', 'failed');

CREATE TABLE IF NOT EXISTS projects.prj_rate_windows (
    bucket        text NOT NULL,
    window_start  timestamptz NOT NULL,
    count         int NOT NULL DEFAULT 0,
    PRIMARY KEY (bucket, window_start)
);

-- ===================================================================== plan features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('projects.api',      'app-projects', 'REST API & API Tokens', 3, 'Connect your own tools and scripts to Projects with scoped API tokens'),
('projects.webhooks', 'app-projects', 'Webhooks',              3, 'Tell other systems the moment work is created, moved, assigned, commented or done')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

-- ===================================================================== invariants
DO $$
BEGIN
    IF to_regclass('projects.prj_api_tokens_key_hash_uq') IS NULL THEN
        RAISE EXCEPTION 'prj_api_tokens has no unique index on key_hash';
    END IF;
    -- A token holds Projects pairs only.
    IF EXISTS (SELECT 1 FROM projects.prj_api_tokens t, unnest(t.permissions) AS pair
                WHERE pair NOT LIKE 'projects|%') THEN
        RAISE EXCEPTION 'a Projects API token carries a permission that is not a Projects pair';
    END IF;
    IF EXISTS (SELECT 1 FROM projects.prj_webhook_deliveries d JOIN projects.prj_webhooks w ON w.id = d.webhook_id
                WHERE w.tenant_id <> d.tenant_id OR w.bus_id <> d.bus_id) THEN
        RAISE EXCEPTION 'a Projects webhook delivery belongs to a webhook of another business';
    END IF;
    IF (SELECT count(*) FROM core_platform.cp_app_feature_catalog
         WHERE feature_key IN ('projects.api', 'projects.webhooks') AND min_tier_rank = 3 AND is_active) <> 2 THEN
        RAISE EXCEPTION 'projects.api and projects.webhooks must be active PREMIUM features';
    END IF;
END $$;

COMMIT;
