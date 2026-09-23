-- An agreed price for one client.
--
-- Until now a subscription named only a tier, and the price came from
-- cp_app_tier_configs on (app, tier) — one number for everybody. So a client
-- could be given a tier or given a price, never both: moving somebody to
-- PREMIUM for the features moved them to the PREMIUM price with it, and the
-- only ways round it were to discount the tier for every customer or to edit
-- the bill by hand every month and hope nobody forgot.
--
-- price_override is what the client actually agreed to pay, kept beside the
-- tier rather than instead of it. The tier still decides what they can use —
-- seats, limits, and the feature catalog — and the override decides what they
-- are charged. Null means the tier price, which is every subscription today.
--
-- PER LOCATION, exactly like the tier price it replaces: a month's bill is
-- this figure times the number of active locations on the app. Writing a whole
-- month's total in here would silently double for anyone with two branches.
--
-- The reason is a column, not a note appended to the description, because
-- "why is this client paying less" is asked long after whoever agreed it has
-- moved on, and an answer buried in free text beside other free text is not an
-- answer.
--
-- price_override_by carries a user id and deliberately no foreign key. The
-- person granting a discount is a platform administrator who need not belong to
-- the tenant being discounted, and a tenant-scoped key into cp_users would
-- refuse exactly those people. cp_users.id is unique on its own, so the id
-- still resolves to one person.
--
-- Replayable.

BEGIN;

ALTER TABLE core_platform.cp_app_subscriptions
    ADD COLUMN IF NOT EXISTS price_override        NUMERIC(12,2),
    ADD COLUMN IF NOT EXISTS price_override_reason TEXT,
    ADD COLUMN IF NOT EXISTS price_override_by     TEXT,
    ADD COLUMN IF NOT EXISTS price_override_at     TIMESTAMPTZ;

COMMENT ON COLUMN core_platform.cp_app_subscriptions.price_override IS
    'What this client agreed to pay per location per month for this app. NULL = charge the tier price from cp_app_tier_configs.';
COMMENT ON COLUMN core_platform.cp_app_subscriptions.price_override_reason IS
    'Why they are on a price of their own, in the words of whoever agreed it.';
COMMENT ON COLUMN core_platform.cp_app_subscriptions.price_override_by IS
    'The user who set it. No foreign key on purpose: a platform admin need not belong to the tenant.';
COMMENT ON COLUMN core_platform.cp_app_subscriptions.price_override_at IS
    'When it was set.';

-- Free is a real agreement, so zero is allowed; below zero is not, because a
-- bill that pays the customer is never what anybody meant.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conrelid = 'core_platform.cp_app_subscriptions'::regclass
           AND conname  = 'ck_cp_app_subscriptions_price_override'
    ) THEN
        ALTER TABLE core_platform.cp_app_subscriptions
            ADD CONSTRAINT ck_cp_app_subscriptions_price_override
            CHECK (price_override IS NULL OR price_override >= 0);
    END IF;
END $$;

-- The few rows that have one, for whoever is asked "who is on a special price".
CREATE INDEX IF NOT EXISTS idx_cp_app_subscriptions_price_override
    ON core_platform.cp_app_subscriptions (tenant_id, app_id)
    WHERE price_override IS NOT NULL;

COMMIT;
