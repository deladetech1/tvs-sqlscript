-- 20261028-90-coreplatform-user-last-place.sql
-- Where each person last was in TroveSuite, so signing in again brings them back there.
--
-- The owner (2026-10-28): "when I open let say mystoreguard and close the browser and login
-- again, it should take me to mystoreguard instead of coreplatform ... it should always bring
-- me back to where I signed off from the system".
--
-- One row per person (tenant_id, user_id), overwritten as they move:
--   * place_kind 'APP': an app was opened (launcher Open, /switch, Manage app) or an app
--     reported its page -- app_id + bus_id + loc_id + the path inside that app.
--   * place_kind 'HUB': they came back to a Core Platform page -- path is that hub page.
--
-- It holds no secret, only an address. Nothing here grants anything: after sign-in the hub
-- re-checks that the person may still use that app at that location before going there.
-- Kept out of the EF model like cp_sidebar_preferences. Idempotent; safe to re-run on every
-- deploy (table grants come from the schema's default privileges).

CREATE TABLE IF NOT EXISTS core_platform.cp_user_last_places (
    tenant_id   text        NOT NULL,
    user_id     text        NOT NULL,
    place_kind  text        NOT NULL CHECK (place_kind IN ('APP', 'HUB')),
    app_id      text        CHECK (app_id IS NULL OR length(app_id) <= 64),
    bus_id      text        CHECK (bus_id IS NULL OR length(bus_id) <= 128),
    loc_id      text        CHECK (loc_id IS NULL OR length(loc_id) <= 128),
    path        text        NOT NULL DEFAULT '/'
        CHECK (left(path, 1) = '/' AND left(path, 2) <> '//' AND length(path) <= 1000),
    updated_at  timestamptz NOT NULL DEFAULT now(),

    PRIMARY KEY (tenant_id, user_id),
    -- An app place names the app and the business it was opened in.
    CHECK (place_kind = 'HUB' OR (app_id IS NOT NULL AND bus_id IS NOT NULL)),

    FOREIGN KEY (tenant_id, user_id) REFERENCES core_platform.cp_users (tenant_id, id) ON DELETE CASCADE
);
