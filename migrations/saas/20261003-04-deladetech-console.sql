-- =====================================================================================
-- The console's own tables: who operates it, and what they did.
--
-- deladetech already holds our side of the conversation with people who have no
-- tenant yet (dlt_hosting_requests). This adds the other half: the staff who work
-- those requests, and a record of each client we stood up as a result.
--
-- SAAS-ONLY, like the rest of deladetech. The console is one deployment pointed at
-- the pooled control database; a silo has no console of its own, and an enterprise
-- install is the customer's own deployment.
--
-- WHY OPERATORS ARE NOT cp_users
-- cp_users is tenant data -- every row carries a tenant_id and belongs to a customer.
-- Staff belong to no tenant, and putting them in cp_users would mean inventing a
-- tenant for Trovesuite itself and then carefully excluding it from every customer
-- listing for the rest of time. The 'system-tenant-id' row exists for platform
-- bookkeeping, not as somewhere to hide employees.
--
-- It also keeps the blast radius honest: a console operator can read every tenant's
-- metadata, which is a strictly larger privilege than any customer account has. That
-- should not be a flag on a row in the customers' own table.
-- =====================================================================================

-- ------------------------------------------------------------------------ operators
CREATE TABLE IF NOT EXISTS deladetech.dlt_operators (
    id              text        NOT NULL DEFAULT (gen_random_uuid())::text,

    email           text        NOT NULL,
    fullname        text        NOT NULL,
    -- bcrypt. Never a plaintext column, and never reversible: the console can
    -- reset an operator's password, not tell anyone what it is.
    password_hash   text        NOT NULL,

    -- What they may do. Deliberately three, not a permission matrix: this is a
    -- handful of staff, and the platform already demonstrates how expensive a
    -- fine-grained catalogue is to keep correct.
    --   VIEWER    read everything, change nothing
    --   OPERATOR  work requests, set a client up
    --   OWNER     the above, plus managing operators
    role            text        NOT NULL DEFAULT 'VIEWER',

    is_active       boolean     NOT NULL DEFAULT true,
    -- Set on first sign-in. A seeded operator starts with a password we chose,
    -- so the console makes them change it before anything else.
    must_change_password boolean NOT NULL DEFAULT true,
    last_login_at   timestamptz,

    delete_status   text        NOT NULL DEFAULT 'NOT_DELETED',
    cdate           text,
    ctime           text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text,
    udatetime       timestamptz,
    updated_by      text,

    CONSTRAINT pk_dlt_operators PRIMARY KEY (id),
    CONSTRAINT ck_dlt_operators_role CHECK (role IN ('VIEWER', 'OPERATOR', 'OWNER'))
);

-- One account per address. Lower-cased so Ada@ and ada@ cannot both exist, which
-- is the shape of a sign-in bug nobody finds until two people share a mailbox.
CREATE UNIQUE INDEX IF NOT EXISTS ux_dlt_operators_email
    ON deladetech.dlt_operators (lower(email))
 WHERE delete_status = 'NOT_DELETED';

-- ------------------------------------------------------------------------- sessions
CREATE TABLE IF NOT EXISTS deladetech.dlt_operator_sessions (
    -- The SHA-256 of the cookie value, never the value. A leaked database should
    -- not be a drawer full of live sessions.
    token_hash      text        NOT NULL,
    operator_id     text        NOT NULL,

    issued_at       timestamptz NOT NULL DEFAULT now(),
    expires_at      timestamptz NOT NULL,
    -- Set when someone signs out, or when an operator is deactivated. Kept rather
    -- than deleted so "who was signed in when that happened" stays answerable.
    revoked_at      timestamptz,

    ip              text,
    user_agent      text,

    CONSTRAINT pk_dlt_operator_sessions PRIMARY KEY (token_hash),
    CONSTRAINT fk_dlt_operator_sessions_operator
        FOREIGN KEY (operator_id) REFERENCES deladetech.dlt_operators (id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_dlt_operator_sessions_operator
    ON deladetech.dlt_operator_sessions (operator_id, expires_at DESC);

-- --------------------------------------------------------------------- client setup
-- What the console did, and to whom.
--
-- Standing a client up is several steps across systems that cannot share a
-- transaction: core-platform creates the tenant and owner, the control plane gets a
-- route row, the request is closed. If that stops halfway -- and it will, because one
-- of those is an HTTP call -- the only way to know how far it got is to have written
-- it down as it went.
CREATE TABLE IF NOT EXISTS deladetech.dlt_client_setups (
    id              text        NOT NULL DEFAULT (gen_random_uuid())::text,

    -- The request this came from, where there was one. Nullable: a client can be
    -- set up without having filled in the form -- a deal done over a call.
    hosting_request_id text,

    -- What we are standing up.
    hosting_kind    text        NOT NULL,
    host            text        NOT NULL,
    silo_key        text,
    company_name    text        NOT NULL,
    owner_email     text        NOT NULL,

    -- Filled in as the steps complete, so a half-finished setup says where it got
    -- to rather than leaving someone to guess from three systems.
    tenant_id       text,
    route_written   boolean     NOT NULL DEFAULT false,
    request_closed  boolean     NOT NULL DEFAULT false,

    status          text        NOT NULL DEFAULT 'STARTED',
    failure_reason  text,

    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text,
    udatetime       timestamptz,

    CONSTRAINT pk_dlt_client_setups PRIMARY KEY (id),
    CONSTRAINT ck_dlt_client_setups_status CHECK (
        status IN ('STARTED', 'TENANT_CREATED', 'COMPLETED', 'FAILED')
    ),
    CONSTRAINT ck_dlt_client_setups_kind CHECK (
        hosting_kind IN ('SILO_SHARED', 'SILO_DEDICATED', 'BYO', 'SELF_HOSTED', 'POOLED')
    ),
    CONSTRAINT fk_dlt_client_setups_request
        FOREIGN KEY (hosting_request_id)
        REFERENCES deladetech.dlt_hosting_requests (id)
        ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS ix_dlt_client_setups_recent
    ON deladetech.dlt_client_setups (cdatetime DESC);

-- A host is one tenant's address, so two completed setups must not claim the same
-- one. Partial, because a FAILED attempt at a host should not block the retry that
-- fixes it.
CREATE UNIQUE INDEX IF NOT EXISTS ux_dlt_client_setups_host
    ON deladetech.dlt_client_setups (host)
 WHERE status <> 'FAILED';

-- ------------------------------------------------------------------------ comments
COMMENT ON TABLE deladetech.dlt_operators IS
    'Trovesuite staff who may sign in to the client console. Not tenant data: these '
    'people belong to no tenant and can read across all of them.';
COMMENT ON TABLE deladetech.dlt_operator_sessions IS
    'Live console sessions, keyed by the SHA-256 of the cookie value.';
COMMENT ON TABLE deladetech.dlt_client_setups IS
    'One row per client the console stood up, recording how far a multi-system '
    'setup got when it did not finish.';

-- -------------------------------------------------------------------------- grants
-- Same narrow shape as the hosting-requests grant: the pooled app group only.
--
-- NOT a loop over every tvs_app_% group. That is what control_plane does, and it
-- means a retired tenant's group keeps accruing privileges in objects created after
-- it. These tables hold staff credentials and a cross-tenant audit trail, which is
-- the last thing that should be handed out by a wildcard.
DO $$
DECLARE grp text;
BEGIN
    FOR grp IN
        SELECT rolname FROM pg_roles
         WHERE rolname ~ '^tvs_app_[a-z0-9]+$' AND NOT rolcanlogin
    LOOP
        EXECUTE format('GRANT USAGE ON SCHEMA deladetech TO %I', grp);
        EXECUTE format(
            'GRANT SELECT, INSERT, UPDATE ON deladetech.dlt_operators, '
            'deladetech.dlt_operator_sessions, deladetech.dlt_client_setups TO %I', grp);
        -- Sessions are the one thing the console genuinely deletes: an expired
        -- session row has no evidentiary value and they accumulate forever.
        EXECUTE format(
            'GRANT DELETE ON deladetech.dlt_operator_sessions TO %I', grp);
        RAISE NOTICE 'deladetech console tables: granted to %', grp;
    END LOOP;
END $$;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer;
BEGIN
    FOR n IN
        SELECT 1 FROM (VALUES
            ('dlt_operators'), ('dlt_operator_sessions'), ('dlt_client_setups')
        ) AS t(name)
        WHERE to_regclass('deladetech.' || t.name) IS NULL
    LOOP
        RAISE EXCEPTION 'a console table was not created';
    END LOOP;

    -- Still not tenant data, so still not in the retention registry -- registering
    -- deladetech would schedule staff accounts for deletion alongside activity logs.
    SELECT count(*) INTO n
      FROM core_platform.cp_app_schemas WHERE schema_name = 'deladetech';
    IF n > 0 THEN
        RAISE EXCEPTION 'deladetech is registered in cp_app_schemas; the retention '
                        'job would purge console operators';
    END IF;

    -- Two live setups must not claim one host. Prove the partial unique index is
    -- really in force, since it is the only thing standing between a typo and two
    -- tenants answering at the same address.
    BEGIN
        INSERT INTO deladetech.dlt_client_setups
            (hosting_kind, host, company_name, owner_email, status)
        VALUES ('SILO_SHARED', 'probe.example.invalid', 'probe', 'p@example.com', 'STARTED'),
               ('SILO_SHARED', 'probe.example.invalid', 'probe', 'p@example.com', 'STARTED');
        RAISE EXCEPTION 'two live setups were accepted for one host';
    EXCEPTION WHEN unique_violation THEN
        NULL;  -- refused, as it should be
    END;

    -- ...but a failed attempt must not block the retry that fixes it.
    BEGIN
        INSERT INTO deladetech.dlt_client_setups
            (hosting_kind, host, company_name, owner_email, status)
        VALUES ('SILO_SHARED', 'probe2.example.invalid', 'probe', 'p@example.com', 'FAILED'),
               ('SILO_SHARED', 'probe2.example.invalid', 'probe', 'p@example.com', 'STARTED');
        RAISE EXCEPTION 'probe_ok';
    EXCEPTION
        WHEN unique_violation THEN
            RAISE EXCEPTION 'a retry after a FAILED setup was refused';
        WHEN raise_exception THEN
            IF SQLERRM <> 'probe_ok' THEN RAISE; END IF;
    END;

    RAISE NOTICE 'deladetech console tables ready';
END $$;
