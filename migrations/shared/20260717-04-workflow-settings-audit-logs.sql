-- 20260717-04-workflow-settings-audit-logs.sql
-- Per-entity audit log for Workflow Settings (per-user task notification
-- preferences). Mirrors the existing audit tables. Idempotent.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_workflow_setting_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,
    entity_id              text        NOT NULL,
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
CREATE INDEX IF NOT EXISTS idx_msg_workflow_setting_audit_logs_scope
    ON mystoreguard.msg_workflow_setting_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_workflow_setting_audit_logs_action
    ON mystoreguard.msg_workflow_setting_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_workflow_setting_audit_logs_performed_by
    ON mystoreguard.msg_workflow_setting_audit_logs (tenant_id, org_id, bus_id, performed_by);
