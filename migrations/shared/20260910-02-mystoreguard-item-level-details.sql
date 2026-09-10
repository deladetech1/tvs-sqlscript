-- An item recorded on its own describes itself.
--
-- "Record each item separately" has meant, until now, recording each item's
-- NUMBERS separately and everything else in common: the size, the colour, the
-- condition and the shop's own answers all sat on the batch. For twenty UK-used
-- iPhones in one consignment that forces a claim nobody believes — that they are
-- all 256GB, all Space Gray, all the same grade — which is the exact claim the
-- shop switched serialisation on to stop making.
--
-- So the split follows what is actually true of what:
--
--   the batch is the ARRIVAL   — supplier, date, currency, its papers, and the
--                                defaults for what came in on it;
--   the item is the THING      — its numbers, its size, its colour, its
--                                condition, its own photographs.
--
-- Everything here is NULLABLE and inherited: an item with nothing of its own
-- reads as its batch, so a delivery of fifty identical handsets is still typed
-- once. Only the two that differ are touched.
--
-- The same argument that moved photographs from the product to the batch moves
-- them again to the item, for the same reason: the scuff is on that handset, not
-- on the consignment. A shop selling used phones can now show the customer the
-- unit they are buying, and put it on the receipt.

ALTER TABLE mystoreguard.msg_product_units
    ADD COLUMN IF NOT EXISTS product_size text,
    ADD COLUMN IF NOT EXISTS description text,
    -- Cost and price per item, for stock bought and sold one at a time — a used
    -- handset rarely costs what the one beside it cost. Added now so the shape
    -- is settled; nothing reads them yet, and NULL means "the batch's".
    ADD COLUMN IF NOT EXISTS cost_price numeric,
    ADD COLUMN IF NOT EXISTS base_selling_price numeric;

COMMENT ON COLUMN mystoreguard.msg_product_units.product_size IS
    'This item''s own size or storage. NULL inherits the batch''s.';
COMMENT ON COLUMN mystoreguard.msg_product_units.description IS
    'What is true of THIS item — "small scratch on the back". NULL inherits the batch''s.';
COMMENT ON COLUMN mystoreguard.msg_product_units.cost_price IS
    'What this particular item cost. NULL inherits the batch''s.';
COMMENT ON COLUMN mystoreguard.msg_product_units.base_selling_price IS
    'What this particular item sells for. NULL inherits the batch''s.';


-- ---------------------------------------------------------------------------
-- Photographs of one item.
--
-- Mirrors msg_batch_document_ids exactly, one level down. A picture attached to
-- an item is a picture of that object: the screen, the scuffed corner, the IMEI
-- sticker. Deleting the item takes them with it; deleting the file takes its
-- links with it, so an item can never point at a picture that is gone.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mystoreguard.msg_unit_document_ids (
    tenant_id     text NOT NULL,
    id            text NOT NULL,
    org_id        text NOT NULL,
    bus_id        text NOT NULL,
    unit_id       text NOT NULL,
    document_id   text NOT NULL,
    cdate         text,
    ctime         text,
    cdatetime     timestamp with time zone,
    created_by    text,
    updated_by    text,
    deleted_by    text,
    delete_status text NOT NULL DEFAULT 'NOT_DELETED',
    is_active     boolean NOT NULL DEFAULT true,
    description   text,

    CONSTRAINT pk_msg_unit_document_ids PRIMARY KEY (tenant_id, id),
    CONSTRAINT ck_msg_unit_document_ids_delete_status
        CHECK (delete_status = ANY (ARRAY['PENDING', 'DELETED', 'NOT_DELETED'])),

    CONSTRAINT fk_msg_unit_document_ids_cp_tenants
        FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants(id) ON DELETE CASCADE,
    CONSTRAINT fk_msg_unit_document_ids_cp_organizations
        FOREIGN KEY (org_id, tenant_id) REFERENCES core_platform.cp_organizations(id, tenant_id) ON DELETE RESTRICT,
    CONSTRAINT fk_msg_unit_document_ids_cp_businesses
        FOREIGN KEY (bus_id, tenant_id) REFERENCES core_platform.cp_businesses(id, tenant_id) ON DELETE RESTRICT,

    CONSTRAINT fk_msg_unit_document_ids_document
        FOREIGN KEY (tenant_id, org_id, bus_id, document_id)
        REFERENCES mystoreguard.msg_document_paths(tenant_id, org_id, bus_id, id) ON DELETE CASCADE,

    -- The item. Keyed the way msg_product_units actually is — on tenant, org,
    -- business and id — which is also the foreign key the batch document table
    -- could not have to its product: an item deleted without its pictures
    -- leaves rows nothing can reach.
    CONSTRAINT fk_msg_unit_document_ids_unit
        FOREIGN KEY (tenant_id, org_id, bus_id, unit_id)
        REFERENCES mystoreguard.msg_product_units(tenant_id, org_id, bus_id, id) ON DELETE CASCADE
);

-- The two questions ever asked of this table: "what does this item look like"
-- and "which items use this file".
CREATE INDEX IF NOT EXISTS ix_msg_unit_document_ids_unit
    ON mystoreguard.msg_unit_document_ids (tenant_id, org_id, bus_id, unit_id)
    WHERE delete_status = 'NOT_DELETED';

CREATE INDEX IF NOT EXISTS ix_msg_unit_document_ids_document
    ON mystoreguard.msg_unit_document_ids (tenant_id, org_id, bus_id, document_id);

-- One file attached once to an item, so re-uploading the same photograph does
-- not make the carousel show it twice.
CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_unit_document_ids_unit_document
    ON mystoreguard.msg_unit_document_ids (tenant_id, org_id, bus_id, unit_id, document_id)
    WHERE delete_status = 'NOT_DELETED';

COMMENT ON TABLE mystoreguard.msg_unit_document_ids IS
    'Photographs of one individual item. What a shop selling used stock shows a '
    'customer and puts on the receipt: this is the handset you bought, as it '
    'left the shop.';
