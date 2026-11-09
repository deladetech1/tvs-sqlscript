-- Projects: Zapier / Make / n8n subscriptions, Sentry and Datadog alerts as bugs, and
-- subscribable calendar feeds. All built on what 20261109-41 and -51 made.
--
--   prj_webhooks (kind)     zapier, make and n8n join webhook, slack and teams: a REST-hook
--                           subscription an automation platform makes with an API token
--                           (token_id). The same outbox, retries, auto-disable and delivery log.
--                           Revoking the token turns its subscriptions off.
--   prj_dev_connections     sentry and datadog join github, gitlab and bitbucket: the same public
--                           inbound address (/projects/hooks/v1/<provider>/<token>), the sealed
--                           secret, the call log and rate limits. The alert_* columns say which
--                           bug to make (the connection's one project), how often a repeating
--                           alert may comment, and what resolving / regressing does.
--   prj_alert_issues        one row per provider issue (Sentry issue id, Datadog aggregation key):
--                           the bug it made, its count and first/last seen, so further events
--                           update it and never make a second bug.
--   prj_calendar_feeds      a person's secret iCal address ("my work", or one project's): only the
--                           sha256 of its token is stored; revoking or regenerating ends the old
--                           address at once.
--
-- Plan: projects.integrations (PREMIUM, 20261109-51), projects.api and projects.webhooks
-- (20261109-41). No new feature. This file now owns projects.integrations' title and description.
--
-- No grants (the schema's default privileges cover new tables). Idempotent; safe to re-run on
-- every deploy.

BEGIN;

-- ===================================================================== automation platforms
ALTER TABLE projects.prj_webhooks ADD COLUMN IF NOT EXISTS token_id text;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'prj_webhooks_kind_check'
                  AND conrelid = 'projects.prj_webhooks'::regclass
                  AND pg_get_constraintdef(oid) NOT LIKE '%zapier%') THEN
        ALTER TABLE projects.prj_webhooks DROP CONSTRAINT prj_webhooks_kind_check;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'prj_webhooks_kind_check'
                      AND conrelid = 'projects.prj_webhooks'::regclass) THEN
        ALTER TABLE projects.prj_webhooks ADD CONSTRAINT prj_webhooks_kind_check
            CHECK (kind IN ('webhook', 'slack', 'teams', 'zapier', 'make', 'n8n'));
    END IF;
END $$;
CREATE INDEX IF NOT EXISTS prj_webhooks_token_idx ON projects.prj_webhooks (token_id) WHERE token_id IS NOT NULL;

-- ===================================================================== alerts (Sentry, Datadog)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'prj_dev_connections_provider_check'
                  AND conrelid = 'projects.prj_dev_connections'::regclass
                  AND pg_get_constraintdef(oid) NOT LIKE '%sentry%') THEN
        ALTER TABLE projects.prj_dev_connections DROP CONSTRAINT prj_dev_connections_provider_check;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'prj_dev_connections_provider_check'
                      AND conrelid = 'projects.prj_dev_connections'::regclass) THEN
        ALTER TABLE projects.prj_dev_connections ADD CONSTRAINT prj_dev_connections_provider_check
            CHECK (provider IN ('github', 'gitlab', 'bitbucket', 'sentry', 'datadog'));
    END IF;
END $$;
ALTER TABLE projects.prj_dev_connections ADD COLUMN IF NOT EXISTS alert_kind text NOT NULL DEFAULT 'bug';
ALTER TABLE projects.prj_dev_connections ADD COLUMN IF NOT EXISTS alert_assignee_user_id text;
ALTER TABLE projects.prj_dev_connections ADD COLUMN IF NOT EXISTS comment_every_minutes int NOT NULL DEFAULT 60;
-- NULL: off (the default); 'category:<todo|in_progress|done>' or a status id of the project.
ALTER TABLE projects.prj_dev_connections ADD COLUMN IF NOT EXISTS resolve_move_to text;
ALTER TABLE projects.prj_dev_connections ADD COLUMN IF NOT EXISTS reopen_on_regression boolean NOT NULL DEFAULT true;
-- Datadog does not sign: the address is the secret, plus (when true) the X-Projects-Secret header.
ALTER TABLE projects.prj_dev_connections ADD COLUMN IF NOT EXISTS require_header boolean NOT NULL DEFAULT true;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'prj_dev_connections_comment_every_check'
                      AND conrelid = 'projects.prj_dev_connections'::regclass) THEN
        ALTER TABLE projects.prj_dev_connections ADD CONSTRAINT prj_dev_connections_comment_every_check
            CHECK (comment_every_minutes BETWEEN 5 AND 1440);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'prj_dev_connections_alert_kind_check'
                      AND conrelid = 'projects.prj_dev_connections'::regclass) THEN
        ALTER TABLE projects.prj_dev_connections ADD CONSTRAINT prj_dev_connections_alert_kind_check
            CHECK (alert_kind IN ('bug', 'task', 'story'));
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS projects.prj_alert_issues (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    connection_id    text NOT NULL REFERENCES projects.prj_dev_connections (id) ON DELETE CASCADE,
    provider         text NOT NULL,
    external_id      text NOT NULL,
    task_id          text NOT NULL REFERENCES projects.prj_tasks (id) ON DELETE CASCADE,
    title            text NOT NULL DEFAULT '',
    level            text,
    environment      text,
    culprit          text,
    url              text CONSTRAINT prj_alert_issues_url_check CHECK (url IS NULL OR url ~ '^https?://'),
    event_count      bigint NOT NULL DEFAULT 1,
    -- Events since the last comment, told in the next one.
    pending_events   bigint NOT NULL DEFAULT 0,
    first_seen       timestamptz NOT NULL DEFAULT now(),
    last_seen        timestamptz NOT NULL DEFAULT now(),
    last_comment_at  timestamptz,
    state            text NOT NULL DEFAULT 'open'
                     CONSTRAINT prj_alert_issues_state_check CHECK (state IN ('open', 'resolved')),
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS prj_alert_issues_uq ON projects.prj_alert_issues (connection_id, external_id);
CREATE INDEX IF NOT EXISTS prj_alert_issues_task_idx ON projects.prj_alert_issues (task_id);

-- ===================================================================== calendar feeds
CREATE TABLE IF NOT EXISTS projects.prj_calendar_feeds (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    user_id       text NOT NULL,
    kind          text NOT NULL CONSTRAINT prj_calendar_feeds_kind_check CHECK (kind IN ('person', 'project')),
    project_id    text REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    include       text[] NOT NULL DEFAULT ARRAY['due', 'sprints', 'milestones']::text[]
                  CONSTRAINT prj_calendar_feeds_include_check CHECK (include <@ ARRAY['due', 'sprints', 'milestones']::text[]),
    -- NULL: no reminder; else days before, at the start of the person's working day.
    alarm_days    int CONSTRAINT prj_calendar_feeds_alarm_check CHECK (alarm_days IS NULL OR alarm_days BETWEEN 0 AND 7),
    -- The Projects address the feed's links open (the one it was made from).
    link_base     text,
    token_prefix  text NOT NULL,
    token_hash    text NOT NULL,
    last_used_at  timestamptz,
    revoked_at    timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz,
    CONSTRAINT prj_calendar_feeds_project_check CHECK ((kind = 'project') = (project_id IS NOT NULL))
);
ALTER TABLE projects.prj_calendar_feeds ADD COLUMN IF NOT EXISTS link_base text;
CREATE UNIQUE INDEX IF NOT EXISTS prj_calendar_feeds_token_uq ON projects.prj_calendar_feeds (token_hash);
-- One live address per person and calendar.
CREATE UNIQUE INDEX IF NOT EXISTS prj_calendar_feeds_one_uq ON projects.prj_calendar_feeds (tenant_id, bus_id, user_id, kind, coalesce(project_id, ''))
    WHERE revoked_at IS NULL;

-- ===================================================================== plan feature
UPDATE core_platform.cp_app_feature_catalog
   SET title = 'Integrations: GitHub, GitLab, Bitbucket, Slack, Teams, Sentry, Datadog, Zapier, Make, n8n & calendars',
       description = 'Link code and builds to work, post work updates to chat, turn Sentry and Datadog alerts into bugs, '
                     'connect Zapier, Make and n8n, and subscribe to work in Google, Outlook or Apple Calendar'
 WHERE feature_key = 'projects.integrations';

-- ===================================================================== invariants
DO $$
BEGIN
    IF to_regclass('projects.prj_calendar_feeds_token_uq') IS NULL OR to_regclass('projects.prj_alert_issues_uq') IS NULL THEN
        RAISE EXCEPTION 'prj_calendar_feeds or prj_alert_issues lacks its unique index';
    END IF;
    IF EXISTS (SELECT 1 FROM projects.prj_alert_issues a JOIN projects.prj_dev_connections c ON c.id = a.connection_id
                WHERE c.tenant_id <> a.tenant_id OR c.bus_id <> a.bus_id) THEN
        RAISE EXCEPTION 'a Projects alert belongs to a connection of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM projects.prj_calendar_feeds f JOIN projects.prj_projects p ON p.id = f.project_id
                WHERE p.tenant_id <> f.tenant_id OR p.bus_id <> f.bus_id) THEN
        RAISE EXCEPTION 'a Projects calendar feed names a project of another business';
    END IF;
    -- An automation subscription is always some API token's.
    IF EXISTS (SELECT 1 FROM projects.prj_webhooks WHERE kind IN ('zapier', 'make', 'n8n') AND token_id IS NULL) THEN
        RAISE EXCEPTION 'a Projects automation subscription has no API token';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM core_platform.cp_app_feature_catalog
                    WHERE feature_key = 'projects.integrations' AND min_tier_rank = 3 AND is_active) THEN
        RAISE EXCEPTION 'projects.integrations must be an active PREMIUM feature';
    END IF;
END $$;

COMMIT;
