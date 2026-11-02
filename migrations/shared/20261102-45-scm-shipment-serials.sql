-- SCM: which serial numbers a shipment sends (MSG-SCM phase 1 leftover).
--
-- An item tracked by serial number could not be shipped at all: shipping refused it ("which
-- shipping does not take yet"). Now each shipment line of such an item names the very units that
-- go, as MyStoreGuard's sales name their units:
--
--   scm_shipment_line_serials  one row per unit on a shipment line. Chosen while the shipment is a
--                              draft; checked again when it is packed and when it leaves (the unit
--                              must be in stock in the shipment's warehouse, of the line's lot when
--                              the line names one, and on no other shipment still going); a line
--                              sends exactly as many units as its quantity. Rewriting a draft's
--                              lines drops them with the line (ON DELETE CASCADE).
--   scm_serials.shipment_id    the shipment a unit left on; status 'shipped' (the status list,
--                              20261029-23, already has it) and no warehouse or bin any more.
--
-- Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS scm.scm_shipment_line_serials (
    shipment_line_id text NOT NULL REFERENCES scm.scm_shipment_lines (id) ON DELETE CASCADE,
    serial_id        text NOT NULL REFERENCES scm.scm_serials (id),
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (shipment_line_id, serial_id)
);
CREATE INDEX IF NOT EXISTS scm_shipment_line_serials_serial_idx ON scm.scm_shipment_line_serials (serial_id);

ALTER TABLE scm.scm_serials ADD COLUMN IF NOT EXISTS shipment_id text REFERENCES scm.scm_shipments (id);
CREATE INDEX IF NOT EXISTS scm_serials_shipment_idx ON scm.scm_serials (shipment_id) WHERE shipment_id IS NOT NULL;

COMMIT;
