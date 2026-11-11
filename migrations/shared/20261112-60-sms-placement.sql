-- MyEduGuard: every student in the academic structure.
--
-- Admission classes now admit into a year group of the academic structure, and enrolment places
-- the student there (and in the year group's class, when it has one that year). This puts right
-- what was enrolled before:
--
--   1. an admission class named like one of the school's year groups is linked to it;
--   2. a student with no year group takes their class's, else their admission class's, else the
--      year group their class name names;
--   3. a student in a year group but no class, whose year group has one class that year, is
--      placed in it.
--
-- Nothing is guessed beyond a name that matches exactly (case aside). Idempotent; safe to re-run.

BEGIN;

UPDATE sms.sms_admission_classes c
   SET year_group_id = y.id
  FROM sms.sms_year_groups y
 WHERE c.year_group_id IS NULL AND y.profile_id = c.profile_id AND y.archived_at IS NULL
   AND lower(trim(y.name)) = lower(trim(c.name))
   AND (SELECT count(*) FROM sms.sms_year_groups y2 WHERE y2.profile_id = c.profile_id AND y2.archived_at IS NULL
          AND lower(trim(y2.name)) = lower(trim(c.name))) = 1;

UPDATE sms.sms_students x
   SET year_group_id = coalesce(
         (SELECT g.year_group_id FROM sms.sms_classes g WHERE g.id = x.class_group_id),
         (SELECT a.year_group_id FROM sms.sms_admission_classes a WHERE a.id = x.class_id),
         (SELECT y.id FROM sms.sms_year_groups y WHERE y.profile_id = x.profile_id AND y.archived_at IS NULL
             AND lower(trim(y.name)) = lower(trim(x.class_name))
             AND (SELECT count(*) FROM sms.sms_year_groups y2 WHERE y2.profile_id = x.profile_id AND y2.archived_at IS NULL
                    AND lower(trim(y2.name)) = lower(trim(x.class_name))) = 1)),
       updated_at = now()
 WHERE x.year_group_id IS NULL
   AND coalesce(
         (SELECT g.year_group_id FROM sms.sms_classes g WHERE g.id = x.class_group_id),
         (SELECT a.year_group_id FROM sms.sms_admission_classes a WHERE a.id = x.class_id),
         (SELECT y.id FROM sms.sms_year_groups y WHERE y.profile_id = x.profile_id AND y.archived_at IS NULL
             AND lower(trim(y.name)) = lower(trim(x.class_name)))) IS NOT NULL;

UPDATE sms.sms_students x
   SET class_group_id = c.id, class_name = c.name, updated_at = now()
  FROM sms.sms_classes c
 WHERE x.class_group_id IS NULL AND x.year_group_id IS NOT NULL AND x.status = 'active'
   AND c.profile_id = x.profile_id AND c.year_group_id = x.year_group_id AND c.archived_at IS NULL
   AND c.academic_year = coalesce(x.academic_year, (SELECT p.current_year FROM sms.sms_profiles p WHERE p.id = x.profile_id))
   AND (SELECT count(*) FROM sms.sms_classes c2 WHERE c2.profile_id = x.profile_id AND c2.year_group_id = x.year_group_id
          AND c2.archived_at IS NULL AND c2.academic_year = c.academic_year) = 1;

COMMIT;
