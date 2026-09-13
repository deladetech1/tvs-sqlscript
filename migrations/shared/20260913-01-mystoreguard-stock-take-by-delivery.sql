-- Counting stock the way it is actually held: delivery by delivery, and item by
-- item where the items have names.
--
-- A stock take line was one product and one number, checked against the
-- product's total on the shelf. Stock is not held that way. One product sits in
-- several deliveries, each bought at its own cost and sold at its own price, and
-- some of those deliveries name every item in them.
--
-- Two consequences, both seen on live data:
--
--   * A shop holding 10, 12 and 4 across three deliveries when the system says
--     7, 7 and 4 counts 26 against 26 and reads as a PERFECT MATCH. Two
--     deliveries are wrong, they are priced 90,897 and 7,890 apart, and nothing
--     on the line can tell them apart afterwards.
--
--   * Tracked stock could be counted and then never corrected. The resolution
--     refuses with "there is nowhere on this form to say which item" — which is
--     true, and is what this fixes rather than works around. The guard stays for
--     any path that still cannot name its items.
--
-- batch_id is NULLABLE on purpose. A line with no delivery is a whole-product
-- count: every stock take taken before today, and the quick count that a
-- product with one plain delivery still deserves. Nothing already recorded
-- changes meaning.

ALTER TABLE mystoreguard.msg_stock_take_items
    ADD COLUMN IF NOT EXISTS batch_id text;

COMMENT ON COLUMN mystoreguard.msg_stock_take_items.batch_id IS
    'The delivery this line counted. NULL means the line counted the product as '
    'a whole, which is every line taken before deliveries were counted '
    'separately, and the quick count for a product held in one plain delivery.';

-- A product may now appear once per delivery rather than once per take.
--
-- COALESCE, because NULLs are distinct from each other in a unique index: two
-- whole-product lines for the same product would both have been allowed, which
-- is the very thing the old index existed to stop.
DROP INDEX IF EXISTS mystoreguard.ix_msg_stock_take_items_tenant_id_org_id_bus_id_stock_take_id_;

CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_stock_take_items_line
    ON mystoreguard.msg_stock_take_items
    (tenant_id, org_id, bus_id, stock_take_id, product_id, COALESCE(batch_id, ''));


-- Which named items were actually on the shelf ------------------------------
--
-- A tracked delivery is not counted by typing a number; it is counted by going
-- through the items it should hold and marking off the ones in front of you.
-- What is left unmarked is not "a shortage of one" — it is that handset, by its
-- serial, and resolving the line writes off THAT one.
--
-- The row exists for every item the delivery should have held, present or not,
-- so the count is a record of what was checked rather than only of what was
-- missing. `found` false with nothing else said is a genuine "not there".

CREATE TABLE IF NOT EXISTS mystoreguard.msg_stock_take_item_units (
    id                 text PRIMARY KEY,
    tenant_id          text NOT NULL,
    org_id             text NOT NULL,
    bus_id             text NOT NULL,
    stock_take_id      text NOT NULL,
    stock_take_item_id text NOT NULL,
    -- The item itself. Kept as a plain reference rather than a foreign key so
    -- that writing one off later, which changes its status, never rewrites the
    -- history of a count that found it.
    unit_id            text NOT NULL,
    -- What it is called on the shelf — the serial, the IMEI — snapshotted so a
    -- finished count still reads correctly after the item is disposed of.
    unit_label         text,
    found              boolean NOT NULL DEFAULT false,
    note               text,
    cdate              text,
    ctime              text,
    cdatetime          timestamptz NOT NULL DEFAULT NOW(),
    created_by         text
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_stock_take_item_units
    ON mystoreguard.msg_stock_take_item_units (stock_take_item_id, unit_id);

CREATE INDEX IF NOT EXISTS ix_msg_stock_take_item_units_take
    ON mystoreguard.msg_stock_take_item_units
    (tenant_id, org_id, bus_id, stock_take_id);

COMMENT ON TABLE mystoreguard.msg_stock_take_item_units IS
    'One row per named item a tracked delivery should have held, saying whether '
    'the count found it. A shortage here is a specific item, not a quantity.';
