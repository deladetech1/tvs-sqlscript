-- SCM: orders and fulfilment -- what customers ordered, the stock held for them, and what
-- went out of the door.
--
--   scm_sales_orders        an order from a customer (core_platform.cp_parties, is_customer):
--                           confirmed, allocated against stock, shipped in one or more
--                           shipments, then closed
--   scm_sales_order_lines   product, quantity ordered, allocated and shipped, price and tax
--   scm_reservations        stock held for a sales order line: active until released or
--                           consumed by a shipment. Active reservations are the "reserved" side
--                           of scm_stock_balances (20261026-04).
--   scm_shipments           goods going out against a sales order; completing one writes the
--                           ledger and consumes the reservations
--   scm_shipment_lines      what went, from where, of which lot
--
-- Status lists are CHECK constraints owned by this file. Idempotent; safe to re-run.

BEGIN;

-- ================================================================= sales orders
CREATE TABLE IF NOT EXISTS scm.scm_sales_orders (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    number            text NOT NULL,
    customer_id       text NOT NULL,
    warehouse_id      text NOT NULL REFERENCES scm.scm_warehouses (id),
    status            text NOT NULL DEFAULT 'draft',
    order_date        date NOT NULL DEFAULT CURRENT_DATE,
    requested_date    date,
    currency          text NOT NULL,
    subtotal          numeric(14,2) NOT NULL DEFAULT 0,
    tax_total         numeric(14,2) NOT NULL DEFAULT 0,
    total             numeric(14,2) NOT NULL DEFAULT 0,
    notes             text,
    cancelled_reason  text,
    version           integer NOT NULL DEFAULT 1,
    idempotency_key   text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text
);
ALTER TABLE scm.scm_sales_orders DROP CONSTRAINT IF EXISTS scm_sales_orders_status_check;
ALTER TABLE scm.scm_sales_orders ADD CONSTRAINT scm_sales_orders_status_check CHECK (status IN
    ('draft', 'confirmed', 'allocated', 'partially_shipped', 'shipped', 'closed', 'cancelled'));
ALTER TABLE scm.scm_sales_orders DROP CONSTRAINT IF EXISTS scm_sales_orders_totals_check;
ALTER TABLE scm.scm_sales_orders ADD CONSTRAINT scm_sales_orders_totals_check CHECK (subtotal >= 0 AND tax_total >= 0 AND total >= 0);
CREATE UNIQUE INDEX IF NOT EXISTS scm_sales_orders_number_uq ON scm.scm_sales_orders (bus_id, number);
CREATE UNIQUE INDEX IF NOT EXISTS scm_sales_orders_idem_uq ON scm.scm_sales_orders (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS scm_sales_orders_board_idx ON scm.scm_sales_orders (bus_id, status, requested_date);
CREATE INDEX IF NOT EXISTS scm_sales_orders_customer_idx ON scm.scm_sales_orders (bus_id, customer_id, order_date DESC);

CREATE TABLE IF NOT EXISTS scm.scm_sales_order_lines (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    so_id           text NOT NULL REFERENCES scm.scm_sales_orders (id) ON DELETE CASCADE,
    line_no         integer NOT NULL,
    product_id      text NOT NULL,
    qty_ordered     numeric(14,3) NOT NULL CHECK (qty_ordered > 0),
    qty_allocated   numeric(14,3) NOT NULL DEFAULT 0 CHECK (qty_allocated >= 0),
    qty_shipped     numeric(14,3) NOT NULL DEFAULT 0 CHECK (qty_shipped >= 0),
    uom_id          text,
    unit_price      numeric(14,4) NOT NULL DEFAULT 0 CHECK (unit_price >= 0),
    tax_rate_id     text,
    tax_rate        numeric(6,3) NOT NULL DEFAULT 0 CHECK (tax_rate >= 0),
    line_total      numeric(14,2) NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX IF NOT EXISTS scm_sales_order_lines_uq ON scm.scm_sales_order_lines (so_id, line_no);
CREATE INDEX IF NOT EXISTS scm_sales_order_lines_product_idx ON scm.scm_sales_order_lines (product_id);

-- ================================================================= reservations
CREATE TABLE IF NOT EXISTS scm.scm_reservations (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    org_id          text,
    bus_id          text NOT NULL,
    so_line_id      text NOT NULL REFERENCES scm.scm_sales_order_lines (id) ON DELETE CASCADE,
    product_id      text NOT NULL,
    warehouse_id    text NOT NULL REFERENCES scm.scm_warehouses (id),
    -- '' when not pinned to a bin / a lot, matching the balance key (20261026-04).
    bin_id          text NOT NULL DEFAULT '',
    lot_id          text NOT NULL DEFAULT '',
    qty             numeric(14,3) NOT NULL CHECK (qty > 0),
    status          text NOT NULL DEFAULT 'active',
    released_at     timestamptz,
    consumed_at     timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    updated_by      text
);
ALTER TABLE scm.scm_reservations DROP CONSTRAINT IF EXISTS scm_reservations_status_check;
ALTER TABLE scm.scm_reservations ADD CONSTRAINT scm_reservations_status_check CHECK (status IN ('active', 'released', 'consumed'));
CREATE INDEX IF NOT EXISTS scm_reservations_line_idx ON scm.scm_reservations (so_line_id, status);
CREATE INDEX IF NOT EXISTS scm_reservations_stock_idx
    ON scm.scm_reservations (bus_id, product_id, warehouse_id, bin_id, lot_id) WHERE status = 'active';

-- ==================================================================== shipments
CREATE TABLE IF NOT EXISTS scm.scm_shipments (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    number            text NOT NULL,
    so_id             text NOT NULL REFERENCES scm.scm_sales_orders (id),
    warehouse_id      text NOT NULL REFERENCES scm.scm_warehouses (id),
    status            text NOT NULL DEFAULT 'draft',
    carrier_name      text,
    tracking_ref      text,
    shipped_at        timestamptz,
    delivered_at      timestamptz,
    notes             text,
    idempotency_key   text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text
);
ALTER TABLE scm.scm_shipments DROP CONSTRAINT IF EXISTS scm_shipments_status_check;
ALTER TABLE scm.scm_shipments ADD CONSTRAINT scm_shipments_status_check CHECK (status IN
    ('draft', 'packed', 'shipped', 'delivered', 'cancelled'));
CREATE UNIQUE INDEX IF NOT EXISTS scm_shipments_number_uq ON scm.scm_shipments (bus_id, number);
CREATE UNIQUE INDEX IF NOT EXISTS scm_shipments_idem_uq ON scm.scm_shipments (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS scm_shipments_so_idx ON scm.scm_shipments (so_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS scm_shipments_board_idx ON scm.scm_shipments (bus_id, status, cdatetime DESC);

CREATE TABLE IF NOT EXISTS scm.scm_shipment_lines (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    shipment_id     text NOT NULL REFERENCES scm.scm_shipments (id) ON DELETE CASCADE,
    so_line_id      text NOT NULL REFERENCES scm.scm_sales_order_lines (id),
    product_id      text NOT NULL,
    bin_id          text REFERENCES scm.scm_bins (id),
    lot_id          text REFERENCES scm.scm_lots (id),
    qty             numeric(14,3) NOT NULL CHECK (qty > 0)
);
CREATE INDEX IF NOT EXISTS scm_shipment_lines_shipment_idx ON scm.scm_shipment_lines (shipment_id);
CREATE INDEX IF NOT EXISTS scm_shipment_lines_so_line_idx ON scm.scm_shipment_lines (so_line_id);

COMMIT;
