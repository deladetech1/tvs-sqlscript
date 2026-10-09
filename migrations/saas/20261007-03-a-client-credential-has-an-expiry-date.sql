-- =====================================================================================
-- When a BYOD client's storage credential dies, nobody finds out.
--
-- A client whose files live in their own storage gives us a token. It expires. When it
-- does, NOTHING RAISES: signed URLs simply stop being produced, `presign` returns None,
-- and their screens render with gaps where the images were. No user sees an error, no
-- log carries one, and the first report is somebody saying their logo disappeared --
-- days after the cause.
--
-- The application can see this coming: the expiry is inside the token, and
-- tvs-package's storage_health() reads it. But the application sees ONE route, on a
-- request, and nobody reads application logs looking for a date three weeks out. The
-- console is where somebody would notice, and the console cannot read those secrets --
-- deliberately, since they are a client's credentials.
--
-- So this is the same shape as the billing ledger: the side that CAN see it writes what
-- it saw, and the console reads the record.
--
-- NOT APPEND-ONLY, unlike ctl_billing_facts. A credential has one current state and no
-- history worth keeping -- "it expires on the 14th" replaces "it expires on the 14th".
-- The ledger is append-only because a revenue figure for a past month must never be
-- silently rewritten; an expiry date has no such property.
-- =====================================================================================

CREATE TABLE IF NOT EXISTS control_plane.ctl_storage_credentials (
    -- One row per ROUTE, because storage is chosen by the address, exactly as the
    -- database is. Two addresses for one tenant can legitimately point at different
    -- storage.
    host            text PRIMARY KEY
                    REFERENCES control_plane.ctl_tenant_routes(host) ON DELETE CASCADE,
    tenant_id       text,
    storage_account text,
    -- 'managed-identity' | 'account-key' | 'sas'. What we authenticate with, never
    -- the credential: this table is read by the console and must stay worthless to
    -- anyone who gets hold of it.
    auth_kind       text,
    -- NULL for an account key, which does not expire, and for a token whose expiry
    -- could not be read -- which is itself a finding, carried in status.
    expires_at      timestamptz,
    -- 'healthy' | 'degraded' | 'unknown', as storage_health() reports them.
    status          text NOT NULL DEFAULT 'unknown',
    -- The sentence an operator reads. Written where the facts are, so the console
    -- does not have to reconstruct the reasoning from three columns.
    detail          text,
    checked_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE control_plane.ctl_storage_credentials IS
    'What each route''s storage authenticates with and when it stops working. Written '
    'by the platform, which can read the credential; read by the console, which cannot.';
COMMENT ON COLUMN control_plane.ctl_storage_credentials.expires_at IS
    'When the client''s token stops working. Read FROM the token, not recorded beside '
    'it -- the token is the only thing that cannot be wrong about its own expiry.';

-- Finding what needs attention is the only query anybody runs against this.
CREATE INDEX IF NOT EXISTS ix_ctl_storage_credentials_status
    ON control_plane.ctl_storage_credentials (status, expires_at);

-- --------------------------------------------------------------------- who may write
-- The app groups, which is what the reporter runs as. INSERT and UPDATE, because a
-- row is replaced rather than accumulated -- see the note on append-only above.
DO $$
DECLARE grp text;
BEGIN
    FOR grp IN
        SELECT rolname FROM pg_roles
         WHERE rolname ~ '^tvs_app_[a-z0-9_]+$' AND NOT rolcanlogin
    LOOP
        EXECUTE format('GRANT USAGE ON SCHEMA control_plane TO %I', grp);
        EXECUTE format(
            'GRANT SELECT, INSERT, UPDATE, DELETE ON '
            'control_plane.ctl_storage_credentials TO %I', grp);
        RAISE NOTICE 'storage credentials: write granted to %', grp;
    END LOOP;
END $$;

-- ---------------------------------------------------------------------- who may read
-- The console's login by name, the same way the billing ledger does it, and for the
-- same reason: a dedicated role cannot be created here because the migrator is not a
-- superuser. Migrations re-run every deploy, so the grant follows the console the day
-- it gets its own login.
DO $$
DECLARE r text;
BEGIN
    FOR r IN
        SELECT rolname FROM pg_roles
         WHERE rolcanlogin
           AND rolname ~ '^(coreplatform|deladetech)_[a-z0-9]+$'
    LOOP
        EXECUTE format('GRANT USAGE ON SCHEMA control_plane TO %I', r);
        EXECUTE format(
            'GRANT SELECT ON control_plane.ctl_storage_credentials TO %I', r);
    END LOOP;
END $$;

-- ------------------------------------------------------------------------------ checks
DO $$
DECLARE n integer;
BEGIN
    SELECT count(*) INTO n FROM information_schema.tables
     WHERE table_schema = 'control_plane'
       AND table_name = 'ctl_storage_credentials';
    IF n <> 1 THEN
        RAISE EXCEPTION 'ctl_storage_credentials was not created';
    END IF;

    -- The table must never be able to hold a credential. A column added later with a
    -- tempting name is exactly how one ends up here, in a table the console reads.
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'control_plane'
       AND table_name = 'ctl_storage_credentials'
       AND (column_name ~* 'secret|key|token|password|sas');
    IF n > 0 THEN
        RAISE EXCEPTION
            'ctl_storage_credentials has a column that looks like it holds a '
            'credential; this table is read by the console and must not';
    END IF;

    PERFORM count(*) FROM control_plane.ctl_storage_credentials;
    RAISE NOTICE 'a client credential now has a recorded expiry date';
END $$;
