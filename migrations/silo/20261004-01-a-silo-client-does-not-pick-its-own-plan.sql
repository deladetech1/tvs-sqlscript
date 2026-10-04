-- =====================================================================================
-- A silo client does not change its own plan.
--
-- This belongs in silo/ rather than shared/ because it is the whole test for a class
-- folder: true of a silo, false of the pool. A pooled client changing plan changes only
-- entitlements and price. A silo client changing plan changes neither their database nor
-- their server -- so selecting BASIC, which is pooled-only by design, leaves them using
-- a dedicated database at the shared price, with nothing to reconcile the two.
--
-- Moving a client between hosting classes is a provisioning job and sometimes a data
-- migration (general/tvs-iac, .github/workflows/silos.yml). It cannot be a click, so the
-- request goes through us: the console already has the hosting-request pipeline for
-- exactly this shape.
--
-- EVERY TENANT IN THIS DATABASE, not a named one. A silo database holds one tenant (see
-- 00010101-01), and if it somehow holds more they are all silo tenants -- so there is no
-- id to get wrong and nothing to keep in step when a silo is renamed.
--
-- RE-RUN SAFE. Every migration runs on every deploy, so this re-asserts rather than
-- toggles: an operator who deliberately granted a silo client self-service for an
-- afternoon will find it closed again on the next deploy. That is the intended
-- direction -- the exception should be the thing that expires, not the rule.
-- =====================================================================================

DO $$
DECLARE n integer;
BEGIN
    IF to_regclass('core_platform.cp_tenants') IS NULL THEN
        RAISE NOTICE 'cp_tenants does not exist yet; nothing to close';
        RETURN;
    END IF;

    -- The column arrives in shared/20261004-08, which sorts earlier and therefore runs
    -- first. Guarded anyway: a silo that is one release behind must not fail its whole
    -- deploy over a column it has not been given yet.
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'core_platform' AND table_name = 'cp_tenants'
           AND column_name = 'self_service_plan_changes'
    ) THEN
        RAISE NOTICE 'self_service_plan_changes does not exist here yet; skipping';
        RETURN;
    END IF;

    UPDATE core_platform.cp_tenants
       SET self_service_plan_changes = false
     WHERE self_service_plan_changes;
    GET DIAGNOSTICS n = ROW_COUNT;

    IF n > 0 THEN
        RAISE NOTICE 'silo: closed self-service plan changes for % tenant(s)', n;
    END IF;

    -- And prove it, rather than trusting the UPDATE's WHERE clause.
    SELECT count(*) INTO n FROM core_platform.cp_tenants
     WHERE self_service_plan_changes
       AND delete_status = 'NOT_DELETED';
    IF n > 0 THEN
        RAISE EXCEPTION '% tenant(s) in this silo can still change their own plan', n;
    END IF;
END $$;
