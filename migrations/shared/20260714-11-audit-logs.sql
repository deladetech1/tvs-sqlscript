-- 20260714-11-audit-logs.sql
-- Per-entity audit logs for MyStoreGuard. Separate from the unified
-- mystoreguard.msg_activity_logs trail: each audited entity gets its own
-- dedicated table so its history can be listed and filtered independently.
-- Two tables here: customers and suppliers. Every create/update/delete on
-- those entities appends one row (written in the same transaction as the CRUD
-- op, so it commits/rolls back atomically). old_data/new_data are kept as JSONB
-- purely to render a clean before/after diff in the UI.
-- Idempotent; safe to re-run on every deploy.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_customer_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,

    entity_id              text        NOT NULL,               -- customer_id the action was performed on
    entity_name            text,                               -- snapshot of the customer's fullname for display/filter

    action                 text        NOT NULL,               -- 'create' | 'update' | 'delete'
    old_data               jsonb,                              -- state before the change (update/delete)
    new_data               jsonb,                              -- state after the change (create/update)
    description            text,

    performed_by           text,                               -- user id who performed the action
    performed_by_fullname  text,                               -- denormalised for display + person filter
    performed_by_email     text,
    performed_by_contact   text,

    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_msg_customer_audit_logs_scope
    ON mystoreguard.msg_customer_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);

CREATE INDEX IF NOT EXISTS idx_msg_customer_audit_logs_action
    ON mystoreguard.msg_customer_audit_logs (tenant_id, org_id, bus_id, action);

CREATE INDEX IF NOT EXISTS idx_msg_customer_audit_logs_performed_by
    ON mystoreguard.msg_customer_audit_logs (tenant_id, org_id, bus_id, performed_by);


CREATE TABLE IF NOT EXISTS mystoreguard.msg_supplier_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,

    entity_id              text        NOT NULL,               -- supplier_id the action was performed on
    entity_name            text,                               -- snapshot of the supplier's fullname for display/filter

    action                 text        NOT NULL,               -- 'create' | 'update' | 'delete'
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

CREATE INDEX IF NOT EXISTS idx_msg_supplier_audit_logs_scope
    ON mystoreguard.msg_supplier_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);

CREATE INDEX IF NOT EXISTS idx_msg_supplier_audit_logs_action
    ON mystoreguard.msg_supplier_audit_logs (tenant_id, org_id, bus_id, action);

CREATE INDEX IF NOT EXISTS idx_msg_supplier_audit_logs_performed_by
    ON mystoreguard.msg_supplier_audit_logs (tenant_id, org_id, bus_id, performed_by);
