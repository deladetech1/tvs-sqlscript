-- CloudHams (app-hospital), part 11: pictures in the file manager for medicines and store items
-- (the pack, the label, so the right one is picked) and for records that are better with a photo
-- (a wound, an incident, a broken machine, a fundus).
--
-- Idempotent; safe to re-run.

BEGIN;

SELECT hospital.widen_check('hospital.hospital_files', 'hospital_files_entity_check', $q$'entry'$q$,
    $q$CHECK (entity_type IS NULL OR entity_type IN ('facility', 'patient', 'encounter', 'order', 'expense', 'drug', 'entry'))$q$);

COMMIT;
