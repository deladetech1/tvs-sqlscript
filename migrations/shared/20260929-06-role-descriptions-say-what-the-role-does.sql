-- =====================================================================================
-- Say what these roles actually do.
--
-- The descriptions are what somebody reads in the role picker to decide whether to grant a
-- role, and four of them were wrong in ways that mattered:
--
--   Admin           "The administrator of the Sales and Inventory system, can manage all
--                   operations including log management" -- the wrong app entirely, copied
--                   word for word from Mystoreguard Admin, and wrong about logs: Admin lost
--                   log modification in 20260928-10 and the sentence still promised it.
--
--   Mystoreguard    the same sentence. Right about the app, still wrong about logs.
--   Admin
--
--   Loandrift       "can manage all operations including loan management" -- says nothing a
--   Admin           reader does not already know from the name.
--
--   ZelosHR Admin   "Administrator of the Human Resources system" -- true but silent on the
--                   boundary, which is the part somebody granting it needs.
--
-- Each now says its scope and its one exception, because that boundary is the whole reason
-- these roles are separate: an app admin cannot touch another app, an admin cannot erase an
-- audit trail, and only the owner can.
--
-- Safe to rerun.
-- =====================================================================================

UPDATE core_platform.cp_roles SET description = v.description
  FROM (VALUES
    ('role-owner',
     'Can do anything in every app, including deleting activity logs. The only role that '
     || 'can erase an audit trail.'),
    ('role-admin',
     'Can do anything in Core Platform and in every subscribed app, EXCEPT deleting '
     || 'activity logs. Reading logs is allowed; erasing them is the owner''s alone.'),
    ('role-subscribed-app-msg-admin',
     'Can do anything in MyStoreGuard -- sales, inventory, stock, storefront and its '
     || 'settings -- except deleting its activity logs. Carries no access to LoanDrift, '
     || 'ZelosHR, or Core Platform settings such as billing.'),
    ('role-subscribed-app-loandrift-admin',
     'Can do anything in LoanDrift -- loans, repayments, disbursement, collections and its '
     || 'settings -- except deleting its activity logs. Carries no access to MyStoreGuard, '
     || 'ZelosHR, or Core Platform settings such as billing.'),
    ('role-subscribed-app-zeloshr-admin',
     'Can do anything in ZelosHR -- employees, leave, attendance and recruitment. Carries '
     || 'no access to MyStoreGuard, LoanDrift, or Core Platform settings such as billing.')
  ) AS v(id, description)
 WHERE cp_roles.id = v.id
   AND cp_roles.description IS DISTINCT FROM v.description;
