-- =====================================================
-- Mystoreguard Database Schema
-- =====================================================

-- CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE SCHEMA IF NOT EXISTS mystoreguard;

-- Set the search path to mystoreguard schema for this session
SET search_path TO mystoreguard;

-- =============================================
-- ROLE-PERMISSION MAPPINGS
-- =============================================

-- =============================================
-- CORE PLATFORM PERMISSIONS FOR ALL MYSTOREGUARD ROLES
-- These permissions are required for navigation: apps, businesses, organizations, subscribed apps, and app deployment management
-- =============================================

-- All Mystoreguard roles need these core platform permissions to navigate the system
-- Note: role-msg-admin is excluded as it gets all permissions via trigger
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id) VALUES
-- Core platform navigation permissions for all roles
('system-tenant-id', 'role-subscribed-app-msg-admin', 'permission-app-get'),
('system-tenant-id', 'role-subscribed-app-msg-admin', 'permission-business-get'),
('system-tenant-id', 'role-subscribed-app-msg-admin', 'permission-organization-get'),
('system-tenant-id', 'role-subscribed-app-msg-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-subscribed-app-msg-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-subscribed-app-msg-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-subscribed-app-msg-admin', 'permission-user-get-locations'),

-- Mystoreguard Admin: explicit permissions for Reports, Logs, and Expenses (resource types have parent null in DB, so trigger does not assign these)
('system-tenant-id', 'role-subscribed-app-msg-admin', 'permission-msg-reports-get'),
('system-tenant-id', 'role-subscribed-app-msg-admin', 'permission-msg-logs-get'),
('system-tenant-id', 'role-subscribed-app-msg-admin', 'permission-msg-logs-delete'),
('system-tenant-id', 'role-subscribed-app-msg-admin', 'permission-expense-create'),
('system-tenant-id', 'role-subscribed-app-msg-admin', 'permission-expense-get'),
('system-tenant-id', 'role-subscribed-app-msg-admin', 'permission-expense-update'),
('system-tenant-id', 'role-subscribed-app-msg-admin', 'permission-expense-delete'),
('system-tenant-id', 'role-subscribed-app-msg-admin', 'permission-expense-get-statistics'),

-- role-msg-admin (Admin) is only in cp_roles if 5_insert_role.sql was run; add same permissions for it via separate INSERT when that role exists

('system-tenant-id', 'role-msg-warehouse-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-store-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-store-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-store-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-store-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-store-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-store-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-store-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-clients-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-clients-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-clients-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-clients-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-clients-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-clients-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-clients-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-expenses-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-expenses-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-expenses-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-expenses-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-expenses-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-expenses-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-expenses-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-creditors-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-creditors-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-creditors-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-creditors-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-creditors-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-creditors-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-creditors-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-depositors-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-depositors-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-depositors-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-depositors-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-depositors-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-depositors-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-depositors-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-returns-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-returns-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-returns-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-returns-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-returns-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-returns-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-returns-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-invoice-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-invoice-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-invoice-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-invoice-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-invoice-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-invoice-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-invoice-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-suppliers-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-suppliers-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-suppliers-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-suppliers-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-suppliers-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-suppliers-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-suppliers-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-product-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-product-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-product-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-product-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-product-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-product-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-product-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-product-metadata-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-product-metadata-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-product-metadata-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-product-metadata-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-product-metadata-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-product-metadata-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-product-metadata-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-product-prices-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-product-prices-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-product-prices-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-product-prices-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-product-prices-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-product-prices-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-product-prices-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-pricing-rules-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-pricing-rules-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-pricing-rules-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-pricing-rules-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-pricing-rules-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-pricing-rules-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-pricing-rules-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-customers-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-customers-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-customers-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-customers-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-customers-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-customers-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-customers-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-file-manager-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-file-manager-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-file-manager-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-file-manager-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-file-manager-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-file-manager-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-file-manager-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-taxes-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-taxes-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-taxes-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-taxes-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-taxes-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-taxes-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-taxes-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-tax-rules-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-tax-rules-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-tax-rules-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-tax-rules-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-tax-rules-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-tax-rules-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-tax-rules-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-store-configs-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-store-configs-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-store-configs-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-store-configs-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-store-configs-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-store-configs-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-store-configs-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-store-sales-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-store-sales-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-store-sales-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-store-sales-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-store-sales-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-store-sales-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-store-sales-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-store-sales-personnel', 'permission-app-get'),
('system-tenant-id', 'role-msg-store-sales-personnel', 'permission-business-get'),
('system-tenant-id', 'role-msg-store-sales-personnel', 'permission-organization-get'),
('system-tenant-id', 'role-msg-store-sales-personnel', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-store-sales-personnel', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-store-sales-personnel', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-store-sales-personnel', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-reports-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-reports-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-reports-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-reports-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-reports-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-reports-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-reports-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-viewer-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-viewer-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-viewer-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-viewer-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-viewer-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-viewer-admin', 'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- role-msg-admin (Admin): same Reports/Logs/Expenses permissions when that role exists (inserted by 5_insert_role.sql)
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', 'role-msg-admin', x.permission_id
FROM (VALUES
  ('permission-msg-reports-get'),
  ('permission-msg-logs-get'),
  ('permission-msg-logs-delete'),
  ('permission-expense-create'),
  ('permission-expense-get'),
  ('permission-expense-update'),
  ('permission-expense-delete'),
  ('permission-expense-get-statistics')
) AS x(permission_id)
WHERE EXISTS (SELECT 1 FROM core_platform.cp_roles WHERE id = 'role-msg-admin')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =============================================
-- MODULE-SPECIFIC PERMISSIONS
-- Note: Store Sales roles have manual mappings (not using triggers)
-- Other admin roles will get their permissions via triggers based on resource_type_id
-- =============================================

-- Link Store Sales Admin role to its permissions (includes cancel and delete)
-- Also granted store-products-get so sales staff can view the shop's item catalog
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id) VALUES
('system-tenant-id', 'role-msg-store-sales-admin', 'permission-msg-store-sales-create'),
('system-tenant-id', 'role-msg-store-sales-admin', 'permission-msg-store-sales-get'),
('system-tenant-id', 'role-msg-store-sales-admin', 'permission-msg-store-sales-update'),
('system-tenant-id', 'role-msg-store-sales-admin', 'permission-msg-store-sales-cancel'),
('system-tenant-id', 'role-msg-store-sales-admin', 'permission-msg-store-sales-delete'),
('system-tenant-id', 'role-msg-store-sales-admin', 'permission-msg-store-products-get')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- Link Store Sales Personnel role to its permissions (create and get only)
-- Also granted store-products-get so sales staff can view the shop's item catalog
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id) VALUES
('system-tenant-id', 'role-msg-store-sales-personnel', 'permission-msg-store-sales-create'),
('system-tenant-id', 'role-msg-store-sales-personnel', 'permission-msg-store-sales-get'),
('system-tenant-id', 'role-msg-store-sales-personnel', 'permission-msg-store-products-get')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;
