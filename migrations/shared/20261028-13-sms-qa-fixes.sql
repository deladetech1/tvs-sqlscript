-- MyEduGuard: what the first QA pass found.
--
--   classes of an archived year group    archived with it (archiving a year group now does this;
--                                        this clears the ones left behind, e.g. "QA-Core Basic 2 Gold")
--   sms_leave_requests.status            'cancelled': approved leave called off
--   sms_staff_checkins                   a day marked by hand: status (present, late, absent, sick,
--                                        leave, duty), a note, who recorded it; no time in when away
--   sms_calendar_events                  holidays, closures and events on the school calendar
--   sms_audit_logs                       "structure_classe" is "structure_class"; the school filled
--                                        in where the business has only one
--
-- Idempotent.

BEGIN;

UPDATE sms.sms_classes c SET archived_at = coalesce(y.archived_at, now())
  FROM sms.sms_year_groups y
 WHERE y.id = c.year_group_id AND y.archived_at IS NOT NULL AND c.archived_at IS NULL;

ALTER TABLE sms.sms_leave_requests DROP CONSTRAINT IF EXISTS sms_leave_requests_check2;
ALTER TABLE sms.sms_leave_requests ADD CONSTRAINT sms_leave_requests_check2
    CHECK (reason IN ('sick', 'medical', 'family', 'religious', 'travel', 'other') AND via IN ('portal', 'staff')
           AND status IN ('pending', 'approved', 'declined', 'withdrawn', 'cancelled'));

ALTER TABLE sms.sms_staff_checkins ALTER COLUMN in_at DROP NOT NULL;
ALTER TABLE sms.sms_staff_checkins ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'present';
ALTER TABLE sms.sms_staff_checkins ADD COLUMN IF NOT EXISTS note text;
ALTER TABLE sms.sms_staff_checkins ADD COLUMN IF NOT EXISTS recorded_by text;
ALTER TABLE sms.sms_staff_checkins DROP CONSTRAINT IF EXISTS sms_staff_checkins_method_check;
ALTER TABLE sms.sms_staff_checkins ADD CONSTRAINT sms_staff_checkins_method_check CHECK (method IN ('qr', 'mobile', 'biometric', 'manual'));
ALTER TABLE sms.sms_staff_checkins DROP CONSTRAINT IF EXISTS sms_staff_checkins_status_check;
ALTER TABLE sms.sms_staff_checkins ADD CONSTRAINT sms_staff_checkins_status_check
    CHECK (status IN ('present', 'late', 'absent', 'sick', 'leave', 'duty')
           AND (in_at IS NOT NULL OR status IN ('absent', 'sick', 'leave', 'duty')));

CREATE TABLE IF NOT EXISTS sms.sms_calendar_events (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles (id) ON DELETE CASCADE,
    title       text NOT NULL,
    kind        text NOT NULL DEFAULT 'event',
    starts_on   date NOT NULL,
    ends_on     date NOT NULL,
    no_school   boolean NOT NULL DEFAULT false,
    notes       text,
    created_by  text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    CHECK (ends_on >= starts_on)
);
ALTER TABLE sms.sms_calendar_events DROP CONSTRAINT IF EXISTS sms_calendar_events_kind_check;
ALTER TABLE sms.sms_calendar_events ADD CONSTRAINT sms_calendar_events_kind_check
    CHECK (kind IN ('holiday', 'closure', 'event', 'meeting', 'exam', 'sports'));
CREATE INDEX IF NOT EXISTS sms_calendar_events_idx ON sms.sms_calendar_events (profile_id, starts_on);

UPDATE sms.sms_audit_logs SET entity_type = 'structure_class' WHERE entity_type = 'structure_classe';

UPDATE sms.sms_audit_logs a SET profile_id = p.id
  FROM (SELECT bus_id, min(id) AS id FROM sms.sms_profiles WHERE deleted_at IS NULL GROUP BY bus_id HAVING count(*) = 1) p
 WHERE a.profile_id IS NULL AND a.bus_id = p.bus_id;

COMMIT;
