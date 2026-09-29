-- =====================================================================================
-- Make Admin and Core Platform Admin impossible to confuse.
--
-- The names invite exactly the wrong guess. "Core Platform Admin" sounds like the platform's
-- top administrator and "Admin" sounds like a lesser, generic one. It is the other way
-- round: Admin covers Core Platform AND MyStoreGuard AND LoanDrift AND ZelosHR, and Core
-- Platform Admin covers Core Platform alone. Somebody scanning the picker for the narrower
-- of the two would pick Admin and hand over every app.
--
-- The descriptions did not help. Admin's put its scope mid-sentence; Core Platform Admin's
-- put "Carries no access to any subscribed app" last, after a nine-item list.
--
-- Each now opens with the fact that distinguishes it and names the other outright, so the
-- comparison is on screen rather than in the reader's head.
--
-- What this does NOT do is rename them, which is the real fix. role_name is matched as a
-- string in the auto-assign trigger ('Owner', 'Admin'), in seed grants, and in role
-- allow-lists in the backends; renaming would need all of those found and changed together
-- and is its own piece of work, not a description change.
--
-- Safe to rerun.
-- =====================================================================================

UPDATE core_platform.cp_roles SET description = v.description
  FROM (VALUES
    ('role-admin',
     'EVERY APP. The most powerful role after Owner: full access to Core Platform and to '
     || 'MyStoreGuard, LoanDrift and ZelosHR. The only thing it cannot do is delete '
     || 'activity logs. If you want Core Platform on its own, use Core Platform Admin, '
     || 'which is narrower than this.'),
    ('role-cp-admin',
     'CORE PLATFORM ONLY. Organizations, businesses, locations, users, groups, roles, '
     || 'permissions, settings and billing -- and nothing in MyStoreGuard, LoanDrift or '
     || 'ZelosHR. Cannot delete activity logs. Narrower than Admin, which despite the '
     || 'shorter name also covers every app.')
  ) AS v(id, description)
 WHERE cp_roles.id = v.id
   AND cp_roles.description IS DISTINCT FROM v.description;
