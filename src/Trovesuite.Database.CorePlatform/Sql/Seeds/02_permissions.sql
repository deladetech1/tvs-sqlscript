
-- =====================================================
-- Core Platform Database Schema
-- =====================================================

-- CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE SCHEMA IF NOT EXISTS core_platform;

-- Set the search path to core_platform schema for this session
SET search_path TO core_platform;

-- Insert permissions

INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime) VALUES

-- =====================================================
-- BUSINESS PERMISSIONS
-- =====================================================
('permission-business-create', 'Business Create', 'rt-business', 'Create new businesses', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-business-update', 'Business Update', 'rt-business', 'Edit business information', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-business-delete', 'Business Delete', 'rt-business', 'Delete businesses (can be restored)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-business-get', 'Business Get', 'rt-business', 'View businesses', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-business-approve-deletion', 'Business Approve Deletion', 'rt-business', 'Approve or reject business deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-business-statistics-get', 'Business Statistics Get', 'rt-business', 'View business statistics and reports', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-business-restore', 'Business Restore', 'rt-business', 'Restore deleted businesses', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-business-permanent-delete', 'Business Permanent Delete', 'rt-business', 'Permanently delete businesses (cannot be undone)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-business-deletion-chat-history-get', 'Business Deletion Chat History Get', 'rt-business', 'View deletion approval comments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- =====================================================
-- GROUP PERMISSIONS
-- =====================================================
('permission-group-create', 'Group Create', 'rt-group', 'Create new groups', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-group-update', 'Group Update', 'rt-group', 'Edit group information', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-group-delete', 'Group Delete', 'rt-group', 'Delete groups (can be restored)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-group-get', 'Group Get', 'rt-group', 'View groups', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-group-statistics-get', 'Group Statistics Get', 'rt-group', 'View group statistics and reports', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-group-restore', 'Group Restore', 'rt-group', 'Restore deleted groups', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-group-permanent-delete', 'Group Permanent Delete', 'rt-group', 'Permanently delete groups (cannot be undone)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-group-approve-deletion', 'Group Approve Deletion', 'rt-group', 'Approve or reject group deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-group-deletion-chat-history-get', 'Group Deletion Chat History Get', 'rt-group', 'View deletion approval comments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-group-assign-roles', 'Group Assign Roles', 'rt-group', 'Assign roles to groups', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-group-remove-roles', 'Group Remove Roles', 'rt-group', 'Remove roles from groups', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-group-remove-users', 'Group Remove Users', 'rt-group', 'Remove users from groups', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-group-assign-locations', 'Group Assign Locations', 'rt-group', 'Assign locations to groups', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-group-remove-locations', 'Group Remove Locations', 'rt-group', 'Remove locations from groups', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-group-locations-get', 'Group Locations Get', 'rt-group', 'View group locations', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-group-add-users', 'Group Add Users', 'rt-group', 'Add users to groups', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- =====================================================
-- LOCATION PERMISSIONS
-- =====================================================
('permission-location-create', 'Location Create', 'rt-location', 'Create new locations', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-location-update', 'Location Update', 'rt-location', 'Edit location information', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-location-delete', 'Location Delete', 'rt-location', 'Delete locations (can be restored)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-location-get', 'Location Get', 'rt-location', 'View locations', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-location-approve-deletion', 'Location Approve Deletion', 'rt-location', 'Approve or reject location deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-location-statistics-get', 'Location Statistics Get', 'rt-location', 'View location statistics and reports', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-location-restore', 'Location Restore', 'rt-location', 'Restore deleted locations', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-location-permanent-delete', 'Location Permanent Delete', 'rt-location', 'Permanently delete locations (cannot be undone)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-location-deletion-chat-history-get', 'Location Deletion Chat History Get', 'rt-location', 'View deletion approval comments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- =====================================================
-- ORGANIZATION PERMISSIONS
-- =====================================================
('permission-organization-create', 'Organization Create', 'rt-organization', 'Create new organizations', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-organization-update', 'Organization Update', 'rt-organization', 'Edit organization information', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-organization-delete', 'Organization Delete', 'rt-organization', 'Delete organizations (can be restored)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-organization-get', 'Organization Get', 'rt-organization', 'View organizations', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-organization-approve-deletion', 'Organization Approve Deletion', 'rt-organization', 'Approve or reject organization deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-organization-statistics-get', 'Organization Statistics Get', 'rt-organization', 'View organization statistics and reports', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-organization-restore', 'Organization Restore', 'rt-organization', 'Restore deleted organizations', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-organization-permanent-delete', 'Organization Permanent Delete', 'rt-organization', 'Permanently delete organizations (cannot be undone)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-organization-deletion-chat-history-get', 'Organization Deletion Chat History Get', 'rt-organization', 'View deletion approval comments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- =====================================================
-- APP PERMISSIONS
-- =====================================================
('permission-app-create', 'App Create', 'rt-app', 'Create new apps', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-app-update', 'App Update', 'rt-app', 'Edit app information', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-app-delete', 'App Delete', 'rt-app', 'Delete apps (can be restored)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-app-get', 'App Get', 'rt-app', 'View apps', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-app-approve-deletion', 'App Approve Deletion', 'rt-app', 'Approve or reject app deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-app-statistics-get', 'App Statistics Get', 'rt-app', 'View app statistics and reports', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-app-restore', 'App Restore', 'rt-app', 'Restore deleted apps', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-app-permanent-delete', 'App Permanent Delete', 'rt-app', 'Permanently delete apps (cannot be undone)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-app-deletion-chat-history-get', 'App Deletion Chat History Get', 'rt-app', 'View deletion approval comments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- =====================================================
-- PERMISSION PERMISSIONS
-- =====================================================
('permission-permission-get', 'Permission Get', 'rt-permission', 'View permissions', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- =====================================================
-- ROLE PERMISSIONS
-- =====================================================
('permission-role-create', 'Role Create', 'rt-role', 'Create new roles', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-role-update', 'Role Update', 'rt-role', 'Edit roles', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-role-delete', 'Role Delete', 'rt-role', 'Delete roles', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-role-get', 'Role Get', 'rt-role', 'View roles', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-role-approve-deletion', 'Role Approve Deletion', 'rt-role', 'Approve or reject role deletion requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-role-statistics-get', 'Role Statistics Get', 'rt-role', 'View role statistics and reports', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-role-restore', 'Role Restore', 'rt-role', 'Restore deleted roles', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-role-permanent-delete', 'Role Permanent Delete', 'rt-role', 'Permanently delete roles (cannot be undone)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-role-deletion-chat-history-get', 'Role Deletion Chat History Get', 'rt-role', 'View deletion approval comments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- =====================================================
-- SETTINGS PERMISSIONS (covers Unit of Measure, Currency, Password Policy, MFA Settings, Change Password Policy)
-- =====================================================
('permission-settings-create', 'Settings Create', 'rt-setting', 'Create new settings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-settings-update', 'Settings Update', 'rt-setting', 'Edit settings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-settings-delete', 'Settings Delete', 'rt-setting', 'Delete settings (can be restored)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-settings-get', 'Settings Get', 'rt-setting', 'View settings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-settings-restore', 'Settings Restore', 'rt-setting', 'Restore deleted settings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-settings-permanent-delete', 'Settings Permanent Delete', 'rt-setting', 'Permanently delete settings (cannot be undone)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-settings-statistics-get', 'Settings Statistics Get', 'rt-setting', 'View settings statistics and reports', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
--
('permission-currency-get', 'Currency Get', 'rt-setting', 'View and list currencies - available to all users by default', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- =====================================================
-- SUBSCRIPTION PERMISSIONS
-- =====================================================
('permission-subscription-get', 'Subscription Get', 'rt-subscription', 'View subscription plan', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-subscription-update', 'Subscription Update', 'rt-subscription', 'Change subscription plan', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- =====================================================
-- BUSINESS APP PERMISSIONS
-- =====================================================
('permission-business-app-subscribe', 'Business App Subscribe', 'rt-business-app', 'Subscribe to apps', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-business-app-unsubscribe', 'Business App Unsubscribe', 'rt-business-app', 'Unsubscribe from apps', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-business-app-get', 'Business App Get', 'rt-business-app', 'View available apps and subscriptions', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-business-app-get-locations', 'Business App Get Locations', 'rt-business-app', 'View app deployment locations', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-business-app-deploy-locations', 'Business App Deploy Locations', 'rt-business-app', 'Deploy apps to locations', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-business-app-remove-locations', 'Business App Remove Locations', 'rt-business-app', 'Remove apps from locations', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- =====================================================
-- USER PERMISSIONS
-- =====================================================
('permission-user-create', 'User Create', 'rt-user', 'Create new users', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-update', 'User Update', 'rt-user', 'Edit other users', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-delete', 'User Delete', 'rt-user', 'Delete users', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-get', 'User Get', 'rt-user', 'View other users', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-get-locations', 'User Get Locations', 'rt-user', 'View user location details', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-get-own', 'User Get Own Profile', 'rt-user', 'View own profile', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-update-own', 'User Update Own Profile', 'rt-user', 'Edit own profile', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-grant-access', 'User Grant Access', 'rt-user', 'Give users access', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-revoke-access', 'User Revoke Access', 'rt-user', 'Remove user access', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-add-to-groups', 'User Add to Groups', 'rt-user', 'Add users to groups', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-remove-from-groups', 'User Remove from Groups', 'rt-user', 'Remove users from groups', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-assign-roles', 'User Assign Roles', 'rt-user', 'Assign roles to users', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-remove-roles', 'User Remove Roles', 'rt-user', 'Remove roles from users', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-assign-locations', 'User Assign Locations', 'rt-user', 'Assign locations to users', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-remove-locations', 'User Remove Locations', 'rt-user', 'Remove locations from users', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-locations-get', 'User Locations Get', 'rt-user', 'View other users locations', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-locations-get-own', 'User Locations Get Own', 'rt-user', 'View own locations', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-statistics-get', 'User Statistics Get', 'rt-user', 'View user statistics and reports', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-restore', 'User Restore', 'rt-user', 'Restore deleted users', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-permanent-delete', 'User Permanent Delete', 'rt-user', 'Permanently delete users (cannot be undone)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-deletion-chat-history-get', 'User Deletion Chat History Get', 'rt-user', 'View deletion approval comments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-groups-get', 'User Groups Get', 'rt-user', 'View other users groups', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-groups-get-own', 'User Groups Get Own', 'rt-user', 'View own groups', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-roles-get', 'User Roles Get', 'rt-user', 'View other users roles', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-roles-get-own', 'User Roles Get Own', 'rt-user', 'View own roles', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-login-settings-get', 'User Login Settings Get', 'rt-user', 'View login settings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-login-settings-update', 'User Login Settings Update', 'rt-user', 'Change login settings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-reset-password', 'User Reset Password', 'rt-user', 'Reset other users passwords', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-change-password', 'User Change Password', 'rt-user', 'Change own password', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-upload-profile-picture', 'User Upload Profile Picture', 'rt-user', 'Upload profile picture', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-user-resource-types-with-roles-get', 'User Resource Types with Roles Get', 'rt-user', 'View resource types and roles', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- =====================================================
-- THEME PERMISSIONS
-- =====================================================
('permission-theme-get', 'Theme Get', 'rt-theme', 'View theme', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-theme-update', 'Theme Update', 'rt-theme', 'Change theme', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- =====================================================
-- EXPENSE PERMISSIONS
-- =====================================================
('permission-expense-create', 'Expense Create', 'rt-expenses', 'Can create new expenses', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-expense-update', 'Expense Update', 'rt-expenses', 'Can update expenses', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-expense-get', 'Expense Get', 'rt-expenses', 'Can get expense details', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-expense-delete', 'Expense Delete', 'rt-expenses', 'Can permanently delete expenses', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-expense-get-statistics', 'Expense Get Statistics', 'rt-expenses', 'Can get expense statistics', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- =====================================================
-- FILE PERMISSIONS
-- =====================================================
('permission-cp-file-upload-multiple', 'Core Platform File Upload Multiple', 'rt-file', 'Can upload multiple files', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-cp-file-update', 'Core Platform File Update', 'rt-file', 'Can update files', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-cp-file-delete', 'Core Platform File Delete', 'rt-file', 'Can delete files', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-cp-file-list-documents', 'Core Platform File List Documents', 'rt-file', 'Can list and view documents', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- =====================================================
-- BILLING PERMISSIONS
-- =====================================================
('permission-billing-create', 'Billing Create', 'rt-billing', 'Create new billing records', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-billing-delete', 'Billing Delete', 'rt-billing', 'Delete billing records (can be restored)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-billing-get', 'Billing Get', 'rt-billing', 'View billing records', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-billing-statistics-get', 'Billing Statistics Get', 'rt-billing', 'View billing statistics and reports', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-billing-restore', 'Billing Restore', 'rt-billing', 'Restore deleted billing records', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-billing-make-payment', 'Billing Make Payment', 'rt-billing', 'Make payments for billing records', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- =====================================================
-- LOGS PERMISSIONS (using core platform rt-logs resource type)
-- Unified logs permissions - replaces individual entity activity log permissions
-- =====================================================
('permission-cp-logs-get', 'Core Platform Logs Get', 'rt-logs', 'Can view, list, and read activity logs', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-cp-logs-delete', 'Core Platform Logs Delete', 'rt-logs', 'Can delete activity logs', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)

ON CONFLICT (id) DO NOTHING;