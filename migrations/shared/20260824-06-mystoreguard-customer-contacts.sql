-- =====================================================================
-- More than one phone number and email per customer
-- ---------------------------------------------------------------------
-- msg_customers carries a single `email` and a single `contact`, each unique
-- per business. Real customers have more than one — a business customer has an
-- accounts address and the person who actually answers the phone — and until
-- now the shop had to pick one and lose the rest.
--
-- The single columns STAY, and stay authoritative as the PRIMARY value. About a
-- dozen features read c.email / c.contact directly — clients search, loyalty
-- tiers and points, segments and the campaigns they send, customer insights,
-- deliveries, receipts — and none of them need to change or even know this
-- table exists. Extra values live here alongside.
--
-- Uniqueness carries over rather than being quietly dropped: today Postgres
-- refuses two customers with the same email in a business, and that has to keep
-- holding once a customer can have several, or a walk-in quoting a phone number
-- could match two records with no way to tell them apart.
--
-- Runs after the EF migrations on every deploy. Idempotent; safe to re-run.
-- =====================================================================

CREATE TABLE IF NOT EXISTS mystoreguard.msg_customer_contacts (
    id           text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text        NOT NULL,
    org_id       text        NOT NULL,
    bus_id       text        NOT NULL,
    customer_id  text        NOT NULL,

    -- 'email' or 'phone'. Held as text rather than an enum so adding a kind
    -- later is a code change, not a migration on a live table.
    kind         text        NOT NULL,
    value        text        NOT NULL,

    -- The one mirrored onto msg_customers, and therefore the one every existing
    -- feature uses.
    is_primary   boolean     NOT NULL DEFAULT false,

    cdate        date,
    ctime        time,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    udatetime    timestamptz,
    created_by   text,
    updated_by   text,

    CONSTRAINT ck_msg_customer_contacts_kind CHECK (kind IN ('email', 'phone'))
);

-- The rule that was on msg_customers, now covering every value a customer has.
CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_customer_contacts_value
    ON mystoreguard.msg_customer_contacts (tenant_id, org_id, bus_id, kind, value);

-- Exactly one primary per kind per customer, enforced here rather than hoped
-- for in code: two primaries would make "the customer's email" ambiguous, and
-- whichever one got mirrored onto msg_customers would be arbitrary.
CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_customer_contacts_primary
    ON mystoreguard.msg_customer_contacts (tenant_id, org_id, bus_id, customer_id, kind)
    WHERE is_primary;

CREATE INDEX IF NOT EXISTS idx_msg_customer_contacts_customer
    ON mystoreguard.msg_customer_contacts (tenant_id, org_id, bus_id, customer_id);

-- ---------------------------------------------------------------------
-- Backfill: every customer's existing email and phone become their primary.
--
-- Without this an existing customer would look like they had no contact details
-- the moment the new screen shipped. ON CONFLICT DO NOTHING makes the whole
-- thing re-runnable, and skips a value some other customer in the business
-- already holds — that pair cannot both be primary, and the older single-column
-- unique index means it should not arise in the first place.
-- ---------------------------------------------------------------------
INSERT INTO mystoreguard.msg_customer_contacts
    (tenant_id, org_id, bus_id, customer_id, kind, value, is_primary,
     cdate, ctime, cdatetime, created_by)
SELECT c.tenant_id, c.org_id, c.bus_id, c.id, 'email', trim(c.email), true,
       CURRENT_DATE, CURRENT_TIME, now(), c.created_by
FROM mystoreguard.msg_customers c
WHERE c.email IS NOT NULL AND trim(c.email) <> ''
  AND c.delete_status = 'NOT_DELETED'
ON CONFLICT DO NOTHING;

INSERT INTO mystoreguard.msg_customer_contacts
    (tenant_id, org_id, bus_id, customer_id, kind, value, is_primary,
     cdate, ctime, cdatetime, created_by)
SELECT c.tenant_id, c.org_id, c.bus_id, c.id, 'phone', trim(c.contact), true,
       CURRENT_DATE, CURRENT_TIME, now(), c.created_by
FROM mystoreguard.msg_customers c
WHERE c.contact IS NOT NULL AND trim(c.contact) <> ''
  AND c.delete_status = 'NOT_DELETED'
ON CONFLICT DO NOTHING;
