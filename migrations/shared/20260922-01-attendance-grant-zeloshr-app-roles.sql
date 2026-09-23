-- Attendance schema was created by tvs_migrator; ZelosHR Container App roles
-- (zeloshradmin_dev / zeloshremployee_dev / tvs_app_dev) had no USAGE, so every
-- attendance API returned HTTP 500 (permission denied) while zeloshr tables worked.
--
-- Idempotent: skip roles that do not exist (prod may use non-_dev names).

DO $$
DECLARE
  r text;
  roles text[] := ARRAY[
    'zeloshradmin_dev',
    'zeloshremployee_dev',
    'tvs_app_dev',
    'zeloshradmin',
    'zeloshremployee',
    'tvs_app'
  ];
BEGIN
  FOREACH r IN ARRAY roles
  LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
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
    END IF;
  END LOOP;
END $$;
