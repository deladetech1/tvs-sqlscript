-- A barcode and a note belong to the delivery, like everything else about it.
--
-- The barcode sat on the product, which says "every one of these scans the
-- same". For a shop buying the same model repeatedly that is often false: the
-- 256GB box and the 1TB box carry different EANs, and a refurbished batch
-- arrives with the refurbisher's own label over the original. Scanning the box
-- in your hand then found the product but not the delivery it came from, so the
-- till still had to be told which one — which is the entire question scanning
-- was supposed to answer.
--
-- The description is the same idea in words: "ex-display, small scratch on the
-- back" is true of one delivery, not of the model. The product keeps its own
-- description for what the model IS.
--
-- The product's bar_code column stays. Products that have one keep it, scanning
-- still matches it, and a shop that never cared about per-delivery barcodes
-- notices nothing.

ALTER TABLE mystoreguard.msg_purchase_batches
    ADD COLUMN IF NOT EXISTS bar_code text,
    ADD COLUMN IF NOT EXISTS description text;

COMMENT ON COLUMN mystoreguard.msg_purchase_batches.bar_code IS
    'The barcode on THIS delivery''s boxes. Two deliveries of one product can '
    'scan differently — different storage sizes, a refurbisher''s own label — '
    'and the product''s own barcode is the fallback when a delivery has none.';

COMMENT ON COLUMN mystoreguard.msg_purchase_batches.description IS
    'What is true of this delivery: "ex-display, scratch on the back". The '
    'product''s description says what the model is.';

-- Scanning has to find a delivery by its own code, and that lookup happens on
-- every scan at the counter. Deliberately not unique: two deliveries of the
-- same 256GB phone genuinely carry the same EAN, and refusing the second would
-- be refusing the truth.
CREATE INDEX IF NOT EXISTS ix_msg_purchase_batches_bar_code
    ON mystoreguard.msg_purchase_batches (tenant_id, org_id, bus_id, bar_code)
    WHERE bar_code IS NOT NULL AND delete_status = 'NOT_DELETED';
