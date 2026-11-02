-- MyStoreGuard <-> Supply Chain (SCM), phase 3: SCM supplies MyStoreGuard branches
-- (apps-setup/msg-scm-integration-plan.md §3-5; plumbing in 20261102-50).
--
-- Two SCM documents travel to MyStoreGuard on the scm-mystoreguard link (per business, OFF by
-- default; the receiver checks it and fails closed):
--
--   branch shipment   scm.scm_branch_shipments (+ _lines, _line_serials, _parts). Stock leaves a
--                     mapped SCM warehouse (scm_branch_supply) for a MyStoreGuard place. Dispatch
--                     takes it out of SCM first in, first out (transfer_out movements, reference
--                     'branch_shipment') and writes one PART per lot it took, with that lot's cost
--                     converted into the business's base currency at the Core Platform rate. The
--                     parts travel as scm.branch_shipment_sent; each becomes one MyStoreGuard batch.
--                     Numbers come from the 'shipment' series (SHP-), shared with sales shipments
--                     (adding a kind to scm_number_series would break 20261026-09 on its re-run).
--   PO to a branch    scm_purchase_orders.deliver_to_loc_id / deliver_to_side: a supplier delivers an
--                     SCM order straight to a MyStoreGuard place. SCM never receives it (no goods
--                     receipt, no warehouse stock); approval publishes scm.po_receipt_for_branch and
--                     MyStoreGuard's confirmation closes the lines (qty_received, qty_short).
--
-- MyStoreGuard takes each in as an INCOMING DELIVERY (mystoreguard.msg_incoming_deliveries +
-- _lines) that touches no stock until a person confirms it (decision 3). Confirming makes one
-- batch per line exactly as Add stock with a new delivery does (same delivery_id, cost = SCM's,
-- the selling price the person entered), placed at the branch side; shortages and a reason are kept
-- per line. Confirm or reject answers msg.branch_delivery_received, which SCM records against the
-- shipment (received / short / rejected) or the order lines.
--
-- Accounting (docs/POSTINGS.md §1b): SCM posts nothing to the books, so nothing is counted twice.
-- A batch confirmed from a SHIPMENT is stock the business already owned: msg_acc_sync_batch (here
-- replaced, otherwise identical to 20261019-39) now publishes it with credit_to SCM_TRANSFER, which
-- Accounting posts Dr Inventory / Cr Stock transfers clearing (no profit or loss, decision in plan
-- §3). A PO delivered to a branch stays an ordinary purchase (credit_to SUPPLIER).
--
-- Idempotent; safe to re-run.

BEGIN;

-- ===================================================================== SCM
DO $$
BEGIN
    IF to_regclass('scm.scm_warehouses') IS NULL THEN
        RAISE NOTICE 'msg-scm phase 3: no SCM schema here: its branch shipments come with it';
        RETURN;
    END IF;

    CREATE TABLE IF NOT EXISTS scm.scm_branch_shipments (
        id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
        tenant_id        text NOT NULL,
        org_id           text,
        bus_id           text NOT NULL,
        number           text NOT NULL,
        warehouse_id     text NOT NULL REFERENCES scm.scm_warehouses (id),
        loc_id           text NOT NULL,
        side             text NOT NULL DEFAULT 'STORE',
        status           text NOT NULL DEFAULT 'draft',
        expected_date    date,
        notes            text,
        currency         text,
        dispatched_at    timestamptz,
        dispatched_by    text,
        event_id         bigint,
        received_at      timestamptz,
        msg_delivery_id  text,
        received_note    text,
        idempotency_key  text,
        version          integer NOT NULL DEFAULT 1,
        cdatetime        timestamptz NOT NULL DEFAULT now(),
        created_by       text,
        updated_at       timestamptz NOT NULL DEFAULT now(),
        updated_by       text,
        CONSTRAINT ck_scm_branch_shipments_side CHECK (side IN ('STORE', 'WAREHOUSE')),
        CONSTRAINT ck_scm_branch_shipments_status CHECK (status IN ('draft', 'dispatched', 'received', 'short', 'rejected', 'cancelled'))
    );
    CREATE UNIQUE INDEX IF NOT EXISTS scm_branch_shipments_number_uq ON scm.scm_branch_shipments (bus_id, number);
    CREATE UNIQUE INDEX IF NOT EXISTS scm_branch_shipments_key_uq ON scm.scm_branch_shipments (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
    CREATE INDEX IF NOT EXISTS scm_branch_shipments_list_idx ON scm.scm_branch_shipments (tenant_id, bus_id, cdatetime DESC);

    CREATE TABLE IF NOT EXISTS scm.scm_branch_shipment_lines (
        id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
        shipment_id      text NOT NULL REFERENCES scm.scm_branch_shipments (id) ON DELETE CASCADE,
        tenant_id        text NOT NULL,
        bus_id           text NOT NULL,
        line_no          integer NOT NULL,
        product_id       text NOT NULL,
        lot_id           text REFERENCES scm.scm_lots (id),
        bin_id           text,
        qty              numeric(14,3) NOT NULL CHECK (qty > 0),
        suggested_price  numeric(18,4) CHECK (suggested_price IS NULL OR suggested_price >= 0),
        qty_received     numeric(14,3),
        qty_short        numeric(14,3),
        short_reason     text
    );
    CREATE INDEX IF NOT EXISTS scm_branch_shipment_lines_shipment_idx ON scm.scm_branch_shipment_lines (shipment_id, line_no);

    CREATE TABLE IF NOT EXISTS scm.scm_branch_shipment_line_serials (
        line_id    text NOT NULL REFERENCES scm.scm_branch_shipment_lines (id) ON DELETE CASCADE,
        serial_id  text NOT NULL REFERENCES scm.scm_serials (id),
        tenant_id  text NOT NULL,
        bus_id     text NOT NULL,
        part_id    text,
        received   boolean,
        cdatetime  timestamptz NOT NULL DEFAULT now(),
        PRIMARY KEY (line_id, serial_id)
    );
    CREATE INDEX IF NOT EXISTS scm_branch_shipment_line_serials_serial_idx ON scm.scm_branch_shipment_line_serials (serial_id);

    -- What dispatch actually sent: one row per (line, lot taken), each at that lot's cost. These
    -- are the lines of scm.branch_shipment_sent (line_id = part id) and of MyStoreGuard's answer.
    CREATE TABLE IF NOT EXISTS scm.scm_branch_shipment_parts (
        id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
        shipment_id      text NOT NULL REFERENCES scm.scm_branch_shipments (id) ON DELETE CASCADE,
        line_id          text NOT NULL REFERENCES scm.scm_branch_shipment_lines (id) ON DELETE CASCADE,
        tenant_id        text NOT NULL,
        bus_id           text NOT NULL,
        part_no          integer NOT NULL,
        lot_id           text REFERENCES scm.scm_lots (id),
        lot_number       text,
        expiry_date      date,
        qty              numeric(14,3) NOT NULL CHECK (qty > 0),
        unit_cost        numeric(18,6),          -- in the shipment's currency (the base)
        lot_unit_cost    numeric(18,6),          -- in the lot's own currency
        lot_currency     text,
        rate             numeric(20,10),         -- 1 lot_currency = rate base
        qty_received     numeric(14,3),
        qty_short        numeric(14,3),
        short_reason     text,
        msg_batch_id     text
    );
    CREATE INDEX IF NOT EXISTS scm_branch_shipment_parts_shipment_idx ON scm.scm_branch_shipment_parts (shipment_id, part_no);

    ALTER TABLE scm.scm_serials ADD COLUMN IF NOT EXISTS branch_shipment_id text REFERENCES scm.scm_branch_shipments (id);
    CREATE INDEX IF NOT EXISTS scm_serials_branch_shipment_idx ON scm.scm_serials (branch_shipment_id) WHERE branch_shipment_id IS NOT NULL;

    -- A purchase order delivered straight to a MyStoreGuard place.
    ALTER TABLE scm.scm_purchase_orders ADD COLUMN IF NOT EXISTS deliver_to_loc_id text;
    ALTER TABLE scm.scm_purchase_orders ADD COLUMN IF NOT EXISTS deliver_to_side   text;
    ALTER TABLE scm.scm_purchase_orders ADD COLUMN IF NOT EXISTS branch_event_id   bigint;
    ALTER TABLE scm.scm_purchase_orders ADD COLUMN IF NOT EXISTS branch_sent_at    timestamptz;
    ALTER TABLE scm.scm_purchase_orders ADD COLUMN IF NOT EXISTS branch_status     text;
    ALTER TABLE scm.scm_purchase_orders ADD COLUMN IF NOT EXISTS msg_delivery_id   text;
    ALTER TABLE scm.scm_purchase_orders DROP CONSTRAINT IF EXISTS ck_scm_purchase_orders_deliver_to;
    ALTER TABLE scm.scm_purchase_orders ADD CONSTRAINT ck_scm_purchase_orders_deliver_to CHECK (
        (deliver_to_loc_id IS NULL AND deliver_to_side IS NULL)
        OR (deliver_to_loc_id IS NOT NULL AND deliver_to_side IN ('STORE', 'WAREHOUSE')));
    ALTER TABLE scm.scm_purchase_orders DROP CONSTRAINT IF EXISTS ck_scm_purchase_orders_branch_status;
    ALTER TABLE scm.scm_purchase_orders ADD CONSTRAINT ck_scm_purchase_orders_branch_status CHECK (
        branch_status IS NULL OR branch_status IN ('awaiting', 'received', 'short', 'rejected'));
    ALTER TABLE scm.scm_purchase_order_lines ADD COLUMN IF NOT EXISTS qty_short    numeric(14,3);
    ALTER TABLE scm.scm_purchase_order_lines ADD COLUMN IF NOT EXISTS short_reason text;

    INSERT INTO core_platform.cp_product_references (table_name, column_name, is_extension) VALUES
        ('scm.scm_branch_shipment_lines', 'product_id', false)
    ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;
END $$;

-- ===================================================================== MyStoreGuard
-- What SCM sent a branch, waiting for a person to count it in. No stock moves until confirmed.
CREATE TABLE IF NOT EXISTS mystoreguard.msg_incoming_deliveries (
    id               text PRIMARY KEY DEFAULT ('inc_' || replace(gen_random_uuid()::text, '-', '')),
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    loc_id           text NOT NULL,
    side             text NOT NULL DEFAULT 'STORE',
    source_kind      text NOT NULL,           -- shipment | purchase_order
    source_id        text NOT NULL,           -- SCM's document id
    source_number    text,                    -- SHP-00012 / PO-00003
    source_event_id  bigint,
    inbox_id         text,
    from_name        text,                    -- the SCM warehouse, or the supplier
    warehouse_id     text,
    supplier_id      text,                    -- cp_parties id (purchase orders)
    currency_code    text NOT NULL,
    expected_at      date,
    dispatched_at    timestamptz,
    status           text NOT NULL DEFAULT 'PENDING',
    delivery_ref     text,                    -- the delivery_id its batches share once confirmed
    note             text,
    reject_reason    text,
    received_at      timestamptz,
    received_by      text,
    reply_event_id   bigint,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_msg_incoming_deliveries_side CHECK (side IN ('STORE', 'WAREHOUSE')),
    CONSTRAINT ck_msg_incoming_deliveries_kind CHECK (source_kind IN ('shipment', 'purchase_order')),
    CONSTRAINT ck_msg_incoming_deliveries_status CHECK (status IN ('PENDING', 'RECEIVED', 'PARTIAL', 'REJECTED'))
);
CREATE UNIQUE INDEX IF NOT EXISTS msg_incoming_deliveries_source_uq
    ON mystoreguard.msg_incoming_deliveries (tenant_id, bus_id, source_kind, source_id);
CREATE INDEX IF NOT EXISTS msg_incoming_deliveries_pending_idx
    ON mystoreguard.msg_incoming_deliveries (tenant_id, bus_id, loc_id) WHERE status = 'PENDING';

CREATE TABLE IF NOT EXISTS mystoreguard.msg_incoming_delivery_lines (
    id               text PRIMARY KEY DEFAULT ('incl_' || replace(gen_random_uuid()::text, '-', '')),
    incoming_id      text NOT NULL REFERENCES mystoreguard.msg_incoming_deliveries (id) ON DELETE CASCADE,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    line_no          integer NOT NULL,
    source_line_id   text NOT NULL,           -- SCM's part id (shipment) or PO line id
    product_id       text NOT NULL,           -- the cp_products id MyStoreGuard sells (a variant's parent)
    kind             text,                    -- the variant, as MyStoreGuard's product_size
    qty_sent         integer NOT NULL CHECK (qty_sent > 0),
    unit_cost        numeric(18,4) NOT NULL CHECK (unit_cost >= 0),
    suggested_price  numeric(18,4) CHECK (suggested_price IS NULL OR suggested_price >= 0),
    lot_number       text,
    expiry_date      date,
    serials          jsonb NOT NULL DEFAULT '[]'::jsonb,
    qty_received     integer CHECK (qty_received IS NULL OR qty_received >= 0),
    short_reason     text,
    selling_price    numeric(18,4) CHECK (selling_price IS NULL OR selling_price >= 0),
    batch_id         text
);
CREATE INDEX IF NOT EXISTS msg_incoming_delivery_lines_incoming_idx
    ON mystoreguard.msg_incoming_delivery_lines (incoming_id, line_no);
CREATE INDEX IF NOT EXISTS msg_incoming_delivery_lines_batch_idx
    ON mystoreguard.msg_incoming_delivery_lines (tenant_id, batch_id) WHERE batch_id IS NOT NULL;

INSERT INTO core_platform.cp_product_references (table_name, column_name, is_extension) VALUES
    ('mystoreguard.msg_incoming_delivery_lines', 'product_id', false)
ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;

-- ===================================================================== Accounting: the hand-over
-- msg_acc_sync_batch as 20261019-39 has it, except credit_to (marked 20261102-60 below).
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
        -- 20261102-60: a batch confirmed from an SCM branch shipment is stock the business already
        -- owned, handed over from its own warehouse: no supplier is owed and nothing is gained, so it
        -- is credited to the stock-transfer clearing account (credit_to SCM_TRANSFER). A purchase
        -- order SCM had delivered straight to the branch is an ordinary purchase (SUPPLIER).
        credit_to := CASE WHEN EXISTS (SELECT 1 FROM mystoreguard.msg_incoming_delivery_lines il
                                         JOIN mystoreguard.msg_incoming_deliveries i ON i.id = il.incoming_id
                                        WHERE il.tenant_id = p_tenant AND il.batch_id = b.id AND i.source_kind = 'shipment')
                          THEN 'SCM_TRANSFER'
                          WHEN b.batch_type = 'PURCHASE' OR b.supplier_id IS NOT NULL OR b.delivery_id IS NOT NULL
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

-- ===================================================================== checks (invariants, not counts)
DO $$
DECLARE bad text;
BEGIN
    -- The catalogue rows phase 3 sends and answers must be there (20261102-50 owns them).
    SELECT string_agg(k, ', ') INTO bad FROM unnest(ARRAY['scm.branch_shipment_sent', 'scm.po_receipt_for_branch',
                                                           'msg.branch_delivery_received']) k
     WHERE NOT EXISTS (SELECT 1 FROM core_platform.cp_event_schemas s WHERE s.kind = k AND s.version = 1);
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'msg-scm phase 3: event catalogue lacks %', bad;
    END IF;
    -- Every confirmed incoming line names its batch; a pending delivery has none.
    SELECT string_agg(i.id, ', ') INTO bad FROM mystoreguard.msg_incoming_deliveries i
     WHERE (i.status = 'PENDING' AND EXISTS (SELECT 1 FROM mystoreguard.msg_incoming_delivery_lines l WHERE l.incoming_id = i.id AND l.batch_id IS NOT NULL))
        OR (i.status IN ('RECEIVED', 'PARTIAL') AND EXISTS (SELECT 1 FROM mystoreguard.msg_incoming_delivery_lines l
                                                             WHERE l.incoming_id = i.id AND coalesce(l.qty_received, 0) > 0 AND l.batch_id IS NULL));
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'msg-scm phase 3: incoming deliveries whose batches do not match their status: %', bad;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                    WHERE n.nspname = 'mystoreguard' AND p.proname = 'msg_acc_sync_batch'
                      AND pg_get_functiondef(p.oid) LIKE '%SCM_TRANSFER%') THEN
        RAISE EXCEPTION 'msg-scm phase 3: msg_acc_sync_batch does not know the SCM hand-over';
    END IF;
END $$;

COMMIT;
