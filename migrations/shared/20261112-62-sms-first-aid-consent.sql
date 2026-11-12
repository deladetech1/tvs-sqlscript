-- MyEduGuard: first-aid consent is not assumed.
--
-- A health record said "Agreed" to first aid before the family was asked, because the column
-- defaulted to true. It is now empty until the family answers (shown as "Not asked yet").
-- Records whose consent was never set apart from the default cannot be told from those that
-- were, so they are left as they are. Idempotent; safe to re-run.

BEGIN;

ALTER TABLE sms.sms_health_records ALTER COLUMN consent_first_aid DROP NOT NULL;
ALTER TABLE sms.sms_health_records ALTER COLUMN consent_first_aid DROP DEFAULT;

COMMIT;
