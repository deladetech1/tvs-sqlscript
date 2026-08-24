-- 20260824-01-mystoreguard-login-audit-logs.sql
-- Sign-in history for the MyStoreGuard web app, mirroring the CorePlatform
-- trail added in 20260823-03 but scoped the MyStoreGuard way (org_id/bus_id
-- NOT NULL, like every other msg_*_audit_logs table) so AuditLogService reads
-- and writes it unchanged.
--
-- MyStoreGuard web has no login screen of its own: it receives an already-minted
-- token from TroveSuite (URL hash on launch, or an AUTH_UPDATE postMessage when
-- embedded). So a row here is an APP SESSION, not a credential authentication —
-- 'login' means the user opened MyStoreGuard for this business/location and
-- 'logout' means that session ended. The password check itself lives in
-- CorePlatform's core_platform.cp_login_audit_logs.
--
--   entity_id   = cp_users.id
--   entity_name = snapshot of the user's fullname
--   action      = 'login' | 'logout'
--   new_data    = ip address, user agent, how the session started/ended
--
-- No foreign key to the user on purpose: the history must outlive the user row.
-- tenant_id + cdatetime are mandatory for the retention job in
-- 20260731-01-activity-log-retention.sql to discover and purge this table.
--
-- Idempotent; safe to re-run on every deploy.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_login_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,

    entity_id              text        NOT NULL,               -- user id the session belongs to
    entity_name            text,                               -- snapshot of fullname for display/filter

    action                 text        NOT NULL,               -- 'login' | 'logout'
    old_data               jsonb,
    new_data               jsonb,                              -- ip_address, user_agent, login_method, logout_reason
    description            text,

    performed_by           text,
    performed_by_fullname  text,
    performed_by_email     text,
    performed_by_contact   text,

    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_msg_login_audit_logs_scope
    ON mystoreguard.msg_login_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_login_audit_logs_entity
    ON mystoreguard.msg_login_audit_logs (tenant_id, org_id, bus_id, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_login_audit_logs_action
    ON mystoreguard.msg_login_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_login_audit_logs_performed_by
    ON mystoreguard.msg_login_audit_logs (tenant_id, org_id, bus_id, performed_by);
