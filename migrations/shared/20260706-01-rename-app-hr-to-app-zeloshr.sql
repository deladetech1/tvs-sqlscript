-- 20260706-01-rename-app-hr-to-app-zeloshr.sql
-- Data migration for the app-id rename: app-hr -> app-zeloshr.
--
-- The zeloshr admin app now identifies itself as `app-zeloshr` (IaC env var +
-- appsettings), and the CorePlatform / HR RBAC seeds were re-pointed to the new
-- id. Seeds only touch rows whose PRIMARY KEY matches the code, so they create
-- the new rows but never rewrite existing subscribers' data. This script fixes
-- the rows that already carry the old `app-hr` values so existing subscribers
-- keep their access instead of being stranded on orphaned ids.
--
-- Covers, in core_platform:
--   * catalog PK renames (FK-referenced, so copy -> repoint -> delete):
--       cp_apps.id                     'app-hr'                     -> 'app-zeloshr'
--       cp_resource_types.id           'rt-subscribed-app-hr'       -> 'rt-subscribed-app-zeloshr'
--       cp_roles.id                    'role-subscribed-app-hr-admin' -> 'role-subscribed-app-zeloshr-admin'
--   * every FK / data column that references those ids or the app-id value.
--
-- IDEMPOTENT: safe to re-run. On an already-migrated (or fresh) DB every
-- statement is a no-op. This is why it can live in migrations/shared/.
--
-- ORDERING CAVEAT (existing environments only): the HR seeder
-- (HumanResourceRbacSeeder.UpsertHrAdminRolePermissionsAsync) inserts
-- role-permission rows with the deterministic id `rp-hr-admin-{permissionId}`.
-- On a DB that was already seeded under the old role id, those ids already
-- exist, so the seeder will hit a duplicate-key error BEFORE this shared SQL
-- (which runs after seeds) gets a chance. For any environment that already has
-- live app-hr subscribers, RUN THIS SCRIPT MANUALLY ONCE against the DB before
-- deploying the renamed seeds. Run standalone it fully migrates the DB, after
-- which the seeder's existence check passes and the deploy is clean.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Ensure the new catalog / RBAC rows exist (copied from the old rows if
--    present; no-op if the seeder already created them). Done before any
--    repoint so the FK targets are guaranteed to exist.
-- ---------------------------------------------------------------------
INSERT INTO core_platform.cp_apps
    (id, app_name, feature1, feature2, feature3, feature4, feature5,
     delete_status, is_active, status, description, cdate, ctime, cdatetime)
SELECT 'app-zeloshr', app_name, feature1, feature2, feature3, feature4, feature5,
       delete_status, is_active, status, description, cdate, ctime, cdatetime
FROM   core_platform.cp_apps
WHERE  id = 'app-hr'
ON CONFLICT (id) DO NOTHING;

INSERT INTO core_platform.cp_resource_types
    (id, resource_type_name, parent_resource_id, delete_status, is_active,
     description, cdate, ctime, cdatetime)
SELECT 'rt-subscribed-app-zeloshr', resource_type_name, parent_resource_id,
       delete_status, is_active, description, cdate, ctime, cdatetime
FROM   core_platform.cp_resource_types
WHERE  id = 'rt-subscribed-app-hr'
ON CONFLICT (id) DO NOTHING;

INSERT INTO core_platform.cp_roles
    (id, role_name, resource_type_id, is_system, cdate, ctime, cdatetime,
     created_by, updated_by, deleted_by, tenant_id, delete_status, is_active, description)
SELECT 'role-subscribed-app-zeloshr-admin', role_name, 'rt-subscribed-app-zeloshr',
       is_system, cdate, ctime, cdatetime, created_by, updated_by, deleted_by,
       tenant_id, delete_status, is_active, description
FROM   core_platform.cp_roles
WHERE  id = 'role-subscribed-app-hr-admin'
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------
-- 2. Repoint every FK reference from the old ids to the new ids.
-- ---------------------------------------------------------------------
-- Resource-type children + anything typed against the subscribed-app roletype.
UPDATE core_platform.cp_resource_types
   SET parent_resource_id = 'rt-subscribed-app-zeloshr'
 WHERE parent_resource_id = 'rt-subscribed-app-hr';

UPDATE core_platform.cp_roles
   SET resource_type_id = 'rt-subscribed-app-zeloshr'
 WHERE resource_type_id = 'rt-subscribed-app-hr';

UPDATE core_platform.cp_permissions
   SET resource_type_id = 'rt-subscribed-app-zeloshr'
 WHERE resource_type_id = 'rt-subscribed-app-hr';

UPDATE core_platform.cp_shared_resource_ids
   SET resource_type_id = 'rt-subscribed-app-zeloshr'
 WHERE resource_type_id = 'rt-subscribed-app-hr';

-- Role references: role-permissions (keeps the deterministic rp ids, just
-- points them at the new role) and user/group role assignments.
UPDATE core_platform.cp_role_permissions
   SET role_id = 'role-subscribed-app-zeloshr-admin'
 WHERE role_id = 'role-subscribed-app-hr-admin';

UPDATE core_platform.cp_assign_roles
   SET role_id = 'role-subscribed-app-zeloshr-admin'
 WHERE role_id = 'role-subscribed-app-hr-admin';

-- ---------------------------------------------------------------------
-- 3. Repoint the tenant DATA rows that store the app-id value. These are the
--    rows that decide whether an existing subscriber still resolves to the app.
-- ---------------------------------------------------------------------
UPDATE core_platform.cp_app_tier_configs
   SET app_id = 'app-zeloshr' WHERE app_id = 'app-hr';

UPDATE core_platform.cp_business_apps
   SET app_id = 'app-zeloshr' WHERE app_id = 'app-hr';

UPDATE core_platform.cp_app_subscriptions
   SET app_id = 'app-zeloshr' WHERE app_id = 'app-hr';

UPDATE core_platform.cp_app_subscription_histories
   SET app_id = 'app-zeloshr' WHERE app_id = 'app-hr';

UPDATE core_platform.cp_business_app_locations
   SET app_id = 'app-zeloshr' WHERE app_id = 'app-hr';

UPDATE core_platform.cp_user_locations
   SET app_id = 'app-zeloshr' WHERE app_id = 'app-hr';

UPDATE core_platform.cp_group_locations
   SET app_id = 'app-zeloshr' WHERE app_id = 'app-hr';

-- ---------------------------------------------------------------------
-- 4. Remove the now-orphaned old catalog / RBAC rows. Nothing references them
--    after step 2, so the FK deletes are clean.
-- ---------------------------------------------------------------------
DELETE FROM core_platform.cp_roles          WHERE id = 'role-subscribed-app-hr-admin';
DELETE FROM core_platform.cp_resource_types WHERE id = 'rt-subscribed-app-hr';
DELETE FROM core_platform.cp_apps           WHERE id = 'app-hr';

COMMIT;
