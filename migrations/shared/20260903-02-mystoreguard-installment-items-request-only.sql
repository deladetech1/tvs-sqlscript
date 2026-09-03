-- 20260903-02-mystoreguard-installment-items-request-only.sql
-- Items the shop finances cannot be bought outright on its website.
--
-- A shop selling on instalments wants the plan arranged before anything else
-- happens: the customer asks, somebody in the shop approves, and only then does
-- the sale get raised. Leaving Add to cart on those items means the site can
-- take full payment for something that was meant to go through that gate, and
-- the first anybody knows is a paid order for goods nobody agreed terms on.
--
-- Off by default, and it has to be. Whether an item is "financed" is decided by
-- the shop's instalment policies, and a policy targeting ALL_PRODUCTS covers
-- the entire catalogue — turning this on for a shop with one of those removes
-- Add to cart from everything it sells. That is a legitimate way to run a shop
-- and a catastrophic accident, so it is a decision somebody makes, not a
-- default they inherit.
--
-- Idempotent; safe to re-run on every deploy.


ALTER TABLE mystoreguard.msg_ecommerce_settings
    ADD COLUMN IF NOT EXISTS installment_items_request_only boolean NOT NULL DEFAULT false;


COMMENT ON COLUMN mystoreguard.msg_ecommerce_settings.installment_items_request_only IS
    'When true, a product covered by an active ALLOW instalment policy cannot be '
    'added to a basket or paid for on the storefront — the only route is an '
    'instalment request the shop approves. Scope follows the policies: a policy '
    'targeting ALL_PRODUCTS makes the whole catalogue request-only.';
