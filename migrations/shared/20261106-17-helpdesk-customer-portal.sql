-- Help Desk R4: the customer portal, with its own sign-in for people who are not hub users.
--
--   hd_portal_settings       one row per business: on or off, the public portal_key, branding,
--                            whether unknown people may sign up
--   hd_customer_login_links  single-use email magic links (15 minutes)
--   hd_customer_sessions     opaque session tokens (12 hours), revocable, never a hub JWT
--
-- Tokens are never stored: only their sha256 hash, unique everywhere, because the portal looks a
-- token up before it knows the business (as MFG device keys). portal_key is public addressing like
-- a status page's public_key, unique everywhere.
-- Provisional (owner decision D4, R4.md): a later SSO may replace the magic links.
-- CHECK lists are defined here, inline. No grants.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R4.md §3, §6. Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS helpdesk.hd_portal_settings (
    tenant_id                text NOT NULL,
    bus_id                   text NOT NULL,
    customer_portal_enabled  boolean NOT NULL DEFAULT false,
    portal_key               text CONSTRAINT hd_portal_settings_portal_key_check CHECK (length(portal_key) >= 32 AND portal_key ~ '^[A-Za-z0-9_-]+$'),
    brand_name               text,
    brand_color              text,
    logo_attachment_id       text REFERENCES helpdesk.hd_attachments (id),
    welcome                  text,
    allow_signup             boolean NOT NULL DEFAULT false,
    cdatetime                timestamptz NOT NULL DEFAULT now(),
    created_by               text,
    updated_at               timestamptz,
    updated_by               text,
    PRIMARY KEY (tenant_id, bus_id),
    -- An enabled portal is reached only through its key.
    CONSTRAINT hd_portal_settings_enabled_needs_key CHECK (NOT customer_portal_enabled OR portal_key IS NOT NULL)
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_portal_settings_portal_key_uq
    ON helpdesk.hd_portal_settings (portal_key) WHERE portal_key IS NOT NULL;

CREATE TABLE IF NOT EXISTS helpdesk.hd_customer_login_links (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    contact_id  text NOT NULL REFERENCES helpdesk.hd_contacts (id),
    token_hash  text NOT NULL,
    expires_at  timestamptz NOT NULL,
    used_at     timestamptz,
    ip          text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_customer_login_links_token_uq ON helpdesk.hd_customer_login_links (token_hash);
CREATE INDEX IF NOT EXISTS hd_customer_login_links_contact_idx ON helpdesk.hd_customer_login_links (contact_id, cdatetime DESC);

CREATE TABLE IF NOT EXISTS helpdesk.hd_customer_sessions (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    contact_id    text NOT NULL REFERENCES helpdesk.hd_contacts (id),
    token_hash    text NOT NULL,
    expires_at    timestamptz NOT NULL,
    revoked_at    timestamptz,
    last_seen_at  timestamptz,
    user_agent    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text,
    updated_at    timestamptz,
    updated_by    text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_customer_sessions_token_uq ON helpdesk.hd_customer_sessions (token_hash);
CREATE INDEX IF NOT EXISTS hd_customer_sessions_contact_idx ON helpdesk.hd_customer_sessions (contact_id) WHERE revoked_at IS NULL;

-- ===================================================================== invariants
DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['hd_portal_settings_portal_key_uq', 'hd_customer_login_links_token_uq', 'hd_customer_sessions_token_uq'] LOOP
        IF to_regclass('helpdesk.' || t) IS NULL THEN
            RAISE EXCEPTION 'helpdesk.% is missing: a public key or token hash must be unique', t;
        END IF;
    END LOOP;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_customer_login_links l JOIN helpdesk.hd_contacts c ON c.id = l.contact_id
                WHERE c.tenant_id <> l.tenant_id OR c.bus_id <> l.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk login link belongs to a contact of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_customer_sessions s JOIN helpdesk.hd_contacts c ON c.id = s.contact_id
                WHERE c.tenant_id <> s.tenant_id OR c.bus_id <> s.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk customer session belongs to a contact of another business';
    END IF;
END $$;

COMMIT;
