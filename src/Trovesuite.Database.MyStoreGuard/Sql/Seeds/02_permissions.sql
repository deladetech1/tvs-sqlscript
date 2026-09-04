-- =====================================================
-- Mystoreguard Database Schema
-- =====================================================

-- CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE SCHEMA IF NOT EXISTS mystoreguard;

-- Set the search path to mystoreguard schema for this session
SET search_path TO mystoreguard;

-- Insert permissions into core_platform schema (shared across all modules)

INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime) VALUES

-- Removed: the four permission-msg-clients-* permissions. They guarded a router that was
-- never mounted, against a table that was never created. Dropped in Seeds/04_others.sql.

-- Invoice permissions
('permission-msg-invoices-create', 'Mystoreguard Invoices Create', 'rt-invoice', 'Can create new invoices', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-invoices-get', 'Mystoreguard Invoices Get', 'rt-invoice', 'Can view, list, read invoices, view statistics, view deletion chat history, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-invoices-update', 'Mystoreguard Invoices Update', 'rt-invoice', 'Can update invoices, restore soft-deleted invoices, approve or reject deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-invoices-delete', 'Mystoreguard Invoices Delete', 'rt-invoice', 'Can delete invoices', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),


-- Store permissions
('permission-msg-store-config-create', 'Mystoreguard Store Config Create', 'rt-store-configs', 'Can create new store configuration settings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-store-config-get', 'Mystoreguard Store Config Get', 'rt-store-configs', 'Can view and read store configuration settings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
--
('permission-msg-store-products-create', 'Mystoreguard Store Products Create', 'rt-store-products', 'Can create new store products', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-store-products-get', 'Mystoreguard Store Products Get', 'rt-store-products', 'Can view, list, read store products, view statistics, view deletion chat history, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-store-products-update', 'Mystoreguard Store Products Update', 'rt-store-products', 'Can update store products, restore soft-deleted store products, approve or reject deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-store-products-delete', 'Mystoreguard Store Products Delete', 'rt-store-products', 'Can delete store products', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
--
('permission-msg-store-transfers-create', 'Mystoreguard Store Transfers Create', 'rt-store-transfers', 'Can create new store transfers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-store-transfers-approve', 'Mystoreguard Store Transfers Approve', 'rt-store-transfers', 'Can approve or reject store transfers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-store-transfers-get', 'Mystoreguard Store Transfers Get', 'rt-store-transfers', 'Can view, list, read store transfers, view statistics, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-store-transfers-update', 'Mystoreguard Store Transfers Update', 'rt-store-transfers', 'Can update store transfers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-store-transfers-delete', 'Mystoreguard Store Transfers Delete', 'rt-store-transfers', 'Can delete store transfers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
--
-- Suppliers permissions
('permission-msg-suppliers-create', 'Mystoreguard Suppliers Create', 'rt-suppliers', 'Can create new suppliers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-suppliers-get', 'Mystoreguard Suppliers Get', 'rt-suppliers', 'Can view, list, read suppliers, view statistics, view deletion chat history, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-suppliers-update', 'Mystoreguard Suppliers Update', 'rt-suppliers', 'Can update suppliers, restore soft-deleted suppliers, approve or reject deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-suppliers-delete', 'Mystoreguard Suppliers Delete', 'rt-suppliers', 'Can delete suppliers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Warehouse permissions
('permission-msg-warehouse-config-create', 'Mystoreguard Warehouse Config Create', 'rt-warehouse-configs', 'Can create new warehouse configuration settings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-warehouse-config-get', 'Mystoreguard Warehouse Config Get', 'rt-warehouse-configs', 'Can view and read warehouse configuration settings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
--
('permission-msg-warehouse-products-create', 'Mystoreguard Warehouse Products Create', 'rt-warehouse-products', 'Can create new warehouse products', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-warehouse-products-get', 'Mystoreguard Warehouse Products Get', 'rt-warehouse-products', 'Can view, list, read warehouse products, view statistics, view deletion chat history, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-warehouse-products-update', 'Mystoreguard Warehouse Products Update', 'rt-warehouse-products', 'Can update warehouse products, restore soft-deleted warehouse products, approve or reject deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-warehouse-products-delete', 'Mystoreguard Warehouse Products Delete', 'rt-warehouse-products', 'Can delete warehouse products', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
--
('permission-msg-warehouse-transfers-create', 'Mystoreguard Warehouse Transfers Create', 'rt-warehouse-transfers', 'Can create new warehouse transfers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-warehouse-transfers-approve', 'Mystoreguard Warehouse Transfers Approve', 'rt-warehouse-transfers', 'Can approve or reject warehouse transfers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-warehouse-transfers-get', 'Mystoreguard Warehouse Transfers Get', 'rt-warehouse-transfers', 'Can view, list, read warehouse transfers, view statistics, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-warehouse-transfers-update', 'Mystoreguard Warehouse Transfers Update', 'rt-warehouse-transfers', 'Can update warehouse transfers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-warehouse-transfers-delete', 'Mystoreguard Warehouse Transfers Delete', 'rt-warehouse-transfers', 'Can delete warehouse transfers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Products permissions
('permission-msg-products-create', 'Mystoreguard Products Create', 'rt-product', 'Can create new products', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-products-get', 'Mystoreguard Products Get', 'rt-product', 'Can view, list, read products, view statistics, view deletion chat history, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-products-update', 'Mystoreguard Products Update', 'rt-product', 'Can update products, restore soft-deleted products, approve or reject deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-products-delete', 'Mystoreguard Products Delete', 'rt-product', 'Can delete products', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-products-split', 'Mystoreguard Products Split', 'rt-product', 'Can split (break-bulk) products into smaller units and reverse splits', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
--
('permission-msg-product-metadata-create', 'Mystoreguard Product Metadata Create', 'rt-product-metadata', 'Can create new product metadata', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-product-metadata-get', 'Mystoreguard Product Metadata Get', 'rt-product-metadata', 'Can view, list, read product metadata, view statistics, view deletion chat history, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-product-metadata-update', 'Mystoreguard Product Metadata Update', 'rt-product-metadata', 'Can update product metadata, restore soft-deleted product metadata, approve or reject deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-product-metadata-delete', 'Mystoreguard Product Metadata Delete', 'rt-product-metadata', 'Can delete product metadata', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
--
('permission-msg-product-price-create', 'Mystoreguard Product Price Create', 'rt-product-prices', 'Can create new product prices', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-product-price-get', 'Mystoreguard Product Price Get', 'rt-product-prices', 'Can view, list, read product prices, view statistics, view deletion chat history, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-product-price-update', 'Mystoreguard Product Price Update', 'rt-product-prices', 'Can update product prices, restore soft-deleted product prices, approve or reject deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-product-price-delete', 'Mystoreguard Product Price Delete', 'rt-product-prices', 'Can delete product prices', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Purchase Orders permissions
('permission-msg-purchase-orders-create', 'Mystoreguard Purchase Orders Create', 'rt-purchase-orders', 'Can create new purchase orders', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-purchase-orders-get', 'Mystoreguard Purchase Orders Get', 'rt-purchase-orders', 'Can view, list, read purchase orders, view statistics, view deletion chat history, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-purchase-orders-update', 'Mystoreguard Purchase Orders Update', 'rt-purchase-orders', 'Can update purchase orders, restore soft-deleted purchase orders, approve or reject deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-purchase-orders-delete', 'Mystoreguard Purchase Orders Delete', 'rt-purchase-orders', 'Can delete purchase orders', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Pricing Rules permissions
('permission-msg-pricing-rule-create', 'Mystoreguard Pricing Rule Create', 'rt-pricing-rules', 'Can create new pricing rules', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-pricing-rule-get', 'Mystoreguard Pricing Rule Get', 'rt-pricing-rules', 'Can view, list, read pricing rules, view statistics, view deletion chat history, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-pricing-rule-update', 'Mystoreguard Pricing Rule Update', 'rt-pricing-rules', 'Can update pricing rules, restore soft-deleted pricing rules, approve or reject deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-pricing-rule-delete', 'Mystoreguard Pricing Rule Delete', 'rt-pricing-rules', 'Can delete pricing rules', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Customers permissions
('permission-msg-customers-create', 'Mystoreguard Customers Create', 'rt-customers', 'Can create new customers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-customers-get', 'Mystoreguard Customers Get', 'rt-customers', 'Can view, list, read customers, view statistics, view deletion chat history, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-customers-update', 'Mystoreguard Customers Update', 'rt-customers', 'Can update customers, restore soft-deleted customers, approve or reject deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-customers-delete', 'Mystoreguard Customers Delete', 'rt-customers', 'Can delete customers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- File Manager permissions
('permission-msg-file-upload-multiple', 'Mystoreguard File Upload Multiple', 'rt-file-manager', 'Can upload multiple files', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-file-update', 'Mystoreguard File Update', 'rt-file-manager', 'Can update files', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-file-delete', 'Mystoreguard File Delete', 'rt-file-manager', 'Can delete files', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-file-list-documents', 'Mystoreguard File List Documents', 'rt-file-manager', 'Can list and view documents', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Taxes permissions
('permission-msg-taxes-create', 'Mystoreguard Taxes Create', 'rt-taxes', 'Can create new taxes', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-taxes-get', 'Mystoreguard Taxes Get', 'rt-taxes', 'Can view, list, read taxes, view statistics, view deletion chat history, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-taxes-update', 'Mystoreguard Taxes Update', 'rt-taxes', 'Can update taxes, restore soft-deleted taxes, approve or reject deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-taxes-delete', 'Mystoreguard Taxes Delete', 'rt-taxes', 'Can delete taxes', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
--
('permission-msg-tax-rule-create', 'Mystoreguard Tax Rule Create', 'rt-tax-rules', 'Can create new tax rules', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-tax-rule-get', 'Mystoreguard Tax Rule Get', 'rt-tax-rules', 'Can view, list, read tax rules, view statistics, view deletion chat history, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-tax-rule-update', 'Mystoreguard Tax Rule Update', 'rt-tax-rules', 'Can update tax rules, restore soft-deleted tax rules, approve or reject deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-tax-rule-delete', 'Mystoreguard Tax Rule Delete', 'rt-tax-rules', 'Can delete tax rules', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Appointments permissions
('permission-msg-appointments-create', 'Mystoreguard Appointments Create', 'rt-appointments', 'Can create new appointments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-appointments-get', 'Mystoreguard Appointments Get', 'rt-appointments', 'Can view, list, read appointments, view statistics, view deletion chat history, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-appointments-update', 'Mystoreguard Appointments Update', 'rt-appointments', 'Can update appointments, restore soft-deleted appointments, approve or reject deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-appointments-delete', 'Mystoreguard Appointments Delete', 'rt-appointments', 'Can delete appointments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-tasks-get', 'Mystoreguard Tasks Get', 'rt-tasks', 'Can view and list tasks/jobs, their steps and workflow templates', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-tasks-create', 'Mystoreguard Tasks Create', 'rt-tasks', 'Can create tasks/jobs and act on steps (claim, start, mark done)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-tasks-update', 'Mystoreguard Tasks Update', 'rt-tasks', 'Can update tasks and claim/start/complete steps', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-tasks-delete', 'Mystoreguard Tasks Delete', 'rt-tasks', 'Can cancel/delete tasks', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-tasks-approve', 'Mystoreguard Tasks Approve', 'rt-tasks', 'Eligible to approve/reject DONE steps and close them as COMPLETED', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-tasks-manage-templates', 'Mystoreguard Tasks Manage Templates', 'rt-tasks', 'Can create, edit and delete workflow templates', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Store Sales permissions
('permission-msg-store-sales-create', 'Mystoreguard Store Sales Create', 'rt-store-sales', 'Can create new sales', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-store-sales-get', 'Mystoreguard Store Sales Get', 'rt-store-sales', 'Can view, read sales, and access sales statistics', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-store-sales-update', 'Mystoreguard Store Sales Update', 'rt-store-sales', 'Can update and refund sales', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-store-sales-cancel', 'Mystoreguard Store Sales Cancel', 'rt-store-sales', 'Can cancel sales', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-store-sales-delete', 'Mystoreguard Store Sales Delete', 'rt-store-sales', 'Can delete sales', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Backdate: lives under rt-store-sales-backdate, not rt-store-sales, so the auto-assign
-- triggers only reach Owner, Admin, the MSG app admins and role-msg-store-sales-backdate.
('permission-msg-store-sales-backdate', 'Mystoreguard Store Sales Backdate', 'rt-store-sales-backdate', 'Can set a past occurrence date and time (occurred_at) when creating a sale', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Backdate for receiving. Without it the Received Date still records on the receipt, but the
-- batch and the stock movement are stamped with the moment of entry, so a delivery keyed in
-- late lands in today's stock figures rather than the day it arrived.
('permission-msg-purchase-orders-backdate', 'Mystoreguard Purchase Orders Backdate', 'rt-purchase-orders-backdate', 'Can date received stock to the Received Date, so a delivery entered late lands on the day it actually arrived', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),


-- REPORTS
-- Unified Report Permissions (replacing all report-specific permissions)
('permission-msg-reports-get', 'Mystoreguard Reports Get', 'rt-reports', 'Can view, list, and read all reports', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- =====================================================
-- LOGS PERMISSIONS (using core platform rt-logs resource type)
-- =====================================================
('permission-msg-logs-get', 'Mystoreguard Logs Get', 'rt-logs', 'Can view, list, and read activity logs', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-logs-delete', 'Mystoreguard Logs Delete', 'rt-logs', 'Can delete activity logs', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Gift Cards permissions
('permission-msg-gift-cards-create', 'Mystoreguard Gift Cards Create', 'rt-gift-cards', 'Can create new gift cards', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-gift-cards-get', 'Mystoreguard Gift Cards Get', 'rt-gift-cards', 'Can view, list, read gift cards, view statistics, view deletion chat history, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-gift-cards-update', 'Mystoreguard Gift Cards Update', 'rt-gift-cards', 'Can update gift cards, restore soft-deleted gift cards, approve or reject deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-gift-cards-delete', 'Mystoreguard Gift Cards Delete', 'rt-gift-cards', 'Can delete gift cards', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Promo Codes permissions
('permission-msg-promo-codes-create', 'Mystoreguard Promo Codes Create', 'rt-promo-codes', 'Can create new promo codes', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-promo-codes-get', 'Mystoreguard Promo Codes Get', 'rt-promo-codes', 'Can view, list, read promo codes, view statistics, view deletion chat history, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-promo-codes-update', 'Mystoreguard Promo Codes Update', 'rt-promo-codes', 'Can update promo codes, restore soft-deleted promo codes, approve or reject deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-promo-codes-delete', 'Mystoreguard Promo Codes Delete', 'rt-promo-codes', 'Can delete promo codes', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Affiliates permissions
('permission-msg-affiliates-create', 'Mystoreguard Affiliates Create', 'rt-affiliates', 'Can create new affiliates', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-affiliates-get', 'Mystoreguard Affiliates Get', 'rt-affiliates', 'Can view, list, read affiliates, view statistics, view deletion chat history, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-affiliates-update', 'Mystoreguard Affiliates Update', 'rt-affiliates', 'Can update affiliates, restore soft-deleted affiliates, approve or reject deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-affiliates-delete', 'Mystoreguard Affiliates Delete', 'rt-affiliates', 'Can delete affiliates', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Return Policies permissions
('permission-msg-installment-policy-create', 'Mystoreguard Installment Policy Create', 'rt-installment-policies', 'Can create new installment policies', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-installment-policy-get', 'Mystoreguard Installment Policy Get', 'rt-installment-policies', 'Can view, list and read installment policies, view statistics, resolve a policy for a cart and test a formula', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-installment-policy-update', 'Mystoreguard Installment Policy Update', 'rt-installment-policies', 'Can update installment policies', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-installment-policy-delete', 'Mystoreguard Installment Policy Delete', 'rt-installment-policies', 'Can delete installment policies', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-installment-plan-get', 'Mystoreguard Installment Plan Get', 'rt-installment-plans', 'Can view installment plans and schedules, evaluate a cart for installment, and view statistics', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-installment-plan-pay', 'Mystoreguard Installment Plan Pay', 'rt-installment-plans', 'Can record payments against an installment plan', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-installment-plan-cancel', 'Mystoreguard Installment Plan Cancel', 'rt-installment-plans', 'Can cancel an installment plan', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-installment-plan-approve', 'Mystoreguard Installment Plan Approve', 'rt-installment-plans', 'Can approve or reject installment plans you are named on as an approver', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-installment-plan-waive', 'Mystoreguard Installment Penalty Waive', 'rt-installment-plans', 'Can waive a late payment penalty. Every waiver is recorded with a reason.', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-installment-plan-close-refund', 'Mystoreguard Installment Refund Close', 'rt-installment-plans', 'Can declare that money held on a rejected plan has been handed back. Held separately because it closes a debt the shop owes a customer.', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-credit-score-settings', 'Mystoreguard Credit Score Settings', 'rt-installment-plans', 'Can change how customers are scored. Held separately from reading a score because re-weighting decides who gets credit.', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-credit-score-adjust', 'Mystoreguard Credit Score Adjust', 'rt-installment-plans', 'Can override a customer''s score by hand. Separate again: it overrules the engine for one person.', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-collection-reconcile', 'Mystoreguard Collection Reconcile', 'rt-installment-plans', 'Can match money that arrived outside the till to a plan, and post it. Posting moves somebody''s balance, so it is not a read.', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-guarantor-create', 'Mystoreguard Guarantor Create', 'rt-guarantors', 'Can add guarantors to a customer', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-guarantor-get', 'Mystoreguard Guarantor Get', 'rt-guarantors', 'Can view and list guarantors', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-guarantor-update', 'Mystoreguard Guarantor Update', 'rt-guarantors', 'Can update guarantors', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-guarantor-delete', 'Mystoreguard Guarantor Delete', 'rt-guarantors', 'Can delete guarantors', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-return-policy-create', 'Mystoreguard Return Policy Create', 'rt-return-policies', 'Can create new return policies', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-return-policy-get', 'Mystoreguard Return Policy Get', 'rt-return-policies', 'Can view, list, read return policies, view statistics, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-return-policy-update', 'Mystoreguard Return Policy Update', 'rt-return-policies', 'Can update return policies', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-return-policy-delete', 'Mystoreguard Return Policy Delete', 'rt-return-policies', 'Can delete return policies', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Store Returns permissions
('permission-msg-store-returns-create', 'Mystoreguard Store Returns Create', 'rt-store-returns', 'Can create new return requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-store-returns-get', 'Mystoreguard Store Returns Get', 'rt-store-returns', 'Can view, list, read returns, view statistics, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-store-returns-update', 'Mystoreguard Store Returns Update', 'rt-store-returns', 'Can process approved returns (restock and refund)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-store-returns-approve', 'Mystoreguard Store Returns Approve', 'rt-store-returns', 'Can approve or reject pending return requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Deliveries permissions
('permission-msg-deliveries-create', 'Mystoreguard Deliveries Create', 'rt-deliveries', 'Can create new deliveries', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-deliveries-get', 'Mystoreguard Deliveries Get', 'rt-deliveries', 'Can view, list, read deliveries, view statistics, view deletion chat history, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-deliveries-update', 'Mystoreguard Deliveries Update', 'rt-deliveries', 'Can update deliveries, restore soft-deleted deliveries, approve or reject deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-deliveries-delete', 'Mystoreguard Deliveries Delete', 'rt-deliveries', 'Can delete deliveries', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Stock takes permissions
('permission-msg-stock-takes-create', 'Mystoreguard Stock Takes Create', 'rt-stock-takes', 'Can create stock takes (count products) and complete/lock them', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-stock-takes-get', 'Mystoreguard Stock Takes Get', 'rt-stock-takes', 'Can view and list stock takes and their variance reports', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-stock-takes-resolve', 'Mystoreguard Stock Takes Resolve', 'rt-stock-takes', 'Can investigate and resolve stock take variances, including applying optional stock corrections', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-stock-takes-reverse', 'Mystoreguard Stock Takes Reverse', 'rt-stock-takes', 'Can reverse stock corrections applied when resolving a stock take variance, putting the stock back and reopening the line', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-stock-takes-delete', 'Mystoreguard Stock Takes Delete', 'rt-stock-takes', 'Can permanently delete a DRAFT stock take along with its counted lines and comments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Estimate template permissions (the per-domain blueprint)
('permission-msg-estimate-templates-create', 'Mystoreguard Estimate Templates Create', 'rt-estimate-template', 'Can create new estimate templates', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-estimate-templates-get', 'Mystoreguard Estimate Templates Get', 'rt-estimate-template', 'Can view, list, read estimate templates and view statistics', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-estimate-templates-update', 'Mystoreguard Estimate Templates Update', 'rt-estimate-template', 'Can update estimate templates', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-estimate-templates-delete', 'Mystoreguard Estimate Templates Delete', 'rt-estimate-template', 'Can delete estimate templates', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Estimate permissions (the priced quote created from a template)
('permission-msg-estimates-create', 'Mystoreguard Estimates Create', 'rt-estimate', 'Can create new estimates from a template', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-estimates-get', 'Mystoreguard Estimates Get', 'rt-estimate', 'Can view, list, read estimates and view statistics', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-estimates-update', 'Mystoreguard Estimates Update', 'rt-estimate', 'Can update/re-price estimates and change their status', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-estimates-delete', 'Mystoreguard Estimates Delete', 'rt-estimate', 'Can delete estimates', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Ecommerce permissions (storefront configuration, listings, versions, home page)
-- -update is what publishes: promoting a version is an update, and it is the act that
-- changes what the public sees. Anyone holding it can change the shop window, which is
-- why reading (-get) is separate and much more freely granted.
('permission-msg-ecommerce-create', 'Mystoreguard Ecommerce Create', 'rt-ecommerce', 'Can create storefront versions, version items, home sections and product images', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-ecommerce-get', 'Mystoreguard Ecommerce Get', 'rt-ecommerce', 'Can view the storefront overview, settings, listings, versions and previews', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-ecommerce-update', 'Mystoreguard Ecommerce Update', 'rt-ecommerce', 'Can change storefront settings, edit versions and promote or unpromote them', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-ecommerce-delete', 'Mystoreguard Ecommerce Delete', 'rt-ecommerce', 'Can delete storefront versions, version items, home sections and product images', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)

ON CONFLICT (id) DO UPDATE SET
    permission_name  = EXCLUDED.permission_name,
    resource_type_id = EXCLUDED.resource_type_id,
    description      = EXCLUDED.description;