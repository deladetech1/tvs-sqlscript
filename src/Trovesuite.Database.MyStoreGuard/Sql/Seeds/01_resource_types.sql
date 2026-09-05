-- =====================================================
-- Mystoreguard Database Schema
-- =====================================================

-- CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE SCHEMA IF NOT EXISTS mystoreguard;

-- Set the search path to mystoreguard schema for this session
SET search_path TO mystoreguard;

-- Insert resource types into core_platform schema (shared across all modules)
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES

-- MSG APP Start Here
('rt-subscribed-app-msg', 'MSG APP', 'MSG Subscribed APP', null),
('rt-warehouse', 'Warehouse', 'Warehouse management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-shop', 'Store', 'Store management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-expenses', 'Expenses', 'Expenses management for Mystoreguard', 'rt-subscribed-app-msg'),
-- Removed rt-creditors / rt-depositors / rt-returns: placeholder resource types for features that were never built (cleaned up in Seeds/04_others.sql)
-- Removed rt-clients for the same reason, one step further along: clients got as far as a
-- controller and a service, but the router was never mounted, no msg_clients table was ever
-- created, and MSG_CLIENTS_TABLE is not a setting that exists — so every one of those
-- endpoints was unreachable, and would have raised on the table name if it weren't.
-- Its role and permissions are dropped alongside it in Seeds/04_others.sql.
('rt-invoice', 'Invoice', 'Invoice management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-sales', 'Sales', 'Sales management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-suppliers', 'Suppliers', 'Suppliers management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-product', 'Products', 'Products management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-product-metadata', 'Product Metadata', 'Product Metadata management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-product-prices', 'Product Prices', 'Product Prices management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-pricing-rules', 'Pricing Rules', 'Pricing Rules management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-customers', 'Customers', 'Customers management for Mystoreguard', 'rt-subscribed-app-msg'),
-- Loyalty was built with tables, services and five screens, and never given permissions of
-- its own — every one of its endpoints checked permission-msg-customers-*, so anyone who
-- could read a customer could read the whole loyalty programme, and there was no way to
-- separate the two because the distinction did not exist.
('rt-loyalty', 'Loyalty', 'Loyalty programme (points, tiers, rules, segments and campaigns) for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-file-manager', 'File Manager', 'File Manager for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-taxes', 'Taxes', 'Taxes management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-tax-rules', 'Tax Rules', 'Tax Rules management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-store-configs', 'Store Configs', 'Store Configs management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-warehouse-configs', 'Warehouse Configs', 'Warehouse Configs management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-store-products', 'Store Products', 'Store Products management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-warehouse-products', 'Warehouse Products', 'Warehouse Products management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-purchase-orders', 'Purchase Orders', 'Purchase Orders management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-purchase-receipts', 'Purchase Receipts', 'Purchase Receipts management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-product-batch', 'Product Batch', 'Product Batch management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-product-split', 'Product Split', 'Product split (break-bulk) management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-product-movement', 'Product Movement', 'Product Movement management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-stock-takes', 'Stock Takes', 'Manual stock taking (count, investigate, resolve) for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-appointments', 'Appointments', 'Appointments management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-tasks', 'Tasks', 'Tasks and multi-step workflow management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-store-transfers', 'Store Transfers', 'Store Transfers management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-warehouse-transfers', 'Warehouse Transfers', 'Warehouse Transfers management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-store-sales', 'Store Sales', 'Store Sales management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-gift-cards', 'Gift Cards', 'Gift Cards management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-promo-codes', 'Promo Codes', 'Promo Codes management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-affiliates', 'Affiliates', 'Affiliates management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-deliveries', 'Deliveries', 'Deliveries management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-installment-policies', 'Installment Policies', 'Installment Policies management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-installment-plans', 'Installment Plans', 'Installment plans, schedules and collections for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-guarantors', 'Guarantors', 'Guarantors backing installment plans for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-return-policies', 'Return Policies', 'Return Policies management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-store-returns', 'Store Returns', 'Store Returns management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-reports', 'Mystoreguard Reports', 'Centralized reporting and analytics module for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-estimate-template', 'Estimate Template', 'Estimate template (per-domain blueprint) management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-estimate', 'Estimate', 'Estimate management for Mystoreguard', 'rt-subscribed-app-msg'),
-- Backdating sales is a standalone capability, deliberately NOT under rt-store-sales:
-- the auto-assign triggers would otherwise hand it to every Store Sales role. Its own
-- resource type keeps it grantable to one named person via role-msg-store-sales-backdate.
('rt-store-sales-backdate', 'Store Sales Backdate', 'Permission to set a past occurrence date when creating a sale in Mystoreguard', 'rt-subscribed-app-msg'),
-- Same reasoning for receiving stock against a past date: kept out of rt-purchase-orders
-- so the auto-assign triggers do not hand it to everyone who can receive a delivery.
('rt-purchase-orders-backdate', 'Purchase Orders Backdate', 'Permission to date received stock to the day it actually arrived in Mystoreguard', 'rt-subscribed-app-msg'),
-- One resource type for the whole storefront, not one per screen. Setup, images,
-- versions and the home page are four views of a single decision — what the public
-- sees — and someone trusted with any of them is trusted with the rest. Splitting it
-- would mean four roles that are only ever granted together.
('rt-ecommerce', 'Ecommerce', 'Ecommerce storefront configuration, products, versions and promotion for Mystoreguard', 'rt-subscribed-app-msg')

ON CONFLICT (id) DO UPDATE SET
    resource_type_name = EXCLUDED.resource_type_name,
    description        = EXCLUDED.description,
    parent_resource_id = EXCLUDED.parent_resource_id;