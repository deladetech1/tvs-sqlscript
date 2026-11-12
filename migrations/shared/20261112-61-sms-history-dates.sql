-- MyEduGuard: a student's history is dated when things happened.
--
-- An enrolment line was dated the day it was typed in, so a student admitted in 2020 and added
-- this week read "Enrolled 12 Nov 2026". It now takes the admission date; a withdrawal or transfer
-- out takes the day the student left. This puts the lines already written right.
--
-- Staff phones are kept as +233241234567 whatever spacing they were typed with (one typed
-- "+23320 112233" showed just so); those already written are tidied the same way.
--
-- Idempotent; safe to re-run.

BEGIN;

UPDATE sms.sms_student_history h
   SET on_date = x.admitted_on
  FROM sms.sms_students x
 WHERE x.id = h.student_id AND h.outcome = 'enrolled' AND x.admitted_on IS NOT NULL
   AND h.on_date IS DISTINCT FROM x.admitted_on;

UPDATE sms.sms_student_history h
   SET on_date = x.left_on
  FROM sms.sms_students x
 WHERE x.id = h.student_id AND h.outcome IN ('withdrawn', 'transferred_out') AND x.left_on IS NOT NULL
   AND h.on_date IS DISTINCT FROM x.left_on
   AND h.id = (SELECT h2.id FROM sms.sms_student_history h2 WHERE h2.student_id = h.student_id
                 AND h2.outcome IN ('withdrawn', 'transferred_out') ORDER BY h2.on_date DESC, h2.id DESC LIMIT 1);

UPDATE sms.sms_staff
   SET phone = '+' || regexp_replace(phone, '\D', '', 'g')
 WHERE phone ~ '^\s*\+' AND phone ~ '[^0-9+]';

UPDATE sms.sms_staff
   SET emergency_phone = '+' || regexp_replace(emergency_phone, '\D', '', 'g')
 WHERE emergency_phone ~ '^\s*\+' AND emergency_phone ~ '[^0-9+]';

COMMIT;
