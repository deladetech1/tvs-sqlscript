-- A transfer line remembers which bin it is being taken off.
--
-- Stock leaving a branch has to come off a bin as well as the shelf, or the
-- bin goes on claiming goods that are now standing in another branch. The
-- person who knows which bin is the one packing the transfer — and that is
-- when the transfer is CREATED, not when it is approved and executed hours or
-- days later by somebody else. So the answer has to be kept on the line.
--
-- Null is a real answer and the common one: no bins in use, or a delivery
-- sitting in exactly one bin, which needs no asking.
--
-- Moves no stock, and is not read by anything that counts.

ALTER TABLE mystoreguard.msg_product_transfer_items
    ADD COLUMN IF NOT EXISTS place_id text;

-- No foreign key on purpose. A place can be dismantled after a transfer has
-- gone out, and "it came off the rack we no longer have" is still the true
-- answer to what happened — worth more than a tidy constraint that would
-- either block the tidy-up or erase the history.
COMMENT ON COLUMN mystoreguard.msg_product_transfer_items.place_id IS
    'Bin the sending branch takes these off. Null = no bin, or nothing to ask.';
