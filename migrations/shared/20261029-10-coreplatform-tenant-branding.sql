-- Sidebar name: what Premium and Enterprise tenants show at the top of Core Platform's sidebar
-- in place of "TroveSuite" (the owner, 2026-10-28: "a text with only 10 characters with no
-- spaces"). Core Platform -> Settings -> General -> Sidebar name.
--
-- One row per tenant:
--   sidebar_label  1-10 characters, no whitespace. The API (Core Platform branding.py) is the
--                  real rule and refuses anything but letters (any language), digits and
--                  . - _ & ' -- the check here is the backstop for writes that skip it: the
--                  length, and no whitespace, control characters or < >. It is deliberately not
--                  the API's letter class: [[:alnum:]] on non-ASCII depends on the database's
--                  locale, and a check stricter than the API would turn a valid save into a 500.
--
-- READERS. Every signed-in member reads it through /settings/branding/get (tenant from the
-- token), because everybody's sidebar draws it; the saved name shows only while the tenant's
-- plan is Premium or Enterprise. Admins write it through /settings/branding (settings
-- permission), which logs every change to cp_activity_logs. No row = "TroveSuite"; "reset"
-- deletes it. Before this file is deployed the API answers "not available yet" and every
-- sidebar says TroveSuite.
--
-- No grants: core_platform's default privileges already cover a new table for the app roles.
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS core_platform.cp_tenant_branding (
    tenant_id      text PRIMARY KEY,
    sidebar_label  text NOT NULL,
    updated_by     text,
    updated_at     timestamptz NOT NULL DEFAULT now(),
    created_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_cp_tenant_branding_sidebar_label CHECK (
        char_length(sidebar_label) BETWEEN 1 AND 10
        AND sidebar_label !~ '[[:space:][:cntrl:]<>]'
    )
);

COMMENT ON TABLE core_platform.cp_tenant_branding IS
    'Per tenant: the name at the top of Core Platform''s sidebar in place of TroveSuite (Premium and Enterprise). No row = TroveSuite. Read by /settings/branding/get (tenant from the token); written by /settings/branding (settings permission, logged).';

COMMIT;
