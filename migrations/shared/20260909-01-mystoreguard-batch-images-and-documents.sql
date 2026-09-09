-- Images and documents belong to the delivery, not the product.
--
-- A product photograph used to hang off the product, which said "this is what
-- this model looks like". That is the wrong claim for a shop that buys the same
-- model repeatedly: one delivery arrives sealed, the next is ex-display with a
-- scuffed corner, a third comes in a different colour. One picture standing for
-- all of them shows the customer something they are not being sold, and the
-- receipt for the scuffed one carries the photograph of the sealed one.
--
-- So the link moves to the batch, exactly as the shop's own Products fields did
-- in 20260907-02, and for the same reason: what arrived is a property of the
-- arrival.
--
-- "The product's image" does not disappear as an idea — the storefront, the
-- catalogue and the till all need one. It is now DERIVED: the newest batch that
-- has an image speaks for the product. That keeps every one of those screens
-- working with nothing extra to fill in, and it means the shop window shows what
-- is actually on the shelf rather than what was on it two years ago.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_batch_document_ids (
    tenant_id     text NOT NULL,
    id            text NOT NULL,
    org_id        text NOT NULL,
    bus_id        text NOT NULL,
    batch_id      text NOT NULL,
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

    CONSTRAINT pk_msg_batch_document_ids PRIMARY KEY (tenant_id, id),
    CONSTRAINT ck_msg_batch_document_ids_delete_status
        CHECK (delete_status = ANY (ARRAY['PENDING', 'DELETED', 'NOT_DELETED'])),

    CONSTRAINT fk_msg_batch_document_ids_cp_tenants
        FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants(id) ON DELETE CASCADE,
    CONSTRAINT fk_msg_batch_document_ids_cp_organizations
        FOREIGN KEY (org_id, tenant_id) REFERENCES core_platform.cp_organizations(id, tenant_id) ON DELETE RESTRICT,
    CONSTRAINT fk_msg_batch_document_ids_cp_businesses
        FOREIGN KEY (bus_id, tenant_id) REFERENCES core_platform.cp_businesses(id, tenant_id) ON DELETE RESTRICT,

    -- The file itself. Removing a document takes its links with it, so a picture
    -- deleted from the file manager cannot leave a batch pointing at nothing.
    CONSTRAINT fk_msg_batch_document_ids_document
        FOREIGN KEY (tenant_id, org_id, bus_id, document_id)
        REFERENCES mystoreguard.msg_document_paths(tenant_id, org_id, bus_id, id) ON DELETE CASCADE,

    -- The batch. CASCADE deliberately: a delivery that is deleted or reversed
    -- takes its own photographs with it. The product link table had no such
    -- constraint to the product, which is how deleting a product left orphaned
    -- rows behind.
    CONSTRAINT fk_msg_batch_document_ids_batch
        FOREIGN KEY (tenant_id, org_id, bus_id, batch_id)
        REFERENCES mystoreguard.msg_purchase_batches(tenant_id, org_id, bus_id, id) ON DELETE CASCADE
);

-- The two questions ever asked of this table: "what does this delivery look
-- like" and "which deliveries use this file".
CREATE INDEX IF NOT EXISTS ix_msg_batch_document_ids_batch
    ON mystoreguard.msg_batch_document_ids (tenant_id, org_id, bus_id, batch_id)
    WHERE delete_status = 'NOT_DELETED';

CREATE INDEX IF NOT EXISTS ix_msg_batch_document_ids_document
    ON mystoreguard.msg_batch_document_ids (tenant_id, org_id, bus_id, document_id);

-- One file attached once to a delivery. Re-uploading the same picture should not
-- make the carousel show it twice.
CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_batch_document_ids_batch_document
    ON mystoreguard.msg_batch_document_ids (tenant_id, org_id, bus_id, batch_id, document_id)
    WHERE delete_status = 'NOT_DELETED';

COMMENT ON TABLE mystoreguard.msg_batch_document_ids IS
    'Images and documents for one delivery. The product''s own picture is derived '
    'from the newest batch that has one, so the shop window shows what is on the '
    'shelf rather than what the model looked like years ago.';


-- ---------------------------------------------------------------------------
-- Carry the existing product images onto a delivery, so nothing uploaded so far
-- is orphaned.
--
-- Onto the product's OLDEST batch: those pictures were taken of the product as
-- it first arrived, and the oldest delivery is the closest thing to a truthful
-- home for them. Putting them on the newest would be a lie about a delivery
-- somebody photographed separately.
--
-- Products with no batch at all keep their rows in the old table untouched;
-- there is nowhere to move them to, and dropping them would lose the file.
-- ---------------------------------------------------------------------------
INSERT INTO mystoreguard.msg_batch_document_ids
    (tenant_id, id, org_id, bus_id, batch_id, document_id,
     cdate, ctime, cdatetime, created_by, delete_status, is_active, description)
SELECT pdi.tenant_id,
       'bdoc_' || md5(pdi.id || ':' || oldest.id),
       pdi.org_id, pdi.bus_id, oldest.id, pdi.document_id,
       pdi.cdate, pdi.ctime, pdi.cdatetime, pdi.created_by,
       'NOT_DELETED', true,
       COALESCE(pdi.description, 'Moved from the product when images became per-delivery')
  FROM mystoreguard.msg_product_document_ids pdi
  JOIN LATERAL (
        SELECT pb.id
          FROM mystoreguard.msg_purchase_batches pb
         WHERE pb.product_id = pdi.product_id
           AND pb.tenant_id = pdi.tenant_id
           AND pb.org_id = pdi.org_id
           AND pb.bus_id = pdi.bus_id
           AND pb.delete_status = 'NOT_DELETED'
         ORDER BY pb.cdatetime ASC, pb.id ASC
         LIMIT 1
       ) oldest ON TRUE
 WHERE pdi.delete_status = 'NOT_DELETED'
ON CONFLICT DO NOTHING;
