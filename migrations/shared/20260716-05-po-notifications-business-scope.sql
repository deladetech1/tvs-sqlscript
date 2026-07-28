-- 20260716-05-po-notifications-business-scope.sql
-- Purchase-order approval reminder settings become PER-BUSINESS instead of
-- per-user: one opt-in + interval for the whole tenant/org/bus. Collapses any
-- existing per-user rows into a single business row. Idempotent.

-- Allow the business-level row (no user).
ALTER TABLE mystoreguard.msg_purchase_order_notification_settings
    ALTER COLUMN user_id DROP NOT NULL;

-- Drop the old per-user uniqueness.
DROP INDEX IF EXISTS mystoreguard.uq_msg_po_notification_settings_user;

-- Collapse to one row per business (keep the most recently updated), then clear
-- the user so it reads as a business-level setting.
DELETE FROM mystoreguard.msg_purchase_order_notification_settings s
WHERE s.id NOT IN (
    SELECT DISTINCT ON (tenant_id, org_id, bus_id) id
    FROM mystoreguard.msg_purchase_order_notification_settings
    ORDER BY tenant_id, org_id, bus_id, cdatetime DESC NULLS LAST
);

UPDATE mystoreguard.msg_purchase_order_notification_settings
SET user_id = NULL
WHERE user_id IS NOT NULL;

-- One settings row per business.
CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_po_notification_settings_business
    ON mystoreguard.msg_purchase_order_notification_settings (tenant_id, org_id, bus_id);
