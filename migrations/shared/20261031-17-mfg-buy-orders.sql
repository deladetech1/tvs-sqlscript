-- Manufacturing: buy orders (contract R3.md D21; owner 2026-10-29: planned buys become Manufacturing
-- buy orders, with or without SCM; D26: no SCM connection).
--
--   mfg_buy_orders        BO-00007 (mfg_number_series kind buy_order) to one supplier (a Core party,
--                         supplier_party_id) for one plant, into one warehouse of the shared ledger.
--                         draft -> placed -> partially_received -> received -> closed; cancelled
--                         before any receipt. Not a procurement module: no RFQ, approval chain or
--                         invoice match
--   mfg_buy_order_lines   product, quantity, unit price, expected date, quantity received so far,
--                         and the planned order it came from (planned_order_id). Open lines are MRP
--                         supply at expected_on (pegging supply type mfg_buy_order_line). Receipts are
--                         ledger movements (stock.Post kind receipt, RefType mfg_buy_order), so this
--                         file keeps no receipt table
--
-- Over-receipt beyond 10 % is refused by the API (409 QUANTITY_EXCEEDED) and, as a backstop, by
-- the line's rule. Product and party ids are Core's, registered for merges in 20261031-21; the
-- warehouse is the shared ledger's (no foreign key, as R1/R2). The CHECK list (status) lives in
-- 20261031-20. No grants. Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS mfg.mfg_buy_orders (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    org_id              text,
    bus_id              text NOT NULL,
    plant_id            text NOT NULL REFERENCES mfg.mfg_plants (id),
    number              text NOT NULL,            -- BO-00007
    supplier_party_id   text NOT NULL,            -- cp_parties.id
    warehouse_id        text,                     -- where it is received (the shared ledger's)
    status              text NOT NULL DEFAULT 'draft',
    expected_on         date,
    currency            text,
    total               numeric(14,2) NOT NULL DEFAULT 0,   -- sum of the lines' qty x unit price
    notes               text,
    placed_at           timestamptz,
    placed_by           text,
    received_at         timestamptz,              -- the last receipt
    closed_at           timestamptz,
    closed_by           text,
    close_reason        text,                     -- a short-close
    cancelled_at        timestamptz,
    cancelled_by        text,
    cancelled_reason    text,
    idempotency_key     text,
    custom              jsonb NOT NULL DEFAULT '{}',
    version             integer NOT NULL DEFAULT 1,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    created_by          text,
    updated_at          timestamptz NOT NULL DEFAULT now(),
    updated_by          text
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_buy_orders_number_uq ON mfg.mfg_buy_orders (bus_id, number);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_buy_orders_idempotency_uq
    ON mfg.mfg_buy_orders (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS mfg_buy_orders_list_idx ON mfg.mfg_buy_orders (bus_id, plant_id, status, expected_on);
CREATE INDEX IF NOT EXISTS mfg_buy_orders_supplier_idx ON mfg.mfg_buy_orders (bus_id, supplier_party_id, cdatetime DESC);
ALTER TABLE mfg.mfg_buy_orders DROP CONSTRAINT IF EXISTS mfg_buy_orders_rules_check;
ALTER TABLE mfg.mfg_buy_orders ADD CONSTRAINT mfg_buy_orders_rules_check
    CHECK (total >= 0
           AND (status IN ('draft', 'cancelled') OR placed_at IS NOT NULL)
           AND (status <> 'closed' OR closed_at IS NOT NULL)
           AND (status <> 'cancelled' OR cancelled_at IS NOT NULL));

CREATE TABLE IF NOT EXISTS mfg.mfg_buy_order_lines (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    org_id              text,
    bus_id              text NOT NULL,
    order_id            text NOT NULL REFERENCES mfg.mfg_buy_orders (id) ON DELETE CASCADE,
    line_no             integer NOT NULL,
    product_id          text NOT NULL,            -- cp_products.id
    qty                 numeric(18,6) NOT NULL,
    unit                text,
    unit_price          numeric(18,4) NOT NULL DEFAULT 0,
    expected_on         date,                     -- the line's own date, else the order's
    received_qty        numeric(18,6) NOT NULL DEFAULT 0,
    planned_order_id    text REFERENCES mfg.mfg_planned_orders (id),
    closed_at           timestamptz,              -- short-closed: no more supply expected
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    created_by          text,
    updated_at          timestamptz NOT NULL DEFAULT now(),
    updated_by          text,
    UNIQUE (order_id, line_no)
);
CREATE INDEX IF NOT EXISTS mfg_buy_order_lines_product_idx ON mfg.mfg_buy_order_lines (bus_id, product_id);
CREATE INDEX IF NOT EXISTS mfg_buy_order_lines_open_idx
    ON mfg.mfg_buy_order_lines (bus_id, product_id, expected_on) WHERE closed_at IS NULL;
CREATE INDEX IF NOT EXISTS mfg_buy_order_lines_planned_idx
    ON mfg.mfg_buy_order_lines (planned_order_id) WHERE planned_order_id IS NOT NULL;
ALTER TABLE mfg.mfg_buy_order_lines DROP CONSTRAINT IF EXISTS mfg_buy_order_lines_rules_check;
ALTER TABLE mfg.mfg_buy_order_lines ADD CONSTRAINT mfg_buy_order_lines_rules_check
    CHECK (qty > 0 AND unit_price >= 0 AND received_qty >= 0 AND received_qty <= qty * 1.1 AND line_no >= 1);

COMMIT;
