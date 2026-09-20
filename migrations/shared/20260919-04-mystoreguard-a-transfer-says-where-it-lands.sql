-- A transfer line says which delivery it moves, and where it lands.
--
-- A transfer already carried `place_id`, but that is the bin the goods are
-- taken OFF at the branch sending them. Nothing said where they go at the
-- other end, so stock arrived on the shelf and in no bin — and the branch
-- receiving it, who is the only one who knows where it went, had no way to
-- say so at the moment they knew.
--
-- Naming them apart rather than reusing one column, because they are two
-- different branches' answers to two different questions, and a transfer
-- between two shops that both use bins needs both.
--
-- `batch_id` (added in 20260919-01) is the other half: which delivery the
-- quantity comes out of. Without it a transfer takes oldest-first, which is
-- right by default and wrong whenever somebody is deliberately moving the
-- newer stock, or the stock that came from a particular supplier.
--
-- Moves nothing on its own.

ALTER TABLE mystoreguard.msg_product_transfer_items
    -- Which bin the goods go into at the destination. Null means nobody said,
    -- which is the ordinary answer for a shop that does not use bins and a
    -- perfectly good one for a shop that will put them away later.
    ADD COLUMN IF NOT EXISTS destination_place_id text;

-- Reading a bin's incoming transfers. Partial, because the column is null on
-- most rows and an index over those would be mostly empty.
CREATE INDEX IF NOT EXISTS ix_msg_product_transfer_items_destination_place
    ON mystoreguard.msg_product_transfer_items
       (tenant_id, org_id, bus_id, destination_place_id)
    WHERE destination_place_id IS NOT NULL;
