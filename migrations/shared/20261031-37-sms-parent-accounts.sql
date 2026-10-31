-- MyEduGuard: parents sign in to the school portal.
--
--   sms_guardians.user_id   a guardian's portal account (a Core Platform user of the tenant, like a
--                           student's): they sign in with their phone number or email and a
--                           password, and see each of their children -- the family page's
--                           pages, behind a password, with a dashboard. The family page's link keeps
--                           working for families who never set one.
--
-- Idempotent; safe to re-run.

BEGIN;

ALTER TABLE sms.sms_guardians ADD COLUMN IF NOT EXISTS user_id text;
CREATE UNIQUE INDEX IF NOT EXISTS sms_guardians_user_uq ON sms.sms_guardians (user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS sms_guardians_phone_idx ON sms.sms_guardians (regexp_replace(coalesce(phone, ''), '\D', '', 'g'));
CREATE INDEX IF NOT EXISTS sms_guardians_email_idx ON sms.sms_guardians (lower(email));

-- A guardian's activation link names no student.
COMMENT ON COLUMN sms.sms_portal_tokens.student_id IS 'The student an activation or reset link is for; NULL for staff and parents.';

COMMIT;
