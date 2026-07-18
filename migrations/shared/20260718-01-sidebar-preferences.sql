-- 20260718-01-sidebar-preferences.sql
-- Per-user sidebar preference (docked / collapsed / hidden) for the coreplatform
-- and mystoreguard frontends. Mirrors the cp_themes per-user-setting design.
--
-- Created here (shared SQL) rather than via EF for the same reason the advanced
-- returns store-credit tables were: a self-contained per-user setting table that
-- needs to land on every DB, kept out of the EF model. Idempotent; safe to
-- re-run on every deploy.

CREATE TABLE IF NOT EXISTS core_platform.cp_sidebar_preferences (
    id             text        NOT NULL DEFAULT gen_random_uuid()::text,
    tenant_id      text        NOT NULL,
    user_id        text        NOT NULL,

    sidebar_mode   text        NOT NULL DEFAULT 'hidden'
        CHECK (sidebar_mode IN ('docked', 'collapsed', 'hidden')),
    description    text,

    delete_status  text        NOT NULL DEFAULT 'NOT_DELETED',
    is_active      boolean     NOT NULL DEFAULT true,

    cdate          text,
    ctime          text,
    cdatetime      timestamptz NOT NULL DEFAULT NOW(),

    created_by     text,
    updated_by     text,
    deleted_by     text,

    PRIMARY KEY (tenant_id, user_id, id),

    FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants(id) ON DELETE CASCADE,
    FOREIGN KEY (tenant_id, user_id)    REFERENCES core_platform.cp_users(tenant_id, id) ON DELETE CASCADE,
    FOREIGN KEY (tenant_id, created_by) REFERENCES core_platform.cp_users(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, updated_by) REFERENCES core_platform.cp_users(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, deleted_by) REFERENCES core_platform.cp_users(tenant_id, id) ON DELETE RESTRICT
);

-- One active preference row per user.
CREATE UNIQUE INDEX IF NOT EXISTS uq_cp_sidebar_preferences_user
    ON core_platform.cp_sidebar_preferences (tenant_id, user_id)
    WHERE delete_status = 'NOT_DELETED';
