-- Projects: the summary email comes every 30 minutes by default, and each person may choose
-- how often.
--
--   * prj_member_prefs.digest: 15m, 30m, 1h, 2h, 4h (in working hours, only with something
--     open to say), twice_daily (9:00 and 15:00), daily, weekly, or off. Default 30m.
--   * The rows that said 'weekly' were written by the summary job itself, from the column's
--     old default, not chosen by anyone (the setting had no other default), so they move to
--     the new default -- ONCE, on the run that widens the constraint. Re-runs see the new
--     constraint and leave everyone's choice alone, including anyone who picks weekly later.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

DO $$
BEGIN
    IF to_regclass('projects.prj_member_prefs') IS NULL THEN
        RETURN;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conrelid = 'projects.prj_member_prefs'::regclass
           AND conname = 'prj_member_prefs_digest_check'
           AND pg_get_constraintdef(oid) LIKE '%30m%'
    ) THEN
        ALTER TABLE projects.prj_member_prefs DROP CONSTRAINT IF EXISTS prj_member_prefs_digest_check;
        UPDATE projects.prj_member_prefs SET digest = '30m' WHERE digest = 'weekly';
        ALTER TABLE projects.prj_member_prefs ADD CONSTRAINT prj_member_prefs_digest_check
            CHECK (digest IN ('15m', '30m', '1h', '2h', '4h', 'twice_daily', 'daily', 'weekly', 'off'));
    END IF;
END $$;

ALTER TABLE projects.prj_member_prefs ALTER COLUMN digest SET DEFAULT '30m';

COMMIT;
