-- SCM: master data and settings -- what a business stocks, who it buys from, and where it
-- keeps things.
--
--   scm_settings           one per business: currency, approval policy, stock rules
--   scm_number_series      the next REQ-, PO-, GRN-, ADJ-, TRF-, SO- and SHP- number per business
--   scm_item_settings      SCM's own row for a product it stocks: unit, tracking, reorder rules,
--                          standard cost. The product itself is core_platform.cp_products.
--   scm_items              VIEW: cp_products joined to scm_item_settings -- what SCM lists
--   scm_supplier_profiles  SCM's own fields for a supplier (lead time, terms, OTIF rating). The
--                          supplier itself is core_platform.cp_parties with is_supplier.
--   scm_supplier_items     a supplier's price list: what it charges for a product
--   scm_warehouses         a store, depot or yard; may sit at a Core Platform location
--   scm_bins               a storage place inside a warehouse
--
-- Suppliers, customers and products are shared across the suite (docs/SHARED_PARTIES.md), so
-- every column here or in a later SCM file that holds a party id or a product id is registered
-- in cp_party_references / cp_product_references. Both are plain tables and the merge
-- functions skip a table that does not exist yet, so every SCM column is registered here, the
-- ones of tables that 20261026-03..06 create included.
--
-- Every row belongs to a business (bus_id) of a tenant; the API limits every query to the
-- caller's business. Status lists are CHECK constraints owned by this file (dropped and re-added
-- on every run). Idempotent; safe to re-run.

BEGIN;

-- ===================================================================== settings
CREATE TABLE IF NOT EXISTS scm.scm_settings (
    bus_id                          text PRIMARY KEY,
    tenant_id                       text NOT NULL,
    org_id                          text,
    base_currency                   text NOT NULL DEFAULT 'GHS',
    default_warehouse_id            text,
    requisition_approval_required   boolean NOT NULL DEFAULT true,
    -- NULL: every purchase order needs approval; 0: none does; else orders at or above it do.
    po_approval_threshold           numeric(14,2),
    allow_negative_stock            boolean NOT NULL DEFAULT false,
    onboarded_at                    timestamptz,
    updated_at                      timestamptz NOT NULL DEFAULT now(),
    updated_by                      text
);
ALTER TABLE scm.scm_settings DROP CONSTRAINT IF EXISTS scm_settings_po_approval_threshold_check;
ALTER TABLE scm.scm_settings ADD CONSTRAINT scm_settings_po_approval_threshold_check
    CHECK (po_approval_threshold IS NULL OR po_approval_threshold >= 0);

CREATE TABLE IF NOT EXISTS scm.scm_number_series (
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    kind         text NOT NULL,
    prefix       text NOT NULL,
    next_number  integer NOT NULL DEFAULT 1,
    padding      integer NOT NULL DEFAULT 5,
    PRIMARY KEY (bus_id, kind)
);
-- The kind list (scm_number_series_kind_check) is owned by 20261026-09, which added the return
-- and stock-count series: a CHECK list lives in the newest file that touches it.
ALTER TABLE scm.scm_number_series DROP CONSTRAINT IF EXISTS scm_number_series_next_number_check;
ALTER TABLE scm.scm_number_series ADD CONSTRAINT scm_number_series_next_number_check CHECK (next_number > 0);
ALTER TABLE scm.scm_number_series DROP CONSTRAINT IF EXISTS scm_number_series_padding_check;
ALTER TABLE scm.scm_number_series ADD CONSTRAINT scm_number_series_padding_check CHECK (padding BETWEEN 0 AND 12);
-- The defaults the API seeds at onboarding, stated once where the API can read them.
COMMENT ON TABLE scm.scm_number_series IS
    'Document numbering per business and kind. Defaults: requisition REQ-, purchase_order PO-, receipt GRN-, adjustment ADJ-, transfer TRF-, sales_order SO-, shipment SHP-; padding 5. Taken with SELECT ... FOR UPDATE.';

-- ======================================================================== items
CREATE TABLE IF NOT EXISTS scm.scm_item_settings (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    product_id       text NOT NULL REFERENCES core_platform.cp_products (id) ON DELETE CASCADE,
    uom_id           text,
    tracking         text NOT NULL DEFAULT 'none',
    reorder_point    numeric(14,3),
    reorder_qty      numeric(14,3),
    safety_stock     numeric(14,3),
    min_order_qty    numeric(14,3),
    lead_time_days   integer,
    standard_cost    numeric(14,4),
    is_active        boolean NOT NULL DEFAULT true,
    archived_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz NOT NULL DEFAULT now(),
    updated_by       text
);
ALTER TABLE scm.scm_item_settings DROP CONSTRAINT IF EXISTS scm_item_settings_tracking_check;
ALTER TABLE scm.scm_item_settings ADD CONSTRAINT scm_item_settings_tracking_check CHECK (tracking IN ('none', 'lot', 'serial'));
ALTER TABLE scm.scm_item_settings DROP CONSTRAINT IF EXISTS scm_item_settings_quantities_check;
ALTER TABLE scm.scm_item_settings ADD CONSTRAINT scm_item_settings_quantities_check CHECK (
    (reorder_point IS NULL OR reorder_point >= 0) AND (reorder_qty IS NULL OR reorder_qty >= 0)
    AND (safety_stock IS NULL OR safety_stock >= 0) AND (min_order_qty IS NULL OR min_order_qty >= 0)
    AND (lead_time_days IS NULL OR lead_time_days >= 0) AND (standard_cost IS NULL OR standard_cost >= 0));
CREATE UNIQUE INDEX IF NOT EXISTS scm_item_settings_product_uq ON scm.scm_item_settings (bus_id, product_id);
CREATE INDEX IF NOT EXISTS scm_item_settings_business_idx ON scm.scm_item_settings (tenant_id, bus_id) WHERE archived_at IS NULL;

-- What SCM lists: a product is in SCM when SCM has its row. id is the product's id, so every
-- document line's product_id is both a cp_products id and an scm_items id.
CREATE OR REPLACE VIEW scm.scm_items AS
SELECT p.id,
       s.tenant_id,
       coalesce(s.org_id, p.org_id) AS org_id,
       s.bus_id,
       p.name, p.sku, p.barcode, p.code, p.description, p.category, p.kind, p.parent_id, p.variant, p.unit,
       s.id AS settings_id,
       s.uom_id, s.tracking, s.reorder_point, s.reorder_qty, s.safety_stock, s.min_order_qty,
       s.lead_time_days, s.standard_cost, s.is_active, s.archived_at,
       s.cdatetime, s.updated_at
  FROM scm.scm_item_settings s
  JOIN core_platform.cp_products p ON p.id = s.product_id AND p.bus_id = s.bus_id;

-- ==================================================================== suppliers
CREATE TABLE IF NOT EXISTS scm.scm_supplier_profiles (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    org_id              text,
    bus_id              text NOT NULL,
    party_id            text NOT NULL REFERENCES core_platform.cp_parties (id) ON DELETE CASCADE,
    lead_time_days      integer,
    min_order_value     numeric(14,2),
    currency            text,
    payment_terms_days  integer,
    rating_otif         numeric(5,2),
    notes               text,
    archived_at         timestamptz,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    created_by          text,
    updated_at          timestamptz NOT NULL DEFAULT now(),
    updated_by          text
);
ALTER TABLE scm.scm_supplier_profiles DROP CONSTRAINT IF EXISTS scm_supplier_profiles_values_check;
ALTER TABLE scm.scm_supplier_profiles ADD CONSTRAINT scm_supplier_profiles_values_check CHECK (
    (lead_time_days IS NULL OR lead_time_days >= 0) AND (min_order_value IS NULL OR min_order_value >= 0)
    AND (payment_terms_days IS NULL OR payment_terms_days BETWEEN 0 AND 3650)
    AND (rating_otif IS NULL OR rating_otif BETWEEN 0 AND 100));
CREATE UNIQUE INDEX IF NOT EXISTS scm_supplier_profiles_party_uq ON scm.scm_supplier_profiles (bus_id, party_id);

CREATE TABLE IF NOT EXISTS scm.scm_supplier_items (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    party_id         text NOT NULL REFERENCES core_platform.cp_parties (id) ON DELETE RESTRICT,
    product_id       text NOT NULL REFERENCES core_platform.cp_products (id) ON DELETE CASCADE,
    supplier_sku     text,
    unit_price       numeric(14,4) NOT NULL CHECK (unit_price >= 0),
    currency         text NOT NULL,
    lead_time_days   integer CHECK (lead_time_days IS NULL OR lead_time_days >= 0),
    min_order_qty    numeric(14,3) CHECK (min_order_qty IS NULL OR min_order_qty >= 0),
    is_preferred     boolean NOT NULL DEFAULT false,
    archived_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz NOT NULL DEFAULT now(),
    updated_by       text
);
CREATE UNIQUE INDEX IF NOT EXISTS scm_supplier_items_uq ON scm.scm_supplier_items (bus_id, party_id, product_id);
CREATE INDEX IF NOT EXISTS scm_supplier_items_product_idx ON scm.scm_supplier_items (bus_id, product_id) WHERE archived_at IS NULL;

-- =================================================================== warehouses
CREATE TABLE IF NOT EXISTS scm.scm_warehouses (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    code             text NOT NULL,
    name             text NOT NULL,
    location_id      text,
    address_line1    text,
    address_line2    text,
    city             text,
    region           text,
    postal_code      text,
    country          char(2),
    is_active        boolean NOT NULL DEFAULT true,
    archived_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz NOT NULL DEFAULT now(),
    updated_by       text
);
CREATE UNIQUE INDEX IF NOT EXISTS scm_warehouses_code_uq ON scm.scm_warehouses (bus_id, lower(code)) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS scm_warehouses_business_idx ON scm.scm_warehouses (tenant_id, bus_id);

CREATE TABLE IF NOT EXISTS scm.scm_bins (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    warehouse_id     text NOT NULL REFERENCES scm.scm_warehouses (id) ON DELETE CASCADE,
    code             text NOT NULL,
    zone             text,
    kind             text NOT NULL DEFAULT 'storage',
    is_active        boolean NOT NULL DEFAULT true,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz NOT NULL DEFAULT now(),
    updated_by       text
);
ALTER TABLE scm.scm_bins DROP CONSTRAINT IF EXISTS scm_bins_kind_check;
ALTER TABLE scm.scm_bins ADD CONSTRAINT scm_bins_kind_check CHECK (kind IN ('storage', 'receiving', 'shipping', 'quarantine'));
CREATE UNIQUE INDEX IF NOT EXISTS scm_bins_code_uq ON scm.scm_bins (warehouse_id, lower(code));
CREATE INDEX IF NOT EXISTS scm_bins_business_idx ON scm.scm_bins (bus_id, warehouse_id);

-- ============================================== where SCM holds a party or a product
-- An extension is SCM's own row for the party or product: a merge moves it (or drops the
-- loser's when the keeper has one) and it does not stop the record being deleted. Everything
-- else is a use: it is moved by a merge and keeps the record alive.
INSERT INTO core_platform.cp_party_references (table_name, column_name, is_extension) VALUES
    ('scm.scm_supplier_profiles', 'party_id', true)
ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;
INSERT INTO core_platform.cp_party_references (table_name, column_name, is_extension) VALUES
    ('scm.scm_supplier_items',     'party_id',              false),
    ('scm.scm_requisition_lines',  'preferred_supplier_id', false),
    ('scm.scm_purchase_orders',    'supplier_id',           false),
    ('scm.scm_sales_orders',       'customer_id',           false),
    ('scm.scm_lots',               'supplier_id',           false)
ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;

INSERT INTO core_platform.cp_product_references (table_name, column_name, is_extension) VALUES
    ('scm.scm_item_settings', 'product_id', true)
ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;
INSERT INTO core_platform.cp_product_references (table_name, column_name, is_extension) VALUES
    ('scm.scm_supplier_items',       'product_id', false),
    ('scm.scm_requisition_lines',    'product_id', false),
    ('scm.scm_purchase_order_lines', 'product_id', false),
    ('scm.scm_receipt_lines',        'product_id', false),
    ('scm.scm_lots',                 'product_id', false),
    ('scm.scm_inventory_movements',  'product_id', false),
    ('scm.scm_stock_balances',       'product_id', false),
    ('scm.scm_adjustment_lines',     'product_id', false),
    ('scm.scm_transfer_lines',       'product_id', false),
    ('scm.scm_sales_order_lines',    'product_id', false),
    ('scm.scm_reservations',         'product_id', false),
    ('scm.scm_shipment_lines',       'product_id', false)
ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;

-- ===================================================================== invariants
DO $$
BEGIN
    IF to_regclass('scm.scm_items') IS NULL OR (SELECT relkind FROM pg_class WHERE oid = 'scm.scm_items'::regclass) <> 'v' THEN
        RAISE EXCEPTION 'scm.scm_items is not a view';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM core_platform.cp_party_references WHERE table_name = 'scm.scm_supplier_profiles' AND column_name = 'party_id' AND is_extension)
       OR NOT EXISTS (SELECT 1 FROM core_platform.cp_product_references WHERE table_name = 'scm.scm_item_settings' AND column_name = 'product_id' AND is_extension) THEN
        RAISE EXCEPTION 'SCM''s own supplier and item rows are not registered as extensions; a merge would refuse them';
    END IF;
END $$;

COMMIT;
