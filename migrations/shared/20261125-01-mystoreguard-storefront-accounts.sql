-- 20261125-01-mystoreguard-storefront-accounts.sql
-- Shop accounts: everyone who signs up on a storefront, kept apart from customers.
--
-- Until now signing up on a storefront created a customer at once, so the customer
-- list filled with people who never bought anything. From here:
--
--   msg_storefront_accounts     everyone who signed up on the storefront (the "users")
--   msg_customers               customers, as before (walk-ins, imports, buyers). An
--                               account points at its customer with customer_id once
--                               the person buys (orders, asks for an instalment plan,
--                               bids or buys coins), or straight away when they prove
--                               a contact the shop already has on a customer.
--   msg_storefront_credentials  who can sign in with a password (the "can login"):
--                               one row per account that has one, holding only a hash.
--
-- How shoppers sign in is the shop's choice (msg_ecommerce_settings.auth_*): a code by
-- email, a code by SMS, username + password, email + password, any mix. The defaults are
-- the codes by email and SMS, which is what every storefront did before this, so an
-- existing shop keeps working unchanged.
--
-- Existing shoppers: each customer who has signed in to a storefront gets an account
-- linked to that customer (section 6), and their sessions keep working.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================================
-- 1. Shop accounts.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_storefront_accounts (
    id                 text        PRIMARY KEY,
    tenant_id          text        NOT NULL,
    org_id             text        NOT NULL,
    bus_id             text        NOT NULL,

    -- The customer this account is, once it is one. Null: signed up, not a customer.
    customer_id        text,
    became_customer_at timestamptz,

    -- How they can be found. Any may be empty, but not all unless the account is a
    -- customer's (ck below): a shopper from before this, whose contact another account holds.
    username           text,
    email              text,
    phone              text,
    -- Proved by a code sent there. Only a proved contact may link to an existing
    -- customer: otherwise anyone could sign up with a walk-in's number and read their
    -- points and plans.
    email_verified_at  timestamptz,
    phone_verified_at  timestamptz,

    -- What they told the shop, copied onto the customer when they become one.
    fullname           text,
    address            text,
    gender             text,
    date_of_birth      date,

    status             text        NOT NULL DEFAULT 'ACTIVE',
    last_sign_in_at    timestamptz,

    cdate              date,
    ctime              time,
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    created_by         text,
    udatetime          timestamptz,
    updated_by         text,
    deleted_at         timestamptz,
    deleted_by         text
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_storefront_accounts_status') THEN
        ALTER TABLE mystoreguard.msg_storefront_accounts
            ADD CONSTRAINT ck_msg_storefront_accounts_status CHECK (status IN ('ACTIVE', 'BLOCKED'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_storefront_accounts_findable') THEN
        ALTER TABLE mystoreguard.msg_storefront_accounts
            ADD CONSTRAINT ck_msg_storefront_accounts_findable
            CHECK (coalesce(username, email, phone, customer_id) IS NOT NULL);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_storefront_accounts_gender') THEN
        ALTER TABLE mystoreguard.msg_storefront_accounts
            ADD CONSTRAINT ck_msg_storefront_accounts_gender CHECK (
                gender IS NULL OR gender IN ('MALE', 'FEMALE', 'OTHER', 'PREFER_NOT_TO_SAY'));
    END IF;
END $$;

-- One account per username, email and phone in a shop.
CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_storefront_accounts_username
    ON mystoreguard.msg_storefront_accounts (tenant_id, bus_id, lower(username))
    WHERE username IS NOT NULL AND deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_storefront_accounts_email
    ON mystoreguard.msg_storefront_accounts (tenant_id, bus_id, lower(email))
    WHERE email IS NOT NULL AND deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_storefront_accounts_phone
    ON mystoreguard.msg_storefront_accounts (tenant_id, bus_id, phone)
    WHERE phone IS NOT NULL AND deleted_at IS NULL;
-- Not unique: a customer merge (cp_party_merge) may bring two accounts onto one customer.
CREATE INDEX IF NOT EXISTS ix_msg_storefront_accounts_customer
    ON mystoreguard.msg_storefront_accounts (customer_id)
    WHERE customer_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS ix_msg_storefront_accounts_shop
    ON mystoreguard.msg_storefront_accounts (tenant_id, bus_id, cdatetime DESC)
    WHERE deleted_at IS NULL;


-- =====================================================================================
-- 2. Passwords. Only a hash (scrypt, salted per row); never the password.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_storefront_credentials (
    account_id          text        PRIMARY KEY
                        REFERENCES mystoreguard.msg_storefront_accounts (id) ON DELETE CASCADE,
    tenant_id           text        NOT NULL,
    bus_id              text        NOT NULL,
    password_hash       text        NOT NULL,
    failed_attempts     integer     NOT NULL DEFAULT 0,
    locked_until        timestamptz,
    password_changed_at timestamptz NOT NULL DEFAULT now(),
    cdatetime           timestamptz NOT NULL DEFAULT now()
);


-- =====================================================================================
-- 3. Sessions and codes belong to an account. customer_id stays for the sessions that
--    are already out there; a new session has an account and maybe no customer yet.
-- =====================================================================================
ALTER TABLE mystoreguard.msg_storefront_sessions ADD COLUMN IF NOT EXISTS account_id text;
ALTER TABLE mystoreguard.msg_storefront_sessions ALTER COLUMN customer_id DROP NOT NULL;
CREATE INDEX IF NOT EXISTS ix_msg_storefront_sessions_account
    ON mystoreguard.msg_storefront_sessions (account_id, expires_at DESC)
    WHERE revoked_at IS NULL AND deleted_by IS NULL;

ALTER TABLE mystoreguard.msg_storefront_login_codes ADD COLUMN IF NOT EXISTS account_id text;
-- SIGN_IN: a code to sign in. VERIFY: proving a contact on an account. RESET: a new password.
ALTER TABLE mystoreguard.msg_storefront_login_codes ADD COLUMN IF NOT EXISTS purpose text NOT NULL DEFAULT 'SIGN_IN';
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_storefront_login_codes_purpose') THEN
        ALTER TABLE mystoreguard.msg_storefront_login_codes
            ADD CONSTRAINT ck_msg_storefront_login_codes_purpose CHECK (purpose IN ('SIGN_IN', 'VERIFY', 'RESET'));
    END IF;
END $$;


-- =====================================================================================
-- 4. How the shop's shoppers sign in. Defaults = what every storefront did before.
-- =====================================================================================
ALTER TABLE mystoreguard.msg_ecommerce_settings
    ADD COLUMN IF NOT EXISTS auth_otp_email          boolean NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS auth_otp_sms            boolean NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS auth_username_password  boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS auth_email_password     boolean NOT NULL DEFAULT false;


-- =====================================================================================
-- 5. A customer merge moves the account with the customer.
-- =====================================================================================
DO $$
BEGIN
    IF to_regclass('core_platform.cp_party_references') IS NOT NULL THEN
        INSERT INTO core_platform.cp_party_references (table_name, column_name, is_extension)
        VALUES ('mystoreguard.msg_storefront_accounts', 'customer_id', true)
        ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;
    END IF;
END $$;


-- =====================================================================================
-- 6. Existing shoppers: an account for each customer who has signed in to a storefront,
--    linked to that customer, with the contact they proved. A contact another account
--    already holds is left off (the unique indexes); the account is still made, and
--    still signs in through its customer's sessions.
-- =====================================================================================
DO $$
DECLARE r record;
BEGIN
    FOR r IN
        SELECT DISTINCT ON (s.bus_id, s.customer_id)
               s.tenant_id, s.org_id, s.bus_id, s.customer_id, c.fullname, c.address,
               lower(nullif(trim(c.email), '')) AS email,
               nullif(regexp_replace(coalesce(c.contact, ''), '[^0-9+]', '', 'g'), '') AS phone,
               min(s.cdatetime) OVER (PARTITION BY s.bus_id, s.customer_id) AS first_seen,
               max(s.last_seen_at) OVER (PARTITION BY s.bus_id, s.customer_id) AS last_seen,
               EXISTS (SELECT 1 FROM mystoreguard.msg_storefront_login_codes k
                        WHERE k.customer_id = s.customer_id AND k.bus_id = s.bus_id
                          AND k.channel = 'EMAIL' AND k.consumed_at IS NOT NULL) AS proved_email,
               EXISTS (SELECT 1 FROM mystoreguard.msg_storefront_login_codes k
                        WHERE k.customer_id = s.customer_id AND k.bus_id = s.bus_id
                          AND k.channel = 'SMS' AND k.consumed_at IS NOT NULL) AS proved_phone
          FROM mystoreguard.msg_storefront_sessions s
          JOIN mystoreguard.msg_customers c ON c.id = s.customer_id
         WHERE s.customer_id IS NOT NULL
           AND s.deleted_by IS NULL
           AND NOT EXISTS (SELECT 1 FROM mystoreguard.msg_storefront_accounts a
                            WHERE a.customer_id = s.customer_id AND a.bus_id = s.bus_id
                              AND a.deleted_at IS NULL)
    LOOP
        INSERT INTO mystoreguard.msg_storefront_accounts
            (id, tenant_id, org_id, bus_id, customer_id, became_customer_at, email, phone,
             email_verified_at, phone_verified_at, fullname, address, last_sign_in_at,
             cdate, ctime, cdatetime, created_by)
        SELECT 'sfa_' || replace(gen_random_uuid()::text, '-', ''), r.tenant_id, r.org_id, r.bus_id,
               r.customer_id, r.first_seen,
               CASE WHEN taken_email THEN NULL ELSE r.email END,
               CASE WHEN taken_phone THEN NULL ELSE r.phone END,
               CASE WHEN r.proved_email AND NOT taken_email AND r.email IS NOT NULL THEN r.first_seen END,
               CASE WHEN r.proved_phone AND NOT taken_phone AND r.phone IS NOT NULL THEN r.first_seen END,
               r.fullname, r.address, r.last_seen,
               r.first_seen::date, r.first_seen::time, r.first_seen, 'migration:20261125-01'
          FROM (SELECT
                  EXISTS (SELECT 1 FROM mystoreguard.msg_storefront_accounts a
                           WHERE a.tenant_id = r.tenant_id AND a.bus_id = r.bus_id AND a.deleted_at IS NULL
                             AND lower(a.email) = r.email) AS taken_email,
                  EXISTS (SELECT 1 FROM mystoreguard.msg_storefront_accounts a
                           WHERE a.tenant_id = r.tenant_id AND a.bus_id = r.bus_id AND a.deleted_at IS NULL
                             AND a.phone = r.phone) AS taken_phone) t
         ;
    END LOOP;

    UPDATE mystoreguard.msg_storefront_sessions s
       SET account_id = a.id
      FROM mystoreguard.msg_storefront_accounts a
     WHERE s.account_id IS NULL AND s.customer_id IS NOT NULL
       AND a.customer_id = s.customer_id AND a.bus_id = s.bus_id AND a.deleted_at IS NULL;
END $$;
