-- =====================================================================
-- The Finance bundle: Invoicing + Expenses + Accounting in ONE subscription
-- ---------------------------------------------------------------------
-- Owner's decision (2026-10-22): the three finance apps can be bought
-- together, per BUSINESS per month, USD at rate 12.0 GHS/USD:
--
--     plan       bundle   the three separately (10+15+25 / 20+30+50 / 35+60+90)
--     BASIC        40       50
--     ADVANCE      80      100
--     PREMIUM     150      185
--     ENTERPRISE  quote    (self-hosted, whole-suite quote: never a hosted pick)
--
-- Each member app keeps its own tier's max_login_users.
--
-- THE MODEL
--
--   cp_bundles               the catalogue (global, like cp_apps)
--   cp_bundle_apps           which apps a bundle holds (an app is in at most ONE)
--   cp_bundle_tier_configs   the bundle's price and rate per plan
--                            (NULL price = by quote: ENTERPRISE)
--   cp_bundle_subscriptions  one per (tenant, business, bundle) while live
--
-- The three member apps keep their OWN cp_app_subscriptions rows -- created
-- or kept exactly as a single-app subscription is -- and point at the bundle
-- through cp_app_subscriptions.bundle_subscription_id. So entitlement
-- (cp_business_app_tier), the plan features, the seat caps and the access
-- gate do not change at all: they read the member rows, which sit on the
-- bundle's plan and carry the paid-up period.
--
-- BILLING: while a bundle is live (status not DISSOLVED/CANCELLED) its members
-- are never billed on their own. The bundle is billed ONE line per business
-- per period: line_type 'BUNDLE', app_id NULL, location NULL ('All
-- locations'), cp_billings_logs.bundle_subscription_id set, price and rate
-- snapshotted like every other line (COALESCE(price_override, tier price)).
-- Paying that line extends every member's period, each from where it is paid
-- up to (so an app that joined with paid time left keeps it).
--
-- LEAVING: unsubscribing one member, or "leave the bundle", DISSOLVES it.
-- The members keep their periods and their pointer (so a bundle line still
-- unpaid at that moment extends them when it is paid) and are billed on their
-- own, at their own list price, from their next period. No discount lingers.
--
-- JOINING WITH APPS ALREADY SUBSCRIBED: no money maths is invented. A plan
-- change today is not prorated (the next bill is at the new price), and the
-- same rule applies here: a member's paid-up period is kept as it is; any
-- member bill not yet paid at all is withdrawn (delete_status DELETED) and the
-- bundle line covers that period instead. A bundle line is raised at once only
-- if some member is not covered today; otherwise the first bundle bill comes
-- when the earliest member's period ends.
--
-- Every member app must be billed per BUSINESS (cp_apps.billing_unit): a
-- bundle line carries no location, so a per-location member would be
-- under-billed. Asserted below.
--
-- CHECK lists here are owned by THIS file (sqlscript-migrations-rerun-every-
-- deploy): a later file that changes one replaces it, never repeats it.
--
-- Prices are seeded here, not in the CorePlatform seed: the seed runs BEFORE
-- migrations/shared, so on a fresh database these tables do not exist yet
-- when it runs. This file is the authority for the bundle's list prices.
--
-- Idempotent; safe to re-run.
-- =====================================================================
BEGIN;

-- ------------------------------------------------------------ catalogue
CREATE TABLE IF NOT EXISTS core_platform.cp_bundles (
    id            text PRIMARY KEY,
    bundle_name   text NOT NULL,
    description   text,
    sort_order    integer NOT NULL DEFAULT 0,
    is_active     boolean NOT NULL DEFAULT true,
    delete_status text NOT NULL DEFAULT 'NOT_DELETED',
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz
);
COMMENT ON TABLE core_platform.cp_bundles IS
    'Apps sold together in one subscription per business (e.g. the Finance bundle). Global catalogue, like cp_apps.';

CREATE TABLE IF NOT EXISTS core_platform.cp_bundle_apps (
    bundle_id  text NOT NULL REFERENCES core_platform.cp_bundles(id) ON DELETE CASCADE,
    app_id     text NOT NULL REFERENCES core_platform.cp_apps(id) ON DELETE RESTRICT,
    sort_order integer NOT NULL DEFAULT 0,
    cdatetime  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (bundle_id, app_id)
);
-- An app is in at most one bundle, so "the bundle this app belongs to" has
-- exactly one answer everywhere it is asked.
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_bundle_apps_app_id
    ON core_platform.cp_bundle_apps (app_id);
COMMENT ON TABLE core_platform.cp_bundle_apps IS
    'The apps in a bundle. An app is in at most one bundle (ux_cp_bundle_apps_app_id).';

CREATE TABLE IF NOT EXISTS core_platform.cp_bundle_tier_configs (
    id              text PRIMARY KEY,
    bundle_id       text NOT NULL REFERENCES core_platform.cp_bundles(id) ON DELETE CASCADE,
    subscription_id text NOT NULL REFERENCES core_platform.cp_subscriptions(id) ON DELETE RESTRICT,
    price           numeric(12,2),
    rate            numeric(12,4) NOT NULL DEFAULT 12.0,
    is_active       boolean NOT NULL DEFAULT true,
    delete_status   text NOT NULL DEFAULT 'NOT_DELETED',
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_bundle_tier_configs_bundle_tier
    ON core_platform.cp_bundle_tier_configs (bundle_id, subscription_id);
ALTER TABLE core_platform.cp_bundle_tier_configs
    DROP CONSTRAINT IF EXISTS ck_cp_bundle_tier_configs_price;
ALTER TABLE core_platform.cp_bundle_tier_configs
    ADD CONSTRAINT ck_cp_bundle_tier_configs_price CHECK (price IS NULL OR price >= 0);
ALTER TABLE core_platform.cp_bundle_tier_configs
    DROP CONSTRAINT IF EXISTS ck_cp_bundle_tier_configs_rate;
ALTER TABLE core_platform.cp_bundle_tier_configs
    ADD CONSTRAINT ck_cp_bundle_tier_configs_rate CHECK (rate > 0);
COMMENT ON COLUMN core_platform.cp_bundle_tier_configs.price IS
    'USD per business per month for the whole bundle on this plan. NULL = by quote (ENTERPRISE): never a hosted pick.';
COMMENT ON COLUMN core_platform.cp_bundle_tier_configs.rate IS
    'Local currency per USD (12.0 = GHS). Snapshotted onto every bundle bill line.';

-- ------------------------------------------------------- subscriptions
CREATE TABLE IF NOT EXISTS core_platform.cp_bundle_subscriptions (
    id                     text PRIMARY KEY
                           DEFAULT ('bsub_' || replace(gen_random_uuid()::text, '-', '')),
    tenant_id              text NOT NULL
                           REFERENCES core_platform.cp_tenants(id) ON DELETE CASCADE,
    business_id            text NOT NULL,
    bundle_id              text NOT NULL
                           REFERENCES core_platform.cp_bundles(id) ON DELETE RESTRICT,
    shared_subscription_id text NOT NULL
                           REFERENCES core_platform.cp_subscriptions(id) ON DELETE RESTRICT,
    status                 text NOT NULL,
    is_enterprise          boolean NOT NULL DEFAULT false,
    current_period_start   timestamptz,
    current_period_end     timestamptz,
    next_charge_date       timestamptz,
    price_override         numeric(12,2),
    price_override_reason  text,
    price_override_by      text,
    price_override_at      timestamptz,
    rate_override          numeric(12,4),
    rate_override_reason   text,
    rate_override_by       text,
    rate_override_at       timestamptz,
    dissolved_at           timestamptz,
    dissolved_by           text,
    dissolved_reason       text,
    is_active              boolean NOT NULL DEFAULT true,
    delete_status          text NOT NULL DEFAULT 'NOT_DELETED',
    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz NOT NULL DEFAULT now(),
    created_by             text,
    updated_at             timestamptz,
    updated_by             text,
    CONSTRAINT fk_cp_bundle_subscriptions_business
        FOREIGN KEY (business_id, tenant_id)
        REFERENCES core_platform.cp_businesses(id, tenant_id) ON DELETE CASCADE
);
COMMENT ON TABLE core_platform.cp_bundle_subscriptions IS
    'One bundle bought by one business. Members are the cp_app_subscriptions whose bundle_subscription_id points here. Live while status is not DISSOLVED/CANCELLED; members of a live bundle are billed only through the bundle''s BUNDLE line.';
COMMENT ON COLUMN core_platform.cp_bundle_subscriptions.price_override IS
    'What this client agreed to pay per month for the whole bundle (per business). NULL = cp_bundle_tier_configs.price.';
COMMENT ON COLUMN core_platform.cp_bundle_subscriptions.current_period_end IS
    'Paid up to, for the bundle as a whole: when its next BUNDLE line is due. Each member also keeps its own (an app that joined with paid time left stays ahead).';

ALTER TABLE core_platform.cp_bundle_subscriptions
    DROP CONSTRAINT IF EXISTS ck_cp_bundle_subscriptions_status;
ALTER TABLE core_platform.cp_bundle_subscriptions
    ADD CONSTRAINT ck_cp_bundle_subscriptions_status CHECK (status IN
        ('TRIALING', 'ACTIVE', 'PENDING_PAYMENT', 'PAST_DUE', 'DISSOLVED', 'CANCELLED'));
ALTER TABLE core_platform.cp_bundle_subscriptions
    DROP CONSTRAINT IF EXISTS ck_cp_bundle_subscriptions_price_override;
ALTER TABLE core_platform.cp_bundle_subscriptions
    ADD CONSTRAINT ck_cp_bundle_subscriptions_price_override
        CHECK (price_override IS NULL OR price_override >= 0);
ALTER TABLE core_platform.cp_bundle_subscriptions
    DROP CONSTRAINT IF EXISTS ck_cp_bundle_subscriptions_rate_override;
ALTER TABLE core_platform.cp_bundle_subscriptions
    ADD CONSTRAINT ck_cp_bundle_subscriptions_rate_override
        CHECK (rate_override IS NULL OR rate_override > 0);
ALTER TABLE core_platform.cp_bundle_subscriptions
    DROP CONSTRAINT IF EXISTS ck_cp_bundle_subscriptions_delete_status;
ALTER TABLE core_platform.cp_bundle_subscriptions
    ADD CONSTRAINT ck_cp_bundle_subscriptions_delete_status
        CHECK (delete_status IN ('PENDING', 'DELETED', 'NOT_DELETED'));

-- One LIVE bundle of a kind per business. A dissolved one stays as history.
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_bundle_subscriptions_live
    ON core_platform.cp_bundle_subscriptions (tenant_id, business_id, bundle_id)
 WHERE status NOT IN ('DISSOLVED', 'CANCELLED') AND delete_status = 'NOT_DELETED';
CREATE INDEX IF NOT EXISTS ix_cp_bundle_subscriptions_tenant
    ON core_platform.cp_bundle_subscriptions (tenant_id, status);

-- ----------------------------------------------- members point at the bundle
ALTER TABLE core_platform.cp_app_subscriptions
    ADD COLUMN IF NOT EXISTS bundle_subscription_id text;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conrelid = 'core_platform.cp_app_subscriptions'::regclass
           AND conname = 'fk_cp_app_subscriptions_bundle_subscription'
    ) THEN
        -- Single column, so SET NULL nulls only this column (a composite key
        -- with tenant_id would null tenant_id too, which is NOT NULL).
        ALTER TABLE core_platform.cp_app_subscriptions
            ADD CONSTRAINT fk_cp_app_subscriptions_bundle_subscription
            FOREIGN KEY (bundle_subscription_id)
            REFERENCES core_platform.cp_bundle_subscriptions(id) ON DELETE SET NULL;
    END IF;
END $$;
CREATE INDEX IF NOT EXISTS ix_cp_app_subscriptions_bundle
    ON core_platform.cp_app_subscriptions (bundle_subscription_id)
 WHERE bundle_subscription_id IS NOT NULL;
COMMENT ON COLUMN core_platform.cp_app_subscriptions.bundle_subscription_id IS
    'The bundle this app was bought in. While that bundle is live this subscription is billed only through the bundle; once it is DISSOLVED the pointer stays (history, and so an unpaid bundle line still extends it) and the app is billed on its own again.';

-- ------------------------------------------------- the bundle's bill line
-- line_type has never been constrained (shared/20261004-11), so BUNDLE needs
-- no CHECK change. The line names no app and no location.
ALTER TABLE core_platform.cp_billings_logs
    ADD COLUMN IF NOT EXISTS bundle_subscription_id text;
CREATE INDEX IF NOT EXISTS ix_cp_billings_logs_bundle
    ON core_platform.cp_billings_logs (tenant_id, bundle_subscription_id)
 WHERE bundle_subscription_id IS NOT NULL;
COMMENT ON COLUMN core_platform.cp_billings_logs.bundle_subscription_id IS
    'Set on a BUNDLE line: the bundle subscription it bills. Paying it extends every member app subscription pointing at that bundle.';

-- ------------------------------------------------------------- the seed
INSERT INTO core_platform.cp_bundles (id, bundle_name, description, sort_order)
VALUES ('bundle-finance', 'Finance bundle',
        'Invoicing, Expenses and Accounting together in one subscription per business, for less than the three apps separately.',
        1)
ON CONFLICT (id) DO UPDATE
   SET bundle_name = EXCLUDED.bundle_name,
       description = EXCLUDED.description,
       sort_order  = EXCLUDED.sort_order,
       updated_at  = now()
 WHERE (core_platform.cp_bundles.bundle_name, core_platform.cp_bundles.description,
        core_platform.cp_bundles.sort_order)
       IS DISTINCT FROM (EXCLUDED.bundle_name, EXCLUDED.description, EXCLUDED.sort_order);

-- Only the apps that exist here: the app rows come from the CorePlatform seed,
-- and a shared file must not require a module seed.
INSERT INTO core_platform.cp_bundle_apps (bundle_id, app_id, sort_order)
SELECT 'bundle-finance', v.app_id, v.ord
  FROM (VALUES ('app-invoicing', 1), ('app-expenses', 2), ('app-accounting', 3)) AS v(app_id, ord)
 WHERE EXISTS (SELECT 1 FROM core_platform.cp_apps a WHERE a.id = v.app_id)
ON CONFLICT (bundle_id, app_id) DO UPDATE SET sort_order = EXCLUDED.sort_order;

INSERT INTO core_platform.cp_bundle_tier_configs (id, bundle_id, subscription_id, price, rate)
SELECT v.id, 'bundle-finance', v.sub, v.price, v.rate
  FROM (VALUES ('bundle-cfg-finance-basic',      'shared-subscription-basic',       40.00::numeric, 12.0::numeric),
               ('bundle-cfg-finance-advance',    'shared-subscription-advance',     80.00::numeric, 12.0::numeric),
               ('bundle-cfg-finance-premium',    'shared-subscription-premium',    150.00::numeric, 12.0::numeric),
               ('bundle-cfg-finance-enterprise', 'shared-subscription-enterprise', NULL::numeric,  12.0::numeric))
       AS v(id, sub, price, rate)
 WHERE EXISTS (SELECT 1 FROM core_platform.cp_subscriptions s WHERE s.id = v.sub)
ON CONFLICT (id) DO UPDATE
   SET price = EXCLUDED.price,
       rate = EXCLUDED.rate,
       is_active = true,
       delete_status = 'NOT_DELETED',
       updated_at = now()
 WHERE (core_platform.cp_bundle_tier_configs.price, core_platform.cp_bundle_tier_configs.rate,
        core_platform.cp_bundle_tier_configs.is_active, core_platform.cp_bundle_tier_configs.delete_status)
       IS DISTINCT FROM (EXCLUDED.price, EXCLUDED.rate, true, 'NOT_DELETED');

-- ----------------------------------------------------------- invariants
-- Structural: about this file's own work, at any row count.
DO $$
DECLARE
    wrong text;
BEGIN
    -- A bundle line carries no location, so a member billed per location
    -- would be under-billed by every location past the first.
    SELECT string_agg(ba.bundle_id || ':' || ba.app_id || '=' || a.billing_unit, ', ')
      INTO wrong
      FROM core_platform.cp_bundle_apps ba
      JOIN core_platform.cp_apps a ON a.id = ba.app_id
     WHERE a.billing_unit <> 'BUSINESS';
    IF wrong IS NOT NULL THEN
        RAISE EXCEPTION 'bundle members must be billed per BUSINESS: %', wrong;
    END IF;

    -- ENTERPRISE is a quote, never a list price on a bundle; the hosted plans
    -- always have one.
    SELECT string_agg(c.id, ', ') INTO wrong
      FROM core_platform.cp_bundle_tier_configs c
      JOIN core_platform.cp_subscriptions s ON s.id = c.subscription_id
     WHERE c.is_active AND c.delete_status = 'NOT_DELETED'
       AND ((upper(s.subscription_name) = 'ENTERPRISE' AND c.price IS NOT NULL)
         OR (upper(s.subscription_name) <> 'ENTERPRISE' AND c.price IS NULL));
    IF wrong IS NOT NULL THEN
        RAISE EXCEPTION 'bundle prices: ENTERPRISE must be NULL (quote), hosted plans must be priced: %', wrong;
    END IF;
END $$;

-- About live data: reported, never a reason to stop every later migration.
DO $$
DECLARE
    n integer;
BEGIN
    -- A member must belong to the same tenant and business as its bundle, and
    -- its app must be one the bundle holds.
    SELECT count(*) INTO n
      FROM core_platform.cp_app_subscriptions s
      JOIN core_platform.cp_bundle_subscriptions bs ON bs.id = s.bundle_subscription_id
     WHERE bs.tenant_id <> s.tenant_id
        OR bs.business_id <> s.business_id
        OR NOT EXISTS (SELECT 1 FROM core_platform.cp_bundle_apps ba
                        WHERE ba.bundle_id = bs.bundle_id AND ba.app_id = s.app_id);
    IF n > 0 THEN
        RAISE WARNING '% app subscription(s) point at a bundle of another tenant, business or set of apps', n;
    END IF;

    -- Members of a LIVE bundle sit on the bundle's plan.
    SELECT count(*) INTO n
      FROM core_platform.cp_app_subscriptions s
      JOIN core_platform.cp_bundle_subscriptions bs ON bs.id = s.bundle_subscription_id
     WHERE bs.status NOT IN ('DISSOLVED', 'CANCELLED')
       AND s.delete_status = 'NOT_DELETED'
       AND s.shared_subscription_id <> bs.shared_subscription_id;
    IF n > 0 THEN
        RAISE WARNING '% member(s) of a live bundle are not on the bundle''s plan', n;
    END IF;

    RAISE NOTICE 'bundles: %; live bundle subscriptions: %',
        (SELECT coalesce(string_agg(b.id || '(' || (SELECT count(*) FROM core_platform.cp_bundle_apps ba WHERE ba.bundle_id = b.id) || ' apps)', ', '), 'none')
           FROM core_platform.cp_bundles b),
        (SELECT count(*) FROM core_platform.cp_bundle_subscriptions
          WHERE status NOT IN ('DISSOLVED', 'CANCELLED'));
END $$;

COMMIT;
