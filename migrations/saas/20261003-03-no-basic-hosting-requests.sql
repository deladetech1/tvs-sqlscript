-- =====================================================================================
-- BASIC is the shared database, and nothing that reaches this table.
--
-- Every row here is a request for something hand-provisioned: a silo is a database,
-- roles, secrets and containers we build before anyone can sign in, and dedicated is
-- a server and a storage account of their own. That work is not sold at the entry
-- plan, so a BASIC request is one we would only decline after someone had filled the
-- form -- which is the worst place to say no.
--
-- The shared database is the BASIC path, and it never becomes a request: that one
-- creates its own account, which is why 'shared_database' is absent from the
-- hosting_kind CHECK as well.
--
-- Narrowing the existing tier CHECK rather than adding a second one, so there is a
-- single place that answers "which plans may be asked for here".
-- =====================================================================================

DO $$
DECLARE n integer;
BEGIN
    -- Say so plainly rather than failing on a constraint violation three lines
    -- later. Nothing should match -- the signup form has never offered BASIC on a
    -- path that writes here -- but a migration that re-runs everywhere should
    -- explain itself when it cannot proceed.
    SELECT count(*) INTO n
      FROM deladetech.dlt_hosting_requests
     WHERE requested_tier = 'BASIC';
    IF n > 0 THEN
        RAISE EXCEPTION
            '% hosting request(s) ask for BASIC; decide what they should be before '
            'narrowing the constraint', n;
    END IF;
END $$;

ALTER TABLE deladetech.dlt_hosting_requests
    DROP CONSTRAINT IF EXISTS ck_dlt_hosting_requests_tier;

ALTER TABLE deladetech.dlt_hosting_requests
    ADD CONSTRAINT ck_dlt_hosting_requests_tier CHECK (
        requested_tier IS NULL
        OR requested_tier IN ('ADVANCE', 'PREMIUM', 'ENTERPRISE')
    );

-- ----------------------------------------------------------------------------- checks
DO $$
BEGIN
    -- Prove the narrowed constraint is in force, rather than trusting the DDL.
    BEGIN
        INSERT INTO deladetech.dlt_hosting_requests
            (hosting_kind, fullname, email, contact, company_name,
             country_code, requested_tier)
        VALUES ('SILO_SHARED', 'probe', 'probe@example.com', '+000', 'probe',
                'gh', 'BASIC');
        RAISE EXCEPTION 'a BASIC hosting request was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;  -- refused, as it should be
    END;

    -- And that the plans we DO take still go in: a constraint that refuses
    -- everything would pass the test above while breaking the form.
    BEGIN
        INSERT INTO deladetech.dlt_hosting_requests
            (hosting_kind, fullname, email, contact, company_name,
             country_code, requested_tier)
        VALUES ('SILO_SHARED', 'probe', 'probe@example.com', '+000', 'probe',
                'gh', 'ADVANCE');
        RAISE EXCEPTION 'probe_ok';  -- roll the row back without leaving it behind
    EXCEPTION
        WHEN check_violation THEN
            RAISE EXCEPTION 'an ADVANCE hosting request was refused';
        WHEN raise_exception THEN
            IF SQLERRM <> 'probe_ok' THEN RAISE; END IF;
    END;

    RAISE NOTICE 'hosting requests start at ADVANCE';
END $$;
