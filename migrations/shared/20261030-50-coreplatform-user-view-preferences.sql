-- 20261030-50-coreplatform-user-view-preferences.sql
-- Each person's layout choices in each app (table or grid, a zoom, a remembered tab), so they
-- follow the person across browsers and sign-ins.
--
-- The owner (2026-10-30): "I want these switches we've been doing to be persisted in a
-- database, so when I log in again it uses those settings."
--
-- One row per (tenant, person, app, key), overwritten on each change. Read and written only
-- through Core's GET/PUT /api/v1/view-preferences, keyed by the tenant and user in the token
-- (tvs-coreplatform-bk app/src/entities/view_preferences). A value is a short string such as
-- 'table' or 'month' -- a layout, never data. The theme stays in cp_themes.
-- Kept out of the EF model like cp_user_last_places. Idempotent; safe to re-run on every
-- deploy (table grants come from the schema's default privileges).

CREATE TABLE IF NOT EXISTS core_platform.cp_user_view_preferences (
    tenant_id   text        NOT NULL,
    user_id     text        NOT NULL,
    app_id      text        NOT NULL CHECK (length(app_id) BETWEEN 1 AND 64),
    pref_key    text        NOT NULL CHECK (pref_key ~ '^[A-Za-z0-9_.:-]{1,100}$'),
    pref_value  text        NOT NULL CHECK (length(pref_value) BETWEEN 1 AND 200),
    updated_at  timestamptz NOT NULL DEFAULT now(),

    PRIMARY KEY (tenant_id, user_id, app_id, pref_key),

    FOREIGN KEY (tenant_id, user_id) REFERENCES core_platform.cp_users (tenant_id, id) ON DELETE CASCADE
);
