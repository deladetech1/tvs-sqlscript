-- Require a password when opening an app (the owner, 2026-10-29: "if enabled and I login to
-- coreplatform, when opening an app I should provide my password. Is either all apps or only
-- apps I select"). Core Platform -> Security -> Require password to open apps.
--
--   1. cp_app_open_password_settings   one row per tenant: the rule.
--        mode           OFF | ALL_APPS | SELECTED_APPS
--        app_ids        the apps that ask, when mode = SELECTED_APPS (cp_apps.id, e.g. app-crm);
--                       kept when the mode changes so switching back restores the selection
--        grace_minutes  0 = every time, else 5 / 15 / 30 / 60: no second prompt for that long
--   2. cp_app_open_password_settings_audit_logs   every change (the shape of every other
--        settings audit table: tenant_id + cdatetime, so the retention purge finds it).
--   3. cp_app_unlock_grants   the proof a person gets back after confirming their password or
--        passkey. The API hands out a SIGNED token naming one of these rows; the row is what
--        makes it single-use (grace 0), cancellable, and tied to the session that earned it.
--
-- READERS. Every signed-in person asks /app-open-password/required (tenant + user from the
-- token) before the hub opens an app; admins read and write the rule through
-- /app-open-password/settings (security or settings permission). Before this file is deployed
-- the API answers "OFF" and nothing asks.
--
-- No grants: core_platform's default privileges already cover a new table for the app roles.
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS core_platform.cp_app_open_password_settings (
    id             text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text        NOT NULL,
    mode           text        NOT NULL DEFAULT 'OFF',
    app_ids        text[]      NOT NULL DEFAULT '{}'::text[],
    grace_minutes  integer     NOT NULL DEFAULT 0,
    updated_by     text,
    updated_at     timestamptz NOT NULL DEFAULT now(),
    created_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ux_cp_app_open_password_settings_tenant UNIQUE (tenant_id),
    CONSTRAINT ck_cp_app_open_password_settings_mode
        CHECK (mode IN ('OFF', 'ALL_APPS', 'SELECTED_APPS')),
    CONSTRAINT ck_cp_app_open_password_settings_grace
        CHECK (grace_minutes IN (0, 5, 15, 30, 60))
);

COMMENT ON TABLE core_platform.cp_app_open_password_settings IS
    'Per tenant: whether opening an app from Core Platform asks for the password again (OFF | ALL_APPS | SELECTED_APPS), which apps, and for how many minutes a confirmation lasts (0 = every time). No row = OFF.';


CREATE TABLE IF NOT EXISTS core_platform.cp_app_open_password_settings_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,
    bus_id                 text,

    entity_id              text        NOT NULL,               -- settings row id
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

CREATE INDEX IF NOT EXISTS idx_cp_app_open_password_audit_logs_scope
    ON core_platform.cp_app_open_password_settings_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_app_open_password_audit_logs_entity
    ON core_platform.cp_app_open_password_settings_audit_logs (tenant_id, entity_id, cdatetime DESC);


CREATE TABLE IF NOT EXISTS core_platform.cp_app_unlock_grants (
    id           text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text        NOT NULL,
    user_id      text        NOT NULL,
    -- The session that earned it: a proof from one browser opens nothing in another.
    session_jti  text,
    -- One app (cp_apps.id), or '*' when the tenant asks for every app.
    app_id       text        NOT NULL,
    -- Grace 0 ("every time"): spent by its first use.
    single_use   boolean     NOT NULL DEFAULT false,
    method       text        NOT NULL DEFAULT 'PASSWORD',
    expires_at   timestamptz NOT NULL,
    used_at      timestamptz,
    ip_address   text,
    created_at   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_cp_app_unlock_grants_method CHECK (method IN ('PASSWORD', 'PASSKEY'))
);

CREATE INDEX IF NOT EXISTS idx_cp_app_unlock_grants_user
    ON core_platform.cp_app_unlock_grants (tenant_id, user_id, expires_at DESC);
CREATE INDEX IF NOT EXISTS idx_cp_app_unlock_grants_session
    ON core_platform.cp_app_unlock_grants (session_jti);

COMMENT ON TABLE core_platform.cp_app_unlock_grants IS
    'Short-lived proofs that a signed-in person re-entered their password (or used their passkey) to open an app. Named by a signed token the API returns; single_use when the tenant asks every time. Expired rows are deleted by the API as it writes new ones.';

COMMIT;
