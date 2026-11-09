-- Core Platform: AI -- one place an organisation connects AI, and every TroveSuite app uses it.
--
-- Settings > AI in Core. An organisation connects any provider -- Anthropic (Claude), OpenAI,
-- Azure OpenAI, Google Gemini, AWS Bedrock, or ANY OpenAI-compatible endpoint (Ollama, vLLM,
-- LM Studio, LocalAI, TGI, LiteLLM, a corporate gateway), including models it hosts itself. Apps
-- never hold AI keys: they call Core's gateway (POST /api/v1/ai/complete | structured | embed,
-- or the /ai/service/* routes with SERVICE_SECRET), and Core picks the connection and model,
-- applies the organisation's data policy, enforces caps and the plan, and meters usage.
-- Design and on-prem guide: tvs-coreplatform-bk docs/ai/README.md.
--
--   cp_ai_connections   a provider connection, for the organisation (bus_id NULL) or one business
--                       (an override, as business email overrides the organisation's). The API key
--                       and custom headers are Fernet-encrypted by Core (secret_crypto, "enc::") and
--                       never returned. is_internal: the admin says this endpoint is on their own
--                       network -- it may then use a private address, but ONLY where the deployment
--                       allows private AI endpoints (self-hosted installs; never our SaaS default).
--   cp_ai_policies      the organisation's data policy: AI on/off, which apps may use it, whether
--                       customer text may be sent, redaction, "never leave our network", monthly
--                       caps (organisation and per app), whether prompts are kept for audit.
--   cp_ai_usage         one row per gateway request: metadata only (who, which app, purpose,
--                       connection, model, tokens, outcome, latency) -- never the prompt.
--   cp_ai_prompt_log    prompts and answers, ONLY when the organisation turned "keep prompts for
--                       audit" on (off by default). Kept 30 days.
--
-- Plan: ai.gateway at ADVANCE (rank 2). Never rank 4: ENTERPRISE is the same product self-hosted.
--
-- Idempotent; re-runs on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS core_platform.cp_ai_connections (
    tenant_id          text        NOT NULL,
    id                 text        NOT NULL,
    -- NULL: the organisation's. A business's own connection overrides the organisation's for it.
    bus_id             text,
    name               text        NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 120),
    provider           text        NOT NULL CHECK (provider IN
                           ('anthropic', 'openai', 'azure_openai', 'gemini', 'bedrock', 'openai_compatible')),
    base_url           text        NOT NULL CHECK (length(base_url) BETWEEN 8 AND 2000),
    -- Fernet-encrypted by Core ("enc::..."); NULL for an endpoint that needs no key (a local Ollama).
    api_key            text,
    -- Custom request headers, a JSON object Fernet-encrypted as one string (they often carry auth).
    headers            text,
    -- Provider specifics: azure api_version; bedrock region, auth (api_key | sigv4), access_key_id;
    -- openai_compatible structured_mode (json_schema | json_object | prompt).
    settings           jsonb       NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(settings) = 'object'),
    -- The model names this connection offers (["llama3.1:8b", "qwen2.5:14b"]).
    models             jsonb       NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(models) = 'array'),
    -- The default model per purpose: {"chat": .., "summarise": .., "extract": .., "embed": ..}.
    purpose_models     jsonb       NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(purpose_models) = 'object'),
    timeout_seconds    integer     NOT NULL DEFAULT 60 CHECK (timeout_seconds BETWEEN 5 AND 600),
    max_tokens         integer     NOT NULL DEFAULT 2048 CHECK (max_tokens BETWEEN 16 AND 128000),
    temperature        numeric(3,2) CHECK (temperature IS NULL OR temperature BETWEEN 0 AND 2),
    is_internal        boolean     NOT NULL DEFAULT false,
    -- An extra CA bundle (PEM) trusted for THIS connection only: internal endpoints with a private CA.
    ca_bundle          text        CHECK (ca_bundle IS NULL OR length(ca_bundle) <= 65536),
    is_enabled         boolean     NOT NULL DEFAULT true,
    -- The one the scope (organisation, or the business) uses unless an app is routed elsewhere.
    is_default         boolean     NOT NULL DEFAULT false,
    last_test_at       timestamptz,
    last_test_ok       boolean,
    last_test_message  text,
    created_by         text,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_by         text,
    updated_at         timestamptz NOT NULL DEFAULT now(),
    deleted_at         timestamptz,
    PRIMARY KEY (tenant_id, id)
);
CREATE INDEX IF NOT EXISTS ix_cp_ai_connections_scope
    ON core_platform.cp_ai_connections (tenant_id, bus_id) WHERE deleted_at IS NULL;
-- At most one default per scope (the organisation, or one business).
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_ai_connections_default
    ON core_platform.cp_ai_connections (tenant_id, coalesce(bus_id, ''))
    WHERE is_default AND deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS core_platform.cp_ai_policies (
    tenant_id              text        NOT NULL PRIMARY KEY,
    -- The master switch. Off: no app gets an answer, whatever else is set.
    enabled                boolean     NOT NULL DEFAULT false,
    -- {"app-helpdesk": {"enabled": true, "monthly_request_cap": 500, "monthly_token_cap": null,
    --   "connection_id": null}, ...}. An app missing here may NOT use AI.
    apps                   jsonb       NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(apps) = 'object'),
    -- Whether text about customers (tickets, messages, receipts) may be sent at all.
    allow_customer_data    boolean     NOT NULL DEFAULT false,
    -- Replace email addresses and phone numbers before anything is sent.
    redact_personal_data   boolean     NOT NULL DEFAULT true,
    -- "Never leave our network": only internal connections whose addresses are all private.
    local_only             boolean     NOT NULL DEFAULT false,
    monthly_request_cap    integer     CHECK (monthly_request_cap IS NULL OR monthly_request_cap >= 0),
    monthly_token_cap      bigint      CHECK (monthly_token_cap IS NULL OR monthly_token_cap >= 0),
    -- Keep prompts and answers for audit (cp_ai_prompt_log, 30 days). Off by default.
    keep_prompts           boolean     NOT NULL DEFAULT false,
    updated_by             text,
    updated_at             timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS core_platform.cp_ai_usage (
    id               bigint      GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    tenant_id        text        NOT NULL,
    bus_id           text,
    app_id           text        NOT NULL,
    purpose          text        NOT NULL,
    route            text        NOT NULL CHECK (route IN ('complete', 'structured', 'embed', 'test')),
    -- user: a signed-in person through Core; service: an app backend with SERVICE_SECRET.
    via              text        NOT NULL CHECK (via IN ('user', 'service')),
    user_id          text,
    connection_id    text,
    provider         text,
    model            text,
    outcome          text        NOT NULL CHECK (outcome IN
                         ('ok', 'refused', 'capped', 'not_configured', 'error', 'timeout')),
    -- The reason code for anything but ok (AI_APP_DISABLED, AI_PROVIDER_ERROR, ...).
    reason           text,
    tokens_in        integer     NOT NULL DEFAULT 0,
    tokens_out       integer     NOT NULL DEFAULT 0,
    latency_ms       integer,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_cp_ai_usage_tenant_month
    ON core_platform.cp_ai_usage (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS ix_cp_ai_usage_tenant_app
    ON core_platform.cp_ai_usage (tenant_id, app_id, cdatetime DESC);

CREATE TABLE IF NOT EXISTS core_platform.cp_ai_prompt_log (
    id          bigint      GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    tenant_id   text        NOT NULL,
    usage_id    bigint      NOT NULL,
    request     jsonb       NOT NULL,
    response    text,
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_cp_ai_prompt_log_tenant
    ON core_platform.cp_ai_prompt_log (tenant_id, cdatetime);

-- ===================================================================== the plan
DO $$
BEGIN
    IF to_regclass('core_platform.cp_platform_feature_catalog') IS NOT NULL THEN
        INSERT INTO core_platform.cp_platform_feature_catalog (feature_key, title, min_tier_rank, description)
        VALUES ('ai.gateway', 'AI for every app', 2,
                'Connect Claude, OpenAI, Azure OpenAI, Gemini, Bedrock or your own self-hosted models once, for every app')
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
         WHERE feature_key = 'ai.gateway' AND min_tier_rank > 3) THEN
        RAISE EXCEPTION 'ai.gateway must never be gated at rank 4 (ENTERPRISE is self-hosted, not a bigger plan)';
    END IF;
END $$;

COMMIT;
