-- =====================================================================
-- Core Platform: "these are not duplicates"
-- ---------------------------------------------------------------------
-- Settings -> Duplicates lists customers/suppliers (cp_parties) and products
-- (cp_products) of a business that look like the same record entered twice,
-- and merges them with cp_party_merge / cp_product_merge (20261019-29..31).
-- Two records that only LOOK alike (two "Kofi Mensah"s) are marked as not
-- duplicates once, and the screen stops offering them:
--
--   core_platform.cp_duplicate_dismissals   one row per pair said to be different,
--                                           per business; a_id < b_id (sorted by
--                                           code point), so a pair is stored once
--                                           whichever way round it was sent
--
-- A dismissed pair stays dismissed when a third record joins the group: only
-- the pairs the person looked at are dismissed.
--
-- Grants: none here. Like every core_platform table, Core Platform's role reads
-- and writes it through the schema's default privileges.
--
-- Re-runs every deploy: idempotent.
-- =====================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS core_platform.cp_duplicate_dismissals (
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    kind         text NOT NULL CHECK (kind IN ('party', 'product')),
    a_id         text NOT NULL,
    b_id         text NOT NULL,
    dismissed_by text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (kind, a_id, b_id),
    CHECK (a_id < b_id COLLATE "C")
);
CREATE INDEX IF NOT EXISTS cp_duplicate_dismissals_bus_idx
    ON core_platform.cp_duplicate_dismissals (tenant_id, bus_id, kind);

COMMIT;
