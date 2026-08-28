-- 20260828-08-mystoreguard-invoice-sale-mode.sql
-- A sale raised by paying an invoice gets its own mode.
--
-- INSTALLMENT was carrying two meanings. A sale on an installment PLAN is
-- priced by a policy, held by a schedule and possibly gated by an approver. An
-- invoice being paid off in parts has none of that — the invoice owns the
-- balance and decides when the next payment comes — yet both were written as
-- INSTALLMENT, so every partial invoice payment was refused for having no plan.
--
-- Separating them restores an invariant worth having: INSTALLMENT means there
-- is a plan. That is what the installment screens and their counts assume, and
-- it is why a plan-less sale showing among them was confusing before.
--
-- INVOICE settles the same way INSTALLMENT does — stock moves on full payment,
-- not on the first instalment — so nothing about fulfilment changes.
--
-- Idempotent; safe to re-run on every deploy.

-- ---------------------------------------------------------------------------
-- Allow the new mode
-- ---------------------------------------------------------------------------
ALTER TABLE mystoreguard.msg_sales
    DROP CONSTRAINT IF EXISTS ck_msg_sales_sale_mode;
ALTER TABLE mystoreguard.msg_sales
    ADD CONSTRAINT ck_msg_sales_sale_mode
    CHECK (sale_mode IN ('INSTANT', 'INSTALLMENT', 'CREDIT', 'INVOICE'));

ALTER TABLE mystoreguard.msg_invoices
    DROP CONSTRAINT IF EXISTS ck_msg_invoices_sale_mode;
ALTER TABLE mystoreguard.msg_invoices
    ADD CONSTRAINT ck_msg_invoices_sale_mode
    CHECK (sale_mode IN ('INSTANT', 'INSTALLMENT', 'CREDIT', 'INVOICE'));

-- ---------------------------------------------------------------------------
-- Relabel the sales that were only ever invoice payments
--
-- Narrow on purpose. A plan-less INSTALLMENT sale is not proof of an invoice:
-- the DEPOSIT-era sales that predate plans look identical on that test alone,
-- and calling those INVOICE would be a different lie. The description is what
-- the invoice service writes on every sale it raises, so the three conditions
-- together name exactly the affected rows.
-- ---------------------------------------------------------------------------
UPDATE mystoreguard.msg_sales s
   SET sale_mode = 'INVOICE'
 WHERE s.sale_mode = 'INSTALLMENT'
   AND s.description LIKE 'Payment for invoice %'
   AND NOT EXISTS (
       SELECT 1 FROM mystoreguard.msg_installment_plans p
        WHERE p.sale_id = s.id AND p.tenant_id = s.tenant_id
          AND p.deleted_by IS NULL);
