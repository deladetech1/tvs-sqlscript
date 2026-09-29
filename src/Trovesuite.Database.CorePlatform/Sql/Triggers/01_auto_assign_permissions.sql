-- ====================================================================================================================
-- Triggers for Automated Permission Assignment
-- Function to automatically assign permissions to roles based on resource type
-- This function is triggered after a new role is inserted
-- It extracts the resource type name from the role name and assigns the appropriate permissions to the role
-- This is a dynamic role creation system that allows for the creation of new roles with the appropriate permissions
-- This is a dynamic role creation system that allows for the creation of new roles with the appropriate permissions
-- ====================================================================================================================

-- Set the search path to core_platform schema for this session
SET search_path TO core_platform;

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


CREATE OR REPLACE FUNCTION core_platform.auto_assign_resource_permissions_to_admin_role()
RETURNS TRIGGER AS $$
DECLARE
    permission_record RECORD;
    total_permissions_assigned INTEGER := 0;
BEGIN
    -- Only process roles with a resource_type_id (skip rt-system-role roles like User Profile)
    -- Owner and Admin get all permissions via separate triggers (by role_name)
    -- User Profile role permissions are assigned manually
    -- Viewer Admin roles are handled separately - they should only get GET permissions
    -- Store Sales Personnel role permissions are assigned manually (not via trigger)
    IF NEW.resource_type_id IS NOT NULL 
       AND NEW.resource_type_id != 'rt-system-role'
       AND NEW.role_name NOT LIKE '%Viewer Admin%'
       AND NEW.role_name NOT LIKE '%Store Sales Personnel%' THEN
        -- Verify the resource type exists
        IF NOT EXISTS (SELECT 1 FROM core_platform.cp_resource_types WHERE id = NEW.resource_type_id) THEN
            RAISE NOTICE 'Resource type % does not exist for role: %', NEW.resource_type_id, NEW.role_name;
            RETURN NEW;
        END IF;

        -- Get all permissions for this resource type AND all its child resource types
        -- This includes:
        -- 1. Direct match: permissions where resource_type_id = role's resource_type_id
        -- 2. Child match: permissions where resource_type's parent_resource_id = role's resource_type_id
        FOR permission_record IN
            SELECT p.id, p.permission_name, p.description, rt.resource_type_name
            FROM core_platform.cp_permissions p
            JOIN core_platform.cp_resource_types rt ON p.resource_type_id = rt.id
            WHERE p.resource_type_id = NEW.resource_type_id  -- Direct match
               OR rt.parent_resource_id = NEW.resource_type_id  -- Child match
        LOOP
            -- Insert role permission mapping (ignore duplicates)
            INSERT INTO core_platform.cp_role_permissions (
                tenant_id,
                role_id,
                permission_id,
                description,
                cdate,
                ctime,
                cdatetime
            ) VALUES (
                NEW.tenant_id,
                NEW.id,
                permission_record.id,
                NEW.role_name || ' can ' || LOWER(permission_record.permission_name),
                CURRENT_DATE::TEXT,
                CURRENT_TIME::TEXT,
                CURRENT_TIMESTAMP
            ) ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

            total_permissions_assigned := total_permissions_assigned + 1;
        END LOOP;

        -- Log successful assignment
        RAISE NOTICE 'Successfully assigned % permissions for role: % (resource type: % including children)',
            total_permissions_assigned,
            NEW.role_name,
            NEW.resource_type_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger that fires after inserting a new role
DROP TRIGGER IF EXISTS trigger_auto_assign_resource_permissions_to_admin_role ON core_platform.cp_roles;
CREATE TRIGGER trigger_auto_assign_resource_permissions_to_admin_role
    AFTER INSERT ON core_platform.cp_roles
    FOR EACH ROW
    EXECUTE FUNCTION core_platform.auto_assign_resource_permissions_to_admin_role();


-- ====================================================================================================================
-- ====================================================================================================================
-- ====================================================================================================================
-- ====================================================================================================================

-- Function to automatically assign all permissions to owner role
CREATE OR REPLACE FUNCTION core_platform.auto_assign_all_permissions_to_owner_role()
RETURNS TRIGGER AS $$
DECLARE
    permission_record RECORD;
BEGIN
    -- Only process owner role
    -- Owner role should have ALL permissions
    -- Use the role's tenant_id (system roles use 'system-tenant-id')
    IF NEW.role_name = 'Owner' OR NEW.id = 'role-owner' THEN
        -- Get all permissions and assign them to the owner role
        FOR permission_record IN
            SELECT id, permission_name
            FROM core_platform.cp_permissions
        LOOP
            -- Insert role permission mapping using role's tenant_id (ignore duplicates)
            INSERT INTO core_platform.cp_role_permissions (
                tenant_id,
                role_id,
                permission_id,
                description,
                cdate,
                ctime,
                cdatetime
            ) VALUES (
                NEW.tenant_id,
                NEW.id,
                permission_record.id,
                'Owner has all permissions',
                CURRENT_DATE::TEXT,
                CURRENT_TIME::TEXT,
                CURRENT_TIMESTAMP
            ) ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;
        END LOOP;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- The trigger that used to fire on creating the Owner role is GONE, and the function above
-- is left only so an older database can still drop it cleanly.
--
-- A new tenant's Owner was given all 513 permissions the moment the role was created. It
-- now needs none: the check answers true for the Owner role before it looks at any
-- permission set (tvs-package 1.0.42). Recreating this trigger would hand every new tenant
-- the rows 20260929-03 exists to remove.
DROP TRIGGER IF EXISTS trigger_auto_assign_all_permissions_to_owner_role ON core_platform.cp_roles;

-- ====================================================================================================================
-- ====================================================================================================================
-- ====================================================================================================================
-- ====================================================================================================================

-- ====================================================================================================================
-- Function to automatically assign all permissions (except log modifications) to admin role
-- This function is triggered after a new role is inserted
-- It assigns all permissions except log modification permissions to the Admin role
-- Admin CAN read/view logs but CANNOT modify them
-- ====================================================================================================================

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

-- Create trigger that fires after inserting the admin role
DROP TRIGGER IF EXISTS trigger_auto_assign_all_permissions_except_logs_to_admin_role ON core_platform.cp_roles;
CREATE TRIGGER trigger_auto_assign_all_permissions_except_logs_to_admin_role
    AFTER INSERT ON core_platform.cp_roles
    FOR EACH ROW
    EXECUTE FUNCTION core_platform.auto_assign_all_permissions_except_logs_to_admin_role();

-- ====================================================================================================================
-- ====================================================================================================================
-- ====================================================================================================================
-- ====================================================================================================================

-- ====================================================================================================================
-- Function to automatically assign new permissions to existing admin roles
-- This function is triggered after a new permission is inserted
-- It finds all admin roles for the same resource type and assigns the new permission to them
-- This ensures that when you add new permissions, existing admin roles automatically get them
-- ====================================================================================================================

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
    -- 3. Owner: nothing to do.
    --
    -- Owner used to be granted every permission as it was created, which is why this rule
    -- existed and why it had to be right forever -- one missed backfill and the owner
    -- quietly could not do something. It is now allowed by BEING the role: the check
    -- answers true before it looks at any permission set (tvs-package 1.0.42).
    --
    -- Granting here would undo that on the next deploy. 20260929-03 removes the rows and
    -- this is one of the places that kept putting them back.
    -- ---------------------------------------------------------------------------------

    -- ---------------------------------------------------------------------------------
    -- 4. Admin: everything except MODIFYING logs. `resource_key = 'logs'` is the whole log
    --    family across every app (cp, msg, loandrift), and is_read_only says whether this
    --    particular verb changes them -- which is what the name matching was trying and
    --    failing to express.
    -- ---------------------------------------------------------------------------------
    IF NOT (NEW.resource_key = 'logs' AND NOT is_read_only_var) THEN
        INSERT INTO core_platform.cp_role_permissions
            (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
        SELECT r.tenant_id, r.id, NEW.id,
               CASE WHEN NEW.resource_key = 'logs'
                    THEN 'Admin can view logs but not modify them'
                    ELSE 'Admin has all permissions except log modification' END,
               CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
        FROM core_platform.cp_roles r
        WHERE r.role_name = 'Admin'
        ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;
    ELSE
        RAISE NOTICE 'Withheld % from Admin: it modifies logs', NEW.id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger that fires after inserting a new permission
-- Drop trigger if it exists to ensure it's recreated properly
DROP TRIGGER IF EXISTS trigger_auto_assign_new_permission_to_existing_admin_roles ON core_platform.cp_permissions;
CREATE TRIGGER trigger_auto_assign_new_permission_to_existing_admin_roles
    AFTER INSERT ON core_platform.cp_permissions
    FOR EACH ROW
    EXECUTE FUNCTION core_platform.auto_assign_new_permission_to_existing_admin_roles();

-- ====================================================================================================================
-- ====================================================================================================================
-- ====================================================================================================================
-- ====================================================================================================================

-- ====================================================================================================================
-- Function to automatically assign only GET permissions to Viewer Admin roles
-- This function is triggered after a new role is inserted
-- It assigns only GET permissions (read-only) to roles with "Viewer Admin" in the name
-- ====================================================================================================================

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

-- Create trigger that fires after inserting a new role
DROP TRIGGER IF EXISTS trigger_auto_assign_get_permissions_to_viewer_admin_role ON core_platform.cp_roles;
CREATE TRIGGER trigger_auto_assign_get_permissions_to_viewer_admin_role
    AFTER INSERT ON core_platform.cp_roles
    FOR EACH ROW
    EXECUTE FUNCTION core_platform.auto_assign_get_permissions_to_viewer_admin_role();