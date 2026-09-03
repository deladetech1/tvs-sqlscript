-- 20260902-06-mystoreguard-installment-requests.sql
-- A shopper asking to buy something on instalments.
--
-- A request, and deliberately nothing more. It creates no sale, no plan, no
-- schedule and takes no money — a shopper on a website is not a cashier, and an
-- instalment plan is a credit decision the shop makes about a person. What the
-- storefront can do is put the question, with everything the shop needs to
-- answer it.
--
-- So this table is the question. Somebody in the shop reads it, and if they
-- agree, they raise the sale at the counter the way they always have. Approving
-- a request does not create anything either; it records that the shop said yes.
--
-- The quote is snapshotted whole. Prices move, policies get edited, and a
-- shopper who was shown "GHS 790 a month for ten months" must still be able to
-- point at that when they come in — and the shop must be able to see what its
-- own site promised, rather than recomputing today's answer and wondering why
-- the customer is arguing.
--
-- Idempotent; safe to re-run on every deploy.


CREATE TABLE IF NOT EXISTS mystoreguard.msg_installment_requests (
    id                  text        PRIMARY KEY,
    tenant_id           text        NOT NULL,
    org_id              text        NOT NULL,
    bus_id              text        NOT NULL,
    -- Null until somebody in the shop decides which branch would fill it. The
    -- storefront sums stock across branches and has no business choosing one.
    loc_id              text,

    -- Who is asking. A shopper is a customer, as everywhere else on the
    -- storefront, so the shop can see their history before deciding.
    customer_id         text        NOT NULL,

    product_id          text        NOT NULL,
    quantity            numeric     NOT NULL DEFAULT 1,

    -- What they were shown, at the moment they were shown it.
    unit_price          numeric(18, 2),
    total_amount        numeric(18, 2) NOT NULL,

    -- The terms they picked out of the ones the policy offered.
    policy_id           text,
    policy_name         text,
    frequency           text,
    term_count          integer,

    -- The whole computed quote: deposit, instalment, total payable, finance
    -- charge and the schedule. Kept because it is what the site promised.
    quote               jsonb       NOT NULL DEFAULT '{}'::jsonb,

    -- Anything the shopper wanted to say, and how to reach them if the contact
    -- on their customer record is not the one they want used for this.
    note                text,
    contact             text,

    status              text        NOT NULL DEFAULT 'PENDING',
    decided_at          timestamptz,
    decided_by          text,
    decision_note       text,

    -- Set if the shop went on to raise the sale. The link is what stops the
    -- same request being served twice by two members of staff.
    sale_id             text,

    cdatetime           timestamptz NOT NULL DEFAULT now(),
    udatetime           timestamptz,
    delete_status       text        NOT NULL DEFAULT 'NOT_DELETED',
    deleted_at          timestamptz,
    deleted_by          text
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'ck_msg_installment_requests_status') THEN
        ALTER TABLE mystoreguard.msg_installment_requests
            ADD CONSTRAINT ck_msg_installment_requests_status CHECK (
                status IN (
                    'PENDING',    -- waiting on the shop
                    'APPROVED',   -- the shop said yes; come in, or we will call
                    'DECLINED',   -- the shop said no
                    'WITHDRAWN',  -- the shopper changed their mind
                    'FULFILLED'   -- a sale was raised from it
                )
            );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'ck_msg_installment_requests_amounts') THEN
        ALTER TABLE mystoreguard.msg_installment_requests
            ADD CONSTRAINT ck_msg_installment_requests_amounts CHECK (
                quantity > 0 AND total_amount >= 0
            );
    END IF;
END $$;

-- The shop's queue: what is waiting, oldest first, because somebody who asked
-- on Monday should not be behind somebody who asked this morning.
CREATE INDEX IF NOT EXISTS ix_msg_installment_requests_pending
    ON mystoreguard.msg_installment_requests (tenant_id, org_id, bus_id, cdatetime ASC)
    WHERE status = 'PENDING' AND delete_status = 'NOT_DELETED';

-- The shopper's own list, on their profile.
CREATE INDEX IF NOT EXISTS ix_msg_installment_requests_customer
    ON mystoreguard.msg_installment_requests
       (tenant_id, org_id, bus_id, customer_id, cdatetime DESC)
    WHERE delete_status = 'NOT_DELETED';

-- One open request per person per product. Somebody pressing the button twice
-- is asking once; two rows would have two members of staff ring the same
-- customer about the same phone.
CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_installment_requests_open
    ON mystoreguard.msg_installment_requests (tenant_id, customer_id, product_id)
    WHERE status = 'PENDING' AND delete_status = 'NOT_DELETED';
