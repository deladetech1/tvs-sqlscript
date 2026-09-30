-- =====================================================================================
-- Take away the grants that no longer decide anything.
--
-- Four roles are now allowed by BEING the role, not by holding rows:
--
--   Owner                 anything, anywhere            (tvs-package 1.0.42)
--   Mystoreguard Admin    anything with app_prefix msg  (tvs-package 1.0.43,
--   Loandrift Admin       ...loandrift                   Trovesuite.Package 1.0.1)
--   ZelosHR Admin         ...zeloshr
--
-- Every one of those roles already held every permission of its scope -- 513, 194, 105
-- and 65 rows. Keeping them complete was the job of seeds, triggers and a grant clause in
-- seven migrations, each of which had to be remembered on every change. Owner drifting
-- back from 0 to 29 rows during yesterday's deploy is what that costs: a role whose
-- contents nobody can predict without reading eight files.
--
-- WHAT IS NOT REMOVED
--
--   * The app admins' Core Platform grants -- 11, 16 and 6 rows covering app, business,
--     business-app, organization, user and a few more. Core Platform is not their app and
--     the rule does not cover it, so removing these would take away the screens they need
--     to reach their own.
--   * Mystoreguard Admin's one LoanDrift grant, permission-loandrift-reports-get. A read
--     on another app's reports, which reads as deliberate rather than accidental.
--   * Every other role's rows. Only these four change.
--
-- Log deletion goes with the rest: msg and loandrift admins held logs+delete on their own
-- app, and the rule pointedly does not grant it. Reading logs they keep, because the
-- Python rule allows read-only verbs and takes that list from cp_actions.
--
-- REVERSIBLE. Nothing here is unrecoverable: re-running the seeds and the seven migrations
-- puts every row back, and the roles keep working throughout either way, because the rules
-- were deployed to all four apps first.
--
-- Safe to rerun.
-- =====================================================================================

-- Owner: everything goes. It is allowed before the check ever looks at a permission set.
DELETE FROM core_platform.cp_role_permissions
 WHERE role_id = 'role-owner';

-- App admins: their own app's rows go, nothing else does.
DELETE FROM core_platform.cp_role_permissions rp
 USING core_platform.cp_permissions p
 WHERE p.id = rp.permission_id
   AND (
        (rp.role_id = 'role-subscribed-app-msg-admin'       AND p.app_prefix = 'msg')
     OR (rp.role_id = 'role-subscribed-app-loandrift-admin' AND p.app_prefix = 'loandrift')
     OR (rp.role_id = 'role-subscribed-app-zeloshr-admin'   AND p.app_prefix = 'zeloshr')
   );
