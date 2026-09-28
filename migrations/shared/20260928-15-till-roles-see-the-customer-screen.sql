-- =====================================================================================
-- The second order of 20260928-14, and the last of it.
--
-- Giving the three till roles customers+create so a walk-in could be added mid-sale made
-- the customer screen theirs, and that screen shows two more things: how many customers
-- there are, and what credit one of them is on. Both reads, both refused, so the screen a
-- cashier had just been given the right to use came up with two panels erroring.
--
-- Found by rerunning scripts/audit_role_permissions.py after -14 landed, which is the point
-- of it being a script rather than a list written once. It now reports every app clean.
--
-- store-admin gets the count but not store-credit: it was already reaching that screen and
-- already lacked the count, so this fixes an older gap at the same time. It has no business
-- with a customer's credit standing, which belongs to whoever takes the money.
--
-- Safe to rerun.
-- =====================================================================================

INSERT INTO core_platform.cp_role_permissions
    (id, tenant_id, role_id, permission_id, created_by, cdate, ctime, cdatetime)
SELECT
    'rpid_' || md5(v.role_id || ':' || v.permission_id),
    'system-tenant-id',
    v.role_id,
    v.permission_id,
    NULL,
    to_char(now(), 'FMDay FMDDth FMMonth, YYYY'),
    to_char(now(), 'HH12:MI AM'),
    now()
FROM (VALUES
    ('role-msg-store-admin',            'permission-msg-customers-statistics'),
    ('role-msg-store-sales-admin',      'permission-msg-customers-statistics'),
    ('role-msg-store-sales-admin',      'permission-msg-store-credit-get'),
    ('role-msg-store-sales-personnel',  'permission-msg-customers-statistics'),
    ('role-msg-store-sales-personnel',  'permission-msg-store-credit-get')
) AS v(role_id, permission_id)
WHERE EXISTS (SELECT 1 FROM core_platform.cp_roles r WHERE r.id = v.role_id)
  AND EXISTS (SELECT 1 FROM core_platform.cp_permissions p WHERE p.id = v.permission_id)
  AND NOT EXISTS (
        SELECT 1 FROM core_platform.cp_role_permissions rp
         WHERE rp.role_id = v.role_id AND rp.permission_id = v.permission_id
  );
