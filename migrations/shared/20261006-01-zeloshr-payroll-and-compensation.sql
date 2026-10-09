-- ZelosHR runs payroll itself now, so the Payroll Officer gets the job its description was
-- waiting for, and pay gets two resources of its own.
--
-- payroll       get · create (open and prepare a run) · update (approve, reject, mark paid)
--               · delete (cancel before approval)
-- compensation  get · create (propose a change) · update (approve or reject one)
--
-- Separation of duties is enforced by the API as well as by these grants: whoever prepared a
-- run cannot approve it, and whoever proposed a pay change cannot approve it. Granting both
-- create and update to the same role is therefore safe — it still takes two people.
--
-- Every grant is explicit (the auto-assign triggers were removed in 20260929-10), and the
-- assertion at the end fails the deploy if a new permission is left unheld.
-- Idempotent: re-run on every deploy.

BEGIN;

-- The pair the API compares: app_prefix|resource_key|action|target|scope.
UPDATE core_platform.cp_permissions p SET
    app_prefix = v.app_prefix, resource_key = v.resource_key,
    action = v.action, target = v.target, scope = v.scope
FROM (VALUES
('permission-zeloshr-payroll-get',          'zeloshr', 'payroll',      'get',    '', 'any'),
('permission-zeloshr-payroll-create',       'zeloshr', 'payroll',      'create', '', 'any'),
('permission-zeloshr-payroll-update',       'zeloshr', 'payroll',      'update', '', 'any'),
('permission-zeloshr-payroll-delete',       'zeloshr', 'payroll',      'delete', '', 'any'),
('permission-zeloshr-compensation-get',     'zeloshr', 'compensation', 'get',    '', 'any'),
('permission-zeloshr-compensation-create',  'zeloshr', 'compensation', 'create', '', 'any'),
('permission-zeloshr-compensation-update',  'zeloshr', 'compensation', 'update', '', 'any')
) AS v(id, app_prefix, resource_key, action, target, scope)
WHERE p.id = v.id;

UPDATE core_platform.cp_roles
   SET description = 'Prepares payroll: opens each run, checks it is ready, calculates it and submits it for approval, and pays it once approved. Proposes pay changes. Reads everything pay depends on — hours, timesheets, employee details and their documents — and changes none of it.'
 WHERE id = 'role-zeloshr-payroll-officer';

INSERT INTO core_platform.cp_role_permissions
    (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id,
       r.role_name || ' can ' || lower(p.permission_name),
       CURRENT_DATE::text, CURRENT_TIME::text, now()
  FROM (VALUES
        ('role-zeloshr-payroll-officer', 'payroll', 'get'),
        ('role-zeloshr-payroll-officer', 'payroll', 'create'),
        ('role-zeloshr-payroll-officer', 'payroll', 'update'),
        ('role-zeloshr-payroll-officer', 'payroll', 'delete'),
        ('role-zeloshr-payroll-officer', 'compensation', 'get'),
        ('role-zeloshr-payroll-officer', 'compensation', 'create'),
        ('role-zeloshr-hr-manager', 'payroll', 'get'),
        ('role-zeloshr-hr-manager', 'payroll', 'update'),
        ('role-zeloshr-hr-manager', 'compensation', 'get'),
        ('role-zeloshr-hr-manager', 'compensation', 'create'),
        ('role-zeloshr-hr-manager', 'compensation', 'update'),
        ('role-zeloshr-hr-auditor', 'payroll', 'get'),
        ('role-zeloshr-hr-auditor', 'compensation', 'get')
      ) AS spec(role_id, resource_key, action)
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'zeloshr' AND p.resource_key = spec.resource_key
   AND p.action = spec.action AND coalesce(p.target,'') = ''
   AND p.delete_status = 'NOT_DELETED' AND p.is_active
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

DO $$
DECLARE
    unheld text;
BEGIN
    SELECT string_agg(p.id, ', ' ORDER BY p.id) INTO unheld
      FROM core_platform.cp_permissions p
     WHERE p.app_prefix = 'zeloshr'
       AND p.resource_key IN ('payroll', 'compensation')
       AND p.delete_status = 'NOT_DELETED' AND p.is_active
       AND NOT EXISTS (
            SELECT 1 FROM core_platform.cp_role_permissions rp
              JOIN core_platform.cp_roles r ON r.id = rp.role_id
             WHERE rp.permission_id = p.id AND r.delete_status = 'NOT_DELETED' AND r.is_active);
    IF unheld IS NOT NULL THEN
        RAISE EXCEPTION 'Pay permissions no live role holds: %', unheld;
    END IF;

    IF (SELECT count(*) FROM core_platform.cp_permissions
         WHERE app_prefix = 'zeloshr' AND resource_key IN ('payroll', 'compensation')) <> 7 THEN
        RAISE EXCEPTION 'Expected 7 pay permissions with their pairs set; the seed did not run first.';
    END IF;
END $$;

COMMIT;
