-- 20260712-04-purchase-order-received-status.sql
-- Add a RECEIVED status to purchase orders: all items are in but the supplier
-- is not yet fully paid. COMPLETED now means received AND fully paid.
-- Widens the existing status CHECK constraint. Idempotent (drop-then-add).

ALTER TABLE mystoreguard.msg_purchase_orders
    DROP CONSTRAINT IF EXISTS ck_msg_purchase_orders_status;

ALTER TABLE mystoreguard.msg_purchase_orders
    ADD CONSTRAINT ck_msg_purchase_orders_status
    CHECK (status IN ('DRAFT', 'APPROVED', 'PARTIALLY_RECEIVED', 'RECEIVED', 'CANCELLED', 'COMPLETED'));
