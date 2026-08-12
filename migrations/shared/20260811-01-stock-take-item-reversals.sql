-- =====================================================================
-- Stock-take correction reversals
-- ---------------------------------------------------------------------
-- Resolving a variance may apply a REAL stock change: a shortage is
-- written off (stock deducted FIFO from the location's delivery
-- breakdown) or a surplus is added as a new purchase batch. Both stamp
-- msg_stock_take_items.adjustment_qty (signed) and adjustment_movement_id.
--
-- These columns let such a correction be UNDONE. On reversal the stock
-- movement is played back in the opposite direction, the line's
-- adjustment is cleared and it returns to PENDING so it can be resolved
-- again, and the reversal itself is recorded here (who / when / why).
-- reversal_count survives repeated resolve -> reverse cycles.
--
-- Runs after the EF migrations on every deploy. Idempotent; safe to re-run.
-- =====================================================================

ALTER TABLE mystoreguard.msg_stock_take_items
    ADD COLUMN IF NOT EXISTS reversed_qty         integer,
    ADD COLUMN IF NOT EXISTS reversal_note        text,
    ADD COLUMN IF NOT EXISTS reversed_by          text,
    ADD COLUMN IF NOT EXISTS reversed_datetime    timestamptz,
    ADD COLUMN IF NOT EXISTS reversal_movement_id text,
    ADD COLUMN IF NOT EXISTS reversal_count       integer NOT NULL DEFAULT 0;

-- Reversals replay the original movements in reverse, tagged with their own
-- reasons (STOCK_TAKE_ADJUSTMENT_REVERSAL / STOCK_TAKE_SURPLUS_REVERSAL) and
-- the stock take id as reference_id. The write-off reversal nets OUT against
-- already-reversed IN per batch to find what is still owed back, so this
-- lookup runs on every reversal.
CREATE INDEX IF NOT EXISTS idx_msg_product_movements_reference_product
    ON mystoreguard.msg_product_movements (tenant_id, org_id, bus_id, reference_id, product_id);
