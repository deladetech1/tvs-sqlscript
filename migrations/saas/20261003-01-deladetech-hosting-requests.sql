-- =====================================================================================
-- deladetech: our own business records, not any tenant's data.
--
-- The first schema in this database that does not belong to a tenant. Everything in
-- core_platform is scoped to one -- a tenant_id on the row, a group that can read it --
-- and everything in mystoreguard / loandrift / zeloshr is one app's data for one
-- tenant. These rows are neither: they are enquiries from people who have NO tenant
-- yet, addressed to us.
--
-- Hence a schema named after the company rather than a product. Putting them in
-- core_platform would have meant inventing a tenant for someone who has not got one,
-- and the audit-retention convention sweeps tenant tables by (tenant_id, cdatetime) --
-- which is the opposite of what a sales enquiry needs.
--
-- SAAS-ONLY on purpose. migrations/shared/ reaches every silo and every self-hosted
-- install, and none of them take inbound signups: a silo is one customer who already
-- exists, and an enterprise install is their own deployment. Only the pooled platform
-- has a signup page pointed at it.
--
-- WHY THE TABLE EXISTS
-- Choosing anything other than the shared database provisions nothing on signing up.
-- A silo needs a database, roles, secrets and containers built before anyone can sign
-- in, so those paths collect what we need and a person reads the request. This is where
-- the request lands between the two.
--
-- WHAT IT DELIBERATELY DOES NOT HOLD
-- No credentials. "Bring your own database" needs a host, a password and probably a
-- network route, and none of that belongs in a table that an application role can
-- SELECT. The row records what they are asking for and enough to contact them; the
-- secrets are collected out of band and go to Key Vault, which is where every other
-- credential in this platform lives.
-- =====================================================================================

CREATE SCHEMA IF NOT EXISTS deladetech;

COMMENT ON SCHEMA deladetech IS
    'Trovesuite''s own business records -- inbound requests from people who have no '
    'tenant yet. Not tenant data, and not swept by the audit-log retention job.';

CREATE TABLE IF NOT EXISTS deladetech.dlt_hosting_requests (
    id              text        NOT NULL DEFAULT (gen_random_uuid())::text,

    -- Which path on the signup page they came down. One table rather than four
    -- because the fields are all but identical and "what is outstanding?" should
    -- be one query; the differences are the nullable columns below.
    hosting_kind    text        NOT NULL,
    -- The plan they say they want. Advisory: what they are entitled to is settled
    -- when the subscription is created, not here.
    requested_tier  text,

    -- Who to talk to. Same shape as the enterprise enquiry form, so the two can be
    -- worked from one list.
    fullname        text        NOT NULL,
    email           text        NOT NULL,
    contact         text        NOT NULL,
    company_name    text        NOT NULL,
    description     text,

    -- DEDICATED only: the point of the tier is that data residency is a choice, so
    -- it has to be asked at request time rather than assumed.
    preferred_region    text,
    expected_locations  integer,

    -- BRING YOUR OWN only, and non-secret by design. Enough to judge whether we can
    -- support it; the credentials and the network route are collected out of band.
    byo_provider        text,
    byo_postgres_version text,
    byo_notes           text,

    -- Where this request has got to. A request is a small workflow, and without
    -- this the only way to know whether someone has been contacted is to remember.
    status          text        NOT NULL DEFAULT 'RECEIVED',
    status_note     text,

    delete_status   text        NOT NULL DEFAULT 'NOT_DELETED',
    is_active       boolean     NOT NULL DEFAULT true,
    cdate           text,
    ctime           text,
    cdatetime       timestamptz,
    created_by      text,
    udatetime       timestamptz,
    updated_by      text,
    deleted_by      text,

    CONSTRAINT pk_dlt_hosting_requests PRIMARY KEY (id),

    -- The four paths that are not self-service. shared_database is absent on
    -- purpose: that one creates its own account and never becomes a request.
    CONSTRAINT ck_dlt_hosting_requests_kind CHECK (
        hosting_kind IN ('SILO_SHARED', 'SILO_DEDICATED', 'BYO', 'SELF_HOSTED')
    ),
    CONSTRAINT ck_dlt_hosting_requests_tier CHECK (
        requested_tier IS NULL
        OR requested_tier IN ('BASIC', 'ADVANCE', 'PREMIUM', 'ENTERPRISE')
    ),
    CONSTRAINT ck_dlt_hosting_requests_status CHECK (
        status IN ('RECEIVED', 'CONTACTED', 'PROVISIONING', 'PROVISIONED', 'DECLINED')
    ),
    -- A dedicated request that names no region is a request we cannot act on: the
    -- whole tier is "your data sits where you choose".
    CONSTRAINT ck_dlt_hosting_requests_region CHECK (
        hosting_kind <> 'SILO_DEDICATED' OR preferred_region IS NOT NULL
    )
);

-- "What is outstanding?" is the question this table is read for.
CREATE INDEX IF NOT EXISTS ix_dlt_hosting_requests_status
    ON deladetech.dlt_hosting_requests (status, cdatetime DESC);

-- Someone asking twice should be found, not duplicated. Not a unique constraint:
-- a company may legitimately ask for a silo and later for a dedicated one.
CREATE INDEX IF NOT EXISTS ix_dlt_hosting_requests_email
    ON deladetech.dlt_hosting_requests (lower(email));

-- ------------------------------------------------------------------------ grants
-- Only core-platform, and only the group it belongs to.
--
-- Narrower than control_plane's grant on purpose. That one loops over every
-- tvs_app_% group, which means a retired tenant's group keeps accruing privileges
-- in databases created after it -- the thing that made dropping those roles
-- awkward. Core-platform owns the signup endpoint; nothing else needs these rows.
DO $$
DECLARE
    grp text;
BEGIN
    -- The POOLED group only: tvs_app_<env> has exactly one segment after the
    -- prefix, where a silo's is tvs_app_<silo>_<env>. My first draft looped over
    -- every tvs_app_% group -- the same mistake control_plane makes -- and granted
    -- these rows to tvs_app_shared_dev and tvs_app_tenantb_dev, two retired
    -- tenants' groups that still existed. A deleted tenant accruing privileges in
    -- schemas created after it is what made dropping those roles awkward in the
    -- first place.
    --
    -- This file is saas-only, so the pooled group is the only one that should ever
    -- see it; a silo has no signup page pointed at it.
    FOR grp IN
        SELECT rolname FROM pg_roles
         WHERE rolname ~ '^tvs_app_[a-z0-9]+$' AND NOT rolcanlogin
    LOOP
        EXECUTE format('GRANT USAGE ON SCHEMA deladetech TO %I', grp);
        EXECUTE format(
            'GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA deladetech TO %I', grp);
        EXECUTE format(
            'ALTER DEFAULT PRIVILEGES IN SCHEMA deladetech '
            'GRANT SELECT, INSERT, UPDATE ON TABLES TO %I', grp);
        -- No DELETE. A request is evidence of a conversation; closing one is a
        -- status change, and the delete_status column is how it disappears from a
        -- list without leaving the table.
        RAISE NOTICE 'deladetech: granted select/insert/update to %', grp;
    END LOOP;
END $$;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer;
BEGIN
    IF to_regclass('deladetech.dlt_hosting_requests') IS NULL THEN
        RAISE EXCEPTION 'deladetech.dlt_hosting_requests was not created';
    END IF;

    -- This table must NOT be registered in cp_app_schemas. That is the audit-log
    -- retention registry, and registering it would schedule sales enquiries for
    -- deletion alongside activity logs.
    SELECT count(*) INTO n FROM core_platform.cp_app_schemas WHERE schema_name = 'deladetech';
    IF n > 0 THEN
        RAISE EXCEPTION
            'deladetech is registered in cp_app_schemas; the retention job would purge these requests';
    END IF;

    -- A dedicated request without a region cannot be acted on, so prove the
    -- constraint is actually in force rather than trusting the DDL.
    BEGIN
        INSERT INTO deladetech.dlt_hosting_requests
            (hosting_kind, fullname, email, contact, company_name)
        VALUES ('SILO_DEDICATED', 'probe', 'probe@example.com', '+000', 'probe');
        RAISE EXCEPTION 'a SILO_DEDICATED request was accepted with no preferred_region';
    EXCEPTION WHEN check_violation THEN
        NULL;  -- refused, as it should be
    END;

    RAISE NOTICE 'deladetech.dlt_hosting_requests ready (not in the retention registry)';
END $$;
