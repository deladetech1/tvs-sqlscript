-- HMS: paying at the table, and paying when room service arrives.
--
--   hms_orders.bill_presented_at/_by  the bill was taken to the table: the guests are finishing and
--                                     will pay there (cash, card, mobile money, or the QR on the bill).
--   hms_orders.delivered_at/_by       room service (or a delivery) handed over.
--   hms_orders.pay_on_delivery        the guest pays when it arrives, not on the room's bill.

BEGIN;

ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS bill_presented_at timestamptz;
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS bill_presented_by text;
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS delivered_at timestamptz;
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS delivered_by text;
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS pay_on_delivery boolean NOT NULL DEFAULT false;

COMMIT;
