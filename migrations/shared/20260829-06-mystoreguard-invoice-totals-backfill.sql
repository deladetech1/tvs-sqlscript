-- 20260829-06-mystoreguard-invoice-totals-backfill.sql
-- Bring invoice paid/balance figures back in line with the payments behind them.
--
-- An invoice takes payment by creating a SALE, so its paid_amount,
-- balance_amount and status are figures derived from that sale's payments.
-- Until the fix that accompanies this migration, only the invoice's own paying
-- path refreshed them. Every other route to a payment on that sale left the
-- money banked and the invoice reading as outstanding:
--
--   * a cash payment added later from the sale screen,
--   * an online payment banked by the till,
--   * one picked up by the sweep hours afterwards when no browser reported it.
--
-- The code fix stops new drift. It does not repair what already drifted, which
-- is what this does. On dev that is one invoice short by GHS 10.00 — a cash
-- payment taken the day after the invoice was raised. Other environments will
-- have their own; this recomputes every invoice rather than naming any, so it
-- corrects whatever is actually wrong wherever it runs.
--
-- The figure is computed exactly as invoices_service._TOTAL_PAID_SQL computes
-- it, from BOTH places a payment can live: msg_sales_payments reached through
-- msg_invoice_sales, and msg_invoice_payments directly (an invoice raised for
-- goods not yet held has no sale until it is fulfilled).
--
-- Safe to re-run. It is a recomputation, not an adjustment, so running it
-- twice leaves the same answer; only rows that actually differ are written.

BEGIN;

WITH derived AS (
    SELECT
        i.id,
        i.tenant_id,
        i.org_id,
        i.bus_id,
        i.loc_id,
        i.total_amount,
        COALESCE((
            SELECT SUM(x.paid_amount) FROM (
                SELECT sp.paid_amount
                FROM mystoreguard.msg_sales_payments sp
                INNER JOIN mystoreguard.msg_invoice_sales ins
                    ON  sp.sale_id   = ins.sale_id
                    AND sp.tenant_id = ins.tenant_id
                    AND sp.org_id    = ins.org_id
                    AND sp.bus_id    = ins.bus_id
                    AND sp.loc_id    = ins.loc_id
                WHERE ins.invoice_id = i.id
                  AND sp.payment_status = 'SUCCESS'
                  AND ins.deleted_at IS NULL
                  AND sp.deleted_at IS NULL
                UNION ALL
                SELECT ip.paid_amount
                FROM mystoreguard.msg_invoice_payments ip
                WHERE ip.invoice_id = i.id
                  AND ip.payment_status = 'SUCCESS'
                  AND ip.deleted_at IS NULL
            ) x
        ), 0) AS new_paid
    FROM mystoreguard.msg_invoices i
)
UPDATE mystoreguard.msg_invoices i
SET paid_amount    = d.new_paid,
    balance_amount = d.total_amount - d.new_paid,
    -- CANCELLED is left exactly as it is. A cancelled invoice carrying money
    -- needs a person to look at it, not a status quietly moved by a migration.
    status = CASE
                 WHEN i.status = 'CANCELLED'        THEN i.status
                 WHEN d.new_paid >= d.total_amount  THEN 'COMPLETED'
                 WHEN d.new_paid > 0                THEN 'PARTIALLY_PAID'
                 ELSE 'DRAFT'
             END
FROM derived d
WHERE i.id        = d.id
  AND i.tenant_id = d.tenant_id
  AND i.org_id    = d.org_id
  AND i.bus_id    = d.bus_id
  AND i.loc_id    = d.loc_id
  -- Only rows that are actually wrong, so the audit trail and updated
  -- timestamps of correct invoices are left undisturbed.
  AND (
        i.paid_amount    IS DISTINCT FROM d.new_paid
     OR i.balance_amount IS DISTINCT FROM (d.total_amount - d.new_paid)
     OR i.status         IS DISTINCT FROM CASE
             WHEN i.status = 'CANCELLED'       THEN i.status
             WHEN d.new_paid >= d.total_amount THEN 'COMPLETED'
             WHEN d.new_paid > 0               THEN 'PARTIALLY_PAID'
             ELSE 'DRAFT'
         END
  );

COMMIT;
