-- =====================================================================================
-- Take log deletion away from Admin.
--
-- cp_roles describes Admin as able to do anything "except log modification", and the trigger
-- that grants its permissions says it can read logs but not modify them. Neither was ever true:
-- the rule matched '%-log-%' or '% log %' against names like "Core Platform Logs Delete", so it
-- never fired. 20260928-07 and -08 fixed the rules. This removes what the broken ones granted.
--
-- It is also the fix for fresh installs. 02_permissions.sql inserts permissions with no
-- resource_key -- those columns arrive with 20260928-05, by which time 03_roles.sql has already
-- created Admin under the old behaviour. migrations/shared runs after every seed, so reconciling
-- here corrects a brand-new database and a long-lived one in the same statement.
--
-- This is the first REVOKE in this series; everything before it only widened or was inert.
-- Scoped by the rule rather than by role id: any role named Admin loses any verb that CHANGES
-- logs. On saas-dev that is exactly three grants on role-admin.
--
-- Owner is untouched and keeps all three, so log deletion remains possible -- it just stops
-- being possible for the role whose whole description says it should not be.
--
-- A hard DELETE, matching how cp_role_permissions is edited everywhere else in the codebase
-- (role_service deletes and re-inserts a role's grants). Reversible with a single INSERT; the
-- triggers will not put it back, because the rules now withhold it.
--
-- Safe to rerun.
-- =====================================================================================

SET search_path TO core_platform;

DO $$
DECLARE
    removed   INTEGER;
    detail    TEXT;
BEGIN
    IF to_regclass('core_platform.cp_actions') IS NULL THEN
        RAISE EXCEPTION 'cp_actions is missing -- 20260928-05 must run before this file';
    END IF;

    SELECT string_agg(r.role_name || ' / ' || rp.permission_id, ', ' ORDER BY rp.permission_id)
    INTO detail
    FROM core_platform.cp_role_permissions rp
    JOIN core_platform.cp_roles r       ON r.id = rp.role_id
    JOIN core_platform.cp_permissions p  ON p.id = rp.permission_id
    LEFT JOIN core_platform.cp_actions a ON a.action = p.action
    WHERE r.role_name = 'Admin'
      AND p.resource_key = 'logs'
      AND NOT COALESCE(a.is_read_only, false);

    DELETE FROM core_platform.cp_role_permissions rp
    USING core_platform.cp_roles r, core_platform.cp_permissions p
    LEFT JOIN core_platform.cp_actions a ON a.action = p.action
    WHERE r.id = rp.role_id
      AND p.id = rp.permission_id
      AND r.role_name = 'Admin'
      AND p.resource_key = 'logs'
      AND NOT COALESCE(a.is_read_only, false);

    GET DIAGNOSTICS removed = ROW_COUNT;

    IF removed > 0 THEN
        RAISE NOTICE 'Admin can no longer erase logs -- removed % grant(s): %', removed, detail;
    ELSE
        RAISE NOTICE 'Admin already holds no log-modifying permission; nothing to remove';
    END IF;
END $$;

-- -------------------------------------------------------------------------------------
-- Leave the audit trail able to name who still can.
--
-- These are NOT touched: Owner is meant to hold everything, and the two app-wide admins were
-- granted their own app's log deletion by a different rule entirely -- the `permission-<app>-%`
-- sweep in each app's catalogue migration, not the Admin rule this file corrects. Narrowing
-- them is a separate decision about what an app administrator should be able to erase.
--
--     role-owner                          cp / loandrift / msg logs-delete
--     role-subscribed-app-loandrift-admin loandrift-logs-delete
--     role-subscribed-app-msg-admin       msg-logs-delete
-- -------------------------------------------------------------------------------------
DO $$
DECLARE others TEXT;
BEGIN
    SELECT string_agg(DISTINCT r.role_name, ', ' ORDER BY r.role_name) INTO others
    FROM core_platform.cp_role_permissions rp
    JOIN core_platform.cp_roles r       ON r.id = rp.role_id
    JOIN core_platform.cp_permissions p  ON p.id = rp.permission_id
    LEFT JOIN core_platform.cp_actions a ON a.action = p.action
    WHERE rp.delete_status = 'NOT_DELETED'
      AND p.resource_key = 'logs'
      AND NOT COALESCE(a.is_read_only, false);

    RAISE NOTICE 'Roles that can still delete logs: %', COALESCE(others, '(none)');
END $$;
