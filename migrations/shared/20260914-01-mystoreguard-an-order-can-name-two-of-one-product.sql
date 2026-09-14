-- A purchase order can carry the same product twice, if it says which is which.
--
-- A shop orders a hundred curtains in ten colours: sixty red, forty blue, and
-- so on. That is one product, several lines, each with its own quantity —
-- which the database forbade outright:
--
--     UNIQUE (tenant_id, org_id, bus_id, purchase_order_id, product_id)
--
-- The rule was not wrong, it was too blunt. It exists to stop an ACCIDENTAL
-- duplicate: clicking a product twice and ordering it twice by mistake. A
-- deliberate duplicate — the same curtain in two colours — is a different
-- thing, and the index could not tell them apart because nothing on the line
-- said which colour it was.
--
-- So the line gets somewhere to say so, and the ban becomes a question the
-- application can actually answer: two lines of one product are fine when
-- something distinguishes them, and a slip when nothing does. That check lives
-- in the service, where it can name the product and say what is missing,
-- rather than surfacing as a constraint violation.

ALTER TABLE mystoreguard.msg_purchase_order_items
    ADD COLUMN IF NOT EXISTS description text;

COMMENT ON COLUMN mystoreguard.msg_purchase_order_items.description IS
    'What tells this line apart from another of the same product on the same '
    'order — "Red", "Blackout", "UK used". Free text on purpose: a shop knows '
    'what distinguishes its stock and it is not always a colour. Carried onto '
    'the receiving screen so whoever takes the goods in knows which line they '
    'are looking at.';

-- The unique index goes; a plain one takes its place so the lookups it was
-- also serving stay fast.
DROP INDEX IF EXISTS mystoreguard.ix_msg_purchase_order_items_tenant_id_org_id_bus_id_purchase_o;

CREATE INDEX IF NOT EXISTS ix_msg_purchase_order_items_order_product
    ON mystoreguard.msg_purchase_order_items
       (tenant_id, org_id, bus_id, purchase_order_id, product_id);
