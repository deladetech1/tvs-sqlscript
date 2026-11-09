-- SCM: a reservation may hold stock for any demand, not only a sales-order line.
--
-- Manufacturing reserves components for production orders (and, later, spare parts for
-- maintenance orders) in the same scm_reservations table SCM uses, so scm_rebuild_balances and
-- every "available" figure count them. Each reservation names its demand:
--
--   demand_type  'sales_order_line' (SCM, unchanged), 'production_order', 'maintenance_order',
--                'transfer' -- the list is a CHECK in 20261029-21, a file of its own
--   demand_id    the id of that demand; for a sales-order line it is so_line_id
--
-- so_line_id stays, set exactly when the demand is a sales-order line, so SCM's queries and joins
-- keep working and never see another app's reservations. SCM's INSERTs name neither new column:
-- demand_type defaults to 'sales_order_line' and a trigger copies so_line_id into demand_id.
--
-- Idempotent; safe to re-run.

BEGIN;

ALTER TABLE scm.scm_reservations ADD COLUMN IF NOT EXISTS demand_type text NOT NULL DEFAULT 'sales_order_line';
ALTER TABLE scm.scm_reservations ADD COLUMN IF NOT EXISTS demand_id text;
ALTER TABLE scm.scm_reservations ALTER COLUMN so_line_id DROP NOT NULL;

UPDATE scm.scm_reservations SET demand_id = so_line_id WHERE demand_id IS NULL AND so_line_id IS NOT NULL;

CREATE OR REPLACE FUNCTION scm.scm_reservations_demand() RETURNS trigger
LANGUAGE plpgsql AS $f$
BEGIN
    IF NEW.demand_type = 'sales_order_line' AND NEW.demand_id IS NULL THEN
        NEW.demand_id := NEW.so_line_id;
    END IF;
    RETURN NEW;
END
$f$;
DROP TRIGGER IF EXISTS scm_reservations_demand ON scm.scm_reservations;
CREATE TRIGGER scm_reservations_demand BEFORE INSERT OR UPDATE ON scm.scm_reservations
    FOR EACH ROW EXECUTE FUNCTION scm.scm_reservations_demand();

ALTER TABLE scm.scm_reservations DROP CONSTRAINT IF EXISTS scm_reservations_demand_check;
ALTER TABLE scm.scm_reservations ADD CONSTRAINT scm_reservations_demand_check CHECK (
    demand_id IS NOT NULL
    AND (demand_type = 'sales_order_line') = (so_line_id IS NOT NULL)
    AND (so_line_id IS NULL OR demand_id = so_line_id));

CREATE INDEX IF NOT EXISTS scm_reservations_demand_idx
    ON scm.scm_reservations (bus_id, demand_type, demand_id, status);

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM scm.scm_reservations WHERE demand_id IS NULL) THEN
        RAISE EXCEPTION 'scm_reservations: a reservation names no demand';
    END IF;
END $$;

COMMIT;
