-- How a sale decides which delivery its stock comes out of.
--
-- Until now this was always oldest-first, decided in code and not settable. It
-- is the right default and most shops never think about it, but it is wrong for
-- a shop whose deliveries are not interchangeable: one selling the same phone in
-- three storage sizes has three batches at three prices, and "oldest first"
-- hands the customer whichever arrived first rather than the one they asked for.
--
--   FIFO             oldest delivery first. The default, and what every existing
--                    shop has been doing.
--   LIFO             newest first, for stock where the recent cost is the one
--                    that should be recovered.
--   FEFO             nearest expiry first, so short-dated stock moves before it
--                    is thrown away. Batches with no expiry come last.
--   BATCH_SELECTION  the person selling chooses, from the deliveries that
--                    actually have stock at their branch.
--
-- Defaulted rather than nullable: every sale has to draw from somewhere, and a
-- null here would mean each read had to remember the fallback.

ALTER TABLE mystoreguard.msg_store_configs
    ADD COLUMN IF NOT EXISTS stock_deduction_method TEXT NOT NULL DEFAULT 'FIFO';

DO $$
BEGIN
    -- Named so a re-run finds it. IF NOT EXISTS is not available for
    -- constraints, and adding it twice is an error rather than a no-op.
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'msg_store_configs_stock_deduction_method_check'
    ) THEN
        ALTER TABLE mystoreguard.msg_store_configs
            ADD CONSTRAINT msg_store_configs_stock_deduction_method_check
            CHECK (stock_deduction_method IN
                   ('FIFO', 'LIFO', 'FEFO', 'BATCH_SELECTION'));
    END IF;
END $$;

COMMENT ON COLUMN mystoreguard.msg_store_configs.stock_deduction_method IS
    'Which delivery a sale draws from: FIFO (oldest first, the default), LIFO '
    '(newest first), FEFO (nearest expiry first) or BATCH_SELECTION (the person '
    'selling chooses).';
