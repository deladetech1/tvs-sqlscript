-- Projects: whiteboards -- a freeform canvas of sticky notes, text, shapes, arrows and pen,
-- where a sticky note can become a work item.
--
--   * prj_whiteboards: a board in a workspace, optionally a project's (it then follows the
--     project's privacy).
--   * prj_whiteboard_items: each thing on it, saved on its own so people drawing at the same
--     time do not overwrite each other (the last change to an item wins). data holds its
--     position, size, text, colour, points, ends; task_id the work item a sticky became.
--     Deleting an item keeps a tombstone (deleted) so everyone's board removes it too.
--
-- Read and edited with the Docs permissions (projects|docs|*). Idempotent.

BEGIN;

CREATE TABLE IF NOT EXISTS projects.prj_whiteboards (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    workspace_id   text NOT NULL REFERENCES projects.prj_workspaces (id) ON DELETE CASCADE,
    project_id     text REFERENCES projects.prj_projects (id) ON DELETE SET NULL,
    name           text NOT NULL CHECK (btrim(name) <> ''),
    created_by     text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    delete_status  text NOT NULL DEFAULT 'NOT_DELETED'
);
CREATE INDEX IF NOT EXISTS prj_whiteboards_ws_idx ON projects.prj_whiteboards (tenant_id, workspace_id) WHERE delete_status = 'NOT_DELETED';

CREATE TABLE IF NOT EXISTS projects.prj_whiteboard_items (
    id          text NOT NULL,
    board_id    text NOT NULL REFERENCES projects.prj_whiteboards (id) ON DELETE CASCADE,
    tenant_id   text NOT NULL,
    kind        text NOT NULL CHECK (kind IN ('sticky', 'text', 'rect', 'ellipse', 'arrow', 'pen')),
    data        jsonb NOT NULL DEFAULT '{}'::jsonb,
    z           double precision NOT NULL DEFAULT 0,
    task_id     text REFERENCES projects.prj_tasks (id) ON DELETE SET NULL,
    deleted     boolean NOT NULL DEFAULT false,
    updated_by  text,
    updated_at  timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (board_id, id)
);
CREATE INDEX IF NOT EXISTS prj_whiteboard_items_changed_idx ON projects.prj_whiteboard_items (board_id, updated_at);

COMMIT;
