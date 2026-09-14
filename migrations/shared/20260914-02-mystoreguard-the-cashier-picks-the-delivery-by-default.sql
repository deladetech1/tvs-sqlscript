-- A sale asks which delivery it is coming out of, unless the shop says otherwise.
--
-- Stock deduction defaulted to FIFO — oldest first — because that is what every
-- shop had before the setting existed. It is the wrong default for this
-- business. Deliveries here are NOT interchangeable: the same phone arrives in
-- three storage sizes at three prices, curtains arrive in ten colours, and
-- oldest-first hands the customer whichever came in first rather than the one
-- they pointed at.
--
-- Both shops on production had already set BATCH_SELECTION by hand, which is
-- the clearest evidence available that the default was wrong: the first thing
-- a real shop did was turn it off.
--
-- Only affects a location with NO setting of its own, and locations created
-- from here on. Anything already chosen — including a shop that deliberately
-- wants FIFO — is left exactly as it is.

ALTER TABLE mystoreguard.msg_store_configs
    ALTER COLUMN stock_deduction_method SET DEFAULT 'BATCH_SELECTION';

COMMENT ON COLUMN mystoreguard.msg_store_configs.stock_deduction_method IS
    'Which delivery a sale draws its stock from. BATCH_SELECTION, the default, '
    'hands the choice to the person selling — right wherever two deliveries of '
    'one product are not the same thing. FIFO takes the oldest first, LIFO the '
    'newest, FEFO the nearest expiry so short-dated stock moves before it is '
    'thrown away.';
