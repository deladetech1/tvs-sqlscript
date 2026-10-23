-- Attendance schema was created by tvs_migrator; ZelosHR Container App roles
-- (zeloshradmin_dev / zeloshremployee_dev / tvs_app_dev) had no USAGE, so every
-- attendance API returned HTTP 500 (permission denied) while zeloshr tables worked.
--
-- 2026-10-23: granted to THIS database's app group(s) -- control_plane.app_groups_here(),
-- defined in 20261001-01 -- instead of a fixed list of role names. The fixed list
-- named the POOLED roles (tvs_app_dev, zeloshradmin_dev, ...), and roles are per
-- server, so every silo database on the shared server granted the pooled ZelosHR
-- logins DML on that silo's attendance data -- while the silo's own ZelosHR, which
-- the list did not name, got nothing. The pooled logins still get it in the pool
-- through tvs_app_<env>; the silo's logins now get it through their own group.
--
-- On a database's very first deploy control_plane does not exist yet (this file sorts
-- before 20261001-01), so it skips; 20261023-01 makes the same grants later in that
-- deploy. On a one-client server (enterprise / BYOD) the old names are kept as well.
--
-- Idempotent: safe to re-run.

DO $$
DECLARE
  r text;
  u text;
BEGIN
  IF to_regnamespace('attendance') IS NULL THEN
    RAISE NOTICE 'attendance: no schema here, nothing to grant';
    RETURN;
  END IF;
  IF to_regprocedure('control_plane.app_groups_here(boolean)') IS NULL THEN
    RAISE NOTICE 'attendance: control_plane not created yet; 20261023-01 grants this later in the deploy';
    RETURN;
  END IF;
  u := (control_plane.this_database_unit()).unit;

  FOR r IN
    SELECT control_plane.app_groups_here()
    UNION
    SELECT x FROM unnest(ARRAY['zeloshradmin', 'zeloshremployee', 'tvs_app']) AS x
     WHERE u = 'single' AND EXISTS (SELECT 1 FROM pg_roles WHERE rolname = x)
  LOOP
    EXECUTE format('GRANT USAGE ON SCHEMA attendance TO %I', r);
    EXECUTE format(
      'GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA attendance TO %I',
      r);
    EXECUTE format(
      'GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA attendance TO %I',
      r);
    -- Future tables created by the migrator role in this schema.
    EXECUTE format(
      'ALTER DEFAULT PRIVILEGES IN SCHEMA attendance GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO %I',
      r);
    EXECUTE format(
      'ALTER DEFAULT PRIVILEGES IN SCHEMA attendance GRANT USAGE, SELECT ON SEQUENCES TO %I',
      r);
  END LOOP;
END $$;
