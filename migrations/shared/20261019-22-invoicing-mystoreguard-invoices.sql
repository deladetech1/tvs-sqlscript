-- =====================================================================
-- Invoicing: MyStoreGuard's invoices, brought in to be paid here
-- ---------------------------------------------------------------------
-- A MyStoreGuard invoice that is still owed can be brought into Invoicing,
-- so the customer can pay it with Invoicing's link, portal and saved cards.
-- It stays MyStoreGuard's: its lines and total are MyStoreGuard's, and a
-- payment taken here is posted back to MyStoreGuard THROUGH MyStoreGuard's own
-- payment code (InvoicesService.create_payment), the one path that knows how
-- an invoice takes money -- the linked sale, stock, fulfilment.
--
-- Invoicing never writes MyStoreGuard's tables. It queues the payment in
-- invoicing.inv_msg_payment_queue, in the same transaction as the payment
-- itself, and MyStoreGuard drains the queue (msg_queue_claim / msg_queue_done).
-- Each queued payment carries a reference ('invoicing:<queue id>') that
-- MyStoreGuard stores on the payment it makes, under a unique index, so a
-- payment is posted once however often it is retried.
--
-- Idempotent; safe to re-run.
-- =====================================================================
BEGIN;

-- The reference on an invoice payment taken before the goods are here (moved
-- onto the sale's payment, with the reference, at fulfilment).
ALTER TABLE mystoreguard.msg_invoice_payments ADD COLUMN IF NOT EXISTS online_payment_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_invoice_payments_online_reference
    ON mystoreguard.msg_invoice_payments (tenant_id, online_payment_reference)
    WHERE online_payment_reference IS NOT NULL AND deleted_at IS NULL;

-- ===================================================================== the source
DO $$
BEGIN
    IF to_regclass('mystoreguard.msg_invoices') IS NOT NULL AND to_regclass('mystoreguard.msg_invoice_items') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW invoicing.src_mystoreguard_invoice_lines AS
        SELECT it.tenant_id, it.bus_id, it.invoice_id,
               it.id                                                AS source_line_id,
               coalesce(NULLIF(btrim(it.product_name), ''), 'Item') AS name,
               coalesce(btrim(it.description), '')                  AS description,
               coalesce(it.quantity, 0)                             AS quantity,
               coalesce(it.final_price, 0)                          AS unit_price,
               coalesce(it.line_total, 0)                           AS line_total,
               coalesce(it.tax_amount, 0)                           AS tax_amount,
               coalesce((SELECT string_agg(DISTINCT coalesce(t->>'tax_name', t->>'name'), ', ')
                           FROM jsonb_array_elements(CASE WHEN jsonb_typeof(it.taxes_applied) = 'array' THEN it.taxes_applied ELSE '[]'::jsonb END) t
                          WHERE coalesce(t->>'tax_name', t->>'name') IS NOT NULL), '') AS tax_names,
               it.cdatetime
          FROM mystoreguard.msg_invoice_items it
         WHERE it.deleted_by IS NULL
        $v$;

        -- What has been paid, and how much of it came from Invoicing.
        EXECUTE $v$
        CREATE OR REPLACE VIEW invoicing.src_mystoreguard_invoice_paid AS
        SELECT x.tenant_id, x.invoice_id,
               coalesce(sum(x.paid_amount), 0)                                                        AS paid,
               coalesce(sum(x.paid_amount) FILTER (WHERE x.ref LIKE 'invoicing:%'), 0)                AS paid_from_invoicing,
               coalesce(array_agg(x.ref) FILTER (WHERE x.ref LIKE 'invoicing:%'), '{}')               AS invoicing_refs
          FROM (SELECT ins.tenant_id, ins.invoice_id, sp.paid_amount, sp.online_payment_reference AS ref
                  FROM mystoreguard.msg_sales_payments sp
                  JOIN mystoreguard.msg_invoice_sales ins ON ins.sale_id = sp.sale_id AND ins.tenant_id = sp.tenant_id
                 WHERE sp.payment_status = 'SUCCESS' AND sp.deleted_at IS NULL AND ins.deleted_at IS NULL
                UNION ALL
                SELECT ip.tenant_id, ip.invoice_id, ip.paid_amount, ip.online_payment_reference
                  FROM mystoreguard.msg_invoice_payments ip
                 WHERE ip.payment_status = 'SUCCESS' AND ip.deleted_at IS NULL) x
         GROUP BY x.tenant_id, x.invoice_id
        $v$;

        EXECUTE $v$
        CREATE OR REPLACE VIEW invoicing.src_mystoreguard_invoices AS
        SELECT i.tenant_id, i.org_id, i.bus_id, i.loc_id,
               coalesce(l.loc_name, '')                AS location,
               i.id                                    AS source_id,
               i.invoice_number                        AS number,
               i.customer_id,
               coalesce(btrim(c.fullname), '')         AS customer_name,
               i.sale_date, i.due_date, i.status, i.sale_mode,
               coalesce(i.description, '')             AS description,
               i.total_amount                          AS total,
               i.promo_discount_amount                 AS promo_discount,
               i.gift_card_amount_used                 AS gift_card_used,
               coalesce(p.paid, 0)                     AS paid,
               coalesce(p.paid_from_invoicing, 0)      AS paid_from_invoicing,
               i.total_amount - coalesce(p.paid, 0)    AS balance,
               coalesce(i.fulfilment_status, '')       AS fulfilment_status,
               (i.deleted_by IS NOT NULL)              AS is_removed,
               i.created_by,
               i.cdatetime
          FROM mystoreguard.msg_invoices i
          LEFT JOIN mystoreguard.msg_customers c ON c.id = i.customer_id AND c.tenant_id = i.tenant_id
          LEFT JOIN core_platform.cp_locations l ON l.id = i.loc_id AND l.tenant_id = i.tenant_id
          LEFT JOIN invoicing.src_mystoreguard_invoice_paid p ON p.invoice_id = i.id AND p.tenant_id = i.tenant_id
        $v$;
    END IF;
END $$;

-- ===================================================================== the queue
CREATE TABLE IF NOT EXISTS invoicing.inv_msg_payment_queue (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    org_id          text,
    bus_id          text NOT NULL,
    loc_id          text NOT NULL,
    msg_invoice_id  text NOT NULL,
    invoice_id      text NOT NULL REFERENCES invoicing.inv_invoices (id) ON DELETE CASCADE,
    payment_id      text NOT NULL REFERENCES invoicing.inv_payments (id) ON DELETE CASCADE,
    amount          numeric(18,2) NOT NULL CHECK (amount > 0),
    method          text NOT NULL,
    description     text NOT NULL DEFAULT '',
    -- Who MyStoreGuard records it as: the person who took it here, else the invoice's maker.
    posted_as       text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    attempts        int NOT NULL DEFAULT 0,
    next_try_at     timestamptz NOT NULL DEFAULT now(),
    posted_at       timestamptz,
    failed_at       timestamptz,
    last_error      text,
    cancelled_at    timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS inv_msg_payment_queue_payment_uq ON invoicing.inv_msg_payment_queue (payment_id);
CREATE INDEX IF NOT EXISTS inv_msg_payment_queue_due ON invoicing.inv_msg_payment_queue (next_try_at)
    WHERE posted_at IS NULL AND failed_at IS NULL AND cancelled_at IS NULL;
CREATE INDEX IF NOT EXISTS inv_msg_payment_queue_invoice ON invoicing.inv_msg_payment_queue (invoice_id);

-- MyStoreGuard takes up to p_limit due payments. Each is held for two minutes (the next
-- try), so two replicas never post the same one at once, and one that crashed mid-post is
-- taken again -- harmless, as the reference makes the second post a no-op.
CREATE OR REPLACE FUNCTION invoicing.msg_queue_claim(p_limit int DEFAULT 20)
RETURNS TABLE (id text, tenant_id text, org_id text, bus_id text, loc_id text, msg_invoice_id text,
               amount numeric, method text, description text, reference text, posted_as text, attempts int)
LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, invoicing AS $f$
    UPDATE invoicing.inv_msg_payment_queue q
       SET attempts = q.attempts + 1, next_try_at = now() + interval '2 minutes'
     WHERE q.id IN (SELECT d.id FROM invoicing.inv_msg_payment_queue d
                     WHERE d.posted_at IS NULL AND d.failed_at IS NULL AND d.cancelled_at IS NULL AND d.next_try_at <= now()
                     ORDER BY d.cdatetime
                     LIMIT greatest(1, least(p_limit, 100))
                     FOR UPDATE SKIP LOCKED)
    RETURNING q.id, q.tenant_id, q.org_id, q.bus_id, q.loc_id, q.msg_invoice_id, q.amount, q.method, q.description,
              'invoicing:' || q.id, q.posted_as, q.attempts
$f$;

-- What came of one: posted; refused for good (MyStoreGuard said no, e.g. more than is
-- owed there -- a person must look); or a passing failure, tried again later, less often.
CREATE OR REPLACE FUNCTION invoicing.msg_queue_done(p_id text, p_outcome text, p_error text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, invoicing AS $f$
BEGIN
    IF p_outcome = 'posted' THEN
        UPDATE invoicing.inv_msg_payment_queue SET posted_at = now(), last_error = NULL WHERE id = p_id;
    ELSIF p_outcome = 'refused' THEN
        UPDATE invoicing.inv_msg_payment_queue SET failed_at = now(), last_error = left(p_error, 1000) WHERE id = p_id;
    ELSE
        UPDATE invoicing.inv_msg_payment_queue
           SET last_error = left(p_error, 1000),
               next_try_at = now() + least(interval '1 hour', interval '30 seconds' * power(2, least(attempts, 10)))
         WHERE id = p_id;
    END IF;
END
$f$;

REVOKE ALL ON FUNCTION invoicing.msg_queue_claim(int) FROM PUBLIC;
REVOKE ALL ON FUNCTION invoicing.msg_queue_done(text, text, text) FROM PUBLIC;
DO $$
DECLARE r text;
BEGIN
    -- THIS database's MyStoreGuard login(s), whatever the environment calls them
    -- (control_plane.app_logins_here, 20261001-01). Until 2026-10-23 it was every
    -- ^mystoreguard(_|$) role on the server, so each silo's MyStoreGuard could claim
    -- and mark another tenant's payment-queue rows in their database.
    FOR r IN SELECT control_plane.app_logins_here('mystoreguard') LOOP
        EXECUTE format('GRANT EXECUTE ON FUNCTION invoicing.msg_queue_claim(int) TO %I', r);
        EXECUTE format('GRANT EXECUTE ON FUNCTION invoicing.msg_queue_done(text, text, text) TO %I', r);
    END LOOP;
END $$;

COMMIT;
