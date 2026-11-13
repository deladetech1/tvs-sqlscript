-- MyEduGuard: pay online wherever money is taken.
--
-- Online payments went through the organisation's gateway in Core Platform for a family's fees,
-- trips and wallet, and the alumni pages. The school office now offers it at every counter too:
-- fees, trips, wallet top-ups, the application fee, the re-enrolment deposit, library fines,
-- transport fees, facility hire, the school shop, event tickets and gifts -- and an applicant
-- pays the application fee, and a family the re-enrolment deposit, from their own pages.
--
--   created_by   who at the school started it (their name goes on what is recorded)
--   description  what it is for, as the gateway was told
--   note         why a paid payment could not be recorded (status to_record), or how it was resolved
--
-- A payment the gateway took that cannot be recorded (a fine paid at the desk meanwhile, a shop
-- item sold out) is never dropped: it waits as to_record for the bursar to record again or
-- resolve (refund it), with the reason.
--
-- Idempotent; safe to re-run.

BEGIN;

ALTER TABLE sms.sms_online_payments ADD COLUMN IF NOT EXISTS created_by text;
ALTER TABLE sms.sms_online_payments ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE sms.sms_online_payments ADD COLUMN IF NOT EXISTS note text;

SELECT sms.widen_check('sms.sms_online_payments', 'sms_online_payments_check', $q$'to_record'$q$, $q$CHECK (
    subject IN ('fees', 'trip', 'wallet', 'ticket', 'donation', 'application', 'deposit', 'fine', 'transport', 'booking', 'shop')
    AND status IN ('pending', 'paid', 'failed', 'to_record', 'resolved') AND amount_minor > 0)$q$);

CREATE INDEX IF NOT EXISTS sms_online_payments_profile_idx ON sms.sms_online_payments (profile_id, cdatetime DESC);

COMMIT;
