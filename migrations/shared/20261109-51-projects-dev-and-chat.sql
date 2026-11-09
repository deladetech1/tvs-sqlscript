-- Projects: GitHub, GitLab and Bitbucket (the developer panel) and Slack / Microsoft Teams
-- channels, all without a registered app: a repository webhook and a channel's incoming
-- webhook address that the customer pastes in.
--
--   prj_dev_connections  one repository webhook: its provider, the inbound address's token
--                        (unique everywhere: a call is matched to its connection before the
--                        business is known), the signing secret sealed (secret_enc, AES-256-GCM
--                        under PROJECTS_WEBHOOK_KEY; secret_hint is its last 4 characters),
--                        which projects it links into (empty = every project of the business),
--                        and its smart-commit and merged-pull-request settings.
--   prj_dev_events       the inbound log: every call to a connection's address, accepted or
--                        refused (a bad signature is logged here, then answered 401). 30 days.
--   prj_dev_links        what the repository told us about a work item: branches, commits,
--                        pull/merge requests, builds and deployments. Metadata and links only,
--                        never code.
--   prj_dev_commands     each smart-commit command applied (or refused), once per commit, so a
--                        redelivered push or a commit pushed to two branches acts once.
--
-- Slack and Teams channels are webhooks of their own kind (prj_webhooks.kind): the same outbox,
-- retries, auto-disable, delivery log and test button. Their address is a secret (whoever has
-- it can post to the channel), so it is sealed (url_enc); url keeps a masked form to show.
-- condition is a work query (the rule editor's language) a work item must match to be told.
--
-- Plan: projects.integrations is PREMIUM (rank 3), never Enterprise-only (20261022-75).
--
-- No grants (the schema's default privileges cover new tables). Idempotent; safe to re-run on
-- every deploy.

BEGIN;

-- ===================================================================== chat channels
ALTER TABLE projects.prj_webhooks ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'webhook';
ALTER TABLE projects.prj_webhooks ADD COLUMN IF NOT EXISTS url_enc text;
ALTER TABLE projects.prj_webhooks ADD COLUMN IF NOT EXISTS condition text NOT NULL DEFAULT '';
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'prj_webhooks_kind_check'
                      AND conrelid = 'projects.prj_webhooks'::regclass) THEN
        ALTER TABLE projects.prj_webhooks ADD CONSTRAINT prj_webhooks_kind_check
            CHECK (kind IN ('webhook', 'slack', 'teams'));
    END IF;
END $$;

-- ===================================================================== repositories
CREATE TABLE IF NOT EXISTS projects.prj_dev_connections (
    id                    text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id             text NOT NULL,
    bus_id                text NOT NULL,
    provider              text NOT NULL
                          CONSTRAINT prj_dev_connections_provider_check CHECK (provider IN ('github', 'gitlab', 'bitbucket')),
    name                  text NOT NULL,
    repo                  text,
    repo_url              text,
    project_ids           text[] NOT NULL DEFAULT '{}',
    inbound_token         text NOT NULL,
    secret_hint           text,
    secret_enc            text,
    default_branch        text,
    smart_commits         boolean NOT NULL DEFAULT true,
    -- NULL: the repository's default branch; '*': every branch; else one branch name.
    smart_commit_branch   text,
    -- Who smart commits act as when the commit's email is nobody's here (NULL: they are refused).
    fallback_user_id      text,
    -- A merged pull request moves its work here: NULL (off), 'category:<todo|in_progress|done>'
    -- or a status id.
    merge_move_to         text,
    is_active             boolean NOT NULL DEFAULT true,
    last_event_at         timestamptz,
    last_error            text,
    delete_status         text NOT NULL DEFAULT 'NOT_DELETED'
                          CONSTRAINT prj_dev_connections_delete_status_check CHECK (delete_status IN ('NOT_DELETED', 'DELETED')),
    cdatetime             timestamptz NOT NULL DEFAULT now(),
    created_by            text,
    updated_at            timestamptz,
    updated_by            text
);
CREATE UNIQUE INDEX IF NOT EXISTS prj_dev_connections_token_uq ON projects.prj_dev_connections (inbound_token);
CREATE INDEX IF NOT EXISTS prj_dev_connections_business_idx ON projects.prj_dev_connections (tenant_id, bus_id)
    WHERE delete_status = 'NOT_DELETED';

CREATE TABLE IF NOT EXISTS projects.prj_dev_events (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    connection_id  text NOT NULL REFERENCES projects.prj_dev_connections (id) ON DELETE CASCADE,
    provider       text NOT NULL,
    event_type     text NOT NULL DEFAULT '',
    delivery_ref   text,
    outcome        text NOT NULL
                   CONSTRAINT prj_dev_events_outcome_check CHECK (outcome IN ('processed', 'ignored', 'unauthorized', 'rejected', 'error')),
    http_status    int NOT NULL,
    detail         text,
    linked         int NOT NULL DEFAULT 0,
    cdatetime      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prj_dev_events_connection_idx ON projects.prj_dev_events (connection_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS prj_dev_events_age_idx ON projects.prj_dev_events (cdatetime);

CREATE TABLE IF NOT EXISTS projects.prj_dev_links (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    connection_id  text NOT NULL REFERENCES projects.prj_dev_connections (id) ON DELETE CASCADE,
    task_id        text NOT NULL REFERENCES projects.prj_tasks (id) ON DELETE CASCADE,
    kind           text NOT NULL
                   CONSTRAINT prj_dev_links_kind_check CHECK (kind IN ('branch', 'commit', 'pull_request', 'build', 'deployment')),
    external_id    text NOT NULL,
    repo           text,
    title          text,
    url            text CONSTRAINT prj_dev_links_url_check CHECK (url IS NULL OR url ~ '^https?://'),
    state          text,
    branch         text,
    sha            text,
    author         text,
    extra          jsonb NOT NULL DEFAULT '{}',
    occurred_at    timestamptz NOT NULL DEFAULT now(),
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS prj_dev_links_uq ON projects.prj_dev_links (connection_id, task_id, kind, external_id);
CREATE INDEX IF NOT EXISTS prj_dev_links_task_idx ON projects.prj_dev_links (task_id, kind, occurred_at DESC);
CREATE INDEX IF NOT EXISTS prj_dev_links_sha_idx ON projects.prj_dev_links (connection_id, sha) WHERE sha IS NOT NULL;

CREATE TABLE IF NOT EXISTS projects.prj_dev_commands (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    connection_id  text NOT NULL REFERENCES projects.prj_dev_connections (id) ON DELETE CASCADE,
    task_id        text NOT NULL REFERENCES projects.prj_tasks (id) ON DELETE CASCADE,
    sha            text NOT NULL,
    position       int NOT NULL,
    command        text NOT NULL,
    argument       text,
    outcome        text NOT NULL
                   CONSTRAINT prj_dev_commands_outcome_check CHECK (outcome IN ('done', 'refused', 'failed')),
    detail         text,
    actor_user_id  text,
    cdatetime      timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS prj_dev_commands_once_uq ON projects.prj_dev_commands (connection_id, sha, task_id, position);
CREATE INDEX IF NOT EXISTS prj_dev_commands_task_idx ON projects.prj_dev_commands (task_id, cdatetime DESC);

-- ===================================================================== plan feature
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('projects.integrations', 'app-projects', 'GitHub, GitLab, Bitbucket, Slack & Teams', 3,
 'Link branches, commits, pull requests, builds and deployments to work, smart commits, and work updates in Slack and Microsoft Teams')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

-- ===================================================================== invariants
DO $$
BEGIN
    IF to_regclass('projects.prj_dev_connections_token_uq') IS NULL THEN
        RAISE EXCEPTION 'prj_dev_connections has no unique index on inbound_token';
    END IF;
    -- A chat channel's address is only ever stored sealed.
    IF EXISTS (SELECT 1 FROM projects.prj_webhooks WHERE kind <> 'webhook' AND delete_status = 'NOT_DELETED' AND url_enc IS NULL) THEN
        RAISE EXCEPTION 'a Projects chat channel has no sealed address';
    END IF;
    IF EXISTS (SELECT 1 FROM projects.prj_dev_links l JOIN projects.prj_dev_connections c ON c.id = l.connection_id
                WHERE c.tenant_id <> l.tenant_id OR c.bus_id <> l.bus_id) THEN
        RAISE EXCEPTION 'a Projects development link belongs to a connection of another business';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM core_platform.cp_app_feature_catalog
                    WHERE feature_key = 'projects.integrations' AND min_tier_rank = 3 AND is_active) THEN
        RAISE EXCEPTION 'projects.integrations must be an active PREMIUM feature';
    END IF;
END $$;

COMMIT;
