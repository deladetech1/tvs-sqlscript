-- HMS restaurant and bar, for a place that runs mainly as a restaurant:
--
--   * delivery: areas delivered to, each with its fee (free above an amount, a minimum order and
--     how long it takes); an order carries the address, a landmark, the area, the fee and the
--     rider, and when it was ready, sent out and delivered;
--   * order ahead: due_at is when the customer wants it; its lines wait until it is time to start;
--   * delivery apps (Bolt Food, Glovo, Chowdeck...): the apps a property sells through, with each
--     one's commission; an order names its app and the app's own order number;
--   * bar tabs: an order run under a name, at the bar or a table, with what is held for it;
--   * texts to the customer when the order is ready or on its way (hms_settings.order_texts).
--
-- No CHECK constraint is widened here: earlier files re-create theirs on every deploy, so a tab is
-- a flag on the order, and an app's payout is taken as method 'other'. Idempotent.

BEGIN;

CREATE TABLE IF NOT EXISTS hms.hms_delivery_zones (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    property_id   text NOT NULL REFERENCES hms.hms_properties (id),
    name          text NOT NULL,
    -- The places it covers, as a customer would say them (East Legon, Airport Residential...).
    areas         text,
    fee           numeric(14,2) NOT NULL DEFAULT 0 CHECK (fee >= 0),
    min_order     numeric(14,2) CHECK (min_order IS NULL OR min_order >= 0),
    free_over     numeric(14,2) CHECK (free_over IS NULL OR free_over >= 0),
    minutes       int CHECK (minutes IS NULL OR minutes BETWEEN 1 AND 600),
    active        boolean NOT NULL DEFAULT true,
    sort_order    int NOT NULL DEFAULT 0,
    archived_at   timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_delivery_zones_name_uq ON hms.hms_delivery_zones (property_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS hms.hms_sales_channels (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    bus_id              text NOT NULL,
    property_id         text NOT NULL REFERENCES hms.hms_properties (id),
    -- bolt_food, glovo, chowdeck, jumia_food, uber_eats, other
    app                 text NOT NULL,
    name                text NOT NULL,
    commission_percent  numeric(5,2) NOT NULL DEFAULT 0 CHECK (commission_percent BETWEEN 0 AND 100),
    active              boolean NOT NULL DEFAULT true,
    archived_at         timestamptz,
    cdatetime           timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_sales_channels_name_uq ON hms.hms_sales_channels (property_id, lower(name)) WHERE archived_at IS NULL;

ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS delivery_address text;
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS delivery_landmark text;
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS delivery_zone_id text REFERENCES hms.hms_delivery_zones (id);
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS delivery_fee numeric(14,2) NOT NULL DEFAULT 0;
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS rider_name text;
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS rider_phone text;
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS ready_at timestamptz;
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS dispatched_at timestamptz;
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS ready_texted_at timestamptz;
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS dispatch_texted_at timestamptz;
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS due_at timestamptz;
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS channel_id text REFERENCES hms.hms_sales_channels (id);
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS channel_ref text;
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS commission_percent numeric(5,2) NOT NULL DEFAULT 0;
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS is_tab boolean NOT NULL DEFAULT false;
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS tab_holding text;
ALTER TABLE hms.hms_orders DROP CONSTRAINT IF EXISTS hms_orders_delivery_fee_check;
ALTER TABLE hms.hms_orders ADD CONSTRAINT hms_orders_delivery_fee_check CHECK (delivery_fee >= 0);
CREATE INDEX IF NOT EXISTS hms_orders_due_idx ON hms.hms_orders (due_at) WHERE due_at IS NOT NULL AND status IN ('open', 'part_paid');
CREATE INDEX IF NOT EXISTS hms_orders_tabs_idx ON hms.hms_orders (property_id) WHERE is_tab AND status IN ('open', 'part_paid');

ALTER TABLE hms.hms_settings ADD COLUMN IF NOT EXISTS order_texts boolean NOT NULL DEFAULT true;

COMMIT;
