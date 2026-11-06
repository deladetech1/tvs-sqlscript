-- SCM: serial numbers follow the stock on transfers and returns; MyStoreGuard dismisses a failed
-- link message (apps-setup/msg-scm-integration-plan.md).
--
-- SCM (shipments already name their units: 20261102-45):
--   scm_transfer_line_serials  the units a transfer line moves, chosen while it is a draft. When
--                              the transfer is shipped each unit is in transit (status in_transit,
--                              no warehouse or bin, scm_serials.transfer_id set); received, it is
--                              in stock at the destination warehouse and bin, of the line's lot;
--                              cancelled in transit, back where it left from.
--   scm_return_line_serials    the units a return line takes back. A customer return names only
--                              units shipped on the very shipment line it returns; completing it
--                              puts them back in stock (restock / quarantine) at the return's
--                              warehouse, of the line's lot, or scraps them. A supplier return
--                              names units of the receipt line's lot still in stock; completing it
--                              marks them returned (they leave).
--   scm_serial_history         one row per thing that happened to a unit (event, the document,
--                              where it went, its status after). Append-only by convention.
--   status in_transit          added to the status list, which lives in 20261029-23.
--
-- MyStoreGuard:
--   msg_link_inbox DISMISSED   a dead letter (DEAD / REFUSED) a person looked at and closed in
--                              Settings -> Integrations -> SCM messages. Kept for audit
--                              (dismissed_at, dismissed_by, dismissed_from); never retried, and not
--                              listed by Core Platform's link drawer (it reads DEAD / REFUSED only).
--
-- Idempotent; safe to re-run.

BEGIN;

DO $$
BEGIN
    IF to_regclass('scm.scm_serials') IS NOT NULL THEN
        CREATE TABLE IF NOT EXISTS scm.scm_transfer_line_serials (
            transfer_line_id text NOT NULL REFERENCES scm.scm_transfer_lines (id) ON DELETE CASCADE,
            serial_id        text NOT NULL REFERENCES scm.scm_serials (id),
            tenant_id        text NOT NULL,
            bus_id           text NOT NULL,
            cdatetime        timestamptz NOT NULL DEFAULT now(),
            PRIMARY KEY (transfer_line_id, serial_id)
        );
        CREATE INDEX IF NOT EXISTS scm_transfer_line_serials_serial_idx ON scm.scm_transfer_line_serials (serial_id);

        ALTER TABLE scm.scm_serials ADD COLUMN IF NOT EXISTS transfer_id text REFERENCES scm.scm_transfers (id);
        CREATE INDEX IF NOT EXISTS scm_serials_transfer_idx ON scm.scm_serials (transfer_id) WHERE transfer_id IS NOT NULL;

        CREATE TABLE IF NOT EXISTS scm.scm_return_line_serials (
            return_line_id text NOT NULL REFERENCES scm.scm_return_lines (id) ON DELETE CASCADE,
            serial_id      text NOT NULL REFERENCES scm.scm_serials (id),
            tenant_id      text NOT NULL,
            bus_id         text NOT NULL,
            cdatetime      timestamptz NOT NULL DEFAULT now(),
            PRIMARY KEY (return_line_id, serial_id)
        );
        CREATE INDEX IF NOT EXISTS scm_return_line_serials_serial_idx ON scm.scm_return_line_serials (serial_id);

        CREATE TABLE IF NOT EXISTS scm.scm_serial_history (
            id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
            tenant_id      text NOT NULL,
            org_id         text,
            bus_id         text NOT NULL,
            serial_id      text NOT NULL REFERENCES scm.scm_serials (id) ON DELETE CASCADE,
            event          text NOT NULL,
            ref_type       text,
            ref_id         text,
            status         text NOT NULL,
            warehouse_id   text,
            bin_id         text,
            lot_id         text,
            from_warehouse_id text,
            from_bin_id    text,
            note           text,
            cdatetime      timestamptz NOT NULL DEFAULT now(),
            created_by     text
        );
        CREATE INDEX IF NOT EXISTS scm_serial_history_serial_idx ON scm.scm_serial_history (serial_id, cdatetime);
        CREATE INDEX IF NOT EXISTS scm_serial_history_ref_idx ON scm.scm_serial_history (ref_type, ref_id);
    END IF;

    IF to_regclass('mystoreguard.msg_link_inbox') IS NOT NULL THEN
        ALTER TABLE mystoreguard.msg_link_inbox ADD COLUMN IF NOT EXISTS dismissed_at   timestamptz;
        ALTER TABLE mystoreguard.msg_link_inbox ADD COLUMN IF NOT EXISTS dismissed_by   text;
        ALTER TABLE mystoreguard.msg_link_inbox ADD COLUMN IF NOT EXISTS dismissed_from text;
        ALTER TABLE mystoreguard.msg_link_inbox DROP CONSTRAINT IF EXISTS ck_msg_link_inbox_status;
        ALTER TABLE mystoreguard.msg_link_inbox ADD CONSTRAINT ck_msg_link_inbox_status
            CHECK (status IN ('PENDING', 'RETRY', 'DONE', 'REFUSED', 'DEAD', 'DISMISSED'));
        CREATE INDEX IF NOT EXISTS msg_link_inbox_failed ON mystoreguard.msg_link_inbox (tenant_id, bus_id)
            WHERE status IN ('DEAD', 'REFUSED');
    END IF;
END $$;

-- ===================================================================== checks (invariants, not counts)
DO $$
BEGIN
    IF to_regclass('scm.scm_serials') IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'scm_serials_status_check'
           AND pg_get_constraintdef(oid) LIKE '%in_transit%') THEN
        RAISE EXCEPTION 'scm serials: the status list (20261029-23) must allow in_transit';
    END IF;
END $$;

COMMIT;
