-- Projects: the one-click Slack app, Microsoft Teams bot and GitHub App (Settings > Integrations
-- > Apps). The paste-a-URL connections (20261109-51) keep working beside them.
--
--   prj_app_installs  one installation bound to one business: a Slack workspace (external_id =
--                     team id), a Microsoft 365 tenant that runs the Teams bot (the Entra tenant
--                     id) or a GitHub App installation (its installation id). A Slack bot token is
--                     sealed (token_enc, AES-256-GCM under PROJECTS_WEBHOOK_KEY, bound to the
--                     install); nothing else secret is kept. One live install per provider and
--                     external id.
--   prj_app_routes    which database answers an installation: the provider's call names only its
--                     workspace / tenant / installation, never our tenant. Read and written in the
--                     shared (pooled) database for every tenant; site is the silo tenant's address
--                     (NULL: the pooled database). Also holds a Teams link code's address while it
--                     is valid (provider 'teams_code', external_id = sha256 of the code).
--   prj_app_states    a pending install: the OAuth state (Slack, GitHub) or the Teams link code,
--                     stored as its sha256, bound to the tenant, business, admin and the Projects
--                     address the admin came from; single use, expires in 10 (OAuth) or 30 (code)
--                     minutes.
--
-- prj_webhooks: Slack-app and Teams-bot channels are webhooks of their own kinds ('slack_app',
-- 'teams_bot'), on the same outbox; install_id names the install, target the channel's name to
-- show, config what posting needs (Slack channel id; Teams service URL and conversation id).
-- prj_dev_connections: app_install_id marks a repository connected through the GitHub App (no
-- pasted secret: the App's webhook secret signs it).
--
-- Plan: projects.integrations (PREMIUM), as 20261109-51.
-- No grants (the schema's default privileges cover new tables). Idempotent; safe to re-run on
-- every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS projects.prj_app_installs (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    provider       text NOT NULL
                   CONSTRAINT prj_app_installs_provider_check CHECK (provider IN ('slack', 'teams', 'github')),
    external_id    text NOT NULL,
    external_name  text,
    account_type   text,
    token_enc      text,
    bot_user_id    text,
    scopes         text,
    extra          jsonb NOT NULL DEFAULT '{}',
    status         text NOT NULL DEFAULT 'active'
                   CONSTRAINT prj_app_installs_status_check CHECK (status IN ('active', 'suspended')),
    installed_by   text,
    last_event_at  timestamptz,
    last_error     text,
    delete_status  text NOT NULL DEFAULT 'NOT_DELETED'
                   CONSTRAINT prj_app_installs_delete_status_check CHECK (delete_status IN ('NOT_DELETED', 'DELETED')),
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz,
    updated_by     text
);
CREATE UNIQUE INDEX IF NOT EXISTS prj_app_installs_external_uq ON projects.prj_app_installs (provider, external_id)
    WHERE delete_status = 'NOT_DELETED';
CREATE INDEX IF NOT EXISTS prj_app_installs_business_idx ON projects.prj_app_installs (tenant_id, bus_id)
    WHERE delete_status = 'NOT_DELETED';

CREATE TABLE IF NOT EXISTS projects.prj_app_routes (
    provider     text NOT NULL,
    external_id  text NOT NULL,
    site         text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    expires_at   timestamptz,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (provider, external_id)
);

CREATE TABLE IF NOT EXISTS projects.prj_app_states (
    id          text PRIMARY KEY,
    provider    text NOT NULL,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    user_id     text NOT NULL,
    origin      text,
    expires_at  timestamptz NOT NULL,
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prj_app_states_age_idx ON projects.prj_app_states (expires_at);

-- ===================================================================== channels
ALTER TABLE projects.prj_webhooks ADD COLUMN IF NOT EXISTS install_id text;
ALTER TABLE projects.prj_webhooks ADD COLUMN IF NOT EXISTS target text;
ALTER TABLE projects.prj_webhooks ADD COLUMN IF NOT EXISTS config jsonb NOT NULL DEFAULT '{}';
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'prj_webhooks_kind_check'
                  AND conrelid = 'projects.prj_webhooks'::regclass
                  AND pg_get_constraintdef(oid) NOT LIKE '%slack_app%') THEN
        ALTER TABLE projects.prj_webhooks DROP CONSTRAINT prj_webhooks_kind_check;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'prj_webhooks_kind_check'
                      AND conrelid = 'projects.prj_webhooks'::regclass) THEN
        ALTER TABLE projects.prj_webhooks ADD CONSTRAINT prj_webhooks_kind_check
            CHECK (kind IN ('webhook', 'slack', 'teams', 'zapier', 'make', 'n8n', 'slack_app', 'teams_bot'));
    END IF;
END $$;
CREATE INDEX IF NOT EXISTS prj_webhooks_install_idx ON projects.prj_webhooks (install_id)
    WHERE install_id IS NOT NULL AND delete_status = 'NOT_DELETED';

-- ===================================================================== repositories
ALTER TABLE projects.prj_dev_connections ADD COLUMN IF NOT EXISTS app_install_id text;
CREATE INDEX IF NOT EXISTS prj_dev_connections_app_idx ON projects.prj_dev_connections (app_install_id, lower(repo))
    WHERE app_install_id IS NOT NULL AND delete_status = 'NOT_DELETED';

COMMIT;
