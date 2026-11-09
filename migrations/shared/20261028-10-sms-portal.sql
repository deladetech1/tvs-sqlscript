-- SMS: the school portal -- where students, teachers and the head sign in (tvs-student-teacher-ft),
-- at the school's own address (<label>.sms.trovesuite.com).
--
--   sms_profiles.portal_label    the school's address on the portal (osupresby -> osupresby.sms...)
--   sms_students.user_id         the student's portal account: a Core Platform user of the tenant,
--                                signed in with the student number
--   sms_portal_tokens            activation and password-reset links, each used once, expiring
--
-- Staff sign in with their Core Platform account (email). Idempotent.

BEGIN;

ALTER TABLE sms.sms_profiles ADD COLUMN IF NOT EXISTS portal_label text;
ALTER TABLE sms.sms_profiles DROP CONSTRAINT IF EXISTS sms_profiles_portal_label_check;
ALTER TABLE sms.sms_profiles ADD CONSTRAINT sms_profiles_portal_label_check CHECK (portal_label IS NULL OR portal_label ~ '^[a-z0-9]([a-z0-9-]{1,38}[a-z0-9])$');
CREATE UNIQUE INDEX IF NOT EXISTS sms_profiles_portal_label_idx ON sms.sms_profiles (portal_label) WHERE portal_label IS NOT NULL AND deleted_at IS NULL;

ALTER TABLE sms.sms_students ADD COLUMN IF NOT EXISTS user_id text;
CREATE UNIQUE INDEX IF NOT EXISTS sms_students_user_idx ON sms.sms_students (tenant_id, user_id) WHERE user_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS sms.sms_portal_tokens (
    token       text PRIMARY KEY,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    user_id     text NOT NULL,
    student_id  text REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    kind        text NOT NULL,
    sent_to     text,
    sent_via    text,
    created_by  text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    expires_at  timestamptz NOT NULL,
    used_at     timestamptz
);
ALTER TABLE sms.sms_portal_tokens DROP CONSTRAINT IF EXISTS sms_portal_tokens_kind_check;
ALTER TABLE sms.sms_portal_tokens ADD CONSTRAINT sms_portal_tokens_kind_check CHECK (kind IN ('activate', 'reset'));
ALTER TABLE sms.sms_portal_tokens DROP CONSTRAINT IF EXISTS sms_portal_tokens_via_check;
ALTER TABLE sms.sms_portal_tokens ADD CONSTRAINT sms_portal_tokens_via_check CHECK (sent_via IS NULL OR sent_via IN ('email', 'sms', 'printed'));
CREATE INDEX IF NOT EXISTS sms_portal_tokens_user_idx ON sms.sms_portal_tokens (user_id, kind);

COMMIT;
