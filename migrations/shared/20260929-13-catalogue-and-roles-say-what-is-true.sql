-- Four loose ends, each one a place where the catalogue claimed something untrue
--
-- 1. `calender` is spelled wrong.
--
--    The resource itself, not just the role that was named after it. Nothing outside the
--    generated permission module referenced it, so this is a database rename plus a
--    regeneration. The permission id changes with it, which cp_role_permissions references
--    under ON DELETE RESTRICT and no ON UPDATE rule -- so the new row is inserted, the fifteen
--    grants are repointed, and only then is the old row removed.
--
-- 2. The two collections roles could not open the collections screens.
--
--    Collections Manager and Collections Officer held penalty, repayment, capturing and client
--    permissions but not one `collections` permission between them. The only role that had any
--    was Collections Admin -- renamed Collections Supervisor in 20260929-11 -- which held the
--    four collections verbs, one unrelated read, and nothing else. It was scaffolding: a role
--    per resource, named after the screen.
--
--    So this is not the overlap it looked like, it is a gap. The two job roles get the
--    collections permissions their names promise -- the Manager including delete, the Officer
--    not -- and the scaffolding role is retired. Nobody holds it.
--
-- 3. Fourteen ZelosHR permissions name nothing.
--
--    No endpoint enforces them and no line of C# mentions them:
--
--      custom-field-values  create, delete, get, update   -- per-employee values are not built;
--      sensitive-fields     reveal                           only definitions exist
--      attendance-employees create, delete, get, update   -- no controller
--      audit                create, update                -- entries are written by the system
--      dashboard            create, update, delete        -- a dashboard is read-only
--
--    A permission that grants nothing is worse than a missing one: somebody grants "reveal
--    sensitive fields" to a role, and nothing happens. Marking a custom field sensitive today
--    has no effect on who can read it, because nothing masks a value -- there are no values.
--    These are retired so the catalogue stops promising them. Whoever builds per-employee
--    custom field values adds the permissions back in the migration that adds the feature,
--    which is how it works now that nothing is auto-assigned.
--
--    18 grant rows across 5 roles are retired with them.
--
-- 4. Nobody could be allowed to take a payment.
--
--    coreplatform's /payments/initialize and /payments/initialize-for-service check nothing.
--    They are gated on billing|pay in the app, and Billing Administrator already holds it, so
--    this migration only asserts that -- if that grant ever disappeared, the endpoints would
--    become owner-and-admin-only and nobody would notice.

BEGIN;

-- ------------------------------------------------------------------ 1. calender -> calendar
INSERT INTO core_platform.cp_permissions
    (id, app_prefix, resource_key, action, target, scope, permission_name, description,
     resource_type_id, cdate, ctime, cdatetime, delete_status, is_active)
SELECT replace(p.id, 'calender', 'calendar'), p.app_prefix, 'calendar', p.action, p.target,
       p.scope, replace(p.permission_name, 'Calender', 'Calendar'),
       replace(coalesce(p.description, ''), 'calender', 'calendar'),
       p.resource_type_id, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'NOT_DELETED', true
  FROM core_platform.cp_permissions p
 WHERE p.resource_key = 'calender'
ON CONFLICT (id) DO NOTHING;

-- Drop the misspelt grant wherever the corrected one is already held, BEFORE
-- renaming the rest. Otherwise the rename below collides with it: saas-dev has
-- 15 rows on 'calender' and the same 15 roles already hold 'calendar', so every
-- single row would violate ix_cp_role_permissions_tenant_id_role_id_permission_id
-- and an UPDATE cannot carry an ON CONFLICT clause to absorb that.
--
-- Both spellings coexist because this migration never completed: the deploys
-- that would have run it died earlier, in a module seed, while something else
-- went on granting the correctly-spelled permission. On a database where only
-- 'calender' exists this DELETE matches nothing and the rename does the whole
-- job, exactly as before.
DELETE FROM core_platform.cp_role_permissions rp
 WHERE rp.resource_key = 'calender'
   AND EXISTS (
        SELECT 1 FROM core_platform.cp_role_permissions x
         WHERE x.tenant_id     = rp.tenant_id
           AND x.role_id       = rp.role_id
           AND x.permission_id = replace(rp.permission_id, 'calender', 'calendar')
   );

UPDATE core_platform.cp_role_permissions rp
   SET permission_id = replace(rp.permission_id, 'calender', 'calendar'),
       resource_key  = 'calendar'
 WHERE rp.resource_key = 'calender';

DELETE FROM core_platform.cp_permissions WHERE resource_key = 'calender';

UPDATE core_platform.cp_resources SET resource_key = 'calendar' WHERE resource_key = 'calender';

-- --------------------------------------------- 2. the collections roles can do collections
INSERT INTO core_platform.cp_role_permissions
    (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', r.id, p.id,
       r.role_name || ' can ' || lower(p.permission_name),
       CURRENT_DATE::text, CURRENT_TIME::text, now()
  FROM core_platform.cp_roles r
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'loandrift' AND p.resource_key = 'collections'
   AND p.delete_status = 'NOT_DELETED' AND p.is_active
   -- The Manager may remove a collections record; the Officer works them but may not.
   AND (r.role_name = 'Collections Manager'
        OR (r.role_name = 'Collections Officer' AND p.action <> 'delete'))
 WHERE r.role_name IN ('Collections Manager', 'Collections Officer')
   AND r.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

UPDATE core_platform.cp_roles
   SET delete_status = 'DELETED', is_active = false
 WHERE role_name = 'Collections Supervisor' AND delete_status = 'NOT_DELETED';

-- ------------------------------------- 3. retire the ZelosHR permissions that name nothing
CREATE TEMP TABLE _retire ON COMMIT DROP AS
SELECT p.id
  FROM core_platform.cp_permissions p
 WHERE p.app_prefix = 'zeloshr'
   AND ( p.resource_key IN ('attendance-employees', 'custom-field-values', 'sensitive-fields')
      OR (p.resource_key = 'audit'     AND p.action IN ('create', 'update'))
      OR (p.resource_key = 'dashboard' AND p.action IN ('create', 'update', 'delete')) );

UPDATE core_platform.cp_role_permissions
   SET delete_status = 'DELETED', is_active = false
 WHERE permission_id IN (SELECT id FROM _retire) AND delete_status = 'NOT_DELETED';

UPDATE core_platform.cp_permissions
   SET delete_status = 'DELETED', is_active = false
 WHERE id IN (SELECT id FROM _retire);

-- The catalogue drives regeneration, so it has to agree or the next run puts them back.
DELETE FROM core_platform.cp_resources
 WHERE app_prefix = 'zeloshr'
   AND resource_key IN ('attendance-employees', 'custom-field-values', 'sensitive-fields');

UPDATE core_platform.cp_resources SET actions = ARRAY['delete','get']
 WHERE app_prefix = 'zeloshr' AND resource_key = 'audit';

UPDATE core_platform.cp_resources SET actions = ARRAY['get']
 WHERE app_prefix = 'zeloshr' AND resource_key = 'dashboard';

-- ----------------------------------------------------------------------------- assertions
DO $$
DECLARE
    bad_calender integer;
    coll_mgr     integer;
    coll_off     integer;
    zeloshr_live integer;
    billing_pay  integer;
BEGIN
    SELECT (SELECT count(*) FROM core_platform.cp_permissions      WHERE resource_key = 'calender')
         + (SELECT count(*) FROM core_platform.cp_resources        WHERE resource_key = 'calender')
         + (SELECT count(*) FROM core_platform.cp_role_permissions WHERE resource_key = 'calender')
      INTO bad_calender;

    SELECT count(*) INTO coll_mgr FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_roles r ON r.id = rp.role_id
     WHERE r.role_name = 'Collections Manager' AND rp.resource_key = 'collections'
       AND rp.delete_status = 'NOT_DELETED';

    SELECT count(*) INTO coll_off FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_roles r ON r.id = rp.role_id
     WHERE r.role_name = 'Collections Officer' AND rp.resource_key = 'collections'
       AND rp.delete_status = 'NOT_DELETED';

    SELECT count(*) INTO zeloshr_live FROM core_platform.cp_permissions
     WHERE app_prefix = 'zeloshr' AND delete_status = 'NOT_DELETED' AND is_active;

    SELECT count(*) INTO billing_pay FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_roles r ON r.id = rp.role_id AND r.delete_status = 'NOT_DELETED'
     WHERE rp.resource_key = 'billing' AND rp.action = 'pay' AND rp.delete_status = 'NOT_DELETED';

    IF bad_calender > 0 THEN
        RAISE EXCEPTION 'calender still present in % row(s)', bad_calender;
    END IF;
    IF coll_mgr <> 4 THEN
        RAISE EXCEPTION 'Collections Manager should hold 4 collections permissions, holds %', coll_mgr;
    END IF;
    IF coll_off <> 3 THEN
        RAISE EXCEPTION 'Collections Officer should hold 3 collections permissions, holds %', coll_off;
    END IF;
    IF zeloshr_live <> 68 THEN
        RAISE EXCEPTION 'expected 68 live ZelosHR permissions (82 less the 14 that name nothing), found %', zeloshr_live;
    END IF;
    IF billing_pay = 0 THEN
        RAISE EXCEPTION 'no role holds billing|pay; gating /payments/initialize on it would lock everybody out';
    END IF;

    RAISE NOTICE 'calendar fixed; collections % / %; ZelosHR % live permissions; billing|pay held by % role(s)',
        coll_mgr, coll_off, zeloshr_live, billing_pay;
END $$;

COMMIT;
