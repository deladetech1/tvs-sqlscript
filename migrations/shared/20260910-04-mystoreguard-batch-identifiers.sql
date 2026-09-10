-- The numbers written on a delivery that nobody is naming item by item.
--
-- A counted delivery still arrives with numbers on it: a lot code on the carton,
-- the EAN on the box, the supplier's own reference. They identify the delivery,
-- not any one unit inside it — five hundred tins of Milo share one lot number,
-- and no tin has a serial.
--
-- A tracked delivery keeps its numbers where they belong, on each item, in
-- msg_product_unit_identifiers. This table is the same idea one level up, and
-- the two never overlap: the check added in 20260910-03 already refuses items on
-- a counted delivery.
--
-- Deliberately NOT globally unique, unlike an item's numbers. An item's serial
-- identifies one physical object and taking it in twice is an error worth
-- refusing. A lot code is shared by everything in the lot, and two deliveries of
-- the same 256GB phone genuinely carry the same EAN — refusing the second would
-- be refusing the truth.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_batch_identifiers (
    tenant_id     text NOT NULL,
    id            text NOT NULL,
    org_id        text NOT NULL,
    bus_id        text NOT NULL,
    batch_id      text NOT NULL,
    label         text NOT NULL,
    value         text NOT NULL,
    is_primary    boolean NOT NULL DEFAULT false,
    cdate         text,
    ctime         text,
    cdatetime     timestamp with time zone,
    created_by    text,
    updated_by    text,

    CONSTRAINT pk_msg_batch_identifiers PRIMARY KEY (tenant_id, id),

    CONSTRAINT fk_msg_batch_identifiers_cp_tenants
        FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants(id) ON DELETE CASCADE,
    CONSTRAINT fk_msg_batch_identifiers_cp_organizations
        FOREIGN KEY (org_id, tenant_id) REFERENCES core_platform.cp_organizations(id, tenant_id) ON DELETE RESTRICT,
    CONSTRAINT fk_msg_batch_identifiers_cp_businesses
        FOREIGN KEY (bus_id, tenant_id) REFERENCES core_platform.cp_businesses(id, tenant_id) ON DELETE RESTRICT,

    -- A delivery that is reversed or deleted takes its numbers with it. There is
    -- nothing to keep: the code described that arrival and no other.
    CONSTRAINT fk_msg_batch_identifiers_batch
        FOREIGN KEY (tenant_id, org_id, bus_id, batch_id)
        REFERENCES mystoreguard.msg_purchase_batches(tenant_id, org_id, bus_id, id) ON DELETE CASCADE
);

-- The two questions asked of it: "what is written on this delivery" and, at a
-- counter, "which delivery does this scanned code belong to".
CREATE INDEX IF NOT EXISTS ix_msg_batch_identifiers_batch
    ON mystoreguard.msg_batch_identifiers (tenant_id, org_id, bus_id, batch_id);

CREATE INDEX IF NOT EXISTS ix_msg_batch_identifiers_value
    ON mystoreguard.msg_batch_identifiers (tenant_id, org_id, bus_id, upper(value));

-- One code recorded once against one delivery. Typing it twice is a slip, not a
-- second code.
CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_batch_identifiers_batch_value
    ON mystoreguard.msg_batch_identifiers (tenant_id, org_id, bus_id, batch_id, upper(value));

COMMENT ON TABLE mystoreguard.msg_batch_identifiers IS
    'Numbers written on a counted delivery — a lot code, the carton EAN, the '
    'supplier''s reference. They identify the arrival, not any unit in it; a '
    'delivery whose units are named individually keeps its numbers on the items.';
