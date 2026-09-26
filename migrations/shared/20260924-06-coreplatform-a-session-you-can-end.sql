-- A session you can end.
--
-- Today a token is valid until it expires — up to twenty-four hours — and
-- nothing can stop it. A laptop left on a train, a password shared and
-- regretted, a contractor who finished on Friday: in every case the only
-- honest answer is "wait a day". There is no session table, no jti, no refresh
-- token, and "sign out all devices" cannot be built without one.
--
-- This is the table. Enforcement lives in the shared package, because the same
-- token is accepted by MyStoreGuard and LoanDrift and a revocation that only
-- Core Platform honoured would be worse than none — it would read as done.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================
-- 1. One row per signed-in session.
-- =====================================================================
CREATE TABLE IF NOT EXISTS core_platform.cp_user_sessions (
    id             text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text        NOT NULL,
    user_id        text        NOT NULL,

    -- The JWT's own id claim. This is the join between a token somebody is
    -- holding and the row that says whether it still counts. Unique because
    -- two sessions sharing one jti would make revoking either revoke both.
    jti            text        NOT NULL,

    ip_address     text,
    user_agent     text,
    -- "Chrome on Windows". Derived at sign-in and stored, rather than parsed
    -- on every read of the screen, because the parsing rules change and a
    -- session should keep describing itself the way it did when it started.
    device_label   text,

    created_at     timestamptz NOT NULL DEFAULT now(),
    -- Touched at most once every few minutes rather than on every request.
    -- A write per authenticated request would cost more than the whole check.
    last_seen_at   timestamptz NOT NULL DEFAULT now(),
    -- Mirrors the token's exp, so the screen can say when a session dies on
    -- its own and the sweep below knows what is safe to delete.
    expires_at     timestamptz NOT NULL,

    revoked_at     timestamptz,
    revoked_by     text,
    -- Free text, but in practice one of: 'logout', 'admin', 'all-devices',
    -- 'lockdown', 'concurrent-limit', 'password-change'.
    revoke_reason  text,

    cdate          text,
    ctime          text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT fk_cp_user_sessions_cp_tenants_tenant_id
        FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants (id) ON DELETE CASCADE
);

-- The lookup on the authentication path, made by every app through the shared
-- package. Unique so the jti is genuinely a key; this is the index that has to
-- be fast, because it is consulted once per authenticated request.
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_user_sessions_jti
    ON core_platform.cp_user_sessions (jti);

-- "Everything this person has open", for the screen and for revoke-all.
CREATE INDEX IF NOT EXISTS ix_cp_user_sessions_user
    ON core_platform.cp_user_sessions (tenant_id, user_id, revoked_at, last_seen_at DESC);

-- "Everything open in this tenant", for lockdown and the admin list. Partial,
-- because a revoked or expired session is never what either one is looking
-- for and the live set stays small even when the table does not.
CREATE INDEX IF NOT EXISTS ix_cp_user_sessions_live
    ON core_platform.cp_user_sessions (tenant_id, last_seen_at DESC)
    WHERE revoked_at IS NULL;

-- For the sweep below.
CREATE INDEX IF NOT EXISTS ix_cp_user_sessions_expires
    ON core_platform.cp_user_sessions (expires_at);


-- A session that expired on its own is of no interest to anybody after a
-- while: the token it described stopped working when it expired, whatever this
-- row says. Kept for a week so the sessions screen can still show "signed out
-- yesterday", then removed — this table grows by a row per sign-in, and
-- without this it would grow for ever.
--
-- Revoked rows are pruned on the same clock, deliberately. The audit trail of
-- WHO revoked WHAT lives in cp_activity_logs and cp_security_events, which have
-- their own retention; this table is operational state, not the record.
CREATE OR REPLACE FUNCTION core_platform.cp_prune_expired_sessions()
RETURNS integer AS $$
DECLARE v_deleted integer;
BEGIN
    DELETE FROM core_platform.cp_user_sessions
     WHERE expires_at < now() - interval '7 days'
        OR (revoked_at IS NOT NULL AND revoked_at < now() - interval '7 days');
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;


-- =====================================================================
-- 2. How many at once, and whether anybody may sign in at all.
-- =====================================================================
-- Both belong on cp_session_settings rather than in a table of their own: they
-- are answers to "how does this tenant's sessions behave", which is the
-- question that table already answers, and a second table would mean a second
-- upsert and a second screen for two columns.
DO $$
BEGIN
    -- 0 means no limit. A limit of 1 is a real choice — a shared account that
    -- must only ever be in one place — so the "off" value cannot be 1, and a
    -- nullable column would need every reader to handle NULL as well as 0.
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'core_platform'
           AND table_name = 'cp_session_settings'
           AND column_name = 'max_concurrent_sessions'
    ) THEN
        ALTER TABLE core_platform.cp_session_settings
            ADD COLUMN max_concurrent_sessions integer NOT NULL DEFAULT 0;
        ALTER TABLE core_platform.cp_session_settings
            ADD CONSTRAINT ck_cp_session_settings_max_sessions
                CHECK (max_concurrent_sessions >= 0);
    END IF;

    -- Lockdown. Two separate things on purpose: ending every session and
    -- refusing new ones. Ending sessions without refusing new ones lets an
    -- attacker who still has the password sign straight back in; refusing new
    -- ones without ending sessions leaves them exactly where they are.
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'core_platform'
           AND table_name = 'cp_session_settings'
           AND column_name = 'sign_in_blocked'
    ) THEN
        ALTER TABLE core_platform.cp_session_settings
            ADD COLUMN sign_in_blocked        boolean NOT NULL DEFAULT false,
            ADD COLUMN sign_in_blocked_at     timestamptz,
            ADD COLUMN sign_in_blocked_by     text,
            ADD COLUMN sign_in_block_reason   text;
    END IF;
END $$;


-- =====================================================================
-- 3. Its audit trail.
-- =====================================================================
-- Revoking somebody's session is an administrative act performed on another
-- person's account, which is exactly the class of thing that has to be
-- answerable afterwards. Discovered by the retention sweep on the _audit_logs
-- suffix, and conforming: tenant_id and cdatetime are both present.
CREATE TABLE IF NOT EXISTS core_platform.cp_user_sessions_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,
    bus_id                 text,
    entity_id              text        NOT NULL,
    entity_name            text,
    action                 text        NOT NULL,
    old_data               jsonb,
    new_data               jsonb,
    description            text,
    performed_by           text,
    performed_by_fullname  text,
    performed_by_email     text,
    performed_by_contact   text,
    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cp_user_sessions_audit_logs_scope
    ON core_platform.cp_user_sessions_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_user_sessions_audit_logs_action
    ON core_platform.cp_user_sessions_audit_logs (tenant_id, action);


-- =====================================================================
-- 4. What it costs to have it.
-- =====================================================================
-- Sessions are ADVANCE and above (rank 2), already seeded in
-- cp_platform_feature_catalog as 'security.sessions'. Lockdown is the one
-- capability here that is not sold separately: a tenant in trouble at 2am must
-- not meet an upgrade prompt. It is gated on the security permission alone.
--
-- Nothing to insert — this block exists so the next person looking for the
-- tiering of this feature finds the answer here rather than concluding it was
-- forgotten.
