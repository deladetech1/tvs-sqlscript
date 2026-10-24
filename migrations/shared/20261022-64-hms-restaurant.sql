-- HMS restaurant and bar: the menu, the tables and the orders taken at them.
--
--   hms_menu_categories  starters, mains, drinks...
--   hms_menu_items       what can be ordered, at what price, made at which station
--   hms_tables           where people sit
--   hms_orders           one order: dine-in, takeaway, delivery or room service
--   hms_order_items      its lines, with the price as it was when ordered
--
-- An order is settled at the till or charged to a guest's room; a room charge is a folio line
-- whose source is the order (hms_folio_lines source_type 'restaurant_order'), so it posts once
-- and links back. Stock and recipes come later.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS hms.hms_menu_categories (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    name             text NOT NULL,
    sort_order       int NOT NULL DEFAULT 0,
    archived_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_menu_categories_name_uq
    ON hms.hms_menu_categories (property_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS hms.hms_menu_items (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    category_id      text REFERENCES hms.hms_menu_categories (id),
    name             text NOT NULL,
    description      text,
    price            numeric(14,2) NOT NULL CHECK (price >= 0),
    station          text NOT NULL DEFAULT 'kitchen',
    is_available     boolean NOT NULL DEFAULT true,
    archived_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
ALTER TABLE hms.hms_menu_items DROP CONSTRAINT IF EXISTS hms_menu_items_station_check;
ALTER TABLE hms.hms_menu_items ADD CONSTRAINT hms_menu_items_station_check CHECK (station IN ('kitchen', 'bar', 'none'));
CREATE INDEX IF NOT EXISTS hms_menu_items_property_idx ON hms.hms_menu_items (property_id, category_id);

CREATE TABLE IF NOT EXISTS hms.hms_tables (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    name             text NOT NULL,
    seats            int NOT NULL DEFAULT 4 CHECK (seats > 0),
    area             text,
    archived_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_tables_name_uq
    ON hms.hms_tables (property_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS hms.hms_orders (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    number           int NOT NULL,
    kind             text NOT NULL DEFAULT 'dine_in',
    status           text NOT NULL DEFAULT 'open',
    table_id         text REFERENCES hms.hms_tables (id),
    customer_name    text,
    reservation_id   text REFERENCES hms.hms_reservations (id),
    folio_line_id    text REFERENCES hms.hms_folio_lines (id),
    settled_method   text,
    settled_reference text,
    tip              numeric(14,2) NOT NULL DEFAULT 0 CHECK (tip >= 0),
    discount         numeric(14,2) NOT NULL DEFAULT 0 CHECK (discount >= 0),
    void_reason      text,
    notes            text,
    opened_by        text,
    settled_by       text,
    settled_at       timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hms.hms_orders DROP CONSTRAINT IF EXISTS hms_orders_kind_check;
ALTER TABLE hms.hms_orders ADD CONSTRAINT hms_orders_kind_check CHECK (kind IN ('dine_in', 'takeaway', 'delivery', 'room_service'));
-- Created here; widened by a later migration, which owns it from then on (every file re-runs on each deploy).
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'hms_orders_status_check' AND conrelid = 'hms.hms_orders'::regclass) THEN
    ALTER TABLE hms.hms_orders ADD CONSTRAINT hms_orders_status_check CHECK (status IN ('open', 'settled', 'charged_to_room', 'void'));
  END IF;
END $$;
-- Created here; widened by a later migration, which owns it from then on (every file re-runs on each deploy).
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'hms_orders_settled_method_check' AND conrelid = 'hms.hms_orders'::regclass) THEN
    ALTER TABLE hms.hms_orders ADD CONSTRAINT hms_orders_settled_method_check CHECK (settled_method IS NULL OR settled_method IN
        ('cash', 'card', 'momo', 'bank', 'other'));
  END IF;
END $$;
CREATE UNIQUE INDEX IF NOT EXISTS hms_orders_number_uq ON hms.hms_orders (property_id, number);
CREATE INDEX IF NOT EXISTS hms_orders_board_idx ON hms.hms_orders (bus_id, property_id, status, cdatetime DESC);

CREATE TABLE IF NOT EXISTS hms.hms_order_items (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    order_id         text NOT NULL REFERENCES hms.hms_orders (id),
    menu_item_id     text REFERENCES hms.hms_menu_items (id),
    name             text NOT NULL,
    station          text NOT NULL DEFAULT 'kitchen',
    unit_price       numeric(14,2) NOT NULL CHECK (unit_price >= 0),
    quantity         int NOT NULL CHECK (quantity > 0),
    notes            text,
    kitchen_status   text NOT NULL DEFAULT 'new',
    voided_at        timestamptz,
    voided_by        text,
    void_reason      text,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hms.hms_order_items DROP CONSTRAINT IF EXISTS hms_order_items_kitchen_status_check;
ALTER TABLE hms.hms_order_items ADD CONSTRAINT hms_order_items_kitchen_status_check CHECK (kitchen_status IN ('new', 'preparing', 'ready', 'served'));
CREATE INDEX IF NOT EXISTS hms_order_items_order_idx ON hms.hms_order_items (order_id);

COMMIT;
