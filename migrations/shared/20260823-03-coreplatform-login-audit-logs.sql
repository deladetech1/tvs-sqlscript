-- 20260823-03-coreplatform-login-audit-logs.sql
-- Login / logout audit trail for CorePlatform.
--
-- Same per-entity audit shape established in 20260729-01 / 20260730-01, so
-- AuditLogService.record()/list()/stats() work against it unchanged. Here the
-- audited "entity" is the user whose session started or ended:
--   entity_id   = cp_users.id
--   entity_name = snapshot of the user's fullname
--   action      = 'login' | 'logout'
-- Session details that have no dedicated column (ip address, user agent, how the
-- login was authenticated, why the session ended) are kept in new_data.
--
-- No foreign key to cp_users on purpose: the sign-in history must outlive the
-- user row (esp. permanent delete). org_id/bus_id stay nullable — sign-in is a
-- tenant-level event with no org/business scope.
--
-- tenant_id + cdatetime are mandatory for the retention job in
-- 20260731-01-activity-log-retention.sql to discover and purge this table.
--
-- Idempotent; safe to re-run on every deploy.

CREATE TABLE IF NOT EXISTS core_platform.cp_login_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,
    bus_id                 text,

    entity_id              text        NOT NULL,               -- user id the session belongs to
    entity_name            text,                               -- snapshot of fullname for display/filter

    action                 text        NOT NULL,               -- 'login' | 'logout'
    old_data               jsonb,
    new_data               jsonb,                              -- ip_address, user_agent, method, reason
    description            text,

    performed_by           text,
    performed_by_fullname  text,
    performed_by_email     text,
    performed_by_contact   text,

    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cp_login_audit_logs_scope
    ON core_platform.cp_login_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_login_audit_logs_entity
    ON core_platform.cp_login_audit_logs (tenant_id, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_login_audit_logs_action
    ON core_platform.cp_login_audit_logs (tenant_id, action);
CREATE INDEX IF NOT EXISTS idx_cp_login_audit_logs_performed_by
    ON core_platform.cp_login_audit_logs (tenant_id, performed_by);
