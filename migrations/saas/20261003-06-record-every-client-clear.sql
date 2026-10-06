-- =====================================================================================
-- What was cleared, by whom, and how much of it went.
--
-- Clearing a client deletes a tenant and everything belonging to it from the database it
-- lives in, then returns its route to the placeholder so the host can be set up again.
-- It crosses the same systems a setup does and is not reversible, so the one thing that
-- must survive it is the record that it happened.
--
-- Deliberately NOT part of dlt_client_setups. A setup row is the story of a client being
-- created and is deleted when that client is cleared -- which is exactly when this row
-- has to still exist. Keeping both in one table would mean the audit trail disappearing
-- with the thing it was auditing.
-- =====================================================================================

CREATE TABLE IF NOT EXISTS deladetech.dlt_client_clears (
    id            text        NOT NULL DEFAULT (gen_random_uuid())::text,

    -- Copied, not referenced. The tenant is gone by the time this row matters, so a
    -- foreign key would either block the delete or null the evidence.
    tenant_id     text        NOT NULL,
    tenant_name   text,
    host          text        NOT NULL,
    silo_key      text,
    hosting_kind  text        NOT NULL,

    -- How far it got. A clear touches a tenant database, the control plane and the
    -- setup records, and the same partial-failure problem applies as to a setup.
    rows_deleted  integer     NOT NULL DEFAULT 0,
    route_reset   boolean     NOT NULL DEFAULT false,
    setups_removed integer    NOT NULL DEFAULT 0,

    status        text        NOT NULL DEFAULT 'STARTED',
    failure_reason text,

    -- Who, and why. The reason is required by the API: a destructive action with no
    -- stated cause is one nobody can account for afterwards.
    reason        text,
    performed_by  text        NOT NULL,

    cdatetime     timestamptz NOT NULL DEFAULT now(),
    udatetime     timestamptz,

    CONSTRAINT pk_dlt_client_clears PRIMARY KEY (id),
    CONSTRAINT ck_dlt_client_clears_status CHECK (
        status IN ('STARTED', 'TENANT_CLEARED', 'COMPLETED', 'FAILED')
    )
);

CREATE INDEX IF NOT EXISTS ix_dlt_client_clears_recent
    ON deladetech.dlt_client_clears (cdatetime DESC);
CREATE INDEX IF NOT EXISTS ix_dlt_client_clears_host
    ON deladetech.dlt_client_clears (host, cdatetime DESC);

COMMENT ON TABLE deladetech.dlt_client_clears IS
    'One row per client cleared from the console. Outlives the setup record it '
    'replaces, because the setup row is deleted as part of the clear.';

-- -------------------------------------------------------------------------- grants
-- SELECT and INSERT and UPDATE, and no DELETE at all.
--
-- The other console tables allow UPDATE for workflow reasons. This one allows it only
-- so a clear can record its own progress; nothing may remove a row. An audit trail the
-- application can erase is not an audit trail.
DO $$
DECLARE grp text;
BEGIN
    FOR grp IN
        SELECT rolname FROM pg_roles
         WHERE rolname ~ '^tvs_app_[a-z0-9]+$' AND NOT rolcanlogin
    LOOP
        EXECUTE format('GRANT USAGE ON SCHEMA deladetech TO %I', grp);
        EXECUTE format(
            'GRANT SELECT, INSERT, UPDATE ON deladetech.dlt_client_clears TO %I', grp);
        RAISE NOTICE 'dlt_client_clears: granted to %', grp;
    END LOOP;
END $$;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer;
BEGIN
    IF to_regclass('deladetech.dlt_client_clears') IS NULL THEN
        RAISE EXCEPTION 'deladetech.dlt_client_clears was not created';
    END IF;

    -- Still our own records, so still not in the retention registry.
    SELECT count(*) INTO n FROM core_platform.cp_app_schemas WHERE schema_name = 'deladetech';
    IF n > 0 THEN
        RAISE EXCEPTION 'deladetech is in cp_app_schemas; the retention job would purge '
                        'the record of every client deletion';
    END IF;

    -- No application role may delete from it. Checked rather than assumed, because the
    -- whole value of the table rests on it.
    SELECT count(*) INTO n
      FROM information_schema.role_table_grants
     WHERE table_schema = 'deladetech' AND table_name = 'dlt_client_clears'
       AND privilege_type = 'DELETE' AND grantee LIKE 'tvs_app%';
    IF n > 0 THEN
        RAISE EXCEPTION 'an application role can DELETE from the clear audit trail';
    END IF;

    RAISE NOTICE 'client clears are recorded';
END $$;
