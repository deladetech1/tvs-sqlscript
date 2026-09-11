-- How a product is packed, and what that meant on the day it arrived.
--
-- A shop sells water by the pallet, the pack and the bottle; a chemist by the
-- box, the strip and the tablet. Those are not three products — they are one
-- product counted at three scales, and the only honest way to hold that is to
-- count the smallest thing and multiply for everything else.
--
-- Nothing here changes what any existing row means. A product with no rows in
-- msg_product_packaging_levels is counted exactly as it is today, its
-- quantities are the same integers, and no screen it appears on shows anything
-- new. The feature exists only where somebody has described their packaging.
--
-- Deliberately NOT a unit-conversion table on cp_unit_of_measures. A "case" is
-- not a unit of measure the way a kilogram is: it means 24 for one product and
-- 12 for the next, and a shared table would have to be per-product anyway. The
-- chain belongs to the product that is packed that way.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_product_packaging_levels (
    tenant_id     text NOT NULL,
    id            text NOT NULL,
    org_id        text NOT NULL,
    bus_id        text NOT NULL,
    product_id    text NOT NULL,

    -- 1 is the biggest thing the shop handles, counting down. The last row of a
    -- product is its base: what stock is actually counted in.
    level_no      integer NOT NULL,
    name          text NOT NULL,

    -- How many of the NEXT level down this one holds. Null on the base, which
    -- has nothing below it.
    --
    -- Held as the step rather than as "how many of the smallest", because the
    -- step is what a person knows — "a case is twelve packs" — and the total is
    -- arithmetic anyone can get wrong. The multiplication is the computer's job.
    contains      integer,

    cdate         text,
    ctime         text,
    cdatetime     timestamp with time zone,
    created_by    text,
    updated_by    text,

    CONSTRAINT pk_msg_product_packaging_levels PRIMARY KEY (tenant_id, id),

    CONSTRAINT fk_msg_packaging_levels_cp_tenants
        FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants(id) ON DELETE CASCADE,
    CONSTRAINT fk_msg_packaging_levels_cp_organizations
        FOREIGN KEY (org_id, tenant_id) REFERENCES core_platform.cp_organizations(id, tenant_id) ON DELETE RESTRICT,
    CONSTRAINT fk_msg_packaging_levels_cp_businesses
        FOREIGN KEY (bus_id, tenant_id) REFERENCES core_platform.cp_businesses(id, tenant_id) ON DELETE RESTRICT,

    -- A product's packaging has no meaning without the product.
    CONSTRAINT fk_msg_packaging_levels_product
        FOREIGN KEY (tenant_id, org_id, bus_id, product_id)
        REFERENCES mystoreguard.msg_products(tenant_id, org_id, bus_id, id) ON DELETE CASCADE,

    -- A level holds a whole number of the one below, and at least one. Zero or
    -- a negative would make the whole chain meaningless rather than merely
    -- wrong, so it is refused here and not only in the form.
    CONSTRAINT ck_msg_packaging_levels_contains
        CHECK (contains IS NULL OR contains >= 1)
);

-- Read one way only: "this product's levels, biggest first".
CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_packaging_levels_product_level
    ON mystoreguard.msg_product_packaging_levels
       (tenant_id, org_id, bus_id, product_id, level_no);

-- Two levels of one product cannot share a name, or the dropdown offers the
-- same word twice and nobody can tell which they picked.
CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_packaging_levels_product_name
    ON mystoreguard.msg_product_packaging_levels
       (tenant_id, org_id, bus_id, product_id, lower(name));

COMMENT ON TABLE mystoreguard.msg_product_packaging_levels IS
    'How one product is packed: pallet holds 50 packs, pack holds 15 bottles, '
    'bottle is counted. Biggest first; the last row is the base unit that all '
    'stock is stored in. A product with no rows is counted in plain units.';


-- ---------------------------------------------------------------------------
-- What the packaging meant on the day this delivery arrived.
-- ---------------------------------------------------------------------------
-- A supplier changes their case from 24 to 20 next year. The product's chain is
-- edited, and every delivery already received would silently start meaning
-- something else — last year's "2 cases" becoming 40 instead of 48.
--
-- So the chain is copied onto the delivery, exactly as cost and price already
-- are. The product says how it is packed TODAY; the batch says how it was packed
-- WHEN IT CAME IN, and old paperwork keeps its meaning for ever.
--
-- JSONB rather than a child table: this is read whole, written once, and never
-- joined or filtered on. A table here would be a join for nothing.
ALTER TABLE mystoreguard.msg_purchase_batches
    ADD COLUMN IF NOT EXISTS packaging jsonb;

COMMENT ON COLUMN mystoreguard.msg_purchase_batches.packaging IS
    'The product packaging as it stood when this delivery was received: '
    '[{"name": "Pallet", "contains": 50}, {"name": "Pack", "contains": 15}, '
    '{"name": "Bottle", "contains": null}]. Null where the product has none. '
    'Frozen, so editing the product later cannot rewrite what this delivery '
    'meant.';

-- Which level the storekeeper typed in. Only ever used to say the quantity back
-- to a person — "2 Pallets" — never to calculate with: qty_received is already
-- in base units and stays the only number anything reads.
ALTER TABLE mystoreguard.msg_purchase_batches
    ADD COLUMN IF NOT EXISTS entered_unit text;

COMMENT ON COLUMN mystoreguard.msg_purchase_batches.entered_unit IS
    'The packaging level this delivery was entered in, for display only. '
    'Null means it was entered in base units, which is every delivery taken in '
    'before packaging existed.';
