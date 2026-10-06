-- =====================================================================================
-- A client can be on a rate of their own, the way they can be on a price of their own.
--
-- WHAT THE TWO NUMBERS ARE
-- cp_app_tier_configs.price is in USD, per location per month. cp_app_tier_configs.rate
-- is how many units of local currency one USD buys -- 12.0 by default, Ghana Cedis.
-- Every cp_billings_logs row snapshots BOTH, so a bill already records the rate it was
-- raised at and an old bill never moves when today's rate does.
--
-- 20260923-06 made the price negotiable per client and left the rate fixed at whatever
-- the tier said. That is the wrong half to leave fixed. A price is agreed once; a rate
-- is the thing that actually drifts, and a client invoiced in their own currency at a
-- rate nobody can set is a client whose bill we cannot hold still. The two have to be
-- negotiable together or "what will this cost me next month" has no answer.
--
-- WHY PER SUBSCRIPTION AND NOT PER TENANT
-- Exactly where the price override lives, and for the same reason: a subscription is
-- (business, app), so a tenant holds several. Putting the rate on the tenant would make
-- it the one thing about their billing that could not differ per product, which reads
-- as a rule and is only an accident of where the column went. Same grain, one mental
-- model, and the console's pricing screen sets both on one row.
--
-- WHY NOT A RATE TABLE WITH DATES
-- The obvious richer design is a dated FX table and a lookup by bill date. Deliberately
-- not: the rate that matters is already frozen onto every billing row at the moment it
-- is raised, so history is answered. A second dated table would be a second source for
-- a question that is already answered, and the two would disagree the first time
-- somebody backfilled one of them.
-- =====================================================================================

BEGIN;

ALTER TABLE core_platform.cp_app_subscriptions
    ADD COLUMN IF NOT EXISTS rate_override        NUMERIC(12,4),
    ADD COLUMN IF NOT EXISTS rate_override_reason TEXT,
    ADD COLUMN IF NOT EXISTS rate_override_by     TEXT,
    ADD COLUMN IF NOT EXISTS rate_override_at     TIMESTAMPTZ;

COMMENT ON COLUMN core_platform.cp_app_subscriptions.rate_override IS
    'Local currency per USD agreed with this client for this app. NULL = use the tier '
    'rate from cp_app_tier_configs. Four decimals because a rate is a conversion, not a '
    'price: rounding it to two before multiplying moves the bill.';
COMMENT ON COLUMN core_platform.cp_app_subscriptions.rate_override_reason IS
    'Why they are on a rate of their own, in the words of whoever agreed it.';
COMMENT ON COLUMN core_platform.cp_app_subscriptions.rate_override_by IS
    'The user who set it. No foreign key on purpose: a platform admin need not belong '
    'to the tenant.';
COMMENT ON COLUMN core_platform.cp_app_subscriptions.rate_override_at IS
    'When it was set.';

-- A rate of zero would make every bill free while reading like a configured rate, which
-- is worse than an obviously missing one. Free is expressed as a price of 0 -- that is
-- what price_override allows zero FOR. So a rate must be positive.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conrelid = 'core_platform.cp_app_subscriptions'::regclass
           AND conname  = 'ck_cp_app_subscriptions_rate_override'
    ) THEN
        ALTER TABLE core_platform.cp_app_subscriptions
            ADD CONSTRAINT ck_cp_app_subscriptions_rate_override
            CHECK (rate_override IS NULL OR rate_override > 0);
    END IF;
END $$;

-- The few rows that have one, for whoever is asked "who is on a special rate".
CREATE INDEX IF NOT EXISTS idx_cp_app_subscriptions_rate_override
    ON core_platform.cp_app_subscriptions (tenant_id, app_id)
    WHERE rate_override IS NOT NULL;

COMMIT;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer;
BEGIN
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'core_platform' AND table_name = 'cp_app_subscriptions'
       AND column_name IN ('rate_override', 'rate_override_reason',
                           'rate_override_by', 'rate_override_at');
    IF n <> 4 THEN
        RAISE EXCEPTION 'the rate override columns were not all created (% of 4)', n;
    END IF;

    -- Nobody is moved onto a rate BY THE MIGRATION. Asserted as "the column has no
    -- default", not as "no row has one" -- every migration re-runs on every deploy, so
    -- a count of live data here would pass today and fail the first deploy after
    -- somebody legitimately agreed a rate with a client. That is the whole shape of the
    -- route_kind incident, one release later.
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'core_platform' AND table_name = 'cp_app_subscriptions'
       AND column_name LIKE 'rate_override%' AND column_default IS NOT NULL;
    IF n > 0 THEN
        RAISE EXCEPTION '% rate override column(s) have a default, so adding them '
                        're-prices existing clients', n;
    END IF;

    -- Zero must be refused, or "free" and "unset" become the same value. Asserted from
    -- the catalogue rather than by writing a probe: a probe UPDATE is the one thing in
    -- this file that could change a real client's rate, and it would do exactly that
    -- on the database where the constraint had failed to be created -- the database
    -- where the probe was most needed.
    SELECT count(*) INTO n FROM pg_constraint
     WHERE conrelid = 'core_platform.cp_app_subscriptions'::regclass
       AND conname  = 'ck_cp_app_subscriptions_rate_override'
       AND pg_get_constraintdef(oid) LIKE '%> (0)%';
    IF n <> 1 THEN
        RAISE EXCEPTION 'nothing stops a rate override of zero or below';
    END IF;

    -- The precision matters: a rate stored at two decimals cannot express 12.345, and
    -- the error is multiplied by the price on every line of every bill.
    SELECT numeric_scale INTO n FROM information_schema.columns
     WHERE table_schema = 'core_platform' AND table_name = 'cp_app_subscriptions'
       AND column_name = 'rate_override';
    IF n <> 4 THEN
        RAISE EXCEPTION 'rate_override has % decimal places, expected 4', n;
    END IF;

    RAISE NOTICE 'a client can be on an agreed rate';
END $$;
