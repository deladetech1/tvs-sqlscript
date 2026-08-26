-- 20260821-02-mystoreguard-tier-features.sql
-- Which product features each subscription tier includes, for MyStoreGuard.
--
-- Tiers are CUMULATIVE — every tier in the offer is written as "everything in the tier
-- below, plus …". So a feature needs exactly one number: the lowest tier that unlocks it.
-- A tier includes a feature when its rank >= the feature's min_tier_rank. That keeps the
-- whole offer auditable as one table instead of a per-(tier, feature) cross product that
-- has to be kept internally consistent by hand.
--
-- Ranks come from cp_subscription_platform_limits.tier_rank (20260821-01), which is the
-- single place BASIC < ADVANCE < PREMIUM < ENTERPRISE is defined.
--
-- ENTERPRISE deliberately unlocks nothing that PREMIUM does not: the difference is
-- self-hosting on client infrastructure, custom domains and bespoke work — deployment
-- concerns, not feature flags. Its higher rank means it inherits everything anyway.
--
-- Feature entitlement is resolved per (tenant, BUSINESS, app), not per tenant: app
-- subscriptions live in cp_app_subscriptions keyed on business_id, so one business can
-- run MyStoreGuard on BASIC while another under the same tenant runs PREMIUM. This is
-- the opposite of the core-platform caps, which are tenant-wide by design.
--
-- Idempotent; safe to re-run on every deploy.

SET search_path TO core_platform;

-- =====================================================================================
-- 1. The catalog. One row per gateable feature. feature_key is the contract shared by
--    the API (router dependencies) and the UI (nav filtering) — changing one is a
--    breaking change for the other.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS core_platform.cp_app_feature_catalog (
    feature_key   text        PRIMARY KEY,
    app_id        text        NOT NULL,
    title         text        NOT NULL,
    -- Lowest tier rank that unlocks this feature. 1=BASIC 2=ADVANCE 3=PREMIUM 4=ENTERPRISE.
    min_tier_rank integer     NOT NULL CHECK (min_tier_rank BETWEEN 1 AND 4),
    -- false retires a feature from gating without deleting the row: it stops appearing in
    -- cp_business_app_features, so the API and UI treat it as ungated rather than denied.
    is_active     boolean     NOT NULL DEFAULT true,
    description   text,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_cp_app_feature_catalog_app
    ON core_platform.cp_app_feature_catalog (app_id, min_tier_rank);

-- =====================================================================================
-- 2. MyStoreGuard's offer.
--
--    Rank 1 (BASIC) also carries the plumbing every tier needs — locations, currencies,
--    units of measure, alerts, file uploads. Those are not sold, they are what makes the
--    sold features work; they are listed so the gate has an explicit answer for every
--    router rather than an implicit allow.
-- =====================================================================================
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES

-- ---- BASIC ------------------------------------------------------------------------
('dashboard',                 'app-mystoreguard', 'Dashboard',                1, NULL),
('sales',                     'app-mystoreguard', 'Sales',                    1, 'The Sales module itself'),
('sales.instant',             'app-mystoreguard', 'Daily Sales',              1, 'sale_mode = INSTANT'),
('sales.on-hold',             'app-mystoreguard', 'On-hold Sales',            1, 'status = ON_HOLD'),
('sales.stats',               'app-mystoreguard', 'Sales Statistics',         1, NULL),
('inventory',                 'app-mystoreguard', 'Inventory',                1, 'The Inventory module itself'),
('inventory.products',        'app-mystoreguard', 'Products',                 1, 'The only Inventory feature on BASIC'),
('store',                     'app-mystoreguard', 'Store',                    1, 'The Store module itself'),
('store.items',               'app-mystoreguard', 'Store Items',              1, NULL),
('store.transfers',           'app-mystoreguard', 'Store Transfers',          1, NULL),
('customers',                 'app-mystoreguard', 'Customers',                1, 'A sale needs someone to sell to'),
('suppliers',                 'app-mystoreguard', 'Suppliers',                1, 'Stock has to come from somewhere'),
('reports',                   'app-mystoreguard', 'Reports',                  1, 'Module opens on every tier; individual reports are gated by the feature they report on'),
('audit-logs',                'app-mystoreguard', 'Audit Logs',               1, 'Visible on every tier; how long they are KEPT is cp_subscription_retention_defaults'),
('guide',                     'app-mystoreguard', 'Guide',                    1, 'Documentation, not a sold feature'),
('settings.tax',              'app-mystoreguard', 'Tax',                      1, NULL),
('settings.tax-rules',        'app-mystoreguard', 'Tax Rules',                1, NULL),
('settings.receipt',          'app-mystoreguard', 'Receipt Settings',         1, 'You cannot sell without being able to print a receipt'),
('locations',                 'app-mystoreguard', 'Locations',                1, 'Plumbing: how many you may create is a core-platform cap'),
('currencies',                'app-mystoreguard', 'Currencies',               1, 'Plumbing'),
('unit-of-measures',          'app-mystoreguard', 'Units of Measure',         1, 'Plumbing'),
('alerts',                    'app-mystoreguard', 'Alerts',                   1, 'Plumbing'),
('groups',                    'app-mystoreguard', 'Groups (lookup)',          1, 'Read-only list for assignment; creating groups is a core-platform entitlement'),
('file-manager',              'app-mystoreguard', 'File Uploads',             1, 'Plumbing'),

-- ---- ADVANCE ----------------------------------------------------------------------
('sales.credit',              'app-mystoreguard', 'Credit Sales',             2, 'sale_mode = CREDIT ("Creditors")'),
('sales.installment',         'app-mystoreguard', 'Installment Sales',        2, 'sale_mode = INSTALLMENT. Replaced sales.deposit — see 20260825-02'),
('inventory.product-split',   'app-mystoreguard', 'Product Split',            2, 'One key for all three split screens (inventory, store, warehouse) — they all call /products/split*'),
('inventory.purchase-orders', 'app-mystoreguard', 'Purchase Orders',          2, NULL),
('store.stock-take',          'app-mystoreguard', 'Store Stock Taking',       2, NULL),
('store.settings',            'app-mystoreguard', 'Store Settings',           2, NULL),
('warehouse',                 'app-mystoreguard', 'Warehouse',                2, 'Whole module, all sub-features'),
('invoices',                  'app-mystoreguard', 'Invoices',                 2, NULL),
('deliveries',                'app-mystoreguard', 'Deliveries',               2, NULL),
('estimator',                 'app-mystoreguard', 'Estimator',                2, 'Templates and estimates'),
('expenses',                  'app-mystoreguard', 'Expenses',                 2, NULL),
('settings.product-metadata', 'app-mystoreguard', 'Product Metadata',         2, NULL),
('settings.product-prices',   'app-mystoreguard', 'Product Pricing',          2, NULL),
('settings.pricing-rules',    'app-mystoreguard', 'Pricing Rules',            2, NULL),
('settings.price-edits',      'app-mystoreguard', 'Price Edit Settings',      2, 'Governs overriding the prices that ADVANCE pricing sets up'),
('settings.installment-policy','app-mystoreguard','Installment Policy',       2, 'Who may buy on installment, on what terms — gates the policy builder, not the sale'),

-- ---- PREMIUM ----------------------------------------------------------------------
('sales.returns',             'app-mystoreguard', 'Store Returns',            3, NULL),
('loyalty',                   'app-mystoreguard', 'Loyalty',                  3, 'Segments, points, point rules, tiers, analytics'),
('offers-rewards',            'app-mystoreguard', 'Offers & Rewards',         3, 'Gift cards, promo codes, affiliates'),
('appointments',              'app-mystoreguard', 'Appointments',             3, NULL),
('messaging',                 'app-mystoreguard', 'Messages',                 3, NULL),
('messaging.scheduling',      'app-mystoreguard', 'Message Scheduling',       3, NULL),
('workflow',                  'app-mystoreguard', 'Workflow',                 3, 'Templates, tasks, workflow settings'),
('store-credit',              'app-mystoreguard', 'Store Credit',             3, NULL),
('settings.return-policy',    'app-mystoreguard', 'Return Policy',            3, 'Store return configuration'),
('settings.store-credit',     'app-mystoreguard', 'Store Credit Settings',    3, NULL),
('redemption-mfa',            'app-mystoreguard', 'Redemption MFA',           3, 'Secures gift-card / store-credit redemption, both PREMIUM')

ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description;

-- =====================================================================================
-- 3. The tier a given business is on for a given app, and whether it still entitles them.
--    Same entitlement rules as cp_tenant_platform_limits: enterprise always, trials while
--    the tenant-wide window is open, paid tiers while the period runs.
-- =====================================================================================
CREATE OR REPLACE VIEW core_platform.cp_business_app_tier AS
SELECT aps.tenant_id,
       aps.business_id,
       aps.app_id,
       aps.shared_subscription_id             AS subscription_id,
       upper(s.subscription_name)             AS subscription_name,
       COALESCE(pl.tier_rank, 0)              AS tier_rank
FROM core_platform.cp_app_subscriptions aps
JOIN core_platform.cp_subscriptions s
  ON s.id = aps.shared_subscription_id
 AND s.delete_status = 'NOT_DELETED'
 AND s.is_active = true
LEFT JOIN core_platform.cp_subscription_platform_limits pl
  ON pl.subscription_id = aps.shared_subscription_id
LEFT JOIN core_platform.cp_tenants t
  ON t.id = aps.tenant_id
WHERE aps.delete_status = 'NOT_DELETED'
  AND aps.is_active = true
  AND (
        aps.is_enterprise = true
     OR (aps.status = 'TRIALING'
         AND (t.free_trial_ends_at IS NULL OR t.free_trial_ends_at > now()))
     OR (aps.status IN ('ACTIVE', 'PAST_DUE')
         AND aps.current_period_end IS NOT NULL
         AND aps.current_period_end > now())
  );

-- =====================================================================================
-- 4. The resolved feature set: one row per (tenant, business, app, feature the tier
--    includes). This is what the API and the UI both read.
--
--    A business with no entitled subscription produces NO rows — not an empty plan but
--    an absent one. Callers must distinguish the two: "no subscription" is already
--    handled by verify_subscription_active, which fails the request earlier with a
--    subscribe/renew message. Treating absent as "everything denied" here would replace
--    that clear message with a confusing per-feature one.
-- =====================================================================================
CREATE OR REPLACE VIEW core_platform.cp_business_app_features AS
SELECT t.tenant_id,
       t.business_id,
       t.app_id,
       t.subscription_name,
       t.tier_rank,
       f.feature_key,
       f.title
FROM core_platform.cp_business_app_tier t
JOIN core_platform.cp_app_feature_catalog f
  ON f.app_id = t.app_id
 AND f.is_active = true
 AND t.tier_rank >= f.min_tier_rank;
