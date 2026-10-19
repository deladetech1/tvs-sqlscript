-- =====================================================================
-- MyStoreGuard tells the books what happened: accounting events
-- ---------------------------------------------------------------------
-- Roadmap Phase 1, step 1 (docs/POSTINGS.md). Every MyStoreGuard change that moves money or
-- stock publishes an event to core_platform.cp_events IN THE SAME TRANSACTION as the change, so
-- there is never an event without the sale nor a sale without its event. Accounting reads them
-- (reader 'accounting') and posts journals.
--
-- WHY TRIGGERS AND NOT THE SERVICE LAYER. MyStoreGuard has no single place sales go through:
-- create_sale alone is 2,250 lines and is reached from the till, the storefront checkout,
-- auctions, invoice payments and fulfilment, and exchanges; payments are written by six more
-- paths (payments, instalment plans, early settlement, the online-payment sweep, invoices, the
-- Azure functions), and sales are cancelled, deleted and edited by others. A choke point in
-- Python would have to be remembered by every path written from now on. These triggers fire for
-- all of them, including ones that do not exist yet.
--
-- WHY DEFERRED (fired at COMMIT). A sale is written header first, items and payments after,
-- and its status, stock and cost are settled later in the same transaction. A row trigger that
-- published at once would see half a sale. Constraint triggers DEFERRABLE INITIALLY DEFERRED run
-- at commit, read the sale as it finally stands, and compare it with what was last published
-- (the msg_acc_*_state tables): only the difference is published. A sale that fails rolls back
-- and publishes nothing, because its events are in the rolled-back transaction.
--
-- Fail open, loudly: if describing a sale raises, the sale still commits and a
-- 'msg.posting_error' event says which document and why, so Accounting shows it as failed
-- instead of the books silently missing it (a trigger bug must never stop a till).
--
-- Events (subject = the MyStoreGuard id; payload amounts are strings with 2 decimals):
--   msg.sale_completed    goods released (fulfillment FULFILLED, not cancelled): revenue, each
--                         tax, discount, finance charge, cost of the batches deducted, and the
--                         payments made with it; deposits taken earlier; what is still owed
--   msg.sale_voided       a released sale cancelled, deleted, or changed (a change is a void of
--                         the old figures plus a new sale_completed revision)
--   msg.payment_received  a payment not folded into its sale's event: before release a deposit,
--                         after release against the customer's balance (with any penalty part)
--   msg.payment_reversed  a published payment refunded, deleted or reduced
--   msg.return_processed  a return COMPLETED: refund net/tax/fee, restocked cost, how it was paid
--   msg.gift_card_issued  a gift card sold (or given as a reward)
--   msg.plan_refund_paid  money an instalment plan owed the customer, handed back
--   msg.posting_error     a document the triggers could not describe (see above)
--
-- Starts from now: rows that exist when this first runs get a baseline state and publish
-- nothing (history belongs in the books' opening balances). Re-runs every deploy: idempotent.
-- =====================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS mystoreguard.msg_acc_sale_state (
    sale_id      text PRIMARY KEY,
    tenant_id    text NOT NULL,
    bus_id       text,
    created_txid xid8,
    recognised   boolean NOT NULL DEFAULT false,
    revision     integer NOT NULL DEFAULT 0,
    figures      jsonb,
    updated_at   timestamptz NOT NULL DEFAULT now()
);

-- A payment as it was last published. 'applied' is where the money sits in the books:
-- DEPOSIT (goods not yet released) or RECEIVABLE (against the customer's balance).
CREATE TABLE IF NOT EXISTS mystoreguard.msg_acc_payment_state (
    payment_id text PRIMARY KEY,
    source     text NOT NULL CHECK (source IN ('SALE', 'INVOICE')),
    doc_id     text NOT NULL,
    tenant_id  text NOT NULL,
    bus_id     text,
    method     text NOT NULL,
    amount     numeric(18,2) NOT NULL,
    penalty    numeric(18,2) NOT NULL DEFAULT 0,
    applied    text NOT NULL CHECK (applied IN ('DEPOSIT', 'RECEIVABLE')),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS msg_acc_payment_state_doc_idx ON mystoreguard.msg_acc_payment_state (doc_id);

-- Returns, gift cards and plan refunds already published.
CREATE TABLE IF NOT EXISTS mystoreguard.msg_acc_document_state (
    kind       text NOT NULL,
    doc_id     text NOT NULL,
    tenant_id  text NOT NULL,
    value      jsonb NOT NULL DEFAULT '{}',
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (kind, doc_id)
);

-- ===================================================================== helpers
CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_money(v numeric) RETURNS text
LANGUAGE sql IMMUTABLE AS $f$ SELECT to_char(round(coalesce(v, 0), 2), 'FM9999999999999990.00') $f$;

-- The business's date at an instant: the tenant's zone in Core Platform, else UTC.
CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_day(p_tenant text, p_at timestamptz) RETURNS date
LANGUAGE plpgsql STABLE AS $f$
DECLARE z text;
BEGIN
    IF to_regclass('core_platform.cp_timezone_settings') IS NOT NULL THEN
        SELECT timezone INTO z FROM core_platform.cp_timezone_settings
         WHERE tenant_id = p_tenant AND is_active ORDER BY cdatetime DESC NULLS LAST LIMIT 1;
    END IF;
    BEGIN
        RETURN (coalesce(p_at, now()) AT TIME ZONE coalesce(nullif(z, ''), 'UTC'))::date;
    EXCEPTION WHEN invalid_parameter_value THEN
        RETURN (coalesce(p_at, now()) AT TIME ZONE 'UTC')::date;
    END;
END
$f$;

-- A currency id as its code; with no id, the tenant's default currency. '' when unknown
-- (Accounting then takes its base currency).
CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_currency(p_tenant text, p_currency_id text DEFAULT NULL) RETURNS text
LANGUAGE sql STABLE AS $f$
    SELECT coalesce(
        (SELECT upper(code) FROM core_platform.cp_currencies
          WHERE tenant_id = p_tenant AND p_currency_id IS NOT NULL AND id = p_currency_id LIMIT 1),
        (SELECT upper(code) FROM core_platform.cp_currencies
          WHERE tenant_id = p_tenant AND is_default AND coalesce(delete_status, 'NOT_DELETED') = 'NOT_DELETED'
          ORDER BY cdatetime DESC NULLS LAST LIMIT 1),
        '')
$f$;

CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_publish(p_tenant text, p_bus text, p_kind text, p_subject text, p_payload jsonb)
RETURNS bigint LANGUAGE sql AS $f$
    SELECT core_platform.cp_event_publish(p_tenant, p_bus, 'mystoreguard', p_kind, p_subject,
                                          jsonb_build_object('version', 1, 'app', 'mystoreguard') || p_payload)
$f$;

-- What a sale comes to, line by line: gross (what the customer pays, tax included, after
-- pricing rules and promo), each tax, net, and the cost of the batches actually deducted.
-- taxes_applied[].amount is the tax on ONE unit (against final_price), so a line's tax is
-- line_total * amount / final_price. (The line's tax_amount is per unit x quantity since
-- tvs-mystoreguard-bk 71ae82c; it is not read here.)
CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_sale_figures(p_tenant text, p_org text, p_bus text, p_loc text, p_sale text)
RETURNS jsonb LANGUAGE sql STABLE AS $f$
WITH s AS (
    SELECT * FROM mystoreguard.msg_sales
     WHERE tenant_id = p_tenant AND org_id = p_org AND bus_id = p_bus AND loc_id = p_loc AND id = p_sale
), it AS (
    SELECT i.id, i.product_id, i.product_name, coalesce(i.quantity, 0) AS quantity,
           round(coalesce(i.line_total, 0), 2) AS gross, coalesce(i.final_price, 0) AS fp,
           CASE WHEN jsonb_typeof(i.taxes_applied) = 'array' THEN i.taxes_applied ELSE '[]'::jsonb END AS taxes,
           i.line_cost, mystoreguard.msg_acc_currency(i.tenant_id, i.cost_currency_id) AS cost_currency,
           i.cost_currency_id, i.cdatetime
      FROM mystoreguard.msg_sales_items i
     WHERE i.tenant_id = p_tenant AND i.org_id = p_org AND i.bus_id = p_bus AND i.loc_id = p_loc AND i.sale_id = p_sale
), tx AS (
    SELECT it.id AS item_id, coalesce(nullif(t ->> 'tax_id', ''), 'tax') AS tax_id,
           coalesce(nullif(t ->> 'tax_name', ''), 'Tax') AS tax_name,
           CASE WHEN it.fp > 0 THEN round(it.gross * coalesce(nullif(t ->> 'amount', '')::numeric, 0) / it.fp, 2) ELSE 0 END AS amount
      FROM it, jsonb_array_elements(it.taxes) t
), lt AS (
    SELECT it.*, coalesce((SELECT sum(amount) FROM tx WHERE tx.item_id = it.id), 0) AS tax
      FROM it
), sale_currency AS (
    SELECT mystoreguard.msg_acc_currency(p_tenant) AS code
), plan AS (
    -- An instalment plan's charge as agreed (the sale's own column is reduced by an early
    -- settlement), and the early-settlement discounts given (SETTLEMENT_DISCOUNT allocations;
    -- a return's credit is the return's business, not this).
    SELECT pl.finance_charge,
           (SELECT coalesce(sum(a.amount), 0) FROM mystoreguard.msg_installment_allocations a
             WHERE a.tenant_id = pl.tenant_id AND a.org_id = pl.org_id AND a.bus_id = pl.bus_id AND a.loc_id = pl.loc_id
               AND a.plan_id = pl.id AND a.allocation_type = 'SETTLEMENT_DISCOUNT') AS settlement_discount
      FROM mystoreguard.msg_installment_plans pl
     WHERE pl.tenant_id = p_tenant AND pl.org_id = p_org AND pl.bus_id = p_bus AND pl.loc_id = p_loc AND pl.sale_id = p_sale
     LIMIT 1
)
SELECT jsonb_build_object(
    'gross', mystoreguard.msg_acc_money((SELECT sum(gross) FROM lt)),
    'tax', mystoreguard.msg_acc_money((SELECT sum(tax) FROM lt)),
    'net', mystoreguard.msg_acc_money((SELECT sum(gross - tax) FROM lt)),
    'promo_discount', mystoreguard.msg_acc_money((SELECT promo_discount_amount FROM s)),
    'finance_charge', mystoreguard.msg_acc_money(coalesce((SELECT finance_charge FROM plan), (SELECT finance_charge_amount FROM s))),
    'settlement_discount', mystoreguard.msg_acc_money((SELECT settlement_discount FROM plan)),
    'taxes', coalesce((SELECT jsonb_agg(jsonb_build_object(
                  'tax_id', g.tax_id, 'name', g.tax_name,
                  'short_name', (SELECT r.short_name FROM core_platform.cp_tax_rates r WHERE r.id = g.tax_id AND r.tenant_id = p_tenant LIMIT 1),
                  'amount', mystoreguard.msg_acc_money(g.amount)) ORDER BY g.tax_id)
               FROM (SELECT tax_id, min(tax_name) AS tax_name, sum(amount) AS amount FROM tx GROUP BY tax_id HAVING sum(amount) <> 0) g), '[]'::jsonb),
    'costs', coalesce((SELECT jsonb_agg(jsonb_build_object(
                  'currency', CASE WHEN c.cost_currency = '' THEN (SELECT code FROM sale_currency) ELSE c.cost_currency END,
                  'amount', mystoreguard.msg_acc_money(c.amount)) ORDER BY c.cost_currency)
               FROM (SELECT cost_currency, sum(line_cost) AS amount FROM lt WHERE line_cost IS NOT NULL GROUP BY cost_currency HAVING sum(line_cost) <> 0) c), '[]'::jsonb),
    'cost_missing_lines', (SELECT count(*) FROM lt WHERE line_cost IS NULL AND quantity > 0),
    'lines', coalesce((SELECT jsonb_agg(jsonb_build_object(
                  'item_id', lt.id, 'product_id', lt.product_id, 'product_name', lt.product_name,
                  'quantity', lt.quantity::text,
                  'gross', mystoreguard.msg_acc_money(lt.gross), 'tax', mystoreguard.msg_acc_money(lt.tax),
                  'net', mystoreguard.msg_acc_money(lt.gross - lt.tax),
                  'taxes', coalesce((SELECT jsonb_agg(jsonb_build_object('tax_id', tx.tax_id, 'name', tx.tax_name, 'amount', mystoreguard.msg_acc_money(tx.amount)))
                                       FROM tx WHERE tx.item_id = lt.id), '[]'::jsonb),
                  'cost', CASE WHEN lt.line_cost IS NULL THEN NULL ELSE mystoreguard.msg_acc_money(lt.line_cost) END,
                  'cost_currency', CASE WHEN lt.line_cost IS NULL THEN NULL WHEN lt.cost_currency = '' THEN (SELECT code FROM sale_currency) ELSE lt.cost_currency END)
                  ORDER BY lt.cdatetime, lt.id) FROM lt), '[]'::jsonb)
)
$f$;

-- What a change must alter for a released sale to be restated: the amounts that post, never
-- names or labels (a tax renamed in Core Platform is not a new sale). A key missing from
-- figures stored earlier counts as zero, so adding a figure here restates nothing.
CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_fingerprint(f jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE AS $f$
    SELECT CASE WHEN f IS NULL THEN NULL ELSE jsonb_build_object(
        'gross', coalesce(f ->> 'gross', '0.00'), 'net', coalesce(f ->> 'net', '0.00'), 'tax', coalesce(f ->> 'tax', '0.00'),
        'promo_discount', coalesce(f ->> 'promo_discount', '0.00'),
        'finance_charge', coalesce(f ->> 'finance_charge', '0.00'),
        'settlement_discount', coalesce(f ->> 'settlement_discount', '0.00'),
        'taxes', coalesce((SELECT jsonb_object_agg(t ->> 'tax_id', t ->> 'amount') FROM jsonb_array_elements(f -> 'taxes') t), '{}'::jsonb),
        'costs', coalesce((SELECT jsonb_object_agg(c ->> 'currency', c ->> 'amount') FROM jsonb_array_elements(f -> 'costs') c), '{}'::jsonb))
    END
$f$;

-- The facts every sale event repeats: who, where, which document.
CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_sale_header(p_sale mystoreguard.msg_sales) RETURNS jsonb
LANGUAGE sql STABLE AS $f$
    SELECT jsonb_build_object(
        'org_id', p_sale.org_id, 'loc_id', p_sale.loc_id,
        'location_name', (SELECT l.loc_name FROM core_platform.cp_locations l WHERE l.id = p_sale.loc_id AND l.tenant_id = p_sale.tenant_id LIMIT 1),
        'sale_id', p_sale.id, 'sale_number', p_sale.sale_number, 'sale_mode', p_sale.sale_mode,
        'customer_id', p_sale.customer_id,
        'customer_name', (SELECT c.fullname FROM mystoreguard.msg_customers c
                           WHERE c.id = p_sale.customer_id AND c.tenant_id = p_sale.tenant_id LIMIT 1),
        'currency', mystoreguard.msg_acc_currency(p_sale.tenant_id),
        'document_type', 'SALE', 'document_number', p_sale.sale_number, 'document_id', p_sale.id)
$f$;

-- ===================================================================== sales and their payments
CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_sync_sale(p_tenant text, p_org text, p_bus text, p_loc text, p_sale text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
    s mystoreguard.msg_sales;
    st mystoreguard.msg_acc_sale_state;
    found_sale boolean;
    now_recognised boolean;
    fig jsonb;
    ps record;
    p record;
    eff boolean;
    head jsonb;
    today date := mystoreguard.msg_acc_day(p_tenant, now());
    created_now boolean;
    folded jsonb := '[]'::jsonb;
    folded_total numeric := 0;
    folded_cash numeric := 0;
    deposits numeric;
    change_issued numeric := 0;
    change_given numeric := 0;
    receivable numeric;
    gross numeric;
    finance numeric;
    pen numeric;
    restocked boolean;
    rev integer;
    sale_date date;
BEGIN
    SELECT * INTO s FROM mystoreguard.msg_sales
     WHERE tenant_id = p_tenant AND org_id = p_org AND bus_id = p_bus AND loc_id = p_loc AND id = p_sale;
    found_sale := FOUND;

    SELECT * INTO st FROM mystoreguard.msg_acc_sale_state WHERE sale_id = p_sale FOR UPDATE;
    IF NOT FOUND THEN
        IF NOT found_sale THEN RETURN; END IF;
        INSERT INTO mystoreguard.msg_acc_sale_state (sale_id, tenant_id, bus_id, created_txid)
        VALUES (p_sale, p_tenant, p_bus, pg_current_xact_id())
        RETURNING * INTO st;
    END IF;
    created_now := st.created_txid IS NOT DISTINCT FROM pg_current_xact_id();

    IF found_sale THEN
        head := mystoreguard.msg_acc_sale_header(s);
    ELSE
        head := coalesce(st.figures -> 'header', '{}'::jsonb);
    END IF;
    head := head || jsonb_build_object('org_id', p_org, 'loc_id', p_loc);

    now_recognised := found_sale AND s.status IS DISTINCT FROM 'CANCELLED' AND s.fulfillment_status = 'FULFILLED';
    IF now_recognised THEN
        fig := mystoreguard.msg_acc_sale_figures(p_tenant, p_org, p_bus, p_loc, p_sale);
    END IF;

    -- 1. Published payments that no longer stand (refunded, deleted, reduced, or a gift card /
    --    loyalty tender cancel_sale put back): reverse them where they sit in the books.
    FOR ps IN SELECT * FROM mystoreguard.msg_acc_payment_state WHERE source = 'SALE' AND doc_id = p_sale ORDER BY payment_id LOOP
        SELECT * INTO p FROM mystoreguard.msg_sales_payments
         WHERE tenant_id = p_tenant AND org_id = p_org AND bus_id = p_bus AND loc_id = p_loc AND id = ps.payment_id;
        eff := FOUND AND found_sale AND p.payment_status = 'SUCCESS' AND p.deleted_at IS NULL
               AND NOT (s.status = 'CANCELLED' AND p.payment_method IN ('GIFT_CARD', 'LOYALTY_POINTS'))
               AND round(p.paid_amount, 2) = ps.amount AND p.payment_method = ps.method;
        IF NOT eff THEN
            PERFORM mystoreguard.msg_acc_publish(p_tenant, p_bus, 'msg.payment_reversed', ps.payment_id, head || jsonb_build_object(
                'date', today, 'payment_id', ps.payment_id, 'method', ps.method,
                'amount', mystoreguard.msg_acc_money(ps.amount), 'penalty', mystoreguard.msg_acc_money(ps.penalty),
                'applied', ps.applied,
                'reason', CASE WHEN NOT found_sale THEN 'SALE_DELETED' WHEN p.id IS NULL THEN 'DELETED'
                               WHEN p.payment_status = 'REFUNDED' THEN 'REFUNDED'
                               WHEN s.status = 'CANCELLED' THEN 'TENDER_RESTORED' ELSE 'CHANGED' END));
            DELETE FROM mystoreguard.msg_acc_payment_state WHERE payment_id = ps.payment_id;
        END IF;
    END LOOP;

    -- 2. A released sale cancelled, deleted, or whose figures changed: void what was published.
    IF st.recognised AND (NOT now_recognised
                          OR mystoreguard.msg_acc_fingerprint(fig) IS DISTINCT FROM mystoreguard.msg_acc_fingerprint(st.figures)) THEN
        restocked := found_sale AND s.status = 'CANCELLED' AND EXISTS (
            SELECT 1 FROM mystoreguard.msg_product_movements m
             WHERE m.tenant_id = p_tenant AND m.org_id = p_org AND m.bus_id = p_bus AND m.reference_id = p_sale
               AND m.movement_type = 'IN');
        PERFORM mystoreguard.msg_acc_publish(p_tenant, p_bus, 'msg.sale_voided', p_sale, head || jsonb_build_object(
            'date', CASE WHEN created_now AND found_sale THEN s.sale_date ELSE today END,
            'revision', st.revision,
            'reason', CASE WHEN NOT found_sale THEN 'DELETED' WHEN s.status = 'CANCELLED' THEN 'CANCELLED'
                           WHEN NOT now_recognised THEN 'UNRELEASED' ELSE 'CHANGED' END,
            'restocked', CASE WHEN found_sale AND now_recognised THEN true ELSE coalesce(restocked, false) END,
            'figures', st.figures - 'header'));
        UPDATE mystoreguard.msg_acc_sale_state SET recognised = false, updated_at = now() WHERE sale_id = p_sale;
        st.recognised := false;
    END IF;

    -- 3. Payments not yet published.
    IF found_sale THEN
        FOR p IN SELECT sp.* FROM mystoreguard.msg_sales_payments sp
                  WHERE sp.tenant_id = p_tenant AND sp.org_id = p_org AND sp.bus_id = p_bus AND sp.loc_id = p_loc AND sp.sale_id = p_sale
                    AND sp.payment_status = 'SUCCESS' AND sp.deleted_at IS NULL
                    AND NOT (s.status = 'CANCELLED' AND sp.payment_method IN ('GIFT_CARD', 'LOYALTY_POINTS'))
                    AND NOT EXISTS (SELECT 1 FROM mystoreguard.msg_acc_payment_state x WHERE x.payment_id = sp.id)
                  ORDER BY sp.cdatetime, sp.id LOOP
            SELECT coalesce(sum(a.amount), 0) INTO pen FROM mystoreguard.msg_installment_allocations a
             WHERE a.tenant_id = p_tenant AND a.org_id = p_org AND a.bus_id = p_bus AND a.loc_id = p_loc
               AND a.payment_id = p.id AND a.allocation_type = 'PENALTY';
            pen := least(round(pen, 2), round(p.paid_amount, 2));
            IF now_recognised AND NOT st.recognised THEN
                -- Folded into the sale's own event below.
                folded := folded || jsonb_build_array(jsonb_build_object(
                    'payment_id', p.id, 'method', p.payment_method, 'amount', mystoreguard.msg_acc_money(p.paid_amount),
                    'penalty', mystoreguard.msg_acc_money(pen), 'gift_card_id', p.gift_card_id,
                    'reference', p.online_payment_reference));
                folded_total := folded_total + round(p.paid_amount, 2) - pen;
                IF p.payment_method = 'CASH' THEN folded_cash := folded_cash + round(p.paid_amount, 2); END IF;
                INSERT INTO mystoreguard.msg_acc_payment_state (payment_id, source, doc_id, tenant_id, bus_id, method, amount, penalty, applied)
                VALUES (p.id, 'SALE', p_sale, p_tenant, p_bus, p.payment_method, round(p.paid_amount, 2), pen, 'RECEIVABLE');
            ELSE
                PERFORM mystoreguard.msg_acc_publish(p_tenant, p_bus, 'msg.payment_received', p.id, head || jsonb_build_object(
                    'date', mystoreguard.msg_acc_day(p_tenant, p.cdatetime),
                    'payment_id', p.id, 'method', p.payment_method, 'amount', mystoreguard.msg_acc_money(p.paid_amount),
                    'penalty', mystoreguard.msg_acc_money(pen), 'gift_card_id', p.gift_card_id,
                    'reference', p.online_payment_reference,
                    'applied', CASE WHEN st.recognised THEN 'RECEIVABLE' ELSE 'DEPOSIT' END));
                INSERT INTO mystoreguard.msg_acc_payment_state (payment_id, source, doc_id, tenant_id, bus_id, method, amount, penalty, applied)
                VALUES (p.id, 'SALE', p_sale, p_tenant, p_bus, p.payment_method, round(p.paid_amount, 2), pen,
                        CASE WHEN st.recognised THEN 'RECEIVABLE' ELSE 'DEPOSIT' END);
            END IF;
        END LOOP;
    END IF;

    -- 4. Goods released (again): the sale's own event.
    IF now_recognised AND NOT st.recognised THEN
        rev := st.revision + 1;
        SELECT coalesce(sum(amount - penalty), 0) INTO deposits FROM mystoreguard.msg_acc_payment_state
         WHERE source = 'SALE' AND doc_id = p_sale AND applied = 'DEPOSIT';
        UPDATE mystoreguard.msg_acc_payment_state SET applied = 'RECEIVABLE', updated_at = now()
         WHERE source = 'SALE' AND doc_id = p_sale AND applied = 'DEPOSIT';
        gross := (fig ->> 'gross')::numeric;
        finance := (fig ->> 'finance_charge')::numeric - (fig ->> 'settlement_discount')::numeric;
        IF rev = 1 THEN change_issued := round(coalesce(s.store_credit_change_issued, 0), 2); END IF;
        receivable := gross + finance - deposits - folded_total + change_issued;
        -- Cash handed back as change, where the till recorded what was tendered.
        IF receivable < 0 AND folded_cash > 0 THEN
            change_given := least(-receivable, folded_cash);
            receivable := receivable + change_given;
        END IF;
        sale_date := CASE WHEN created_now THEN s.sale_date
                          ELSE mystoreguard.msg_acc_day(p_tenant, coalesce(s.fulfillment_date_time, now())) END;
        PERFORM mystoreguard.msg_acc_publish(p_tenant, p_bus, 'msg.sale_completed', p_sale, head || jsonb_build_object(
            'date', sale_date, 'revision', rev, 'status', s.status,
            'figures', fig,
            'payments', folded,
            'deposits_applied', mystoreguard.msg_acc_money(deposits),
            'store_credit_change_issued', mystoreguard.msg_acc_money(change_issued),
            'change_given', mystoreguard.msg_acc_money(change_given),
            'receivable', mystoreguard.msg_acc_money(receivable)));
        UPDATE mystoreguard.msg_acc_sale_state
           SET recognised = true, revision = rev, figures = fig || jsonb_build_object('header', head), updated_at = now()
         WHERE sale_id = p_sale;
    END IF;

    IF NOT found_sale THEN
        DELETE FROM mystoreguard.msg_acc_sale_state WHERE sale_id = p_sale;
    END IF;
END
$f$;

-- Invoice payments taken before any stock left (msg_invoice_payments): customer deposits.
-- At fulfilment MyStoreGuard copies them onto the new sale and soft-deletes these, so the
-- deposit is reversed here and the copies are received with the sale.
CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_sync_invoice_payment(p_tenant text, p_org text, p_bus text, p_loc text, p_payment text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE p record; ps mystoreguard.msg_acc_payment_state; inv record; eff boolean; head jsonb;
BEGIN
    SELECT * INTO p FROM mystoreguard.msg_invoice_payments
     WHERE tenant_id = p_tenant AND org_id = p_org AND bus_id = p_bus AND loc_id = p_loc AND id = p_payment;
    eff := FOUND AND p.payment_status = 'SUCCESS' AND p.deleted_at IS NULL;
    SELECT * INTO ps FROM mystoreguard.msg_acc_payment_state WHERE payment_id = p_payment FOR UPDATE;
    IF eff AND ps.payment_id IS NOT NULL AND ps.amount = round(p.paid_amount, 2) AND ps.method = p.payment_method THEN
        RETURN;
    END IF;
    SELECT i.id, i.invoice_number, i.customer_id INTO inv FROM mystoreguard.msg_invoices i
     WHERE i.tenant_id = p_tenant AND i.org_id = p_org AND i.bus_id = p_bus AND i.id = coalesce(p.invoice_id, ps.doc_id) LIMIT 1;
    head := jsonb_build_object('org_id', p_org, 'loc_id', p_loc, 'currency', mystoreguard.msg_acc_currency(p_tenant),
        'invoice_id', inv.id, 'customer_id', inv.customer_id,
        'customer_name', (SELECT c.fullname FROM mystoreguard.msg_customers c WHERE c.id = inv.customer_id AND c.tenant_id = p_tenant LIMIT 1),
        'document_type', 'INVOICE', 'document_number', inv.invoice_number, 'document_id', inv.id);
    IF ps.payment_id IS NOT NULL THEN
        PERFORM mystoreguard.msg_acc_publish(p_tenant, p_bus, 'msg.payment_reversed', p_payment, head || jsonb_build_object(
            'date', mystoreguard.msg_acc_day(p_tenant, now()), 'payment_id', p_payment, 'method', ps.method,
            'amount', mystoreguard.msg_acc_money(ps.amount), 'penalty', '0.00', 'applied', 'DEPOSIT',
            'reason', CASE WHEN p.id IS NULL THEN 'DELETED' WHEN p.deleted_at IS NOT NULL THEN 'MOVED_TO_SALE' ELSE 'CHANGED' END));
        DELETE FROM mystoreguard.msg_acc_payment_state WHERE payment_id = p_payment;
    END IF;
    IF eff THEN
        PERFORM mystoreguard.msg_acc_publish(p_tenant, p_bus, 'msg.payment_received', p_payment, head || jsonb_build_object(
            'date', mystoreguard.msg_acc_day(p_tenant, p.cdatetime), 'payment_id', p_payment, 'method', p.payment_method,
            'amount', mystoreguard.msg_acc_money(p.paid_amount), 'penalty', '0.00', 'applied', 'DEPOSIT',
            'reference', p.online_payment_reference));
        INSERT INTO mystoreguard.msg_acc_payment_state (payment_id, source, doc_id, tenant_id, bus_id, method, amount, penalty, applied)
        VALUES (p_payment, 'INVOICE', p.invoice_id, p_tenant, p_bus, p.payment_method, round(p.paid_amount, 2), 0, 'DEPOSIT');
    END IF;
END
$f$;

-- ===================================================================== returns
CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_sync_return(p_tenant text, p_org text, p_bus text, p_loc text, p_return text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
    r mystoreguard.msg_returns; s mystoreguard.msg_sales;
    v_lines jsonb; v_taxes jsonb; v_costs jsonb;
    v_net numeric; v_tax numeric; v_fee numeric; v_total numeric;
    v_store_credit numeric; v_cash numeric; v_trade_in numeric := 0; v_settled numeric := 0; v_written_off numeric := 0; v_owed numeric := 0;
    v_residual numeric; v_method text;
BEGIN
    SELECT * INTO r FROM mystoreguard.msg_returns
     WHERE tenant_id = p_tenant AND org_id = p_org AND bus_id = p_bus AND loc_id = p_loc AND id = p_return;
    IF NOT FOUND OR r.status IS DISTINCT FROM 'COMPLETED' THEN RETURN; END IF;
    IF EXISTS (SELECT 1 FROM mystoreguard.msg_acc_document_state WHERE kind = 'RETURN' AND doc_id = p_return) THEN RETURN; END IF;
    SELECT * INTO s FROM mystoreguard.msg_sales
     WHERE tenant_id = p_tenant AND org_id = p_org AND bus_id = p_bus AND id = r.sale_id LIMIT 1;

    WITH ri AS (
        SELECT ri.id, ri.product_id, ri.quantity_returned AS qty, round(coalesce(ri.line_refund_amount, 0), 2) AS gross,
               coalesce(ri.restock, false) AND coalesce(upper(ri.condition), 'RESALABLE') = 'RESALABLE' AS restocked,
               si.product_name, coalesce(si.final_price, 0) AS fp, si.cost_price,
               CASE WHEN jsonb_typeof(si.taxes_applied) = 'array' THEN si.taxes_applied ELSE '[]'::jsonb END AS taxes,
               mystoreguard.msg_acc_currency(p_tenant, si.cost_currency_id) AS cost_currency
          FROM mystoreguard.msg_return_items ri
          LEFT JOIN mystoreguard.msg_sales_items si
            ON si.tenant_id = ri.tenant_id AND si.org_id = ri.org_id AND si.bus_id = ri.bus_id AND si.id = ri.sale_item_id
         WHERE ri.tenant_id = p_tenant AND ri.org_id = p_org AND ri.bus_id = p_bus AND ri.loc_id = p_loc AND ri.return_id = p_return
    ), tx AS (
        SELECT ri.id AS item_id, coalesce(nullif(t ->> 'tax_id', ''), 'tax') AS tax_id, coalesce(nullif(t ->> 'tax_name', ''), 'Tax') AS tax_name,
               CASE WHEN ri.fp > 0 THEN round(ri.gross * coalesce(nullif(t ->> 'amount', '')::numeric, 0) / ri.fp, 2) ELSE 0 END AS amount
          FROM ri, jsonb_array_elements(ri.taxes) t
    ), lt AS (
        SELECT ri.*, coalesce((SELECT sum(amount) FROM tx WHERE tx.item_id = ri.id), 0) AS tax,
               CASE WHEN ri.restocked AND ri.cost_price IS NOT NULL THEN round(ri.cost_price * ri.qty, 2) END AS restock_cost
          FROM ri
    )
    SELECT coalesce(sum(gross - tax), 0), coalesce(sum(tax), 0),
           coalesce(jsonb_agg(jsonb_build_object('return_item_id', id, 'product_id', product_id, 'product_name', product_name,
                    'quantity', qty::text, 'gross', mystoreguard.msg_acc_money(gross), 'tax', mystoreguard.msg_acc_money(tax),
                    'net', mystoreguard.msg_acc_money(gross - tax), 'restocked', restocked,
                    'restock_cost', CASE WHEN restock_cost IS NULL THEN NULL ELSE mystoreguard.msg_acc_money(restock_cost) END,
                    'cost_currency', CASE WHEN restock_cost IS NULL THEN NULL WHEN cost_currency = '' THEN mystoreguard.msg_acc_currency(p_tenant) ELSE cost_currency END)), '[]'::jsonb),
           coalesce((SELECT jsonb_agg(jsonb_build_object('tax_id', g.tax_id, 'name', g.tax_name, 'amount', mystoreguard.msg_acc_money(g.amount)) ORDER BY g.tax_id)
                       FROM (SELECT tax_id, min(tax_name) AS tax_name, sum(amount) AS amount FROM tx GROUP BY tax_id HAVING sum(amount) <> 0) g), '[]'::jsonb),
           coalesce((SELECT jsonb_agg(jsonb_build_object('currency', CASE WHEN c.cost_currency = '' THEN mystoreguard.msg_acc_currency(p_tenant) ELSE c.cost_currency END,
                                                         'amount', mystoreguard.msg_acc_money(c.amount)))
                       FROM (SELECT cost_currency, sum(restock_cost) AS amount FROM lt WHERE restock_cost IS NOT NULL GROUP BY cost_currency) c), '[]'::jsonb)
      INTO v_net, v_tax, v_lines, v_taxes, v_costs
      FROM lt;

    v_fee := round(coalesce(r.restocking_fee_amount, 0), 2);
    v_total := v_net + v_tax - v_fee;
    v_store_credit := round(coalesce(r.store_credit_issued_amount, 0), 2);
    IF r.installment_plan_id IS NOT NULL THEN
        v_settled := round(coalesce(r.plan_settled_amount, 0), 2);
        v_written_off := round(coalesce(r.plan_written_off_amount, 0), 2);
        -- Cash the plan owes back is handed over later (msg.plan_refund_paid); until then the customer is in credit.
        v_owed := greatest(round(coalesce(r.cash_refund_amount, 0), 2) - v_store_credit, 0);
        v_cash := 0;
    ELSE
        v_cash := greatest(round(coalesce(r.cash_refund_amount, 0), 2) - v_store_credit, 0);
    END IF;
    -- Traded in against a new sale (exchange_to_sale): the credit pays for that sale as an
    -- 'OTHERS' payment, so it is not cash leaving the till.
    IF EXISTS (SELECT 1 FROM mystoreguard.msg_sales x WHERE x.tenant_id = p_tenant AND x.org_id = p_org AND x.bus_id = p_bus
                AND x.exchanged_from_return_id = p_return) THEN
        v_trade_in := v_cash + v_owed; v_cash := 0; v_owed := 0;
    END IF;
    v_residual := v_total - v_settled - v_store_credit - v_cash - v_trade_in - v_owed;
    v_method := CASE upper(coalesce(r.refund_method, 'CASH'))
        WHEN 'ORIGINAL_PAYMENT' THEN coalesce((SELECT sp.payment_method FROM mystoreguard.msg_sales_payments sp
                                                 WHERE sp.tenant_id = p_tenant AND sp.org_id = p_org AND sp.bus_id = p_bus AND sp.sale_id = r.sale_id
                                                   AND sp.payment_status = 'SUCCESS' AND sp.payment_method NOT IN ('GIFT_CARD', 'STORE_CREDIT', 'LOYALTY_POINTS')
                                                 ORDER BY sp.paid_amount DESC LIMIT 1), 'CASH')
        ELSE 'CASH' END;

    PERFORM mystoreguard.msg_acc_publish(p_tenant, p_bus, 'msg.return_processed', p_return, jsonb_build_object(
        'org_id', p_org, 'loc_id', p_loc,
        'location_name', (SELECT l.loc_name FROM core_platform.cp_locations l WHERE l.id = p_loc AND l.tenant_id = p_tenant LIMIT 1),
        'currency', mystoreguard.msg_acc_currency(p_tenant),
        'date', mystoreguard.msg_acc_day(p_tenant, coalesce(r.processed_at, now())),
        'document_type', 'RETURN', 'document_number', r.return_number, 'document_id', r.id,
        'return_id', r.id, 'return_number', r.return_number, 'return_type', r.return_type, 'refund_method', r.refund_method,
        'sale_id', r.sale_id, 'sale_number', s.sale_number, 'customer_id', r.customer_id,
        'customer_name', (SELECT c.fullname FROM mystoreguard.msg_customers c WHERE c.id = r.customer_id AND c.tenant_id = p_tenant LIMIT 1),
        'lines', v_lines, 'taxes', v_taxes, 'restock_costs', v_costs,
        'net', mystoreguard.msg_acc_money(v_net), 'tax', mystoreguard.msg_acc_money(v_tax),
        'restocking_fee', mystoreguard.msg_acc_money(v_fee), 'total_refund', mystoreguard.msg_acc_money(v_total),
        'refund', jsonb_build_object(
            'cash', mystoreguard.msg_acc_money(v_cash), 'cash_method', v_method,
            'store_credit', mystoreguard.msg_acc_money(v_store_credit),
            'trade_in', mystoreguard.msg_acc_money(v_trade_in),
            'plan_settled', mystoreguard.msg_acc_money(v_settled),
            'plan_written_off', mystoreguard.msg_acc_money(v_written_off),
            'owed_to_customer', mystoreguard.msg_acc_money(v_owed),
            'against_balance', mystoreguard.msg_acc_money(v_residual))));
    INSERT INTO mystoreguard.msg_acc_document_state (kind, doc_id, tenant_id) VALUES ('RETURN', p_return, p_tenant)
    ON CONFLICT DO NOTHING;
END
$f$;

-- ===================================================================== gift cards and plan refunds
CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_sync_gift_card(p_tenant text, p_org text, p_bus text, p_card text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE g mystoreguard.msg_gift_cards; sold boolean;
BEGIN
    IF EXISTS (SELECT 1 FROM mystoreguard.msg_acc_document_state WHERE kind = 'GIFT_CARD' AND doc_id = p_card) THEN RETURN; END IF;
    SELECT * INTO g FROM mystoreguard.msg_gift_cards WHERE tenant_id = p_tenant AND org_id = p_org AND bus_id = p_bus AND id = p_card;
    IF NOT FOUND OR coalesce(g.initial_value, 0) <= 0 THEN RETURN; END IF;
    -- Sold over the counter (create_gift_card writes a PURCHASE transaction); a customer-segment
    -- reward card has none.
    sold := EXISTS (SELECT 1 FROM mystoreguard.msg_gift_card_transactions t
                     WHERE t.tenant_id = p_tenant AND t.org_id = p_org AND t.bus_id = p_bus AND t.gift_card_id = p_card
                       AND t.transaction_type = 'PURCHASE');
    PERFORM mystoreguard.msg_acc_publish(p_tenant, p_bus, 'msg.gift_card_issued', p_card, jsonb_build_object(
        'org_id', p_org, 'currency', mystoreguard.msg_acc_currency(p_tenant, g.currency_id),
        'date', mystoreguard.msg_acc_day(p_tenant, g.cdatetime),
        'document_type', 'GIFT_CARD', 'document_number', 'GC-' || right(g.gift_card_code, 4), 'document_id', g.id,
        'gift_card_id', g.id, 'amount', mystoreguard.msg_acc_money(g.initial_value),
        'issued_as', CASE WHEN sold THEN 'SOLD' ELSE 'REWARD' END,
        -- MyStoreGuard records no tender for a gift card it sells; the till takes cash.
        'method', CASE WHEN sold THEN 'CASH' END,
        'customer_id', g.purchased_by_customer_id,
        'customer_name', (SELECT c.fullname FROM mystoreguard.msg_customers c WHERE c.id = g.purchased_by_customer_id AND c.tenant_id = p_tenant LIMIT 1)));
    INSERT INTO mystoreguard.msg_acc_document_state (kind, doc_id, tenant_id) VALUES ('GIFT_CARD', p_card, p_tenant) ON CONFLICT DO NOTHING;
END
$f$;

CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_sync_plan(p_tenant text, p_org text, p_bus text, p_loc text, p_plan text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE pl mystoreguard.msg_installment_plans; s mystoreguard.msg_sales; recognised boolean;
BEGIN
    SELECT * INTO pl FROM mystoreguard.msg_installment_plans
     WHERE tenant_id = p_tenant AND org_id = p_org AND bus_id = p_bus AND loc_id = p_loc AND id = p_plan;
    IF NOT FOUND OR pl.refund_status IS DISTINCT FROM 'RETURNED' OR coalesce(pl.refund_amount, 0) <= 0 THEN RETURN; END IF;
    IF EXISTS (SELECT 1 FROM mystoreguard.msg_acc_document_state WHERE kind = 'PLAN_REFUND' AND doc_id = p_plan) THEN RETURN; END IF;
    SELECT * INTO s FROM mystoreguard.msg_sales
     WHERE tenant_id = p_tenant AND org_id = p_org AND bus_id = p_bus AND loc_id = p_loc AND id = pl.sale_id;
    -- Owed after release (a return) it sits in the customer's balance; owed for goods never
    -- released (a rejected plan) it is still a deposit.
    recognised := coalesce((SELECT st.revision > 0 FROM mystoreguard.msg_acc_sale_state st WHERE st.sale_id = pl.sale_id), false);
    PERFORM mystoreguard.msg_acc_publish(p_tenant, p_bus, 'msg.plan_refund_paid', p_plan,
        (CASE WHEN s.id IS NOT NULL THEN mystoreguard.msg_acc_sale_header(s) ELSE '{}'::jsonb END) || jsonb_build_object(
        'org_id', p_org, 'loc_id', p_loc, 'currency', mystoreguard.msg_acc_currency(p_tenant),
        'date', mystoreguard.msg_acc_day(p_tenant, coalesce(pl.refund_closed_at, now())),
        'plan_id', pl.id, 'amount', mystoreguard.msg_acc_money(pl.refund_amount), 'method', 'CASH',
        'applied', CASE WHEN recognised THEN 'RECEIVABLE' ELSE 'DEPOSIT' END, 'note', pl.refund_note));
    INSERT INTO mystoreguard.msg_acc_document_state (kind, doc_id, tenant_id) VALUES ('PLAN_REFUND', p_plan, p_tenant) ON CONFLICT DO NOTHING;
END
$f$;

-- ===================================================================== fail open, loudly
CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_run(p_kind text, p_tenant text, p_org text, p_bus text, p_loc text, p_id text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE msg text; flag text;
BEGIN
    IF p_id IS NULL OR p_tenant IS NULL THEN RETURN; END IF;
    BEGIN
        CASE p_kind
            WHEN 'SALE' THEN PERFORM mystoreguard.msg_acc_sync_sale(p_tenant, p_org, p_bus, p_loc, p_id);
            WHEN 'INVOICE_PAYMENT' THEN PERFORM mystoreguard.msg_acc_sync_invoice_payment(p_tenant, p_org, p_bus, p_loc, p_id);
            WHEN 'RETURN' THEN PERFORM mystoreguard.msg_acc_sync_return(p_tenant, p_org, p_bus, p_loc, p_id);
            WHEN 'GIFT_CARD' THEN PERFORM mystoreguard.msg_acc_sync_gift_card(p_tenant, p_org, p_bus, p_id);
            WHEN 'PLAN' THEN PERFORM mystoreguard.msg_acc_sync_plan(p_tenant, p_org, p_bus, p_loc, p_id);
        END CASE;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS msg = MESSAGE_TEXT;
        -- Once per document per transaction (the trigger fires for every row touched).
        flag := 'msg_acc.e' || md5(p_kind || p_id);
        IF coalesce(current_setting(flag, true), '') <> '1' THEN
            PERFORM set_config(flag, '1', true);
            PERFORM core_platform.cp_event_publish(p_tenant, p_bus, 'mystoreguard', 'msg.posting_error', p_id,
                jsonb_build_object('version', 1, 'app', 'mystoreguard', 'org_id', p_org, 'loc_id', p_loc,
                                   'document_type', p_kind, 'document_id', p_id, 'error', msg));
        END IF;
    END;
END
$f$;

CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_trigger() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE r record;
BEGIN
    r := CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
    CASE TG_TABLE_NAME
        WHEN 'msg_sales' THEN PERFORM mystoreguard.msg_acc_run('SALE', r.tenant_id, r.org_id, r.bus_id, r.loc_id, r.id);
        WHEN 'msg_sales_items', 'msg_sales_payments' THEN
            PERFORM mystoreguard.msg_acc_run('SALE', r.tenant_id, r.org_id, r.bus_id, r.loc_id, r.sale_id);
        WHEN 'msg_invoice_payments' THEN PERFORM mystoreguard.msg_acc_run('INVOICE_PAYMENT', r.tenant_id, r.org_id, r.bus_id, r.loc_id, r.id);
        WHEN 'msg_returns' THEN PERFORM mystoreguard.msg_acc_run('RETURN', r.tenant_id, r.org_id, r.bus_id, r.loc_id, r.id);
        WHEN 'msg_gift_cards' THEN PERFORM mystoreguard.msg_acc_run('GIFT_CARD', r.tenant_id, r.org_id, r.bus_id, NULL, r.id);
        WHEN 'msg_installment_plans' THEN PERFORM mystoreguard.msg_acc_run('PLAN', r.tenant_id, r.org_id, r.bus_id, r.loc_id, r.id);
    END CASE;
    RETURN NULL;
END
$f$;

-- Remembers which transaction made a sale, so a sale released as it is made is dated on its
-- own sale_date (which may be backdated) and one released later on the day it was released.
CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_sale_created() RETURNS trigger
LANGUAGE plpgsql AS $f$
BEGIN
    INSERT INTO mystoreguard.msg_acc_sale_state (sale_id, tenant_id, bus_id, created_txid)
    VALUES (NEW.id, NEW.tenant_id, NEW.bus_id, pg_current_xact_id())
    ON CONFLICT (sale_id) DO NOTHING;
    RETURN NULL;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END
$f$;

-- ===================================================================== baseline (first run only)
-- Everything that exists before this runs is history: record it as already published.
INSERT INTO mystoreguard.msg_acc_sale_state (sale_id, tenant_id, bus_id, recognised, revision, figures)
SELECT s.id, s.tenant_id, s.bus_id,
       s.status IS DISTINCT FROM 'CANCELLED' AND s.fulfillment_status = 'FULFILLED',
       CASE WHEN s.status IS DISTINCT FROM 'CANCELLED' AND s.fulfillment_status = 'FULFILLED' THEN 1 ELSE 0 END,
       CASE WHEN s.status IS DISTINCT FROM 'CANCELLED' AND s.fulfillment_status = 'FULFILLED'
            THEN mystoreguard.msg_acc_sale_figures(s.tenant_id, s.org_id, s.bus_id, s.loc_id, s.id)
                 || jsonb_build_object('header', mystoreguard.msg_acc_sale_header(s)) END
  FROM mystoreguard.msg_sales s
 WHERE NOT EXISTS (SELECT 1 FROM mystoreguard.msg_acc_sale_state x WHERE x.sale_id = s.id)
   AND NOT EXISTS (SELECT 1 FROM mystoreguard.msg_acc_document_state WHERE kind = 'BASELINE');

INSERT INTO mystoreguard.msg_acc_payment_state (payment_id, source, doc_id, tenant_id, bus_id, method, amount, penalty, applied)
SELECT sp.id, 'SALE', sp.sale_id, sp.tenant_id, sp.bus_id, sp.payment_method, round(sp.paid_amount, 2), 0,
       CASE WHEN s.status IS DISTINCT FROM 'CANCELLED' AND s.fulfillment_status = 'FULFILLED' THEN 'RECEIVABLE' ELSE 'DEPOSIT' END
  FROM mystoreguard.msg_sales_payments sp
  JOIN mystoreguard.msg_sales s ON s.tenant_id = sp.tenant_id AND s.org_id = sp.org_id AND s.bus_id = sp.bus_id AND s.loc_id = sp.loc_id AND s.id = sp.sale_id
 WHERE sp.payment_status = 'SUCCESS' AND sp.deleted_at IS NULL
   AND NOT (s.status = 'CANCELLED' AND sp.payment_method IN ('GIFT_CARD', 'LOYALTY_POINTS'))
   AND NOT EXISTS (SELECT 1 FROM mystoreguard.msg_acc_document_state WHERE kind = 'BASELINE')
ON CONFLICT DO NOTHING;

INSERT INTO mystoreguard.msg_acc_payment_state (payment_id, source, doc_id, tenant_id, bus_id, method, amount, penalty, applied)
SELECT ip.id, 'INVOICE', ip.invoice_id, ip.tenant_id, ip.bus_id, ip.payment_method, round(ip.paid_amount, 2), 0, 'DEPOSIT'
  FROM mystoreguard.msg_invoice_payments ip
 WHERE ip.payment_status = 'SUCCESS' AND ip.deleted_at IS NULL
   AND NOT EXISTS (SELECT 1 FROM mystoreguard.msg_acc_document_state WHERE kind = 'BASELINE')
ON CONFLICT DO NOTHING;

INSERT INTO mystoreguard.msg_acc_document_state (kind, doc_id, tenant_id)
SELECT 'RETURN', r.id, r.tenant_id FROM mystoreguard.msg_returns r
 WHERE r.status = 'COMPLETED' AND NOT EXISTS (SELECT 1 FROM mystoreguard.msg_acc_document_state WHERE kind = 'BASELINE')
UNION ALL
SELECT 'GIFT_CARD', g.id, g.tenant_id FROM mystoreguard.msg_gift_cards g
 WHERE NOT EXISTS (SELECT 1 FROM mystoreguard.msg_acc_document_state WHERE kind = 'BASELINE')
UNION ALL
SELECT 'PLAN_REFUND', p.id, p.tenant_id FROM mystoreguard.msg_installment_plans p
 WHERE p.refund_status = 'RETURNED' AND NOT EXISTS (SELECT 1 FROM mystoreguard.msg_acc_document_state WHERE kind = 'BASELINE')
ON CONFLICT DO NOTHING;

INSERT INTO mystoreguard.msg_acc_document_state (kind, doc_id, tenant_id, value)
VALUES ('BASELINE', 'msg', '', jsonb_build_object('at', now()))
ON CONFLICT DO NOTHING;

-- ===================================================================== the triggers
DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['msg_sales', 'msg_sales_items', 'msg_sales_payments', 'msg_invoice_payments', 'msg_returns',
                             'msg_gift_cards', 'msg_installment_plans'] LOOP
        IF to_regclass('mystoreguard.' || t) IS NULL THEN CONTINUE; END IF;
        EXECUTE format('DROP TRIGGER IF EXISTS msg_acc_event ON mystoreguard.%I', t);
        EXECUTE format(
            'CREATE CONSTRAINT TRIGGER msg_acc_event AFTER %s ON mystoreguard.%I DEFERRABLE INITIALLY DEFERRED
               FOR EACH ROW EXECUTE FUNCTION mystoreguard.msg_acc_trigger()',
            CASE t WHEN 'msg_gift_cards' THEN 'INSERT'
                   WHEN 'msg_returns' THEN 'INSERT OR UPDATE'
                   WHEN 'msg_installment_plans' THEN 'UPDATE'
                   ELSE 'INSERT OR UPDATE OR DELETE' END, t);
        -- Seeds and data fixes (session_replication_role = replica) are business changes too.
        EXECUTE format('ALTER TABLE mystoreguard.%I ENABLE ALWAYS TRIGGER msg_acc_event', t);
    END LOOP;
    DROP TRIGGER IF EXISTS msg_acc_sale_created ON mystoreguard.msg_sales;
    CREATE TRIGGER msg_acc_sale_created AFTER INSERT ON mystoreguard.msg_sales
        FOR EACH ROW EXECUTE FUNCTION mystoreguard.msg_acc_sale_created();
    ALTER TABLE mystoreguard.msg_sales ENABLE ALWAYS TRIGGER msg_acc_sale_created;
END $$;

COMMIT;
