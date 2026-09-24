-- Noticing something, and telling somebody.
--
-- The security dashboard records what happened. Nothing watches it, nothing
-- notices a sign-in from an address that has never been seen before, and
-- nothing tells anyone — an event lands in a table and waits to be found.
--
-- Three tables: what we have seen before, what is hammering the door right now,
-- and what the tenant wants done about either.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================
-- 1. What we have seen before.
-- =====================================================================
-- "New device" and "new location" both mean the same thing mechanically — a
-- value we have not seen for this person before — so they are one table with a
-- kind, rather than two tables that would need the same upsert written twice.
--
-- The alternative was deriving it from cp_login_audit_logs, which already holds
-- every IP and user-agent. Rejected: they live inside new_data jsonb, so asking
-- "has this person used this address before" means a scan with a jsonb
-- extraction per row, on the sign-in path, growing with the tenant's whole
-- history. This table answers it with one indexed lookup and stays small — one
-- row per person per distinct device or network, not one per sign-in.
CREATE TABLE IF NOT EXISTS core_platform.cp_sign_in_sources (
    id            text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text        NOT NULL,
    user_id       text        NOT NULL,

    -- DEVICE  — a user-agent we have seen this person sign in from.
    -- NETWORK — an IP address we have seen this person sign in from.
    kind          text        NOT NULL,

    -- The hash is what is matched on; the raw value is kept only so the screen
    -- can say "Chrome on Windows" or "197.251.x.x" rather than a hex string.
    -- Hashing is what keeps the unique index narrow — a user-agent string can
    -- run to 500 characters and several are near-identical.
    value_hash    text        NOT NULL,
    value         text,

    first_seen_at timestamptz NOT NULL DEFAULT now(),
    last_seen_at  timestamptz NOT NULL DEFAULT now(),
    sign_in_count integer     NOT NULL DEFAULT 1,

    -- Set when somebody confirms "yes, that was me". Does not affect detection
    -- — a known source is already not new — but it records that a human looked.
    is_trusted    boolean     NOT NULL DEFAULT false,
    trusted_at    timestamptz,

    cdatetime     timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT ck_cp_sign_in_sources_kind CHECK (kind IN ('DEVICE', 'NETWORK'))
);

-- The lookup the sign-in path makes, and the constraint the upsert conflicts on.
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_sign_in_sources_identity
    ON core_platform.cp_sign_in_sources (tenant_id, user_id, kind, value_hash);

-- "Everything this person signs in from", for the screen.
CREATE INDEX IF NOT EXISTS ix_cp_sign_in_sources_user
    ON core_platform.cp_sign_in_sources (tenant_id, user_id, last_seen_at DESC);


-- =====================================================================
-- 2. What is hammering the door.
-- =====================================================================
-- Account lockout counts failures per USER, which does nothing about somebody
-- trying one password against a thousand accounts: every account sees a single
-- failure and none of them lock. This counts per ADDRESS, which is the axis
-- that attack moves along.
--
-- In the database rather than in memory because the API runs as several
-- container replicas behind one ingress. An in-process counter would be
-- per-replica, so the real limit would be the configured one times however many
-- replicas happen to be running — a number nobody chose and nobody can see.
-- There is no Redis in this platform to put it in instead.
CREATE TABLE IF NOT EXISTS core_platform.cp_sign_in_attempts (
    id           bigserial   PRIMARY KEY,
    ip_address   text        NOT NULL,
    -- Null when the username matched nobody. Those attempts still count towards
    -- the per-address limit — an attacker guessing usernames is exactly the
    -- case this exists for — they simply cannot be attributed to a tenant.
    tenant_id    text,
    username     text,
    outcome      text        NOT NULL,
    attempted_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT ck_cp_sign_in_attempts_outcome
        CHECK (outcome IN ('SUCCESS', 'FAILURE', 'BLOCKED'))
);

-- The only query this table serves: how many failures from this address since
-- a given moment. Ordered DESC so the window scan stops early.
CREATE INDEX IF NOT EXISTS ix_cp_sign_in_attempts_ip_time
    ON core_platform.cp_sign_in_attempts (ip_address, attempted_at DESC);

-- For the sweep below.
CREATE INDEX IF NOT EXISTS ix_cp_sign_in_attempts_time
    ON core_platform.cp_sign_in_attempts (attempted_at);

-- This table has no retention story of its own and would otherwise grow by a
-- row per sign-in attempt for ever. It is not an audit trail — cp_login_audit_logs
-- is, and keeps the real record — this is a counter with a memory of minutes.
-- Anything older than a day is of no use to anybody.
CREATE OR REPLACE FUNCTION core_platform.cp_prune_sign_in_attempts()
RETURNS integer AS $$
DECLARE v_deleted integer;
BEGIN
    DELETE FROM core_platform.cp_sign_in_attempts
     WHERE attempted_at < now() - interval '1 day';
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;


-- =====================================================================
-- 3. What the tenant wants done about it.
-- =====================================================================
-- Absent row reads as the documented defaults, and writes upsert — the
-- cp_timezone_settings pattern, not the older seeded-at-signup one that 404s
-- for every tenant whose seed did not run.
CREATE TABLE IF NOT EXISTS core_platform.cp_threat_settings (
    id                        text        NOT NULL DEFAULT gen_random_uuid()::text,
    tenant_id                 text        NOT NULL,

    -- ---- Detection --------------------------------------------------
    detect_new_device         boolean     NOT NULL DEFAULT true,
    detect_new_location       boolean     NOT NULL DEFAULT true,

    -- ---- Rate limiting ----------------------------------------------
    -- Off by default. Switching it on for existing tenants unasked could start
    -- refusing sign-ins from an office that shares one outbound address, where
    -- twenty people behind one NAT look exactly like one attacker.
    rate_limit_enabled        boolean     NOT NULL DEFAULT false,
    rate_limit_max_attempts   integer     NOT NULL DEFAULT 20,
    rate_limit_window_minutes integer     NOT NULL DEFAULT 15,
    rate_limit_block_minutes  integer     NOT NULL DEFAULT 15,

    -- ---- Alerting ----------------------------------------------------
    alerts_enabled            boolean     NOT NULL DEFAULT true,
    -- Which severities are worth an email. CRITICAL only by default: an alert
    -- for everything is an alert for nothing, and the fastest way to teach
    -- somebody to ignore a channel is to fill it.
    alert_min_severity        text        NOT NULL DEFAULT 'CRITICAL',
    -- Empty means the tenant owner. Explicit addresses let a security mailbox
    -- receive them instead of one person who might be on leave.
    alert_emails              text[],
    -- SMS costs money per message, so it is opt-in and CRITICAL-only.
    alert_sms_enabled         boolean     NOT NULL DEFAULT false,
    alert_sms_recipients      text[],
    -- Tell the person themselves, not only the administrators, when something
    -- happens to their own account. They are the one who knows whether it was
    -- them.
    notify_user_on_new_device boolean     NOT NULL DEFAULT true,

    description               text,
    cdate                     text,
    ctime                     text,
    cdatetime                 timestamptz,
    created_by                text,
    updated_by                text,
    is_active                 boolean     NOT NULL DEFAULT true,

    CONSTRAINT pk_cp_threat_settings PRIMARY KEY (id, tenant_id),
    CONSTRAINT ck_cp_threat_settings_severity
        CHECK (alert_min_severity IN ('CRITICAL', 'WARNING', 'INFO')),
    -- A window of zero minutes counts nothing; a limit of zero attempts refuses
    -- everybody including the first person through the door.
    CONSTRAINT ck_cp_threat_settings_attempts
        CHECK (rate_limit_max_attempts >= 1),
    CONSTRAINT ck_cp_threat_settings_window
        CHECK (rate_limit_window_minutes >= 1),
    CONSTRAINT ck_cp_threat_settings_block
        CHECK (rate_limit_block_minutes >= 1),
    CONSTRAINT fk_cp_threat_settings_cp_tenants_tenant_id
        FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants (id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS ix_cp_threat_settings_tenant_id
    ON core_platform.cp_threat_settings (tenant_id);


-- =====================================================================
-- 4. Its audit trail.
-- =====================================================================
CREATE TABLE IF NOT EXISTS core_platform.cp_threat_settings_audit_logs (
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

CREATE INDEX IF NOT EXISTS idx_cp_threat_settings_audit_logs_scope
    ON core_platform.cp_threat_settings_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_threat_settings_audit_logs_action
    ON core_platform.cp_threat_settings_audit_logs (tenant_id, action);
