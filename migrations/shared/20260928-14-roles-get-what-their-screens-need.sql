-- =====================================================================================
-- Give each role the permissions its own screens actually need.
--
-- Roles were granted their own resource and nothing around it, so a role could not finish
-- the job it exists to do. A sales person could take a sale but not look up the customer to
-- put it against. Whoever manages products could not upload a product image or see a
-- supplier. The screen loaded and the first request on it returned 403.
--
-- These grants were not chosen by hand. Every controller was read for the permissions it
-- requires, every screen for the endpoints it calls, and the two joined: for each role, the
-- screens it can ACT on (an action cp_actions does not mark read-only), and what those
-- screens need that the role does not hold. scripts/audit_role_permissions.py in this repo
-- reproduces it and prints any gap that appears later.
--
-- What is granted, and only this:
--
--   * 168 reads a role's own screens need. A read is what breaks a workflow
--         outright, and it is the safe half: seeing a supplier is not changing one.
--   *  13 file writes -- upload, update, delete -- for roles whose own screens need
--         them. There is no separate "product images" right, so without these whoever
--         manages products cannot attach one.
--   *   3 customers+create, for roles that can already take a sale, so a walk-in who
--         has never bought before can be added at the till.
--
-- 164 adjacent WRITES found by the same audit are deliberately NOT granted. A screen hosts
-- more than one feature: the sales screen carries store-returns and installment-policy
-- sections, and granting everything it touches would hand a cashier the right to approve
-- returns. Approving returns stays the returns role's, which is the whole point of having
-- roles.
--
-- ON CONFLICT DO NOTHING, so this is safe to rerun and safe on a database where somebody
-- has already granted one of these by hand.
-- =====================================================================================

INSERT INTO core_platform.cp_role_permissions
    (id, tenant_id, role_id, permission_id, created_by, cdate, ctime, cdatetime)
SELECT
    'rpid_' || md5(v.role_id || ':' || v.permission_id),
    'system-tenant-id',
    v.role_id,
    v.permission_id,
    -- NULL, as every other system-tenant grant has. created_by is a foreign key into
    -- cp_users, so a marker like 'system' is not a value it can hold.
    NULL,
    to_char(now(), 'FMDay FMDDth FMMonth, YYYY'),
    to_char(now(), 'HH12:MI AM'),
    now()
FROM (VALUES
    ('role-attendance-admin', 'permission-location-get'),
    ('role-business-admin', 'permission-cp-file-upload-multiple'),
    ('role-business-app-admin', 'permission-location-get'),
    ('role-default-group', 'permission-group-get'),
    ('role-default-group', 'permission-user-get'),
    ('role-default-group', 'permission-user-get-locations'),
    ('role-default-group', 'permission-user-groups-get'),
    ('role-default-group', 'permission-user-roles-get'),
    ('role-file-admin', 'permission-business-deletion-chat-history-get'),
    ('role-file-admin', 'permission-organization-deletion-chat-history-get'),
    ('role-file-admin', 'permission-organization-statistics-get'),
    ('role-group-admin', 'permission-role-get'),
    ('role-group-admin', 'permission-user-get'),
    ('role-group-admin', 'permission-user-groups-get'),
    ('role-group-admin', 'permission-user-login-settings-get'),
    ('role-group-admin', 'permission-user-roles-get'),
    ('role-loandrift-branch-manager', 'permission-loandrift-file-delete'),
    ('role-loandrift-branch-manager', 'permission-loandrift-groups-get'),
    ('role-loandrift-call-center-agent', 'permission-loandrift-client-get-statistics'),
    ('role-loandrift-capturing-admin', 'permission-loandrift-client-get'),
    ('role-loandrift-capturing-admin', 'permission-loandrift-loan-registration-get'),
    ('role-loandrift-capturing-admin', 'permission-loandrift-settings-get'),
    ('role-loandrift-cashier', 'permission-loandrift-groups-get'),
    ('role-loandrift-client-admin', 'permission-loandrift-file-list-documents'),
    ('role-loandrift-client-admin', 'permission-loandrift-settings-get'),
    ('role-loandrift-collections-admin', 'permission-loandrift-loan-registration-get'),
    ('role-loandrift-credit-manager', 'permission-loandrift-groups-get'),
    ('role-loandrift-credit-score-admin', 'permission-loandrift-client-get'),
    ('role-loandrift-disbursement-admin', 'permission-loandrift-groups-get'),
    ('role-loandrift-file-admin', 'permission-loandrift-client-get'),
    ('role-loandrift-file-admin', 'permission-loandrift-loan-registration-get'),
    ('role-loandrift-file-admin', 'permission-loandrift-settings-get'),
    ('role-loandrift-finance-manager', 'permission-loandrift-groups-get'),
    ('role-loandrift-finance-officer', 'permission-loandrift-groups-get'),
    ('role-loandrift-investment-admin', 'permission-loandrift-client-get'),
    ('role-loandrift-loan-officer', 'permission-loandrift-file-delete'),
    ('role-loandrift-loan-officer', 'permission-loandrift-groups-get'),
    ('role-loandrift-loan-registration-admin', 'permission-loandrift-client-get'),
    ('role-loandrift-loan-registration-admin', 'permission-loandrift-penalty-get'),
    ('role-loandrift-loan-registration-admin', 'permission-loandrift-repayment-get'),
    ('role-loandrift-repayment-admin', 'permission-loandrift-client-get'),
    ('role-loandrift-repayment-admin', 'permission-loandrift-groups-get'),
    ('role-loandrift-repayment-admin', 'permission-loandrift-loan-registration-get'),
    ('role-loandrift-repayment-admin', 'permission-loandrift-penalty-get'),
    ('role-loandrift-sales-executive', 'permission-loandrift-file-delete'),
    ('role-loandrift-sales-executive', 'permission-loandrift-penalty-get'),
    ('role-loandrift-sales-executive', 'permission-loandrift-repayment-get'),
    ('role-loandrift-sales-executive', 'permission-loandrift-settings-get'),
    ('role-loandrift-savings-admin', 'permission-loandrift-client-get'),
    ('role-loandrift-settings-admin', 'permission-loandrift-file-list-documents'),
    ('role-loandrift-settings-admin', 'permission-loandrift-file-upload-multiple'),
    ('role-msg-customers-admin', 'permission-msg-customers-statistics'),
    ('role-msg-customers-admin', 'permission-msg-store-credit-get'),
    ('role-msg-customers-admin', 'permission-msg-store-returns-get'),
    ('role-msg-ecommerce-admin', 'permission-msg-file-upload-multiple'),
    ('role-msg-estimate-admin', 'permission-msg-customers-get'),
    ('role-msg-estimate-admin', 'permission-msg-estimate-templates-get'),
    ('role-msg-estimate-admin', 'permission-msg-file-upload-multiple'),
    ('role-msg-estimate-admin', 'permission-msg-products-get'),
    ('role-msg-estimate-admin', 'permission-msg-tasks-statistics'),
    ('role-msg-estimate-admin', 'permission-msg-taxes-get'),
    ('role-msg-estimate-template-admin', 'permission-msg-file-upload-multiple'),
    ('role-msg-estimate-template-admin', 'permission-msg-products-get'),
    ('role-msg-estimate-template-admin', 'permission-msg-tasks-statistics'),
    ('role-msg-estimate-template-admin', 'permission-msg-taxes-get'),
    ('role-msg-file-manager-admin', 'permission-msg-ecommerce-get'),
    ('role-msg-file-manager-admin', 'permission-msg-product-metadata-get'),
    ('role-msg-file-manager-admin', 'permission-msg-products-get'),
    ('role-msg-file-manager-admin', 'permission-msg-products-statistics'),
    ('role-msg-file-manager-admin', 'permission-msg-purchase-orders-get'),
    ('role-msg-file-manager-admin', 'permission-msg-purchase-orders-statistics'),
    ('role-msg-file-manager-admin', 'permission-msg-store-sales-get'),
    ('role-msg-file-manager-admin', 'permission-msg-suppliers-get'),
    ('role-msg-file-manager-admin', 'permission-msg-tasks-statistics'),
    ('role-msg-file-manager-admin', 'permission-msg-taxes-get'),
    ('role-msg-installment-policies-admin', 'permission-msg-customers-get'),
    ('role-msg-installment-policies-admin', 'permission-msg-product-metadata-get'),
    ('role-msg-installment-policies-admin', 'permission-msg-products-get'),
    ('role-msg-installment-policies-admin', 'permission-msg-store-sales-get'),
    ('role-msg-installment-policies-admin', 'permission-msg-store-sales-statistics'),
    ('role-msg-invoice-admin', 'permission-msg-customers-get'),
    ('role-msg-invoice-admin', 'permission-msg-invoices-statistics'),
    ('role-msg-invoice-admin', 'permission-msg-loyalty-get'),
    ('role-msg-invoice-admin', 'permission-msg-store-config-get'),
    ('role-msg-invoice-admin', 'permission-msg-store-products-get'),
    ('role-msg-loyalty-admin', 'permission-msg-products-get'),
    ('role-msg-messaging-admin', 'permission-msg-customers-get'),
    ('role-msg-messaging-admin', 'permission-msg-messaging-statistics'),
    ('role-msg-messaging-admin', 'permission-msg-suppliers-get'),
    ('role-msg-pricing-rules-admin', 'permission-msg-pricing-rule-statistics'),
    ('role-msg-pricing-rules-admin', 'permission-msg-product-metadata-get'),
    ('role-msg-pricing-rules-admin', 'permission-msg-products-get'),
    ('role-msg-pricing-rules-admin', 'permission-msg-store-sales-get'),
    ('role-msg-product-admin', 'permission-msg-file-delete'),
    ('role-msg-product-admin', 'permission-msg-file-list-documents'),
    ('role-msg-product-admin', 'permission-msg-file-update'),
    ('role-msg-product-admin', 'permission-msg-file-upload-multiple'),
    ('role-msg-product-admin', 'permission-msg-products-statistics'),
    ('role-msg-product-admin', 'permission-msg-store-products-get'),
    ('role-msg-product-admin', 'permission-msg-store-sales-get'),
    ('role-msg-product-admin', 'permission-msg-suppliers-get'),
    ('role-msg-product-admin', 'permission-msg-warehouse-products-get'),
    ('role-msg-product-metadata-admin', 'permission-msg-product-metadata-statistics'),
    ('role-msg-product-prices-admin', 'permission-msg-product-metadata-get'),
    ('role-msg-product-prices-admin', 'permission-msg-product-price-statistics'),
    ('role-msg-product-prices-admin', 'permission-msg-products-get'),
    ('role-msg-purchase-orders-backdate', 'permission-msg-file-upload-multiple'),
    ('role-msg-purchase-orders-backdate', 'permission-msg-products-get'),
    ('role-msg-purchase-orders-backdate', 'permission-msg-purchase-orders-get'),
    ('role-msg-purchase-orders-backdate', 'permission-msg-purchase-orders-statistics'),
    ('role-msg-purchase-orders-backdate', 'permission-msg-suppliers-get'),
    ('role-msg-return-policies-admin', 'permission-msg-product-metadata-get'),
    ('role-msg-return-policies-admin', 'permission-msg-products-get'),
    ('role-msg-return-policies-admin', 'permission-msg-return-policy-statistics'),
    ('role-msg-return-policies-admin', 'permission-msg-store-returns-get'),
    ('role-msg-stock-takes-admin', 'permission-msg-products-get'),
    ('role-msg-stock-takes-admin', 'permission-msg-suppliers-get'),
    ('role-msg-store-admin', 'permission-msg-customers-create'),
    ('role-msg-store-admin', 'permission-msg-customers-get'),
    ('role-msg-store-admin', 'permission-msg-installment-policy-get'),
    ('role-msg-store-admin', 'permission-msg-invoices-get'),
    ('role-msg-store-admin', 'permission-msg-loyalty-get'),
    ('role-msg-store-admin', 'permission-msg-products-get'),
    ('role-msg-store-admin', 'permission-msg-return-policy-get'),
    ('role-msg-store-admin', 'permission-msg-return-policy-statistics'),
    ('role-msg-store-admin', 'permission-msg-store-products-statistics'),
    ('role-msg-store-admin', 'permission-msg-store-returns-statistics'),
    ('role-msg-store-admin', 'permission-msg-store-sales-statistics'),
    ('role-msg-store-admin', 'permission-msg-store-transfers-statistics'),
    ('role-msg-store-admin', 'permission-msg-suppliers-get'),
    ('role-msg-store-configs-admin', 'permission-msg-products-get'),
    ('role-msg-store-returns-admin', 'permission-msg-product-metadata-get'),
    ('role-msg-store-returns-admin', 'permission-msg-products-get'),
    ('role-msg-store-returns-admin', 'permission-msg-return-policy-get'),
    ('role-msg-store-returns-admin', 'permission-msg-return-policy-statistics'),
    ('role-msg-store-returns-admin', 'permission-msg-store-products-get'),
    ('role-msg-store-returns-admin', 'permission-msg-store-returns-statistics'),
    ('role-msg-store-returns-admin', 'permission-msg-store-sales-get'),
    ('role-msg-store-sales-admin', 'permission-msg-customers-create'),
    ('role-msg-store-sales-admin', 'permission-msg-customers-get'),
    ('role-msg-store-sales-admin', 'permission-msg-installment-policy-get'),
    ('role-msg-store-sales-admin', 'permission-msg-invoices-get'),
    ('role-msg-store-sales-admin', 'permission-msg-loyalty-get'),
    ('role-msg-store-sales-admin', 'permission-msg-products-get'),
    ('role-msg-store-sales-admin', 'permission-msg-store-config-get'),
    ('role-msg-store-sales-admin', 'permission-msg-store-returns-get'),
    ('role-msg-store-sales-admin', 'permission-msg-store-returns-statistics'),
    ('role-msg-store-sales-admin', 'permission-msg-store-sales-statistics'),
    ('role-msg-store-sales-backdate', 'permission-msg-customers-get'),
    ('role-msg-store-sales-backdate', 'permission-msg-installment-policy-get'),
    ('role-msg-store-sales-backdate', 'permission-msg-invoices-get'),
    ('role-msg-store-sales-backdate', 'permission-msg-loyalty-get'),
    ('role-msg-store-sales-backdate', 'permission-msg-products-get'),
    ('role-msg-store-sales-backdate', 'permission-msg-store-config-get'),
    ('role-msg-store-sales-backdate', 'permission-msg-store-products-get'),
    ('role-msg-store-sales-backdate', 'permission-msg-store-returns-get'),
    ('role-msg-store-sales-backdate', 'permission-msg-store-returns-statistics'),
    ('role-msg-store-sales-backdate', 'permission-msg-store-sales-get'),
    ('role-msg-store-sales-backdate', 'permission-msg-store-sales-statistics'),
    ('role-msg-store-sales-personnel', 'permission-msg-customers-create'),
    ('role-msg-store-sales-personnel', 'permission-msg-customers-get'),
    ('role-msg-store-sales-personnel', 'permission-msg-installment-policy-get'),
    ('role-msg-store-sales-personnel', 'permission-msg-invoices-get'),
    ('role-msg-store-sales-personnel', 'permission-msg-loyalty-get'),
    ('role-msg-store-sales-personnel', 'permission-msg-products-get'),
    ('role-msg-store-sales-personnel', 'permission-msg-store-config-get'),
    ('role-msg-store-sales-personnel', 'permission-msg-store-returns-get'),
    ('role-msg-store-sales-personnel', 'permission-msg-store-returns-statistics'),
    ('role-msg-store-sales-personnel', 'permission-msg-store-sales-statistics'),
    ('role-msg-suppliers-admin', 'permission-msg-suppliers-statistics'),
    ('role-msg-tax-rules-admin', 'permission-msg-product-metadata-get'),
    ('role-msg-tax-rules-admin', 'permission-msg-products-get'),
    ('role-msg-tax-rules-admin', 'permission-msg-store-sales-get'),
    ('role-msg-tax-rules-admin', 'permission-msg-tax-rule-statistics'),
    ('role-msg-tax-rules-admin', 'permission-msg-taxes-get'),
    ('role-msg-taxes-admin', 'permission-msg-taxes-statistics'),
    ('role-msg-warehouse-admin', 'permission-msg-products-get'),
    ('role-msg-warehouse-admin', 'permission-msg-store-sales-get'),
    ('role-msg-warehouse-admin', 'permission-msg-suppliers-get'),
    ('role-msg-warehouse-admin', 'permission-msg-warehouse-products-statistics'),
    ('role-msg-warehouse-admin', 'permission-msg-warehouse-transfers-statistics'),
    ('role-organization-admin', 'permission-cp-file-upload-multiple'),
    ('role-settings-admin', 'permission-location-get'),
    ('role-user-admin', 'permission-group-get')
) AS v(role_id, permission_id)
WHERE EXISTS (SELECT 1 FROM core_platform.cp_roles r WHERE r.id = v.role_id)
  AND EXISTS (SELECT 1 FROM core_platform.cp_permissions p WHERE p.id = v.permission_id)
  AND NOT EXISTS (
        SELECT 1 FROM core_platform.cp_role_permissions rp
         WHERE rp.role_id = v.role_id AND rp.permission_id = v.permission_id
  );
