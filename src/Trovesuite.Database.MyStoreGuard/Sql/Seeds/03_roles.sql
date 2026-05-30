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
('role-msg-clients-admin', 'system-tenant-id', 'Mystoreguard Clients Admin', 'Administrator for clients management', 'rt-clients', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-expenses-admin', 'system-tenant-id', 'Mystoreguard Expenses Admin', 'Administrator for expenses management', 'rt-expenses', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
-- Removed creditors/depositors/returns admin roles: placeholder roles for features that were never built (cleaned up in 04_others.sql)
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
('role-msg-return-policies-admin', 'system-tenant-id', 'Mystoreguard Return Policies Admin', 'Administrator for return policies management', 'rt-return-policies', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-store-returns-admin', 'system-tenant-id', 'Mystoreguard Store Returns Admin', 'Administrator for store returns management with full access including approve and process', 'rt-store-returns', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-reports-admin', 'system-tenant-id', 'Mystoreguard Reports Admin', 'Administrator for reports and analytics management', 'rt-reports', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Viewer Admin Role (read-only access to all Mystoreguard resources)
('role-msg-viewer-admin', 'system-tenant-id', 'Mystoreguard Viewer Admin', 'Viewer Admin for Mystoreguard - can view all Mystoreguard resources with GET permissions only', 'rt-subscribed-app-msg', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (tenant_id, role_name) DO UPDATE SET
    description      = EXCLUDED.description,
    resource_type_id = EXCLUDED.resource_type_id,
    is_system        = EXCLUDED.is_system,
    is_active        = EXCLUDED.is_active;