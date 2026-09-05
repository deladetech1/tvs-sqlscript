-- Set the search path to core_platform schema for this session
SET search_path TO core_platform;

-- System tenant is now created in 5_insert_role.sql (before roles are inserted)

-- Note: Role-permission mappings are handled automatically by triggers
-- Only the default role mapping is defined here for the system default group

-- Link User Profile role to permissions (self-service permissions for regular users)
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id) VALUES
('system-tenant-id', 'role-default-group', 'permission-user-get-own'),
('system-tenant-id', 'role-default-group', 'permission-user-update-own'),
('system-tenant-id', 'role-default-group', 'permission-user-groups-get-own'),
('system-tenant-id', 'role-default-group', 'permission-user-roles-get-own'),
('system-tenant-id', 'role-default-group', 'permission-user-login-settings-get'),
('system-tenant-id', 'role-default-group', 'permission-user-login-settings-update'),
('system-tenant-id', 'role-default-group', 'permission-user-change-password'),
('system-tenant-id', 'role-default-group', 'permission-user-upload-profile-picture'),
('system-tenant-id', 'role-default-group', 'permission-user-locations-get-own'),
('system-tenant-id', 'role-default-group', 'permission-theme-get'),
('system-tenant-id', 'role-default-group', 'permission-theme-update'),
('system-tenant-id', 'role-default-group', 'permission-business-app-get'),
('system-tenant-id', 'role-default-group', 'permission-currency-get')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;
-- cp_role_permissions has no data columns worth overwriting (pure many-to-many), keep DO NOTHING.

-- Business App Admin needs to read the current app subscription when opening
-- the appstore Subscribe modal (the tier picker hides itself if a tier already
-- exists for this (tenant, app)). The trigger-based auto-assignment only gives
-- this role rt-business-app permissions, so we grant subscription-get explicitly.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id) VALUES
('system-tenant-id', 'role-business-app-admin', 'permission-subscription-get')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =============================================
-- CORE PLATFORM ADMIN: every Core Platform permission, and nothing from any app
-- =============================================
-- Granted here rather than by a trigger. The resource-type trigger hands a role only the
-- permissions of its own resource type, and this role spans all twenty of them; the
-- alternative was a fourth bespoke trigger function beside the three already in
-- Triggers/01_auto_assign_permissions.sql, each of which has to be edited in two places to
-- stay complete. A SELECT states the rule once, and because seeds re-run on every deploy it
-- picks up Core Platform permissions added later without anyone remembering to.
--
-- The boundary is the permission's own namespace, NOT its resource type. Resource types look
-- like the obvious test and are the wrong one: rt-expenses and rt-file are Core Platform
-- resource types that MyStoreGuard and LoanDrift re-parent under their own rt-subscribed-app-%
-- when their seeds run. A parentage test would therefore include permission-expense-* and
-- permission-cp-file-* on a fresh database — this file runs before the apps re-parent anything
-- — and exclude them on the next deploy, when it runs after. Same seeds, two different roles.
--
-- Every app permission is prefixed with its app (permission-msg-, permission-loandrift-,
-- permission-zeloshr-) and no Core Platform permission is, so the namespace says plainly what
-- the hierarchy only implies, and says the same thing whenever it is asked. A new app means
-- adding a line here — as it means adding lines in a dozen other places.
--
-- Deleting activity logs is withheld: an administrator who can erase the record of what they
-- did is not one the record can be trusted about. Reading them is included.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', 'role-cp-admin', p.id
FROM core_platform.cp_permissions p
WHERE p.id NOT LIKE 'permission-msg-%'
  AND p.id NOT LIKE 'permission-loandrift-%'
  AND p.id NOT LIKE 'permission-zeloshr-%'
  AND p.id <> 'permission-cp-logs-delete'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =============================================
-- NAVIGATION PERMISSIONS FOR EVERY CORE PLATFORM ADMIN ROLE
-- =============================================
-- Nothing in this platform sits on its own: a location belongs to a business,
-- a business to an organization, and every screen begins by asking which one
-- you are standing in. The auto-assign trigger only ever hands a role the
-- permissions of its OWN resource type, so a Location Admin could administer
-- locations but could not list the businesses they belong to — the picker at
-- the top of the page came back empty and the screen had nothing to show.
--
-- Every app role (MyStoreGuard, LoanDrift, ZelosHR) has been granted this same
-- block in its own 04_others.sql since the beginning, for exactly this reason.
-- The core platform's own roles never were. Read-only, and the floor below
-- which a role cannot navigate at all.
--
-- Three more permissions belong to this floor — business-app-get,
-- user-change-password and user-get-own — and are deliberately NOT repeated
-- here: every user is put in sysgrp-default-group, whose role-default-group
-- already grants all three (see above). Granting them again would be duplicating
-- a floor that is already under everybody.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', r.id, p.permission_id
FROM core_platform.cp_roles r
CROSS JOIN (VALUES
  ('permission-business-get'),
  ('permission-organization-get'),
  ('permission-business-app-get-locations'),
  ('permission-user-get-locations'),
  -- The App Store is where a person chooses which app to open, and it is gated on this: the
  -- page asks hasAnyPermissionForResource("app"), which only permission-app-* satisfies.
  -- Every app role has been given it since the beginning; the platform's own roles never
  -- were, so a Location Admin signing in met Unauthorized where the list of apps belongs.
  ('permission-app-get')
) AS p(permission_id)
WHERE r.tenant_id = 'system-tenant-id'
  AND r.is_system = true
  -- Owner and Admin already hold everything via their own triggers, and
  -- role-default-group is the self-service floor itself, not an admin role.
  AND r.id NOT IN ('role-owner', 'role-admin', 'role-default-group')
  -- App roles seed this block themselves, alongside the app-store permissions
  -- they also need. Left to them so each app keeps one place to look.
  AND r.resource_type_id NOT LIKE 'rt-subscribed-app-%'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =============================================
-- CLEANUP: business-app-subscribe belongs to whoever manages subscriptions, not to everybody
-- =============================================
-- It had been travelling inside the navigation block every app role is given, so 64 seeded
-- roles held it — a cashier, a stock counter, a loan officer. It is not navigation. It is
-- the call that picks a paid tier out of cp_app_tier_configs and can spend the tenant's
-- one free-trial window.
--
-- Nothing was ever exposed by it: /business-apps/subscribe checks the permission and then
-- checks the caller's role against a hard-coded list of role-owner and role-admin, so every
-- other caller was refused at the second gate. That is the problem. The grant did nothing, so it read as
-- an ability people had, and the only thing standing behind it was a list of role ids that
-- somebody will one day, quite reasonably, replace with the permission check in front of it.
-- Removing it now means that day is uneventful.
--
-- Three roles keep it, and all three receive it from a trigger rather than a seeded row —
-- so there is nothing to re-grant here:
--   role-owner              every permission, by the Owner trigger
--   role-admin              every non-log permission, by the Admin trigger
--   role-business-app-admin its resource type IS rt-business-app; this is its whole job
--
-- Tenant-created roles are left alone: is_system = false means somebody ticked that box on
-- purpose, and this is not the place to overrule them.
--
-- Idempotent. Safe to re-run.
DELETE FROM core_platform.cp_role_permissions rp
USING core_platform.cp_roles r
WHERE rp.role_id = r.id
  AND rp.permission_id = 'permission-business-app-subscribe'
  AND r.is_system = true
  AND r.id NOT IN ('role-owner', 'role-admin')
  AND (r.resource_type_id IS DISTINCT FROM 'rt-business-app');

-- =============================================
-- NOTE: permission-app-get is load-bearing after all
-- =============================================
-- It was briefly retired here on the grounds that no endpoint checks it. No endpoint does —
-- but the App Store page does, and that is where somebody chooses which app to open. The
-- check is written hasAnyPermissionForResource("app"), which builds the id at runtime, so
-- grepping the frontends for the literal "permission-app-get" found nothing and the
-- conclusion drawn from that was wrong. Removing it left every role except Owner, Admin and
-- App Admin looking at Unauthorized where the list of apps should be.
--
-- The grants are back in each app's own seed file. Nothing to do here; this note exists so
-- the next person to notice it is enforced by no router does not reach the same conclusion.

-- Then insert into cp_groups
INSERT INTO core_platform.cp_groups (id, tenant_id, group_name, description, is_active, is_system, cdate, ctime, cdatetime) VALUES
('sysgrp-default-group', 'system-tenant-id', 'Default Group', 'Default system group for all users - provides basic self-service permissions', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (tenant_id, group_name) DO UPDATE SET
    description = EXCLUDED.description,
    is_active   = EXCLUDED.is_active,
    is_system   = EXCLUDED.is_system;

-- Assign User Profile role to User Profile system group
-- Now using cp_assign_roles table with is_system=true instead of separate system_assign_roles table
INSERT INTO core_platform.cp_assign_roles (tenant_id, group_id, role_id, resource_type, is_active, is_system, cdate, ctime, cdatetime) VALUES
('system-tenant-id', 'sysgrp-default-group', 'role-default-group', 'system-group', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (tenant_id, group_id, role_id) DO UPDATE SET
    resource_type = EXCLUDED.resource_type,
    is_active     = EXCLUDED.is_active,
    is_system     = EXCLUDED.is_system;

-- INSERT INTO SUBSCRIPTION TABLE --
INSERT INTO core_platform.cp_subscriptions (id, subscription_name, description, cdate, ctime, cdatetime) VALUES
('shared-subscription-enterprise', 'ENTERPRISE', 'Enterprise subscription', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('shared-subscription-premium', 'PREMIUM', 'Premium subscription', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('shared-subscription-advance', 'ADVANCE', 'Advance subscription', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('shared-subscription-basic', 'BASIC', 'Basic subscription', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET
    subscription_name = EXCLUDED.subscription_name,
    description       = EXCLUDED.description;

-- INSERT INTO APPS TABLE --
INSERT INTO core_platform.cp_apps (id, app_name, feature1, feature2, feature3, feature4, feature5, description, cdate, ctime, cdatetime, status, is_active) VALUES
('app-mystoreguard', 'MYSTOREGUARD', 'Point of Sale', 'Inventory Management', 'Sales Analytics', 'Customer Management', 'Receipt Printing', 'Complete POS solution for retail businesses with inventory tracking, sales reporting, and customer management', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP, 'live', true),
('app-loandrift', 'LOANDRIFT', 'Loan Application', 'Credit Scoring', 'Approval Workflow', 'Payment Tracking', 'Document Management', 'Comprehensive loan approval system with automated credit scoring, multi-stage approval workflows, and payment tracking', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP, 'live', true),
('app-zeloshr', 'ZELOSHR', 'Employee Management', 'Leave & Attendance', 'Org Structure', 'Onboarding & Recruitment', 'Performance Reviews', 'Complete HR platform for employee records, org structure, leave and attendance, onboarding, recruitment, and performance management', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP, 'live', true),
('app-accounting', 'ACCOUNTING', 'General Ledger', 'Accounts Payable', 'Accounts Receivable', 'Financial Reporting', 'Tax Management', 'Comprehensive accounting system with chart of accounts, AP/AR modules, financial reporting, and tax compliance support', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP, 'coming_soon', false),
('app-payroll', 'PAYROLL', 'Employee Payroll', 'Salary Processing', 'Tax Deductions', 'Payslip Generation', 'Compliance Management', 'Complete payroll management system for salary computation, payslip generation, tax deductions, and statutory compliance tracking', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP, 'coming_soon', false),
('app-hams', 'HAMS', 'Hospital Management', 'Patient Records', 'Appointment Scheduling', 'Billing System', 'Inventory Control', 'Comprehensive hospital management system for patient care, appointments, billing, and medical inventory tracking', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP, 'coming_soon', false)
ON CONFLICT (id) DO UPDATE SET
    app_name    = EXCLUDED.app_name,
    feature1    = EXCLUDED.feature1,
    feature2    = EXCLUDED.feature2,
    feature3    = EXCLUDED.feature3,
    feature4    = EXCLUDED.feature4,
    feature5    = EXCLUDED.feature5,
    description = EXCLUDED.description,
    status      = EXCLUDED.status,
    is_active   = EXCLUDED.is_active;

-- INSERT INTO APP TIER CONFIGS (caps + pricing per (app, tier)) --
-- max_login_users is a per-(business, app) SEAT cap, separate from the tenant-wide
-- account cap in cp_subscription_platform_limits. Keep MyStoreGuard BASIC at 5 to
-- match that plan's 5 users: a lower number here means an account a tenant is
-- entitled to create simply cannot sign in to the app, which reads as a bug.
--
-- Retire the pre-rename `tier-cfg-hr-*` rows first. On an environment that was
-- already seeded under `app-hr`, the 20260706 rename repointed those rows to
-- app-zeloshr but kept their old ids, so the zeloshr rows below collide with
-- them on ix_cp_app_tier_configs_app_id_subscription_id — and ON CONFLICT (id)
-- cannot see that conflict. Seeds run before migrations/shared, so the cleanup
-- has to live here or the deploy dies before the shared SQL gets a turn.
-- Nothing references cp_app_tier_configs.id (every reader joins on
-- app_id + subscription_id), and the rows are re-created immediately below, so
-- deleting them is safe. No-op on a fresh or already-reconciled DB.
DELETE FROM core_platform.cp_app_tier_configs WHERE id LIKE 'tier-cfg-hr-%';

INSERT INTO core_platform.cp_app_tier_configs (id, app_id, subscription_id, max_login_users, price, rate, cdate, ctime, cdatetime) VALUES
('tier-cfg-msg-basic',      'app-mystoreguard', 'shared-subscription-basic',      5,    70.00, 12.0, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('tier-cfg-msg-advance',    'app-mystoreguard', 'shared-subscription-advance',    8,   100.00, 12.0, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('tier-cfg-msg-premium',    'app-mystoreguard', 'shared-subscription-premium',   16,   190.00, 12.0, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('tier-cfg-msg-enterprise', 'app-mystoreguard', 'shared-subscription-enterprise', NULL, 3000.00, 12.0, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('tier-cfg-ld-basic',       'app-loandrift',    'shared-subscription-basic',      6,   100.00, 12.0, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('tier-cfg-ld-advance',     'app-loandrift',    'shared-subscription-advance',   12,   150.00, 12.0, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('tier-cfg-ld-premium',     'app-loandrift',    'shared-subscription-premium',   24,   200.00, 12.0, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('tier-cfg-ld-enterprise',  'app-loandrift',    'shared-subscription-enterprise', NULL, 3000.00, 12.0, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('tier-cfg-zhr-basic',      'app-zeloshr',      'shared-subscription-basic',      6,   100.00, 12.0, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('tier-cfg-zhr-advance',    'app-zeloshr',      'shared-subscription-advance',   12,   150.00, 12.0, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('tier-cfg-zhr-premium',    'app-zeloshr',      'shared-subscription-premium',   24,   200.00, 12.0, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('tier-cfg-zhr-enterprise', 'app-zeloshr',      'shared-subscription-enterprise', NULL, 3000.00, 12.0, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET
    app_id          = EXCLUDED.app_id,
    subscription_id = EXCLUDED.subscription_id,
    max_login_users = EXCLUDED.max_login_users,
    price           = EXCLUDED.price,
    rate            = EXCLUDED.rate;

INSERT INTO cp_app_features (id, feature_type, title, description) VALUES
('upcoming-01', 'upcoming', 'Attendance Tracking', 'Enable employees or users to check in and out, track presence, and generate attendance logs.'),
('upcoming-02', 'available', 'Advanced Reporting', 'Provide deeper analytics with customizable filters, charts, and downloadable report formats.'),
('upcoming-03', 'upcoming', 'Group-Level Login Settings', 'Allow login policies to be configured per group, such as always allowed, restricted days, or customized rules.'),
('upcoming-04', 'upcoming', 'Day & Time-based Login Rules', 'Restrict login access to specific days and time ranges, such as Mondays & Tuesdays from 6:00 AM to 10:00 AM.'),
('upcoming-05', 'available', 'Enhanced Reporting Features', 'Improve existing reporting modules with new metrics, summaries, and audit-based insights.'),
('upcoming-06', 'upcoming', 'Hardware POS Integration', 'Connect the system with physical POS devices for sales processing and syncing transactions.'),
('upcoming-07', 'upcoming', 'Hardware Attendance Integration', 'Integrate biometric or RFID attendance devices to sync clock-in/clock-out data.'),
('upcoming-08', 'available', 'Receipt Printer Integration', 'Allow printing of receipts directly from supported hardware thermal printers.'),
('availble-01', 'available', 'Currency Setup', 'Configure multiple currencies with symbols, codes, exchange settings, and minor units.'),
('availble-02', 'available', 'Unit of Measure Setup', 'Create and manage units of measure for stock, sales, and inventory operations.'),
('availble-03', 'available', 'Multi-Organization Support', 'Enable managing multiple organizations within one platform.'),
('availble-04', 'available', 'Multi-Business Management', 'Allow each organization to have multiple business entities under it.'),
('availble-05', 'available', 'Group & User Management', 'Create groups and assign permissions for managing multiple users effectively.')
ON CONFLICT (id) DO UPDATE SET
    feature_type = EXCLUDED.feature_type,
    title        = EXCLUDED.title,
    description  = EXCLUDED.description;