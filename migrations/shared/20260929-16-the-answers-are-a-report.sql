-- Custom field ANSWERS move behind the report permission
--
-- /custom-fields/report returns every value anyone has ever entered into a custom field,
-- across every entity, with counts -- 906 of them on dev. It was behind store-config, which
-- seven roles hold: Sales Assistant, Backdated Sales Clerk, Invoicing Officer, Sales Manager,
-- Store Viewer, Store Manager and Store Configuration Manager.
--
-- Reading a shop's settings and reading everything its staff have ever typed into a custom
-- field are not the same authority. A shop can attach a custom field to any entity and put
-- anything in it -- supplier terms, a note about a customer -- and a sales assistant does not
-- need all of it to serve somebody at the till.
--
-- It is a report, so it now takes reports|get, like every other report. That is held by Store
-- Reports Viewer and Store Viewer. Store Manager is added here: they run the shop and plainly
-- should see its reports, and they could see this one before.
--
-- Four roles lose it: Sales Assistant, Backdated Sales Clerk, Invoicing Officer and Sales
-- Manager. That is the point of the change. Store Configuration Manager also loses it and
-- keeps what its name describes -- configuring the shop, including which custom fields exist.
--
-- The definitions stay open to anyone who can reach the app, unchanged. They are the
-- questions, and every role needs them to render a form; only the answers move.

BEGIN;

INSERT INTO core_platform.cp_role_permissions
    (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', r.id, 'permission-msg-reports-get',
       r.role_name || ' can view reports',
       CURRENT_DATE::text, CURRENT_TIME::text, now()
  FROM core_platform.cp_roles r
 WHERE r.role_name = 'Store Manager' AND r.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

DO $$
DECLARE
    can_report integer;
    names      text;
BEGIN
    SELECT count(*), string_agg(r.role_name, ', ' ORDER BY r.role_name)
      INTO can_report, names
      FROM core_platform.cp_roles r
      JOIN core_platform.cp_role_permissions rp
        ON rp.role_id = r.id AND rp.delete_status = 'NOT_DELETED'
     WHERE rp.permission_id = 'permission-msg-reports-get'
       AND r.delete_status = 'NOT_DELETED';

    IF can_report < 3 THEN
        RAISE EXCEPTION 'expected at least 3 roles to hold msg reports|get, found %', can_report;
    END IF;

    RAISE NOTICE 'custom field answers now readable by % role(s): %', can_report, names;
END $$;

COMMIT;
