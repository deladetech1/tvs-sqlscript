-- Help Desk R7: import row notes.
--
--   hd_import_rows.note   information about a row that is not an error: why a row was skipped
--                         (for example, a ticket already carries its external reference). R6 kept
--                         that text in error; it is moved here for skipped rows whose error starts
--                         "Skipped:", and error is cleared.
--
-- No grants. Design: tvs-shared-apps-bk docs/helpdesk/contracts/R7.md §1. Idempotent; safe to re-run.

BEGIN;

ALTER TABLE helpdesk.hd_import_rows ADD COLUMN IF NOT EXISTS note text;

-- A re-run finds no skipped row with a "Skipped:" error left, so it changes nothing.
UPDATE helpdesk.hd_import_rows
   SET note  = coalesce(note, error),
       error = NULL
 WHERE outcome = 'skipped' AND error LIKE 'Skipped:%';

COMMIT;
