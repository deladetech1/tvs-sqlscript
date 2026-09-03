-- 20260901-07-mystoreguard-storefront-shoppers.sql
-- Who a shopper is, and how they prove it.
--
-- A shopper IS a customer. Not a parallel identity: the shop already knows these
-- people — they walk in, they have loyalty points, they owe on installment plans
-- — and giving the storefront its own user table would mean the same person
-- existing twice with two histories, which is the failure that makes "do you
-- have an account with us" an unanswerable question.
--
-- So signing up on the storefront finds an existing customer by contact or
-- email, or creates one. Everything downstream — orders, plans, points — then
-- points at the customer it already would have.
--
-- Proving it is a code sent to that contact. Modelled on the redemption
-- verifications this app already runs at the till: the code is hashed, short
-- lived, attempt limited, and never stored in a form that could be read back
-- out of the database.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================================
-- 1. What signup asks for beyond what a customer already has.
--
--    msg_customers already carries fullname, email, contact and address. Only
--    these two are new, and both are optional — the shop asks, the shopper may
--    decline, and nothing downstream may assume either is present.
-- =====================================================================================
ALTER TABLE mystoreguard.msg_customers
    ADD COLUMN IF NOT EXISTS gender        text,
    ADD COLUMN IF NOT EXISTS date_of_birth date;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_customers_gender'
    ) THEN
        ALTER TABLE mystoreguard.msg_customers
            ADD CONSTRAINT ck_msg_customers_gender CHECK (
                -- PREFER_NOT_TO_SAY is a real answer and is stored as one. The
                -- alternative is NULL meaning both "declined" and "never asked",
                -- and those are different facts about a person.
                gender IS NULL
                OR gender IN ('MALE', 'FEMALE', 'OTHER', 'PREFER_NOT_TO_SAY')
            );
    END IF;
END $$;


-- =====================================================================================
-- 2. The code that proves a contact belongs to whoever typed it.
--
--    One row per request. The code itself is never stored — only a hash of it
--    salted with the row id, so a leaked table cannot be replayed and two
--    identical codes in flight do not collide.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_storefront_login_codes (
    id              text        PRIMARY KEY,
    tenant_id       text        NOT NULL,
    org_id          text        NOT NULL,
    bus_id          text        NOT NULL,

    -- How it was sent, and to where. Kept so a retry goes to the same place and
    -- so "we sent it to the number ending 4821" can be said without guessing.
    channel         text        NOT NULL,
    destination     text        NOT NULL,

    code_hash       text        NOT NULL,

    -- The customer this will sign in, when one already exists. Null for someone
    -- the shop has never met — the account is created on the way through, after
    -- the code is proved, never before.
    customer_id     text,

    attempts        integer     NOT NULL DEFAULT 0,
    expires_at      timestamptz NOT NULL,
    consumed_at     timestamptz,

    cdate           date,
    ctime           time,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text,
    deleted_by      text
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_storefront_login_codes_channel'
    ) THEN
        ALTER TABLE mystoreguard.msg_storefront_login_codes
            ADD CONSTRAINT ck_msg_storefront_login_codes_channel
            CHECK (channel IN ('SMS', 'EMAIL'));
    END IF;
END $$;

-- The lookup every verify does: the newest live code for this destination.
CREATE INDEX IF NOT EXISTS ix_msg_storefront_login_codes_lookup
    ON mystoreguard.msg_storefront_login_codes
       (tenant_id, org_id, bus_id, destination, expires_at DESC)
    WHERE consumed_at IS NULL AND deleted_by IS NULL;


-- =====================================================================================
-- 3. A signed-in shopper.
--
--    An opaque token rather than a JWT. A staff token is minted by the platform
--    and carries roles and permissions; a shopper has none of that, and issuing
--    them from the same place is how an audience mix-up becomes a privilege
--    escalation. This is a random secret, stored hashed, that means exactly one
--    thing: this browser is that customer, until it expires or is revoked.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_storefront_sessions (
    id           text        PRIMARY KEY,
    tenant_id    text        NOT NULL,
    org_id       text        NOT NULL,
    bus_id       text        NOT NULL,
    customer_id  text        NOT NULL,

    token_hash   text        NOT NULL,

    expires_at   timestamptz NOT NULL,
    revoked_at   timestamptz,
    last_seen_at timestamptz,

    cdate        date,
    ctime        time,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text,
    deleted_by   text
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_msg_storefront_sessions_token
    ON mystoreguard.msg_storefront_sessions (token_hash);

CREATE INDEX IF NOT EXISTS ix_msg_storefront_sessions_customer
    ON mystoreguard.msg_storefront_sessions (customer_id, expires_at DESC)
    WHERE revoked_at IS NULL AND deleted_by IS NULL;


-- =====================================================================================
-- 4. A storefront has to be findable by its address.
--
--    Every public request arrives with a slug and nothing else — no headers, no
--    tenant. This is the one lookup that turns "big-phones" into a business, so
--    it is the one that must not be a sequential scan, and it must not match two
--    businesses.
-- =====================================================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_msg_ecommerce_settings_slug
    ON mystoreguard.msg_ecommerce_settings (lower(storefront_slug))
    WHERE storefront_slug IS NOT NULL AND deleted_by IS NULL;
