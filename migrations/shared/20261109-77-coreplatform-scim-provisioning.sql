-- 20261109-77-coreplatform-scim-provisioning.sql
-- SCIM 2.0 provisioning for company sign-in (SSO part 2), plus the SSO follow-ups.
-- Builds on 20261109-71 (the cp_sso_* tables).
--
-- A customer's identity provider (Entra ID, Okta, OneLogin, ...) creates, updates and
-- deactivates the organisation's people and groups in Core Platform by calling
-- https://<tenant address>/scim/v2 with a per-organisation bearer token. The tenant's
-- own address is what lets the tenancy gate pick the right database (silo or pool).
--
--   cp_scim_tokens      bearer tokens, stored ONLY as SHA-256; shown once, rotated, revoked.
--   cp_scim_settings    one row per tenant: groups new people join.
--   cp_scim_groups      the Core groups SCIM may manage. Anything not listed here is
--                       invisible to SCIM, so an identity provider cannot take over an
--                       administrators' group. allow_privileged is the administrator's
--                       explicit "yes, this group may carry admin roles".
--   cp_scim_users       SCIM's view of a person: userName, externalId, name parts, and
--                       whether SCIM deactivated / deprovisioned them. Keyed by the Core
--                       user, per tenant (an email is unique only within a tenant).
--   cp_sso_audit_logs   sign-ins through the company account and SCIM calls (success,
--                       failure, reason). Named *_audit_logs with tenant_id + cdatetime,
--                       so activity-log retention purges it by convention (20260731-01).
--
-- Also:
--   cp_sso_domains      missing_since / last_check_error: the periodic re-check of the DNS
--                       TXT record; admins are warned when it disappears.
--   cp_sso_flows        purpose STEP_UP (re-authenticate at the IdP instead of a password),
--                       with the session it proves and the scope it is for.
--
-- Plan: feature 'security.scim' at PREMIUM (rank 3), the same tier as 'security.sso'.
--
-- Idempotent; safe to re-run on every deploy. Table grants come from the schema's
-- default privileges.

CREATE TABLE IF NOT EXISTS core_platform.cp_scim_tokens (
    id              text        PRIMARY KEY,
    tenant_id       text        NOT NULL,
    token_hash      text        NOT NULL,              -- sha256(token), hex
    hint            text        NOT NULL DEFAULT '',   -- last four characters, for the screen
    created_by      text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    last_used_at    timestamptz,
    revoked_at      timestamptz,
    revoked_by      text
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_scim_tokens_hash ON core_platform.cp_scim_tokens (token_hash);
CREATE INDEX IF NOT EXISTS ix_cp_scim_tokens_tenant ON core_platform.cp_scim_tokens (tenant_id);

CREATE TABLE IF NOT EXISTS core_platform.cp_scim_settings (
    tenant_id          text        PRIMARY KEY,
    default_group_ids  text[]      NOT NULL DEFAULT '{}',
    updated_by         text,
    updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS core_platform.cp_scim_groups (
    tenant_id         text        NOT NULL,
    group_id          text        NOT NULL,
    external_id       text,
    -- SCIM: the identity provider created this group. ADMIN: an administrator let SCIM
    -- manage an existing group.
    origin            text        NOT NULL DEFAULT 'ADMIN' CHECK (origin IN ('SCIM', 'ADMIN')),
    allow_privileged  boolean     NOT NULL DEFAULT false,
    created_by        text,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, group_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_scim_groups_external
    ON core_platform.cp_scim_groups (tenant_id, external_id) WHERE external_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS core_platform.cp_scim_users (
    tenant_id            text        NOT NULL,
    user_id              text        NOT NULL,
    user_name            text        NOT NULL CHECK (length(user_name) BETWEEN 1 AND 320),
    external_id          text,
    given_name           text        NOT NULL DEFAULT '',
    family_name          text        NOT NULL DEFAULT '',
    display_name         text        NOT NULL DEFAULT '',
    created_via_scim     boolean     NOT NULL DEFAULT false,
    deactivated_by_scim  boolean     NOT NULL DEFAULT false,
    -- DELETE /Users/{id}: the person is deactivated (never hard-deleted) and SCIM no
    -- longer sees them. A later POST with the same externalId revives the account.
    deprovisioned_at     timestamptz,
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, user_id),
    FOREIGN KEY (tenant_id, user_id) REFERENCES core_platform.cp_users (tenant_id, id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_scim_users_user_name
    ON core_platform.cp_scim_users (tenant_id, lower(user_name));
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_scim_users_external
    ON core_platform.cp_scim_users (tenant_id, external_id) WHERE external_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS core_platform.cp_sso_audit_logs (
    id               text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text        NOT NULL,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    kind             text        NOT NULL CHECK (kind IN ('SIGN_IN', 'STEP_UP', 'SCIM', 'DOMAIN')),
    outcome          text        NOT NULL CHECK (outcome IN ('SUCCESS', 'FAILURE', 'WARNING', 'INFO')),
    connection_id    text,
    connection_name  text,
    provider         text,
    protocol         text,
    operation        text,          -- e.g. 'POST /Users', 'sign-in', 'domain re-check'
    user_id          text,
    email            text,
    reason           text,
    ip_address       text,
    detail           jsonb        NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS ix_cp_sso_audit_logs_tenant_time
    ON core_platform.cp_sso_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS ix_cp_sso_audit_logs_tenant_kind
    ON core_platform.cp_sso_audit_logs (tenant_id, kind, cdatetime DESC);

-- Periodic DNS re-check of verified domains.
ALTER TABLE core_platform.cp_sso_domains ADD COLUMN IF NOT EXISTS missing_since timestamptz;
ALTER TABLE core_platform.cp_sso_domains ADD COLUMN IF NOT EXISTS last_check_error text;
CREATE INDEX IF NOT EXISTS ix_cp_sso_domains_recheck
    ON core_platform.cp_sso_domains (last_checked_at) WHERE status = 'VERIFIED';

-- Step-up through the identity provider.
ALTER TABLE core_platform.cp_sso_flows ADD COLUMN IF NOT EXISTS session_jti text;
ALTER TABLE core_platform.cp_sso_flows ADD COLUMN IF NOT EXISTS step_up_scope text;
ALTER TABLE core_platform.cp_sso_flows DROP CONSTRAINT IF EXISTS cp_sso_flows_purpose_check;
ALTER TABLE core_platform.cp_sso_flows ADD CONSTRAINT cp_sso_flows_purpose_check
    CHECK (purpose IN ('SIGN_IN', 'TEST', 'STEP_UP'));
ALTER TABLE core_platform.cp_sso_flows DROP CONSTRAINT IF EXISTS cp_sso_flows_step_up_check;
ALTER TABLE core_platform.cp_sso_flows ADD CONSTRAINT cp_sso_flows_step_up_check
    CHECK (purpose <> 'STEP_UP' OR (session_jti IS NOT NULL AND step_up_scope IS NOT NULL AND started_by IS NOT NULL));

-- The plan feature. Insert-only (migrations re-run every deploy).
INSERT INTO core_platform.cp_platform_feature_catalog
    (feature_key, title, min_tier_rank, description)
VALUES
    ('security.scim', 'User provisioning (SCIM)', 3,
     'Your identity provider (Entra ID, Okta, OneLogin and others) creates, updates and deactivates your people and groups automatically over SCIM 2.0.')
ON CONFLICT (feature_key) DO NOTHING;

-- Invariants, not counts.
DO $$
BEGIN
    IF (SELECT min_tier_rank FROM core_platform.cp_platform_feature_catalog
         WHERE feature_key = 'security.scim') > 3 THEN
        RAISE EXCEPTION 'security.scim is gated above PREMIUM; ENTERPRISE is self-hosted, not a bigger plan';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_scim_tokens WHERE length(token_hash) <> 64) THEN
        RAISE EXCEPTION 'cp_scim_tokens.token_hash must be a sha256 hex digest, never a token';
    END IF;
END $$;
