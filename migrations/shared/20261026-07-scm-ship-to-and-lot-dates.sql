-- SCM: where an order goes, and when a lot was made.
--
--   scm_sales_orders   ship_to_*: the address the customer wants the goods delivered to, typed
--                      on the order (prefilled from the customer's address, changed per order).
--                      All null when the order names none.
--   scm_shipments      ship_to_*: the address a shipment goes to, copied from its order when
--                      the shipment is made and corrected on the shipment while it is a draft
--                      or packed. A copy, not a reference: what was shipped where stays true
--                      when the order's address changes later.
--   scm_lots           manufactured_date beside expiry_date, so a lot's dates can be corrected
--                      together (PATCH /scm/v1/inventory/lots/{id}).
--
-- Plain nullable columns on tables 20261026-04 and -05 own; no data is moved. Idempotent; safe
-- to re-run.

BEGIN;

-- ============================================================= sales orders
ALTER TABLE scm.scm_sales_orders ADD COLUMN IF NOT EXISTS ship_to_name        text;
ALTER TABLE scm.scm_sales_orders ADD COLUMN IF NOT EXISTS ship_to_line1       text;
ALTER TABLE scm.scm_sales_orders ADD COLUMN IF NOT EXISTS ship_to_line2       text;
ALTER TABLE scm.scm_sales_orders ADD COLUMN IF NOT EXISTS ship_to_city        text;
ALTER TABLE scm.scm_sales_orders ADD COLUMN IF NOT EXISTS ship_to_region      text;
ALTER TABLE scm.scm_sales_orders ADD COLUMN IF NOT EXISTS ship_to_postal_code text;
ALTER TABLE scm.scm_sales_orders ADD COLUMN IF NOT EXISTS ship_to_country     text;
ALTER TABLE scm.scm_sales_orders ADD COLUMN IF NOT EXISTS ship_to_phone       text;
-- A country is an ISO two-letter code, as on core_platform.cp_parties.
ALTER TABLE scm.scm_sales_orders DROP CONSTRAINT IF EXISTS scm_sales_orders_ship_to_country_check;
ALTER TABLE scm.scm_sales_orders ADD CONSTRAINT scm_sales_orders_ship_to_country_check
    CHECK (ship_to_country IS NULL OR ship_to_country ~ '^[A-Z]{2}$');

-- ================================================================ shipments
ALTER TABLE scm.scm_shipments ADD COLUMN IF NOT EXISTS ship_to_name        text;
ALTER TABLE scm.scm_shipments ADD COLUMN IF NOT EXISTS ship_to_line1       text;
ALTER TABLE scm.scm_shipments ADD COLUMN IF NOT EXISTS ship_to_line2       text;
ALTER TABLE scm.scm_shipments ADD COLUMN IF NOT EXISTS ship_to_city        text;
ALTER TABLE scm.scm_shipments ADD COLUMN IF NOT EXISTS ship_to_region      text;
ALTER TABLE scm.scm_shipments ADD COLUMN IF NOT EXISTS ship_to_postal_code text;
ALTER TABLE scm.scm_shipments ADD COLUMN IF NOT EXISTS ship_to_country     text;
ALTER TABLE scm.scm_shipments ADD COLUMN IF NOT EXISTS ship_to_phone       text;
ALTER TABLE scm.scm_shipments DROP CONSTRAINT IF EXISTS scm_shipments_ship_to_country_check;
ALTER TABLE scm.scm_shipments ADD CONSTRAINT scm_shipments_ship_to_country_check
    CHECK (ship_to_country IS NULL OR ship_to_country ~ '^[A-Z]{2}$');

-- ===================================================================== lots
ALTER TABLE scm.scm_lots ADD COLUMN IF NOT EXISTS manufactured_date date;
ALTER TABLE scm.scm_lots DROP CONSTRAINT IF EXISTS scm_lots_dates_check;
ALTER TABLE scm.scm_lots ADD CONSTRAINT scm_lots_dates_check
    CHECK (manufactured_date IS NULL OR expiry_date IS NULL OR manufactured_date <= expiry_date);

-- =============================================================== invariants
DO $$
DECLARE
    n int;
BEGIN
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'scm' AND table_name IN ('scm_sales_orders', 'scm_shipments') AND column_name LIKE 'ship_to\_%';
    IF n <> 16 THEN
        RAISE EXCEPTION 'scm: % ship-to column(s) on sales orders and shipments, want 16', n;
    END IF;
END $$;

COMMIT;
