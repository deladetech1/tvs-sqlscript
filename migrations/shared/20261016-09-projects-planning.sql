-- Projects: planning -- a timeline, a roadmap and workload.
--
--   * prj_capacity: how much a person can take on in a week, in points (an item without an
--     estimate counts as one), per workspace. Without a row, ten.
--   * projects.src_zhr_leave: ZelosHR leave, read-only and only where ZelosHR is installed:
--     each person's approved (and pending, shown as tentative) leave, by their user id, so
--     workload takes it off their week.
--   * projects.src_zhr_holidays: ZelosHR's public holidays (recurring ones by month and day).
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS projects.prj_capacity (
    workspace_id    text NOT NULL REFERENCES projects.prj_workspaces (id) ON DELETE CASCADE,
    user_id         text NOT NULL,
    tenant_id       text NOT NULL,
    weekly_capacity numeric(8, 2) NOT NULL CHECK (weekly_capacity >= 0 AND weekly_capacity <= 1000),
    updated_by      text,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, user_id)
);

DO $$
BEGIN
    IF to_regclass('zeloshr.zhr_leave_requests') IS NULL OR to_regclass('zeloshr.zhr_employees') IS NULL THEN
        RAISE NOTICE 'ZelosHR is not here; workload goes without leave';
        RETURN;
    END IF;
    EXECUTE $v$
    CREATE OR REPLACE VIEW projects.src_zhr_leave AS
    SELECT l.tenant_id, e.user_id, l.start_date, l.end_date, l.status, coalesce(l.leave_type, '') AS leave_type
      FROM zeloshr.zhr_leave_requests l
      JOIN zeloshr.zhr_employees e ON e.id = l.employee_id AND e.tenant_id = l.tenant_id
     WHERE e.user_id IS NOT NULL AND coalesce(e.is_deleted, false) = false
       AND l.status IN ('Approved', 'Pending') AND l.start_date IS NOT NULL AND l.end_date IS NOT NULL
    $v$;
    IF to_regclass('zeloshr.zhr_public_holidays') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW projects.src_zhr_holidays AS
        SELECT h.tenant_id, h.holiday_date, h.name, coalesce(h.is_recurring, false) AS is_recurring
          FROM zeloshr.zhr_public_holidays h WHERE coalesce(h.is_active, true)
        $v$;
    END IF;
END $$;

COMMIT;
