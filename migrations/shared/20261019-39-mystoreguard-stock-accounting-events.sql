-- =====================================================================
-- MyStoreGuard tells the books about its STOCK: receipts, adjustments, suppliers
-- ---------------------------------------------------------------------
-- Roadmap Phase 1, step 1b (docs/POSTINGS.md §1b). 20261019-38 publishes sales, payments and
-- returns, whose cost of goods credits Inventory; nothing debited it, so a live test showed
-- Inventory at -60. This file publishes everything else that changes what the stock is worth,
-- with the same machinery as 38: deferred constraint triggers that run at COMMIT, compare
-- with what was last published (msg_acc_batch_state, msg_acc_document_state) and publish only
-- the difference, in the same transaction. A stock-in that fails rolls back and publishes
-- nothing. A trigger that cannot describe a document publishes 'msg.posting_error' and lets
-- the business change commit (fail open, loudly): stock-in is never blocked by the books.
--
-- THE MODEL: THE BOOKS HOLD WHAT THE SHELVES HOLD, BATCH BY BATCH.
-- MyStoreGuard has some twenty paths that move stock (agent survey, 2026-10-19): product create
-- and Add stock (OPENING_STOCK batches), purchase-order receipts (PURCHASE), store/warehouse
-- add-stock with a new delivery and splits (ADJUSTMENT), delivery corrections, cost edits,
-- batch reversal/void/delete, write-offs, stock-take shortages and surpluses and their
-- reversals, splits and their reversal, transfers, allocations, supplier returns. Their
-- movement reasons are partly free text. So instead of one rule per path, every batch is
-- RECONCILED at commit:
--
--   on hand  = msg_purchase_batches.qty_remaining (the unallocated pool, while the batch is
--              not DELETED) + SUM(msg_batch_locations.qty) (placed stock)
--   receipt  = qty_received x cost_price, in the batch's currency, while the batch is neither
--              VOID nor DELETED (gone entirely when the row is deleted)
--
-- Published per batch:
--   msg.stock_received        the receipt, the first time and again after any change to its
--   msg.stock_receipt_voided  quantity, cost or currency (void of the old + new revision, as
--                             a sale is restated). Credit: the supplier's balance for a
--                             delivery (PURCHASE, or a supplier or delivery named), else Stock
--                             adjustments (a split's output, a stock-take surplus).
--   msg.stock_adjusted        whatever change in on-hand value nothing else explains:
--                               (q1 - r1 - S - R - X) * c1  -  (q0 - r0) * c0
--                             q = on hand, r = receipt quantity, c = unit cost; S = quantity
--                             moved by sales, invoices, customer returns and plan cancels
--                             (their own events post that cost), R = sent back to the
--                             supplier (msg.supplier_return posts it), X = handed out in an
--                             exchange (posted here, to cost of sales). Kind WRITE_OFF when a
--                             write-off moved it, COUNT for a stock take, SPLIT, else
--                             ADJUSTMENT. So a cost edit revalues the stock on hand, a
--                             write-off or a shortage costs what the batch cost, and a path
--                             nobody listed still leaves the books equal to the shelves.
-- Per document:
--   msg.supplier_payment_made / msg.supplier_payment_reversed   msg_purchase_payments
--   msg.supplier_return       a purchase return COMPLETED: the goods at the batch's cost.
--
-- S, R and X come from the movements written IN THIS TRANSACTION (msg_product_movements
-- INSERT, an ordinary row trigger), accumulated in transaction-local settings and consumed by
-- the batch's commit-time reconciliation. A savepoint rolled back takes its settings with it.
-- Transfers and allocations need nothing: they move stock between rows of one batch.
--
-- Starts from now: every batch, supplier payment and purchase return that exists when this
-- first runs is recorded as already published (the BASELINE_STOCK marker); stock on hand
-- belongs in the books' opening balance of Inventory. Re-runs every deploy: idempotent.
-- =====================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS mystoreguard.msg_acc_batch_state (
    batch_id     text PRIMARY KEY,
    tenant_id    text NOT NULL,
    org_id       text,
    bus_id       text,
    created_txid xid8,
    qty          numeric NOT NULL DEFAULT 0,   -- on hand, as the books hold it
    unit_cost    numeric NOT NULL DEFAULT 0,
    currency     text NOT NULL DEFAULT '',
    receipt_qty  numeric NOT NULL DEFAULT 0,   -- the receipt as last published
    revision     integer NOT NULL DEFAULT 0,
    receipt      jsonb,                        -- the published receipt payload (for its void)
    updated_at   timestamptz NOT NULL DEFAULT now()
);

-- ===================================================================== movements of this transaction
-- What a movement means for the books. S: a sale-family path (its own event posts the cost);
-- R: back to the supplier; X: an exchange's replacement; W/T/P mark write-off, stock take, split.
CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_movement_class(p_reason text) RETURNS text
LANGUAGE sql IMMUTABLE AS $f$
    SELECT CASE
        WHEN r LIKE 'SALE%' OR r = 'RETURN' OR r LIKE 'INVOICE%' OR r LIKE 'WRITE\_OFF\_%'
             OR r LIKE 'INSTALLMENT PLAN CANCELLED%' THEN 'S'
        WHEN r = 'RETURN_TO_SUPPLIER' THEN 'R'
        WHEN r = 'EXCHANGE' THEN 'X'
        WHEN r LIKE '%WRITTEN OFF%' OR r LIKE '%WRITE-OFF%' OR r LIKE '%WRITE OFF%' OR r ~ '^BATCH .* REVERSED$' THEN 'W'
        WHEN r LIKE 'STOCK_TAKE%' OR r LIKE 'STOCK TAKE%' THEN 'T'
        WHEN r LIKE 'SPLIT%' THEN 'P'
        ELSE '' END
    FROM (SELECT upper(btrim(coalesce(p_reason, ''))) AS r) x
$f$;

CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_tx_get(p_key text) RETURNS numeric
LANGUAGE sql STABLE AS $f$ SELECT coalesce(nullif(current_setting(p_key, true), ''), '0')::numeric $f$;

CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_movement_noted() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE cls text; k text; sgn numeric;
BEGIN
    IF NEW.batch_id IS NULL THEN RETURN NULL; END IF;
    cls := mystoreguard.msg_acc_movement_class(NEW.reason);
    IF cls = '' THEN RETURN NULL; END IF;
    k := 'msg_acc.' || lower(cls) || md5(NEW.batch_id);
    sgn := CASE WHEN upper(NEW.movement_type) = 'OUT' THEN -1 ELSE 1 END;
    IF cls IN ('S', 'R', 'X') THEN
        PERFORM set_config(k, (mystoreguard.msg_acc_tx_get(k) + sgn * coalesce(NEW.qty, 0))::text, true);
    ELSE
        PERFORM set_config(k, '1', true);
    END IF;
    RETURN NULL;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;   -- never stop a stock movement over the books
END
$f$;

-- ===================================================================== a batch
CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_sync_batch(p_tenant text, p_batch text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
    b mystoreguard.msg_purchase_batches;
    st mystoreguard.msg_acc_batch_state;
    found_batch boolean;
    today date := mystoreguard.msg_acc_day(p_tenant, now());
    h text := md5(p_batch);
    q1 numeric; r1 numeric; c1 numeric; k1 text;
    s_qty numeric; r_qty numeric; x_qty numeric;
    receipt_changed boolean;
    head jsonb; rec jsonb; lines jsonb := '[]'::jsonb;
    resid_new numeric; resid_old numeric; kind text;
    created_now boolean; credit_to text; po record; rev integer; d date;
BEGIN
    SELECT * INTO b FROM mystoreguard.msg_purchase_batches WHERE tenant_id = p_tenant AND id = p_batch;
    found_batch := FOUND;

    SELECT * INTO st FROM mystoreguard.msg_acc_batch_state WHERE batch_id = p_batch FOR UPDATE;
    IF NOT FOUND THEN
        IF NOT found_batch THEN RETURN; END IF;
        INSERT INTO mystoreguard.msg_acc_batch_state (batch_id, tenant_id, org_id, bus_id, created_txid,
                                                      unit_cost, currency)
        VALUES (p_batch, p_tenant, b.org_id, b.bus_id, pg_current_xact_id(),
                coalesce(b.cost_price, 0), mystoreguard.msg_acc_currency(p_tenant, b.currency_id))
        RETURNING * INTO st;
    END IF;
    created_now := st.created_txid IS NOT DISTINCT FROM pg_current_xact_id();

    -- What the shelves hold now, and what the receipt now is.
    IF found_batch THEN
        q1 := CASE WHEN coalesce(b.delete_status, 'NOT_DELETED') = 'DELETED' THEN 0 ELSE greatest(coalesce(b.qty_remaining, 0), 0) END
              + coalesce((SELECT sum(bl.qty) FROM mystoreguard.msg_batch_locations bl
                           WHERE bl.tenant_id = p_tenant AND bl.purchase_batche_id = p_batch), 0);
        r1 := CASE WHEN coalesce(b.delete_status, 'NOT_DELETED') = 'DELETED' OR b.status = 'VOID' THEN 0
                   ELSE coalesce(b.qty_received, 0) END;
        c1 := coalesce(b.cost_price, 0);
        k1 := mystoreguard.msg_acc_currency(p_tenant, b.currency_id);
    ELSE
        q1 := coalesce((SELECT sum(bl.qty) FROM mystoreguard.msg_batch_locations bl
                         WHERE bl.tenant_id = p_tenant AND bl.purchase_batche_id = p_batch), 0);
        r1 := 0; c1 := st.unit_cost; k1 := st.currency;
    END IF;

    s_qty := mystoreguard.msg_acc_tx_get('msg_acc.s' || h);
    r_qty := mystoreguard.msg_acc_tx_get('msg_acc.r' || h);
    x_qty := mystoreguard.msg_acc_tx_get('msg_acc.x' || h);

    receipt_changed := r1 <> st.receipt_qty
        OR (r1 <> 0 AND (round(c1, 4) <> round(st.unit_cost, 4) OR k1 <> st.currency))
        OR (r1 <> 0 AND st.revision = 0);

    IF found_batch THEN
        SELECT p.id, p.po_number, rc.receipt_number INTO po
          FROM mystoreguard.msg_product_movements m
          JOIN mystoreguard.msg_purchase_receipts rc ON rc.tenant_id = m.tenant_id AND rc.id = m.reference_id
          JOIN mystoreguard.msg_purchase_orders p ON p.tenant_id = rc.tenant_id AND p.id = rc.purchase_order_id
         WHERE m.tenant_id = p_tenant AND m.batch_id = p_batch AND m.reason = 'PURCHASE'
         LIMIT 1;
        credit_to := CASE WHEN b.batch_type = 'PURCHASE' OR b.supplier_id IS NOT NULL OR b.delivery_id IS NOT NULL
                          THEN 'SUPPLIER' ELSE 'STOCK_ADJUSTMENT' END;
        head := jsonb_build_object(
            'org_id', b.org_id, 'currency', k1,
            'document_type', CASE WHEN po.id IS NOT NULL THEN 'PURCHASE_RECEIPT' ELSE 'DELIVERY' END,
            'document_number', coalesce(po.receipt_number, b.batch_number, b.id), 'document_id', b.id,
            'batch_id', b.id, 'batch_number', b.batch_number, 'batch_type', b.batch_type,
            'delivery_id', b.delivery_id,
            'product_id', b.product_id,
            'product_name', (SELECT p.name FROM core_platform.cp_products p WHERE p.id = b.product_id AND p.tenant_id = p_tenant LIMIT 1),
            'supplier_id', b.supplier_id,
            'supplier_name', (SELECT s.fullname FROM mystoreguard.msg_suppliers s WHERE s.id = b.supplier_id AND s.tenant_id = p_tenant LIMIT 1),
            'purchase_order_id', po.id, 'po_number', po.po_number,
            'credit_to', credit_to);
    ELSE
        head := coalesce(st.receipt, jsonb_build_object('org_id', st.org_id, 'currency', st.currency,
                    'document_type', 'DELIVERY', 'document_number', p_batch, 'document_id', p_batch, 'batch_id', p_batch));
    END IF;

    -- 1. The receipt: void what was published, publish what it is now.
    IF receipt_changed THEN
        rev := st.revision;
        IF st.receipt IS NOT NULL AND st.receipt_qty <> 0 THEN
            PERFORM mystoreguard.msg_acc_publish(p_tenant, coalesce(st.bus_id, b.bus_id), 'msg.stock_receipt_voided', p_batch,
                (st.receipt - 'date') || jsonb_build_object('date', today, 'revision', st.revision,
                    'reason', CASE WHEN NOT found_batch THEN 'DELETED' WHEN b.delete_status = 'DELETED' THEN 'DELETED'
                                   WHEN b.status = 'VOID' THEN 'VOIDED' ELSE 'CHANGED' END));
        END IF;
        rec := NULL;
        IF r1 <> 0 THEN
            rev := st.revision + 1;
            d := CASE WHEN created_now THEN least(coalesce(b.received_date, today), today) ELSE today END;
            rec := head || jsonb_build_object(
                'date', d, 'revision', rev,
                'quantity', r1::text, 'unit_cost', round(c1, 4)::text,
                'amount', mystoreguard.msg_acc_money(r1 * c1));
            PERFORM mystoreguard.msg_acc_publish(p_tenant, b.bus_id, 'msg.stock_received', p_batch, rec);
        END IF;
    END IF;

    -- 2. Whatever else changed what this batch is worth.
    resid_new := round((q1 - r1 - s_qty - r_qty - x_qty) * c1, 2);
    resid_old := round((st.qty - st.receipt_qty) * st.unit_cost, 2);
    kind := CASE WHEN current_setting('msg_acc.w' || h, true) = '1' THEN 'WRITE_OFF'
                 WHEN current_setting('msg_acc.t' || h, true) = '1' THEN 'COUNT'
                 WHEN current_setting('msg_acc.p' || h, true) = '1' THEN 'SPLIT'
                 ELSE 'ADJUSTMENT' END;
    IF k1 = st.currency THEN
        IF resid_new - resid_old <> 0 THEN
            lines := lines || jsonb_build_object('kind', kind, 'currency', k1,
                'quantity', (q1 - st.qty - s_qty - r_qty - x_qty - (r1 - st.receipt_qty))::text,
                'unit_cost', round(c1, 4)::text, 'amount', mystoreguard.msg_acc_money(resid_new - resid_old));
        END IF;
    ELSE
        IF resid_new <> 0 THEN
            lines := lines || jsonb_build_object('kind', kind, 'currency', k1, 'quantity', (q1 - r1 - s_qty - r_qty - x_qty)::text,
                'unit_cost', round(c1, 4)::text, 'amount', mystoreguard.msg_acc_money(resid_new));
        END IF;
        IF resid_old <> 0 THEN
            lines := lines || jsonb_build_object('kind', kind, 'currency', st.currency, 'quantity', (st.receipt_qty - st.qty)::text,
                'unit_cost', round(st.unit_cost, 4)::text, 'amount', mystoreguard.msg_acc_money(-resid_old));
        END IF;
    END IF;
    IF x_qty <> 0 THEN
        lines := lines || jsonb_build_object('kind', 'EXCHANGE', 'currency', k1, 'quantity', x_qty::text,
            'unit_cost', round(c1, 4)::text, 'amount', mystoreguard.msg_acc_money(x_qty * c1));
    END IF;
    IF jsonb_array_length(lines) > 0 THEN
        PERFORM mystoreguard.msg_acc_publish(p_tenant, coalesce(b.bus_id, st.bus_id), 'msg.stock_adjusted', p_batch,
            (head - 'credit_to') || jsonb_build_object(
                'date', today, 'document_type', 'STOCK_ADJUSTMENT',
                'adjustment_kind', kind,
                'lines', (SELECT jsonb_agg(l || jsonb_build_object('batch_id', p_batch, 'product_id', head ->> 'product_id',
                                                                    'product_name', head ->> 'product_name')) FROM jsonb_array_elements(lines) l)));
    END IF;

    -- 3. Remember, and use up this transaction's movements for the batch.
    PERFORM set_config('msg_acc.s' || h, '0', true), set_config('msg_acc.r' || h, '0', true),
            set_config('msg_acc.x' || h, '0', true), set_config('msg_acc.w' || h, '', true),
            set_config('msg_acc.t' || h, '', true), set_config('msg_acc.p' || h, '', true);
    IF NOT found_batch AND q1 = 0 THEN
        DELETE FROM mystoreguard.msg_acc_batch_state WHERE batch_id = p_batch;
    ELSE
        UPDATE mystoreguard.msg_acc_batch_state
           SET qty = q1, unit_cost = c1, currency = k1, receipt_qty = r1,
               revision = CASE WHEN receipt_changed AND r1 <> 0 THEN st.revision + 1 ELSE st.revision END,
               receipt = CASE WHEN receipt_changed THEN rec ELSE st.receipt END,
               updated_at = now()
         WHERE batch_id = p_batch;
    END IF;
END
$f$;

-- ===================================================================== suppliers
-- The currency a purchase order is priced in: its items' one currency, else the tenant's default.
CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_po_currency(p_tenant text, p_po text) RETURNS text
LANGUAGE sql STABLE AS $f$
    SELECT mystoreguard.msg_acc_currency(p_tenant,
        (SELECT CASE WHEN count(DISTINCT currency_id) = 1 THEN min(currency_id) END
           FROM mystoreguard.msg_purchase_order_items WHERE tenant_id = p_tenant AND purchase_order_id = p_po))
$f$;

CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_po_header(p_tenant text, p_po text) RETURNS jsonb
LANGUAGE sql STABLE AS $f$
    SELECT jsonb_build_object('purchase_order_id', p.id, 'po_number', p.po_number, 'supplier_id', p.supplier_id,
               'supplier_name', (SELECT s.fullname FROM mystoreguard.msg_suppliers s WHERE s.id = p.supplier_id AND s.tenant_id = p_tenant LIMIT 1))
      FROM mystoreguard.msg_purchase_orders p WHERE p.tenant_id = p_tenant AND p.id = p_po
$f$;

CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_sync_supplier_payment(p_tenant text, p_payment text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE p record; ds mystoreguard.msg_acc_document_state; eff boolean; head jsonb;
BEGIN
    SELECT * INTO p FROM mystoreguard.msg_purchase_payments WHERE tenant_id = p_tenant AND id = p_payment;
    eff := FOUND AND p.payment_status = 'SUCCESS' AND p.deleted_at IS NULL;
    SELECT * INTO ds FROM mystoreguard.msg_acc_document_state WHERE kind = 'SUPPLIER_PAYMENT' AND doc_id = p_payment FOR UPDATE;
    IF eff AND ds.doc_id IS NOT NULL AND (ds.value ->> 'amount') = mystoreguard.msg_acc_money(p.paid_amount)
       AND (ds.value ->> 'method') = p.payment_method THEN
        RETURN;
    END IF;
    IF ds.doc_id IS NOT NULL THEN
        PERFORM mystoreguard.msg_acc_publish(p_tenant, ds.value ->> 'bus_id', 'msg.supplier_payment_reversed', p_payment,
            (ds.value - 'bus_id') || jsonb_build_object('date', mystoreguard.msg_acc_day(p_tenant, now()),
                'reason', CASE WHEN p.id IS NULL THEN 'DELETED' WHEN p.payment_status = 'REFUNDED' THEN 'REFUNDED' ELSE 'CHANGED' END));
        DELETE FROM mystoreguard.msg_acc_document_state WHERE kind = 'SUPPLIER_PAYMENT' AND doc_id = p_payment;
    END IF;
    IF eff THEN
        head := coalesce(mystoreguard.msg_acc_po_header(p_tenant, p.purchase_order_id), '{}'::jsonb) || jsonb_build_object(
            'org_id', p.org_id, 'bus_id', p.bus_id, 'currency', mystoreguard.msg_acc_po_currency(p_tenant, p.purchase_order_id),
            'document_type', 'SUPPLIER_PAYMENT', 'document_id', p.id, 'payment_id', p.id,
            'method', p.payment_method, 'amount', mystoreguard.msg_acc_money(p.paid_amount), 'description', p.description);
        head := head || jsonb_build_object('document_number', coalesce(head ->> 'po_number', p.id));
        PERFORM mystoreguard.msg_acc_publish(p_tenant, p.bus_id, 'msg.supplier_payment_made', p_payment,
            (head - 'bus_id') || jsonb_build_object('date', mystoreguard.msg_acc_day(p_tenant, p.cdatetime)));
        INSERT INTO mystoreguard.msg_acc_document_state (kind, doc_id, tenant_id, value)
        VALUES ('SUPPLIER_PAYMENT', p_payment, p_tenant, head);
    END IF;
END
$f$;

CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_sync_supplier_return(p_tenant text, p_return text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE r record; v_lines jsonb;
BEGIN
    SELECT * INTO r FROM mystoreguard.msg_purchase_returns WHERE tenant_id = p_tenant AND id = p_return;
    IF NOT FOUND OR r.status IS DISTINCT FROM 'COMPLETED' OR r.deleted_at IS NOT NULL THEN RETURN; END IF;
    IF EXISTS (SELECT 1 FROM mystoreguard.msg_acc_document_state WHERE kind = 'SUPPLIER_RETURN' AND doc_id = p_return) THEN RETURN; END IF;
    SELECT coalesce(jsonb_agg(jsonb_build_object(
               'batch_id', ri.batch_id, 'product_id', ri.product_id,
               'product_name', (SELECT p.name FROM core_platform.cp_products p WHERE p.id = ri.product_id AND p.tenant_id = p_tenant LIMIT 1),
               'quantity', ri.qty_returned::text, 'unit_cost', round(ri.cost_price, 4)::text,
               'amount', mystoreguard.msg_acc_money(ri.line_total),
               'currency', mystoreguard.msg_acc_currency(p_tenant, b.currency_id), 'condition', ri.condition)
             ORDER BY ri.cdatetime, ri.id), '[]'::jsonb)
      INTO v_lines
      FROM mystoreguard.msg_purchase_return_items ri
      LEFT JOIN mystoreguard.msg_purchase_batches b ON b.tenant_id = ri.tenant_id AND b.id = ri.batch_id
     WHERE ri.tenant_id = p_tenant AND ri.purchase_return_id = p_return;
    PERFORM mystoreguard.msg_acc_publish(p_tenant, r.bus_id, 'msg.supplier_return', p_return,
        coalesce(mystoreguard.msg_acc_po_header(p_tenant, r.purchase_order_id), '{}'::jsonb) || jsonb_build_object(
            'org_id', r.org_id, 'loc_id', r.loc_id,
            'currency', mystoreguard.msg_acc_po_currency(p_tenant, r.purchase_order_id),
            'date', mystoreguard.msg_acc_day(p_tenant, r.cdatetime),
            'document_type', 'SUPPLIER_RETURN', 'document_number', r.return_number, 'document_id', r.id,
            'return_id', r.id, 'reason', r.reason, 'total', mystoreguard.msg_acc_money(r.total_return_value),
            'lines', v_lines));
    INSERT INTO mystoreguard.msg_acc_document_state (kind, doc_id, tenant_id) VALUES ('SUPPLIER_RETURN', p_return, p_tenant)
    ON CONFLICT DO NOTHING;
END
$f$;

-- ===================================================================== fail open, loudly
CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_stock_run(p_kind text, p_tenant text, p_org text, p_bus text, p_id text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE msg text; flag text;
BEGIN
    IF p_id IS NULL OR p_tenant IS NULL THEN RETURN; END IF;
    BEGIN
        CASE p_kind
            WHEN 'BATCH' THEN PERFORM mystoreguard.msg_acc_sync_batch(p_tenant, p_id);
            WHEN 'SUPPLIER_PAYMENT' THEN PERFORM mystoreguard.msg_acc_sync_supplier_payment(p_tenant, p_id);
            WHEN 'SUPPLIER_RETURN' THEN PERFORM mystoreguard.msg_acc_sync_supplier_return(p_tenant, p_id);
        END CASE;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS msg = MESSAGE_TEXT;
        flag := 'msg_acc.e' || md5(p_kind || p_id);
        IF coalesce(current_setting(flag, true), '') <> '1' THEN
            PERFORM set_config(flag, '1', true);
            PERFORM core_platform.cp_event_publish(p_tenant, p_bus, 'mystoreguard', 'msg.posting_error', p_id,
                jsonb_build_object('version', 1, 'app', 'mystoreguard', 'org_id', p_org,
                                   'document_type', p_kind, 'document_id', p_id, 'error', msg));
        END IF;
    END;
END
$f$;

CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_stock_trigger() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE r record;
BEGIN
    r := CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
    CASE TG_TABLE_NAME
        WHEN 'msg_purchase_batches' THEN PERFORM mystoreguard.msg_acc_stock_run('BATCH', r.tenant_id, r.org_id, r.bus_id, r.id);
        WHEN 'msg_batch_locations' THEN
            PERFORM mystoreguard.msg_acc_stock_run('BATCH', r.tenant_id, r.org_id, r.bus_id, r.purchase_batche_id);
            IF TG_OP = 'UPDATE' AND OLD.purchase_batche_id IS DISTINCT FROM NEW.purchase_batche_id THEN
                PERFORM mystoreguard.msg_acc_stock_run('BATCH', OLD.tenant_id, OLD.org_id, OLD.bus_id, OLD.purchase_batche_id);
            END IF;
        WHEN 'msg_purchase_payments' THEN PERFORM mystoreguard.msg_acc_stock_run('SUPPLIER_PAYMENT', r.tenant_id, r.org_id, r.bus_id, r.id);
        WHEN 'msg_purchase_returns' THEN PERFORM mystoreguard.msg_acc_stock_run('SUPPLIER_RETURN', r.tenant_id, r.org_id, r.bus_id, r.id);
    END CASE;
    RETURN NULL;
END
$f$;

-- ===================================================================== baseline (first run only)
-- Every batch as it stands is history: its receipt published, its stock held.
INSERT INTO mystoreguard.msg_acc_batch_state (batch_id, tenant_id, org_id, bus_id, qty, unit_cost, currency, receipt_qty, revision, receipt)
SELECT b.id, b.tenant_id, b.org_id, b.bus_id,
       CASE WHEN coalesce(b.delete_status, 'NOT_DELETED') = 'DELETED' THEN 0 ELSE greatest(coalesce(b.qty_remaining, 0), 0) END
         + coalesce((SELECT sum(bl.qty) FROM mystoreguard.msg_batch_locations bl
                      WHERE bl.tenant_id = b.tenant_id AND bl.purchase_batche_id = b.id), 0),
       coalesce(b.cost_price, 0), mystoreguard.msg_acc_currency(b.tenant_id, b.currency_id),
       CASE WHEN coalesce(b.delete_status, 'NOT_DELETED') = 'DELETED' OR b.status = 'VOID' THEN 0 ELSE coalesce(b.qty_received, 0) END,
       1,
       jsonb_build_object('org_id', b.org_id, 'currency', mystoreguard.msg_acc_currency(b.tenant_id, b.currency_id),
           'document_type', 'DELIVERY', 'document_number', coalesce(b.batch_number, b.id), 'document_id', b.id,
           'batch_id', b.id, 'batch_number', b.batch_number, 'product_id', b.product_id, 'supplier_id', b.supplier_id,
           'credit_to', CASE WHEN b.batch_type = 'PURCHASE' OR b.supplier_id IS NOT NULL OR b.delivery_id IS NOT NULL
                             THEN 'SUPPLIER' ELSE 'STOCK_ADJUSTMENT' END,
           'revision', 1, 'baseline', true,
           'quantity', coalesce(b.qty_received, 0)::text, 'unit_cost', round(coalesce(b.cost_price, 0), 4)::text,
           'amount', mystoreguard.msg_acc_money(coalesce(b.qty_received, 0) * coalesce(b.cost_price, 0)))
  FROM mystoreguard.msg_purchase_batches b
 WHERE NOT EXISTS (SELECT 1 FROM mystoreguard.msg_acc_document_state WHERE kind = 'BASELINE_STOCK')
ON CONFLICT (batch_id) DO NOTHING;

INSERT INTO mystoreguard.msg_acc_document_state (kind, doc_id, tenant_id, value)
SELECT 'SUPPLIER_PAYMENT', p.id, p.tenant_id,
       jsonb_build_object('org_id', p.org_id, 'bus_id', p.bus_id, 'currency', mystoreguard.msg_acc_po_currency(p.tenant_id, p.purchase_order_id),
                          'document_type', 'SUPPLIER_PAYMENT', 'document_id', p.id, 'document_number', p.id, 'payment_id', p.id,
                          'purchase_order_id', p.purchase_order_id,
                          'method', p.payment_method, 'amount', mystoreguard.msg_acc_money(p.paid_amount), 'baseline', true)
  FROM mystoreguard.msg_purchase_payments p
 WHERE p.payment_status = 'SUCCESS' AND p.deleted_at IS NULL
   AND NOT EXISTS (SELECT 1 FROM mystoreguard.msg_acc_document_state WHERE kind = 'BASELINE_STOCK')
UNION ALL
SELECT 'SUPPLIER_RETURN', r.id, r.tenant_id, '{}'::jsonb
  FROM mystoreguard.msg_purchase_returns r
 WHERE r.status = 'COMPLETED' AND NOT EXISTS (SELECT 1 FROM mystoreguard.msg_acc_document_state WHERE kind = 'BASELINE_STOCK')
ON CONFLICT DO NOTHING;

INSERT INTO mystoreguard.msg_acc_document_state (kind, doc_id, tenant_id, value)
VALUES ('BASELINE_STOCK', 'msg', '', jsonb_build_object('at', now()))
ON CONFLICT DO NOTHING;

-- ===================================================================== the triggers
DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['msg_purchase_batches', 'msg_batch_locations', 'msg_purchase_payments', 'msg_purchase_returns'] LOOP
        IF to_regclass('mystoreguard.' || t) IS NULL THEN CONTINUE; END IF;
        EXECUTE format('DROP TRIGGER IF EXISTS msg_acc_stock_event ON mystoreguard.%I', t);
        EXECUTE format(
            'CREATE CONSTRAINT TRIGGER msg_acc_stock_event AFTER %s ON mystoreguard.%I DEFERRABLE INITIALLY DEFERRED
               FOR EACH ROW EXECUTE FUNCTION mystoreguard.msg_acc_stock_trigger()',
            CASE t WHEN 'msg_purchase_returns' THEN 'INSERT OR UPDATE' ELSE 'INSERT OR UPDATE OR DELETE' END, t);
        EXECUTE format('ALTER TABLE mystoreguard.%I ENABLE ALWAYS TRIGGER msg_acc_stock_event', t);
    END LOOP;
    IF to_regclass('mystoreguard.msg_product_movements') IS NOT NULL THEN
        DROP TRIGGER IF EXISTS msg_acc_movement_noted ON mystoreguard.msg_product_movements;
        CREATE TRIGGER msg_acc_movement_noted AFTER INSERT ON mystoreguard.msg_product_movements
            FOR EACH ROW EXECUTE FUNCTION mystoreguard.msg_acc_movement_noted();
        ALTER TABLE mystoreguard.msg_product_movements ENABLE ALWAYS TRIGGER msg_acc_movement_noted;
    END IF;
END $$;

COMMIT;
