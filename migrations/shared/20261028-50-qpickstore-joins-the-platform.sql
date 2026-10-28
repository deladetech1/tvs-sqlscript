-- QPickStore joins the platform: MyStoreGuard's ecommerce, sold as its own add-on app.
--
-- Owner, 2026-10-28: the storefront (shop-owner screens: overview, setup, appearance, pages,
-- products, pricing, auctions, coins) is its own app, QPickStore, with its own subscription
-- priced per business in the console. It is an ADD-ON: a business can only hold it alongside
-- MyStoreGuard, because underneath it uses MyStoreGuard's products, stock and sales -- an
-- online order is a sale on MyStoreGuard's Sales page, never a second stock. MyStoreGuard
-- Premium no longer includes the storefront. The shopper site (tvs-commerce-ft) is unchanged.
--
-- Served by the MyStoreGuard API and frontend (opened as QPickStore from the hub's /switch);
-- no new backend, host or route. This file holds:
--
--   * cp_apps.requires_app_id: the add-on rule, for Core Platform to enforce on subscribe
--     (no QPickStore without an active MyStoreGuard for the same business);
--   * the app row, billed per BUSINESS, and its tier rows -- INSERT ONLY: a row that exists
--     keeps its price, rate and seats, because the console owns list prices
--     (shared/20261023-30). The starting prices are PLACEHOLDERS for the owner to set there;
--   * its resource type and job roles. Its screens are guarded by MyStoreGuard's own
--     ecommerce permissions (msg|ecommerce|*), so the roles carry those and the few
--     MyStoreGuard reads a shop owner needs (products, prices, online orders); the roles are
--     named role-qpickstore-* and the cross-app check (20260929-11) maps that prefix to msg;
--   * which features each tier includes (all of them: tiers differ by seats);
--   * ONCE per database, recorded in core_platform.cp_migration_decisions: every business
--     whose MyStoreGuard plan includes ecommerce today gets a QPickStore subscription on the
--     same tier, status and period, deployed where its MyStoreGuard is, so nobody loses a
--     live storefront. A re-run (every deploy) never re-subscribes a business that later
--     leaves QPickStore. created_by stays NULL on those rows (it is a foreign key to cp_users);
--     they are marked by their description and by the decision row.
--
-- MyStoreGuard's catalogue keeps its ecommerce keys (the UI's padlock contract); the API
-- opens them from the QPickStore subscription once app-qpickstore exists here
-- (tvs-mystoreguard-bk c69b937, src/utils/feature_gate.py).
-- Nothing here asserts on rows a module seed creates. Idempotent; safe to re-run.

BEGIN;

-- ======================================================================= add-on rule
ALTER TABLE core_platform.cp_apps ADD COLUMN IF NOT EXISTS requires_app_id text;
COMMENT ON COLUMN core_platform.cp_apps.requires_app_id IS
    'An add-on: a business may only subscribe to this app while it holds an active subscription to that one (QPickStore -> MyStoreGuard). NULL for a standalone app.';

-- ====================================================================== the app row
INSERT INTO core_platform.cp_apps (id, app_name, feature1, feature2, feature3, feature4, feature5,
                                   description, cdate, ctime, cdatetime, status, is_active)
VALUES ('app-qpickstore', 'QPICKSTORE', 'Online Storefront', 'Pages & Appearance', 'Online Prices',
        'Auctions & Coins', 'Orders on Your Sales Page',
        'Sell online from your MyStoreGuard stock: your own storefront, pages, online prices, auctions and coins, with every order landing on your MyStoreGuard Sales page',
        CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'live', true)
ON CONFLICT (id) DO NOTHING;

UPDATE core_platform.cp_apps
   SET requires_app_id = 'app-mystoreguard'
 WHERE id = 'app-qpickstore' AND requires_app_id IS DISTINCT FROM 'app-mystoreguard';

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'core_platform' AND table_name = 'cp_apps' AND column_name = 'billing_unit') THEN
        UPDATE core_platform.cp_apps SET billing_unit = 'BUSINESS'
         WHERE id = 'app-qpickstore' AND billing_unit IS DISTINCT FROM 'BUSINESS';
    END IF;
END $$;

-- Starting values only (USD per business per month, seats in the 4th column). The console
-- (Billing > Price list) owns them from here on; a row that exists is never touched.
INSERT INTO core_platform.cp_app_tier_configs (id, app_id, subscription_id, max_login_users, price, rate, cdate, ctime, cdatetime) VALUES
('tier-cfg-qps-basic',      'app-qpickstore', 'shared-subscription-basic',       3,   20.00, 12.0, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP),
('tier-cfg-qps-advance',    'app-qpickstore', 'shared-subscription-advance',    10,   45.00, 12.0, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP),
('tier-cfg-qps-premium',    'app-qpickstore', 'shared-subscription-premium',    25,   90.00, 12.0, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP),
('tier-cfg-qps-enterprise', 'app-qpickstore', 'shared-subscription-enterprise', NULL, 3000.00, 12.0, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO NOTHING;

-- ============================================================== resource type and roles
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-subscribed-app-qpickstore', 'QPICKSTORE APP', 'QPickStore Subscribed APP', NULL)
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description;

-- role_name is unique per tenant across every app, so every name starts with "QPickStore".
INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-qpickstore-manager', 'system-tenant-id', 'QPickStore Manager', 'Runs the online store: storefront, pages, appearance, online prices, auctions and coins, and sees online orders', 'rt-system-role', true, true, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP),
('role-qpickstore-viewer',  'system-tenant-id', 'QPickStore Viewer',  'Reads the online store and its orders; changes nothing', 'rt-system-role', true, true, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name        = EXCLUDED.role_name,
                               description      = EXCLUDED.description,
                               resource_type_id = EXCLUDED.resource_type_id,
                               is_system        = EXCLUDED.is_system,
                               is_active        = EXCLUDED.is_active;

-- The screens are MyStoreGuard's ecommerce module, guarded by msg|ecommerce|*; a shop owner
-- also reads the catalogue it sells from and the online orders on the Sales page, and keeps
-- the ECOMMERCE channel's prices. Only permissions that exist here are granted.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(coalesce(p.description, p.permission_name)),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (VALUES
        ('role-qpickstore-manager', 'permission-msg-ecommerce-get'),
        ('role-qpickstore-manager', 'permission-msg-ecommerce-create'),
        ('role-qpickstore-manager', 'permission-msg-ecommerce-update'),
        ('role-qpickstore-manager', 'permission-msg-ecommerce-delete'),
        ('role-qpickstore-manager', 'permission-msg-store-sales-get'),
        ('role-qpickstore-manager', 'permission-msg-products-get'),
        ('role-qpickstore-manager', 'permission-msg-product-metadata-get'),
        ('role-qpickstore-manager', 'permission-msg-product-price-get'),
        ('role-qpickstore-manager', 'permission-msg-product-price-create'),
        ('role-qpickstore-manager', 'permission-msg-product-price-update'),
        ('role-qpickstore-manager', 'permission-msg-pricing-rules-get'),
        ('role-qpickstore-manager', 'permission-msg-pricing-rules-create'),
        ('role-qpickstore-manager', 'permission-msg-pricing-rules-update'),
        ('role-qpickstore-manager', 'permission-msg-customers-get'),
        ('role-qpickstore-viewer',  'permission-msg-ecommerce-get'),
        ('role-qpickstore-viewer',  'permission-msg-store-sales-get'),
        ('role-qpickstore-viewer',  'permission-msg-products-get')
       ) AS spec(role_id, permission_id)
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p ON p.id = spec.permission_id AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- The core-platform navigation block every app role seeds for itself.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', r.id, p.id
  FROM core_platform.cp_roles r
  JOIN core_platform.cp_permissions p
    ON p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations',
                'permission-user-get-locations')
 WHERE r.id IN ('role-qpickstore-manager', 'role-qpickstore-viewer')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ========================================================== features per tier
-- Every tier includes the whole storefront: QPickStore's tiers differ by seats, like the
-- one gate MyStoreGuard always had on it ("is there a storefront at all"). Listed for the
-- hub's plan comparison; the API opens MyStoreGuard's ecommerce.* keys from the subscription.
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('qpickstore.storefront', 'app-qpickstore', 'Online Storefront',   1, 'Your own shop address, products and pictures from your MyStoreGuard stock'),
('qpickstore.pages',      'app-qpickstore', 'Pages & Appearance',  1, 'Home, Pre-used and Market pages with versions, promotion and your own look'),
('qpickstore.pricing',    'app-qpickstore', 'Online Prices',       1, 'Prices and pricing rules for the online channel'),
('qpickstore.auctions',   'app-qpickstore', 'Auctions & Coins',    1, 'Timed auctions and coin packages for bidding'),
('qpickstore.orders',     'app-qpickstore', 'Orders on Your Sales Page', 1, 'Every online order is a sale on your MyStoreGuard Sales page, from the same stock')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

-- ============================================== who keeps their storefront (once per database)
CREATE TABLE IF NOT EXISTS core_platform.cp_migration_decisions (
    decision_key text PRIMARY KEY,
    applied_at   timestamptz NOT NULL DEFAULT now(),
    detail       jsonb NOT NULL DEFAULT '{}'
);
COMMENT ON TABLE core_platform.cp_migration_decisions IS
    'One row per one-off data decision a migration applied in THIS database, so a file that re-runs every deploy applies it once (e.g. qpickstore-entitlement@20261028).';

DO $$
DECLARE
    v_key  text := 'qpickstore-entitlement@20261028';
    v_subs int := 0;
    v_locs int := 0;
BEGIN
    IF EXISTS (SELECT 1 FROM core_platform.cp_migration_decisions WHERE decision_key = v_key) THEN
        RETURN;
    END IF;
    -- A database without the plan views (MyStoreGuard's tier features never installed) has no
    -- one whose plan includes ecommerce: record nothing, so it is decided when they arrive.
    IF to_regclass('core_platform.cp_business_app_features') IS NULL THEN
        RETURN;
    END IF;

    CREATE TEMP TABLE _qps_keep ON COMMIT DROP AS
    SELECT DISTINCT ON (s.tenant_id, s.business_id)
           s.tenant_id, s.business_id, s.shared_subscription_id, s.status, s.is_enterprise,
           s.is_payment_required, s.current_period_start, s.current_period_end, s.next_charge_date,
           'busapp_qps_' || md5(s.tenant_id || ':' || s.business_id) AS business_app_id
      FROM core_platform.cp_business_app_features f
      JOIN core_platform.cp_app_subscriptions s
        ON s.tenant_id = f.tenant_id AND s.business_id = f.business_id
       AND s.app_id = 'app-mystoreguard' AND s.delete_status = 'NOT_DELETED' AND s.is_active = true
     WHERE f.app_id = 'app-mystoreguard' AND f.feature_key = 'ecommerce'
       AND NOT EXISTS (SELECT 1 FROM core_platform.cp_app_subscriptions q
                        WHERE q.tenant_id = s.tenant_id AND q.business_id = s.business_id
                          AND q.app_id = 'app-qpickstore' AND q.delete_status = 'NOT_DELETED')
     ORDER BY s.tenant_id, s.business_id, s.cdatetime DESC;

    INSERT INTO core_platform.cp_business_apps (id, tenant_id, bus_id, app_id, description, cdate, ctime, cdatetime, created_by)
    SELECT k.business_app_id, k.tenant_id, k.business_id, 'app-qpickstore',
           'Kept their storefront when ecommerce became QPickStore (2026-10-28)',
           CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, NULL
      FROM _qps_keep k
     WHERE NOT EXISTS (SELECT 1 FROM core_platform.cp_business_apps b
                        WHERE b.tenant_id = k.tenant_id AND b.bus_id = k.business_id
                          AND b.app_id = 'app-qpickstore' AND b.delete_status = 'NOT_DELETED');

    INSERT INTO core_platform.cp_app_subscriptions
           (tenant_id, business_app_id, business_id, app_id, shared_subscription_id, status, is_enterprise,
            is_payment_required, current_period_start, current_period_end, next_charge_date,
            is_active, delete_status, description, cdate, ctime, cdatetime, created_by)
    SELECT k.tenant_id, b.id, k.business_id, 'app-qpickstore', k.shared_subscription_id, k.status, k.is_enterprise,
           k.is_payment_required, k.current_period_start, k.current_period_end, k.next_charge_date,
           true, 'NOT_DELETED', 'Kept their storefront when ecommerce became QPickStore (2026-10-28)',
           CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, NULL
      FROM _qps_keep k
      JOIN core_platform.cp_business_apps b
        ON b.tenant_id = k.tenant_id AND b.bus_id = k.business_id
       AND b.app_id = 'app-qpickstore' AND b.delete_status = 'NOT_DELETED';
    GET DIAGNOSTICS v_subs = ROW_COUNT;

    INSERT INTO core_platform.cp_app_subscription_history
           (tenant_id, app_subscription_id, business_id, app_id, shared_subscription_id, is_active,
            delete_status, start_at, end_at, cdate, ctime, cdatetime, created_by)
    SELECT s.tenant_id, s.id, s.business_id, 'app-qpickstore', s.shared_subscription_id, true,
           'NOT_DELETED', CURRENT_DATE::text, NULL, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP,
           NULL
      FROM core_platform.cp_app_subscriptions s
      JOIN _qps_keep k ON k.tenant_id = s.tenant_id AND k.business_id = s.business_id
     WHERE s.app_id = 'app-qpickstore'
       AND s.description = 'Kept their storefront when ecommerce became QPickStore (2026-10-28)';

    -- Deployed wherever this business runs MyStoreGuard.
    INSERT INTO core_platform.cp_business_app_locations
           (id, tenant_id, business_app_id, loc_id, org_id, bus_id, app_id, is_active, delete_status,
            cdate, ctime, cdatetime, created_by)
    SELECT 'bal_qps_' || md5(m.tenant_id || ':' || m.bus_id || ':' || m.loc_id), m.tenant_id, b.id, m.loc_id,
           m.org_id, m.bus_id, 'app-qpickstore', true, 'NOT_DELETED',
           CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, NULL
      FROM (SELECT DISTINCT ml.tenant_id, ml.bus_id, ml.loc_id, ml.org_id
              FROM core_platform.cp_business_app_locations ml
              JOIN _qps_keep k ON k.tenant_id = ml.tenant_id AND k.business_id = ml.bus_id
             WHERE ml.app_id = 'app-mystoreguard' AND ml.delete_status = 'NOT_DELETED' AND ml.is_active = true) m
      JOIN core_platform.cp_business_apps b
        ON b.tenant_id = m.tenant_id AND b.bus_id = m.bus_id
       AND b.app_id = 'app-qpickstore' AND b.delete_status = 'NOT_DELETED'
     WHERE NOT EXISTS (SELECT 1 FROM core_platform.cp_business_app_locations x
                        WHERE x.tenant_id = m.tenant_id AND x.bus_id = m.bus_id AND x.loc_id = m.loc_id
                          AND x.app_id = 'app-qpickstore' AND x.delete_status = 'NOT_DELETED');
    GET DIAGNOSTICS v_locs = ROW_COUNT;

    INSERT INTO core_platform.cp_migration_decisions (decision_key, detail)
    VALUES (v_key, jsonb_build_object(
        'rule', 'every business whose MyStoreGuard plan included ecommerce gets QPickStore on the same tier, status and period, deployed where its MyStoreGuard is',
        'subscriptions', v_subs, 'locations', v_locs, 'by', 'migration:20261028-50'));
    RAISE NOTICE 'qpickstore: % business(es) kept their storefront, deployed at % location(s)', v_subs, v_locs;
END $$;

-- ===================================================================== invariants
-- Properties, never counts.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM core_platform.cp_apps WHERE id = 'app-qpickstore'
                AND requires_app_id IS DISTINCT FROM 'app-mystoreguard') THEN
        RAISE EXCEPTION 'QPickStore must be an add-on of MyStoreGuard';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                 JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                 JOIN core_platform.cp_actions a ON a.action = p.action
                WHERE rp.role_id = 'role-qpickstore-viewer' AND p.app_prefix = 'msg' AND NOT a.is_read_only) THEN
        RAISE EXCEPTION 'role-qpickstore-viewer holds a permission that changes data';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                 JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id LIKE 'role-qpickstore-%'
                  AND coalesce(p.app_prefix, '') NOT IN ('', 'cp', 'msg')) THEN
        RAISE EXCEPTION 'a QPickStore role holds another app''s permission';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_roles
                WHERE id LIKE 'role-qpickstore-%' AND role_name NOT LIKE 'QPickStore %') THEN
        RAISE EXCEPTION 'a QPickStore role is not named "QPickStore ..."; role names are unique across apps';
    END IF;
    -- No business may hold QPickStore without MyStoreGuard.
    IF EXISTS (SELECT 1 FROM core_platform.cp_app_subscriptions q
                WHERE q.app_id = 'app-qpickstore' AND q.delete_status = 'NOT_DELETED' AND q.is_active
                  AND NOT EXISTS (SELECT 1 FROM core_platform.cp_app_subscriptions m
                                   WHERE m.tenant_id = q.tenant_id AND m.business_id = q.business_id
                                     AND m.app_id = 'app-mystoreguard' AND m.delete_status = 'NOT_DELETED'
                                     AND m.is_active)) THEN
        RAISE EXCEPTION 'a business holds QPickStore without MyStoreGuard';
    END IF;
END $$;

COMMIT;
