-- =====================================================================================
-- The default role reads its own person and nobody else's.
--
-- 20260930-01 took away the staff directory. This takes away the rest: with
-- permission-user-groups-get, permission-user-roles-get and permission-user-get-locations
-- at ANY scope, every user in every tenant could still read which groups anybody belongs
-- to, which roles anybody holds, and where anybody works -- one user id at a time instead
-- of as a list.
--
-- Each has an own-scope twin the role already holds, and the endpoints already prefer the
-- twin when the record is yours: they build [any-scope] and append the own-scope one only
-- when user_id is the caller's. So removing the any-scope grant narrows these to yourself
-- and changes nothing else.
--
-- One of the three needed code first. /users/location-details/{user_id} had no own-scope
-- alternative at all, and the app store calls it on every visit with the signed-in user's
-- own id -- so the only way it worked was the any-scope grant. That endpoint now offers the
-- own-scoped read for your own record, and role_service's navigation floor asks for the
-- own-scoped permission too, because navigating means knowing where YOU work.
--
-- Kept deliberately, despite reading as any-scope:
--
--   permission-user-login-settings-get / -update   Only ever offered when the record is
--   permission-user-change-password                your own -- the endpoints append them
--   permission-user-upload-profile-picture         under `if is_own_data`. There is no
--                                                  own-scope twin to swap them for, and
--                                                  they are already confined in code.
--
--   permission-theme-get / -update, permission-currency-get, permission-business-app-get
--                                                  Not about people.
-- =====================================================================================

DELETE FROM core_platform.cp_role_permissions
 WHERE role_id = 'role-default-group'
   AND permission_id IN (
         'permission-user-groups-get',
         'permission-user-roles-get',
         'permission-user-get-locations'
       );

-- Only this role is narrowed. An earlier draft rewrote every system role's any-scope
-- locations grant to the own-scope one "to keep the floor in step", which would have taken
-- from the administrators the very read their job needs. role_service.DEFAULT_ROLE_PERMISSIONS
-- governs roles created from now on; roles that already hold the any-scope read keep it, and
-- whether each of them should is a separate question from this one.
