-- Manufacturing: what it reads of SCM's own documents (design: docs/mfg/03-database-model.md §1
-- "Cross-app reads", §5 Genealogy; 02-domain-model.md §3, §7; contract R2.md C1, C2, C7, C9).
--
--   mfg.src_scm_open_so_lines         open sales-order lines (confirmed, allocated, partially
--                                     shipped; quantity not all shipped): MRP demand (C1)
--   mfg.src_scm_open_po_lines         open purchase-order lines (approved, sent, confirmed,
--                                     partially received; quantity not all received): MRP supply (C2)
--   mfg.src_scm_open_transfer_lines   transfer lines not yet received (draft, in transit): MRP
--                                     supply at the receiving warehouse (C2)
--   mfg.src_scm_receipt_lines         posted receipt lines with their supplier, PO and lot: the
--                                     bottom of a backward trace (C9), receipt inspections (C7)
--                                     and a purchased item's latest unit cost (C10)
--   mfg.src_scm_shipment_lines        shipment lines (packed, shipped, delivered) with their
--                                     customer and lot: the top of a forward trace, a recall's
--                                     customers (C9)
--
-- SCM is optional (R1 A1). Each view is (re)made only when every SCM table it reads exists
-- (to_regclass), so a database without SCM gets no view and no error. In the pool the tables always
-- exist, so the API still checks the business's SCM subscription (entitle.Business(..., SCM))
-- before every read and fails closed. Every view carries tenant_id and bus_id: the API filters on
-- them.
--
-- Column names are SCM's (customer_id, supplier_id are cp_parties ids). The views are dropped and
-- made again on every run, so a later change of columns here needs nothing else. No grants: default
-- privileges and the IaC app group handle access. Idempotent; safe to re-run.

BEGIN;

DO $$
BEGIN
    -- ------------------------------------------------------------- open sales-order lines
    IF to_regclass('scm.scm_sales_orders') IS NOT NULL AND to_regclass('scm.scm_sales_order_lines') IS NOT NULL THEN
        DROP VIEW IF EXISTS mfg.src_scm_open_so_lines;
        CREATE VIEW mfg.src_scm_open_so_lines AS
        SELECT l.id                                    AS so_line_id,
               l.so_id,
               so.tenant_id, so.org_id, so.bus_id,
               so.number                               AS so_number,
               so.customer_id,
               so.warehouse_id,
               l.line_no,
               l.product_id,
               l.uom_id,
               l.qty_ordered,
               l.qty_shipped,
               l.qty_ordered - l.qty_shipped           AS qty_open,
               coalesce(so.requested_date, so.order_date) AS need_on,
               so.status
          FROM scm.scm_sales_order_lines l
          JOIN scm.scm_sales_orders so ON so.id = l.so_id
         WHERE so.status IN ('confirmed', 'allocated', 'partially_shipped')
           AND l.qty_ordered > l.qty_shipped;
    END IF;

    -- ---------------------------------------------------------- open purchase-order lines
    IF to_regclass('scm.scm_purchase_orders') IS NOT NULL AND to_regclass('scm.scm_purchase_order_lines') IS NOT NULL THEN
        DROP VIEW IF EXISTS mfg.src_scm_open_po_lines;
        CREATE VIEW mfg.src_scm_open_po_lines AS
        SELECT l.id                                    AS po_line_id,
               l.po_id,
               po.tenant_id, po.org_id, po.bus_id,
               po.number                               AS po_number,
               po.supplier_id,
               po.warehouse_id,
               l.line_no,
               l.product_id,
               l.uom_id,
               l.qty_ordered,
               l.qty_received,
               l.qty_ordered - l.qty_received          AS qty_open,
               l.unit_price,
               po.currency,
               coalesce(l.expected_date, po.confirmed_date, po.expected_date, po.order_date) AS due_on,
               po.status
          FROM scm.scm_purchase_order_lines l
          JOIN scm.scm_purchase_orders po ON po.id = l.po_id
         WHERE po.status IN ('approved', 'sent', 'confirmed', 'partially_received')
           AND l.qty_ordered > l.qty_received;
    END IF;

    -- ------------------------------------------------------------- open transfer lines
    IF to_regclass('scm.scm_transfers') IS NOT NULL AND to_regclass('scm.scm_transfer_lines') IS NOT NULL THEN
        DROP VIEW IF EXISTS mfg.src_scm_open_transfer_lines;
        CREATE VIEW mfg.src_scm_open_transfer_lines AS
        SELECT l.id                                    AS transfer_line_id,
               l.transfer_id,
               t.tenant_id, t.org_id, t.bus_id,
               t.number                                AS transfer_number,
               t.from_warehouse_id,
               t.to_warehouse_id,
               l.product_id,
               l.lot_id,
               l.qty,
               t.status,
               t.shipped_at,
               t.cdatetime
          FROM scm.scm_transfer_lines l
          JOIN scm.scm_transfers t ON t.id = l.transfer_id
         WHERE t.status IN ('draft', 'in_transit');
    END IF;

    -- -------------------------------------------------------------------- receipt lines
    IF to_regclass('scm.scm_receipts') IS NOT NULL AND to_regclass('scm.scm_receipt_lines') IS NOT NULL
       AND to_regclass('scm.scm_purchase_orders') IS NOT NULL AND to_regclass('scm.scm_lots') IS NOT NULL THEN
        DROP VIEW IF EXISTS mfg.src_scm_receipt_lines;
        CREATE VIEW mfg.src_scm_receipt_lines AS
        SELECT l.id                                    AS receipt_line_id,
               l.receipt_id,
               r.tenant_id, r.org_id, r.bus_id,
               r.number                                AS receipt_number,
               r.po_id,
               po.number                               AS po_number,
               l.po_line_id,
               po.supplier_id,
               r.warehouse_id,
               l.bin_id,
               l.product_id,
               l.qty,
               l.lot_number,
               lot.id                                  AS lot_id,
               l.expiry_date,
               l.unit_cost,
               po.currency,
               r.received_at,
               r.posted_at
          FROM scm.scm_receipt_lines l
          JOIN scm.scm_receipts r ON r.id = l.receipt_id
          JOIN scm.scm_purchase_orders po ON po.id = r.po_id
          LEFT JOIN scm.scm_lots lot
            ON lot.bus_id = r.bus_id AND lot.product_id = l.product_id AND lot.lot_number = l.lot_number
         WHERE r.status = 'posted';
    END IF;

    -- ------------------------------------------------------------------- shipment lines
    IF to_regclass('scm.scm_shipments') IS NOT NULL AND to_regclass('scm.scm_shipment_lines') IS NOT NULL
       AND to_regclass('scm.scm_sales_orders') IS NOT NULL THEN
        DROP VIEW IF EXISTS mfg.src_scm_shipment_lines;
        CREATE VIEW mfg.src_scm_shipment_lines AS
        SELECT l.id                                    AS shipment_line_id,
               l.shipment_id,
               s.tenant_id, s.org_id, s.bus_id,
               s.number                                AS shipment_number,
               s.so_id,
               so.number                               AS so_number,
               l.so_line_id,
               so.customer_id,
               s.warehouse_id,
               l.product_id,
               l.lot_id,
               l.qty,
               s.status,
               s.shipped_at,
               s.delivered_at
          FROM scm.scm_shipment_lines l
          JOIN scm.scm_shipments s ON s.id = l.shipment_id
          JOIN scm.scm_sales_orders so ON so.id = s.so_id
         WHERE s.status IN ('packed', 'shipped', 'delivered');
    END IF;
END $$;

-- ===================================================================== invariants
DO $$
DECLARE
    v text;
    src text;
BEGIN
    -- With SCM's tables present, every view exists and carries the tenant and business.
    FOR v, src IN SELECT * FROM (VALUES
        ('src_scm_open_so_lines',       'scm.scm_sales_order_lines'),
        ('src_scm_open_po_lines',       'scm.scm_purchase_order_lines'),
        ('src_scm_open_transfer_lines', 'scm.scm_transfer_lines'),
        ('src_scm_receipt_lines',       'scm.scm_receipt_lines'),
        ('src_scm_shipment_lines',      'scm.scm_shipment_lines')) AS x(v, src) LOOP
        CONTINUE WHEN to_regclass(src) IS NULL;
        IF to_regclass('mfg.' || v) IS NULL THEN
            RAISE EXCEPTION 'mfg.% is missing although % exists', v, src;
        END IF;
        IF (SELECT count(*) FROM information_schema.columns
             WHERE table_schema = 'mfg' AND table_name = v AND column_name IN ('tenant_id', 'bus_id')) <> 2 THEN
            RAISE EXCEPTION 'mfg.% does not carry tenant_id and bus_id', v;
        END IF;
    END LOOP;
END $$;

COMMIT;
