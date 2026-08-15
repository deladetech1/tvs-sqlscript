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

-- Removed: role-msg-creditors-admin, role-msg-depositors-admin, role-msg-returns-admin
-- These were placeholder roles for features that were never built (no controllers, routes,
-- or feature-specific permissions anywhere in the codebase). The roles, their resource types,
-- and any leftover rows are dropped in the cleanup block at the end of this file.

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

('system-tenant-id', 'role-msg-store-sales-backdate', 'permission-app-get'),
('system-tenant-id', 'role-msg-store-sales-backdate', 'permission-business-get'),
('system-tenant-id', 'role-msg-store-sales-backdate', 'permission-organization-get'),
('system-tenant-id', 'role-msg-store-sales-backdate', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-store-sales-backdate', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-store-sales-backdate', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-store-sales-backdate', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-reports-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-reports-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-reports-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-reports-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-reports-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-reports-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-reports-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-return-policies-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-return-policies-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-return-policies-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-return-policies-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-return-policies-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-return-policies-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-return-policies-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-store-returns-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-store-returns-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-store-returns-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-store-returns-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-store-returns-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-store-returns-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-store-returns-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-tasks-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-tasks-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-tasks-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-tasks-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-tasks-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-tasks-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-tasks-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-estimate-template-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-estimate-template-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-estimate-template-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-estimate-template-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-estimate-template-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-estimate-template-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-estimate-template-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-estimate-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-estimate-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-estimate-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-estimate-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-estimate-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-estimate-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-estimate-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-stock-takes-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-stock-takes-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-stock-takes-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-stock-takes-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-stock-takes-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-stock-takes-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-stock-takes-admin', 'permission-user-get-locations'),

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

-- Link Sales Backdate role to its single capability permission.
-- The role-insert trigger already does this (rt-store-sales-backdate has exactly one
-- permission), but state it explicitly so the grant survives if triggers are ever disabled.
-- Deliberately NOT granted store-sales-create/get: this role is additive to a sales role.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id) VALUES
('system-tenant-id', 'role-msg-store-sales-backdate', 'permission-msg-store-sales-backdate')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- Backfill the backdate permission for the roles that could already backdate before it existed
-- (the role-based allow-list in the backend: Owner, Admin, and the two MSG admin roles), so the
-- switch to a permission check is not a regression on databases seeded before this change.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT r.tenant_id, r.id, 'permission-msg-store-sales-backdate'
FROM core_platform.cp_roles r
WHERE r.id IN ('role-owner', 'role-admin', 'role-msg-admin', 'role-subscribed-app-msg-admin')
   OR r.role_name IN ('Owner', 'Admin')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- Link Store Admin role (rt-shop) to all store-domain permissions.
-- The auto-assign trigger cannot reach these: store permissions live under sibling
-- resource types (rt-store-products, rt-store-transfers, etc.), not children of rt-shop,
-- so they must be mapped manually (same approach as Store Sales above).
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id) VALUES
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-store-config-create'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-store-config-get'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-store-products-create'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-store-products-get'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-store-products-update'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-store-products-delete'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-store-transfers-create'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-store-transfers-approve'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-store-transfers-get'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-store-transfers-update'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-store-transfers-delete'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-store-sales-create'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-store-sales-get'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-store-sales-update'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-store-sales-cancel'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-store-sales-delete'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-store-returns-create'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-store-returns-get'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-store-returns-update'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-store-returns-approve'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-stock-takes-create'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-stock-takes-get'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-stock-takes-resolve'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-stock-takes-reverse'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-stock-takes-delete')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- Link Warehouse Admin role (rt-warehouse) to all warehouse-domain permissions.
-- Same reasoning as Store Admin: warehouse permissions live under sibling resource types
-- (rt-warehouse-configs, rt-warehouse-products, rt-warehouse-transfers), not children of
-- rt-warehouse, so the trigger never attaches them — map manually.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id) VALUES
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-msg-warehouse-config-create'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-msg-warehouse-config-get'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-msg-warehouse-products-create'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-msg-warehouse-products-get'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-msg-warehouse-products-update'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-msg-warehouse-products-delete'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-msg-warehouse-transfers-create'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-msg-warehouse-transfers-approve'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-msg-warehouse-transfers-get'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-msg-warehouse-transfers-update'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-msg-warehouse-transfers-delete'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-msg-stock-takes-create'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-msg-stock-takes-get'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-msg-stock-takes-resolve'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-msg-stock-takes-reverse'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-msg-stock-takes-delete')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- Let every role that picks products read the product metadata used to filter them.
-- The badge filter above each product picker (sales, invoices, purchase orders,
-- product split, stock take, adding store/warehouse items) lists metadata from
-- /product-metadata/list, which requires permission-msg-product-metadata-get. That
-- permission lives under rt-product-metadata, so the auto-assign trigger only ever
-- gives it to role-msg-product-metadata-admin — every other role got a 403 and the
-- filter silently rendered empty, looking like a missing feature rather than a
-- blocked one. Read-only access to what is effectively reference data.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id) VALUES
('system-tenant-id', 'role-msg-store-sales-admin', 'permission-msg-product-metadata-get'),
('system-tenant-id', 'role-msg-store-sales-personnel', 'permission-msg-product-metadata-get'),
('system-tenant-id', 'role-msg-invoice-admin', 'permission-msg-product-metadata-get'),
('system-tenant-id', 'role-msg-product-admin', 'permission-msg-product-metadata-get'),
('system-tenant-id', 'role-msg-store-admin', 'permission-msg-product-metadata-get'),
('system-tenant-id', 'role-msg-warehouse-admin', 'permission-msg-product-metadata-get'),
('system-tenant-id', 'role-msg-stock-takes-admin', 'permission-msg-product-metadata-get'),
('system-tenant-id', 'role-msg-suppliers-admin', 'permission-msg-product-metadata-get')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =============================================
-- CLEANUP: remove dead placeholder roles & resource types (creditors / depositors / returns)
-- These features were never implemented (no controllers, routes, or feature permissions).
-- Idempotent: re-running on a clean database is a harmless no-op.
-- Deleted child-first to respect foreign keys: assignments -> role_permissions -> roles -> resource_types.
-- =============================================
DELETE FROM core_platform.cp_assign_roles
WHERE role_id IN ('role-msg-creditors-admin', 'role-msg-depositors-admin', 'role-msg-returns-admin');

DELETE FROM core_platform.cp_role_permissions
WHERE role_id IN ('role-msg-creditors-admin', 'role-msg-depositors-admin', 'role-msg-returns-admin');

DELETE FROM core_platform.cp_roles
WHERE id IN ('role-msg-creditors-admin', 'role-msg-depositors-admin', 'role-msg-returns-admin');

DELETE FROM core_platform.cp_resource_types
WHERE id IN ('rt-creditors', 'rt-depositors', 'rt-returns');

-- =============================================
-- RENAME: permission-msg-stock-takes-view -> permission-msg-stock-takes-get
-- The permission id changed, so the upsert in 02_permissions.sql inserts the new
-- row but cannot rename the old one on already-seeded databases. Carry any existing
-- role grants over to the new id (preserves access for custom/tenant roles), then
-- drop the obsolete permission and its grants. Idempotent; no-op on a clean database.
-- Deleted child-first: cp_role_permissions (FK -> cp_permissions, RESTRICT) before cp_permissions.
-- =============================================
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT tenant_id, role_id, 'permission-msg-stock-takes-get'
FROM core_platform.cp_role_permissions
WHERE permission_id = 'permission-msg-stock-takes-view'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

DELETE FROM core_platform.cp_role_permissions
WHERE permission_id = 'permission-msg-stock-takes-view';

DELETE FROM core_platform.cp_permissions
WHERE id = 'permission-msg-stock-takes-view';
