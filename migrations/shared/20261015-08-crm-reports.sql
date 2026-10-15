-- CRM release 6: reports.
--
-- The reports themselves are read from the records; what is stored is who gets one by email,
-- how often, and when it last went. Permissions to see, export and schedule reports.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS crm.crm_report_subscriptions (
    id             text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text        NOT NULL,
    org_id         text        NOT NULL,
    bus_id         text        NOT NULL,
    -- sales | customers | activities | service | messaging
    report_key     text        NOT NULL,
    -- weekly: the last seven days, on `weekday`. monthly: the month before, on the 1st.
    frequency      text        NOT NULL DEFAULT 'weekly',
    -- ISO 1 Monday .. 7 Sunday, for weekly.
    weekday        smallint    NOT NULL DEFAULT 1,
    -- Local hour it goes.
    hour           smallint    NOT NULL DEFAULT 7,
    recipient_user_ids text[]  NOT NULL DEFAULT '{}',
    is_active      boolean     NOT NULL DEFAULT true,
    -- The CRM's address, for the link in the email.
    link_base      text,
    last_sent_at   timestamptz,
    last_error     text,
    created_by     text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_crm_report_subscriptions_key  CHECK (report_key IN ('sales', 'customers', 'activities', 'service', 'messaging')),
    CONSTRAINT ck_crm_report_subscriptions_freq CHECK (frequency IN ('weekly', 'monthly')),
    CONSTRAINT ck_crm_report_subscriptions_when CHECK (weekday BETWEEN 1 AND 7 AND hour BETWEEN 0 AND 23)
);
CREATE INDEX IF NOT EXISTS ix_crm_report_subscriptions_bus ON crm.crm_report_subscriptions (tenant_id, bus_id);

-- ===================================================================== permissions
INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('export', 'Export', true, false)
ON CONFLICT (action) DO NOTHING;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-crm-reports', 'CRM Reports', 'Sales, customer, activity, service and messaging reports', 'rt-subscribed-app-crm')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('reports', 'rt-crm-reports', 'get',    'See reports (each only for what the person may see)'),
    ('reports', 'rt-crm-reports', 'export', 'Download reports to Excel'),
    ('reports', 'rt-crm-reports', 'manage', 'Schedule reports to be emailed')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-crm-' || spec.resource_key || '-' || spec.action,
       'CRM ' || initcap(replace(spec.resource_key, '-', ' ')) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'crm',
       resource_key = substring(p.id FROM '^permission-crm-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-crm-%'
   AND (p.app_prefix IS DISTINCT FROM 'crm' OR p.action IS NULL);

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (VALUES
        ('role-crm-user', 'get'), ('role-crm-user', 'export'),
        ('role-crm-viewer', 'get'),
        ('role-crm-sales-manager', 'get'), ('role-crm-sales-manager', 'export'), ('role-crm-sales-manager', 'manage')
       ) AS spec(role_id, action)
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'crm' AND p.resource_key = 'reports' AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions
     WHERE id LIKE 'permission-crm-%' AND (app_prefix <> 'crm' OR resource_key IS NULL OR action IS NULL);
    IF n > 0 THEN
        RAISE EXCEPTION '% CRM permission(s) have no pair', n;
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-crm-viewer' AND p.app_prefix = 'crm' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-crm-viewer holds % CRM permission(s) that change data', n;
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_permissions p
     WHERE p.app_prefix = 'crm' AND p.resource_key = 'reports' AND p.delete_status = 'NOT_DELETED'
       AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                        WHERE rp.role_id = 'role-crm-sales-manager' AND rp.permission_id = p.id);
    IF n > 0 THEN
        RAISE EXCEPTION 'role-crm-sales-manager lacks % report permission(s)', n;
    END IF;
END $$;

COMMIT;
