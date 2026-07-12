-- 20260712-02-purchase-order-approver.sql
-- Named approver for MyStoreGuard purchase orders.
-- A PO can designate a specific user who must approve it (DRAFT -> APPROVED);
-- only that user is allowed to approve/reject. Mirrors the store-transfers
-- person_to_approve_id model. Column is added idempotently so it lands on
-- every DB without a code-first migration. Safe to re-run on every deploy.

ALTER TABLE mystoreguard.msg_purchase_orders
    ADD COLUMN IF NOT EXISTS person_to_approve_id text;

CREATE INDEX IF NOT EXISTS idx_msg_purchase_orders_approver
    ON mystoreguard.msg_purchase_orders (person_to_approve_id, tenant_id, org_id, bus_id);
