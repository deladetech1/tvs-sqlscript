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

-- Create trigger that fires after inserting the owner role
DROP TRIGGER IF EXISTS trigger_auto_assign_all_permissions_to_owner_role ON core_platform.cp_roles;
CREATE TRIGGER trigger_auto_assign_all_permissions_to_owner_role
    AFTER INSERT ON core_platform.cp_roles
    FOR EACH ROW
    EXECUTE FUNCTION core_platform.auto_assign_all_permissions_to_owner_role();

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
    permission_record RECORD;
BEGIN
    -- Only process admin role
    -- Use the role's tenant_id (system roles use 'system-tenant-id')
    IF NEW.role_name = 'Admin' THEN
        -- Get all permissions except log modification permissions
        -- Log permissions are identified by having '-log-' in the permission name
        -- Admin gets read-only log permissions but ALL non-log permissions
        FOR permission_record IN
            SELECT p.id, p.permission_name, rt.resource_type_name
            FROM core_platform.cp_permissions p
            JOIN core_platform.cp_resource_types rt ON p.resource_type_id = rt.id
            WHERE NOT (LOWER(p.permission_name) LIKE '%-log-%' OR LOWER(p.permission_name) LIKE '% log %')  -- Non-log permissions: assign all
               OR ((LOWER(p.permission_name) LIKE '%-log-%' OR LOWER(p.permission_name) LIKE '% log %') AND (  -- Log permissions: only read-only
                   (LOWER(p.permission_name) LIKE '%-log-read%' OR LOWER(p.permission_name) LIKE '%log read%') OR
                   (LOWER(p.permission_name) LIKE '%-log-list%' OR LOWER(p.permission_name) LIKE '%log list%') OR
                   (LOWER(p.permission_name) LIKE '%-log-get%' OR LOWER(p.permission_name) LIKE '%log get%') OR
                   (LOWER(p.permission_name) LIKE '%-log-view%' OR LOWER(p.permission_name) LIKE '%log view%') OR
                   (LOWER(p.permission_name) LIKE '%-log-export%' OR LOWER(p.permission_name) LIKE '%log export%')
               ))
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
                CASE
                    WHEN LOWER(permission_record.permission_name) LIKE '%-log-%' THEN 'Admin can view logs but not modify them'
                    ELSE 'Admin has all permissions except log modification'
                END,
                CURRENT_DATE::TEXT,
                CURRENT_TIME::TEXT,
                CURRENT_TIMESTAMP
            ) ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;
        END LOOP;

        -- Log successful assignment
        RAISE NOTICE 'Successfully assigned all non-log-modification permissions to Admin role';
    END IF;

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
    admin_role_record RECORD;
    resource_type_name_var TEXT;
    parent_resource_id_var TEXT;
BEGIN
    -- Get the resource type name and parent for this permission
    SELECT resource_type_name, parent_resource_id
    INTO resource_type_name_var, parent_resource_id_var
    FROM core_platform.cp_resource_types
    WHERE id = NEW.resource_type_id;

    -- If no resource type found, skip
    IF resource_type_name_var IS NULL THEN
        RAISE NOTICE 'No resource type found for permission: %', NEW.id;
        RETURN NEW;
    END IF;

    -- Find all roles that should get this permission:
    -- 1. Roles with exact resource_type_id match
    -- 2. Roles whose resource_type_id is the parent of this permission's resource_type
    --    (e.g., permission for 'rt-msg-warehouse' assigned to role with 'rt-subscribed-app-msg')
    -- Note: Owner and Admin (rt-system-role) are handled separately below (by role_name)
    -- Note: User Profile role (rt-system-role) is excluded - permissions assigned manually
    -- Note: Viewer Admin roles are handled separately below - only GET permissions
    -- Note: Now cp_roles has tenant_id, so we use each role's own tenant_id
    FOR admin_role_record IN
        SELECT id, role_name, tenant_id
        FROM core_platform.cp_roles
        WHERE resource_type_id != 'rt-system-role'  -- Exclude rt-system-role roles (Owner, Admin, User Profile)
          AND role_name NOT LIKE '%Viewer Admin%'  -- Exclude Viewer Admin roles (handled separately)
          AND role_name NOT LIKE '%Store Sales Personnel%'  -- Exclude Store Sales Personnel (permissions assigned manually)
          AND (resource_type_id = NEW.resource_type_id  -- Direct match
           OR (parent_resource_id_var IS NOT NULL AND resource_type_id = parent_resource_id_var))  -- Parent match
    LOOP
        -- Insert role permission mapping using the role's own tenant_id (ignore duplicates)
        INSERT INTO core_platform.cp_role_permissions (
            tenant_id,
            role_id,
            permission_id,
            description,
            cdate,
            ctime,
            cdatetime
        ) VALUES (
            admin_role_record.tenant_id,
            admin_role_record.id,
            NEW.id,
            admin_role_record.role_name || ' can ' || LOWER(NEW.permission_name),
            CURRENT_DATE::TEXT,
            CURRENT_TIME::TEXT,
            CURRENT_TIMESTAMP
        ) ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

        -- Log successful assignment
        RAISE NOTICE 'Successfully assigned permission % to role %', NEW.id, admin_role_record.role_name;
    END LOOP;

    -- Handle Viewer Admin roles - only assign GET permissions
    -- For Core Platform Viewer Admin: assign GET permissions that don't belong to subscribed apps
    IF NEW.permission_name LIKE '%Get%' OR NEW.permission_name LIKE '% get%' OR 
       NEW.permission_name LIKE '%-get%' OR NEW.permission_name LIKE '% get %' OR
       NEW.permission_name LIKE '%-get-%' OR NEW.permission_name LIKE '% get-%' OR
       NEW.permission_name LIKE '%-get-list%' OR NEW.permission_name LIKE '% get list%' OR
       NEW.permission_name LIKE '%-get-statistics%' OR NEW.permission_name LIKE '% get statistics%' OR
       NEW.permission_name LIKE '%-get-activity-logs%' OR NEW.permission_name LIKE '% get activity logs%' OR
       NEW.permission_name LIKE '%-get-own%' OR NEW.permission_name LIKE '% get own%' OR
       NEW.permission_name LIKE '%-get-locations%' OR NEW.permission_name LIKE '% get locations%' OR
       NEW.permission_name LIKE '%-get-chart-data%' OR NEW.permission_name LIKE '% get chart data%' OR
       NEW.permission_name LIKE '%-get-total-captured%' OR NEW.permission_name LIKE '% get total captured%' OR
       NEW.permission_name LIKE '%-get-payment-dates%' OR NEW.permission_name LIKE '% get payment dates%' OR
       NEW.permission_name LIKE '%-get-loan-messages%' OR NEW.permission_name LIKE '% get loan messages%' OR
       NEW.permission_name LIKE '%-get-deletion-chat-history%' OR NEW.permission_name LIKE '% get deletion chat history%' OR
       NEW.permission_name LIKE '%reports-get%' OR NEW.permission_name LIKE '% reports get%' OR
       NEW.permission_name LIKE '%-reports-get%' OR NEW.permission_name LIKE '% reports-get%' THEN
        
        -- Check if this is a Core Platform permission (not from subscribed apps)
        -- Core Platform permissions don't have parent_resource_id pointing to subscribed apps
        -- and don't have resource_type_id starting with 'rt-subscribed-app-'
        IF (parent_resource_id_var IS NULL OR parent_resource_id_var NOT LIKE 'rt-subscribed-app-%') 
           AND NEW.resource_type_id NOT LIKE 'rt-subscribed-app-%'
           AND NEW.resource_type_id != 'rt-system-role' THEN
            -- Assign to Core Platform Viewer Admin
            INSERT INTO core_platform.cp_role_permissions (
                tenant_id,
                role_id,
                permission_id,
                description,
                cdate,
                ctime,
                cdatetime
            )
            SELECT
                r.tenant_id,
                r.id,
                NEW.id,
                r.role_name || ' can ' || LOWER(NEW.permission_name),
                CURRENT_DATE::TEXT,
                CURRENT_TIME::TEXT,
                CURRENT_TIMESTAMP
            FROM core_platform.cp_roles r
            WHERE r.role_name = 'Core Platform Viewer Admin'
            ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

            IF EXISTS (SELECT 1 FROM core_platform.cp_roles WHERE role_name = 'Core Platform Viewer Admin') THEN
                RAISE NOTICE 'Successfully assigned GET permission % to Core Platform Viewer Admin role', NEW.id;
            END IF;
        END IF;

        -- For application-specific Viewer Admin roles
        -- Assign GET permissions to Viewer Admin roles for the same resource type or parent
        FOR admin_role_record IN
            SELECT id, role_name, tenant_id, resource_type_id
            FROM core_platform.cp_roles
            WHERE role_name LIKE '%Viewer Admin%'
              AND role_name != 'Core Platform Viewer Admin'
              AND (resource_type_id = NEW.resource_type_id  -- Direct match
               OR (parent_resource_id_var IS NOT NULL AND resource_type_id = parent_resource_id_var))  -- Parent match
        LOOP
            INSERT INTO core_platform.cp_role_permissions (
                tenant_id,
                role_id,
                permission_id,
                description,
                cdate,
                ctime,
                cdatetime
            ) VALUES (
                admin_role_record.tenant_id,
                admin_role_record.id,
                NEW.id,
                admin_role_record.role_name || ' can ' || LOWER(NEW.permission_name),
                CURRENT_DATE::TEXT,
                CURRENT_TIME::TEXT,
                CURRENT_TIMESTAMP
            ) ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

            RAISE NOTICE 'Successfully assigned GET permission % to Viewer Admin role %', NEW.id, admin_role_record.role_name;
        END LOOP;
    END IF;

    -- ALWAYS assign to Owner role (if it exists)
    -- Owner should have ALL permissions without exception
    -- Use the role's own tenant_id (system Owner uses 'system-tenant-id')
    INSERT INTO core_platform.cp_role_permissions (
        tenant_id,
        role_id,
        permission_id,
        description,
        cdate,
        ctime,
        cdatetime
    )
    SELECT
        r.tenant_id,
        r.id,
        NEW.id,
        'Owner has all permissions',
        CURRENT_DATE::TEXT,
        CURRENT_TIME::TEXT,
        CURRENT_TIMESTAMP
    FROM core_platform.cp_roles r
    WHERE r.role_name = 'Owner'
    ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

    -- Log assignment attempt (even if role doesn't exist, the INSERT will just do nothing)
    IF EXISTS (SELECT 1 FROM core_platform.cp_roles WHERE role_name = 'Owner') THEN
        RAISE NOTICE 'Successfully assigned permission % to Owner role', NEW.id;
    END IF;

    -- ALWAYS assign to Admin role with special handling for log permissions
    -- Admin should have ALL non-log permissions
    -- Admin should have ONLY read-only log permissions (identified by 'log' in permission name)
    -- Admin CAN read/view logs but CANNOT modify them (no delete, create, update, import)
    -- Handle both formats: "log" with dash (log-read) and with space (log read)
    IF NOT (LOWER(NEW.permission_name) LIKE '%-log-%' OR LOWER(NEW.permission_name) LIKE '% log %') THEN
        -- Non-log permission: assign to Admin
        -- Use the role's own tenant_id (system Admin uses 'system-tenant-id')
        INSERT INTO core_platform.cp_role_permissions (
            tenant_id,
            role_id,
            permission_id,
            description,
            cdate,
            ctime,
            cdatetime
        )
        SELECT
            r.tenant_id,
            r.id,
            NEW.id,
            'Admin has all permissions except log modification',
            CURRENT_DATE::TEXT,
            CURRENT_TIME::TEXT,
            CURRENT_TIMESTAMP
        FROM core_platform.cp_roles r
        WHERE r.role_name = 'Admin'
        ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

        -- Log assignment attempt
        IF EXISTS (SELECT 1 FROM core_platform.cp_roles WHERE role_name = 'Admin') THEN
            RAISE NOTICE 'Successfully assigned permission % to Admin role', NEW.id;
        END IF;
    ELSE
        -- Log permission: only assign read-only permissions to Admin
        -- Read-only log permissions: -log-read, -log-list, -log-get, -log-view, -log-export
        -- Handle both formats: "log-read" (with dash) and "log read" (with space)
        IF (LOWER(NEW.permission_name) LIKE '%-log-read%' OR LOWER(NEW.permission_name) LIKE '%log read%') OR
           (LOWER(NEW.permission_name) LIKE '%-log-list%' OR LOWER(NEW.permission_name) LIKE '%log list%') OR
           (LOWER(NEW.permission_name) LIKE '%-log-get%' OR LOWER(NEW.permission_name) LIKE '%log get%') OR
           (LOWER(NEW.permission_name) LIKE '%-log-view%' OR LOWER(NEW.permission_name) LIKE '%log view%') OR
           (LOWER(NEW.permission_name) LIKE '%-log-export%' OR LOWER(NEW.permission_name) LIKE '%log export%') THEN

            -- Use the role's own tenant_id (system Admin uses 'system-tenant-id')
            INSERT INTO core_platform.cp_role_permissions (
                tenant_id,
                role_id,
                permission_id,
                description,
                cdate,
                ctime,
                cdatetime
            )
            SELECT
                r.tenant_id,
                r.id,
                NEW.id,
                'Admin can view logs but not modify them',
                CURRENT_DATE::TEXT,
                CURRENT_TIME::TEXT,
                CURRENT_TIMESTAMP
            FROM core_platform.cp_roles r
            WHERE r.role_name = 'Admin'
            ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

            IF EXISTS (SELECT 1 FROM core_platform.cp_roles WHERE role_name = 'Admin') THEN
                RAISE NOTICE 'Successfully assigned read-only log permission % to Admin role', NEW.id;
            END IF;
        ELSE
            RAISE NOTICE 'Skipping Admin role assignment for log modification permission % (excluded)', NEW.id;
        END IF;
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
    permission_record RECORD;
    total_permissions_assigned INTEGER := 0;
    resource_type_parent_var TEXT;
BEGIN
    -- Only process roles with "Viewer Admin" in the name
    IF NEW.role_name LIKE '%Viewer Admin%' THEN
        -- Get the resource type parent for this role
        SELECT parent_resource_id INTO resource_type_parent_var
        FROM core_platform.cp_resource_types
        WHERE id = NEW.resource_type_id;

        -- For Core Platform Viewer Admin, assign all GET permissions that don't belong to subscribed apps
        IF NEW.role_name = 'Core Platform Viewer Admin' THEN
            -- Get all GET permissions for Core Platform (not from subscribed apps)
            -- Core Platform permissions don't have parent_resource_id pointing to subscribed apps
            -- and don't have resource_type_id starting with 'rt-subscribed-app-'
            FOR permission_record IN
                SELECT p.id, p.permission_name, p.description, rt.resource_type_name, rt.parent_resource_id
                FROM core_platform.cp_permissions p
                JOIN core_platform.cp_resource_types rt ON p.resource_type_id = rt.id
                WHERE (LOWER(p.permission_name) LIKE '%-get%' OR 
                       LOWER(p.permission_name) LIKE '% get%' OR
                       LOWER(p.permission_name) LIKE '%-get-%' OR
                       LOWER(p.permission_name) LIKE '% get %' OR
                       LOWER(p.permission_name) LIKE '%-get-list%' OR
                       LOWER(p.permission_name) LIKE '% get list%' OR
                       LOWER(p.permission_name) LIKE '%-get-statistics%' OR
                       LOWER(p.permission_name) LIKE '% get statistics%' OR
                       LOWER(p.permission_name) LIKE '%-get-activity-logs%' OR
                       LOWER(p.permission_name) LIKE '% get activity logs%' OR
                       LOWER(p.permission_name) LIKE '%-get-own%' OR
                       LOWER(p.permission_name) LIKE '% get own%' OR
                       LOWER(p.permission_name) LIKE '%-get-locations%' OR
                       LOWER(p.permission_name) LIKE '% get locations%' OR
                       LOWER(p.permission_name) LIKE '%-get-chart-data%' OR
                       LOWER(p.permission_name) LIKE '% get chart data%' OR
                       LOWER(p.permission_name) LIKE '%-get-total-captured%' OR
                       LOWER(p.permission_name) LIKE '% get total captured%' OR
                       LOWER(p.permission_name) LIKE '%-get-payment-dates%' OR
                       LOWER(p.permission_name) LIKE '% get payment dates%' OR
                       LOWER(p.permission_name) LIKE '%-get-loan-messages%' OR
                       LOWER(p.permission_name) LIKE '% get loan messages%' OR
                       LOWER(p.permission_name) LIKE '%-get-deletion-chat-history%' OR
                       LOWER(p.permission_name) LIKE '% get deletion chat history%' OR
                       LOWER(p.permission_name) LIKE '%reports-get%' OR
                       LOWER(p.permission_name) LIKE '% reports get%' OR
                       LOWER(p.permission_name) LIKE '%-reports-get%' OR
                       LOWER(p.permission_name) LIKE '% reports-get%')
                  AND (rt.parent_resource_id IS NULL OR 
                       rt.parent_resource_id NOT LIKE 'rt-subscribed-app-%')
                  AND rt.id NOT LIKE 'rt-subscribed-app-%'
                  AND rt.id != 'rt-system-role'  -- Exclude system role permissions
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
        ELSE
            -- For application-specific Viewer Admin roles (Loandrift, Mystoreguard, etc.)
            -- Get all GET permissions for this resource type and its children
            FOR permission_record IN
                SELECT p.id, p.permission_name, p.description, rt.resource_type_name, rt.parent_resource_id
                FROM core_platform.cp_permissions p
                JOIN core_platform.cp_resource_types rt ON p.resource_type_id = rt.id
                WHERE (p.resource_type_id = NEW.resource_type_id  -- Direct match
                   OR rt.parent_resource_id = NEW.resource_type_id)  -- Child match
                  AND (LOWER(p.permission_name) LIKE '%-get%' OR 
                       LOWER(p.permission_name) LIKE '% get%' OR
                       LOWER(p.permission_name) LIKE '%-get-%' OR
                       LOWER(p.permission_name) LIKE '% get %' OR
                       LOWER(p.permission_name) LIKE '%-get-list%' OR
                       LOWER(p.permission_name) LIKE '% get list%' OR
                       LOWER(p.permission_name) LIKE '%-get-statistics%' OR
                       LOWER(p.permission_name) LIKE '% get statistics%' OR
                       LOWER(p.permission_name) LIKE '%-get-activity-logs%' OR
                       LOWER(p.permission_name) LIKE '% get activity logs%' OR
                       LOWER(p.permission_name) LIKE '%-get-own%' OR
                       LOWER(p.permission_name) LIKE '% get own%' OR
                       LOWER(p.permission_name) LIKE '%-get-locations%' OR
                       LOWER(p.permission_name) LIKE '% get locations%' OR
                       LOWER(p.permission_name) LIKE '%-get-chart-data%' OR
                       LOWER(p.permission_name) LIKE '% get chart data%' OR
                       LOWER(p.permission_name) LIKE '%-get-total-captured%' OR
                       LOWER(p.permission_name) LIKE '% get total captured%' OR
                       LOWER(p.permission_name) LIKE '%-get-payment-dates%' OR
                       LOWER(p.permission_name) LIKE '% get payment dates%' OR
                       LOWER(p.permission_name) LIKE '%-get-loan-messages%' OR
                       LOWER(p.permission_name) LIKE '% get loan messages%' OR
                       LOWER(p.permission_name) LIKE '%-get-deletion-chat-history%' OR
                       LOWER(p.permission_name) LIKE '% get deletion chat history%' OR
                       LOWER(p.permission_name) LIKE '%reports-get%' OR
                       LOWER(p.permission_name) LIKE '% reports get%' OR
                       LOWER(p.permission_name) LIKE '%-reports-get%' OR
                       LOWER(p.permission_name) LIKE '% reports-get%')
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
        END IF;

        -- Log successful assignment
        RAISE NOTICE 'Successfully assigned % GET permissions for Viewer Admin role: % (resource type: %)',
            total_permissions_assigned,
            NEW.role_name,
            NEW.resource_type_id;
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