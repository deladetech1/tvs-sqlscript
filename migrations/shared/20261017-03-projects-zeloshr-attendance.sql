-- Projects: ZelosHR attendance beside logged time.
--
--   * projects.src_zhr_attendance: each person's day at work from ZelosHR -- clock in, clock out,
--     hours worked and whether they are on the clock now -- by their user id, read-only and only
--     where ZelosHR is installed. Projects' timesheet sets it against the time logged on work,
--     and the clock nudges someone who starts work without having clocked in.
--     zhr_attendance_records is ZelosHR's own answer (approved corrections are written back into
--     it, and payroll reads it); "on the clock" is the day's latest punch being a clock-in.
--
-- Projects never writes to ZelosHR. Idempotent; safe to re-run on every deploy.

BEGIN;

DO $$
BEGIN
    IF to_regclass('zeloshr.zhr_attendance_records') IS NULL OR to_regclass('zeloshr.zhr_employees') IS NULL THEN
        RAISE NOTICE 'ZelosHR is not here; the timesheet goes without attendance';
        RETURN;
    END IF;
    IF to_regclass('attendance.att_punches') IS NOT NULL AND has_table_privilege('attendance.att_punches', 'SELECT') THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW projects.src_zhr_attendance AS
        SELECT a.tenant_id, e.user_id, a.attendance_date, a.clock_in, a.clock_out,
               coalesce(a.hours_worked, 0)::numeric AS hours_worked, coalesce(a.status, '') AS status,
               coalesce((SELECT p.punch_type = 'clock_in' FROM attendance.att_punches p
                          WHERE p.attendance_id = a.id AND NOT coalesce(p.is_superseded, false)
                          ORDER BY p.punched_at DESC LIMIT 1),
                        a.clock_in IS NOT NULL AND a.clock_out IS NULL) AS on_clock
          FROM zeloshr.zhr_attendance_records a
          JOIN zeloshr.zhr_employees e ON e.id = a.employee_id AND e.tenant_id = a.tenant_id
         WHERE e.user_id IS NOT NULL AND coalesce(e.is_deleted, false) = false
        $v$;
    ELSE
        EXECUTE $v$
        CREATE OR REPLACE VIEW projects.src_zhr_attendance AS
        SELECT a.tenant_id, e.user_id, a.attendance_date, a.clock_in, a.clock_out,
               coalesce(a.hours_worked, 0)::numeric AS hours_worked, coalesce(a.status, '') AS status,
               (a.clock_in IS NOT NULL AND a.clock_out IS NULL) AS on_clock
          FROM zeloshr.zhr_attendance_records a
          JOIN zeloshr.zhr_employees e ON e.id = a.employee_id AND e.tenant_id = a.tenant_id
         WHERE e.user_id IS NOT NULL AND coalesce(e.is_deleted, false) = false
        $v$;
    END IF;
    -- Who has a ZelosHR record at all: without one, "not clocked in" means nothing.
    EXECUTE $v$
    CREATE OR REPLACE VIEW projects.src_zhr_people AS
    SELECT e.tenant_id, e.user_id FROM zeloshr.zhr_employees e
     WHERE e.user_id IS NOT NULL AND coalesce(e.is_deleted, false) = false
    $v$;
END $$;

COMMIT;
