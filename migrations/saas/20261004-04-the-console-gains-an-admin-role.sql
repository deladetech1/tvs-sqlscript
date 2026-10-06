-- =====================================================================================
-- ADMIN joins the console's roles.
--
-- An admin runs the console day to day -- reads everything, works requests, verifies
-- clients, sees billing -- and specifically may NOT set a client up or remove one, and
-- may not grant access. Only an owner does those three.
--
-- WHY THE DATABASE HAS TO KNOW
-- The role is enforced in the application, by capability rather than by rank (see
-- internal/auth/auth.go). The column's CHECK is not a second permission system -- it is
-- the guard that stops a typo or a direct UPDATE putting a value in there that the
-- application has no entry for. A role the code does not recognise grants nothing, so
-- the account silently stops working rather than gaining anything; still, an operator
-- row that cannot sign in is a support ticket nobody can explain, and the constraint
-- turns it into an error at the moment somebody writes it.
--
-- This is why the first attempt to create an admin returned 500: the application was
-- ready and the column was not.
--
-- WHY NOT A LOOKUP TABLE
-- Four values that change about once a year, read on every request. A table would add a
-- join and a second place for the list to be wrong. The one real cost of a CHECK is
-- exactly what happened here -- adding a value needs a migration -- and that is a cost
-- worth paying for a column that decides what somebody can do.
-- =====================================================================================

ALTER TABLE deladetech.dlt_operators
    DROP CONSTRAINT IF EXISTS ck_dlt_operators_role;

ALTER TABLE deladetech.dlt_operators
    ADD CONSTRAINT ck_dlt_operators_role
    CHECK (role IN ('VIEWER', 'OPERATOR', 'ADMIN', 'OWNER'));

COMMENT ON COLUMN deladetech.dlt_operators.role IS
    'VIEWER reads. OPERATOR also works requests and SETS CLIENTS UP. ADMIN runs the '
    'console but may NOT set a client up or remove one. OWNER may do everything, '
    'including removal and granting access. The roles do NOT nest -- an operator can '
    'set up and an admin cannot -- so the application checks capabilities, not rank.';

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer;
BEGIN
    -- The new value is accepted.
    BEGIN
        INSERT INTO deladetech.dlt_operators
            (id, email, fullname, role, password_hash, must_change_password)
        VALUES ('op_probe_admin', 'probe-admin@example.invalid', 'Probe', 'ADMIN',
                'x', true);
        RAISE EXCEPTION 'probe_ok';
    EXCEPTION
        WHEN check_violation THEN
            RAISE EXCEPTION 'ADMIN is still refused by the role constraint';
        WHEN raise_exception THEN
            IF SQLERRM <> 'probe_ok' THEN RAISE; END IF;
    END;

    -- ...and a value the application has no capabilities for is still refused, or the
    -- constraint is doing nothing.
    BEGIN
        INSERT INTO deladetech.dlt_operators
            (id, email, fullname, role, password_hash, must_change_password)
        VALUES ('op_probe_bad', 'probe-bad@example.invalid', 'Probe', 'SUPERUSER',
                'x', true);
        RAISE EXCEPTION 'an unknown role was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;  -- refused, as it should be
    END;

    -- Nothing was left behind by either probe.
    SELECT count(*) INTO n FROM deladetech.dlt_operators
     WHERE id IN ('op_probe_admin', 'op_probe_bad');
    IF n > 0 THEN
        RAISE EXCEPTION '% probe operator(s) survived', n;
    END IF;

    RAISE NOTICE 'the console has an ADMIN role';
END $$;
