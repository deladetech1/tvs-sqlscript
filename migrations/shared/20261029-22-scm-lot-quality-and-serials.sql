-- SCM: a lot's quality status, and serial numbers.
--
--   scm_lots.quality_status  'available' unless quality has put the lot in quarantine, on hold or
--                            rejected it (list: 20261029-23). The ledger (tvs-shared-apps-bk
--                            internal/platform/stock) refuses to issue, ship, transfer out or scrap
--                            stock of a lot that is not available, whichever app posts it. Receipts,
--                            returns and adjustments still post, so stock found or counted is
--                            recorded.
--   scm_lots.revision        the item revision the lot was made or bought to (Manufacturing).
--   scm_lots.produced_by_ref the document that made the lot, e.g. 'mfg_production_order:<id>'.
--   scm_serials              one row per serial number of a product: where it is and what became
--                            of it (status list: 20261029-23). Genealogy (what a serial was made
--                            from) is Manufacturing's; this table is the stock side.
--
-- Idempotent; safe to re-run.

BEGIN;

ALTER TABLE scm.scm_lots ADD COLUMN IF NOT EXISTS quality_status text NOT NULL DEFAULT 'available';
ALTER TABLE scm.scm_lots ADD COLUMN IF NOT EXISTS revision text;
ALTER TABLE scm.scm_lots ADD COLUMN IF NOT EXISTS produced_by_ref text;
CREATE INDEX IF NOT EXISTS scm_lots_blocked_idx ON scm.scm_lots (bus_id, quality_status) WHERE quality_status <> 'available';

CREATE TABLE IF NOT EXISTS scm.scm_serials (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    org_id          text,
    bus_id          text NOT NULL,
    product_id      text NOT NULL,
    serial_number   text NOT NULL CHECK (btrim(serial_number) <> '' AND length(serial_number) <= 80),
    lot_id          text REFERENCES scm.scm_lots (id),
    status          text NOT NULL DEFAULT 'in_stock',
    warehouse_id    text REFERENCES scm.scm_warehouses (id),
    bin_id          text REFERENCES scm.scm_bins (id),
    revision        text,
    produced_by_ref text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    updated_by      text
);
CREATE UNIQUE INDEX IF NOT EXISTS scm_serials_number_uq ON scm.scm_serials (bus_id, product_id, serial_number);
CREATE INDEX IF NOT EXISTS scm_serials_lot_idx ON scm.scm_serials (lot_id) WHERE lot_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS scm_serials_where_idx ON scm.scm_serials (bus_id, warehouse_id, status);

INSERT INTO core_platform.cp_product_references (table_name, column_name, is_extension) VALUES
    ('scm.scm_serials', 'product_id', false)
ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;

COMMIT;
