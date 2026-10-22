-- HMS, the rest of the restaurant and the stores: modifiers, a floor plan, split bills, recipes,
-- stock in every store, purchase orders and receiving.
--
--   hms_menu_modifiers     add-ons and sizes for a dish, each with its own price
--   hms_order_payments     how an order was paid: one payment, or several (split bills)
--   hms_stock_locations    where stock is kept: the main store, the kitchen, the bar, housekeeping
--   hms_stock_items        what is kept: ingredients, drinks, linen, amenities, spare parts
--   hms_stock_levels       how much of an item is in each place
--   hms_stock_movements    every change: received, issued, sold, wasted, counted, moved
--   hms_recipe_lines       what one portion of a dish uses, taken from stock when it is sent
--   hms_purchase_orders    what is ordered from a supplier (a cp_parties supplier)
--   hms_po_lines           its lines, and how much of each has arrived
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS hms.hms_menu_modifiers (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    menu_item_id  text NOT NULL REFERENCES hms.hms_menu_items (id),
    group_name    text NOT NULL DEFAULT 'Extras',
    name          text NOT NULL,
    price_delta   numeric(14,2) NOT NULL DEFAULT 0,
    sort_order    int NOT NULL DEFAULT 0,
    archived_at   timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS hms_menu_modifiers_item_idx ON hms.hms_menu_modifiers (menu_item_id) WHERE archived_at IS NULL;

ALTER TABLE hms.hms_order_items ADD COLUMN IF NOT EXISTS modifiers jsonb NOT NULL DEFAULT '[]';
ALTER TABLE hms.hms_order_items ADD COLUMN IF NOT EXISTS seat int;
ALTER TABLE hms.hms_order_items ADD COLUMN IF NOT EXISTS stock_deducted boolean NOT NULL DEFAULT false;
ALTER TABLE hms.hms_menu_items ADD COLUMN IF NOT EXISTS sku text;

-- The floor plan: where a table stands and how it is drawn.
ALTER TABLE hms.hms_tables ADD COLUMN IF NOT EXISTS pos_x int NOT NULL DEFAULT 0;
ALTER TABLE hms.hms_tables ADD COLUMN IF NOT EXISTS pos_y int NOT NULL DEFAULT 0;
ALTER TABLE hms.hms_tables ADD COLUMN IF NOT EXISTS shape text NOT NULL DEFAULT 'square';
ALTER TABLE hms.hms_tables DROP CONSTRAINT IF EXISTS hms_tables_shape_check;
ALTER TABLE hms.hms_tables ADD CONSTRAINT hms_tables_shape_check CHECK (shape IN ('square', 'round', 'long'));

-- An order is paid by one or more payments; settled once they cover it. A room charge is a
-- payment whose method is "room" and which names the folio line it posted.
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS company_id text;
ALTER TABLE hms.hms_orders DROP CONSTRAINT IF EXISTS hms_orders_status_check;
ALTER TABLE hms.hms_orders ADD CONSTRAINT hms_orders_status_check CHECK (status IN ('open', 'part_paid', 'settled', 'charged_to_room', 'void'));
ALTER TABLE hms.hms_orders DROP CONSTRAINT IF EXISTS hms_orders_settled_method_check;
ALTER TABLE hms.hms_orders ADD CONSTRAINT hms_orders_settled_method_check CHECK (settled_method IS NULL OR settled_method IN
    ('cash', 'card', 'momo', 'bank', 'other', 'room', 'company', 'split'));

CREATE TABLE IF NOT EXISTS hms.hms_order_payments (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    order_id         text NOT NULL REFERENCES hms.hms_orders (id),
    amount           numeric(14,2) NOT NULL CHECK (amount > 0),
    tip              numeric(14,2) NOT NULL DEFAULT 0 CHECK (tip >= 0),
    method           text NOT NULL,
    reference        text,
    -- Which lines this payment is for, when a bill is split by item.
    item_ids         text[] NOT NULL DEFAULT '{}',
    reservation_id   text REFERENCES hms.hms_reservations (id),
    folio_line_id    text REFERENCES hms.hms_folio_lines (id),
    cash_session_id  text REFERENCES hms.hms_cash_sessions (id),
    voided_at        timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
ALTER TABLE hms.hms_order_payments DROP CONSTRAINT IF EXISTS hms_order_payments_method_check;
ALTER TABLE hms.hms_order_payments ADD CONSTRAINT hms_order_payments_method_check CHECK (method IN ('cash', 'card', 'momo', 'bank', 'other', 'room', 'company'));
CREATE INDEX IF NOT EXISTS hms_order_payments_order_idx ON hms.hms_order_payments (order_id);
-- A room charge posts to a bill once; the old one-charge-per-order rule gives way to this.
DROP INDEX IF EXISTS hms.hms_folio_lines_order_uq;
CREATE UNIQUE INDEX IF NOT EXISTS hms_folio_lines_order_payment_uq ON hms.hms_folio_lines (source_id)
    WHERE source_type IN ('restaurant_order', 'order_payment', 'activity_booking') AND reverses_line_id IS NULL;

-- --------------------------------------------------------------------- stores
CREATE TABLE IF NOT EXISTS hms.hms_stock_locations (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    property_id   text NOT NULL REFERENCES hms.hms_properties (id),
    name          text NOT NULL,
    kind          text NOT NULL DEFAULT 'store',
    archived_at   timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hms.hms_stock_locations DROP CONSTRAINT IF EXISTS hms_stock_locations_kind_check;
ALTER TABLE hms.hms_stock_locations ADD CONSTRAINT hms_stock_locations_kind_check CHECK (kind IN ('store', 'kitchen', 'bar', 'housekeeping', 'maintenance', 'retail'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_stock_locations_name_uq ON hms.hms_stock_locations (property_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS hms.hms_stock_items (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    name            text NOT NULL,
    sku             text,
    barcode         text,
    category        text NOT NULL DEFAULT 'food',
    unit            text NOT NULL DEFAULT 'each',
    avg_cost        numeric(14,4) NOT NULL DEFAULT 0 CHECK (avg_cost >= 0),
    reorder_level   numeric(14,3) NOT NULL DEFAULT 0 CHECK (reorder_level >= 0),
    reorder_qty     numeric(14,3) NOT NULL DEFAULT 0 CHECK (reorder_qty >= 0),
    supplier_id     text,
    archived_at     timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
ALTER TABLE hms.hms_stock_items DROP CONSTRAINT IF EXISTS hms_stock_items_category_check;
ALTER TABLE hms.hms_stock_items ADD CONSTRAINT hms_stock_items_category_check CHECK (category IN
    ('food', 'beverage', 'linen', 'amenity', 'cleaning', 'maintenance', 'retail', 'other'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_stock_items_name_uq ON hms.hms_stock_items (bus_id, lower(name)) WHERE archived_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS hms_stock_items_barcode_uq ON hms.hms_stock_items (bus_id, barcode) WHERE barcode IS NOT NULL AND archived_at IS NULL;

CREATE TABLE IF NOT EXISTS hms.hms_stock_levels (
    item_id       text NOT NULL REFERENCES hms.hms_stock_items (id),
    location_id   text NOT NULL REFERENCES hms.hms_stock_locations (id),
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    qty           numeric(14,3) NOT NULL DEFAULT 0,
    updated_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (item_id, location_id)
);

CREATE TABLE IF NOT EXISTS hms.hms_stock_movements (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    item_id         text NOT NULL REFERENCES hms.hms_stock_items (id),
    location_id     text NOT NULL REFERENCES hms.hms_stock_locations (id),
    kind            text NOT NULL,
    qty             numeric(14,3) NOT NULL,
    unit_cost       numeric(14,4),
    reference_type  text,
    reference_id    text,
    note            text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
ALTER TABLE hms.hms_stock_movements DROP CONSTRAINT IF EXISTS hms_stock_movements_kind_check;
ALTER TABLE hms.hms_stock_movements ADD CONSTRAINT hms_stock_movements_kind_check CHECK (kind IN
    ('receipt', 'issue', 'sale', 'waste', 'adjust', 'count', 'transfer_in', 'transfer_out', 'complimentary', 'return'));
CREATE INDEX IF NOT EXISTS hms_stock_movements_item_idx ON hms.hms_stock_movements (item_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS hms_stock_movements_bus_idx ON hms.hms_stock_movements (bus_id, cdatetime DESC);

CREATE TABLE IF NOT EXISTS hms.hms_recipe_lines (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    menu_item_id    text NOT NULL REFERENCES hms.hms_menu_items (id),
    stock_item_id   text NOT NULL REFERENCES hms.hms_stock_items (id),
    qty             numeric(14,4) NOT NULL CHECK (qty > 0)
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_recipe_lines_uq ON hms.hms_recipe_lines (menu_item_id, stock_item_id);
-- Where the kitchen and the bar take their stock from.
ALTER TABLE hms.hms_menu_items ADD COLUMN IF NOT EXISTS stock_location_id text REFERENCES hms.hms_stock_locations (id);

CREATE TABLE IF NOT EXISTS hms.hms_purchase_orders (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    org_id          text,
    bus_id          text NOT NULL,
    property_id     text NOT NULL REFERENCES hms.hms_properties (id),
    location_id     text NOT NULL REFERENCES hms.hms_stock_locations (id),
    number          int NOT NULL,
    supplier_id     text NOT NULL,
    status          text NOT NULL DEFAULT 'draft',
    expected_on     date,
    notes           text,
    approved_by     text,
    approved_at     timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
ALTER TABLE hms.hms_purchase_orders DROP CONSTRAINT IF EXISTS hms_purchase_orders_status_check;
ALTER TABLE hms.hms_purchase_orders ADD CONSTRAINT hms_purchase_orders_status_check CHECK (status IN
    ('draft', 'submitted', 'approved', 'partly_received', 'received', 'cancelled'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_purchase_orders_number_uq ON hms.hms_purchase_orders (bus_id, number);

CREATE TABLE IF NOT EXISTS hms.hms_po_lines (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    po_id           text NOT NULL REFERENCES hms.hms_purchase_orders (id) ON DELETE CASCADE,
    item_id         text NOT NULL REFERENCES hms.hms_stock_items (id),
    qty             numeric(14,3) NOT NULL CHECK (qty > 0),
    unit_cost       numeric(14,4) NOT NULL CHECK (unit_cost >= 0),
    received_qty    numeric(14,3) NOT NULL DEFAULT 0 CHECK (received_qty >= 0)
);
CREATE INDEX IF NOT EXISTS hms_po_lines_po_idx ON hms.hms_po_lines (po_id);

COMMIT;
