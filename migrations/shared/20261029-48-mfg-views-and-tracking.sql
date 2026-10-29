-- Manufacturing: saved list views (contract R1.md; 02-domain-model.md §11, R-18).
--
--   mfg_saved_views           a user's named filter, sort and column set on a list (the list
--                             route's query string), optionally shared with the business
--
-- mfg_item_settings.tracking (none | lot | serial) is added in 20261029-42, the table's own file,
-- so the list in 20261029-45 (which runs before this file) applies on the first deploy too.
--
-- No product or party column is added. Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS mfg.mfg_saved_views (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    org_id       text,
    bus_id       text NOT NULL,
    user_id      text NOT NULL,                 -- the owner
    list         text NOT NULL,                 -- e.g. production-orders
    name         text NOT NULL,
    query        text NOT NULL DEFAULT '',      -- the list route's query string
    shared       boolean NOT NULL DEFAULT false,
    position     integer NOT NULL DEFAULT 0,
    archived_at  timestamptz,
    version      integer NOT NULL DEFAULT 1,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text,
    updated_at   timestamptz NOT NULL DEFAULT now(),
    updated_by   text
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_saved_views_name_uq
    ON mfg.mfg_saved_views (bus_id, user_id, list, name) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS mfg_saved_views_shared_idx
    ON mfg.mfg_saved_views (bus_id, list) WHERE shared AND archived_at IS NULL;

COMMIT;
