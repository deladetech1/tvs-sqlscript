-- 20261109-71-coreplatform-company-sign-in-sso.sql
-- Company sign-in (single sign-on) for every TroveSuite app.
--
-- A customer points Core Platform at THEIR identity provider -- Microsoft Entra ID,
-- Google Workspace, Okta, Auth0, any OpenID Connect provider, or SAML 2.0 -- and their
-- people sign in there instead of typing a TroveSuite password. Core still issues the
-- session (same token, same cp_user_sessions row), so every app works unchanged and
-- revocation, tenant locks, lockdown, IP rules and sign-in schedules all still apply.
--
-- Everything here is keyed by tenant_id: identity in Core is per tenant (an email is
-- unique only within a tenant, see 20261005-09), so the SSO set-up is too. The same
-- email in two tenants signs into whichever tenant's address the person is at, never
-- the other.
--
-- Five tables:
--   cp_sso_connections  one identity provider (OIDC or SAML); the client secret is
--                       Fernet-encrypted by the API ("enc::" prefix), never plaintext.
--   cp_sso_domains      email domains the tenant has PROVEN it owns (DNS TXT). Only a
--                       verified domain routes anybody to an identity provider, and an
--                       asserted email must be in one of them to sign in.
--   cp_sso_policies     one row per tenant: optional / required, break-glass owners.
--   cp_sso_flows        one row per sign-in attempt (state, nonce, PKCE, SAML request
--                       id, browser binding). Single use, ten minutes. Holds HASHES of
--                       the state and binding, so a database read cannot finish a
--                       sign-in somebody else started.
--   cp_sso_identities   which IdP subject is which user, so a later change of email at
--                       the provider cannot move a session to a different person.
--   cp_sso_replay       SAML assertion ids already used, until they expire.
--
-- Plan: feature 'security.sso' at PREMIUM (rank 3). ENTERPRISE (rank 4) is the same
-- product self-hosted, not a bigger plan, so nothing is ever gated at 4.
--
-- Idempotent; safe to re-run on every deploy. Table grants come from the schema's
-- default privileges.

CREATE TABLE IF NOT EXISTS core_platform.cp_sso_connections (
    id                      text        PRIMARY KEY,
    tenant_id               text        NOT NULL,
    name                    text        NOT NULL CHECK (length(name) BETWEEN 1 AND 120),
    protocol                text        NOT NULL CHECK (protocol IN ('OIDC', 'SAML')),
    -- Only changes the defaults the screen fills in; the protocol decides behaviour.
    provider                text        NOT NULL DEFAULT 'GENERIC'
        CHECK (provider IN ('ENTRA', 'GOOGLE', 'OKTA', 'AUTH0', 'GENERIC')),
    is_enabled              boolean     NOT NULL DEFAULT false,

    -- OpenID Connect
    oidc_issuer             text,
    oidc_discovery_url      text,
    oidc_client_id          text,
    oidc_client_secret      text,       -- "enc::<fernet>" written by the API only
    oidc_scopes             text        NOT NULL DEFAULT 'openid email profile',
    -- Entra does not send email_verified; its issuer is pinned to the customer's own
    -- directory instead. Everybody else must say the address is verified.
    require_email_verified  boolean     NOT NULL DEFAULT true,

    -- SAML 2.0 (we are the service provider)
    saml_idp_entity_id      text,
    saml_idp_sso_url        text,
    saml_idp_certs          text[]      NOT NULL DEFAULT '{}',
    saml_idp_metadata_url   text,
    saml_allow_idp_initiated boolean    NOT NULL DEFAULT false,

    -- Which claim / attribute carries what. Empty = the protocol's usual names.
    claim_email             text        NOT NULL DEFAULT '',
    claim_name              text        NOT NULL DEFAULT '',
    claim_groups            text        NOT NULL DEFAULT '',
    -- amr / acr / AuthnContextClassRef values that mean "the IdP did MFA".
    mfa_values              text[]      NOT NULL DEFAULT '{}',
    trust_idp_mfa           boolean     NOT NULL DEFAULT true,

    -- Just-in-time provisioning
    jit_enabled             boolean     NOT NULL DEFAULT false,
    jit_group_ids           text[]      NOT NULL DEFAULT '{}',
    -- {"<idp group value>": ["grp-..", ...]}
    group_mapping           jsonb       NOT NULL DEFAULT '{}'::jsonb,
    group_sync              boolean     NOT NULL DEFAULT false,

    -- The tenant address the IdP was registered with (redirect URI / ACS host).
    sp_host                 text,

    created_by              text,
    cdatetime               timestamptz NOT NULL DEFAULT now(),
    updated_by              text,
    updated_at              timestamptz NOT NULL DEFAULT now(),
    delete_status           text        NOT NULL DEFAULT 'NOT_DELETED'
);
CREATE INDEX IF NOT EXISTS ix_cp_sso_connections_tenant
    ON core_platform.cp_sso_connections (tenant_id) WHERE delete_status = 'NOT_DELETED';

CREATE TABLE IF NOT EXISTS core_platform.cp_sso_domains (
    id                  text        PRIMARY KEY,
    tenant_id           text        NOT NULL,
    connection_id       text        REFERENCES core_platform.cp_sso_connections (id) ON DELETE SET NULL,
    domain              text        NOT NULL CHECK (domain = lower(domain) AND length(domain) BETWEEN 3 AND 253),
    verification_token  text        NOT NULL,
    status              text        NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'VERIFIED')),
    verified_at         timestamptz,
    last_checked_at     timestamptz,
    created_by          text,
    cdatetime           timestamptz NOT NULL DEFAULT now()
);
-- Once per tenant. NOT unique across tenants on purpose: two tenants of one company
-- may both prove the same domain (each with its own DNS record), and sign-in is
-- always scoped to the tenant the address names, so they never compete.
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_sso_domains_tenant_domain
    ON core_platform.cp_sso_domains (tenant_id, domain);
CREATE INDEX IF NOT EXISTS ix_cp_sso_domains_domain
    ON core_platform.cp_sso_domains (domain) WHERE status = 'VERIFIED';

CREATE TABLE IF NOT EXISTS core_platform.cp_sso_policies (
    tenant_id            text        PRIMARY KEY,
    enforcement          text        NOT NULL DEFAULT 'OPTIONAL'
        CHECK (enforcement IN ('OPTIONAL', 'REQUIRED_DOMAINS', 'REQUIRED_GROUPS', 'REQUIRED_ALL')),
    required_group_ids   text[]      NOT NULL DEFAULT '{}',
    -- Owners who may still use password + MFA when SSO is required. Always MFA.
    break_glass_user_ids text[]      NOT NULL DEFAULT '{}',
    updated_by           text,
    updated_at           timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS core_platform.cp_sso_flows (
    id               text        PRIMARY KEY,           -- sha256(state), hex
    tenant_id        text        NOT NULL,
    connection_id    text        NOT NULL,
    protocol         text        NOT NULL,
    binding_hash     text,                                -- sha256(browser binding)
    nonce            text,
    pkce_verifier    text,                                -- "enc::" like every secret
    redirect_uri     text,
    saml_request_id  text,
    host             text,
    next_path        text,
    login_hint       text,
    -- TEST: an administrator trying the connection; shows what the IdP asserted
    -- and signs nobody in. SIGN_IN: a real sign-in.
    purpose          text        NOT NULL DEFAULT 'SIGN_IN' CHECK (purpose IN ('SIGN_IN', 'TEST')),
    started_by       text,
    stage            text        NOT NULL DEFAULT 'STARTED'
        CHECK (stage IN ('STARTED', 'MFA_PENDING', 'DONE', 'FAILED')),
    user_id          text,
    mfa_method       text,
    otp_hash         text,
    attempts         integer     NOT NULL DEFAULT 0,
    created_at       timestamptz NOT NULL DEFAULT now(),
    expires_at       timestamptz NOT NULL,
    consumed_at      timestamptz
);
CREATE INDEX IF NOT EXISTS ix_cp_sso_flows_expires ON core_platform.cp_sso_flows (expires_at);

CREATE TABLE IF NOT EXISTS core_platform.cp_sso_identities (
    connection_id    text        NOT NULL,
    subject          text        NOT NULL,
    tenant_id        text        NOT NULL,
    user_id          text        NOT NULL,
    email_at_link    text,
    created_at       timestamptz NOT NULL DEFAULT now(),
    last_login_at    timestamptz,
    PRIMARY KEY (connection_id, subject),
    FOREIGN KEY (tenant_id, user_id) REFERENCES core_platform.cp_users (tenant_id, id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS ix_cp_sso_identities_user
    ON core_platform.cp_sso_identities (tenant_id, user_id);

CREATE TABLE IF NOT EXISTS core_platform.cp_sso_replay (
    connection_id    text        NOT NULL,
    assertion_id     text        NOT NULL,
    expires_at       timestamptz NOT NULL,
    PRIMARY KEY (connection_id, assertion_id)
);
CREATE INDEX IF NOT EXISTS ix_cp_sso_replay_expires ON core_platform.cp_sso_replay (expires_at);

-- The plan feature. Insert-only: re-tiering is an UPDATE somebody makes on purpose,
-- and a re-run must not undo it (migrations re-run every deploy).
INSERT INTO core_platform.cp_platform_feature_catalog
    (feature_key, title, min_tier_rank, description)
VALUES
    ('security.sso', 'Single sign-on (SSO)', 3,
     'Sign in with the company''s own identity provider (Entra ID, Google Workspace, Okta, Auth0, any OIDC or SAML 2.0), verified email domains, required SSO and just-in-time accounts.')
ON CONFLICT (feature_key) DO NOTHING;

-- Invariants, not counts (later migrations may add rows).
DO $$
BEGIN
    IF (SELECT min_tier_rank FROM core_platform.cp_platform_feature_catalog
         WHERE feature_key = 'security.sso') > 3 THEN
        RAISE EXCEPTION 'security.sso is gated above PREMIUM; ENTERPRISE is self-hosted, not a bigger plan';
    END IF;
END $$;
