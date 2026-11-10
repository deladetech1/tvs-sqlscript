-- Help Desk phase 3a: field service (tvs-shared-apps-bk docs/helpdesk/contracts/P3-field-service-assets.md §3).
--
--   hd_skills, hd_territories (over Core locations), hd_technicians (+ skills, territories)
--   hd_work_orders: an on-site visit for a ticket -- a Core location or a customer's address, a window, a
--                   technician, required skills, parts, sign-off, photos (ticket attachments), field SLA
--   hd_work_order_skills, hd_work_order_parts, hd_work_order_photos, hd_work_order_events (append-only)
--   hd_settings.fs_travel_buffer_minutes, hd_settings.fs_sla (business minutes per priority)
--   permissions helpdesk|workorders|get/create/update/manage, helpdesk|technicians|get/manage, their grants,
--   the role Help Desk Field Technician, and the plan feature helpdesk.field-service (PREMIUM, rank 3).
--
-- Working hours are Core's (core_platform.cp_effective_working_hours): nothing is stored here.
-- Idempotent; safe to re-run on every deploy. CHECK lists are inline; a later change goes in a newer file.

BEGIN;

DO $$
BEGIN
    IF to_regclass('helpdesk.hd_tickets') IS NULL THEN
        RAISE NOTICE 'helpdesk field service: no helpdesk schema here; it comes with it';
        RETURN;
    END IF;

    CREATE TABLE IF NOT EXISTS helpdesk.hd_skills (
        id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
        tenant_id    text NOT NULL,
        bus_id       text NOT NULL,
        name         text NOT NULL,
        description  text,
        is_active    boolean NOT NULL DEFAULT true,
        cdatetime    timestamptz NOT NULL DEFAULT now(),
        created_by   text,
        updated_at   timestamptz,
        updated_by   text
    );
    CREATE UNIQUE INDEX IF NOT EXISTS hd_skills_name_uq ON helpdesk.hd_skills (tenant_id, bus_id, lower(name));

    CREATE TABLE IF NOT EXISTS helpdesk.hd_territories (
        id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
        tenant_id    text NOT NULL,
        bus_id       text NOT NULL,
        name         text NOT NULL,
        description  text,
        loc_ids      text[] NOT NULL DEFAULT '{}',
        is_active    boolean NOT NULL DEFAULT true,
        cdatetime    timestamptz NOT NULL DEFAULT now(),
        created_by   text,
        updated_at   timestamptz,
        updated_by   text
    );
    CREATE UNIQUE INDEX IF NOT EXISTS hd_territories_name_uq ON helpdesk.hd_territories (tenant_id, bus_id, lower(name));

    CREATE TABLE IF NOT EXISTS helpdesk.hd_technicians (
        id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
        tenant_id    text NOT NULL,
        bus_id       text NOT NULL,
        user_id      text NOT NULL,
        is_active    boolean NOT NULL DEFAULT true,
        home_loc_id  text,
        notes        text,
        cdatetime    timestamptz NOT NULL DEFAULT now(),
        created_by   text,
        updated_at   timestamptz,
        updated_by   text
    );
    CREATE UNIQUE INDEX IF NOT EXISTS hd_technicians_user_uq ON helpdesk.hd_technicians (tenant_id, bus_id, user_id);

    CREATE TABLE IF NOT EXISTS helpdesk.hd_technician_skills (
        technician_id  text NOT NULL REFERENCES helpdesk.hd_technicians (id) ON DELETE CASCADE,
        skill_id       text NOT NULL REFERENCES helpdesk.hd_skills (id) ON DELETE CASCADE,
        PRIMARY KEY (technician_id, skill_id)
    );
    CREATE TABLE IF NOT EXISTS helpdesk.hd_technician_territories (
        technician_id  text NOT NULL REFERENCES helpdesk.hd_technicians (id) ON DELETE CASCADE,
        territory_id   text NOT NULL REFERENCES helpdesk.hd_territories (id) ON DELETE CASCADE,
        PRIMARY KEY (technician_id, territory_id)
    );

    CREATE TABLE IF NOT EXISTS helpdesk.hd_work_orders (
        id                    text PRIMARY KEY DEFAULT gen_random_uuid()::text,
        tenant_id             text NOT NULL,
        bus_id                text NOT NULL,
        number                text NOT NULL,
        ticket_id             text NOT NULL REFERENCES helpdesk.hd_tickets (id),
        client_account_id     text,
        title                 text NOT NULL,
        description           text,
        priority              text NOT NULL DEFAULT 'medium'
                              CONSTRAINT hd_work_orders_priority_check CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
        status                text NOT NULL DEFAULT 'unscheduled'
                              CONSTRAINT hd_work_orders_status_check CHECK (status IN ('unscheduled', 'scheduled', 'travelling',
                                  'on_site', 'completed', 'needs_follow_up', 'cancelled')),
        technician_id         text REFERENCES helpdesk.hd_technicians (id),
        window_start          timestamptz,
        window_end            timestamptz,
        loc_id                text,
        address               text,
        contact_name          text,
        contact_phone         text,
        territory_id          text REFERENCES helpdesk.hd_territories (id),
        travel_started_at     timestamptz,
        arrived_at            timestamptz,
        completed_at          timestamptz,
        on_site_minutes       int CONSTRAINT hd_work_orders_on_site_check CHECK (on_site_minutes >= 0),
        sign_off_name         text,
        signed_off_at         timestamptz,
        no_sign_off_reason    text,
        completion_notes      text,
        follow_up_reason      text,
        follow_up_of_id       text REFERENCES helpdesk.hd_work_orders (id),
        response_due_at       timestamptz,
        resolve_due_at        timestamptz,
        response_breached_at  timestamptz,
        resolve_breached_at   timestamptz,
        warnings              jsonb NOT NULL DEFAULT '[]',
        version               int NOT NULL DEFAULT 1,
        cdatetime             timestamptz NOT NULL DEFAULT now(),
        created_by            text,
        updated_at            timestamptz,
        updated_by            text,
        CONSTRAINT hd_work_orders_window_check CHECK ((window_start IS NULL) = (window_end IS NULL)
                                                     AND (window_end IS NULL OR window_end > window_start)),
        CONSTRAINT hd_work_orders_scheduled_check CHECK (status IN ('unscheduled', 'cancelled')
                                                        OR (technician_id IS NOT NULL AND window_start IS NOT NULL)
                                                        OR status IN ('completed', 'needs_follow_up'))
    );
    CREATE UNIQUE INDEX IF NOT EXISTS hd_work_orders_number_uq ON helpdesk.hd_work_orders (tenant_id, bus_id, number);
    CREATE INDEX IF NOT EXISTS hd_work_orders_ticket_idx ON helpdesk.hd_work_orders (tenant_id, ticket_id);
    CREATE INDEX IF NOT EXISTS hd_work_orders_board_idx ON helpdesk.hd_work_orders (tenant_id, bus_id, technician_id, window_start);
    CREATE INDEX IF NOT EXISTS hd_work_orders_open_idx ON helpdesk.hd_work_orders (resolve_due_at)
        WHERE status NOT IN ('completed', 'needs_follow_up', 'cancelled');

    CREATE TABLE IF NOT EXISTS helpdesk.hd_work_order_skills (
        work_order_id  text NOT NULL REFERENCES helpdesk.hd_work_orders (id) ON DELETE CASCADE,
        skill_id       text NOT NULL REFERENCES helpdesk.hd_skills (id),
        PRIMARY KEY (work_order_id, skill_id)
    );

    CREATE TABLE IF NOT EXISTS helpdesk.hd_work_order_parts (
        id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
        tenant_id      text NOT NULL,
        bus_id         text NOT NULL,
        work_order_id  text NOT NULL REFERENCES helpdesk.hd_work_orders (id) ON DELETE CASCADE,
        kind           text NOT NULL CONSTRAINT hd_work_order_parts_kind_check CHECK (kind IN ('planned', 'used')),
        description    text NOT NULL,
        asset_id       text REFERENCES helpdesk.hd_assets (id),
        qty            numeric(12,3) NOT NULL CONSTRAINT hd_work_order_parts_qty_check CHECK (qty > 0),
        unit_cost      numeric(14,2) CONSTRAINT hd_work_order_parts_cost_check CHECK (unit_cost >= 0),
        currency       text CONSTRAINT hd_work_order_parts_currency_check CHECK (currency ~ '^[A-Z][A-Z][A-Z]$'),
        position       int NOT NULL DEFAULT 0,
        cdatetime      timestamptz NOT NULL DEFAULT now(),
        created_by     text,
        CONSTRAINT hd_work_order_parts_money_check CHECK (unit_cost IS NULL OR currency IS NOT NULL)
    );
    CREATE INDEX IF NOT EXISTS hd_work_order_parts_wo_idx ON helpdesk.hd_work_order_parts (work_order_id, position);

    CREATE TABLE IF NOT EXISTS helpdesk.hd_work_order_photos (
        work_order_id  text NOT NULL REFERENCES helpdesk.hd_work_orders (id) ON DELETE CASCADE,
        attachment_id  text NOT NULL REFERENCES helpdesk.hd_attachments (id),
        tenant_id      text NOT NULL,
        bus_id         text NOT NULL,
        caption        text,
        cdatetime      timestamptz NOT NULL DEFAULT now(),
        created_by     text,
        PRIMARY KEY (work_order_id, attachment_id)
    );

    CREATE TABLE IF NOT EXISTS helpdesk.hd_work_order_events (
        id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
        tenant_id      text NOT NULL,
        bus_id         text NOT NULL,
        work_order_id  text NOT NULL REFERENCES helpdesk.hd_work_orders (id),
        event          text NOT NULL,
        data           jsonb NOT NULL DEFAULT '{}',
        actor_id       text,
        cdatetime      timestamptz NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS hd_work_order_events_wo_idx ON helpdesk.hd_work_order_events (work_order_id, cdatetime);
    DROP TRIGGER IF EXISTS hd_work_order_events_append_only ON helpdesk.hd_work_order_events;
    CREATE TRIGGER hd_work_order_events_append_only BEFORE UPDATE OR DELETE ON helpdesk.hd_work_order_events
        FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_refuse_change();

    ALTER TABLE helpdesk.hd_settings ADD COLUMN IF NOT EXISTS fs_travel_buffer_minutes int NOT NULL DEFAULT 30;
    ALTER TABLE helpdesk.hd_settings ADD COLUMN IF NOT EXISTS fs_sla jsonb NOT NULL DEFAULT
        '{"urgent":{"arrive_minutes":240,"complete_minutes":480},"high":{"arrive_minutes":480,"complete_minutes":960},"medium":{"arrive_minutes":960,"complete_minutes":2400},"low":{"arrive_minutes":2400,"complete_minutes":4800}}';
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'helpdesk.hd_settings'::regclass
                    AND conname = 'hd_settings_fs_travel_buffer_check') THEN
        ALTER TABLE helpdesk.hd_settings ADD CONSTRAINT hd_settings_fs_travel_buffer_check
            CHECK (fs_travel_buffer_minutes BETWEEN 0 AND 480);
    END IF;
END $$;

-- ===================================================================== permissions
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM core_platform.cp_resource_types WHERE id = 'rt-subscribed-app-helpdesk') THEN
        RAISE NOTICE 'helpdesk field service: Help Desk is not registered here; no permissions';
        RETURN;
    END IF;
    INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
    ('rt-helpdesk-workorders',  'Help Desk Work Orders', 'On-site visits: scheduling, dispatch, status, parts, sign-off and photos', 'rt-subscribed-app-helpdesk'),
    ('rt-helpdesk-technicians', 'Help Desk Technicians', 'Field technicians, their skills and territories, and field service settings', 'rt-subscribed-app-helpdesk')
    ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name, description = EXCLUDED.description,
                                   parent_resource_id = EXCLUDED.parent_resource_id;

    WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
        ('workorders',  'rt-helpdesk-workorders',  'get',    'View work orders and the dispatch board'),
        ('workorders',  'rt-helpdesk-workorders',  'create', 'Raise work orders and schedule them'),
        ('workorders',  'rt-helpdesk-workorders',  'update', 'Work a visit: travel, arrive, parts, photos, sign-off and completion'),
        ('workorders',  'rt-helpdesk-workorders',  'manage', 'Dispatch any work order and override schedule conflicts'),
        ('technicians', 'rt-helpdesk-technicians', 'get',    'View technicians, skills and territories'),
        ('technicians', 'rt-helpdesk-technicians', 'manage', 'Manage technicians, skills, territories and field service settings')
    )
    INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
    SELECT 'permission-helpdesk-' || spec.resource_key || '-' || spec.action,
           'Help Desk ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
           spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
      FROM spec
    ON CONFLICT (id) DO UPDATE SET permission_name = EXCLUDED.permission_name, resource_type_id = EXCLUDED.resource_type_id,
                                   description = EXCLUDED.description;

    UPDATE core_platform.cp_permissions p
       SET app_prefix = 'helpdesk', resource_key = substring(p.id FROM '^permission-helpdesk-(.+)-[a-z]+$'),
           action = substring(p.id FROM '-([a-z]+)$'), target = '', scope = 'any'
     WHERE (p.id LIKE 'permission-helpdesk-workorders-%' OR p.id LIKE 'permission-helpdesk-technicians-%')
       AND (p.app_prefix IS DISTINCT FROM 'helpdesk' OR p.action IS NULL);

    INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
    ('role-helpdesk-field-technician', 'system-tenant-id', 'Help Desk Field Technician',
     'Works their own on-site visits: travel, arrival, parts, photos, sign-off and completion, from a phone',
     'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
    ON CONFLICT (id) DO UPDATE SET role_name = EXCLUDED.role_name, description = EXCLUDED.description,
        resource_type_id = EXCLUDED.resource_type_id, is_system = EXCLUDED.is_system, is_active = EXCLUDED.is_active;

    INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
    SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
           CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
      FROM (
        SELECT 'role-helpdesk-service-manager' AS role_id, k AS resource_key, a AS action FROM (VALUES
            ('workorders', 'get'), ('workorders', 'create'), ('workorders', 'update'), ('workorders', 'manage'),
            ('technicians', 'get'), ('technicians', 'manage')) AS sm(k, a)
        UNION ALL
        SELECT 'role-helpdesk-agent', k, a FROM (VALUES
            ('workorders', 'get'), ('workorders', 'create'), ('workorders', 'update'), ('technicians', 'get')) AS ag(k, a)
        UNION ALL
        SELECT 'role-helpdesk-collaborator', 'workorders', 'get'
        UNION ALL
        SELECT 'role-helpdesk-viewer', k, 'get' FROM (VALUES ('workorders'), ('technicians')) AS vw(k)
        UNION ALL
        SELECT 'role-helpdesk-field-technician', k, a FROM (VALUES
            ('workorders', 'get'), ('workorders', 'update'), ('tickets', 'get')) AS ft(k, a)
      ) AS spec
      JOIN core_platform.cp_roles r ON r.id = spec.role_id
      JOIN core_platform.cp_permissions p
        ON p.app_prefix = 'helpdesk' AND p.resource_key = spec.resource_key AND p.action = spec.action
       AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
    ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

    -- The core-platform navigation block every app role seeds for itself.
    INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
    SELECT 'system-tenant-id', 'role-helpdesk-field-technician', p.id
      FROM core_platform.cp_permissions p
     WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                    'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
    ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;
END $$;

-- ===================================================================== plan feature
DO $$
BEGIN
    IF to_regclass('core_platform.cp_app_feature_catalog') IS NULL
       OR NOT EXISTS (SELECT 1 FROM core_platform.cp_app_feature_catalog WHERE app_id = 'app-helpdesk') THEN
        RETURN;
    END IF;
    INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
    ('helpdesk.field-service', 'app-helpdesk', 'Field Service', 3,
     'Work orders for on-site visits, technicians with skills and territories, a dispatch board, the technician''s day on a phone, field SLAs and visit windows in the portals')
    ON CONFLICT (feature_key) DO UPDATE SET app_id = EXCLUDED.app_id, title = EXCLUDED.title,
        min_tier_rank = EXCLUDED.min_tier_rank, description = EXCLUDED.description, is_active = true;
END $$;

-- ===================================================================== checks (invariants, not counts)
DO $$
BEGIN
    IF to_regclass('helpdesk.hd_work_orders') IS NOT NULL AND EXISTS (
        SELECT 1 FROM helpdesk.hd_work_orders w JOIN helpdesk.hd_tickets t ON t.id = w.ticket_id
         WHERE t.tenant_id <> w.tenant_id OR t.bus_id <> w.bus_id) THEN
        RAISE EXCEPTION 'helpdesk field service: a work order belongs to another business''s ticket';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-helpdesk-field-technician' AND p.app_prefix = 'helpdesk'
                  AND NOT ((p.resource_key = 'workorders' AND p.action IN ('get', 'update'))
                           OR (p.resource_key = 'tickets' AND p.action = 'get'))) THEN
        RAISE EXCEPTION 'Help Desk Field Technician holds a Help Desk permission beyond workorders get/update and tickets get';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id NOT IN ('role-helpdesk-service-manager') AND p.app_prefix = 'helpdesk'
                  AND p.resource_key IN ('workorders', 'technicians') AND p.action = 'manage') THEN
        RAISE EXCEPTION 'a role other than Help Desk Service Manager manages work orders or technicians';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-helpdesk-admin' AND permission_id LIKE 'permission-helpdesk-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-helpdesk-admin holds Help Desk permission rows';
    END IF;
END $$;

COMMIT;
