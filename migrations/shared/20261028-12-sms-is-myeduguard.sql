-- The school management app is MyEduGuard (not EDUGUARD, as 20261028-11 named it): the app, its
-- subscribed-app resource, its roles and its permissions, from either earlier name. The ids stay
-- app-sms, rt-*-sms*, role-sms-*, permission-sms-*. Later SMS migrations name new roles and
-- permissions "MyEduGuard ...". Idempotent.

BEGIN;

UPDATE core_platform.cp_apps SET app_name = 'MyEduGuard' WHERE id = 'app-sms';

UPDATE core_platform.cp_resource_types
   SET resource_type_name = regexp_replace(resource_type_name, '^(SMS|EDUGUARD)\M', 'MyEduGuard'),
       description        = regexp_replace(description, '\m(SMS|EDUGUARD)\M', 'MyEduGuard', 'g')
 WHERE id = 'rt-subscribed-app-sms' OR id LIKE 'rt-sms-%';

UPDATE core_platform.cp_roles
   SET role_name   = regexp_replace(role_name, '^(SMS|EDUGUARD)\M', 'MyEduGuard'),
       description = regexp_replace(description, '\m(SMS|EDUGUARD)\M', 'MyEduGuard', 'g')
 WHERE id LIKE 'role-sms-%' OR id = 'role-subscribed-app-sms-admin';

UPDATE core_platform.cp_permissions
   SET permission_name = regexp_replace(permission_name, '^(SMS|EDUGUARD)\M', 'MyEduGuard')
 WHERE app_prefix = 'sms' OR id LIKE 'permission-sms-%';

COMMIT;
