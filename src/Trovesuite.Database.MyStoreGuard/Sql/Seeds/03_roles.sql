-- =====================================================
-- Mystoreguard Database Schema
-- =====================================================

-- CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE SCHEMA IF NOT EXISTS mystoreguard;

-- Set the search path to mystoreguard schema for this session
SET search_path TO mystoreguard;

-- Insert default role into core_platform schema (shared across all modules)
INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES

-- General Admin Role (gets all permissions via trigger)
('role-msg-admin', 'system-tenant-id', 'Admin', 'The administrator of the Sales and Inventory system, can manage all operations including log management', 'rt-subscribed-app-msg', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

('role-subscribed-app-msg-admin', 'system-tenant-id', 'Mystoreguard Admin', 'The administrator of the Sales and Inventory system, can manage all operations including log management', 'rt-subscribed-app-msg', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-warehouse-admin', 'system-tenant-id', 'Mystoreguard Warehouse Admin', 'Administrator for warehouse management', 'rt-warehouse', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-store-admin', 'system-tenant-id', 'Mystoreguard Store Admin', 'Administrator for store management', 'rt-shop', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-expenses-admin', 'system-tenant-id', 'Mystoreguard Expenses Admin', 'Administrator for expenses management', 'rt-expenses', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
-- Removed creditors/depositors/returns admin roles: placeholder roles for features that were never built (cleaned up in 04_others.sql)
-- Removed role-msg-clients-admin with them: it granted rights over a router that was never
-- mounted and a table that was never created, so it appeared in the role picker offering
-- an administrator's access to nothing at all.
('role-msg-invoice-admin', 'system-tenant-id', 'Mystoreguard Invoice Admin', 'Administrator for invoice management', 'rt-invoice', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-suppliers-admin', 'system-tenant-id', 'Mystoreguard Suppliers Admin', 'Administrator for suppliers management', 'rt-suppliers', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-product-admin', 'system-tenant-id', 'Mystoreguard Product Admin', 'Administrator for product management', 'rt-product', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-product-metadata-admin', 'system-tenant-id', 'Mystoreguard Product Metadata Admin', 'Administrator for product metadata management', 'rt-product-metadata', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-product-prices-admin', 'system-tenant-id', 'Mystoreguard Product Prices Admin', 'Administrator for product prices management', 'rt-product-prices', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-pricing-rules-admin', 'system-tenant-id', 'Mystoreguard Pricing Rules Admin', 'Administrator for pricing rules management', 'rt-pricing-rules', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-customers-admin', 'system-tenant-id', 'Mystoreguard Customers Admin', 'Administrator for customers management', 'rt-customers', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-file-manager-admin', 'system-tenant-id', 'Mystoreguard File Manager Admin', 'Administrator for file manager', 'rt-file-manager', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-taxes-admin', 'system-tenant-id', 'Mystoreguard Taxes Admin', 'Administrator for taxes management', 'rt-taxes', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-tax-rules-admin', 'system-tenant-id', 'Mystoreguard Tax Rules Admin', 'Administrator for tax rules management', 'rt-tax-rules', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-store-configs-admin', 'system-tenant-id', 'Mystoreguard Store Configs Admin', 'Administrator for store configuration management', 'rt-store-configs', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-store-sales-admin', 'system-tenant-id', 'Mystoreguard Store Sales Admin', 'Administrator for store sales management with full access including cancel and delete', 'rt-store-sales', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-store-sales-personnel', 'system-tenant-id', 'Mystoreguard Store Sales Personnel', 'Sales personnel for store sales management without cancel or delete permissions', 'rt-store-sales', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-installment-policies-admin', 'system-tenant-id', 'Mystoreguard Installment Policies Admin', 'Administrator for installment policy management', 'rt-installment-policies', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-installment-plans-admin', 'system-tenant-id', 'Mystoreguard Installment Plans Admin', 'Full access to installment plans: view, take payments and cancel', 'rt-installment-plans', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-installment-approver', 'system-tenant-id', 'Mystoreguard Installment Approver', 'Can view installment plans and decide the ones they are named on as an approver', 'rt-installment-plans', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-guarantors-admin', 'system-tenant-id', 'Mystoreguard Guarantors Admin', 'Full access to guarantors backing installment plans', 'rt-guarantors', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-return-policies-admin', 'system-tenant-id', 'Mystoreguard Return Policies Admin', 'Administrator for return policies management', 'rt-return-policies', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-store-returns-admin', 'system-tenant-id', 'Mystoreguard Store Returns Admin', 'Administrator for store returns management with full access including approve and process', 'rt-store-returns', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-reports-admin', 'system-tenant-id', 'Mystoreguard Reports Admin', 'Administrator for reports and analytics management', 'rt-reports', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
-- Tasks Admin Role (resource type rt-tasks): the auto-assign trigger grants all permission-msg-tasks-* on insert
('role-msg-tasks-admin', 'system-tenant-id', 'Mystoreguard Tasks Admin', 'Administrator for tasks and multi-step workflow management', 'rt-tasks', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
-- Estimator Admin Roles: the auto-assign trigger grants all matching permission-msg-estimate(-templates)-* on insert
('role-msg-estimate-template-admin', 'system-tenant-id', 'Mystoreguard Estimate Template Admin', 'Administrator for estimate template (per-domain blueprint) management', 'rt-estimate-template', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-estimate-admin', 'system-tenant-id', 'Mystoreguard Estimate Admin', 'Administrator for estimate management', 'rt-estimate', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
-- Sales Backdate Role (resource type rt-store-sales-backdate): the auto-assign trigger grants
-- the single permission-msg-store-sales-backdate on insert. This is a capability role meant to be
-- assigned ALONGSIDE a sales role (permissions are additive across a user's roles) — on its own it
-- grants no ability to create or view sales.
('role-msg-store-sales-backdate', 'system-tenant-id', 'Mystoreguard Sales Backdate', 'Can backdate a sale to a past date and time when creating it. Assign in addition to a sales role.', 'rt-store-sales-backdate', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
-- Purchase Backdate Role (resource type rt-purchase-orders-backdate): same shape as the sales
-- one. Additive to a purchasing role — on its own it grants no ability to raise or receive an
-- order, only to have the Received Date count for the stock ledger rather than the entry time.
('role-msg-purchase-orders-backdate', 'system-tenant-id', 'Mystoreguard Purchase Backdate', 'Can date received stock to the day it arrived rather than the day it was keyed in. Assign in addition to a purchase orders role.', 'rt-purchase-orders-backdate', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
-- Stock Takes Admin Role (resource type rt-stock-takes): the auto-assign trigger grants all permission-msg-stock-takes-* on insert
('role-msg-stock-takes-admin', 'system-tenant-id', 'Mystoreguard Stock Takes Admin', 'Administrator for stock takes management (count, investigate, and resolve variances)', 'rt-stock-takes', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Ecommerce Admin Role (resource type rt-ecommerce): the auto-assign trigger grants all permission-msg-ecommerce-* on insert
('role-msg-ecommerce-admin', 'system-tenant-id', 'Mystoreguard Ecommerce Admin', 'Administrator for the ecommerce storefront - configuration, listings, images, versions and promotion', 'rt-ecommerce', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Viewer Admin Role (read-only access to all Mystoreguard resources)
('role-msg-viewer-admin', 'system-tenant-id', 'Mystoreguard Viewer Admin', 'Viewer Admin for Mystoreguard - can view all Mystoreguard resources with GET permissions only', 'rt-subscribed-app-msg', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (tenant_id, role_name) DO UPDATE SET
    description      = EXCLUDED.description,
    resource_type_id = EXCLUDED.resource_type_id,
    is_system        = EXCLUDED.is_system,
    is_active        = EXCLUDED.is_active;