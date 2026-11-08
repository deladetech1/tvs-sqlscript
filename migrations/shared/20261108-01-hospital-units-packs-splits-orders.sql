-- CloudHams round 8: units, packs, splits and purchase orders, as MyStoreGuard keeps them.
--
--   hospital_units              the business's units of measure (tablet, strip, box, vial, ml...):
--                               the pick list for what an item is dispensed in and packed in
--   hospital_drug_packs         an item's packs: a strip of 10 tablets, a box of 10 strips (100
--                               tablets), each with its own price and barcode. Stock is always
--                               kept in the item's smallest unit; a pack is how it is bought or sold
--   hospital_stock_splits(+lines)  stock of one item broken into another (a bulk tin of 1,000
--                               into packs of 30): taken from the source batch, a new batch of the
--                               destination with the same batch number and expiry; reversible
--                               while the new stock is untouched
--   hospital_purchase_orders(+lines, receipts, receipt lines)  ordered from a supplier in packs,
--                               approved by someone else, sent, received in parts into a store
--                               with each delivery's batch number and expiry
--   batches gain the shelf or bin they sit on, and the pack they arrived in
--
-- Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS hospital.hospital_units (
    id         text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id  text NOT NULL,
    bus_id     text NOT NULL,
    name       text NOT NULL,
    kind       text NOT NULL DEFAULT 'count' CHECK (kind IN ('count', 'pack', 'volume', 'mass', 'dose')),
    is_active  boolean NOT NULL DEFAULT true,
    sort       int NOT NULL DEFAULT 100,
    cdatetime  timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_units_name_uq ON hospital.hospital_units (bus_id, lower(name));

CREATE TABLE IF NOT EXISTS hospital.hospital_drug_packs (
    id         text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    drug_id    text NOT NULL REFERENCES hospital.hospital_drugs(id) ON DELETE CASCADE,
    name       text NOT NULL,
    size       numeric NOT NULL CHECK (size > 0),
    price      numeric(14,2) CHECK (price >= 0),
    barcode    text,
    buy        boolean NOT NULL DEFAULT true,
    sell       boolean NOT NULL DEFAULT true,
    is_active  boolean NOT NULL DEFAULT true,
    sort       int NOT NULL DEFAULT 0,
    cdatetime  timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_drug_packs_name_uq ON hospital.hospital_drug_packs (drug_id, lower(name));

ALTER TABLE hospital.hospital_stock_batches ADD COLUMN IF NOT EXISTS bin text;
ALTER TABLE hospital.hospital_stock_batches ADD COLUMN IF NOT EXISTS pack_name text;
ALTER TABLE hospital.hospital_stock_batches ADD COLUMN IF NOT EXISTS pack_size numeric;

SELECT hospital.widen_check('hospital.hospital_stock_moves', 'hospital_stock_moves_kind_check', $q$'split_in'$q$,
    $q$CHECK (kind IN ('receive', 'dispense', 'adjust', 'return', 'expire', 'damage', 'transfer_out', 'transfer_in', 'count', 'return_supplier',
      'split_out', 'split_in'))$q$);

-- ======================================================================= splits
CREATE TABLE IF NOT EXISTS hospital.hospital_stock_splits (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    facility_id  text NOT NULL REFERENCES hospital.hospital_facilities(id),
    store_id     text NOT NULL REFERENCES hospital.hospital_stores(id),
    number       text NOT NULL,
    description  text,
    status       text NOT NULL DEFAULT 'done' CHECK (status IN ('done', 'reversed')),
    created_by   text,
    reversed_by  text, reversed_at timestamptz, reverse_reason text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_splits_number_uq ON hospital.hospital_stock_splits (bus_id, number);

CREATE TABLE IF NOT EXISTS hospital.hospital_stock_split_lines (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    split_id         text NOT NULL REFERENCES hospital.hospital_stock_splits(id) ON DELETE CASCADE,
    source_drug_id   text NOT NULL REFERENCES hospital.hospital_drugs(id),
    source_batch_id  text NOT NULL REFERENCES hospital.hospital_stock_batches(id),
    source_qty       numeric NOT NULL CHECK (source_qty > 0),
    divisor          numeric NOT NULL CHECK (divisor > 0),
    dest_drug_id     text NOT NULL REFERENCES hospital.hospital_drugs(id),
    dest_batch_id    text NOT NULL REFERENCES hospital.hospital_stock_batches(id),
    dest_qty         numeric NOT NULL CHECK (dest_qty > 0),
    unit_cost        numeric(14,4) NOT NULL DEFAULT 0,
    unit_price       numeric(14,2)
);

-- ======================================================================= purchase orders
CREATE TABLE IF NOT EXISTS hospital.hospital_purchase_orders (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    facility_id    text NOT NULL REFERENCES hospital.hospital_facilities(id),
    number         text NOT NULL,
    supplier       text NOT NULL,
    supplier_id    text,
    supplier_email text,
    supplier_phone text,
    store_id       text NOT NULL REFERENCES hospital.hospital_stores(id),
    status         text NOT NULL DEFAULT 'draft'
                   CHECK (status IN ('draft', 'approved', 'sent', 'part_received', 'received', 'cancelled', 'closed')),
    expected_on    date,
    reference      text,
    notes          text,
    total          numeric(14,2) NOT NULL DEFAULT 0,
    cancel_reason  text,
    created_by     text,
    approved_by    text, approved_at timestamptz,
    sent_by        text, sent_at     timestamptz,
    closed_by      text, closed_at   timestamptz,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_pos_number_uq ON hospital.hospital_purchase_orders (bus_id, number);
CREATE INDEX IF NOT EXISTS hospital_pos_facility_idx ON hospital.hospital_purchase_orders (facility_id, cdatetime DESC);

CREATE TABLE IF NOT EXISTS hospital.hospital_po_lines (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    po_id         text NOT NULL REFERENCES hospital.hospital_purchase_orders(id) ON DELETE CASCADE,
    drug_id       text NOT NULL REFERENCES hospital.hospital_drugs(id),
    pack_name     text NOT NULL,
    pack_size     numeric NOT NULL CHECK (pack_size > 0),
    quantity      numeric NOT NULL CHECK (quantity > 0),
    unit_cost     numeric(14,4) NOT NULL DEFAULT 0 CHECK (unit_cost >= 0),
    received_qty  numeric NOT NULL DEFAULT 0 CHECK (received_qty >= 0),
    sort          int NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_po_lines_uq ON hospital.hospital_po_lines (po_id, drug_id, lower(pack_name));

CREATE TABLE IF NOT EXISTS hospital.hospital_po_receipts (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    po_id        text NOT NULL REFERENCES hospital.hospital_purchase_orders(id) ON DELETE CASCADE,
    number       text NOT NULL,
    invoice_no   text,
    note         text,
    received_by  text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS hospital.hospital_po_receipt_lines (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    receipt_id  text NOT NULL REFERENCES hospital.hospital_po_receipts(id) ON DELETE CASCADE,
    line_id     text NOT NULL REFERENCES hospital.hospital_po_lines(id),
    quantity    numeric NOT NULL CHECK (quantity > 0),
    batch_id    text NOT NULL REFERENCES hospital.hospital_stock_batches(id),
    batch_no    text NOT NULL,
    expires_on  date NOT NULL,
    unit_cost   numeric(14,4) NOT NULL
);

COMMIT;
