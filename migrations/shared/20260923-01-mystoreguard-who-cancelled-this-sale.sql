-- Who cancelled a sale, when, and why.
--
-- Cancelling set status to CANCELLED and stamped updated_by, which is not the
-- same thing: any later edit overwrites it, so the record of who undid a sale
-- degrades into the record of who touched it last. The audit log holds the
-- truth, but a screen showing a cancelled sale's payments should not have to
-- go and read an audit trail to say the sale was cancelled at all.
--
-- Named like the return columns beside them (approved_by/approved_at,
-- rejected_by/rejected_at) so the same fact is recorded the same way whichever
-- document it happens on.

ALTER TABLE mystoreguard.msg_sales
    ADD COLUMN IF NOT EXISTS cancelled_at timestamptz,
    ADD COLUMN IF NOT EXISTS cancelled_by text,
    ADD COLUMN IF NOT EXISTS cancellation_reason text;

-- Not a foreign key to cp_users, matching how the rest of this table records
-- people: a sale must outlive a staff account being removed, and losing the
-- name is a smaller loss than a delete that is blocked by, or cascades into,
-- somebody's sales history.
CREATE INDEX IF NOT EXISTS ix_msg_sales_cancelled
    ON mystoreguard.msg_sales (tenant_id, cancelled_at)
    WHERE cancelled_at IS NOT NULL;
