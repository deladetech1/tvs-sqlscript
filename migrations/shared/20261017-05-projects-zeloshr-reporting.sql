-- Projects: who manages whom, from ZelosHR, so a line manager sees their team's time at work
-- on the timesheet as ZelosHR shows it to them.
--
--   * projects.src_zhr_reporting: each current employee's user, with the users of their line
--     manager (reports_to, else manager), dotted-line manager and head of department. ZelosHR's
--     own rule (HomeRules / AttendanceController scope=team): direct and dotted-line reports and
--     the departments one heads; departed (Resigned, Terminated, Retired, Inactive), draft and
--     deleted people are nobody's team.
--
-- Read-only, only where ZelosHR is installed. Idempotent; safe to re-run on every deploy.

BEGIN;

DO $$
BEGIN
    IF to_regclass('zeloshr.zhr_employees') IS NULL OR to_regclass('zeloshr.zhr_departments') IS NULL THEN
        RAISE NOTICE 'ZelosHR is not here; no reporting lines';
        RETURN;
    END IF;
    EXECUTE $v$
    CREATE OR REPLACE VIEW projects.src_zhr_reporting AS
    SELECT e.tenant_id, e.org_id, e.user_id,
           lm.user_id AS line_manager_user_id,
           dm.user_id AS dotted_manager_user_id,
           hd.user_id AS department_head_user_id
      FROM zeloshr.zhr_employees e
      LEFT JOIN zeloshr.zhr_employees lm ON lm.id = coalesce(e.reports_to_id, e.manager_id) AND lm.tenant_id = e.tenant_id
      LEFT JOIN zeloshr.zhr_employees dm ON dm.id = e.dotted_line_manager_id AND dm.tenant_id = e.tenant_id
      LEFT JOIN zeloshr.zhr_departments d ON d.id = e.department_id AND d.tenant_id = e.tenant_id
      LEFT JOIN zeloshr.zhr_employees hd ON hd.id = d.head_of_department_id AND hd.tenant_id = e.tenant_id
     WHERE e.user_id IS NOT NULL AND NOT coalesce(e.is_deleted, false) AND NOT coalesce(e.is_draft, false)
       AND lower(coalesce(e.lifecycle_state, '')) NOT IN ('resigned', 'terminated', 'retired', 'inactive')
       AND lower(coalesce(e.employment_status, '')) NOT IN ('resigned', 'terminated', 'retired', 'inactive')
    $v$;
END $$;

COMMIT;
