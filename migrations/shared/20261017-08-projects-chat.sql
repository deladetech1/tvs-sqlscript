-- Projects: chat -- a channel per project, and channels people make in a workspace, with
-- threads, @mentions and work items named inline.
--
--   * prj_channels: a project's channel (project_id set; it follows the project's privacy), or
--     a workspace channel, open to the workspace or to its members only.
--   * prj_channel_members: who is in a members-only channel.
--   * prj_messages: a message; parent_id makes it a reply in a thread. mentions are the people
--     it names (told in the bell and by email), task_ids the work items it names (KEY-12).
--   * prj_channel_reads: how far each person has read, for unread counts.
--   * prj_notifications.channel_id: a mention in chat points at its channel.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS projects.prj_channels (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    workspace_id  text NOT NULL REFERENCES projects.prj_workspaces (id) ON DELETE CASCADE,
    project_id    text UNIQUE REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    name          text NOT NULL CHECK (btrim(name) <> ''),
    description   text NOT NULL DEFAULT '',
    visibility    text NOT NULL DEFAULT 'open' CHECK (visibility IN ('open', 'members')),
    archived      boolean NOT NULL DEFAULT false,
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    last_message_at timestamptz
);
CREATE INDEX IF NOT EXISTS prj_channels_ws_idx ON projects.prj_channels (tenant_id, workspace_id) WHERE NOT archived;
CREATE UNIQUE INDEX IF NOT EXISTS prj_channels_name_uq ON projects.prj_channels (workspace_id, lower(name)) WHERE project_id IS NULL AND NOT archived;

CREATE TABLE IF NOT EXISTS projects.prj_channel_members (
    channel_id  text NOT NULL REFERENCES projects.prj_channels (id) ON DELETE CASCADE,
    user_id     text NOT NULL,
    tenant_id   text NOT NULL,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (channel_id, user_id)
);

CREATE TABLE IF NOT EXISTS projects.prj_messages (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    channel_id  text NOT NULL REFERENCES projects.prj_channels (id) ON DELETE CASCADE,
    parent_id   text REFERENCES projects.prj_messages (id) ON DELETE CASCADE,
    author_id   text NOT NULL,
    body        text NOT NULL CHECK (btrim(body) <> ''),
    mentions    text[] NOT NULL DEFAULT '{}',
    task_ids    text[] NOT NULL DEFAULT '{}',
    edited_at   timestamptz,
    deleted_at  timestamptz,
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prj_messages_channel_idx ON projects.prj_messages (channel_id, cdatetime) WHERE parent_id IS NULL;
CREATE INDEX IF NOT EXISTS prj_messages_thread_idx ON projects.prj_messages (parent_id, cdatetime) WHERE parent_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS projects.prj_channel_reads (
    channel_id    text NOT NULL REFERENCES projects.prj_channels (id) ON DELETE CASCADE,
    user_id       text NOT NULL,
    tenant_id     text NOT NULL,
    last_read_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (channel_id, user_id)
);

ALTER TABLE projects.prj_notifications ADD COLUMN IF NOT EXISTS channel_id text REFERENCES projects.prj_channels (id) ON DELETE CASCADE;

COMMIT;
