-- Stock spread across more than one bin.
--
-- A delivery records ONE place today. A hundred pairs of curtains do not fit
-- in one bin, so the honest answer is "40 on RA-B1 and 60 on RA-B10" and the
-- system could only say "RA-B1" — half wrong, which is worse than silent,
-- because somebody trusts it and walks to the wrong rack.
--
-- Two tables. Both are DETAIL ABOUT stock and never a SOURCE OF stock:
-- msg_batch_locations keeps every quantity the system believes, exactly as it
-- does today, and the fifty-one statements that write it are untouched. If
-- every row below were deleted tomorrow, every stock figure on every screen
-- would be unchanged.

-- ---------------------------------------------------------------------------
-- Where a delivery sits, bin by bin
-- ---------------------------------------------------------------------------
--
-- qty is NULLABLE, and that is the whole of part one.
--
--   qty IS NULL   "these curtains are on RA-B1 and RA-B10" — which bins hold
--                 them, without anybody having counted each bin. Costs one tap
--                 per bin, can never be wrong, and answers the question a
--                 person actually has, which is where to walk.
--
--   qty IS SET    "40 on RA-B1, 60 on RA-B10" — somebody counted. More useful
--                 and more to keep up; a shop that counts its bins already
--                 does this work and has nowhere to put it.
--
-- One row per bin per shelf row, so a delivery split across a branch's shop
-- floor and its stockroom keeps the two sides separate, as everything else
-- here does.
CREATE TABLE IF NOT EXISTS mystoreguard.msg_batch_place_stock (
    id                 text NOT NULL,
    tenant_id          text NOT NULL,
    org_id             text NOT NULL,
    bus_id             text NOT NULL,

    -- The shelf row this is a breakdown OF. Everything about which product,
    -- which delivery, which branch and which side is already answered there,
    -- and is deliberately not repeated: two copies of one fact is how they
    -- come to disagree.
    batch_location_id  text NOT NULL,
    place_id           text NOT NULL,

    -- How many of them are in this bin. Null means nobody has said.
    qty                integer,

    -- When the quantity was last counted, and by whom. Null while qty is null.
    -- A bin number is only ever as good as its date, so the date travels with
    -- it rather than being inferred from whenever the row was touched.
    counted_at         timestamptz,
    counted_by         text,

    cdatetime          timestamptz NOT NULL DEFAULT NOW(),
    created_by         text,
    updated_by         text,

    CONSTRAINT pk_msg_batch_place_stock PRIMARY KEY (tenant_id, org_id, bus_id, id),
    -- A bin holds a given delivery once. Two rows for the same pair would be
    -- two answers to one question.
    CONSTRAINT ux_msg_batch_place_stock_row
        UNIQUE (tenant_id, org_id, bus_id, batch_location_id, place_id),
    -- Negative stock in a bin is not a thing.
    CONSTRAINT ck_msg_batch_place_stock_qty
        CHECK (qty IS NULL OR qty >= 0),
    -- A counted quantity has a date; an uncounted one does not carry a stale
    -- date from some earlier count.
    CONSTRAINT ck_msg_batch_place_stock_counted
        CHECK ((qty IS NULL AND counted_at IS NULL)
            OR (qty IS NOT NULL AND counted_at IS NOT NULL)),

    CONSTRAINT fk_msg_batch_place_stock_tenant
        FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants(id) ON DELETE CASCADE,
    -- CASCADE, and it matters: twelve statements delete shelf rows — transfers
    -- moving stock off a side, a store product being removed, a delivery
    -- reversed. A breakdown of a shelf row that no longer exists is a claim
    -- about stock that is not there.
    CONSTRAINT fk_msg_batch_place_stock_shelf_row
        FOREIGN KEY (tenant_id, org_id, bus_id, batch_location_id)
        REFERENCES mystoreguard.msg_batch_locations(tenant_id, org_id, bus_id, id)
        ON DELETE CASCADE,
    -- SET NULL is not available here because the place is half the key, so a
    -- place cannot be dismantled while stock still names it. The service
    -- clears these rows first, which is also what lets it say how much stock
    -- is about to lose its address.
    CONSTRAINT fk_msg_batch_place_stock_place
        FOREIGN KEY (tenant_id, org_id, bus_id, place_id)
        REFERENCES mystoreguard.msg_storage_places(tenant_id, org_id, bus_id, id)
        ON DELETE CASCADE,
    CONSTRAINT fk_msg_batch_place_stock_counted_by
        FOREIGN KEY (counted_by, tenant_id)
        REFERENCES core_platform.cp_users(id, tenant_id) ON DELETE SET NULL
);

-- "What is on this rack" walks this way.
CREATE INDEX IF NOT EXISTS ix_msg_batch_place_stock_place
    ON mystoreguard.msg_batch_place_stock (tenant_id, org_id, bus_id, place_id);

-- "Where is this delivery" walks the other way.
CREATE INDEX IF NOT EXISTS ix_msg_batch_place_stock_shelf_row
    ON mystoreguard.msg_batch_place_stock (tenant_id, org_id, bus_id, batch_location_id);

-- Finding counts that have gone stale, without reading every row ever written.
CREATE INDEX IF NOT EXISTS ix_msg_batch_place_stock_counted_at
    ON mystoreguard.msg_batch_place_stock (tenant_id, org_id, bus_id, counted_at)
    WHERE qty IS NOT NULL;


-- ---------------------------------------------------------------------------
-- What happened to the bins
-- ---------------------------------------------------------------------------
--
-- Somebody tidies a rack and moves twenty pairs from RA-B1 to RA-B10. No sale
-- happens, so nothing prompts anybody, and both bins are silently wrong from
-- that moment until the next count. Of everything that can rot a breakdown,
-- that one has no other way of being caught, because rearranging stock is
-- routine and leaves no other trace.
--
-- So: a place movement is a thing that can be recorded on its own, and every
-- change to a bin leaves one behind. "Why does RA-B1 say forty when I put
-- sixty there" becomes answerable, which is the question the bin numbers will
-- otherwise generate every week.
--
-- Movements record what was SAID, not what stock did. Nothing in here moves a
-- quantity anywhere; the shelf total is untouched by every row in this table.
CREATE TABLE IF NOT EXISTS mystoreguard.msg_place_movements (
    id                 text NOT NULL,
    tenant_id          text NOT NULL,
    org_id             text NOT NULL,
    bus_id             text NOT NULL,

    batch_location_id  text NOT NULL,

    -- Null on one side is meaningful and common: PLACED comes from nowhere,
    -- CLEARED goes nowhere.
    from_place_id      text,
    to_place_id        text,

    -- PLACED    stock given a bin for the first time
    -- MOVED     carried from one bin to another
    -- COUNTED   a bin counted, and what it came to
    -- CLEARED   stock no longer recorded in that bin
    movement_type      text NOT NULL,

    -- How many. Null where the shop works without bin quantities at all, which
    -- is the whole of part one — "these went on RA-B10" with no number is a
    -- complete and honest record of what happened.
    qty                integer,

    note               text,

    cdatetime          timestamptz NOT NULL DEFAULT NOW(),
    created_by         text,

    CONSTRAINT pk_msg_place_movements PRIMARY KEY (tenant_id, org_id, bus_id, id),
    CONSTRAINT ck_msg_place_movements_type
        CHECK (movement_type = ANY (ARRAY['PLACED','MOVED','COUNTED','CLEARED'])),
    CONSTRAINT ck_msg_place_movements_qty
        CHECK (qty IS NULL OR qty >= 0),
    -- A movement that names neither end describes nothing.
    CONSTRAINT ck_msg_place_movements_has_an_end
        CHECK (from_place_id IS NOT NULL OR to_place_id IS NOT NULL),

    CONSTRAINT fk_msg_place_movements_tenant
        FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants(id) ON DELETE CASCADE,
    CONSTRAINT fk_msg_place_movements_shelf_row
        FOREIGN KEY (tenant_id, org_id, bus_id, batch_location_id)
        REFERENCES mystoreguard.msg_batch_locations(tenant_id, org_id, bus_id, id)
        ON DELETE CASCADE,
    -- History survives the dismantling of a rack. "It used to be on RA-B1" is
    -- precisely the sentence somebody needs when RA-B1 no longer exists, so
    -- these deliberately do NOT cascade — the place id is kept even once the
    -- place is gone, and the reader is told the name is no longer known.
    CONSTRAINT fk_msg_place_movements_created_by
        FOREIGN KEY (created_by, tenant_id)
        REFERENCES core_platform.cp_users(id, tenant_id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS ix_msg_place_movements_shelf_row
    ON mystoreguard.msg_place_movements (tenant_id, org_id, bus_id,
                                         batch_location_id, cdatetime DESC);

CREATE INDEX IF NOT EXISTS ix_msg_place_movements_place
    ON mystoreguard.msg_place_movements (tenant_id, org_id, bus_id,
                                         to_place_id, cdatetime DESC);


COMMENT ON TABLE mystoreguard.msg_batch_place_stock IS
    'Which bins hold a delivery, and how many in each where anybody has '
    'counted. Detail about stock, never a source of it: msg_batch_locations '
    'holds every quantity the system believes, and nothing that counts stock '
    'reads this table.';

COMMENT ON TABLE mystoreguard.msg_place_movements IS
    'What was said about where stock is kept — placed, moved between bins, '
    'counted, cleared. Records statements, not stock: no row here moves a '
    'quantity anywhere.';
