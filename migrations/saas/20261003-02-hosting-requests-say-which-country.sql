-- =====================================================================================
-- A hosting request says which country the client is in.
--
-- Missing from the first version, and it is the question that decides whether we can
-- take the request at all: where a customer is determines which region their data may
-- sit in, which legal entity bills them, and whether there is a residency obligation
-- nobody mentioned. preferred_region asks where they want the data; this asks where
-- THEY are, and the two are regularly not the same answer.
--
-- Two columns rather than one. The ISO code is what anything mechanical should read --
-- it is stable, and it is what the form actually selects. The name is stored beside it
-- so a row still reads plainly in a query or an email years later, without a lookup
-- table nobody maintains; a country being renamed is rarer than this table being read
-- by a person.
--
-- Nullable, because migrations re-run and the rows already in the table were written
-- before the column existed. The API requires it going forward.
-- =====================================================================================

ALTER TABLE deladetech.dlt_hosting_requests
    ADD COLUMN IF NOT EXISTS country_code text,
    ADD COLUMN IF NOT EXISTS country_name text;

COMMENT ON COLUMN deladetech.dlt_hosting_requests.country_code IS
    'ISO 3166-1 alpha-2, lower case, as the signup form selects it (e.g. gh, gb, us).';
COMMENT ON COLUMN deladetech.dlt_hosting_requests.country_name IS
    'The country name as shown to the requester, kept so the row reads without a lookup.';

-- Two letters or nothing. Cheap, and it stops a free-text answer ("UK", "England",
-- "United Kingdom") reaching a column that is meant to be matched on.
ALTER TABLE deladetech.dlt_hosting_requests
    DROP CONSTRAINT IF EXISTS ck_dlt_hosting_requests_country;

ALTER TABLE deladetech.dlt_hosting_requests
    ADD CONSTRAINT ck_dlt_hosting_requests_country CHECK (
        country_code IS NULL OR country_code ~ '^[a-z]{2}$'
    );

-- "Where are our customers?" is a question this table should answer cheaply.
CREATE INDEX IF NOT EXISTS ix_dlt_hosting_requests_country
    ON deladetech.dlt_hosting_requests (country_code);

-- ----------------------------------------------------------------------------- checks
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'deladetech'
           AND table_name = 'dlt_hosting_requests'
           AND column_name = 'country_code'
    ) THEN
        RAISE EXCEPTION 'country_code was not added to deladetech.dlt_hosting_requests';
    END IF;

    -- Prove the constraint is in force rather than trusting the DDL: an upper-case
    -- or spelled-out country is exactly what a hand-written INSERT would put here.
    BEGIN
        INSERT INTO deladetech.dlt_hosting_requests
            (hosting_kind, fullname, email, contact, company_name, country_code)
        VALUES ('SILO_SHARED', 'probe', 'probe@example.com', '+000', 'probe', 'GB');
        RAISE EXCEPTION 'an upper-case country_code was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;  -- refused, as it should be
    END;

    BEGIN
        INSERT INTO deladetech.dlt_hosting_requests
            (hosting_kind, fullname, email, contact, company_name, country_code)
        VALUES ('SILO_SHARED', 'probe', 'probe@example.com', '+000', 'probe', 'United Kingdom');
        RAISE EXCEPTION 'a spelled-out country_code was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    RAISE NOTICE 'hosting requests now record the requester''s country';
END $$;
