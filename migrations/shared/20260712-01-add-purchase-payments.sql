-- 20260712-01-add-purchase-payments.sql
-- Supplier payments against purchase orders for MyStoreGuard.
-- Records money paid OUT to a supplier for a purchase order, supporting paying
-- in full or in installments (credit) over time. Mirrors mystoreguard.msg_sales_payments
-- (the sale side). Used by the tvs-mystoreguard-bk app via raw SQL (not EF-managed),
-- so it lives here as idempotent shared SQL. Safe to re-run on every deploy.

-- ---------------------------------------------------------------------
-- Supplier payments: one row per payment recorded against a purchase order.
-- The PO's balance is derived as SUM(cost_price * qty_ordered) over its items
-- minus SUM(paid_amount) of SUCCESS, non-refunded payments. Refunds set
-- payment_status = 'REFUNDED' and stamp deleted_at, excluding them from the total.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mystoreguard.msg_purchase_payments (
    id                  text        PRIMARY KEY,
    tenant_id           text        NOT NULL,
    org_id              text        NOT NULL,
    bus_id              text        NOT NULL,
    loc_id              text,                                    -- POs are org/bus scoped; kept nullable for parity

    purchase_order_id   text        NOT NULL,                    -- the PO this payment settles

    payment_method      text        NOT NULL,                    -- CASH, CARD, BANK_TRANSFER, MOBILE_MONEY, CHEQUE, BITCOIN, OTHERS
    payment_status      text        NOT NULL DEFAULT 'SUCCESS',  -- SUCCESS, FAILED, PENDING, REFUNDED
    paid_amount         numeric(18,2) NOT NULL CHECK (paid_amount > 0),
    description         text,

    cdate               text,
    ctime               text,
    cdatetime           timestamptz,
    created_by          text,
    updated_by          text,
    deleted_by          text,
    deleted_at          timestamptz                              -- soft delete / refund marker
);

CREATE INDEX IF NOT EXISTS idx_msg_purchase_payments_scope
    ON mystoreguard.msg_purchase_payments (tenant_id, org_id, bus_id);

CREATE INDEX IF NOT EXISTS idx_msg_purchase_payments_po
    ON mystoreguard.msg_purchase_payments (purchase_order_id, tenant_id, org_id, bus_id, payment_status, deleted_at);
