-- =====================================================================================
-- The Admin role's log rule, by action instead of by name.
--
-- This is the function that CAUSED the grants 20260928-07 described. When an Admin role is
-- created it assigns every permission except log modification -- deciding which is which with
-- sixteen references to permission_name:
--
--     WHERE NOT (LOWER(p.permission_name) LIKE '%-log-%' OR LOWER(p.permission_name) LIKE '% log %')
--
-- Every log permission is named "Core Platform Logs Delete", "Mystoreguard Logs Delete",
-- "Loandrift Logs Delete". There is no "-log-" in those, and "% log %" wants " log " while the
-- name says " logs ". So the exclusion has never matched anything, Admin was granted the whole
-- catalogue, and on saas-dev role-admin holds all three logs-delete permissions today.
--
-- 20260928-07 fixed the routing of permissions added FROM NOW ON. This fixes the rule applied
-- when an Admin ROLE is created, which is the other half -- otherwise the next Admin role
-- created anywhere reintroduces the same three grants.
--
-- Uses what 20260928-05 recorded: resource_key = 'logs' is the log family across every app, and
-- cp_actions.is_read_only says whether the verb changes them.
--
-- Does not revoke anything already granted. Safe to rerun.
-- =====================================================================================

SET search_path TO core_platform;

CREATE OR REPLACE FUNCTION core_platform.auto_assign_all_permissions_except_logs_to_admin_role()
RETURNS TRIGGER AS $$
DECLARE
    granted INTEGER := 0;
BEGIN
    IF NEW.role_name <> 'Admin' THEN
        RETURN NEW;
    END IF;

    -- On a fresh database the seed installs triggers before cp_actions exists, and this fires
    -- while roles are being seeded. Fall back to granting nothing rather than erroring: the
    -- shared migrations replace this function and reconcile afterwards.
    IF to_regclass('core_platform.cp_actions') IS NULL THEN
        RAISE NOTICE 'cp_actions not present yet - Admin permission assignment deferred to migrations';
        RETURN NEW;
    END IF;

    INSERT INTO core_platform.cp_role_permissions
        (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
    SELECT NEW.tenant_id, NEW.id, p.id,
           CASE WHEN p.resource_key = 'logs'
                THEN 'Admin can view logs but not modify them'
                ELSE 'Admin has all permissions except log modification' END,
           CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
    FROM core_platform.cp_permissions p
    JOIN core_platform.cp_resource_types rt ON rt.id = p.resource_type_id
    LEFT JOIN core_platform.cp_actions a    ON a.action = p.action
    WHERE p.delete_status = 'NOT_DELETED'
      -- everything except a verb that CHANGES logs. An unknown action counts as not-a-read,
      -- so a log permission with no action yet is withheld rather than handed over.
      AND NOT (p.resource_key = 'logs' AND NOT COALESCE(a.is_read_only, false))
    ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

    GET DIAGNOSTICS granted = ROW_COUNT;
    RAISE NOTICE 'Admin role %: granted % permission(s), log modification withheld', NEW.id, granted;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_auto_assign_all_permissions_except_logs_to_admin_role ON core_platform.cp_roles;
CREATE TRIGGER trigger_auto_assign_all_permissions_except_logs_to_admin_role
    AFTER INSERT ON core_platform.cp_roles
    FOR EACH ROW
    EXECUTE FUNCTION core_platform.auto_assign_all_permissions_except_logs_to_admin_role();

-- -------------------------------------------------------------------------------------
-- NOTE: Sql/Triggers/01_auto_assign_permissions.sql keeps the old version, as with -06 and -07.
-- Triggers install BEFORE seeds; this needs cp_actions, created afterwards by migrations/shared.
-- The guard above makes an early call harmless.
--
-- STILL OUTSTANDING: role-admin already holds permission-cp-logs-delete,
-- permission-msg-logs-delete and permission-loandrift-logs-delete from before this fix.
-- Removing them is a REVOKE -- the first in this series -- and is left as a deliberate,
-- separate decision rather than folded in here.
-- -------------------------------------------------------------------------------------
