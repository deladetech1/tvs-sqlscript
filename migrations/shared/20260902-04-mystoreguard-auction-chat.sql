-- 20260902-04-mystoreguard-auction-chat.sql
-- Bidders talking to each other while an auction runs.
--
-- The room is the point: an auction with people in it is worth staying in, and
-- a silent one is a form. Reactions carried some of that and not enough — you
-- cannot ask "is this the 256GB one" with an emoji.
--
-- What a chat brings with it is the reason this table has the columns it does.
-- Anything people can type, somebody eventually types something the shop does
-- not want on its site, at an hour when nobody is watching. So:
--
--   * a message is hidden, never deleted — the shop can see what was said and
--     who said it, which is what makes a complaint answerable;
--   * every message is scoped to one auction and dies with it, so there is no
--     inbox, no direct messages, and no way to carry a conversation from one
--     item to another;
--   * the sender is a customer, so a shop can find them, and abuse is
--     attributable rather than anonymous.
--
-- There is deliberately no edit. A message that can be changed after it is
-- answered turns a conversation into an argument about what was said.
--
-- Idempotent; safe to re-run on every deploy.


CREATE TABLE IF NOT EXISTS mystoreguard.msg_auction_messages (
    id              text        PRIMARY KEY,
    tenant_id       text        NOT NULL,
    org_id          text        NOT NULL,
    bus_id          text        NOT NULL,
    auction_id      text        NOT NULL,

    -- Who said it. Never null: an anonymous chat on a shop's own site is a
    -- liability nobody signed up for.
    customer_id     text        NOT NULL,
    body            text        NOT NULL,

    -- Said by the shop rather than by a bidder. Marked so the room can tell the
    -- seller from the people bidding against each other, which matters when the
    -- answer to "does it come with the charger" is the shop's.
    is_seller       boolean     NOT NULL DEFAULT false,
    -- The staff member behind a seller message, for the shop's own records. The
    -- room only ever sees "Seller".
    posted_by_user  text,

    -- Hidden, not deleted. The row stays so a shop can answer for what was on
    -- its site; the storefront simply stops sending it.
    is_hidden       boolean     NOT NULL DEFAULT false,
    hidden_at       timestamptz,
    hidden_by       text,
    hidden_reason   text,

    cdatetime       timestamptz NOT NULL DEFAULT now()
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'ck_msg_auction_messages_body') THEN
        ALTER TABLE mystoreguard.msg_auction_messages
            ADD CONSTRAINT ck_msg_auction_messages_body CHECK (
                -- A cap in the database as well as in the service, because the
                -- service is one caller and the table outlives it. Long enough
                -- for a real question, short enough that nobody pastes an essay
                -- into a live auction.
                length(btrim(body)) BETWEEN 1 AND 500
            );
    END IF;
END $$;

-- The one query the room makes, over and over: this auction's messages since
-- the last one I saw. Ordered by time, and the id breaks ties so a cursor can
-- never skip or repeat a message written in the same millisecond.
CREATE INDEX IF NOT EXISTS ix_msg_auction_messages_room
    ON mystoreguard.msg_auction_messages (tenant_id, auction_id, cdatetime, id)
    WHERE is_hidden = false;

-- What the shop needs when somebody complains: everything one person has said,
-- hidden messages included.
CREATE INDEX IF NOT EXISTS ix_msg_auction_messages_sender
    ON mystoreguard.msg_auction_messages (tenant_id, customer_id, cdatetime DESC);
