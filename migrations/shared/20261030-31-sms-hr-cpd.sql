-- MyEduGuard HR: professional development (CPD) and staff ID cards.
--
--   sms_staff_cpd   a member of staff's training: a course, workshop, conference, INSET day or an
--                   online course, its provider, dates and hours, and its certificate (a file,
--                   record 'staff_cpd'). HR records it, or the member of staff logs their own and
--                   HR verifies it. The school may set the hours it expects a year.
--
-- Staff ID cards need no table: they are printed from the staff records, with the photo kept on
-- the record (a file, record 'staff', purpose 'avatar').
--
-- Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS sms.sms_staff_cpd (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    staff_id     text NOT NULL REFERENCES sms.sms_staff(id) ON DELETE CASCADE,
    title        text NOT NULL,
    kind         text NOT NULL DEFAULT 'course',
    provider     text,
    starts_on    date NOT NULL,
    ends_on      date,
    hours        numeric(6,1) NOT NULL DEFAULT 0,
    notes        text,
    logged_by    text,
    verified_by  text,
    verified_at  timestamptz,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_staff_cpd', 'sms_staff_cpd_check2', $q$'qualification'$q$, $q$CHECK (
    kind IN ('course', 'workshop', 'conference', 'inset', 'online', 'mentoring', 'qualification', 'other')
    AND hours >= 0 AND hours <= 2000 AND (ends_on IS NULL OR ends_on >= starts_on))$q$);
CREATE INDEX IF NOT EXISTS sms_staff_cpd_idx ON sms.sms_staff_cpd (staff_id, starts_on DESC);

-- The hours of CPD the school expects of each member of staff a year (0: no target).
ALTER TABLE sms.sms_hr_settings ADD COLUMN IF NOT EXISTS cpd_hours_target numeric(6,1) NOT NULL DEFAULT 0;

-- A CPD certificate is a file of the record 'staff_cpd'.
SELECT sms.widen_check('sms.sms_files', 'sms_files_entity_check', $q$'staff_cpd'$q$, $q$CHECK (entity_type IS NULL OR entity_type IN
    ('profile', 'application', 'enquiry', 'family', 'student', 'leave_request', 'assignment', 'submission', 'class_resource', 'pickup_person', 'incident',
     'safeguarding', 'achievement', 'service_hours', 'trip', 'staff', 'staff_document', 'staff_check', 'job_application', 'staff_leave', 'payslip',
     'staff_cpd'))$q$);

INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.cpd', 'app-sms', 'Professional Development (CPD)', 2, 'Training records, hours and certificates')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id = EXCLUDED.app_id, title = EXCLUDED.title, min_tier_rank = EXCLUDED.min_tier_rank,
    description = EXCLUDED.description, is_active = true;

COMMIT;
