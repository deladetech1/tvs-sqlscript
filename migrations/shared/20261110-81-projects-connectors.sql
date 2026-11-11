-- Projects: the connector gallery (tvs-shared-apps-bk internal/apps/projects/connectors*.go).
--
--   prj_dev_connections  every inbound connector is a connection: the same public address
--                        (/projects/hooks/v1/<provider>/<token>), sealed secret, call log and
--                        rate limits as GitHub and Sentry. New providers:
--                          code & CI    azure_repos, gitea, jenkins, circleci, vercel, netlify
--                          monitoring   newrelic, grafana, alertmanager, pagerduty, opsgenie,
--                                       rollbar, bugsnag, uptimerobot, betterstack
--                          forms        typeform, google_forms, jotform, tally
--                          support      zendesk, freshdesk, intercom
--                          time         toggl, clockify
--                          generic      webhook_in (field mapping in settings)
--                        settings: a connector's own options (the generic webhook's mapping).
--   prj_webhooks         chat kinds google_chat, discord, mattermost, rocketchat, telegram
--                        (telegram's chat id in target).
--
-- The provider and kind lists keep every earlier value, so the earlier migrations' re-runs
-- (which drop their constraint only when it lacks 'sentry' / 'zapier' / 'slack_app') leave
-- this one in place. Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE projects.prj_dev_connections ADD COLUMN IF NOT EXISTS settings jsonb NOT NULL DEFAULT '{}';

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'prj_dev_connections_provider_check'
                  AND conrelid = 'projects.prj_dev_connections'::regclass
                  AND pg_get_constraintdef(oid) NOT LIKE '%webhook_in%') THEN
        ALTER TABLE projects.prj_dev_connections DROP CONSTRAINT prj_dev_connections_provider_check;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'prj_dev_connections_provider_check'
                      AND conrelid = 'projects.prj_dev_connections'::regclass) THEN
        ALTER TABLE projects.prj_dev_connections ADD CONSTRAINT prj_dev_connections_provider_check
            CHECK (provider IN ('github', 'gitlab', 'bitbucket', 'sentry', 'datadog',
                                'azure_repos', 'gitea', 'jenkins', 'circleci', 'vercel', 'netlify',
                                'newrelic', 'grafana', 'alertmanager', 'pagerduty', 'opsgenie', 'rollbar', 'bugsnag',
                                'uptimerobot', 'betterstack',
                                'typeform', 'google_forms', 'jotform', 'tally',
                                'zendesk', 'freshdesk', 'intercom',
                                'toggl', 'clockify',
                                'webhook_in'));
    END IF;
END $$;

-- A time tool's entry, logged once (Toggl, Clockify): a later edit of it is not logged again.
CREATE TABLE IF NOT EXISTS projects.prj_connector_entries (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    connection_id  text NOT NULL REFERENCES projects.prj_dev_connections (id) ON DELETE CASCADE,
    external_id    text NOT NULL,
    task_id        text REFERENCES projects.prj_tasks (id) ON DELETE SET NULL,
    worklog_id     text,
    minutes        int NOT NULL DEFAULT 0,
    cdatetime      timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS prj_connector_entries_uq ON projects.prj_connector_entries (connection_id, external_id);

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'prj_webhooks_kind_check'
                  AND conrelid = 'projects.prj_webhooks'::regclass
                  AND pg_get_constraintdef(oid) NOT LIKE '%telegram%') THEN
        ALTER TABLE projects.prj_webhooks DROP CONSTRAINT prj_webhooks_kind_check;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'prj_webhooks_kind_check'
                      AND conrelid = 'projects.prj_webhooks'::regclass) THEN
        ALTER TABLE projects.prj_webhooks ADD CONSTRAINT prj_webhooks_kind_check
            CHECK (kind IN ('webhook', 'slack', 'teams', 'zapier', 'make', 'n8n', 'slack_app', 'teams_bot',
                            'google_chat', 'discord', 'mattermost', 'rocketchat', 'telegram'));
    END IF;
END $$;

-- ===================================================================== invariants
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'prj_dev_connections_provider_check'
                    AND conrelid = 'projects.prj_dev_connections'::regclass
                    AND pg_get_constraintdef(oid) LIKE '%webhook_in%' AND pg_get_constraintdef(oid) LIKE '%sentry%') THEN
        RAISE EXCEPTION 'prj_dev_connections_provider_check must allow the connectors and keep sentry';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'prj_webhooks_kind_check'
                    AND conrelid = 'projects.prj_webhooks'::regclass
                    AND pg_get_constraintdef(oid) LIKE '%telegram%' AND pg_get_constraintdef(oid) LIKE '%slack_app%'
                    AND pg_get_constraintdef(oid) LIKE '%zapier%') THEN
        RAISE EXCEPTION 'prj_webhooks_kind_check must allow the chat kinds and keep slack_app and zapier';
    END IF;
    IF to_regclass('projects.prj_connector_entries_uq') IS NULL THEN
        RAISE EXCEPTION 'prj_connector_entries lacks its unique index';
    END IF;
    IF EXISTS (SELECT 1 FROM projects.prj_connector_entries e JOIN projects.prj_dev_connections c ON c.id = e.connection_id
                WHERE c.tenant_id <> e.tenant_id OR c.bus_id <> e.bus_id) THEN
        RAISE EXCEPTION 'a Projects time entry belongs to a connection of another business';
    END IF;
    -- A Telegram channel always names its chat.
    IF EXISTS (SELECT 1 FROM projects.prj_webhooks WHERE kind = 'telegram' AND delete_status = 'NOT_DELETED' AND coalesce(target, '') = '') THEN
        RAISE EXCEPTION 'a Projects Telegram channel has no chat id';
    END IF;
END $$;

COMMIT;
