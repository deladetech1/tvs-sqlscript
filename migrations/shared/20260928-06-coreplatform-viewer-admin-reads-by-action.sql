-- =====================================================================================
-- Viewer Admin roles: decide what a read-only role gets from the ACTION, not the name.
--
-- The rule today is ~24 clauses of `LOWER(permission_name) LIKE '%get%'`. It reads the NAME,
-- so what a read-only role can see depends on how somebody worded it. The two apps worded the
-- same concept differently:
--
--     Loandrift Client Get Statistics       -> contains "get" -> Loandrift viewer receives it
--     Mystoreguard Customers Statistics     -> no "get"       -> Mystoreguard viewer does NOT
--
-- So Loandrift Viewer Admin sees every figure in its app and Mystoreguard Viewer Admin sees
-- none of its thirty, though both roles mean the same thing. Every one of those permissions is
-- already in scope by resource type -- rt-msg-statistics is a child of rt-subscribed-app-msg --
-- and is excluded on spelling alone. This is live on every database today.
--
-- 20260928-05 gave every permission an `action`; cp_actions.viewer_default says whether a
-- read-only role should receive that verb. `reveal` is deliberately false: it is a read, but a
-- Viewer Admin must not see ZelosHR sensitive fields.
--
-- Measured against saas-dev before writing this: Core Platform Viewer Admin +0,
-- Loandrift Viewer Admin +2, Mystoreguard Viewer Admin +30. WIDENS read-only roles and
-- revokes nothing. Safe to rerun.
-- =====================================================================================

SET search_path TO core_platform;

-- -------------------------------------------------------------------------------------
-- One definition of "what a Viewer Admin gets", used by both the trigger and the backfill.
-- The old code stated the rule twice and the two copies drifted; stating it once is the point.
--
-- p_role_id NULL reconciles every Viewer Admin role. Grants only -- never revokes -- so a
-- permission somebody added to a viewer by hand survives.
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core_platform.reconcile_viewer_admin_permissions(p_role_id TEXT DEFAULT NULL)
RETURNS INTEGER AS $$
DECLARE
    granted INTEGER := 0;
BEGIN
    -- Seeds install Triggers BEFORE Seeds, and migrations/shared runs after both -- so on a
    -- fresh database this can be reached while cp_actions does not yet exist. No-op rather than
    -- abort: seeding must not fail, and the backfill at the end of this file reconciles every
    -- viewer role once the table is there.
    IF to_regclass('core_platform.cp_actions') IS NULL THEN
        RAISE NOTICE 'cp_actions not present yet - viewer reconciliation skipped';
        RETURN 0;
    END IF;

    INSERT INTO core_platform.cp_role_permissions
        (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
    SELECT r.tenant_id, r.id, p.id,
           r.role_name || ' can ' || LOWER(p.permission_name),
           CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
    FROM core_platform.cp_roles r
    JOIN core_platform.cp_permissions p      ON p.delete_status = 'NOT_DELETED'
    JOIN core_platform.cp_actions a          ON a.action = p.action AND a.viewer_default
    JOIN core_platform.cp_resource_types rt  ON rt.id = p.resource_type_id
    WHERE r.role_name LIKE '%Viewer Admin%'
      AND r.is_active
      AND r.delete_status = 'NOT_DELETED'
      AND (p_role_id IS NULL OR r.id = p_role_id)
      AND (
            CASE WHEN r.role_name = 'Core Platform Viewer Admin'
                 -- The platform's own viewer: everything that is not a subscribed app, and not
                 -- the system-role bucket.
                 THEN rt.id NOT LIKE 'rt-subscribed-app-%'
                      AND (rt.parent_resource_id IS NULL
                           OR rt.parent_resource_id NOT LIKE 'rt-subscribed-app-%')
                      AND rt.id <> 'rt-system-role'
                 -- An app's viewer: its own resource type, or any child of it. This is what puts
                 -- rt-msg-statistics in reach of Mystoreguard Viewer Admin.
                 ELSE p.resource_type_id = r.resource_type_id
                      OR rt.parent_resource_id = r.resource_type_id
            END
          )
    ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

    GET DIAGNOSTICS granted = ROW_COUNT;
    RETURN granted;
END;
$$ LANGUAGE plpgsql;

-- -------------------------------------------------------------------------------------
-- The trigger now only decides WHICH role; the rule itself lives in one place.
-- Still AFTER INSERT, so it covers new Viewer Admin roles only -- existing ones are the
-- backfill below. Every rule change here needs both halves.
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core_platform.auto_assign_get_permissions_to_viewer_admin_role()
RETURNS TRIGGER AS $$
DECLARE
    granted INTEGER;
BEGIN
    IF NEW.role_name LIKE '%Viewer Admin%' THEN
        granted := core_platform.reconcile_viewer_admin_permissions(NEW.id);
        RAISE NOTICE 'Viewer Admin role %: granted % read-only permission(s)', NEW.role_name, granted;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_auto_assign_get_permissions_to_viewer_admin_role ON core_platform.cp_roles;
CREATE TRIGGER trigger_auto_assign_get_permissions_to_viewer_admin_role
    AFTER INSERT ON core_platform.cp_roles
    FOR EACH ROW
    EXECUTE FUNCTION core_platform.auto_assign_get_permissions_to_viewer_admin_role();

-- -------------------------------------------------------------------------------------
-- Backfill every Viewer Admin role that already exists. This is the half that fixes the live
-- databases; replacing the function above does nothing for rows already inserted.
-- -------------------------------------------------------------------------------------
DO $$
DECLARE granted INTEGER;
BEGIN
    granted := core_platform.reconcile_viewer_admin_permissions();
    RAISE NOTICE 'Viewer Admin backfill: % missing read-only grant(s) added', granted;
END $$;

-- -------------------------------------------------------------------------------------
-- NOTE: Sql/Triggers/01_auto_assign_permissions.sql is deliberately NOT updated. Triggers are
-- installed BEFORE seeds and cp_actions is created afterwards by migrations/shared, so a seed
-- copy of this function would fire against a table that does not exist yet. The shared migration
-- replaces the function after seeding, which is the only safe order. Do not "tidy" this by
-- moving the function into the seed file.
--
-- NOTE, left for the next change: auto_assign_new_permission_to_existing_admin_roles() still
-- decides by name when a NEW permission is inserted, so a newly added `statistics` permission
-- will not reach viewers on its own. Re-running
-- core_platform.reconcile_viewer_admin_permissions() closes that gap until the function is
-- converted; it is idempotent and grants only.
-- -------------------------------------------------------------------------------------
