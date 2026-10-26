-- =====================================================================
-- Some apps are billed once per business, not once per location
-- ---------------------------------------------------------------------
-- Until now every price in core_platform.cp_app_tier_configs was "USD per
-- location per month": the bill generator, the subscribe path, pay-ahead and
-- the hub all wrote one bill line per (subscription, deployed location).
--
-- That is right for MyStoreGuard, LoanDrift and HMS -- a shop, a
-- branch, a property each costs us and earns the client something. It is
-- wrong for the business apps: the CRM, Projects, Invoicing, Expenses and
-- Accounting work for the whole business, so the owner decided (2026-10-22)
-- they are charged ONCE per business per month however many locations the
-- business has.
--
-- core_platform.cp_apps.billing_unit says which:
--   LOCATION  one bill line per deployed location per month (the default:
--             every app that existed before this file keeps its behaviour)
--   BUSINESS  one bill line per (business, app) per month. The line carries
--             no location (location_id NULL, location_name 'All locations')
--             because it is not the price of any one of them.
--
-- The backend reads the column and treats a database without it as all
-- LOCATION, so a backend released ahead of this file bills as before.
--
-- The CHECK list lives here and nowhere else (sqlscript-migrations-rerun-
-- every-deploy): a later file that widens it replaces this one's.
--
-- Idempotent; safe to re-run on every deploy.
-- =====================================================================
BEGIN;

ALTER TABLE core_platform.cp_apps
    ADD COLUMN IF NOT EXISTS billing_unit text NOT NULL DEFAULT 'LOCATION';

ALTER TABLE core_platform.cp_apps DROP CONSTRAINT IF EXISTS ck_cp_apps_billing_unit;
ALTER TABLE core_platform.cp_apps
    ADD CONSTRAINT ck_cp_apps_billing_unit CHECK (billing_unit IN ('LOCATION', 'BUSINESS'));

COMMENT ON COLUMN core_platform.cp_apps.billing_unit IS
    'LOCATION: billed per deployed location per month. BUSINESS: billed once per (business, app) per month whatever the number of locations. Read by the bill generator, subscribe, pay-ahead and the hub.';

-- The five business apps, SCM since 20261026-01 (it runs purchasing, stock and
-- fulfilment for the whole business, however many warehouses it has) and ZelosHR since
-- 2026-10-26: the owner decided HR is a business app -- one charge per business per month,
-- whatever the number of locations its staff work at. Only rows that
-- exist are touched, so a database that has not been seeded with one of them is not an error.
UPDATE core_platform.cp_apps
   SET billing_unit = 'BUSINESS'
 WHERE id IN ('app-crm', 'app-projects', 'app-invoicing', 'app-expenses', 'app-accounting', 'app-scm', 'app-zeloshr')
   AND billing_unit IS DISTINCT FROM 'BUSINESS';

-- The per-location apps stay per location. Stated, not assumed: if somebody
-- flipped one by hand, every one of its clients would quietly start paying
-- for one location instead of all of them.
UPDATE core_platform.cp_apps
   SET billing_unit = 'LOCATION'
 WHERE id IN ('app-mystoreguard', 'app-loandrift', 'app-hms')
   AND billing_unit IS DISTINCT FROM 'LOCATION';

-- cp_app_subscriptions.price_override was documented as "per location". For a
-- BUSINESS app the agreed price is per business, the same unit as the list
-- price it replaces.
COMMENT ON COLUMN core_platform.cp_app_subscriptions.price_override IS
    'What this client agreed to pay per month for this app, in the app''s billing unit (cp_apps.billing_unit: per location, or per business). NULL = charge the tier price from cp_app_tier_configs.';

-- Invariant over this file's own work (holds at any row count).
DO $$
DECLARE
    wrong text;
BEGIN
    SELECT string_agg(id || '=' || billing_unit, ', ') INTO wrong
      FROM core_platform.cp_apps
     WHERE (id IN ('app-crm', 'app-projects', 'app-invoicing', 'app-expenses', 'app-accounting', 'app-scm', 'app-zeloshr')
            AND billing_unit <> 'BUSINESS')
        OR (id IN ('app-mystoreguard', 'app-loandrift', 'app-hms')
            AND billing_unit <> 'LOCATION');
    IF wrong IS NOT NULL THEN
        RAISE EXCEPTION 'billing_unit is wrong for: %', wrong;
    END IF;
    RAISE NOTICE 'apps billed per business: %',
        (SELECT coalesce(string_agg(id, ', ' ORDER BY id), 'none')
           FROM core_platform.cp_apps WHERE billing_unit = 'BUSINESS');
END $$;

COMMIT;
