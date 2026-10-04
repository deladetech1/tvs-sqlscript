-- =====================================================================================
-- Whether a tenant may change its own subscription plan.
--
-- WHY THIS IS NEEDED AT ALL
-- PUT /api/v1/subscriptions/update lets a tenant move a (business, app) between BASIC,
-- ADVANCE and PREMIUM. For a POOLED client that is exactly right: nothing about their
-- hosting changes, only what they are entitled to and what they pay, and making them
-- ask us for a cheaper plan would be rude.
--
-- For a SILO client it is wrong, and quietly so. A silo client who selects BASIC keeps
-- their own database -- nothing in the code moves them, and BASIC is pooled-only by
-- design -- so they go on using a dedicated database while paying the shared price. The
-- plan and the hosting now contradict each other and nothing reconciles them. It is not
-- a billing bug, which somebody would notice; it is an incoherence, which nobody does.
--
-- WHY A COLUMN AND NOT A LOOK-UP OF THE TIER
-- The honest answer to "is this a silo?" is ctl_tenant_routes.tier -- but the
-- AUTHORITATIVE copy of that table is in the POOLED database, and the tenant API
-- deliberately never reads control_plane at all (zero references in app/src). A silo's
-- own database has the table from shared/ but no reason to have correct rows in it, so
-- a silo asking itself what tier it is would get a confident wrong answer.
--
-- So the fact is recorded where the tenant lives, by the only thing that knows: the
-- deploy that provisioned the silo. See migrations/silo/ for the other half.
--
-- WHY THE DEFAULT IS true
-- Because the pool is the common case and a new pooled tenant should be able to manage
-- its own plan. The silo half of this is a migration that runs on every silo database,
-- so a silo cannot end up with the pooled default by being forgotten -- it would have to
-- be forgotten by the migration runner, which discovers its targets from the route
-- table rather than from a list.
--
-- An ENTERPRISE install is deliberately NOT addressed here. It is self-hosted: they own
-- the database, so a flag we set is a suggestion they can UPDATE away, and their plan
-- changes bill nothing because their subscriptions are WAIVED. Pretending to enforce
-- something unenforceable is worse than saying plainly that it is a contract matter.
-- =====================================================================================

ALTER TABLE core_platform.cp_tenants
    ADD COLUMN IF NOT EXISTS self_service_plan_changes boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN core_platform.cp_tenants.self_service_plan_changes IS
    'May this tenant change its own subscription plan? True for pooled clients. False '
    'for silo clients, because a plan change there implies a hosting change and '
    'sometimes a data migration, neither of which a self-service click can do. Set '
    'false by migrations/silo/, which runs on every silo database.';

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer;
BEGIN
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'core_platform' AND table_name = 'cp_tenants'
       AND column_name = 'self_service_plan_changes';
    IF n <> 1 THEN
        RAISE EXCEPTION 'self_service_plan_changes was not created';
    END IF;

    -- NOT NULL with a default, so "is this allowed" can never be a three-valued
    -- answer. A NULL here would read as false in some languages and true in others,
    -- and the two readings differ by whether a customer can re-price themselves.
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'core_platform' AND table_name = 'cp_tenants'
       AND column_name = 'self_service_plan_changes'
       AND (is_nullable <> 'NO' OR column_default IS NULL);
    IF n > 0 THEN
        RAISE EXCEPTION 'self_service_plan_changes is nullable or has no default';
    END IF;

    RAISE NOTICE 'tenants record whether they may change their own plan';
END $$;
