-- =====================================================================================
-- The default role stops handing everybody the staff directory.
--
-- Every user in every tenant is in the Default Group, and 20260928-14 gave its role
-- `permission-user-get` and `permission-group-get` -- the ANY-scope reads. So a till clerk
-- could list every user in the business and every group in it, and the hub showed them the
-- Users and Groups screens because they genuinely held the right to be there.
--
-- Reported from production: a sales person seeing tabs nobody had granted them. The nav was
-- not lying and the API was not leaking past a check. The grant was simply wider than anyone
-- intended.
--
-- That migration set out to give each role what its own screens need, which was right. For
-- this role it reached for the any-scope permission when the own-scope one already existed
-- and was already granted beside it:
--
--     permission-user-get           any   <- removed here
--     permission-user-get-own       own   <- kept; this is what "my profile" needs
--     permission-group-get          any   <- removed here
--
-- What stays: themes, currency, business-app, changing your own password, your own login
-- settings, your own profile picture, and `permission-user-get-locations`, which is part of
-- the navigation floor in role_service.DEFAULT_ROLE_PERMISSIONS -- take it away and the hub
-- cannot resolve where somebody works.
--
-- Left deliberately for a decision rather than swept up here: the default role also holds
-- `permission-user-groups-get` and `permission-user-roles-get` at any scope, beside their
-- own-scope twins. They read another person's groups and roles rather than the directory
-- itself, so they are a narrower question and not the one that was reported.
-- =====================================================================================

DELETE FROM core_platform.cp_role_permissions
 WHERE role_id = 'role-default-group'
   AND permission_id IN ('permission-user-get', 'permission-group-get');
