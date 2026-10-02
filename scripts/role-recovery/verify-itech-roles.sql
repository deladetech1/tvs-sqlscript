-- Verify iTech's custom role survived a deploy. Run before and after; the numbers must match.
-- Expected as captured 2026-09-30: role=1, grants=27, assignments=15, missing_perms=0
\set ten '''tnt_f8085a8ca871c83087c24dd4b55a0e2d48f4652ee4eb81e7a9876ea230a'''
\set role '''rid_68fdc51ef83c73d670cb53df77cbc44d62cc8f22e6a2c6485b82dc0caa4'''

SELECT 'role'        AS what, count(*) AS n FROM core_platform.cp_roles
 WHERE id = :role AND delete_status='NOT_DELETED'
UNION ALL
SELECT 'grants',      count(*) FROM core_platform.cp_role_permissions
 WHERE role_id = :role AND delete_status='NOT_DELETED'
UNION ALL
SELECT 'assignments', count(*) FROM core_platform.cp_assign_roles
 WHERE tenant_id = :ten AND delete_status='NOT_DELETED'
UNION ALL
-- grants pointing at a permission that no longer exists: the silent-403 case
SELECT 'dangling_grants', count(*) FROM core_platform.cp_role_permissions rp
 WHERE rp.role_id = :role AND rp.delete_status='NOT_DELETED'
   AND NOT EXISTS (SELECT 1 FROM core_platform.cp_permissions p WHERE p.id = rp.permission_id)
UNION ALL
-- assignments pointing at a role that no longer exists
SELECT 'dangling_assignments', count(*) FROM core_platform.cp_assign_roles ar
 WHERE ar.tenant_id = :ten AND ar.delete_status='NOT_DELETED'
   AND NOT EXISTS (SELECT 1 FROM core_platform.cp_roles r WHERE r.id = ar.role_id);
