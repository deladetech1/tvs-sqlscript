-- Where a sign-in may come from, and proving it is really you.
--
-- Three things that all answer the same question from different angles: is the
-- person at the other end of this request the person the account belongs to?
--
--   1. cp_ip_rules       — sign-ins from addresses you did not expect.
--   2. cp_step_up_grants — a recent password, before an action that cannot be
--                          undone, on a session that might be somebody else's.
--   3. one column on cp_password_policies, for passwords already in a breach.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================
-- 1. Which addresses may sign in.
-- =====================================================================
-- Stored as PostgreSQL's own `cidr` type, not as text.
--
-- Text would mean writing the matching by hand: splitting on '/', converting
-- to integers, masking, and getting IPv6 wrong. `cidr` gives `>>=` — "does
-- this network contain that address" — which is one indexed operator that
-- already handles both families, already rejects 10.0.0.300 at write time, and
-- already normalises 10.0.0.5/24 to 10.0.0.0/24 rather than storing a network
-- with host bits set that would then never match anything.
CREATE TABLE IF NOT EXISTS core_platform.cp_ip_rules (
    id          text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text        NOT NULL,

    -- ALLOW: when any enabled ALLOW rule exists, ONLY addresses inside one may
    --        sign in. The list becomes the whole permitted world.
    -- BLOCK: this range may not sign in, whatever else says otherwise.
    action      text        NOT NULL,

    network     cidr        NOT NULL,
    -- "Head office", "Kwame's home". Without it, a list of ranges becomes
    -- unmaintainable within a month: nobody dares delete a rule they cannot
    -- identify, so the list only ever grows.
    label       text,

    is_enabled  boolean     NOT NULL DEFAULT true,

    description text,
    cdate       text,
    ctime       text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_by  text,

    CONSTRAINT ck_cp_ip_rules_action CHECK (action IN ('ALLOW', 'BLOCK')),
    CONSTRAINT fk_cp_ip_rules_cp_tenants_tenant_id
        FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants (id) ON DELETE CASCADE
);

-- The read on the sign-in path: every enabled rule for one tenant. Small by
-- nature — a tenant with a thousand ranges has a different problem — so the
-- match itself is done in Python against the fetched set rather than with a
-- gist index that would never be reached at this size.
CREATE INDEX IF NOT EXISTS ix_cp_ip_rules_tenant
    ON core_platform.cp_ip_rules (tenant_id, is_enabled);

-- The same range twice, once allowing and once blocking, is a rule set whose
-- behaviour depends on which row is read first. Refused outright.
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_ip_rules_tenant_network
    ON core_platform.cp_ip_rules (tenant_id, network);

CREATE TABLE IF NOT EXISTS core_platform.cp_ip_rules_audit_logs (
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

CREATE INDEX IF NOT EXISTS idx_cp_ip_rules_audit_logs_scope
    ON core_platform.cp_ip_rules_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_ip_rules_audit_logs_action
    ON core_platform.cp_ip_rules_audit_logs (tenant_id, action);


-- =====================================================================
-- 2. Proving it is still you.
-- =====================================================================
-- A token says somebody signed in as this account, once, possibly this morning
-- on a laptop now sitting unattended in a café. Before an action that cannot be
-- undone — locking the whole organisation out, changing who may sign in from
-- where — that is not enough. Step-up asks for the password again and issues a
-- grant that lasts minutes.
--
-- A table rather than a claim in a second token: a grant that can be cancelled
-- when the session is revoked is worth more than one that is merely short, and
-- this way "end all sessions" ends the step-ups with them.
CREATE TABLE IF NOT EXISTS core_platform.cp_step_up_grants (
    id         text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id  text        NOT NULL,
    user_id    text        NOT NULL,

    -- The session this grant belongs to. Proving yourself on your laptop must
    -- not authorise an action from a different browser holding a different
    -- token for the same account.
    session_jti text       NOT NULL,

    granted_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL,
    -- What it was proved for, so a grant taken to change an IP rule cannot be
    -- silently reused to lock the organisation down.
    scope      text        NOT NULL,

    ip_address text,
    used_at    timestamptz,

    CONSTRAINT fk_cp_step_up_grants_cp_tenants_tenant_id
        FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants (id) ON DELETE CASCADE
);

-- The lookup: "is there a live grant for this session and this scope".
CREATE INDEX IF NOT EXISTS ix_cp_step_up_grants_lookup
    ON core_platform.cp_step_up_grants (session_jti, scope, expires_at DESC);

CREATE INDEX IF NOT EXISTS ix_cp_step_up_grants_expiry
    ON core_platform.cp_step_up_grants (expires_at);

-- Grants live for minutes and are of no interest an hour later. Same reasoning
-- as cp_sign_in_attempts: this is operational state, and the record of what was
-- done with a grant is on the action's own audit trail, not here.
CREATE OR REPLACE FUNCTION core_platform.cp_prune_step_up_grants()
RETURNS integer AS $$
DECLARE v_deleted integer;
BEGIN
    DELETE FROM core_platform.cp_step_up_grants
     WHERE expires_at < now() - interval '1 day';
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;


-- =====================================================================
-- 3. Passwords that are already known.
-- =====================================================================
DO $$
BEGIN
    -- Off by default, like every other switch here that can refuse somebody.
    -- Turning it on for existing tenants unasked would mean the next person to
    -- change their password meets a refusal nobody warned them about, from a
    -- check that was not there yesterday.
    --
    -- It is a single column rather than a table because there is exactly one
    -- question — on or off. There is no per-tenant threshold worth exposing:
    -- a password that appears in a breach corpus at all is a password an
    -- attacker's list already contains.
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'core_platform'
           AND table_name = 'cp_password_policies'
           AND column_name = 'check_breached_passwords'
    ) THEN
        ALTER TABLE core_platform.cp_password_policies
            ADD COLUMN check_breached_passwords boolean NOT NULL DEFAULT false;
    END IF;

    -- Step-up is a tenant choice too: how long a proof lasts, and whether the
    -- owner has to give one. Kept on cp_session_settings, which already answers
    -- "how does this tenant's sessions behave" — and a step-up grant is a
    -- property of a session.
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'core_platform'
           AND table_name = 'cp_session_settings'
           AND column_name = 'step_up_enabled'
    ) THEN
        ALTER TABLE core_platform.cp_session_settings
            ADD COLUMN step_up_enabled        boolean NOT NULL DEFAULT false,
            ADD COLUMN step_up_valid_minutes  integer NOT NULL DEFAULT 10;
        ALTER TABLE core_platform.cp_session_settings
            ADD CONSTRAINT ck_cp_session_settings_step_up_minutes
                CHECK (step_up_valid_minutes BETWEEN 1 AND 120);
    END IF;
END $$;
