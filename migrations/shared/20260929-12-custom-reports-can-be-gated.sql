-- MyStoreGuard's custom reports had no permission to be gated on
--
-- custom_reports_controller.py enforces nothing. Eight endpoints: list, create, read, update,
-- delete a report definition, plus /preview and /{id}/run which execute one. Any authenticated
-- user with a MyStoreGuard subscription could define a report over the field catalogue and run
-- it, or delete somebody else's.
--
-- It could not be fixed in the app alone, because `reports` carried a single action, `get`.
-- There was no create, update or delete to name. This adds them, so the controller can say
-- what it means.
--
-- /preview and /{id}/run are reads: they produce a report and change nothing, so they take
-- reports|get alongside the list and fetch endpoints. Defining a report is the write.
--
-- Grants are explicit now. 20260929-10 dropped the auto-assign triggers, so a new permission
-- reaches no role by itself -- which is the point, but it does mean naming who gets these:
-- Store Manager and Store Viewer already read reports; only Store Manager may define them.

BEGIN;

UPDATE core_platform.cp_resources
   SET actions = ARRAY['create','delete','get','update']
 WHERE app_prefix = 'msg' AND resource_key = 'reports';

INSERT INTO core_platform.cp_permissions
    (id, app_prefix, resource_key, action, target, scope, permission_name,
     description, resource_type_id, cdate, ctime, cdatetime, delete_status, is_active)
SELECT 'permission-msg-reports-' || v.action, 'msg', 'reports', v.action, '', 'any',
       v.name, v.description, 'rt-reports',
       CURRENT_DATE::text, CURRENT_TIME::text, now(), 'NOT_DELETED', true
  FROM (VALUES
        ('create', 'Create Report',
         'Can define a new custom report over the MyStoreGuard field catalogue.'),
        ('update', 'Update Report',
         'Can change the definition of an existing custom report.'),
        ('delete', 'Delete Report',
         'Can delete a custom report definition.')
       ) AS v(action, name, description)
ON CONFLICT (id) DO NOTHING;

-- Who gets them. Store Manager runs the store and may define reports; nobody else needs to.
INSERT INTO core_platform.cp_role_permissions
    (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', r.id, p.id,
       r.role_name || ' can ' || lower(p.permission_name),
       CURRENT_DATE::text, CURRENT_TIME::text, now()
  FROM core_platform.cp_roles r
  JOIN core_platform.cp_permissions p
    ON p.id IN ('permission-msg-reports-create',
                'permission-msg-reports-update',
                'permission-msg-reports-delete')
 WHERE r.role_name = 'Store Manager' AND r.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

DO $$
DECLARE
    n integer;
    held integer;
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions
     WHERE app_prefix = 'msg' AND resource_key = 'reports'
       AND delete_status = 'NOT_DELETED' AND is_active;

    SELECT count(*) INTO held FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_roles r ON r.id = rp.role_id AND r.delete_status = 'NOT_DELETED'
     WHERE rp.permission_id LIKE 'permission-msg-reports-%' AND rp.delete_status = 'NOT_DELETED';

    IF n <> 4 THEN
        RAISE EXCEPTION 'expected 4 msg report permissions, found %', n;
    END IF;
    IF held = 0 THEN
        RAISE EXCEPTION 'the new report permissions are held by no role';
    END IF;

    RAISE NOTICE 'msg reports: % permissions, % grant(s)', n, held;
END $$;

COMMIT;
