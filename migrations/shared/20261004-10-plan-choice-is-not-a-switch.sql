-- =====================================================================================
-- cp_tenants.self_service_plan_changes is removed.
--
-- WHY IT EXISTED AND WHY IT IS WRONG
-- 20261004-08 added it to stop a SILO client choosing their own plan, because their plan
-- and their hosting are one arrangement: selecting a pooled-only tier left them on a
-- dedicated database at the shared price, with nothing to reconcile the two.
--
-- The problem was real. The answer was not. Taking plan choice away entirely meant
-- somebody else had to make it for them, which meant a console flow to deploy apps on
-- their behalf -- a second way to do something the product already does, maintained
-- separately, for the sake of a restriction nobody wanted.
--
-- The right answer is narrower: a silo client picks their own plan, from the plans a
-- silo client may be on. BASIC is pooled-only, so it is not offered; the free trial is
-- not offered either, because a silo is paid-for infrastructure standing idle. A
-- self-hosted install is offered ENTERPRISE and nothing else.
--
-- That rule lives in the application, derived from the ROUTE's tier -- which is a fact
-- about the request, available through the tenancy middleware, and not a flag anybody
-- has to remember to set. A per-tenant column could always disagree with the route it
-- was supposed to describe; a derived rule cannot.
--
-- IF EXISTS because the column never existed on a database provisioned after
-- 20261004-08 was deleted, and every migration runs on every deploy.
-- =====================================================================================

ALTER TABLE core_platform.cp_tenants
    DROP COLUMN IF EXISTS self_service_plan_changes;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'core_platform' AND table_name = 'cp_tenants'
           AND column_name = 'self_service_plan_changes'
    ) THEN
        RAISE EXCEPTION 'self_service_plan_changes is still there';
    END IF;
    RAISE NOTICE 'plan choice is a rule, not a column';
END $$;
