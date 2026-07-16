-- 20260716-08-po-notification-mention.sql
-- Let the purchase-order email outbox carry a MENTIONED notification: when a
-- user is @tagged in a PO discussion, a row is enqueued here and the Functions
-- app emails them the message. comment_id lets the drainer fetch the typed text.
-- (kind already accepts new values: ASSIGNED | NEEDS_APPROVAL | REMINDER | MENTIONED.)
-- Idempotent; safe to re-run on every deploy.

ALTER TABLE mystoreguard.msg_purchase_order_notifications
    ADD COLUMN IF NOT EXISTS comment_id text;
