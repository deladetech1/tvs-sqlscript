-- =====================================================================================
-- Group a permission with its parent resource, not beside it.
--
-- 20260928-05 read each id left to right, so `permission-user-roles-get` became the resource
-- "user-roles" rather than user + get + roles. Faithful to the spelling, but it means a screen
-- grouping by resource shows fifteen extra one-verb groups sitting next to the thing they
-- belong to:
--
--     User                       Group
--     User Roles                 Group Locations
--     User Groups                Group Login Settings
--     User Locations             Group Deletion Chat History
--     User Login Settings
--     User Deletion Chat History
--
-- Re-key those 18 onto their parent with the sub-thing as the target. Ids do not change -- they
-- move into the override table, which is what it is for.
--
-- Deliberately NOT folded, though the shape looks the same:
--   * business-app -- Business Apps is its own resource (subscriptions), not part of Business.
--   * penalty-waive, capturing-write-off -- the decision being its own resource is what keeps
--     "request a waiver" and "approve a waiver" from ever collapsing into one permission.
--   * permission-user-locations-get -- folding it would collide with
--     permission-user-get-locations, which already IS user + get + locations. Two ids for one
--     thing; this one is enforced nowhere. Left alone rather than quietly resolved here.
--
-- Changes no permission id, no grant, and no application code. 115 resources (was 128),
-- 74 overrides (was 56). Safe to rerun.
-- =====================================================================================

SET search_path TO core_platform;

UPDATE core_platform.cp_permissions p SET
    resource_key = v.resource_key, action = v.action, target = v.target, scope = v.scope
FROM (VALUES
  ('permission-group-deletion-chat-history-get', 'group', 'get', 'deletion-chat-history', 'any'),
  ('permission-group-locations-get', 'group', 'get', 'locations', 'any'),
  ('permission-group-login-settings-get', 'group', 'get', 'login-settings', 'any'),
  ('permission-group-login-settings-update', 'group', 'update', 'login-settings', 'any'),
  ('permission-business-deletion-chat-history-get', 'business', 'get', 'deletion-chat-history', 'any'),
  ('permission-app-deletion-chat-history-get', 'app', 'get', 'deletion-chat-history', 'any'),
  ('permission-user-groups-get', 'user', 'get', 'groups', 'any'),
  ('permission-location-deletion-chat-history-get', 'location', 'get', 'deletion-chat-history', 'any'),
  ('permission-organization-deletion-chat-history-get', 'organization', 'get', 'deletion-chat-history', 'any'),
  ('permission-role-deletion-chat-history-get', 'role', 'get', 'deletion-chat-history', 'any'),
  ('permission-user-deletion-chat-history-get', 'user', 'get', 'deletion-chat-history', 'any'),
  ('permission-user-groups-get-own', 'user', 'get', 'groups', 'own'),
  ('permission-user-locations-get-own', 'user', 'get', 'locations', 'own'),
  ('permission-user-login-settings-get', 'user', 'get', 'login-settings', 'any'),
  ('permission-user-login-settings-update', 'user', 'update', 'login-settings', 'any'),
  ('permission-user-resource-types-with-roles-get', 'user', 'get', 'resource-types-with-roles', 'any'),
  ('permission-user-roles-get', 'user', 'get', 'roles', 'any'),
  ('permission-user-roles-get-own', 'user', 'get', 'roles', 'own')
) AS v(id, resource_key, action, target, scope)
WHERE p.id = v.id;

-- The declarations, rebuilt to match.
TRUNCATE core_platform.cp_resources;
INSERT INTO core_platform.cp_resources (app_prefix, resource_key, resource_type_id, actions) VALUES
('', 'app', 'rt-app', ARRAY['approve:deletion','create','delete','get','get:deletion-chat-history','permanent-delete','restore','statistics','update']),
('zeloshr', 'attendance-adjustments', 'rt-attendance-adjustments', ARRAY['create','get']),
('zeloshr', 'attendance-clock', 'rt-attendance-clock', ARRAY['create','get']),
('zeloshr', 'attendance-devices', 'rt-attendance-devices', ARRAY['create','delete','get']),
('zeloshr', 'attendance-employees', 'rt-attendance-employees', ARRAY['create','delete','get','update']),
('zeloshr', 'attendance-records', 'rt-attendance-records', ARRAY['create','delete','get','update']),
('zeloshr', 'attendance-team', 'rt-attendance-team', ARRAY['get']),
('zeloshr', 'attendance-timesheet', 'rt-attendance-timesheet', ARRAY['get']),
('', 'billing', 'rt-billing', ARRAY['create','delete','get','pay','restore','statistics']),
('', 'business', 'rt-business', ARRAY['approve:deletion','create','delete','get','get:deletion-chat-history','permanent-delete','restore','statistics','update']),
('', 'business-app', 'rt-business-app', ARRAY['deploy:locations','get','get:locations','remove:locations','subscribe','unsubscribe']),
('', 'currency', 'rt-setting', ARRAY['get']),
('', 'expense', 'rt-expenses', ARRAY['create','delete','get','statistics','update']),
('', 'group', 'rt-group', ARRAY['add:users','approve:deletion','assign:locations','assign:roles','create','delete','get','get:deletion-chat-history','get:locations','get:login-settings','permanent-delete','remove:locations','remove:roles','remove:users','restore','statistics','update','update:login-settings']),
('', 'location', 'rt-location', ARRAY['approve:deletion','create','delete','get','get:deletion-chat-history','permanent-delete','restore','statistics','update']),
('', 'organization', 'rt-organization', ARRAY['approve:deletion','create','delete','get','get:deletion-chat-history','permanent-delete','restore','statistics','update']),
('', 'permission', 'rt-permission', ARRAY['get']),
('', 'role', 'rt-role', ARRAY['approve:deletion','create','delete','get','get:deletion-chat-history','permanent-delete','restore','statistics','update']),
('', 'security', 'rt-security', ARRAY['get','update']),
('', 'settings', 'rt-setting', ARRAY['create','delete','get','permanent-delete','restore','statistics','update']),
('', 'subscription', 'rt-subscription', ARRAY['get','update']),
('', 'theme', 'rt-theme', ARRAY['get','update']),
('', 'user', 'rt-user', ARRAY['add:to-groups','assign:locations','assign:roles','change:password','create','delete','get','get:deletion-chat-history','get:groups','get:groups@own','get:locations','get:locations@own','get:login-settings','get:resource-types-with-roles','get:roles','get:roles@own','get@own','grant:access','permanent-delete','remove:from-groups','remove:locations','remove:roles','reset:password','restore','revoke:access','statistics','update','update:login-settings','update@own','upload:profile-picture']),
('', 'user-locations', 'rt-user', ARRAY['get']),
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
('zeloshr', 'sensitive-fields', 'rt-zeloshr-custom-fields', ARRAY['reveal']);

TRUNCATE core_platform.cp_permission_overrides;
INSERT INTO core_platform.cp_permission_overrides
    (app_prefix, resource_key, action, target, scope, permission_id, resource_type_id) VALUES
('', 'app', 'get', 'deletion-chat-history', 'any', 'permission-app-deletion-chat-history-get', NULL),
('', 'app', 'statistics', '', 'any', 'permission-app-statistics-get', NULL),
('', 'billing', 'pay', '', 'any', 'permission-billing-make-payment', NULL),
('', 'billing', 'statistics', '', 'any', 'permission-billing-statistics-get', NULL),
('', 'business', 'get', 'deletion-chat-history', 'any', 'permission-business-deletion-chat-history-get', NULL),
('', 'business', 'statistics', '', 'any', 'permission-business-statistics-get', NULL),
('', 'expense', 'statistics', '', 'any', 'permission-expense-get-statistics', NULL),
('', 'group', 'get', 'deletion-chat-history', 'any', 'permission-group-deletion-chat-history-get', NULL),
('', 'group', 'get', 'locations', 'any', 'permission-group-locations-get', NULL),
('', 'group', 'get', 'login-settings', 'any', 'permission-group-login-settings-get', NULL),
('', 'group', 'update', 'login-settings', 'any', 'permission-group-login-settings-update', NULL),
('', 'group', 'statistics', '', 'any', 'permission-group-statistics-get', NULL),
('', 'location', 'get', 'deletion-chat-history', 'any', 'permission-location-deletion-chat-history-get', NULL),
('', 'location', 'statistics', '', 'any', 'permission-location-statistics-get', NULL),
('', 'organization', 'get', 'deletion-chat-history', 'any', 'permission-organization-deletion-chat-history-get', NULL),
('', 'organization', 'statistics', '', 'any', 'permission-organization-statistics-get', NULL),
('', 'role', 'get', 'deletion-chat-history', 'any', 'permission-role-deletion-chat-history-get', NULL),
('', 'role', 'statistics', '', 'any', 'permission-role-statistics-get', NULL),
('', 'settings', 'statistics', '', 'any', 'permission-settings-statistics-get', NULL),
('', 'user', 'get', 'deletion-chat-history', 'any', 'permission-user-deletion-chat-history-get', NULL),
('', 'user', 'get', 'groups', 'any', 'permission-user-groups-get', NULL),
('', 'user', 'get', 'groups', 'own', 'permission-user-groups-get-own', NULL),
('', 'user', 'get', 'locations', 'own', 'permission-user-locations-get-own', NULL),
('', 'user', 'get', 'login-settings', 'any', 'permission-user-login-settings-get', NULL),
('', 'user', 'update', 'login-settings', 'any', 'permission-user-login-settings-update', NULL),
('', 'user', 'get', 'resource-types-with-roles', 'any', 'permission-user-resource-types-with-roles-get', NULL),
('', 'user', 'get', 'roles', 'any', 'permission-user-roles-get', NULL),
('', 'user', 'get', 'roles', 'own', 'permission-user-roles-get-own', NULL),
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

SELECT core_platform.sync_permissions_from_catalogue();

-- The same gate as 20260928-09: the catalogue must still describe every live permission and
-- invent none. If the re-keying above were wrong, this is where it stops.
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
        RAISE WARNING 'permissions not described by the catalogue: %', missing;
    END IF;
END $$;
