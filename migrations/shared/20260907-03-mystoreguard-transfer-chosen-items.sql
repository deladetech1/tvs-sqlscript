-- Which individual items a transfer is sending.
--
-- A transfer is raised now and approved later, and the stock only moves on
-- approval — so a branch that says "send THESE two handsets" needs that choice
-- to survive in between. Without somewhere to keep it the approval fell back to
-- first-in-first-out and moved whichever two were oldest, which is not what was
-- agreed and, for serialised goods, not the same handsets at all.
--
-- Null means no choice was made, which is the ordinary case and keeps the
-- first-in-first-out behaviour every existing transfer already has.

ALTER TABLE mystoreguard.msg_product_transfer_items
    ADD COLUMN IF NOT EXISTS unit_ids TEXT[];

COMMENT ON COLUMN mystoreguard.msg_product_transfer_items.unit_ids IS
    'The individual items this line is sending, for stock recorded one at a '
    'time. Null means none were named and the oldest in stock are taken.';
