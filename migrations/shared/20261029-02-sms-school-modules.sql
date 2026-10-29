-- MyEduGuard: each school chooses its modules -- the sections of the menu it runs (admissions,
-- teaching, scheduling, attendance, grading, online learning, welfare, inclusion, boarding).
-- NULL is all of them. Turning one off hides it from the menu; its data stays. Idempotent.

BEGIN;

ALTER TABLE sms.sms_profiles ADD COLUMN IF NOT EXISTS modules text[];
ALTER TABLE sms.sms_profiles DROP CONSTRAINT IF EXISTS sms_profiles_modules_check;
ALTER TABLE sms.sms_profiles ADD CONSTRAINT sms_profiles_modules_check CHECK (modules IS NULL OR (cardinality(modules) > 0 AND modules <@ ARRAY[
    'admissions', 'teaching', 'scheduling', 'attendance', 'grading', 'learning', 'welfare', 'inclusion', 'boarding']::text[]));

COMMIT;
