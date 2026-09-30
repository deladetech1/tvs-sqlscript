-- =====================================================================================
-- Mystoreguard Admin reads nothing in LoanDrift.
--
-- 20260929-03 kept one grant on that role -- permission-loandrift-reports-get, a read on
-- LoanDrift's reports -- on the reading that a single cross-app grant looked deliberate
-- rather than stray. It was not: MyStoreGuard's admin has no business in LoanDrift at all.
--
-- With it gone the role holds only Core Platform rows, and the rule covers the rest: an app
-- admin is allowed anything carrying its OWN app's prefix and nothing carrying another's.
-- There is now no role in the system granted across two apps except Admin and Owner.
--
-- Safe to rerun.
-- =====================================================================================

DELETE FROM core_platform.cp_role_permissions rp
 USING core_platform.cp_permissions p
 WHERE p.id = rp.permission_id
   AND rp.role_id = 'role-subscribed-app-msg-admin'
   AND p.app_prefix <> 'msg'
   AND p.app_prefix NOT IN ('', 'cp');
