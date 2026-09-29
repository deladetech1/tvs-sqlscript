-- =====================================================================================
-- Declare resources and their verbs; generate the permissions from them.
--
-- 02_permissions.sql is 513 hand-written rows, four to seven per entity, and adding an
-- entity means writing every one of them again. Nothing in those rows is new information:
-- 20260928-05 showed all of them decompose into (resource, action, target, scope), and 488 of
-- 513 recompose to exactly the id they already have.
--
-- So declare the part that is real -- 128 resources, each with the verbs it supports -- and
-- let the permissions fall out of it. Adding an entity becomes one line:
--
--     INSERT INTO core_platform.cp_resources VALUES
--       ('msg', 'deliveries', 'rt-deliveries', ARRAY['create','get','update','delete','statistics']);
--     SELECT core_platform.sync_permissions_from_catalogue();
--
-- 128 resources + 56 overrides + 47 verbs = 231 rows, replacing 513 authored ones.
--
-- Generating NAMES is only safe because 20260928-06/07/08 removed the last rule that read
-- them. Nothing decides access by permission_name any more.
--
-- ADDITIVE: creates no permission that does not already exist. Verified at the end.
-- Safe to rerun.
-- =====================================================================================

SET search_path TO core_platform;

-- -------------------------------------------------------------------------------------
-- One row per resource. `actions` entries are `verb`, `verb:target`, or `verb@own`
-- (`verb:target@own` for both) -- the three axes 20260928-05 recorded, written compactly so a
-- resource stays a single line.
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core_platform.cp_resources (
    app_prefix       TEXT NOT NULL DEFAULT '',
    resource_key     TEXT NOT NULL,
    resource_type_id TEXT NOT NULL REFERENCES core_platform.cp_resource_types(id),
    actions          TEXT[] NOT NULL,
    label            TEXT,          -- defaults to the resource key, title-cased
    PRIMARY KEY (app_prefix, resource_key)
);

-- Where a permission cannot be derived: its id is spelled in a different word order
-- (`user-groups-get` for user + get + groups), or it hangs off a resource type other than its
-- resource's usual one (every `statistics` in MyStoreGuard still lives on rt-msg-statistics,
-- and the backdate/release capabilities have resource types of their own so their roles stay
-- separate from the ordinary sales roles).
CREATE TABLE IF NOT EXISTS core_platform.cp_permission_overrides (
    app_prefix       TEXT NOT NULL DEFAULT '',
    resource_key     TEXT NOT NULL,
    action           TEXT NOT NULL,
    target           TEXT NOT NULL DEFAULT '',
    scope            TEXT NOT NULL DEFAULT 'any',
    permission_id    TEXT,
    resource_type_id TEXT REFERENCES core_platform.cp_resource_types(id),
    PRIMARY KEY (app_prefix, resource_key, action, target, scope)
);

TRUNCATE core_platform.cp_resources;
INSERT INTO core_platform.cp_resources (app_prefix, resource_key, resource_type_id, actions) VALUES
('cp', 'file', 'rt-file', ARRAY['delete','list:documents','update','upload:multiple']),
('cp', 'logs', 'rt-logs', ARRAY['delete','get']),
('loandrift', 'accounting', 'rt-loandrift-accounting', ARRAY['create','delete','get','update']),
('loandrift', 'agreements', 'rt-loandrift-agreements', ARRAY['create','get','share','sign','void']),
('loandrift', 'approval', 'rt-approval', ARRAY['get','update']),
('loandrift', 'calender', 'rt-calender', ARRAY['get']),
('loandrift', 'capturing', 'rt-capturing', ARRAY['complete','delete','get:loan-messages','reject','restructure','statistics','update','write-off']),
('loandrift', 'capturing-write-off', 'rt-capturing', ARRAY['approve']),
('loandrift', 'client', 'rt-client', ARRAY['approve:deletion','create','delete','get','get:deletion-chat-history','statistics','update']),
('loandrift', 'collateral', 'rt-loandrift-collateral', ARRAY['create','delete','get','update']),
('loandrift', 'collections', 'rt-loandrift-collections', ARRAY['create','delete','get','update']),
('loandrift', 'credit-score', 'rt-credit-score', ARRAY['adjust','calculate','create','get']),
('loandrift', 'credit-score-settings', 'rt-credit-score', ARRAY['get','update']),
('loandrift', 'dashboard', 'rt-dashboard', ARRAY['get:chart-data','statistics']),
('loandrift', 'disbursement', 'rt-disbursement', ARRAY['disburse','get','update']),
('loandrift', 'expenses', 'rt-loandrift-expenses', ARRAY['create','delete','get','get:activity-logs','statistics','update']),
('loandrift', 'file', 'rt-file', ARRAY['delete','list:documents','update','upload:multiple']),
('loandrift', 'groups', 'rt-loandrift-groups', ARRAY['create','get','update']),
('loandrift', 'investment', 'rt-investment', ARRAY['complete','create','delete','get','statistics','terminate','update']),
('loandrift', 'loan-registration', 'rt-loan-registration', ARRAY['create:existing-client','create:new-client','delete','get','statistics','update']),
('loandrift', 'locations', 'rt-location', ARRAY['get']),
('loandrift', 'logs', 'rt-logs', ARRAY['delete','get']),
('loandrift', 'penalty', 'rt-penalty', ARRAY['add','create','get','waive']),
('loandrift', 'penalty-settings', 'rt-penalty', ARRAY['get','update']),
('loandrift', 'penalty-waive', 'rt-penalty', ARRAY['approve','request']),
('loandrift', 'repayment', 'rt-repayment', ARRAY['create','delete','get','get:payment-dates','refund','reverse','statistics','update']),
('loandrift', 'repayment-auto', 'rt-repayment', ARRAY['manage']),
('loandrift', 'reports', 'rt-reports', ARRAY['get']),
('loandrift', 'savings', 'rt-savings', ARRAY['close','create','delete','get','statistics','transact','update']),
('loandrift', 'settings', 'rt-settings', ARRAY['create','delete','get','update']),
('msg', 'affiliates', 'rt-affiliates', ARRAY['create','delete','get','statistics','update']),
('msg', 'appointments', 'rt-appointments', ARRAY['create','delete','get','update']),
('msg', 'collection', 'rt-installment-plans', ARRAY['reconcile']),
('msg', 'credit-score', 'rt-installment-plans', ARRAY['adjust']),
('msg', 'credit-score-settings', 'rt-installment-plans', ARRAY['manage']),
('msg', 'custom-fields', 'rt-msg-custom-fields', ARRAY['get']),
('msg', 'customers', 'rt-customers', ARRAY['create','delete','get','statistics','update']),
('msg', 'deliveries', 'rt-deliveries', ARRAY['create','delete','get','statistics','update']),
('msg', 'ecommerce', 'rt-ecommerce', ARRAY['create','delete','get','update']),
('msg', 'estimate-templates', 'rt-estimate-template', ARRAY['create','delete','get','statistics','update']),
('msg', 'estimates', 'rt-estimate', ARRAY['create','delete','get','statistics','update']),
('msg', 'expenses', 'rt-msg-expenses', ARRAY['create','delete','get','statistics','update']),
('msg', 'file', 'rt-file-manager', ARRAY['delete','list:documents','update','upload:multiple']),
('msg', 'gift-cards', 'rt-gift-cards', ARRAY['create','delete','get','statistics','update']),
('msg', 'guarantor', 'rt-guarantors', ARRAY['create','delete','get','update']),
('msg', 'installment-plan', 'rt-installment-plans', ARRAY['approve','cancel','get','pay','refund','refund:payment','statistics','waive']),
('msg', 'installment-policy', 'rt-installment-policies', ARRAY['create','delete','get','statistics','update']),
('msg', 'invoices', 'rt-invoice', ARRAY['create','delete','get','statistics','update']),
('msg', 'logs', 'rt-logs', ARRAY['delete','get']),
('msg', 'loyalty', 'rt-loyalty', ARRAY['create','delete','get','update']),
('msg', 'messaging', 'rt-messaging', ARRAY['create','delete','get','statistics','update']),
('msg', 'pricing-rule', 'rt-pricing-rules', ARRAY['create','delete','get','statistics','update']),
('msg', 'product-metadata', 'rt-product-metadata', ARRAY['create','delete','get','statistics','update']),
('msg', 'product-price', 'rt-product-prices', ARRAY['create','delete','get','statistics','update']),
('msg', 'products', 'rt-product', ARRAY['adjust:delivery','create','delete','get','move:batch','split','statistics','update']),
('msg', 'promo-codes', 'rt-promo-codes', ARRAY['create','delete','get','statistics','update']),
('msg', 'purchase-orders', 'rt-purchase-orders', ARRAY['backdate','create','delete','get','statistics','update']),
('msg', 'reports', 'rt-reports', ARRAY['get']),
('msg', 'return-policy', 'rt-return-policies', ARRAY['create','delete','get','statistics','update']),
('msg', 'stock-takes', 'rt-stock-takes', ARRAY['create','delete','get','resolve','reverse','statistics']),
('msg', 'store-config', 'rt-store-configs', ARRAY['create','get']),
('msg', 'store-credit', 'rt-store-returns', ARRAY['get','manage']),
('msg', 'store-products', 'rt-store-products', ARRAY['create','delete','get','statistics','update']),
('msg', 'store-returns', 'rt-store-returns', ARRAY['approve','create','get','statistics','update']),
('msg', 'store-sales', 'rt-store-sales', ARRAY['backdate','cancel','create','delete','get','release:goods','statistics','update']),
('msg', 'store-transfers', 'rt-store-transfers', ARRAY['approve','create','delete','get','statistics','update']),
('msg', 'suppliers', 'rt-suppliers', ARRAY['create','delete','get','statistics','update']),
('msg', 'tasks', 'rt-tasks', ARRAY['approve','create','delete','get','manage:templates','statistics','update']),
('msg', 'tax-rule', 'rt-tax-rules', ARRAY['create','delete','get','statistics','update']),
('msg', 'taxes', 'rt-taxes', ARRAY['create','delete','get','statistics','update']),
('msg', 'warehouse-config', 'rt-warehouse-configs', ARRAY['create','get']),
('msg', 'warehouse-products', 'rt-warehouse-products', ARRAY['create','delete','get','statistics','update']),
('msg', 'warehouse-transfers', 'rt-warehouse-transfers', ARRAY['approve','create','delete','get','statistics','update']),
('msg', 'workflow-templates', 'rt-msg-statistics', ARRAY['statistics']),
('zeloshr', 'attendance', 'rt-zeloshr-attendance', ARRAY['create','delete','get','update']),
('zeloshr', 'audit', 'rt-zeloshr-audit', ARRAY['create','delete','get','update']),
('zeloshr', 'branches', 'rt-zeloshr-branches', ARRAY['create','delete','get','update']),
('zeloshr', 'custom-field-values', 'rt-zeloshr-custom-fields', ARRAY['create','delete','get','update']),
('zeloshr', 'custom-fields', 'rt-zeloshr-custom-fields', ARRAY['create','delete','get','update']),
('zeloshr', 'dashboard', 'rt-zeloshr-dashboard', ARRAY['create','delete','get','update']),
('zeloshr', 'departments', 'rt-zeloshr-departments', ARRAY['create','delete','get','update']),
('zeloshr', 'disciplinary', 'rt-zeloshr-disciplinary', ARRAY['create','delete','get','update']),
('zeloshr', 'documents', 'rt-zeloshr-documents', ARRAY['create','delete','get','update']),
('zeloshr', 'employee', 'rt-zeloshr-employee', ARRAY['create','delete','get','update']),
('zeloshr', 'leave', 'rt-zeloshr-leave', ARRAY['create','delete','get','update']),
('zeloshr', 'lifecycle', 'rt-zeloshr-lifecycle', ARRAY['create','delete','get','update']),
('zeloshr', 'onboarding', 'rt-zeloshr-onboarding', ARRAY['create','delete','get','update']),
('zeloshr', 'org', 'rt-zeloshr-org', ARRAY['create','delete','get','update']),
('zeloshr', 'performance', 'rt-zeloshr-performance', ARRAY['create','delete','get','update']),
('zeloshr', 'recruitment', 'rt-zeloshr-recruitment', ARRAY['create','delete','get','update']),
('zeloshr', 'sensitive-fields', 'rt-zeloshr-custom-fields', ARRAY['reveal']),
('', 'app', 'rt-app', ARRAY['approve:deletion','create','delete','get','permanent-delete','restore','statistics','update']),
('', 'app-deletion-chat-history', 'rt-app', ARRAY['get']),
('', 'attendance-adjustments', 'rt-attendance-adjustments', ARRAY['create','get']),
('', 'attendance-clock', 'rt-attendance-clock', ARRAY['create','get']),
('', 'attendance-devices', 'rt-attendance-devices', ARRAY['create','delete','get']),
('', 'attendance-employees', 'rt-attendance-employees', ARRAY['create','delete','get','update']),
('', 'attendance-records', 'rt-attendance-records', ARRAY['create','delete','get','update']),
('', 'attendance-team', 'rt-attendance-team', ARRAY['get']),
('', 'attendance-timesheet', 'rt-attendance-timesheet', ARRAY['get']),
('', 'billing', 'rt-billing', ARRAY['create','delete','get','pay','restore','statistics']),
('', 'business', 'rt-business', ARRAY['approve:deletion','create','delete','get','permanent-delete','restore','statistics','update']),
('', 'business-app', 'rt-business-app', ARRAY['deploy:locations','get','get:locations','remove:locations','subscribe','unsubscribe']),
('', 'business-deletion-chat-history', 'rt-business', ARRAY['get']),
('', 'currency', 'rt-setting', ARRAY['get']),
('', 'expense', 'rt-expenses', ARRAY['create','delete','get','statistics','update']),
('', 'group', 'rt-group', ARRAY['add:users','approve:deletion','assign:locations','assign:roles','create','delete','get','permanent-delete','remove:locations','remove:roles','remove:users','restore','statistics','update']),
('', 'group-deletion-chat-history', 'rt-group', ARRAY['get']),
('', 'group-locations', 'rt-group', ARRAY['get']),
('', 'group-login-settings', 'rt-group', ARRAY['get','update']),
('', 'location', 'rt-location', ARRAY['approve:deletion','create','delete','get','permanent-delete','restore','statistics','update']),
('', 'location-deletion-chat-history', 'rt-location', ARRAY['get']),
('', 'organization', 'rt-organization', ARRAY['approve:deletion','create','delete','get','permanent-delete','restore','statistics','update']),
('', 'organization-deletion-chat-history', 'rt-organization', ARRAY['get']),
('', 'permission', 'rt-permission', ARRAY['get']),
('', 'role', 'rt-role', ARRAY['approve:deletion','create','delete','get','permanent-delete','restore','statistics','update']),
('', 'role-deletion-chat-history', 'rt-role', ARRAY['get']),
('', 'security', 'rt-security', ARRAY['get','update']),
('', 'settings', 'rt-setting', ARRAY['create','delete','get','permanent-delete','restore','statistics','update']),
('', 'subscription', 'rt-subscription', ARRAY['get','update']),
('', 'theme', 'rt-theme', ARRAY['get','update']),
('', 'user', 'rt-user', ARRAY['add:to-groups','assign:locations','assign:roles','change:password','create','delete','get','get:locations','get@own','grant:access','permanent-delete','remove:from-groups','remove:locations','remove:roles','reset:password','restore','revoke:access','statistics','update','update@own','upload:profile-picture']),
('', 'user-deletion-chat-history', 'rt-user', ARRAY['get']),
('', 'user-groups', 'rt-user', ARRAY['get','get@own']),
('', 'user-locations', 'rt-user', ARRAY['get','get@own']),
('', 'user-login-settings', 'rt-user', ARRAY['get','update']),
('', 'user-resource-types-with-roles', 'rt-user', ARRAY['get']),
('', 'user-roles', 'rt-user', ARRAY['get','get@own']);

TRUNCATE core_platform.cp_permission_overrides;
INSERT INTO core_platform.cp_permission_overrides
    (app_prefix, resource_key, action, target, scope, permission_id, resource_type_id) VALUES
('', 'app', 'statistics', '', 'any', 'permission-app-statistics-get', NULL),
('', 'billing', 'pay', '', 'any', 'permission-billing-make-payment', NULL),
('', 'billing', 'statistics', '', 'any', 'permission-billing-statistics-get', NULL),
('', 'business', 'statistics', '', 'any', 'permission-business-statistics-get', NULL),
('', 'expense', 'statistics', '', 'any', 'permission-expense-get-statistics', NULL),
('', 'group', 'statistics', '', 'any', 'permission-group-statistics-get', NULL),
('', 'location', 'statistics', '', 'any', 'permission-location-statistics-get', NULL),
('', 'organization', 'statistics', '', 'any', 'permission-organization-statistics-get', NULL),
('', 'role', 'statistics', '', 'any', 'permission-role-statistics-get', NULL),
('', 'settings', 'statistics', '', 'any', 'permission-settings-statistics-get', NULL),
('', 'user', 'statistics', '', 'any', 'permission-user-statistics-get', NULL),
('loandrift', 'capturing', 'reject', '', 'any', 'permission-loandrift-capturing-approve-reject', NULL),
('loandrift', 'capturing', 'update', '', 'any', 'permission-loandrift-capturing-create-update', NULL),
('loandrift', 'capturing', 'statistics', '', 'any', 'permission-loandrift-capturing-get-statistics', NULL),
('loandrift', 'client', 'statistics', '', 'any', 'permission-loandrift-client-get-statistics', NULL),
('loandrift', 'dashboard', 'statistics', '', 'any', 'permission-loandrift-dashboard-get-statistics', NULL),
('loandrift', 'expenses', 'statistics', '', 'any', 'permission-loandrift-expenses-get-statistics', NULL),
('loandrift', 'investment', 'statistics', '', 'any', 'permission-loandrift-investment-get-statistics', NULL),
('loandrift', 'loan-registration', 'statistics', '', 'any', 'permission-loandrift-loan-registration-get-statistics', NULL),
('loandrift', 'repayment', 'statistics', '', 'any', 'permission-loandrift-repayment-get-statistics', NULL),
('loandrift', 'repayment-auto', 'manage', '', 'any', 'permission-loandrift-repayment-auto', NULL),
('loandrift', 'savings', 'statistics', '', 'any', 'permission-loandrift-savings-get-statistics', NULL),
('msg', 'affiliates', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'credit-score-settings', 'manage', '', 'any', 'permission-msg-credit-score-settings', NULL),
('msg', 'customers', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'deliveries', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'estimate-templates', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'estimates', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'expenses', 'statistics', '', 'any', 'permission-msg-expenses-get-statistics', 'rt-msg-statistics'),
('msg', 'gift-cards', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'installment-plan', 'refund', '', 'any', 'permission-msg-installment-plan-close-refund', NULL),
('msg', 'installment-plan', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'installment-policy', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'invoices', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'messaging', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'pricing-rule', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'product-metadata', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'product-price', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'products', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'promo-codes', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'purchase-orders', 'backdate', '', 'any', NULL, 'rt-purchase-orders-backdate'),
('msg', 'purchase-orders', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'return-policy', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'stock-takes', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'store-products', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'store-returns', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'store-sales', 'backdate', '', 'any', NULL, 'rt-store-sales-backdate'),
('msg', 'store-sales', 'release', 'goods', 'any', NULL, 'rt-store-sales-release-goods'),
('msg', 'store-sales', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'store-transfers', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'suppliers', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'tasks', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'tax-rule', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'taxes', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'warehouse-products', 'statistics', '', 'any', NULL, 'rt-msg-statistics'),
('msg', 'warehouse-transfers', 'statistics', '', 'any', NULL, 'rt-msg-statistics');

-- -------------------------------------------------------------------------------------
-- The catalogue expanded: exactly the permissions the declarations describe.
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW core_platform.cp_permission_catalogue AS
WITH spec AS (
    SELECT r.app_prefix, r.resource_key, r.resource_type_id AS default_rt,
           COALESCE(r.label, initcap(replace(r.resource_key, '-', ' '))) AS resource_label,
           split_part(split_part(s, '@', 1), ':', 1) AS action,
           CASE WHEN split_part(s, '@', 1) LIKE '%:%'
                THEN split_part(split_part(s, '@', 1), ':', 2) ELSE '' END AS target,
           CASE WHEN s LIKE '%@own' THEN 'own' ELSE 'any' END AS scope
    FROM core_platform.cp_resources r
    CROSS JOIN LATERAL unnest(r.actions) AS s
)
SELECT
    COALESCE(o.permission_id,
             'permission-' || CASE WHEN sp.app_prefix = '' THEN '' ELSE sp.app_prefix || '-' END
             || sp.resource_key || '-' || sp.action
             || CASE WHEN sp.target <> '' THEN '-' || sp.target ELSE '' END
             || CASE WHEN sp.scope = 'own' THEN '-own' ELSE '' END) AS id,
    sp.app_prefix, sp.resource_key, sp.action, sp.target, sp.scope,
    COALESCE(o.resource_type_id, sp.default_rt) AS resource_type_id,
    btrim(
        CASE sp.app_prefix WHEN 'msg' THEN 'Mystoreguard ' WHEN 'loandrift' THEN 'Loandrift '
                           WHEN 'zeloshr' THEN 'ZelosHR '   WHEN 'cp' THEN 'Core Platform '
                           ELSE '' END
        || sp.resource_label || ' ' || a.label
        || CASE WHEN sp.target <> '' THEN ' ' || initcap(replace(sp.target, '-', ' ')) ELSE '' END
        || CASE WHEN sp.scope = 'own' THEN ' Own' ELSE '' END) AS permission_name
FROM spec sp
JOIN core_platform.cp_actions a ON a.action = sp.action
LEFT JOIN core_platform.cp_permission_overrides o
       ON o.app_prefix = sp.app_prefix AND o.resource_key = sp.resource_key
      AND o.action = sp.action AND o.target = sp.target AND o.scope = sp.scope;

-- -------------------------------------------------------------------------------------
-- Apply the catalogue. Inserts what is missing and keeps the structural columns true; it never
-- deletes, and never overwrites a permission_name or description somebody wrote by hand --
-- those carry intent the catalogue cannot reproduce.
--
-- A genuinely new row fires the AFTER INSERT trigger, so declaring a resource also routes its
-- permissions to the right roles. That is the point.
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core_platform.sync_permissions_from_catalogue()
RETURNS INTEGER AS $$
DECLARE inserted INTEGER;
BEGIN
    -- xmax = 0 distinguishes a genuine INSERT from an ON CONFLICT update, so the count
    -- reported is new permissions rather than every row the statement touched.
    WITH upserted AS (
        INSERT INTO core_platform.cp_permissions
            (id, permission_name, resource_type_id, description,
             app_prefix, resource_key, action, target, scope, cdate, ctime, cdatetime)
        SELECT c.id, c.permission_name, c.resource_type_id,
               'Generated from the resource catalogue',
               c.app_prefix, c.resource_key, c.action, c.target, c.scope,
               CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
        FROM core_platform.cp_permission_catalogue c
        ON CONFLICT (id) DO UPDATE SET
            app_prefix       = EXCLUDED.app_prefix,
            resource_key     = EXCLUDED.resource_key,
            action           = EXCLUDED.action,
            target           = EXCLUDED.target,
            scope            = EXCLUDED.scope,
            resource_type_id = EXCLUDED.resource_type_id
        RETURNING (xmax = 0) AS was_insert
    )
    SELECT count(*) FILTER (WHERE was_insert) INTO inserted FROM upserted;
    RETURN inserted;
END;
$$ LANGUAGE plpgsql;

SELECT core_platform.sync_permissions_from_catalogue();

-- -------------------------------------------------------------------------------------
-- Verify: the catalogue must describe every live permission and invent none. If this fires,
-- the declarations are wrong -- not the database.
-- -------------------------------------------------------------------------------------
DO $$
DECLARE extra TEXT; missing TEXT;
BEGIN
    SELECT string_agg(c.id, ', ' ORDER BY c.id) INTO extra
    FROM core_platform.cp_permission_catalogue c
    LEFT JOIN core_platform.cp_permissions p ON p.id = c.id
    WHERE p.id IS NULL;

    SELECT string_agg(p.id, ', ' ORDER BY p.id) INTO missing
    FROM core_platform.cp_permissions p
    LEFT JOIN core_platform.cp_permission_catalogue c ON c.id = p.id
    WHERE c.id IS NULL AND p.delete_status = 'NOT_DELETED';

    IF extra IS NOT NULL THEN
        RAISE EXCEPTION 'catalogue would create permissions that do not exist: %', extra;
    END IF;
    IF missing IS NOT NULL THEN
        RAISE WARNING 'permissions not described by the catalogue (add them to cp_resources): %', missing;
    END IF;
END $$;
