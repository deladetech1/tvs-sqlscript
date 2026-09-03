-- 20260902-01-mystoreguard-storefront-coins.sql
-- Coins: what a shopper buys in order to bid.
--
-- Two prices, set by two different people, and it matters that they are
-- separate. The shop owner decides in MyStoreGuard what a bundle of coins
-- costs — 100 coins for GHS 50, 200 for GHS 80 — and decides on the ecommerce
-- settings screen how many coins one bid costs. The first is a price list; the
-- second is a rule about play. Putting both in one table would force a shop to
-- re-price its bundles in order to make bidding cheaper.
--
-- There is no balance column anywhere. A balance is the sum of a ledger, and
-- the moment it is also stored it can disagree with the ledger, at which point
-- neither number can be trusted and there is no way to tell which is wrong.
-- Money the shopper actually paid for is not a place to keep a cache.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================================
-- 1. What a shop sells coins in.
--
--    Priced in the same currency as everything else the shop sells. No currency
--    column: a bundle in dollars while the till is in cedis is not a feature,
--    it is a bug waiting for somebody to buy 200 coins for GHS 80 worth $80.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_coin_packages (
    id              text        PRIMARY KEY,
    tenant_id       text        NOT NULL,
    org_id          text        NOT NULL,
    bus_id          text        NOT NULL,

    -- What it is called on the shelf. "Starter", "Big bundle". Optional: a
    -- bundle with no name shows as its coin count, which is the honest label.
    name            text,
    coins           bigint      NOT NULL,
    price           numeric(18, 2) NOT NULL,

    -- Retired rather than deleted. A package somebody bought last month must
    -- stay resolvable, because a ledger entry points at it.
    is_active       boolean     NOT NULL DEFAULT true,

    -- The shop's own running order. Cheapest-first is a guess; shops like to
    -- put the bundle they want sold in the middle.
    sort_order      integer     NOT NULL DEFAULT 0,

    cdatetime       timestamptz NOT NULL DEFAULT now(),
    udatetime       timestamptz,
    created_by      text,
    updated_by      text,
    delete_status   text        NOT NULL DEFAULT 'NOT_DELETED',
    deleted_at      timestamptz,
    deleted_by      text
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'ck_msg_coin_packages_amounts') THEN
        ALTER TABLE mystoreguard.msg_coin_packages
            ADD CONSTRAINT ck_msg_coin_packages_amounts CHECK (
                -- A free bundle of coins is a promotion, and promotions have
                -- rules this table does not model. Zero coins is nothing at all.
                coins > 0 AND price > 0
            );
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_msg_coin_packages_shop
    ON mystoreguard.msg_coin_packages (tenant_id, org_id, bus_id, sort_order)
    WHERE delete_status = 'NOT_DELETED';


-- =====================================================================================
-- 2. Every coin that ever moved.
--
--    Append-only by intent. Nothing here is ever updated: a mistake is corrected
--    by writing the opposite entry, so the history of a balance survives its
--    corrections. `coins` is signed — positive puts coins in, negative takes
--    them out — which makes a balance one SUM rather than a case expression that
--    somebody will eventually get backwards.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_coin_ledger (
    id                  text        PRIMARY KEY,
    tenant_id           text        NOT NULL,
    org_id              text        NOT NULL,
    bus_id              text        NOT NULL,

    -- Whose coins. A shopper is a customer, as everywhere else on the
    -- storefront; coins bought online are spendable by the same person at the
    -- counter, because they are the same person.
    customer_id         text        NOT NULL,

    entry_type          text        NOT NULL,
    coins               bigint      NOT NULL,

    -- What the entry is about, whichever of these applies.
    package_id          text,
    -- The gateway reference the coins were bought with. Unique below, which is
    -- what stops a payment being credited twice when the sweep and the shopper's
    -- own "check my payment" both reach it.
    payment_reference   text,
    amount_paid         numeric(18, 2),
    auction_id          text,
    bid_id              text,

    -- Why, in words, for the entries no code can explain: a manual adjustment,
    -- a goodwill credit, a reversal.
    note                text,

    cdatetime           timestamptz NOT NULL DEFAULT now(),
    -- Null for anything the shopper did themselves. A staff id here means a
    -- person in the shop moved somebody else's coins, which is worth being able
    -- to ask about later.
    created_by          text
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'ck_msg_coin_ledger_type') THEN
        ALTER TABLE mystoreguard.msg_coin_ledger
            ADD CONSTRAINT ck_msg_coin_ledger_type CHECK (
                entry_type IN (
                    'PURCHASE',    -- bought and paid for
                    'BID_SPEND',   -- the cost of placing a bid
                    'BID_REFUND',  -- that cost returned: a cancelled auction
                    'ADJUSTMENT',  -- the shop moved them by hand
                    'REVERSAL'     -- an earlier entry undone
                )
            );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'ck_msg_coin_ledger_direction') THEN
        ALTER TABLE mystoreguard.msg_coin_ledger
            ADD CONSTRAINT ck_msg_coin_ledger_direction CHECK (
                -- Each kind of entry may only move coins the way its name says.
                -- Without this a bug that flips a sign turns spending coins into
                -- earning them, and the ledger still validates.
                coins <> 0
                AND (entry_type <> 'PURCHASE'   OR coins > 0)
                AND (entry_type <> 'BID_SPEND'  OR coins < 0)
                AND (entry_type <> 'BID_REFUND' OR coins > 0)
            );
    END IF;
END $$;

-- A payment credits coins exactly once, however many times it is banked.
CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_coin_ledger_payment
    ON mystoreguard.msg_coin_ledger (tenant_id, payment_reference)
    WHERE payment_reference IS NOT NULL;

-- Reading a balance and reading a statement are the same query shape.
CREATE INDEX IF NOT EXISTS ix_msg_coin_ledger_customer
    ON mystoreguard.msg_coin_ledger
       (tenant_id, org_id, bus_id, customer_id, cdatetime DESC);


-- =====================================================================================
-- 3. What one bid costs, and whether bidding happens at all.
--
--    On the ecommerce settings rather than the packages, because this is a rule
--    about the storefront, not a product. Zero is allowed and means bidding is
--    free — a shop running its first auction should not have to invent a price
--    for participation before it can try the feature.
-- =====================================================================================
ALTER TABLE mystoreguard.msg_ecommerce_settings
    ADD COLUMN IF NOT EXISTS bidding_enabled boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS coins_per_bid   integer NOT NULL DEFAULT 0;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'ck_msg_ecommerce_settings_coins_per_bid') THEN
        ALTER TABLE mystoreguard.msg_ecommerce_settings
            ADD CONSTRAINT ck_msg_ecommerce_settings_coins_per_bid CHECK (
                coins_per_bid >= 0
            );
    END IF;
END $$;
