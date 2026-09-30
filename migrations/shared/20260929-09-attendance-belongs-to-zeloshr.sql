-- Attendance is ZelosHR's, not Core Platform's.
--
-- Seven resources -- attendance-adjustments, -clock, -devices, -employees, -records, -team
-- and -timesheet -- were seeded with app_prefix '', which means Core Platform. They are named
-- after seven screens, and all seven of those screens are in the ZelosHR frontend:
--
--     zeloshr/tvs-zeloshr-admin-ft/src/app/attendance/{records,adjustments,team,
--                                                     timesheet,clock,devices}/page.tsx
--
-- Core Platform's frontend has no attendance page at all, and its backend's attendance module
-- is five files of stubs with no APIRouter and nothing mounting it. So the permissions describe
-- ZelosHR's product and were filed under the wrong app.
--
-- Being filed under '' had a consequence beyond tidiness: app_prefix is what the role rules
-- read. Core Platform Admin covered these seventeen permissions and ZelosHR Admin did not, so
-- ZelosHR's own administrator was the one person who could not be given attendance by being an
-- administrator. This migration is what fixes that, and it is only a one-column change because
-- a check now compares the pair -- app|resource|verb|target|scope -- rather than the permission
-- id. Under the id model the same fix meant re-keying seventeen ids and every row pointing at
-- them, since `permission-attendance-records-get` names no app and `permission-zeloshr-...` was
-- the only way to say one.
--
-- The ids are therefore left exactly as they are. They still key the row; they stopped being
-- the address. Renaming them would be churn through cp_role_permissions' foreign keys to buy
-- a cosmetic prefix nothing reads.
--
-- Safe for the two people who hold an attendance role: their grant rows are untouched except
-- for the same app_prefix column, so they keep precisely what they had.
--
-- The earlier migrations that seed these seven resources -- 20260928-05, -09 and -11 -- are
-- deliberately left saying ''. Correcting them there looks tidier and breaks the deploy: -09
-- derives each permission id from the app prefix, so a resource filed under 'zeloshr' gets the
-- id `permission-zeloshr-attendance-records-get`, which does not collide on the id it conflicts
-- on and does collide on ux_cp_permissions_resource_action. Seventeen duplicate keys, and the
-- whole database deploy stops.
--
-- Every migration re-runs on every deploy, in filename order, and 20260929 sorts after
-- 20260928. So the seeds put attendance under Core Platform with its original ids and this
-- migration moves it, on a fresh database and an existing one alike, every time. One statement
-- owns the answer instead of four having to agree.
--
-- That ordering has to stay this way round for a second reason. 20260929-05 empties Core
-- Platform Admin, whose grants a role rule replaced, and it selects them by the PERMISSION's
-- app_prefix being '' or 'cp'. Run after this migration it would no longer recognise the
-- seventeen attendance grants that 20260928-05 hands that role, and Core Platform Admin would
-- keep seventeen ZelosHR permissions for good -- a cross-app grant of exactly the kind
-- 20260929-04 was written to remove. Sorting -09 after -05 means the strip still sees them as
-- Core Platform's, which they are until this runs.
--
-- Checked by replaying all twenty-four 20260928 and 20260929 migrations in order against dev
-- in a transaction that rolls back: the end state is 34 grants across the eight attendance
-- roles, every one of them 'zeloshr', and role-cp-admin holding none.

BEGIN;

-- 1. The resource catalogue, which is what the permission seeder reads.
UPDATE core_platform.cp_resources
   SET app_prefix = 'zeloshr'
 WHERE app_prefix = '' AND resource_key LIKE 'attendance-%';

-- 2. The permissions themselves.
UPDATE core_platform.cp_permissions
   SET app_prefix = 'zeloshr'
 WHERE app_prefix = '' AND resource_key LIKE 'attendance-%';

-- 3. The grant rows carry their own copy of the pair, denormalised so a permission check is
--    one read. Leaving these behind would make a grant say '' while its permission said
--    'zeloshr' -- and the grant's copy is the one the check compares, so the move would have
--    had no effect on who can do what.
UPDATE core_platform.cp_role_permissions rp
   SET app_prefix = 'zeloshr'
  FROM core_platform.cp_permissions p
 WHERE p.id = rp.permission_id
   AND rp.app_prefix = ''
   AND p.resource_key LIKE 'attendance-%';

-- Nothing may be left saying Core Platform owns attendance.
DO $$
DECLARE
    stragglers integer;
BEGIN
    SELECT (SELECT count(*) FROM core_platform.cp_resources
             WHERE app_prefix = '' AND resource_key LIKE 'attendance-%')
         + (SELECT count(*) FROM core_platform.cp_permissions
             WHERE app_prefix = '' AND resource_key LIKE 'attendance-%')
         + (SELECT count(*) FROM core_platform.cp_role_permissions
             WHERE app_prefix = '' AND resource_key LIKE 'attendance-%')
      INTO stragglers;

    IF stragglers > 0 THEN
        RAISE EXCEPTION 'attendance still filed under Core Platform in % row(s)', stragglers;
    END IF;

    RAISE NOTICE 'attendance moved to ZelosHR: % resources, % permissions, % grants',
        (SELECT count(*) FROM core_platform.cp_resources
          WHERE app_prefix = 'zeloshr' AND resource_key LIKE 'attendance-%'),
        (SELECT count(*) FROM core_platform.cp_permissions
          WHERE app_prefix = 'zeloshr' AND resource_key LIKE 'attendance-%'),
        (SELECT count(*) FROM core_platform.cp_role_permissions
          WHERE app_prefix = 'zeloshr' AND resource_key LIKE 'attendance-%');
END $$;

COMMIT;
