-- Projects reads MyStoreGuard's workflow jobs, to import them.
--
-- As the CRM reads LoanDrift and MyStoreGuard (crm.src_*), Projects reads through views in its
-- own schema, never the other app's tables in its code. The views are read-only and carry
-- tenant_id/bus_id so every query stays inside one business; who may use them is decided by
-- the import endpoint, which also requires the caller to hold MyStoreGuard's own read
-- permission on workflow jobs.
--
-- A database without MyStoreGuard's workflow tables gets no views, and the import says so.
--
--   * prj_import_links: which of another app's records became which work item, so importing
--     the same job twice does not make it twice.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS projects.prj_import_links (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    project_id  text NOT NULL REFERENCES projects.prj_projects (id) ON DELETE CASCADE,
    source      text NOT NULL,
    source_id   text NOT NULL,
    task_id     text NOT NULL REFERENCES projects.prj_tasks (id) ON DELETE CASCADE,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    PRIMARY KEY (tenant_id, project_id, source, source_id)
);

DO $$
BEGIN
    IF to_regclass('mystoreguard.msg_tasks') IS NULL OR to_regclass('mystoreguard.msg_task_steps') IS NULL THEN
        RAISE NOTICE 'MyStoreGuard workflow tables are not here; no import views';
        RETURN;
    END IF;

    -- A job: its customer's name rather than the id, which means nothing here.
    EXECUTE $v$
    CREATE OR REPLACE VIEW projects.src_msg_jobs AS
    SELECT t.tenant_id, t.bus_id, t.id, t.title, coalesce(t.description, '') AS description, t.task_type, t.status,
           t.due_date, t.cdatetime, t.created_by, t.template_id,
           c.fullname AS customer_name,
           (SELECT count(*) FROM mystoreguard.msg_task_steps s WHERE s.tenant_id = t.tenant_id AND s.bus_id = t.bus_id AND s.task_id = t.id) AS step_count
      FROM mystoreguard.msg_tasks t
      LEFT JOIN mystoreguard.msg_customers c ON c.tenant_id = t.tenant_id AND c.bus_id = t.bus_id AND c.id = t.customer_id
     WHERE coalesce(t.delete_status, 'NOT_DELETED') = 'NOT_DELETED'
    $v$;

    EXECUTE $v$
    CREATE OR REPLACE VIEW projects.src_msg_steps AS
    SELECT s.tenant_id, s.bus_id, s.id, s.task_id, s.name, coalesce(s.description, '') AS description, s.display_order, s.status,
           s.claimed_by, s.done_by, s.done_at, s.completed_by, s.completed_at, s.cdatetime, s.created_by
      FROM mystoreguard.msg_task_steps s
    $v$;

    -- Who a step is for. A GROUP target is expanded to its members as they are now.
    EXECUTE $v$
    CREATE OR REPLACE VIEW projects.src_msg_step_people AS
    SELECT g.tenant_id, g.bus_id, g.step_id, g.target_kind, g.target_type, g.target_id, g.user_id, g.cdatetime
      FROM (
        SELECT t.tenant_id, t.bus_id, t.step_id, t.target_kind, t.target_type, t.target_id, t.target_id AS user_id, t.cdatetime
          FROM mystoreguard.msg_task_step_targets t WHERE t.target_type = 'USER'
        UNION ALL
        SELECT t.tenant_id, t.bus_id, t.step_id, t.target_kind, t.target_type, t.target_id, ug.user_id, t.cdatetime
          FROM mystoreguard.msg_task_step_targets t
          JOIN core_platform.cp_user_groups ug ON ug.group_id = t.target_id AND ug.tenant_id = t.tenant_id
           AND coalesce(ug.delete_status, 'NOT_DELETED') = 'NOT_DELETED'
         WHERE t.target_type = 'GROUP'
      ) g
    $v$;

    EXECUTE $v$
    CREATE OR REPLACE VIEW projects.src_msg_step_deps AS
    SELECT d.tenant_id, d.bus_id, d.step_id, d.depends_on_step_id FROM mystoreguard.msg_task_step_deps d
    $v$;

    EXECUTE $v$
    CREATE OR REPLACE VIEW projects.src_msg_comments AS
    SELECT c.tenant_id, c.bus_id, c.id, c.step_id, c.task_id, c.body, c.created_by, c.cdatetime, c.edited_at,
           coalesce((SELECT array_agg(m.mentioned_user_id) FROM mystoreguard.msg_task_comment_mentions m
                      WHERE m.tenant_id = c.tenant_id AND m.bus_id = c.bus_id AND m.comment_id = c.id), '{}') AS mentions
      FROM mystoreguard.msg_task_comments c
    $v$;

    -- Files stay in MyStoreGuard's storage; the import counts them so it can say so.
    EXECUTE $v$
    CREATE OR REPLACE VIEW projects.src_msg_files AS
    SELECT a.tenant_id, a.bus_id, a.step_id, a.task_id, count(*) AS files
      FROM mystoreguard.msg_task_attachments a
     WHERE coalesce(a.delete_status, 'NOT_DELETED') = 'NOT_DELETED' AND coalesce(a.is_active, true)
     GROUP BY a.tenant_id, a.bus_id, a.step_id, a.task_id
    $v$;
END $$;

COMMIT;
