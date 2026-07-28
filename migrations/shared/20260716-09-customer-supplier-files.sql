-- 20260716-09-customer-supplier-files.sql
-- Optional profile picture + file/image attachments for customers and suppliers.
--   * profile_document_id points at a single image in msg_document_paths.
--   * msg_customer_attachments / msg_supplier_attachments link any number of
--     uploaded files (docs or images) to a customer/supplier, mirroring
--     msg_task_attachments.
-- Idempotent; safe to re-run on every deploy.

-- Profile pictures ----------------------------------------------------------
ALTER TABLE mystoreguard.msg_customers
    ADD COLUMN IF NOT EXISTS profile_document_id text;

ALTER TABLE mystoreguard.msg_suppliers
    ADD COLUMN IF NOT EXISTS profile_document_id text;

-- Customer attachments ------------------------------------------------------
CREATE TABLE IF NOT EXISTS mystoreguard.msg_customer_attachments (
    id             text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text        NOT NULL,
    org_id         text        NOT NULL,
    bus_id         text        NOT NULL,
    customer_id    text        NOT NULL,
    document_id    text        NOT NULL,                      -- -> mystoreguard.msg_document_paths(id)
    is_active      boolean     DEFAULT TRUE,
    delete_status  text        DEFAULT 'NOT_DELETED',
    cdate          text,
    ctime          text,
    cdatetime      timestamptz DEFAULT NOW(),
    created_by     text
);

CREATE INDEX IF NOT EXISTS idx_msg_customer_attachments_owner
    ON mystoreguard.msg_customer_attachments
    (customer_id, tenant_id, org_id, bus_id, delete_status, is_active);

-- Supplier attachments ------------------------------------------------------
CREATE TABLE IF NOT EXISTS mystoreguard.msg_supplier_attachments (
    id             text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text        NOT NULL,
    org_id         text        NOT NULL,
    bus_id         text        NOT NULL,
    supplier_id    text        NOT NULL,
    document_id    text        NOT NULL,                      -- -> mystoreguard.msg_document_paths(id)
    is_active      boolean     DEFAULT TRUE,
    delete_status  text        DEFAULT 'NOT_DELETED',
    cdate          text,
    ctime          text,
    cdatetime      timestamptz DEFAULT NOW(),
    created_by     text
);

CREATE INDEX IF NOT EXISTS idx_msg_supplier_attachments_owner
    ON mystoreguard.msg_supplier_attachments
    (supplier_id, tenant_id, org_id, bus_id, delete_status, is_active);
