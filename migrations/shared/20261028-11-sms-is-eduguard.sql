-- The school management app is EDUGUARD (myEduGuard): its name in the app store and everywhere
-- Core Platform names it -- the app, its subscribed-app resource, its roles and permissions.
-- The ids stay app-sms, rt-*-sms*, role-sms-*, permission-sms-*: only what people read changes.
-- Later SMS migrations name new roles and permissions "EDUGUARD ...". Idempotent.

BEGIN;

UPDATE core_platform.cp_apps SET app_name = 'EDUGUARD' WHERE id = 'app-sms';

UPDATE core_platform.cp_resource_types
   SET resource_type_name = regexp_replace(resource_type_name, '^SMS\M', 'EDUGUARD'),
       description        = regexp_replace(description, '\mSMS\M', 'EDUGUARD', 'g')
 WHERE id = 'rt-subscribed-app-sms' OR id LIKE 'rt-sms-%';

UPDATE core_platform.cp_roles
   SET role_name   = regexp_replace(role_name, '^SMS\M', 'EDUGUARD'),
       description = regexp_replace(description, '\mSMS\M', 'EDUGUARD', 'g')
 WHERE id LIKE 'role-sms-%' OR id = 'role-subscribed-app-sms-admin';

UPDATE core_platform.cp_permissions
   SET permission_name = regexp_replace(permission_name, '^SMS\M', 'EDUGUARD')
 WHERE app_prefix = 'sms' OR id LIKE 'permission-sms-%';

COMMIT;
