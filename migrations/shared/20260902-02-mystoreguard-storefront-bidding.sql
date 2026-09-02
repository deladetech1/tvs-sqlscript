-- 20260902-02-mystoreguard-storefront-bidding.sql
-- Bidding: an item, a clock, and whoever is highest when it stops.
--
-- An ascending auction, which is the only kind the storefront's existing screen
-- was ever drawn for: a current price, a countdown, and a bid that must beat
-- what is already there. Placing a bid costs coins — that is what coins are for
-- — and the coins are spent whether or not the bid wins, because they buy the
-- act of bidding rather than the item.
--
-- Two things here exist because auctions go wrong in specific, well-known ways.
--
-- The first is the anti-snipe extension. Without it, an auction is decided by
-- whoever's phone has the shortest round trip in the final second, which is not
-- a contest about the item. A bid inside the last stretch pushes the close out,
-- so the auction ends when bidding stops rather than when the clock does.
--
-- The second is that a winner is STAMPED, not computed. "Whoever has the
-- highest bid" is a query that keeps answering, and it would keep answering
-- differently if a bid were ever voided after the close. Once an auction ends,
-- who won is a fact, and facts are written down.
--
-- There is no chat table. Bidders see each other through the bids themselves
-- and through reactions — engagement with nothing to moderate, no way to
-- exchange contact details around the shop, and no inbox for a shop owner to
-- police at midnight.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================================
-- 1. The auction.
--
--    One product, one run. A product may be auctioned repeatedly — that is
--    several rows, not a reused one, because each has its own bids and its own
--    winner and flattening them would lose both.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_auctions (
    id                      text        PRIMARY KEY,
    tenant_id               text        NOT NULL,
    org_id                  text        NOT NULL,
    bus_id                  text        NOT NULL,

    -- The branch whose stock this sells from. Fixed when the auction is
    -- created rather than found at the end: an auction that closes and then
    -- discovers no branch can fill it has already taken somebody's coins.
    loc_id                  text        NOT NULL,
    product_id              text        NOT NULL,

    -- What the shop calls it here. Empty falls back to the product's own name,
    -- so an auction needs no copywriting to run.
    title                   text,
    blurb                   text,

    starting_price          numeric(18, 2) NOT NULL,
    -- The least a new bid must beat the current one by. Without a floor, an
    -- auction becomes a thousand one-pesewa bids, which is a coin-farming
    -- exercise rather than a sale.
    bid_increment           numeric(18, 2) NOT NULL DEFAULT 1.00,
    -- Below this the shop is not obliged to sell. NULL means no reserve.
    -- Never shown to bidders; a visible reserve is just a higher start.
    reserve_price           numeric(18, 2),

    opens_at                timestamptz NOT NULL,
    closes_at               timestamptz NOT NULL,
    -- A bid landing within this many seconds of the close pushes closes_at out
    -- by the same amount. Zero switches sniping protection off.
    extend_seconds          integer     NOT NULL DEFAULT 60,

    -- SCHEDULED once created, CANCELLED if the shop pulls it, SETTLED once the
    -- winner has been stamped. Live and ended are NOT stored: they are the
    -- clock, and a stored copy of the clock is a copy that goes stale between
    -- the moment it is written and the moment anybody reads it.
    status                  text        NOT NULL DEFAULT 'SCHEDULED',

    -- ---- stamped once, at settlement ----
    settled_at              timestamptz,
    winner_customer_id      text,
    winning_bid_id          text,
    winning_amount          numeric(18, 2),
    -- Why there is no winner, when there is none: nobody bid, or the top bid
    -- did not meet the reserve. Both are outcomes worth telling the shop about.
    settled_outcome         text,

    -- The sale raised for the winner, once the shop records it. An auction that
    -- ends is a promise; this is the row that shows it was kept.
    sale_id                 text,

    cdatetime               timestamptz NOT NULL DEFAULT now(),
    udatetime               timestamptz,
    created_by              text,
    updated_by              text,
    delete_status           text        NOT NULL DEFAULT 'NOT_DELETED',
    deleted_at              timestamptz,
    deleted_by              text
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'ck_msg_auctions_status') THEN
        ALTER TABLE mystoreguard.msg_auctions
            ADD CONSTRAINT ck_msg_auctions_status CHECK (
                status IN ('SCHEDULED', 'CANCELLED', 'SETTLED')
            );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'ck_msg_auctions_outcome') THEN
        ALTER TABLE mystoreguard.msg_auctions
            ADD CONSTRAINT ck_msg_auctions_outcome CHECK (
                settled_outcome IS NULL
                OR settled_outcome IN ('WON', 'NO_BIDS', 'RESERVE_NOT_MET')
            );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'ck_msg_auctions_window') THEN
        ALTER TABLE mystoreguard.msg_auctions
            ADD CONSTRAINT ck_msg_auctions_window CHECK (
                -- An auction that closes before it opens can never be bid on,
                -- and would sit on the storefront looking live.
                closes_at > opens_at
                AND starting_price >= 0
                AND bid_increment > 0
                AND extend_seconds >= 0
                AND (reserve_price IS NULL OR reserve_price >= starting_price)
            );
    END IF;
END $$;

-- What the storefront asks for: this shop's auctions, by when they close.
CREATE INDEX IF NOT EXISTS ix_msg_auctions_shop
    ON mystoreguard.msg_auctions (tenant_id, org_id, bus_id, closes_at DESC)
    WHERE delete_status = 'NOT_DELETED';

-- What the settlement pass asks for: ended, not yet stamped.
CREATE INDEX IF NOT EXISTS ix_msg_auctions_unsettled
    ON mystoreguard.msg_auctions (closes_at)
    WHERE status = 'SCHEDULED' AND delete_status = 'NOT_DELETED';


-- =====================================================================================
-- 2. Every bid.
--
--    Append-only, like the coin ledger it spends from. A bid is never edited or
--    removed — it is voided, which leaves it visible and explains the gap. An
--    auction whose history can be quietly rewritten is one nobody should enter.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_auction_bids (
    id              text        PRIMARY KEY,
    tenant_id       text        NOT NULL,
    org_id          text        NOT NULL,
    bus_id          text        NOT NULL,
    auction_id      text        NOT NULL,
    customer_id     text        NOT NULL,

    amount          numeric(18, 2) NOT NULL,
    -- What placing it cost, as it cost then. The shop may change its rate
    -- tomorrow, and this bid was still paid for at today's.
    coins_spent     integer     NOT NULL DEFAULT 0,

    -- Voided bids stay in the list, struck through, with a reason. Deleting
    -- them would make the price appear to fall for no stated cause.
    is_void         boolean     NOT NULL DEFAULT false,
    void_reason     text,

    cdatetime       timestamptz NOT NULL DEFAULT now(),
    voided_at       timestamptz,
    voided_by       text
);

-- The one query that matters: this auction's bids, highest first. Every read of
-- a current price, a leaderboard and a winner comes through it.
CREATE INDEX IF NOT EXISTS ix_msg_auction_bids_ranking
    ON mystoreguard.msg_auction_bids (tenant_id, auction_id, amount DESC, cdatetime ASC)
    WHERE is_void = false;

-- "What am I bidding on", from the shopper's side.
CREATE INDEX IF NOT EXISTS ix_msg_auction_bids_bidder
    ON mystoreguard.msg_auction_bids (tenant_id, customer_id, cdatetime DESC);


-- =====================================================================================
-- 3. Interest, which is the other half of an auction.
--
--    A silent auction page tells a visitor nothing about whether it is worth
--    joining. Reactions and watchers are how one bidder is visible to another
--    without a chat room: no free-text to moderate, no way to arrange a sale
--    around the shop, and nothing that needs a person reading it at midnight.
--
--    One reaction per person per auction, changed by re-reacting. Anything else
--    is a click-counting contest.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_auction_reactions (
    id              text        PRIMARY KEY,
    tenant_id       text        NOT NULL,
    org_id          text        NOT NULL,
    bus_id          text        NOT NULL,
    auction_id      text        NOT NULL,
    customer_id     text        NOT NULL,
    reaction        text        NOT NULL,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    udatetime       timestamptz
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'ck_msg_auction_reactions_kind') THEN
        ALTER TABLE mystoreguard.msg_auction_reactions
            ADD CONSTRAINT ck_msg_auction_reactions_kind CHECK (
                -- A closed set, on purpose. Free-text reactions are a chat with
                -- extra steps, and this is deliberately not that.
                reaction IN ('FIRE', 'EYES', 'HEART', 'WOW', 'CLAP')
            );
    END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_auction_reactions_one_each
    ON mystoreguard.msg_auction_reactions (tenant_id, auction_id, customer_id);


-- Who is in the room. Kept as a row per person rather than a counter so it can
-- be aged out — a counter only ever goes up, and "412 watching" on a dead
-- auction is a lie that cannot be corrected.
CREATE TABLE IF NOT EXISTS mystoreguard.msg_auction_watchers (
    id              text        PRIMARY KEY,
    tenant_id       text        NOT NULL,
    org_id          text        NOT NULL,
    bus_id          text        NOT NULL,
    auction_id      text        NOT NULL,
    customer_id     text        NOT NULL,
    last_seen_at    timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_auction_watchers_one_each
    ON mystoreguard.msg_auction_watchers (tenant_id, auction_id, customer_id);

CREATE INDEX IF NOT EXISTS ix_msg_auction_watchers_recent
    ON mystoreguard.msg_auction_watchers (tenant_id, auction_id, last_seen_at DESC);


-- =====================================================================================
-- 4. What links a bid to the coins it cost.
--
--    The coin ledger already carries auction_id and bid_id. This index is what
--    makes "refund every bid on this cancelled auction" a query rather than a
--    scan of every coin movement the shop has ever made.
-- =====================================================================================
CREATE INDEX IF NOT EXISTS ix_msg_coin_ledger_auction
    ON mystoreguard.msg_coin_ledger (tenant_id, auction_id)
    WHERE auction_id IS NOT NULL;
