-- =====================================================================================
-- When a NEW permission is inserted, route it by action and resource, not by name.
--
-- auto_assign_new_permission_to_existing_admin_roles() is the last place still reading
-- permission_name to decide who gets what, and it is wrong in two ways:
--
-- 1. Viewer Admin roles are gated on `NEW.permission_name LIKE '%Get%'`, so a permission
--    named "Mystoreguard Customers Statistics" never reaches a read-only role. 20260928-06
--    fixed that for roles that already exist; this fixes it for permissions added later.
--
-- 2. Admin is meant to read logs but never modify them -- cp_roles calls it "can do anything
--    except log modification". The rule matches `'%-log-%'` or `'% log %'`, and every log
--    permission is named "... Logs Delete". "logs" is not "log", so the guard has never fired:
--    on saas-dev today role-admin holds permission-cp-logs-delete, permission-msg-logs-delete
--    and permission-loandrift-logs-delete. Somebody who can erase an audit trail is not
--    somebody the trail can be trusted about.
--
-- Both now read the structure 20260928-05 recorded: cp_actions.is_read_only and
-- cp_permissions.resource_key. This changes routing for permissions inserted FROM NOW ON.
-- It does not revoke anything already granted -- the three Admin log grants above are still
-- there and removing them is a deliberate, separate decision.
--
-- Safe to rerun.
-- =====================================================================================

SET search_path TO core_platform;

CREATE OR REPLACE FUNCTION core_platform.auto_assign_new_permission_to_existing_admin_roles()
RETURNS TRIGGER AS $$
DECLARE
    parent_resource_id_var TEXT;
    is_read_only_var       BOOLEAN;
    granted                INTEGER;
BEGIN
    SELECT parent_resource_id INTO parent_resource_id_var
    FROM core_platform.cp_resource_types
    WHERE id = NEW.resource_type_id;

    IF NOT FOUND THEN
        RAISE NOTICE 'No resource type found for permission: %', NEW.id;
        RETURN NEW;
    END IF;

    -- A permission may arrive with no action yet (the column is nullable on purpose until the
    -- seeds supply it). Treat unknown as "not a read", which is the cautious direction: it can
    -- only withhold a log permission from Admin, never hand one over.
    SELECT a.is_read_only INTO is_read_only_var
    FROM core_platform.cp_actions a WHERE a.action = NEW.action;
    is_read_only_var := COALESCE(is_read_only_var, false);

    -- ---------------------------------------------------------------------------------
    -- 1. Resource-scoped admin roles: the permission's own resource type, or its parent.
    --    Unchanged. Owner and Admin are handled below by name; Viewer Admin and Store Sales
    --    Personnel are excluded here because their grants are decided differently.
    -- ---------------------------------------------------------------------------------
    INSERT INTO core_platform.cp_role_permissions
        (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
    SELECT r.tenant_id, r.id, NEW.id, r.role_name || ' can ' || LOWER(NEW.permission_name),
           CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
    FROM core_platform.cp_roles r
    WHERE r.resource_type_id <> 'rt-system-role'
      AND r.role_name NOT LIKE '%Viewer Admin%'
      AND r.role_name NOT LIKE '%Store Sales Personnel%'
      AND (r.resource_type_id = NEW.resource_type_id
        OR (parent_resource_id_var IS NOT NULL AND r.resource_type_id = parent_resource_id_var))
    ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

    -- ---------------------------------------------------------------------------------
    -- 2. Viewer Admin roles: one shared rule, the same one the backfill and the role trigger
    --    use. Guarded because on a fresh database the seed fires this before
    --    migrations/shared has created either cp_actions or the function itself.
    -- ---------------------------------------------------------------------------------
    IF to_regproc('core_platform.reconcile_viewer_admin_permissions') IS NOT NULL THEN
        granted := core_platform.reconcile_viewer_admin_permissions();
        IF granted > 0 THEN
            RAISE NOTICE 'Viewer Admin roles picked up % permission(s) after inserting %', granted, NEW.id;
        END IF;
    END IF;

    -- ---------------------------------------------------------------------------------
    -- 3. Owner: nothing to do. Allowed by BEING the role (tvs-package 1.0.42), so granting
    --    here would re-create on the next permission insert exactly what 20260929-03
    --    removed. This function is redefined here AFTER the trigger file runs, so removing
    --    the rule there alone left it live in the database -- which is where it was found.
    -- ---------------------------------------------------------------------------------


    -- ---------------------------------------------------------------------------------
    -- 4. Admin: everything except MODIFYING logs. `resource_key = 'logs'` is the whole log
    --    family across every app (cp, msg, loandrift), and is_read_only says whether this
    --    particular verb changes them -- which is what the name matching was trying and
    --    failing to express.
    -- ---------------------------------------------------------------------------------
    -- 4. Admin: nothing to do either. Any app, any resource, never a write to logs -- by
    --    being the role (tvs-package 1.0.46), not by holding 510 rows.
    -- ---------------------------------------------------------------------------------


    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_auto_assign_new_permission_to_existing_admin_roles ON core_platform.cp_permissions;
CREATE TRIGGER trigger_auto_assign_new_permission_to_existing_admin_roles
    AFTER INSERT ON core_platform.cp_permissions
    FOR EACH ROW
    EXECUTE FUNCTION core_platform.auto_assign_new_permission_to_existing_admin_roles();

-- -------------------------------------------------------------------------------------
-- NOTE: as with 20260928-06, Sql/Triggers/01_auto_assign_permissions.sql keeps the old
-- version on purpose. Triggers install BEFORE seeds, and this function needs cp_actions and
-- reconcile_viewer_admin_permissions, both created afterwards by migrations/shared. The
-- guards above make it safe if it is ever reached early; the seed copy being replaced after
-- seeding is the intended order.
-- -------------------------------------------------------------------------------------
