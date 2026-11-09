-- CloudHams (app-hospital), part 10: what the QA pass of 7 Nov 2026 needed in the database.
--
-- Allergies: "no known allergies" is something a person was asked and answered, never what an
-- empty list means. Until it is set, the record reads "Allergies not recorded".
--
-- Idempotent; safe to re-run.

BEGIN;

ALTER TABLE hospital.hospital_patients ADD COLUMN IF NOT EXISTS no_known_allergies boolean NOT NULL DEFAULT false;

COMMIT;
