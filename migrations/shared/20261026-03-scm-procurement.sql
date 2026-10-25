-- SCM: procurement -- asking for things, ordering them and receiving them.
--
--   scm_requisitions           a request to buy: draft, submitted, approved or rejected, then
--                              converted into a purchase order or cancelled
--   scm_requisition_lines      what and how much, with an estimate and a preferred supplier
--   scm_purchase_orders        an order to a supplier (core_platform.cp_parties, is_supplier):
--                              approved when policy asks, sent, confirmed by the supplier,
--                              received in one or more receipts, then closed
--   scm_purchase_order_lines   product, quantity ordered and received, price and tax
--   scm_receipts               goods received against a purchase order; posting writes the ledger
--   scm_receipt_lines          what arrived, where it was put, its lot and cost
--
-- Totals are recomputed server-side from lines. Documents users edit carry a version
-- (optimistic concurrency); documents created by POST carry an idempotency_key, unique per
-- business, so a retried request returns the document it already made. Status lists are
-- CHECK constraints owned by this file. Cross-app ids (suppliers, products, tax rates) are
-- plain text; the shared registries in 20261026-02 know which columns they are.
-- Idempotent; safe to re-run.

BEGIN;

-- ================================================================= requisitions
CREATE TABLE IF NOT EXISTS scm.scm_requisitions (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    number            text NOT NULL,
    status            text NOT NULL DEFAULT 'draft',
    warehouse_id      text REFERENCES scm.scm_warehouses (id),
    requested_by      text,
    needed_by         date,
    notes             text,
    submitted_at      timestamptz,
    approved_by       text,
    approved_at       timestamptz,
    rejected_reason   text,
    converted_po_id   text,
    version           integer NOT NULL DEFAULT 1,
    idempotency_key   text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text
);
ALTER TABLE scm.scm_requisitions DROP CONSTRAINT IF EXISTS scm_requisitions_status_check;
ALTER TABLE scm.scm_requisitions ADD CONSTRAINT scm_requisitions_status_check CHECK (status IN
    ('draft', 'submitted', 'approved', 'rejected', 'converted', 'cancelled'));
CREATE UNIQUE INDEX IF NOT EXISTS scm_requisitions_number_uq ON scm.scm_requisitions (bus_id, number);
CREATE UNIQUE INDEX IF NOT EXISTS scm_requisitions_idem_uq ON scm.scm_requisitions (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS scm_requisitions_board_idx ON scm.scm_requisitions (bus_id, status, cdatetime DESC);

CREATE TABLE IF NOT EXISTS scm.scm_requisition_lines (
    id                      text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    requisition_id          text NOT NULL REFERENCES scm.scm_requisitions (id) ON DELETE CASCADE,
    line_no                 integer NOT NULL,
    product_id              text NOT NULL,
    qty                     numeric(14,3) NOT NULL CHECK (qty > 0),
    uom_id                  text,
    est_unit_price          numeric(14,4) CHECK (est_unit_price IS NULL OR est_unit_price >= 0),
    preferred_supplier_id   text,
    notes                   text
);
CREATE UNIQUE INDEX IF NOT EXISTS scm_requisition_lines_uq ON scm.scm_requisition_lines (requisition_id, line_no);

-- ============================================================== purchase orders
CREATE TABLE IF NOT EXISTS scm.scm_purchase_orders (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    number            text NOT NULL,
    supplier_id       text NOT NULL,
    warehouse_id      text NOT NULL REFERENCES scm.scm_warehouses (id),
    requisition_id    text REFERENCES scm.scm_requisitions (id),
    status            text NOT NULL DEFAULT 'draft',
    order_date        date NOT NULL DEFAULT CURRENT_DATE,
    expected_date     date,
    currency          text NOT NULL,
    subtotal          numeric(14,2) NOT NULL DEFAULT 0,
    tax_total         numeric(14,2) NOT NULL DEFAULT 0,
    total             numeric(14,2) NOT NULL DEFAULT 0,
    approved_by       text,
    approved_at       timestamptz,
    sent_at           timestamptz,
    confirmed_at      timestamptz,
    confirmed_ref     text,
    confirmed_date    date,
    notes             text,
    cancelled_reason  text,
    version           integer NOT NULL DEFAULT 1,
    idempotency_key   text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text
);
ALTER TABLE scm.scm_purchase_orders DROP CONSTRAINT IF EXISTS scm_purchase_orders_status_check;
ALTER TABLE scm.scm_purchase_orders ADD CONSTRAINT scm_purchase_orders_status_check CHECK (status IN
    ('draft', 'pending_approval', 'approved', 'sent', 'confirmed', 'partially_received', 'received', 'closed', 'cancelled'));
ALTER TABLE scm.scm_purchase_orders DROP CONSTRAINT IF EXISTS scm_purchase_orders_totals_check;
ALTER TABLE scm.scm_purchase_orders ADD CONSTRAINT scm_purchase_orders_totals_check CHECK (subtotal >= 0 AND tax_total >= 0 AND total >= 0);
CREATE UNIQUE INDEX IF NOT EXISTS scm_purchase_orders_number_uq ON scm.scm_purchase_orders (bus_id, number);
CREATE UNIQUE INDEX IF NOT EXISTS scm_purchase_orders_idem_uq ON scm.scm_purchase_orders (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS scm_purchase_orders_board_idx ON scm.scm_purchase_orders (bus_id, status, expected_date);
CREATE INDEX IF NOT EXISTS scm_purchase_orders_supplier_idx ON scm.scm_purchase_orders (bus_id, supplier_id, order_date DESC);

CREATE TABLE IF NOT EXISTS scm.scm_purchase_order_lines (
    id                    text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    po_id                 text NOT NULL REFERENCES scm.scm_purchase_orders (id) ON DELETE CASCADE,
    line_no               integer NOT NULL,
    product_id            text NOT NULL,
    qty_ordered           numeric(14,3) NOT NULL CHECK (qty_ordered > 0),
    qty_received          numeric(14,3) NOT NULL DEFAULT 0 CHECK (qty_received >= 0),
    uom_id                text,
    unit_price            numeric(14,4) NOT NULL CHECK (unit_price >= 0),
    tax_rate_id           text,
    tax_rate              numeric(6,3) NOT NULL DEFAULT 0 CHECK (tax_rate >= 0),
    line_total            numeric(14,2) NOT NULL DEFAULT 0,
    expected_date         date,
    requisition_line_id   text
);
CREATE UNIQUE INDEX IF NOT EXISTS scm_purchase_order_lines_uq ON scm.scm_purchase_order_lines (po_id, line_no);
CREATE INDEX IF NOT EXISTS scm_purchase_order_lines_product_idx ON scm.scm_purchase_order_lines (product_id);

-- ===================================================================== receipts
CREATE TABLE IF NOT EXISTS scm.scm_receipts (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    number            text NOT NULL,
    po_id             text NOT NULL REFERENCES scm.scm_purchase_orders (id),
    warehouse_id      text NOT NULL REFERENCES scm.scm_warehouses (id),
    status            text NOT NULL DEFAULT 'draft',
    received_at       timestamptz NOT NULL DEFAULT now(),
    supplier_ref      text,
    notes             text,
    posted_by         text,
    posted_at         timestamptz,
    idempotency_key   text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text
);
ALTER TABLE scm.scm_receipts DROP CONSTRAINT IF EXISTS scm_receipts_status_check;
ALTER TABLE scm.scm_receipts ADD CONSTRAINT scm_receipts_status_check CHECK (status IN ('draft', 'posted', 'cancelled'));
CREATE UNIQUE INDEX IF NOT EXISTS scm_receipts_number_uq ON scm.scm_receipts (bus_id, number);
CREATE UNIQUE INDEX IF NOT EXISTS scm_receipts_idem_uq ON scm.scm_receipts (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS scm_receipts_po_idx ON scm.scm_receipts (po_id, received_at DESC);
CREATE INDEX IF NOT EXISTS scm_receipts_board_idx ON scm.scm_receipts (bus_id, status, received_at DESC);

CREATE TABLE IF NOT EXISTS scm.scm_receipt_lines (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    receipt_id      text NOT NULL REFERENCES scm.scm_receipts (id) ON DELETE CASCADE,
    po_line_id      text NOT NULL REFERENCES scm.scm_purchase_order_lines (id),
    product_id      text NOT NULL,
    qty             numeric(14,3) NOT NULL CHECK (qty > 0),
    bin_id          text REFERENCES scm.scm_bins (id),
    lot_number      text,
    expiry_date     date,
    unit_cost       numeric(14,4) CHECK (unit_cost IS NULL OR unit_cost >= 0),
    variance_note   text
);
CREATE INDEX IF NOT EXISTS scm_receipt_lines_receipt_idx ON scm.scm_receipt_lines (receipt_id);
CREATE INDEX IF NOT EXISTS scm_receipt_lines_po_line_idx ON scm.scm_receipt_lines (po_line_id);

COMMIT;
