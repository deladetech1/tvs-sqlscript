-- =====================================================================================
-- The clear may delete the setup record it is supposed to delete.
--
-- Clearing a silo client removes its setup row so the host is free to be set up again.
-- It never worked. The app role was granted SELECT, INSERT, UPDATE on
-- dlt_client_setups and DELETE on nothing but dlt_operator_sessions -- written when
-- sessions really were "the one thing the console genuinely deletes", and never
-- revisited when the clear feature arrived and needed one more.
--
-- SO EVERY SILO CLEAR SAID IT WORKED AND LEFT THE HOST BLOCKED. The handler logs the
-- failure at WARN and carries on, so the operator saw status COMPLETED with
-- setups_removed = 0 and no reason given. Four clears in the audit table, all four
-- reporting 0. itech was cleared three times before anybody worked out why setting it
-- up again kept answering "There is already a COMPLETED setup for this host".
--
-- The deadlock it produced is worth recording, because the two screens disagreed and
-- each was individually right:
--   * setup refused -- a COMPLETED setup row existed, because this grant was missing
--   * clear refused -- the route held its placeholder, so it concluded nobody was set
--     up, which is the guard that stops a clear deleting by an id that matches nothing
-- Neither could run. The route had to be reconciled by hand before the clear would go.
--
-- WHAT IS DELIBERATELY NOT GRANTED
-- DELETE on dlt_client_clears. That is the audit trail of the very operation doing the
-- deleting, which is why the two tables were split in the first place -- see the
-- comment on DeleteSetupsForHost. A clear that could erase its own record is a clear
-- nobody can prove happened. There is a check below asserting it stays ungranted,
-- because "grant DELETE on the deladetech tables" is the obvious over-correction.
-- =====================================================================================

-- 2026-10-23: the grant this file was written for (DELETE on dlt_client_setups) now
-- goes to the console's own login, in 20261023-20, and no longer to the application
-- group -- every app login is a member of that group, and the console's tables were
-- how any of them could become a console OWNER (CONSOLE-GAPS gap 1). 20261023-21 takes
-- every console table from the group, every deploy, and asserts it. The checks below
-- keep the two DELETEs that must never exist.

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer;
BEGIN
    -- ...and the one that must stay missing. An app role that can delete a clear
    -- record can erase the evidence of a purge it performed.
    SELECT count(*) INTO n FROM information_schema.role_table_grants
     WHERE table_schema = 'deladetech' AND table_name = 'dlt_client_clears'
       AND privilege_type = 'DELETE'
       AND grantee ~ '^tvs_app_[a-z0-9]+$';
    IF n > 0 THEN
        RAISE EXCEPTION 'an app group may DELETE from dlt_client_clears, so a clear '
                        'can erase its own audit record';
    END IF;

    -- The operator tables keep their shape too: a console that can delete an operator
    -- row deletes who did what along with it.
    SELECT count(*) INTO n FROM information_schema.role_table_grants
     WHERE table_schema = 'deladetech' AND table_name = 'dlt_operators'
       AND privilege_type = 'DELETE'
       AND grantee ~ '^tvs_app_[a-z0-9]+$';
    IF n > 0 THEN
        RAISE EXCEPTION 'an app group may DELETE operators, which this migration was '
                        'not asking for';
    END IF;

    RAISE NOTICE 'no app group may delete the clear audit or an operator';
END $$;
