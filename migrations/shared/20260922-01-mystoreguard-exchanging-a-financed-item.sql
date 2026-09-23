-- Exchanging an item that is still being paid for.
--
-- Today an exchange on an instalment sale clears the plan out of the returned
-- goods AND hands over the replacement, so the customer leaves owing nothing
-- with a new item and the shop is down one. Nothing charged the replacement:
-- exchange_difference_amount is written to the return and read by nobody.
--
-- Rather than pick a rule for every shop, the policy now carries the choice,
-- because the right answer depends on the trade. A phone shop replacing a
-- faulty handset may want the plan to carry straight over; a shop swapping
-- goods of different value may want the money settled and a fresh plan.

ALTER TABLE mystoreguard.msg_installment_policies
    -- What happens to the value of the returned item when the exchange
    -- becomes a new sale.
    --   CARRY_TO_NEW_PLAN — the surplus becomes a credit on the new sale, so
    --                       the customer swaps the item and keeps paying
    --                       without paying twice.
    --   PAY_OUT_SURPLUS   — the old plan settles as it does now, the surplus
    --                       goes back as cash, and the new sale starts from
    --                       zero under current policy.
    ADD COLUMN IF NOT EXISTS exchange_credit_mode text
        NOT NULL DEFAULT 'CARRY_TO_NEW_PLAN',
    -- Whether the shop may still finish an exchange WITHOUT raising a new
    -- sale. Default false: that is the path that gives an item away, and a
    -- shop should have to turn it on deliberately rather than find it on.
    ADD COLUMN IF NOT EXISTS allow_complete_on_exchange boolean
        NOT NULL DEFAULT false;

ALTER TABLE mystoreguard.msg_installment_policies
    DROP CONSTRAINT IF EXISTS ck_msg_installment_policies_exchange_credit_mode;
ALTER TABLE mystoreguard.msg_installment_policies
    ADD CONSTRAINT ck_msg_installment_policies_exchange_credit_mode
        CHECK (exchange_credit_mode IN ('CARRY_TO_NEW_PLAN', 'PAY_OUT_SURPLUS'));

-- Where a sale came from, when it came from an exchange.
--
-- The replacement is a sale in its own right — it has its own plan, its own
-- schedule, its own receipt. But read on its own it looks like a customer
-- who walked in and bought a phone, with no sign that they handed one back
-- an hour earlier. Both ids, because the return holds the figures and the
-- sale holds what was originally bought, and a shop asking "why is this
-- here?" wants to reach either.
ALTER TABLE mystoreguard.msg_sales
    ADD COLUMN IF NOT EXISTS exchanged_from_sale_id text,
    ADD COLUMN IF NOT EXISTS exchanged_from_return_id text;

-- Not foreign keys on purpose. A sale must survive the deletion of whatever
-- it came from — losing the link is a gap in the story, but a delete that
-- cascades into live sales, or is blocked by them, is worse.
CREATE INDEX IF NOT EXISTS ix_msg_sales_exchanged_from_sale
    ON mystoreguard.msg_sales (tenant_id, exchanged_from_sale_id)
    WHERE exchanged_from_sale_id IS NOT NULL;
