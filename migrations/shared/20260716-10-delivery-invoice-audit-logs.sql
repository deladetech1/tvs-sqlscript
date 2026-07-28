-- 20260716-01-delivery-invoice-audit-logs.sql
-- Per-entity audit logs for the MyStoreGuard Deliveries and Invoices areas,
-- mirroring the sales/store-return audit tables. Two audited entities:
-- deliveries (incl. dispatch/complete/cancel/status changes) and invoices
-- (incl. payments). Idempotent; safe to re-run on every deploy.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_delivery_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_msg_delivery_audit_logs_scope
    ON mystoreguard.msg_delivery_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_delivery_audit_logs_action
    ON mystoreguard.msg_delivery_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_delivery_audit_logs_performed_by
    ON mystoreguard.msg_delivery_audit_logs (tenant_id, org_id, bus_id, performed_by);

CREATE TABLE IF NOT EXISTS mystoreguard.msg_invoice_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_msg_invoice_audit_logs_scope
    ON mystoreguard.msg_invoice_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_invoice_audit_logs_action
    ON mystoreguard.msg_invoice_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_invoice_audit_logs_performed_by
    ON mystoreguard.msg_invoice_audit_logs (tenant_id, org_id, bus_id, performed_by);
