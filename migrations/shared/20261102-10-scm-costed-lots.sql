-- SCM: every stock-in is a costed lot, valued FIFO at actual cost (MSG <-> SCM plan, phase 1).
--
-- MyStoreGuard keeps stock per delivery line (a batch carrying its own cost and expiry) and
-- sells it first in, first out. SCM now does the same:
--
--   scm_lots                 gains its cost: unit_cost (in currency, the document's), cost_basis
--                            ('actual' from a receipt or the posting, 'standard' when only the
--                            item's standard cost was known, 'none'), origin (what made it),
--                            is_opening (made by this file's backfill), numbered (false: a lot
--                            the system made for an item not tracked by lot -- one per receipt
--                            line; the person never types its number), receipt_id /
--                            receipt_line_id, qty_received.
--   scm_lot_stock            how much of each costed lot sits in each warehouse: the FIFO layers.
--                            lot_id '' is stock taken out beyond the costed lots (negative stock
--                            allowed): it may be below 0 and the next stock-in fills it first.
--                            Over a (product, warehouse) it adds up to scm_stock_balances.on_hand.
--   scm_lot_moves            the cost ledger: every quantity put into or taken out of a lot, at
--                            the lot's cost, naming the inventory movement. Value on any day is
--                            sum(qty * unit_cost) up to that day. scm_rebuild_lot_stock(bus_id)
--                            recomputes scm_lot_stock from it.
--   scm_item_settings.whole_units
--                            the item is counted in whole base units (the default, as MSG);
--                            false for weight / volume / length items, which keep 3 decimals.
--   scm_receipt_lines        the pack the line came in, frozen (pack_id, pack_name, qty_per_pack),
--                            the costed lot made when it was posted (lot_id), and its serials
--                            (draft list, jsonb) for an item tracked by serial.
--   scm_serial_identifiers   further labels of one serial unit (IMEI, barcode, MAC), as MSG's
--                            msg_product_unit_identifiers.
--
-- Standard cost stays on scm_item_settings for planning and reports; it is no longer how stock
-- is valued.
--
-- BACKFILL (dev has SCM test data): each (business, product, warehouse) holding stock and with
-- no scm_lot_stock row yet gets its layers: stock already in a numbered lot stays in that lot
-- (costed from its receipts when every one had a cost, else at standard cost); stock not in a
-- lot goes into one opening lot per warehouse ('OPENING-<code>-<id>', numbered false) at the
-- item's current standard cost. Every backfilled lot is is_opening. A pair that already has
-- layers is never touched again, so the file re-runs without changing anything.
--
-- Idempotent; safe to re-run.

BEGIN;

-- ======================================================================= lots
ALTER TABLE scm.scm_lots ADD COLUMN IF NOT EXISTS unit_cost       numeric(18,6);
ALTER TABLE scm.scm_lots ADD COLUMN IF NOT EXISTS currency        text;
ALTER TABLE scm.scm_lots ADD COLUMN IF NOT EXISTS cost_basis      text;
ALTER TABLE scm.scm_lots ADD COLUMN IF NOT EXISTS origin          text;
ALTER TABLE scm.scm_lots ADD COLUMN IF NOT EXISTS is_opening      boolean NOT NULL DEFAULT false;
ALTER TABLE scm.scm_lots ADD COLUMN IF NOT EXISTS numbered        boolean NOT NULL DEFAULT true;
ALTER TABLE scm.scm_lots ADD COLUMN IF NOT EXISTS receipt_id      text REFERENCES scm.scm_receipts (id);
ALTER TABLE scm.scm_lots ADD COLUMN IF NOT EXISTS receipt_line_id text REFERENCES scm.scm_receipt_lines (id);
ALTER TABLE scm.scm_lots ADD COLUMN IF NOT EXISTS qty_received    numeric(14,3);

-- Lots made before this file: what made them, costed from their receipts when every receipt
-- movement of the lot carried a cost, else at the item's standard cost.
UPDATE scm.scm_lots l SET origin = CASE WHEN l.produced_by_ref IS NOT NULL THEN 'production'
                                        WHEN EXISTS (SELECT 1 FROM scm.scm_inventory_movements m
                                                      WHERE m.bus_id = l.bus_id AND m.lot_id = l.id AND m.kind = 'receipt') THEN 'receipt'
                                        ELSE 'other' END
 WHERE l.origin IS NULL;
UPDATE scm.scm_lots l
   SET unit_cost = c.cost, cost_basis = 'actual', is_opening = true
  FROM (SELECT m.lot_id, sum(m.qty * m.unit_cost) / nullif(sum(m.qty), 0) AS cost
          FROM scm.scm_inventory_movements m
         WHERE m.kind = 'receipt' AND m.qty > 0 AND m.lot_id IS NOT NULL
         GROUP BY m.lot_id HAVING bool_and(m.unit_cost IS NOT NULL)) c
 WHERE c.lot_id = l.id AND l.cost_basis IS NULL;
UPDATE scm.scm_lots l
   SET unit_cost = st.standard_cost, cost_basis = CASE WHEN st.standard_cost IS NULL THEN 'none' ELSE 'standard' END, is_opening = true
  FROM scm.scm_item_settings st
 WHERE st.bus_id = l.bus_id AND st.product_id = l.product_id AND l.cost_basis IS NULL;
UPDATE scm.scm_lots SET cost_basis = 'none', is_opening = true WHERE cost_basis IS NULL;

ALTER TABLE scm.scm_lots ALTER COLUMN cost_basis SET DEFAULT 'none';
ALTER TABLE scm.scm_lots ALTER COLUMN cost_basis SET NOT NULL;
ALTER TABLE scm.scm_lots ALTER COLUMN origin SET DEFAULT 'other';
ALTER TABLE scm.scm_lots ALTER COLUMN origin SET NOT NULL;
ALTER TABLE scm.scm_lots DROP CONSTRAINT IF EXISTS scm_lots_cost_basis_check;
ALTER TABLE scm.scm_lots ADD CONSTRAINT scm_lots_cost_basis_check CHECK (cost_basis IN ('actual', 'standard', 'none'));
ALTER TABLE scm.scm_lots DROP CONSTRAINT IF EXISTS scm_lots_origin_check;
ALTER TABLE scm.scm_lots ADD CONSTRAINT scm_lots_origin_check CHECK (origin IN
    ('receipt', 'opening', 'adjustment', 'count', 'return', 'transfer', 'production', 'other'));
ALTER TABLE scm.scm_lots DROP CONSTRAINT IF EXISTS scm_lots_unit_cost_check;
ALTER TABLE scm.scm_lots ADD CONSTRAINT scm_lots_unit_cost_check CHECK (unit_cost IS NULL OR unit_cost >= 0);
CREATE INDEX IF NOT EXISTS scm_lots_receipt_line_idx ON scm.scm_lots (receipt_line_id) WHERE receipt_line_id IS NOT NULL;

-- ============================================================ FIFO layers
CREATE TABLE IF NOT EXISTS scm.scm_lot_stock (
    tenant_id     text NOT NULL,
    org_id        text,
    bus_id        text NOT NULL,
    product_id    text NOT NULL,
    warehouse_id  text NOT NULL REFERENCES scm.scm_warehouses (id),
    lot_id        text NOT NULL DEFAULT '',
    qty           numeric(14,3) NOT NULL DEFAULT 0,
    updated_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (bus_id, product_id, warehouse_id, lot_id)
);
ALTER TABLE scm.scm_lot_stock DROP CONSTRAINT IF EXISTS scm_lot_stock_qty_check;
ALTER TABLE scm.scm_lot_stock ADD CONSTRAINT scm_lot_stock_qty_check CHECK (lot_id = '' OR qty >= 0);
CREATE INDEX IF NOT EXISTS scm_lot_stock_lot_idx ON scm.scm_lot_stock (bus_id, lot_id) WHERE lot_id <> '';

-- ============================================================= cost ledger
CREATE TABLE IF NOT EXISTS scm.scm_lot_moves (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    org_id        text,
    bus_id        text NOT NULL,
    product_id    text NOT NULL,
    warehouse_id  text NOT NULL REFERENCES scm.scm_warehouses (id),
    -- NULL: the part of a movement beyond the costed lots (scm_lot_stock lot_id '').
    lot_id        text REFERENCES scm.scm_lots (id),
    -- NULL only for the opening rows this file writes.
    movement_id   text REFERENCES scm.scm_inventory_movements (id),
    kind          text NOT NULL,
    qty           numeric(14,3) NOT NULL CHECK (qty <> 0),
    unit_cost     numeric(18,6) CHECK (unit_cost IS NULL OR unit_cost >= 0),
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE scm.scm_lot_moves DROP CONSTRAINT IF EXISTS scm_lot_moves_kind_check;
ALTER TABLE scm.scm_lot_moves ADD CONSTRAINT scm_lot_moves_kind_check CHECK (kind IN ('in', 'out', 'opening'));
CREATE INDEX IF NOT EXISTS scm_lot_moves_stock_idx ON scm.scm_lot_moves (bus_id, product_id, warehouse_id, cdatetime);
CREATE INDEX IF NOT EXISTS scm_lot_moves_movement_idx ON scm.scm_lot_moves (movement_id) WHERE movement_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS scm_lot_moves_lot_idx ON scm.scm_lot_moves (lot_id) WHERE lot_id IS NOT NULL;

INSERT INTO core_platform.cp_product_references (table_name, column_name, is_extension) VALUES
    ('scm.scm_lot_stock', 'product_id', false),
    ('scm.scm_lot_moves', 'product_id', false)
ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;

-- Recompute a business's layers from the cost ledger. For repair, and to prove the derived state
-- matches the facts.
CREATE OR REPLACE FUNCTION scm.scm_rebuild_lot_stock(p_bus_id text) RETURNS integer
LANGUAGE plpgsql AS $f$
DECLARE n integer;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext('scm_rebuild_balances'), hashtext(p_bus_id));
    DELETE FROM scm.scm_lot_stock WHERE bus_id = p_bus_id;
    INSERT INTO scm.scm_lot_stock (tenant_id, org_id, bus_id, product_id, warehouse_id, lot_id, qty, updated_at)
    SELECT max(tenant_id), max(org_id), p_bus_id, product_id, warehouse_id, coalesce(lot_id, ''), sum(qty), now()
      FROM scm.scm_lot_moves WHERE bus_id = p_bus_id
     GROUP BY product_id, warehouse_id, coalesce(lot_id, '');
    GET DIAGNOSTICS n = ROW_COUNT;
    RETURN n;
END
$f$;

-- ============================================================ whole units
ALTER TABLE scm.scm_item_settings ADD COLUMN IF NOT EXISTS whole_units boolean;
UPDATE scm.scm_item_settings st
   SET whole_units = NOT (
         coalesce((SELECT u.decimal_place > 0 FROM core_platform.cp_unit_of_measures u WHERE u.id = st.uom_id AND u.tenant_id = st.tenant_id LIMIT 1), false)
      OR coalesce((SELECT lower(btrim(p.unit)) ~ '^(kg|kgs|kilo|kilos|kilogram|kilograms|g|gram|grams|mg|t|ton|tons|tonne|tonnes|lb|lbs|oz|l|lt|ltr|litre|litres|liter|liters|ml|cl|gal|gallon|gallons|m|metre|metres|meter|meters|cm|mm|km|ft|yd|m2|m3|sqm|cbm)$'
                    FROM core_platform.cp_products p WHERE p.id = st.product_id LIMIT 1), false)
      OR EXISTS (SELECT 1 FROM scm.scm_inventory_movements m WHERE m.bus_id = st.bus_id AND m.product_id = st.product_id AND m.qty <> trunc(m.qty))
      OR EXISTS (SELECT 1 FROM scm.scm_purchase_order_lines l WHERE l.product_id = st.product_id AND l.qty_ordered <> trunc(l.qty_ordered)))
 WHERE st.whole_units IS NULL;
ALTER TABLE scm.scm_item_settings ALTER COLUMN whole_units SET DEFAULT true;
ALTER TABLE scm.scm_item_settings ALTER COLUMN whole_units SET NOT NULL;

-- ===================================================== receipt lines: pack, lot, serials
ALTER TABLE scm.scm_receipt_lines ADD COLUMN IF NOT EXISTS pack_id      text;
ALTER TABLE scm.scm_receipt_lines ADD COLUMN IF NOT EXISTS pack_name    text;
ALTER TABLE scm.scm_receipt_lines ADD COLUMN IF NOT EXISTS qty_per_pack numeric(14,3);
ALTER TABLE scm.scm_receipt_lines ADD COLUMN IF NOT EXISTS lot_id       text REFERENCES scm.scm_lots (id);
ALTER TABLE scm.scm_receipt_lines ADD COLUMN IF NOT EXISTS serials      jsonb;
-- Freeze the pack of receipt lines written before this file from their order line, as it is now.
UPDATE scm.scm_receipt_lines rl
   SET pack_id = pl.pack_id, pack_name = pk.name, qty_per_pack = pk.qty_per_pack
  FROM scm.scm_purchase_order_lines pl
  JOIN scm.scm_item_packs pk ON pk.id = pl.pack_id
 WHERE pl.id = rl.po_line_id AND rl.pack_id IS NULL AND pl.pack_id IS NOT NULL;

-- ================================================== serial identifiers
CREATE TABLE IF NOT EXISTS scm.scm_serial_identifiers (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    org_id      text,
    bus_id      text NOT NULL,
    serial_id   text NOT NULL REFERENCES scm.scm_serials (id) ON DELETE CASCADE,
    kind        text NOT NULL,
    value       text NOT NULL CHECK (btrim(value) <> '' AND length(value) <= 80),
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text
);
ALTER TABLE scm.scm_serial_identifiers DROP CONSTRAINT IF EXISTS scm_serial_identifiers_kind_check;
ALTER TABLE scm.scm_serial_identifiers ADD CONSTRAINT scm_serial_identifiers_kind_check CHECK (kind IN ('imei', 'barcode', 'mac', 'other'));
CREATE UNIQUE INDEX IF NOT EXISTS scm_serial_identifiers_value_uq ON scm.scm_serial_identifiers (bus_id, kind, value);
CREATE INDEX IF NOT EXISTS scm_serial_identifiers_serial_idx ON scm.scm_serial_identifiers (serial_id);

-- ================================================================= backfill
-- scm_backfill_lot_stock() gives layers to each (business, product, warehouse) holding stock with
-- none yet (see the top of this file) and answers how many pairs it did. A pair with layers is
-- never touched again, so calling it twice changes nothing. It refuses (raises) when what it made
-- does not add up to scm_stock_balances.
CREATE OR REPLACE FUNCTION scm.scm_backfill_lot_stock() RETURNS integer
LANGUAGE plpgsql AS $f$
DECLARE n integer;
BEGIN
    DROP TABLE IF EXISTS pg_temp.scm_bf_pairs, pg_temp.scm_bf_layers;
    CREATE TEMP TABLE scm_bf_pairs AS
    SELECT b.bus_id, b.product_id, b.warehouse_id, max(b.tenant_id) AS tenant_id, max(b.org_id) AS org_id
      FROM scm.scm_stock_balances b
     WHERE b.on_hand <> 0
       AND NOT EXISTS (SELECT 1 FROM scm.scm_lot_stock x WHERE x.bus_id = b.bus_id AND x.product_id = b.product_id AND x.warehouse_id = b.warehouse_id)
     GROUP BY b.bus_id, b.product_id, b.warehouse_id;
    GET DIAGNOSTICS n = ROW_COUNT;

    -- Stock not in a lot: one opening lot per warehouse, at standard cost, first in the FIFO order.
    INSERT INTO scm.scm_lots (tenant_id, org_id, bus_id, product_id, lot_number, received_at, unit_cost, currency, cost_basis, origin,
                              is_opening, numbered, qty_received)
    SELECT p.tenant_id, p.org_id, p.bus_id, p.product_id, 'OPENING-' || upper(w.code) || '-' || left(w.id, 8),
           coalesce((SELECT min(m.cdatetime) FROM scm.scm_inventory_movements m
                      WHERE m.bus_id = p.bus_id AND m.product_id = p.product_id AND m.warehouse_id = p.warehouse_id), now()),
           st.standard_cost, s.base_currency, CASE WHEN st.standard_cost IS NULL THEN 'none' ELSE 'standard' END, 'opening', true, false, u.q
      FROM scm_bf_pairs p
      JOIN scm.scm_warehouses w ON w.id = p.warehouse_id
      JOIN (SELECT bus_id, product_id, warehouse_id, sum(on_hand) AS q FROM scm.scm_stock_balances WHERE lot_id = '' GROUP BY 1, 2, 3) u
        ON u.bus_id = p.bus_id AND u.product_id = p.product_id AND u.warehouse_id = p.warehouse_id AND u.q > 0
      LEFT JOIN scm.scm_item_settings st ON st.bus_id = p.bus_id AND st.product_id = p.product_id
      LEFT JOIN scm.scm_settings s ON s.bus_id = p.bus_id
    ON CONFLICT (bus_id, product_id, lot_number) DO NOTHING;

    CREATE TEMP TABLE scm_bf_layers AS
    -- numbered lots keep their own stock
    SELECT p.tenant_id, p.org_id, p.bus_id, p.product_id, p.warehouse_id, b.lot_id, sum(b.on_hand) AS q
      FROM scm_bf_pairs p
      JOIN scm.scm_stock_balances b ON b.bus_id = p.bus_id AND b.product_id = p.product_id AND b.warehouse_id = p.warehouse_id AND b.lot_id <> ''
     GROUP BY 1, 2, 3, 4, 5, 6
    UNION ALL
    -- stock not in a lot goes into the opening lot (or, when below 0, the '' row)
    SELECT p.tenant_id, p.org_id, p.bus_id, p.product_id, p.warehouse_id,
           CASE WHEN sum(b.on_hand) > 0 THEN (SELECT l.id FROM scm.scm_lots l JOIN scm.scm_warehouses w ON w.id = p.warehouse_id
                                              WHERE l.bus_id = p.bus_id AND l.product_id = p.product_id
                                                AND l.lot_number = 'OPENING-' || upper(w.code) || '-' || left(w.id, 8))
                ELSE '' END,
           sum(b.on_hand)
      FROM scm_bf_pairs p
      JOIN scm.scm_stock_balances b ON b.bus_id = p.bus_id AND b.product_id = p.product_id AND b.warehouse_id = p.warehouse_id AND b.lot_id = ''
     GROUP BY 1, 2, 3, 4, 5;

    -- A numbered lot with no cost yet is costed at the item's standard cost, as an opening lot.
    UPDATE scm.scm_lots l
       SET unit_cost = st.standard_cost, cost_basis = CASE WHEN st.standard_cost IS NULL THEN 'none' ELSE 'standard' END, is_opening = true
      FROM scm_bf_layers f, scm.scm_item_settings st
     WHERE l.id = f.lot_id AND l.unit_cost IS NULL AND l.numbered AND st.bus_id = l.bus_id AND st.product_id = l.product_id;

    -- A lot below 0 in a warehouse (negative stock allowed) is carried on the '' row.
    INSERT INTO scm.scm_lot_stock (tenant_id, org_id, bus_id, product_id, warehouse_id, lot_id, qty)
    SELECT max(tenant_id), max(org_id), bus_id, product_id, warehouse_id, CASE WHEN q < 0 THEN '' ELSE lot_id END, sum(q)
      FROM scm_bf_layers WHERE q <> 0
     GROUP BY bus_id, product_id, warehouse_id, CASE WHEN q < 0 THEN '' ELSE lot_id END;

    INSERT INTO scm.scm_lot_moves (tenant_id, org_id, bus_id, product_id, warehouse_id, lot_id, movement_id, kind, qty, unit_cost, cdatetime)
    SELECT f.tenant_id, f.org_id, f.bus_id, f.product_id, f.warehouse_id, nullif(CASE WHEN f.q < 0 THEN '' ELSE f.lot_id END, ''), NULL, 'opening', f.q,
           CASE WHEN f.q > 0 THEN (SELECT l.unit_cost FROM scm.scm_lots l WHERE l.id = f.lot_id) END,
           -- dated with the pair's last movement, so a valuation on any later day includes it
           coalesce((SELECT max(m.cdatetime) FROM scm.scm_inventory_movements m
                      WHERE m.bus_id = f.bus_id AND m.product_id = f.product_id AND m.warehouse_id = f.warehouse_id), now())
      FROM scm_bf_layers f WHERE f.q <> 0;

    IF EXISTS (SELECT 1 FROM scm_bf_pairs p
                WHERE (SELECT coalesce(sum(qty), 0) FROM scm.scm_lot_stock x
                        WHERE x.bus_id = p.bus_id AND x.product_id = p.product_id AND x.warehouse_id = p.warehouse_id)
                   <> (SELECT coalesce(sum(on_hand), 0) FROM scm.scm_stock_balances b
                        WHERE b.bus_id = p.bus_id AND b.product_id = p.product_id AND b.warehouse_id = p.warehouse_id)) THEN
        RAISE EXCEPTION 'scm_lot_stock backfill does not add up to scm_stock_balances';
    END IF;
    DROP TABLE pg_temp.scm_bf_pairs, pg_temp.scm_bf_layers;
    RETURN n;
END
$f$;

SELECT scm.scm_backfill_lot_stock();

-- ================================================================ invariants
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM scm.scm_lots WHERE cost_basis IS NULL OR origin IS NULL) THEN
        RAISE EXCEPTION 'scm_lots: a lot without cost_basis or origin';
    END IF;
    IF EXISTS (SELECT 1 FROM scm.scm_item_settings WHERE whole_units IS NULL) THEN
        RAISE EXCEPTION 'scm_item_settings: an item without whole_units';
    END IF;
END $$;

COMMIT;
