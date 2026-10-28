-- Sign-in page designs: each tenant picks how its pre-sign-in pages look on its own address
-- (sign in, forgot / reset password, first-login password change, the code steps).
-- Core Platform -> Settings -> Sign-in page.
--
-- One row per tenant:
--   template_id  one of the templates Core Platform ships ('default' = the standard design);
--                validated by the API against its own list -- the check here only keeps the
--                column to a sane slug, so a new template needs no migration;
--   texts        {page: {headline, subheadline, tagline, footer, button}}, plain text, capped
--                by the API (80/200/240/160/30 characters);
--   colours      {primary, accent, bg1, bg2, panelText}, '#rrggbb' only.
--
-- READERS. The sign-in page reads it anonymously through Core Platform's
-- /landingpage/sign-in-design, with the tenant taken from the address (never the request), and
-- FAILS OPEN: before this file is deployed the table is missing and every address simply gets
-- the default design. Admins write it through /settings/sign-in-design (settings permission),
-- which logs every change to cp_activity_logs. No row = the default design; "reset" deletes it.
--
-- No grants: core_platform's default privileges already cover a new table for the app roles.
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS core_platform.cp_sign_in_designs (
    tenant_id    text PRIMARY KEY,
    template_id  text NOT NULL DEFAULT 'default',
    texts        jsonb NOT NULL DEFAULT '{}'::jsonb,
    colours      jsonb NOT NULL DEFAULT '{}'::jsonb,
    updated_by   text,
    updated_at   timestamptz NOT NULL DEFAULT now(),
    created_at   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_cp_sign_in_designs_template CHECK (template_id ~ '^[a-z0-9-]{1,40}$'),
    CONSTRAINT ck_cp_sign_in_designs_texts    CHECK (jsonb_typeof(texts) = 'object'),
    CONSTRAINT ck_cp_sign_in_designs_colours  CHECK (jsonb_typeof(colours) = 'object')
);

COMMENT ON TABLE core_platform.cp_sign_in_designs IS
    'Per tenant: the template, wording and colours of its pre-sign-in pages. No row = the default design. Read anonymously by Core Platform /landingpage/sign-in-design (tenant from the address, fails open); written by /settings/sign-in-design.';

COMMIT;
