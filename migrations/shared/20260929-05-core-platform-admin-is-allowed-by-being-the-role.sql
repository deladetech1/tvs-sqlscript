-- =====================================================================================
-- Core Platform Admin stops holding rows too.
--
-- The last of the five. It held 147 of Core Platform's 149 permissions -- every one except
-- modifying logs -- and is now allowed by BEING the role, the way the three app admins
-- cover their apps (tvs-package 1.0.45): anything whose permission carries Core Platform's
-- prefix, and never a write to logs.
--
-- Core Platform owns two prefixes. Most of its permissions carry an empty one; six file and
-- logs verbs carry 'cp' so they can be told apart from MyStoreGuard's and LoanDrift's. Both
-- are this role's, and both are removed here.
--
-- Nothing else changes. Admin (role-admin) keeps its 510 rows and is untouched: it spans
-- every app, no rule covers it, and turning that into a rule is a separate decision about
-- the most powerful role after Owner.
--
-- The two rows it never had -- the cp log writes -- stay absent, which the rule also
-- refuses. That agreement is the point: what the role can do no longer depends on which
-- rows somebody remembered to insert.
--
-- Safe to rerun.
-- =====================================================================================

DELETE FROM core_platform.cp_role_permissions rp
 USING core_platform.cp_permissions p
 WHERE p.id = rp.permission_id
   AND rp.role_id = 'role-cp-admin'
   AND COALESCE(p.app_prefix, '') IN ('', 'cp');
