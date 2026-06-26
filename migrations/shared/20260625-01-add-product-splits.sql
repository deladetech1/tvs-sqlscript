-- 20260625-01-add-product-splits.sql
-- Product Split (break-bulk) tables for MyStoreGuard: a split header and its line items.
-- Used by the tvs-mystoreguard-bk app via raw SQL (not EF-managed), so they live here as
-- idempotent shared SQL. Safe to re-run on every deploy.

-- ---------------------------------------------------------------------
-- Header: one row per split operation (the parent you "open")
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mystoreguard.msg_product_splits (
    id                  text        PRIMARY KEY,
    split_number        text,
    tenant_id           text        NOT NULL,
    org_id              text        NOT NULL,
    bus_id              text        NOT NULL,

    description         text,
    source_scope        text        NOT NULL DEFAULT 'PRODUCT',  -- PRODUCT | STORE | WAREHOUSE
    location_type       text,                                    -- STORE | WAREHOUSE
    loc_id              text,

    status              text        NOT NULL DEFAULT 'ACTIVE',   -- ACTIVE | PARTIALLY_REVERSED | REVERSED
    delete_status       text        NOT NULL DEFAULT 'NOT_DELETED',

    cdate               text,
    ctime               text,
    cdatetime           timestamptz,
    created_by          text,
    updated_by          text,
    reversed_by         text,
    reversed_at         timestamptz
);

CREATE INDEX IF NOT EXISTS idx_msg_product_splits_scope
    ON mystoreguard.msg_product_splits (tenant_id, org_id, bus_id);
CREATE INDEX IF NOT EXISTS idx_msg_product_splits_loc
    ON mystoreguard.msg_product_splits (tenant_id, org_id, bus_id, loc_id);
CREATE INDEX IF NOT EXISTS idx_msg_product_splits_status
    ON mystoreguard.msg_product_splits (tenant_id, org_id, bus_id, status);

-- ---------------------------------------------------------------------
-- Items: one row per product line within a split (independently reversible)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mystoreguard.msg_product_split_items (
    id                  text        PRIMARY KEY,
    split_id            text        NOT NULL,
    tenant_id           text        NOT NULL,
    org_id              text        NOT NULL,
    bus_id              text        NOT NULL,

    source_product_id   text        NOT NULL,
    source_qty_taken    integer     NOT NULL,
    divisor             integer     NOT NULL,

    derived_product_id  text        NOT NULL,
    derived_batch_id    text        NOT NULL,
    derived_qty         integer     NOT NULL,

    unit_cost_price     numeric(18,2),
    unit_selling_price  numeric(18,2),
    price_mode          text        NOT NULL DEFAULT 'AUTO',     -- AUTO | MANUAL
    currency_id         text,

    source_batches      jsonb       NOT NULL DEFAULT '[]'::jsonb,

    status              text        NOT NULL DEFAULT 'ACTIVE',   -- ACTIVE | REVERSED
    delete_status       text        NOT NULL DEFAULT 'NOT_DELETED',

    cdate               text,
    ctime               text,
    cdatetime           timestamptz,
    created_by          text,
    updated_by          text,
    reversed_by         text,
    reversed_at         timestamptz
);

CREATE INDEX IF NOT EXISTS idx_msg_product_split_items_split
    ON mystoreguard.msg_product_split_items (split_id);
CREATE INDEX IF NOT EXISTS idx_msg_product_split_items_scope
    ON mystoreguard.msg_product_split_items (tenant_id, org_id, bus_id, status);
CREATE INDEX IF NOT EXISTS idx_msg_product_split_items_source
    ON mystoreguard.msg_product_split_items (tenant_id, org_id, bus_id, source_product_id);
CREATE INDEX IF NOT EXISTS idx_msg_product_split_items_derived_batch
    ON mystoreguard.msg_product_split_items (derived_batch_id);
