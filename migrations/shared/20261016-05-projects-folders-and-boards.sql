-- Projects: folders and boards inside a project.
--
-- A project holds folders, nested as deep as a team likes, and boards, in a folder or at the
-- top. A board is where work items live and is shown as a kanban and a list; every board in a
-- project shares the project's statuses, sprints and keys (WEB-12 stays unique in WEB).
--
--   * prj_folders: parent_id makes the tree; a folder can never sit inside itself (checked by
--     the API). Deleting a folder lifts what is in it up one level -- never deletes work.
--   * prj_boards: folder_id NULL = the project's top level. One per project is the default
--     ("Main board"): existing work lives in it and it cannot be deleted.
--   * prj_tasks.board_id, NOT NULL. A row inserted without one gets its parent's board (a
--     subtask goes where its story is) or the project's default board, so every way work is
--     made -- the form, imports, repeating work -- lands somewhere.
--   * permissions projects|boards|<create|update|delete>: managers all, members create and
--     update (organise), viewers none (they read through projects|projects|get).
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS projects.prj_folders (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    project_id     text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    parent_id      text REFERENCES projects.prj_folders (id) ON DELETE CASCADE,
    name           text NOT NULL CHECK (btrim(name) <> ''),
    position       integer NOT NULL DEFAULT 0,
    created_by     text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    CHECK (parent_id IS DISTINCT FROM id)
);
CREATE INDEX IF NOT EXISTS prj_folders_project_idx ON projects.prj_folders (project_id, parent_id, position);

CREATE TABLE IF NOT EXISTS projects.prj_boards (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    project_id     text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    folder_id      text REFERENCES projects.prj_folders (id) ON DELETE SET NULL,
    name           text NOT NULL CHECK (btrim(name) <> ''),
    description    text NOT NULL DEFAULT '',
    color          text NOT NULL DEFAULT 'amber',
    position       integer NOT NULL DEFAULT 0,
    is_default     boolean NOT NULL DEFAULT false,
    created_by     text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prj_boards_project_idx ON projects.prj_boards (project_id, folder_id, position);
CREATE UNIQUE INDEX IF NOT EXISTS prj_boards_default_uq ON projects.prj_boards (project_id) WHERE is_default;

-- Every project gets its main board.
INSERT INTO projects.prj_boards (tenant_id, bus_id, project_id, name, is_default)
SELECT p.tenant_id, p.bus_id, p.id, 'Main board', true
  FROM projects.prj_projects p
 WHERE NOT EXISTS (SELECT 1 FROM projects.prj_boards b WHERE b.project_id = p.id AND b.is_default)
ON CONFLICT DO NOTHING;

ALTER TABLE projects.prj_tasks ADD COLUMN IF NOT EXISTS board_id text REFERENCES projects.prj_boards (id);
CREATE INDEX IF NOT EXISTS prj_tasks_board_idx ON projects.prj_tasks (board_id) WHERE delete_status = 'NOT_DELETED';

UPDATE projects.prj_tasks t
   SET board_id = b.id
  FROM projects.prj_boards b
 WHERE t.board_id IS NULL AND b.project_id = t.project_id AND b.is_default;

ALTER TABLE projects.prj_tasks ALTER COLUMN board_id SET NOT NULL;

CREATE OR REPLACE FUNCTION projects.prj_tasks_default_board() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.board_id IS NULL AND NEW.parent_id IS NOT NULL AND NEW.kind = 'subtask' THEN
        SELECT board_id INTO NEW.board_id FROM projects.prj_tasks WHERE id = NEW.parent_id AND project_id = NEW.project_id;
    END IF;
    IF NEW.board_id IS NULL THEN
        SELECT id INTO NEW.board_id FROM projects.prj_boards WHERE project_id = NEW.project_id AND is_default;
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS prj_tasks_default_board ON projects.prj_tasks;
CREATE TRIGGER prj_tasks_default_board BEFORE INSERT ON projects.prj_tasks
    FOR EACH ROW EXECUTE FUNCTION projects.prj_tasks_default_board();

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-projects-boards', 'Projects Boards', 'Folders and boards inside a project', 'rt-subscribed-app-projects')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(action, label) AS (VALUES
    ('create', 'Create folders and boards'),
    ('update', 'Rename and move folders and boards'),
    ('delete', 'Delete folders and boards')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-projects-boards-' || spec.action, 'Projects Boards ' || initcap(spec.action), 'rt-projects-boards',
       spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name = EXCLUDED.permission_name, description = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'projects', resource_key = 'boards', action = substring(p.id FROM '-([a-z]+)$'), target = '', scope = 'any'
 WHERE p.id LIKE 'permission-projects-boards-%' AND (p.app_prefix IS DISTINCT FROM 'projects' OR p.action IS NULL);

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', g.role_id, p.id, r.role_name || ' can ' || lower(p.description), CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (VALUES ('role-projects-manager', 'create'), ('role-projects-manager', 'update'), ('role-projects-manager', 'delete'),
               ('role-projects-member', 'create'), ('role-projects-member', 'update')) AS g(role_id, action)
  JOIN core_platform.cp_roles r ON r.id = g.role_id
  JOIN core_platform.cp_permissions p ON p.app_prefix = 'projects' AND p.resource_key = 'boards' AND p.action = g.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM projects.prj_projects p WHERE NOT EXISTS
                (SELECT 1 FROM projects.prj_boards b WHERE b.project_id = p.id AND b.is_default)) THEN
        RAISE EXCEPTION 'a project has no main board';
    END IF;
    IF EXISTS (SELECT 1 FROM projects.prj_tasks t JOIN projects.prj_boards b ON b.id = t.board_id WHERE b.project_id <> t.project_id) THEN
        RAISE EXCEPTION 'a work item is on another project''s board';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_permissions p WHERE p.app_prefix = 'projects'
                AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                                 WHERE rp.role_id = 'role-projects-manager' AND rp.permission_id = p.id)) THEN
        RAISE EXCEPTION 'role-projects-manager lacks a Projects permission';
    END IF;
END $$;

COMMIT;
