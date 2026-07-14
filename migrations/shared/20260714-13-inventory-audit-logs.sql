-- 20260714-13-inventory-audit-logs.sql
-- Per-entity audit logs for MyStoreGuard inventory, mirroring the customer/
-- supplier (20260714-11) and loyalty (20260714-12) audit tables. One dedicated
-- table per audited inventory entity: products, purchase orders and product
-- splits. Every create/update/delete appends one row (written in the same
-- transaction as the CRUD op, so it commits/rolls back atomically). old_data/
-- new_data are kept as JSONB purely to render a clean before/after diff in the UI.
-- Idempotent; safe to re-run on every deploy.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_product_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,
    entity_id              text        NOT NULL,               -- product id
    entity_name            text,                               -- snapshot of the product name
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

CREATE INDEX IF NOT EXISTS idx_msg_product_audit_logs_scope
    ON mystoreguard.msg_product_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_product_audit_logs_action
    ON mystoreguard.msg_product_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_product_audit_logs_performed_by
    ON mystoreguard.msg_product_audit_logs (tenant_id, org_id, bus_id, performed_by);


CREATE TABLE IF NOT EXISTS mystoreguard.msg_purchase_order_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,
    entity_id              text        NOT NULL,               -- purchase order id
    entity_name            text,                               -- snapshot of the po_number
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

CREATE INDEX IF NOT EXISTS idx_msg_purchase_order_audit_logs_scope
    ON mystoreguard.msg_purchase_order_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_purchase_order_audit_logs_action
    ON mystoreguard.msg_purchase_order_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_purchase_order_audit_logs_performed_by
    ON mystoreguard.msg_purchase_order_audit_logs (tenant_id, org_id, bus_id, performed_by);


CREATE TABLE IF NOT EXISTS mystoreguard.msg_product_split_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,
    entity_id              text        NOT NULL,               -- split id
    entity_name            text,                               -- snapshot of the split_number
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

CREATE INDEX IF NOT EXISTS idx_msg_product_split_audit_logs_scope
    ON mystoreguard.msg_product_split_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_product_split_audit_logs_action
    ON mystoreguard.msg_product_split_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_product_split_audit_logs_performed_by
    ON mystoreguard.msg_product_split_audit_logs (tenant_id, org_id, bus_id, performed_by);
