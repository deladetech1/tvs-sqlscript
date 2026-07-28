-- 20260712-05-purchase-returns.sql
-- Purchase returns: sending received stock back to the supplier.
-- Reverses undistributed batch stock (an OUT product movement) and reduces the
-- amount owed on the purchase order by the returned value. Immediate (no
-- approval). Mirrors the purchase order / payments tables.
-- Idempotent; safe to re-run on every deploy.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_purchase_returns (
    id                  text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text        NOT NULL,
    org_id              text        NOT NULL,
    bus_id              text        NOT NULL,
    loc_id              text,

    purchase_order_id   text        NOT NULL,
    supplier_id         text,
    return_number       text,
    reason              text        NOT NULL DEFAULT 'OTHER',   -- DAMAGED | WRONG_ITEM | EXPIRED | OVER_SUPPLIED | OTHER
    status              text        NOT NULL DEFAULT 'COMPLETED',-- COMPLETED | CANCELLED
    notes               text,
    total_return_value  numeric(18,2) NOT NULL DEFAULT 0,

    cdate               text,
    ctime               text,
    cdatetime           timestamptz DEFAULT NOW(),
    created_by          text,
    updated_by          text,
    deleted_by          text,
    deleted_at          timestamptz
);

CREATE INDEX IF NOT EXISTS idx_msg_purchase_returns_po
    ON mystoreguard.msg_purchase_returns (purchase_order_id, tenant_id, org_id, bus_id, deleted_at);

CREATE TABLE IF NOT EXISTS mystoreguard.msg_purchase_return_items (
    id                       text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id                text        NOT NULL,
    org_id                   text        NOT NULL,
    bus_id                   text        NOT NULL,

    purchase_return_id       text        NOT NULL,
    purchase_order_item_id   text,
    product_id               text        NOT NULL,
    batch_id                 text,                              -- purchase batch the stock is returned from

    qty_returned             integer     NOT NULL CHECK (qty_returned > 0),
    cost_price               numeric(18,2) NOT NULL DEFAULT 0,
    line_total               numeric(18,2) NOT NULL DEFAULT 0,  -- cost_price * qty_returned
    condition                text,                              -- optional: item condition note

    cdatetime                timestamptz DEFAULT NOW(),
    created_by               text
);

CREATE INDEX IF NOT EXISTS idx_msg_purchase_return_items_return
    ON mystoreguard.msg_purchase_return_items (purchase_return_id, tenant_id, org_id, bus_id);
