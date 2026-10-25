-- SCM: the inventory ledger -- every movement of stock, written once and never changed, and
-- the balances derived from it.
--
--   scm_lots                 a lot (batch) of a product, with its expiry
--   scm_inventory_movements  the ledger: one row per movement, signed (+ in, - out), naming the
--                            document that caused it. APPEND-ONLY: a trigger refuses UPDATE and
--                            DELETE. A mistake is corrected by another movement.
--   scm_stock_balances       on_hand and reserved per (product, warehouse, bin, lot): derived
--                            state the API keeps in the same transaction as each movement, and
--                            scm_rebuild_balances(bus_id) recomputes from the ledger and the
--                            active reservations (20261026-05)
--   scm_adjustments          a counted difference, a write-off, a found item: posted as signed
--                            adjustment movements
--   scm_adjustment_lines     what changed by how much
--   scm_transfers            stock moved between warehouses: transfer_out when shipped, in
--                            transit, transfer_in when received
--   scm_transfer_lines       what moved
--
-- Status lists are CHECK constraints owned by this file. Idempotent; safe to re-run.

BEGIN;

-- ========================================================================= lots
CREATE TABLE IF NOT EXISTS scm.scm_lots (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    org_id          text,
    bus_id          text NOT NULL,
    product_id      text NOT NULL,
    lot_number      text NOT NULL,
    expiry_date     date,
    supplier_id     text,
    received_at     timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    updated_by      text
);
CREATE UNIQUE INDEX IF NOT EXISTS scm_lots_number_uq ON scm.scm_lots (bus_id, product_id, lot_number);
CREATE INDEX IF NOT EXISTS scm_lots_expiry_idx ON scm.scm_lots (bus_id, expiry_date) WHERE expiry_date IS NOT NULL;

-- ==================================================================== movements
CREATE TABLE IF NOT EXISTS scm.scm_inventory_movements (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    org_id          text,
    bus_id          text NOT NULL,
    product_id      text NOT NULL,
    warehouse_id    text NOT NULL REFERENCES scm.scm_warehouses (id),
    bin_id          text REFERENCES scm.scm_bins (id),
    lot_id          text REFERENCES scm.scm_lots (id),
    kind            text NOT NULL,
    -- Signed: positive into the warehouse, negative out of it. Never zero.
    qty             numeric(14,3) NOT NULL CHECK (qty <> 0),
    unit_cost       numeric(14,4) CHECK (unit_cost IS NULL OR unit_cost >= 0),
    reference_type  text NOT NULL,
    reference_id    text NOT NULL,
    reason          text,
    posted_by       text,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE scm.scm_inventory_movements DROP CONSTRAINT IF EXISTS scm_inventory_movements_kind_check;
ALTER TABLE scm.scm_inventory_movements ADD CONSTRAINT scm_inventory_movements_kind_check CHECK (kind IN
    ('receipt', 'issue', 'transfer_out', 'transfer_in', 'adjustment', 'shipment', 'return', 'scrap'));
CREATE INDEX IF NOT EXISTS scm_inventory_movements_stock_idx
    ON scm.scm_inventory_movements (bus_id, product_id, warehouse_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS scm_inventory_movements_reference_idx
    ON scm.scm_inventory_movements (bus_id, reference_type, reference_id);

-- The ledger is append-only. One exception, so the suite's shared product merge
-- (core_platform.cp_product_merge, which UPDATEs every column in cp_product_references) can
-- re-point a movement at the product that was kept: an UPDATE that changes product_id and
-- nothing else goes through. Every other UPDATE, and every DELETE, is refused.
CREATE OR REPLACE FUNCTION scm.scm_movements_immutable() RETURNS trigger
LANGUAGE plpgsql AS $f$
BEGIN
    IF TG_OP = 'UPDATE'
       AND NEW.product_id IS DISTINCT FROM OLD.product_id
       AND row(NEW.id, NEW.tenant_id, NEW.org_id, NEW.bus_id, NEW.warehouse_id, NEW.bin_id, NEW.lot_id, NEW.kind, NEW.qty,
               NEW.unit_cost, NEW.reference_type, NEW.reference_id, NEW.reason, NEW.posted_by, NEW.cdatetime)
           IS NOT DISTINCT FROM
           row(OLD.id, OLD.tenant_id, OLD.org_id, OLD.bus_id, OLD.warehouse_id, OLD.bin_id, OLD.lot_id, OLD.kind, OLD.qty,
               OLD.unit_cost, OLD.reference_type, OLD.reference_id, OLD.reason, OLD.posted_by, OLD.cdatetime) THEN
        RETURN NEW;
    END IF;
    RAISE EXCEPTION 'scm_inventory_movements is append-only: % is not allowed; post a correcting movement instead', TG_OP
        USING ERRCODE = 'integrity_constraint_violation';
END
$f$;
DROP TRIGGER IF EXISTS scm_inventory_movements_immutable ON scm.scm_inventory_movements;
CREATE TRIGGER scm_inventory_movements_immutable
    BEFORE UPDATE OR DELETE ON scm.scm_inventory_movements
    FOR EACH ROW EXECUTE FUNCTION scm.scm_movements_immutable();

-- ===================================================================== balances
CREATE TABLE IF NOT EXISTS scm.scm_stock_balances (
    tenant_id       text NOT NULL,
    org_id          text,
    bus_id          text NOT NULL,
    product_id      text NOT NULL,
    warehouse_id    text NOT NULL,
    -- '' when the stock is not in a bin / not of a lot: a key column cannot be NULL.
    bin_id          text NOT NULL DEFAULT '',
    lot_id          text NOT NULL DEFAULT '',
    on_hand         numeric(14,3) NOT NULL DEFAULT 0,
    reserved        numeric(14,3) NOT NULL DEFAULT 0,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (bus_id, product_id, warehouse_id, bin_id, lot_id)
);
ALTER TABLE scm.scm_stock_balances DROP CONSTRAINT IF EXISTS scm_stock_balances_reserved_check;
ALTER TABLE scm.scm_stock_balances ADD CONSTRAINT scm_stock_balances_reserved_check CHECK (reserved >= 0);
CREATE INDEX IF NOT EXISTS scm_stock_balances_warehouse_idx ON scm.scm_stock_balances (bus_id, warehouse_id, product_id);

-- Recompute a business's balances from the ledger and its active reservations
-- (scm.scm_reservations, 20261026-05; plpgsql resolves it when called, not here). Returns
-- the number of balance rows written. The API keeps balances in step with every posting; this
-- is for repair and for proving the derived state matches the facts.
CREATE OR REPLACE FUNCTION scm.scm_rebuild_balances(p_bus_id text) RETURNS integer
LANGUAGE plpgsql AS $f$
DECLARE n integer;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext('scm_rebuild_balances'), hashtext(p_bus_id));
    DELETE FROM scm.scm_stock_balances WHERE bus_id = p_bus_id;
    INSERT INTO scm.scm_stock_balances (tenant_id, org_id, bus_id, product_id, warehouse_id, bin_id, lot_id, on_hand, reserved, updated_at)
    SELECT coalesce(m.tenant_id, r.tenant_id), coalesce(m.org_id, r.org_id), p_bus_id,
           coalesce(m.product_id, r.product_id), coalesce(m.warehouse_id, r.warehouse_id),
           coalesce(m.bin_id, r.bin_id), coalesce(m.lot_id, r.lot_id),
           coalesce(m.on_hand, 0), coalesce(r.reserved, 0), now()
      FROM (SELECT bus_id, product_id, warehouse_id, coalesce(bin_id, '') AS bin_id, coalesce(lot_id, '') AS lot_id,
                   max(tenant_id) AS tenant_id, max(org_id) AS org_id, sum(qty) AS on_hand
              FROM scm.scm_inventory_movements
             WHERE bus_id = p_bus_id
             GROUP BY bus_id, product_id, warehouse_id, coalesce(bin_id, ''), coalesce(lot_id, '')) m
      FULL OUTER JOIN
           (SELECT bus_id, product_id, warehouse_id, coalesce(bin_id, '') AS bin_id, coalesce(lot_id, '') AS lot_id,
                   max(tenant_id) AS tenant_id, max(org_id) AS org_id, sum(qty) AS reserved
              FROM scm.scm_reservations
             WHERE bus_id = p_bus_id AND status = 'active'
             GROUP BY bus_id, product_id, warehouse_id, coalesce(bin_id, ''), coalesce(lot_id, '')) r
        ON r.product_id = m.product_id AND r.warehouse_id = m.warehouse_id AND r.bin_id = m.bin_id AND r.lot_id = m.lot_id;
    GET DIAGNOSTICS n = ROW_COUNT;
    RETURN n;
END
$f$;

-- ================================================================== adjustments
CREATE TABLE IF NOT EXISTS scm.scm_adjustments (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    number            text NOT NULL,
    warehouse_id      text NOT NULL REFERENCES scm.scm_warehouses (id),
    status            text NOT NULL DEFAULT 'draft',
    reason            text NOT NULL,
    notes             text,
    posted_by         text,
    posted_at         timestamptz,
    idempotency_key   text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text
);
ALTER TABLE scm.scm_adjustments DROP CONSTRAINT IF EXISTS scm_adjustments_status_check;
ALTER TABLE scm.scm_adjustments ADD CONSTRAINT scm_adjustments_status_check CHECK (status IN ('draft', 'posted', 'cancelled'));
CREATE UNIQUE INDEX IF NOT EXISTS scm_adjustments_number_uq ON scm.scm_adjustments (bus_id, number);
CREATE UNIQUE INDEX IF NOT EXISTS scm_adjustments_idem_uq ON scm.scm_adjustments (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS scm_adjustments_board_idx ON scm.scm_adjustments (bus_id, status, cdatetime DESC);

CREATE TABLE IF NOT EXISTS scm.scm_adjustment_lines (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    adjustment_id   text NOT NULL REFERENCES scm.scm_adjustments (id) ON DELETE CASCADE,
    product_id      text NOT NULL,
    bin_id          text REFERENCES scm.scm_bins (id),
    lot_id          text REFERENCES scm.scm_lots (id),
    qty_delta       numeric(14,3) NOT NULL CHECK (qty_delta <> 0),
    unit_cost       numeric(14,4) CHECK (unit_cost IS NULL OR unit_cost >= 0)
);
CREATE INDEX IF NOT EXISTS scm_adjustment_lines_adjustment_idx ON scm.scm_adjustment_lines (adjustment_id);

-- ==================================================================== transfers
CREATE TABLE IF NOT EXISTS scm.scm_transfers (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    org_id              text,
    bus_id              text NOT NULL,
    number              text NOT NULL,
    from_warehouse_id   text NOT NULL REFERENCES scm.scm_warehouses (id),
    to_warehouse_id     text NOT NULL REFERENCES scm.scm_warehouses (id),
    status              text NOT NULL DEFAULT 'draft',
    notes               text,
    shipped_at          timestamptz,
    received_at         timestamptz,
    posted_by           text,
    idempotency_key     text,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    created_by          text,
    updated_at          timestamptz NOT NULL DEFAULT now(),
    updated_by          text
);
ALTER TABLE scm.scm_transfers DROP CONSTRAINT IF EXISTS scm_transfers_status_check;
ALTER TABLE scm.scm_transfers ADD CONSTRAINT scm_transfers_status_check CHECK (status IN ('draft', 'in_transit', 'received', 'cancelled'));
ALTER TABLE scm.scm_transfers DROP CONSTRAINT IF EXISTS scm_transfers_warehouses_check;
ALTER TABLE scm.scm_transfers ADD CONSTRAINT scm_transfers_warehouses_check CHECK (from_warehouse_id <> to_warehouse_id);
CREATE UNIQUE INDEX IF NOT EXISTS scm_transfers_number_uq ON scm.scm_transfers (bus_id, number);
CREATE UNIQUE INDEX IF NOT EXISTS scm_transfers_idem_uq ON scm.scm_transfers (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS scm_transfers_board_idx ON scm.scm_transfers (bus_id, status, cdatetime DESC);

CREATE TABLE IF NOT EXISTS scm.scm_transfer_lines (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    transfer_id     text NOT NULL REFERENCES scm.scm_transfers (id) ON DELETE CASCADE,
    product_id      text NOT NULL,
    from_bin_id     text REFERENCES scm.scm_bins (id),
    to_bin_id       text REFERENCES scm.scm_bins (id),
    lot_id          text REFERENCES scm.scm_lots (id),
    qty             numeric(14,3) NOT NULL CHECK (qty > 0)
);
CREATE INDEX IF NOT EXISTS scm_transfer_lines_transfer_idx ON scm.scm_transfer_lines (transfer_id);

-- ===================================================================== invariants
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'scm_inventory_movements_immutable'
                    AND tgrelid = 'scm.scm_inventory_movements'::regclass AND NOT tgisinternal) THEN
        RAISE EXCEPTION 'the ledger is not protected: scm_inventory_movements_immutable is missing';
    END IF;
END $$;

COMMIT;
