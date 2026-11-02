-- MyStoreGuard <-> Supply Chain (SCM), phase 4: MyStoreGuard asks SCM for stock and sends stock back
-- (apps-setup/msg-scm-integration-plan.md §3-5; plumbing 20261102-50, branch deliveries 20261102-60).
--
-- Both flows travel on the mystoreguard-scm link (per business, OFF by default; the receiver checks
-- it and fails closed):
--
--   reorder   MyStoreGuard: a warehouse request (mystoreguard.msg_warehouse_requests + _lines) for a
--             branch side mapped to an SCM warehouse (scm.scm_branch_supply) publishes
--             msg.reorder_requested. SCM drafts a requisition for the supplying warehouse
--             (platform/purchasing.CreateRequisition; scm_requisitions.msg_request_id) and submits it
--             under its own approval setting. SCM answers scm.reorder_status (submitted, approved,
--             rejected, cancelled, ordered, shipped, refused). Shipping uses phase 3's branch
--             shipment, linked by scm_branch_shipments.requisition_id; scm.branch_shipment_sent
--             then carries the request, so the incoming delivery names it
--             (msg_incoming_deliveries.request_id) and confirming it marks the request RECEIVED.
--   return    MyStoreGuard: a return to the warehouse (mystoreguard.msg_warehouse_returns + _lines),
--             lines from the branch's batches (with their serial units). Confirming takes the stock
--             off the branch at once (movement reason RETURN_TO_WAREHOUSE) and publishes
--             msg.return_to_warehouse_sent at the batches' cost. SCM opens an inbound return at the
--             supplying warehouse (scm.scm_branch_returns + _lines) that its staff receive: restocked
--             into a new costed lot at the returned cost (serials back in stock) or scrapped. SCM
--             answers scm.return_received v2 (this file) with the outcome per line.
--
-- Books (docs/POSTINGS.md §1b): the return out is the reverse of phase 3's hand-over. Its movement
-- (RETURN_TO_WAREHOUSE, class H) makes msg_acc_sync_batch (here replaced, otherwise as 20261102-60)
-- publish msg.stock_adjusted with adjustment_kind SCM_TRANSFER: Accounting posts Cr Inventory /
-- Dr Stock transfers clearing. Nothing else posts it, so nothing is counted twice.
--
-- Idempotent; safe to re-run.

BEGIN;

-- ===================================================================== event catalogue (new kinds)
WITH envelope AS (
    SELECT jsonb_build_object(
        '$schema', 'https://json-schema.org/draft/2020-12/schema',
        'type', 'object',
        'required', jsonb_build_array('v', 'link', 'idempotency_key', 'data'),
        'properties', jsonb_build_object(
            'v', jsonb_build_object('type', 'integer', 'minimum', 1),
            'link', jsonb_build_object('type', 'string'),
            'idempotency_key', jsonb_build_object('type', 'string', 'minLength', 1, 'maxLength', 200),
            'sent_at', jsonb_build_object('type', 'string', 'format', 'date-time'),
            'sent_by', jsonb_build_object('type', 'string'))) AS e
), kinds (kind, version, link_key, source_app, target_app, phase, description, data) AS (
    SELECT * FROM (VALUES
    ('scm.reorder_status', 1, 'mystoreguard-scm', 'app-scm', 'app-mystoreguard', 4,
     'Where SCM is with a MyStoreGuard warehouse request: its requisition submitted, approved, rejected, cancelled, ordered from a supplier, shipped (branch shipment X), or refused.',
     '{"type":"object","required":["request_id","status"],"properties":{
        "request_id":{"type":"string"},"requisition_id":{"type":"string"},"requisition_number":{"type":"string"},
        "status":{"enum":["submitted","approved","rejected","cancelled","ordered","shipped","refused"]},
        "reason":{"type":"string"},"shipment_id":{"type":"string"},"shipment_number":{"type":"string"},
        "at":{"type":"string","format":"date-time"}}}'::jsonb),
    ('scm.return_received', 2, 'mystoreguard-scm', 'app-scm', 'app-mystoreguard', 4,
     'SCM received (or refused) a return from a MyStoreGuard branch: per line what arrived, what went back into stock and what was scrapped.',
     '{"type":"object","required":["return_id","status","lines"],"properties":{
        "return_id":{"type":"string"},"receipt_id":{"type":"string"},"number":{"type":"string"},
        "status":{"enum":["received","refused"]},"reason":{"type":"string"},"note":{"type":"string"},
        "received_at":{"type":"string","format":"date-time"},
        "lines":{"type":"array","items":{"type":"object","required":["line_id","qty_received"],"properties":{
          "line_id":{"type":"string"},"batch_id":{"type":"string"},"qty_received":{"type":"integer","minimum":0},
          "qty_restocked":{"type":"integer","minimum":0},"qty_scrapped":{"type":"integer","minimum":0},"note":{"type":"string"},
          "serials_restocked":{"type":"array","items":{"type":"string"}},
          "serials_scrapped":{"type":"array","items":{"type":"string"}}}}}}}'::jsonb)
    ) v
)
INSERT INTO core_platform.cp_event_schemas (kind, version, link_key, source_app, target_app, phase, description, schema, updated_at)
SELECT k.kind, k.version, k.link_key, k.source_app, k.target_app, k.phase, k.description,
       jsonb_set(e.e, '{properties,data}', k.data) || jsonb_build_object('title', k.kind || ' v' || k.version), now()
  FROM kinds k CROSS JOIN envelope e
ON CONFLICT (kind, version) DO UPDATE SET
    link_key = EXCLUDED.link_key, source_app = EXCLUDED.source_app, target_app = EXCLUDED.target_app,
    phase = EXCLUDED.phase, description = EXCLUDED.description, schema = EXCLUDED.schema,
    updated_at = CASE WHEN core_platform.cp_event_schemas.schema IS DISTINCT FROM EXCLUDED.schema
                        OR core_platform.cp_event_schemas.description IS DISTINCT FROM EXCLUDED.description
                      THEN now() ELSE core_platform.cp_event_schemas.updated_at END;

-- ===================================================================== SCM
DO $$
BEGIN
    IF to_regclass('scm.scm_branch_shipments') IS NULL THEN
        RAISE NOTICE 'msg-scm phase 4: no SCM schema here: its reorders and returns come with it';
        RETURN;
    END IF;

    -- A requisition MyStoreGuard asked for: which request, for which branch side.
    ALTER TABLE scm.scm_requisitions ADD COLUMN IF NOT EXISTS msg_request_id     text;
    ALTER TABLE scm.scm_requisitions ADD COLUMN IF NOT EXISTS msg_request_number text;
    ALTER TABLE scm.scm_requisitions ADD COLUMN IF NOT EXISTS msg_loc_id         text;
    ALTER TABLE scm.scm_requisitions ADD COLUMN IF NOT EXISTS msg_side           text;
    CREATE UNIQUE INDEX IF NOT EXISTS scm_requisitions_msg_request_uq
        ON scm.scm_requisitions (bus_id, msg_request_id) WHERE msg_request_id IS NOT NULL;

    -- The branch shipment that fulfils a requisition.
    ALTER TABLE scm.scm_branch_shipments ADD COLUMN IF NOT EXISTS requisition_id text REFERENCES scm.scm_requisitions (id);
    CREATE INDEX IF NOT EXISTS scm_branch_shipments_requisition_idx
        ON scm.scm_branch_shipments (requisition_id) WHERE requisition_id IS NOT NULL;

    -- Stock a MyStoreGuard branch sent back, waiting for the warehouse's staff to receive it.
    CREATE TABLE IF NOT EXISTS scm.scm_branch_returns (
        id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
        tenant_id       text NOT NULL,
        org_id          text,
        bus_id          text NOT NULL,
        number          text NOT NULL,              -- MyStoreGuard's number (WRT-00001)
        msg_return_id   text NOT NULL,
        warehouse_id    text NOT NULL REFERENCES scm.scm_warehouses (id),
        loc_id          text NOT NULL,
        side            text NOT NULL DEFAULT 'STORE',
        reason          text,
        note            text,
        currency        text,
        status          text NOT NULL DEFAULT 'awaiting',
        event_id        bigint,
        received_at     timestamptz,
        received_by     text,
        received_note   text,
        reply_event_id  bigint,
        version         integer NOT NULL DEFAULT 1,
        cdatetime       timestamptz NOT NULL DEFAULT now(),
        updated_at      timestamptz NOT NULL DEFAULT now(),
        updated_by      text,
        CONSTRAINT ck_scm_branch_returns_side CHECK (side IN ('STORE', 'WAREHOUSE')),
        CONSTRAINT ck_scm_branch_returns_status CHECK (status IN ('awaiting', 'received'))
    );
    CREATE UNIQUE INDEX IF NOT EXISTS scm_branch_returns_msg_uq ON scm.scm_branch_returns (bus_id, msg_return_id);
    CREATE INDEX IF NOT EXISTS scm_branch_returns_list_idx ON scm.scm_branch_returns (tenant_id, bus_id, cdatetime DESC);

    CREATE TABLE IF NOT EXISTS scm.scm_branch_return_lines (
        id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
        return_id       text NOT NULL REFERENCES scm.scm_branch_returns (id) ON DELETE CASCADE,
        tenant_id       text NOT NULL,
        bus_id          text NOT NULL,
        line_no         integer NOT NULL,
        msg_line_id     text NOT NULL,
        msg_batch_id    text,
        product_id      text NOT NULL,              -- the SCM item (a variant's child product when a kind was sent)
        msg_product_id  text NOT NULL,
        kind            text,
        qty             numeric(14,3) NOT NULL CHECK (qty > 0),
        unit_cost       numeric(18,6),              -- in the return's currency
        lot_number      text,
        expiry_date     date,
        serials         jsonb NOT NULL DEFAULT '[]'::jsonb,
        qty_received    numeric(14,3),
        qty_restocked   numeric(14,3),
        qty_scrapped    numeric(14,3),
        bin_id          text,
        lot_id          text REFERENCES scm.scm_lots (id),
        note            text
    );
    CREATE INDEX IF NOT EXISTS scm_branch_return_lines_return_idx ON scm.scm_branch_return_lines (return_id, line_no);

    ALTER TABLE scm.scm_serials ADD COLUMN IF NOT EXISTS branch_return_id text REFERENCES scm.scm_branch_returns (id);

    INSERT INTO core_platform.cp_product_references (table_name, column_name, is_extension) VALUES
        ('scm.scm_branch_return_lines', 'product_id', false)
    ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;
END $$;

-- ===================================================================== MyStoreGuard
CREATE TABLE IF NOT EXISTS mystoreguard.msg_warehouse_requests (
    id                      text PRIMARY KEY DEFAULT ('wrq_' || replace(gen_random_uuid()::text, '-', '')),
    tenant_id               text NOT NULL,
    org_id                  text,
    bus_id                  text NOT NULL,
    loc_id                  text NOT NULL,
    side                    text NOT NULL DEFAULT 'STORE',
    number                  text NOT NULL,
    warehouse_id            text,
    warehouse_name          text,
    status                  text NOT NULL DEFAULT 'SENT',
    status_note             text,
    status_at               timestamptz,
    needed_by               date,
    note                    text,
    scm_requisition_id      text,
    scm_requisition_number  text,
    scm_shipment_id         text,
    scm_shipment_number     text,
    incoming_id             text,
    event_id                bigint,
    created_by              text,
    cdatetime               timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_msg_warehouse_requests_side CHECK (side IN ('STORE', 'WAREHOUSE')),
    CONSTRAINT ck_msg_warehouse_requests_status CHECK (status IN
        ('SENT', 'SUBMITTED', 'APPROVED', 'REJECTED', 'CANCELLED', 'ORDERED', 'SHIPPED', 'RECEIVED', 'REFUSED'))
);
CREATE UNIQUE INDEX IF NOT EXISTS msg_warehouse_requests_number_uq ON mystoreguard.msg_warehouse_requests (tenant_id, bus_id, number);
CREATE INDEX IF NOT EXISTS msg_warehouse_requests_list_idx ON mystoreguard.msg_warehouse_requests (tenant_id, bus_id, loc_id, cdatetime DESC);

CREATE TABLE IF NOT EXISTS mystoreguard.msg_warehouse_request_lines (
    id             text PRIMARY KEY DEFAULT ('wrql_' || replace(gen_random_uuid()::text, '-', '')),
    request_id     text NOT NULL REFERENCES mystoreguard.msg_warehouse_requests (id) ON DELETE CASCADE,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    line_no        integer NOT NULL,
    product_id     text NOT NULL,
    kind           text,
    qty            integer NOT NULL CHECK (qty > 0),
    on_hand        integer,
    reorder_level  integer
);
CREATE INDEX IF NOT EXISTS msg_warehouse_request_lines_request_idx ON mystoreguard.msg_warehouse_request_lines (request_id, line_no);

CREATE TABLE IF NOT EXISTS mystoreguard.msg_warehouse_returns (
    id               text PRIMARY KEY DEFAULT ('wrt_' || replace(gen_random_uuid()::text, '-', '')),
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    loc_id           text NOT NULL,
    side             text NOT NULL DEFAULT 'STORE',
    number           text NOT NULL,
    warehouse_id     text NOT NULL,
    warehouse_name   text,
    reason           text NOT NULL,
    note             text,
    currency_code    text NOT NULL,
    status           text NOT NULL DEFAULT 'SENT',
    outcome_note     text,
    scm_receipt_id   text,
    received_at      timestamptz,
    event_id         bigint,
    created_by       text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_msg_warehouse_returns_side CHECK (side IN ('STORE', 'WAREHOUSE')),
    CONSTRAINT ck_msg_warehouse_returns_status CHECK (status IN ('SENT', 'RECEIVED', 'PARTIAL', 'REFUSED'))
);
CREATE UNIQUE INDEX IF NOT EXISTS msg_warehouse_returns_number_uq ON mystoreguard.msg_warehouse_returns (tenant_id, bus_id, number);
CREATE INDEX IF NOT EXISTS msg_warehouse_returns_list_idx ON mystoreguard.msg_warehouse_returns (tenant_id, bus_id, loc_id, cdatetime DESC);

CREATE TABLE IF NOT EXISTS mystoreguard.msg_warehouse_return_lines (
    id              text PRIMARY KEY DEFAULT ('wrtl_' || replace(gen_random_uuid()::text, '-', '')),
    return_id       text NOT NULL REFERENCES mystoreguard.msg_warehouse_returns (id) ON DELETE CASCADE,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    line_no         integer NOT NULL,
    batch_id        text NOT NULL,
    product_id      text NOT NULL,
    kind            text,
    qty             integer NOT NULL CHECK (qty > 0),
    unit_cost       numeric(18,4) NOT NULL CHECK (unit_cost >= 0),
    expiry_date     date,
    serials         jsonb NOT NULL DEFAULT '[]'::jsonb,   -- [{unit_id, serial, imei?, barcode?}]
    qty_received    integer,
    qty_restocked   integer,
    qty_scrapped    integer,
    outcome_note    text
);
CREATE INDEX IF NOT EXISTS msg_warehouse_return_lines_return_idx ON mystoreguard.msg_warehouse_return_lines (return_id, line_no);
CREATE INDEX IF NOT EXISTS msg_warehouse_return_lines_batch_idx ON mystoreguard.msg_warehouse_return_lines (tenant_id, batch_id);

ALTER TABLE mystoreguard.msg_incoming_deliveries ADD COLUMN IF NOT EXISTS request_id text;

INSERT INTO core_platform.cp_product_references (table_name, column_name, is_extension) VALUES
    ('mystoreguard.msg_warehouse_request_lines', 'product_id', false),
    ('mystoreguard.msg_warehouse_return_lines', 'product_id', false)
ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;

-- ===================================================================== Accounting: the return out
-- RETURN_TO_WAREHOUSE is class H (stock handed back to the business's own SCM warehouse); every other
-- reason as 20261019-39.
CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_movement_class(p_reason text) RETURNS text
LANGUAGE sql IMMUTABLE AS $f$
    SELECT CASE
        WHEN r LIKE 'SALE%' OR r = 'RETURN' OR r LIKE 'INVOICE%' OR r LIKE 'WRITE\_OFF\_%'
             OR r LIKE 'INSTALLMENT PLAN CANCELLED%' THEN 'S'
        WHEN r = 'RETURN_TO_SUPPLIER' THEN 'R'
        WHEN r = 'EXCHANGE' THEN 'X'
        WHEN r = 'RETURN_TO_WAREHOUSE' THEN 'H'
        WHEN r LIKE '%WRITTEN OFF%' OR r LIKE '%WRITE-OFF%' OR r LIKE '%WRITE OFF%' OR r ~ '^BATCH .* REVERSED$' THEN 'W'
        WHEN r LIKE 'STOCK_TAKE%' OR r LIKE 'STOCK TAKE%' THEN 'T'
        WHEN r LIKE 'SPLIT%' THEN 'P'
        ELSE '' END
    FROM (SELECT upper(btrim(coalesce(p_reason, ''))) AS r) x
$f$;

-- msg_acc_sync_batch as 20261102-60 has it, except the adjustment kind SCM_TRANSFER (marked 20261102-80).
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
        -- owned, handed over from its own warehouse (credit_to SCM_TRANSFER).
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
    -- 20261102-80: stock sent back to the business's SCM warehouse (RETURN_TO_WAREHOUSE) is the
    -- reverse of the phase 3 hand-over: against the stock-transfer clearing account (SCM_TRANSFER).
    kind := CASE WHEN current_setting('msg_acc.h' || h, true) = '1' THEN 'SCM_TRANSFER'
                 WHEN current_setting('msg_acc.w' || h, true) = '1' THEN 'WRITE_OFF'
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
            set_config('msg_acc.t' || h, '', true), set_config('msg_acc.p' || h, '', true),
            set_config('msg_acc.h' || h, '', true);
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
    SELECT string_agg(k, ', ') INTO bad FROM unnest(ARRAY['msg.reorder_requested:1', 'msg.return_to_warehouse_sent:1',
                                                           'scm.reorder_status:1', 'scm.return_received:2']) k
     WHERE NOT EXISTS (SELECT 1 FROM core_platform.cp_event_schemas s
                        WHERE s.kind = split_part(k, ':', 1) AND s.version = split_part(k, ':', 2)::int);
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'msg-scm phase 4: event catalogue lacks %', bad;
    END IF;
    IF mystoreguard.msg_acc_movement_class('RETURN_TO_WAREHOUSE') <> 'H'
       OR mystoreguard.msg_acc_movement_class('RETURN_TO_SUPPLIER') <> 'R' THEN
        RAISE EXCEPTION 'msg-scm phase 4: movement classes are wrong';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                    WHERE n.nspname = 'mystoreguard' AND p.proname = 'msg_acc_sync_batch'
                      AND pg_get_functiondef(p.oid) LIKE '%msg_acc.h%' AND pg_get_functiondef(p.oid) LIKE '%SCM_TRANSFER%') THEN
        RAISE EXCEPTION 'msg-scm phase 4: msg_acc_sync_batch does not know the return to the warehouse';
    END IF;
    -- A return line names no more units than its quantity.
    SELECT string_agg(l.id, ', ') INTO bad FROM mystoreguard.msg_warehouse_return_lines l
     WHERE jsonb_array_length(l.serials) > l.qty;
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'msg-scm phase 4: return lines with more serial units than their quantity: %', bad;
    END IF;
END $$;

COMMIT;
