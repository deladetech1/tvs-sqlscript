-- Somewhere to put the stock.
--
-- Today the system can say stock is at Kasoa, on the shop floor. It cannot say
-- which rack. So "we have three left" is answerable and "where are they" is
-- not, and somebody walks the shop looking.
--
-- A storage place is anywhere a shop puts things and can label: a rack, a
-- shelf, a bin, a fridge, a bay, a crate. Deliberately not three fixed levels
-- called rack/shelf/bin, because this is used by every kind of shop and most of
-- them do not think that way — a pharmacy thinks fridge, controlled cupboard,
-- open shelf, and those categories are about temperature and the law rather
-- than geometry. Forced into somebody else's vocabulary, a shop either leaves
-- levels empty or lies about what they mean.
--
-- Instead a place can sit inside another place, to whatever depth a shop
-- wants, and each shop names its own levels. A kiosk with three crates nests
-- nothing. A warehouse nests four deep. Same table.
--
-- Nesting rather than one flat list is what makes "how full is Rack B" and
-- "everything in the cold room" answerable without every shop having to encode
-- its structure into the names by hand.
--
-- OPTIONAL, ENTIRELY. A business that never opens the screen has no rows here,
-- every place_id below stays null, and nothing it does today behaves
-- differently.
--
-- What this deliberately does NOT do: hold quantities. Stock still counts the
-- way it counts now. A place is an address, not a container with its own
-- total. Per-place quantities would mean teaching every one of the fifty-odd
-- statements that move stock — and the deferred trigger that guards those
-- counts — about a new dimension, and that is a different piece of work
-- nobody should pay for until a shop has actually asked for it.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_storage_places (
    id             text NOT NULL,
    tenant_id      text NOT NULL,
    org_id         text NOT NULL,
    bus_id         text NOT NULL,

    -- Which branch, and which side of it. Stock is already counted separately
    -- for the shop floor and the stockroom, so a place that did not say which
    -- one it was on would leave "ten curtains on Rack A" unable to say whether
    -- that is shop stock or back stock — which the system can always say
    -- today. A rack physically straddling both becomes two places.
    loc_id         text NOT NULL,
    location_type  text NOT NULL,

    -- The place this one sits inside. Null for a top-level place. A parent must
    -- be at the same branch and on the same side; the service enforces that,
    -- since a foreign key cannot express it.
    parent_id      text,

    name           text NOT NULL,
    -- What goes on the sticker — "B-3-02". Optional, because a shop that only
    -- has "Front window" and "Cold room" has no use for codes, and unique per
    -- branch-and-side so scanning or typing one lands in exactly one place.
    code           text,
    -- What THIS shop calls this depth: Rack, Shelf, Bin, Fridge, Bay, Crate.
    -- Free text on purpose. The system does not need to know what a rack is;
    -- it needs the screen to read in the shop's own words.
    level_label    text,

    description    text,
    sort_order     integer NOT NULL DEFAULT 0,
    is_active      boolean NOT NULL DEFAULT true,
    delete_status  text NOT NULL DEFAULT 'NOT_DELETED',

    cdate          text,
    ctime          text,
    cdatetime      timestamptz NOT NULL DEFAULT NOW(),
    created_by     text,
    updated_by     text,
    deleted_by     text,

    CONSTRAINT pk_msg_storage_places PRIMARY KEY (tenant_id, org_id, bus_id, id),
    CONSTRAINT ck_msg_storage_places_location_type
        CHECK (location_type = ANY (ARRAY['STORE'::text, 'WAREHOUSE'::text])),
    CONSTRAINT ck_msg_storage_places_delete_status
        CHECK (delete_status = ANY (ARRAY['NOT_DELETED'::text, 'DELETED'::text])),
    -- A place cannot be inside itself. Deeper loops are the service's to
    -- refuse, but this one is cheap and catches the obvious slip.
    CONSTRAINT ck_msg_storage_places_not_its_own_parent
        CHECK (parent_id IS NULL OR parent_id <> id),

    CONSTRAINT fk_msg_storage_places_tenant
        FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants(id) ON DELETE CASCADE,
    CONSTRAINT fk_msg_storage_places_location
        FOREIGN KEY (loc_id, tenant_id)
        REFERENCES core_platform.cp_locations(id, tenant_id) ON DELETE RESTRICT,
    -- A place that contains another cannot simply vanish; the service moves or
    -- refuses first, so the tree can never be left with orphans pointing at a
    -- row that is gone.
    CONSTRAINT fk_msg_storage_places_parent
        FOREIGN KEY (tenant_id, org_id, bus_id, parent_id)
        REFERENCES mystoreguard.msg_storage_places(tenant_id, org_id, bus_id, id)
        ON DELETE RESTRICT
);

-- One code per branch-and-side. Partial, so a deleted place frees its code for
-- reuse — a shop that dismantles Rack B and builds a new one should be able to
-- call it Rack B.
CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_storage_places_code
    ON mystoreguard.msg_storage_places (tenant_id, org_id, bus_id, loc_id, location_type, lower(code))
    WHERE code IS NOT NULL AND delete_status = 'NOT_DELETED';

CREATE INDEX IF NOT EXISTS ix_msg_storage_places_lookup
    ON mystoreguard.msg_storage_places (tenant_id, org_id, bus_id, loc_id, location_type)
    WHERE delete_status = 'NOT_DELETED';

-- Walking the tree downward, which is how the screen draws it and how a total
-- rolls up from the places inside a place.
CREATE INDEX IF NOT EXISTS ix_msg_storage_places_parent
    ON mystoreguard.msg_storage_places (tenant_id, org_id, bus_id, parent_id)
    WHERE delete_status = 'NOT_DELETED';


-- ---------------------------------------------------------------------------
-- Where a thing actually is
-- ---------------------------------------------------------------------------
--
-- Nullable everywhere, and null means "nobody has said" — which is every row
-- that exists today and every row belonging to a shop that never uses this.
--
-- On an individually tracked item this is a complete fact: that handset, that
-- bin. On a delivery of counted stock it means "where this delivery is kept",
-- which is true for most shops most of the time but cannot express forty
-- curtains split across two racks. Splitting needs per-place quantities, and
-- that is the work this migration is deliberately not doing.

ALTER TABLE mystoreguard.msg_product_units
    ADD COLUMN IF NOT EXISTS place_id text;

ALTER TABLE mystoreguard.msg_batch_locations
    ADD COLUMN IF NOT EXISTS place_id text;

COMMENT ON COLUMN mystoreguard.msg_product_units.place_id IS
    'Which storage place this item is in. Null means nobody has recorded one.';

COMMENT ON COLUMN mystoreguard.msg_batch_locations.place_id IS
    'Where this delivery is kept at this branch and side. Null means nobody has '
    'recorded one. Holds no quantity: one delivery has one place here, so stock '
    'genuinely split across places needs per-place quantities, which this is not.';

-- Deliberately ON DELETE SET NULL rather than RESTRICT: a shop dismantling a
-- rack should not be blocked by stock still pointing at it. The stock is still
-- there and still counted — it has simply gone back to having no recorded
-- address, which is where everything starts.
ALTER TABLE mystoreguard.msg_product_units
    DROP CONSTRAINT IF EXISTS fk_msg_product_units_storage_place;
ALTER TABLE mystoreguard.msg_product_units
    ADD CONSTRAINT fk_msg_product_units_storage_place
    FOREIGN KEY (tenant_id, org_id, bus_id, place_id)
    REFERENCES mystoreguard.msg_storage_places(tenant_id, org_id, bus_id, id)
    ON DELETE SET NULL;

ALTER TABLE mystoreguard.msg_batch_locations
    DROP CONSTRAINT IF EXISTS fk_msg_batch_locations_storage_place;
ALTER TABLE mystoreguard.msg_batch_locations
    ADD CONSTRAINT fk_msg_batch_locations_storage_place
    FOREIGN KEY (tenant_id, org_id, bus_id, place_id)
    REFERENCES mystoreguard.msg_storage_places(tenant_id, org_id, bus_id, id)
    ON DELETE SET NULL;

-- "What is in this place" is the question the whole feature exists to answer,
-- so it should not be a scan of every item the shop has ever recorded.
CREATE INDEX IF NOT EXISTS ix_msg_product_units_place
    ON mystoreguard.msg_product_units (tenant_id, org_id, bus_id, place_id)
    WHERE place_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_msg_batch_locations_place
    ON mystoreguard.msg_batch_locations (tenant_id, org_id, bus_id, place_id)
    WHERE place_id IS NOT NULL;
