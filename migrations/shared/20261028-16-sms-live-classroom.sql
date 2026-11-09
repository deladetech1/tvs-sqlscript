-- MyEduGuard: live classes in MyEduGuard itself (the TroveSuite video conference service),
-- alongside the Zoom, Google Meet and Teams links.
--
--   sms_virtual_classes.provider 'live'   the class runs in MyEduGuard (also allowed by 20261028-09,
--                                        which re-adds the check on every deploy)
--   sms_virtual_classes.waiting_room     students wait until the teacher lets them in
--   sms_virtual_classes.live_*           when it actually started and ended, and the class record
--                                        the video service sends at the end (attendance, talk time,
--                                        poll results, top questions)
--   sms_live_attendance                  who was in the class, each time they joined (a student who
--                                        dropped out and came back has two rows), with what they did
--   sms_live_recordings                  recordings, copied into SMS's own storage
--   sms_live_events                      webhook ids already handled (deliveries are retried)
--
-- The video service keeps no data of its own: everything here arrives by its webhooks.
-- Idempotent.

BEGIN;

SELECT sms.widen_check('sms.sms_virtual_classes', 'sms_virtual_classes_provider_check', $q$'live'$q$, $q$CHECK (provider IN ('zoom', 'meet', 'teams', 'other', 'live'))$q$);
ALTER TABLE sms.sms_virtual_classes ADD COLUMN IF NOT EXISTS waiting_room boolean NOT NULL DEFAULT true;
ALTER TABLE sms.sms_virtual_classes ADD COLUMN IF NOT EXISTS live_started_at timestamptz;
ALTER TABLE sms.sms_virtual_classes ADD COLUMN IF NOT EXISTS live_ended_at timestamptz;
ALTER TABLE sms.sms_virtual_classes ADD COLUMN IF NOT EXISTS live_summary jsonb;

CREATE TABLE IF NOT EXISTS sms.sms_live_attendance (
    session_id       text PRIMARY KEY,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    virtual_class_id text NOT NULL REFERENCES sms.sms_virtual_classes(id) ON DELETE CASCADE,
    student_id       text REFERENCES sms.sms_students(id) ON DELETE SET NULL,
    user_id          text,
    name             text NOT NULL,
    role             text NOT NULL,
    in_breakout      boolean NOT NULL DEFAULT false,
    joined_at        timestamptz NOT NULL,
    left_at          timestamptz,
    seconds          integer,
    engagement       jsonb
);
CREATE INDEX IF NOT EXISTS sms_live_attendance_class_idx ON sms.sms_live_attendance (virtual_class_id, joined_at);
CREATE INDEX IF NOT EXISTS sms_live_attendance_student_idx ON sms.sms_live_attendance (student_id);

CREATE TABLE IF NOT EXISTS sms.sms_live_recordings (
    id               text PRIMARY KEY,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    virtual_class_id text NOT NULL REFERENCES sms.sms_virtual_classes(id) ON DELETE CASCADE,
    status           text NOT NULL DEFAULT 'copying',
    media_path       text,
    timeline_path    text,
    seconds          integer,
    size_bytes       bigint,
    error            text,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_live_recordings DROP CONSTRAINT IF EXISTS sms_live_recordings_status_check;
ALTER TABLE sms.sms_live_recordings ADD CONSTRAINT sms_live_recordings_status_check CHECK (status IN ('copying', 'ready', 'failed'));
CREATE INDEX IF NOT EXISTS sms_live_recordings_class_idx ON sms.sms_live_recordings (virtual_class_id);

CREATE TABLE IF NOT EXISTS sms.sms_live_events (
    id          text PRIMARY KEY,
    event       text NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now()
);

COMMIT;
