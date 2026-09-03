-- 20260903-01-mystoreguard-installment-request-notifiers.sql
-- Who the shop wants told when a request for instalments arrives from its site.
--
-- A third list of people on a policy, beside the approvers and the refund
-- closers, and a separate one for the same reason those two are separate: being
-- the person who reads what came in overnight is a different job from being the
-- person who may approve a plan, and is often a different person. A shop that
-- wanted the same names in both can put them in both.
--
-- It hangs off the policy rather than off the store's settings because the
-- request already carries the policy that priced it — the quote resolves a
-- governing policy before it can quote anything — so the people who wrote the
-- terms are the people who get asked about them. A shop selling phones on one
-- policy and generators on another does not want one inbox for both.
--
-- Nobody listed means nobody is emailed. That is a decision, not a gap: the
-- requests still land in the dashboard and on the alerts bell, and a shop that
-- would rather look than be told should not have to invent an address.
--
-- Idempotent; safe to re-run on every deploy.


CREATE TABLE IF NOT EXISTS mystoreguard.msg_installment_policy_request_notifiers (
    id              text        NOT NULL DEFAULT gen_random_uuid()::text,
    tenant_id       text        NOT NULL,
    org_id          text        NOT NULL,
    bus_id          text        NOT NULL,
    policy_id       text        NOT NULL,
    user_id         text        NOT NULL,
    display_order   integer     NOT NULL DEFAULT 0,
    cdate           text,
    ctime           text,
    cdatetime       timestamptz DEFAULT now(),
    created_by      text,
    CONSTRAINT pk_msg_installment_policy_request_notifiers
        PRIMARY KEY (tenant_id, org_id, bus_id, id)
);

-- One person, once. A duplicate would send the same mail twice and read as two
-- people watching when there is one.
CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_installment_policy_request_notifiers_pair
    ON mystoreguard.msg_installment_policy_request_notifiers
       (tenant_id, org_id, bus_id, policy_id, user_id);

-- Reading a policy loads its people in one pass, keyed the way the loader asks.
CREATE INDEX IF NOT EXISTS ix_msg_installment_policy_request_notifiers_policy
    ON mystoreguard.msg_installment_policy_request_notifiers
       (tenant_id, org_id, bus_id, policy_id, display_order);

-- And the other direction: everything one person is watching, for the day
-- somebody leaves and has to be taken off the lists they were on.
CREATE INDEX IF NOT EXISTS ix_msg_installment_policy_request_notifiers_user
    ON mystoreguard.msg_installment_policy_request_notifiers (user_id, tenant_id);


-- When the shop was last told about each request, so a reminder pass cannot
-- send the same one twice and a request that arrived while the mail server was
-- down is not silently never mentioned.
ALTER TABLE mystoreguard.msg_installment_requests
    ADD COLUMN IF NOT EXISTS notified_at timestamptz;
