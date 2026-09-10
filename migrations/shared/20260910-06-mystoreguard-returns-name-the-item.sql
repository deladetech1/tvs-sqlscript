-- Which handset actually came back.
--
-- A return line said "one of these came back" and the shop put back whichever
-- of that line's items went out first. For a line of one that is right by
-- accident; for a customer returning one of three phones it is wrong two times
-- in three — IMEI-B comes over the counter and IMEI-A goes on the shelf, so the
-- shop's record of who owns which handset is quietly false from then on. The
-- warranty claim that arrives a year later is then answered about the wrong
-- phone.
--
-- A text[] rather than a child table: the ids are read and written as a set,
-- always with their line, and never joined to on their own. A table here would
-- be a join for nothing.
--
-- Nullable, and it stays that way. A shop returning counted stock has nothing
-- to put here, and a shop that does not scan on the way back gets the old
-- oldest-first behaviour rather than a refusal.

ALTER TABLE mystoreguard.msg_return_items
    ADD COLUMN IF NOT EXISTS unit_ids text[];

COMMENT ON COLUMN mystoreguard.msg_return_items.unit_ids IS
    'The physical items returned on this line, for stock recorded one at a '
    'time. Null where nobody said which — the shop then puts back whichever '
    'went out first, which is a guess.';
