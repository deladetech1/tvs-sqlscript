-- A custom field placed on Products is now answered against the BATCH.
--
-- Colour, condition, the grade a supplier shipped: these describe the stock that
-- arrived, not the catalogue entry. Answering them once against the product
-- forced every batch of that product to share one answer, which made the field
-- useless for exactly the things shops were using it for — a shop takes in red
-- phones one month and blue ones the next.
--
-- The module key stays 'products', because that is what a person picks in
-- Settings and what the field is about. What changes is the record the answer
-- hangs on: msg_custom_field_values.record_id now holds a purchase batch id
-- rather than a product id.
--
-- Existing answers are COPIED onto every batch of their product, so nothing is
-- lost and every batch that already exists reads the way it did before. Staff
-- then edit them per batch from that point on.
--
-- Idempotent: the insert skips any (batch, field) that already has an answer, so
-- a re-run neither duplicates rows nor overwrites an answer someone has since
-- edited on a batch. The original product-keyed rows are left in place rather
-- than deleted — they are no longer read, and keeping them means this migration
-- can be re-run and the old answers inspected if a shop questions a value.

INSERT INTO mystoreguard.msg_custom_field_values
    (id, tenant_id, org_id, bus_id, field_id, module, record_id, value,
     cdate, ctime, cdatetime, created_by)
SELECT
    -- Matches the ids the application generates: 'cfv_' and 59 hex characters.
    -- Built from gen_random_uuid rather than pgcrypto's gen_random_bytes, which
    -- is not installed on these databases.
    'cfv_' || substr(md5(gen_random_uuid()::text) || md5(gen_random_uuid()::text), 1, 59),
    v.tenant_id, v.org_id, v.bus_id,
    v.field_id,
    'products',
    b.id,
    v.value,
    CURRENT_DATE, CURRENT_TIME, CURRENT_TIMESTAMP,
    v.created_by
FROM mystoreguard.msg_custom_field_values v
JOIN mystoreguard.msg_purchase_batches b
       ON b.product_id = v.record_id
      AND b.tenant_id  = v.tenant_id
      AND b.org_id     = v.org_id
      AND b.bus_id     = v.bus_id
      AND b.delete_status = 'NOT_DELETED'
WHERE v.module = 'products'
  -- Only rows still keyed to a product. Once copied, the new rows are keyed to a
  -- batch and this join no longer matches them, so a re-run finds nothing new.
  AND EXISTS (
        SELECT 1 FROM mystoreguard.msg_products p
         WHERE p.id = v.record_id AND p.tenant_id = v.tenant_id
      )
  AND NOT EXISTS (
        SELECT 1 FROM mystoreguard.msg_custom_field_values existing
         WHERE existing.tenant_id = v.tenant_id
           AND existing.org_id    = v.org_id
           AND existing.bus_id    = v.bus_id
           AND existing.module    = 'products'
           AND existing.record_id = b.id
           AND existing.field_id  = v.field_id
  );
