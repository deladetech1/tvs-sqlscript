-- Help Desk (app-helpdesk) joins the platform: a service desk for internal and external requests.
-- Tickets, public replies and internal notes, the employee portal, queues, teams, SLAs and reports,
-- then catalogue, approvals, automation, assets, ITSM and the other channels in later releases.
--
-- Served by the shared apps backend (deladetech1/tvs-shared-apps-bk, module "helpdesk") like the CRM,
-- Projects, Invoicing, Expenses, HMS, SCM and Manufacturing; frontend tvs-helpdesk-ft. It is
-- subscribed on its own and needs no other app.
-- Its cp_apps row, tier prices and the role-cp-admin exclusion live in the CorePlatform seed
-- (04_others.sql), which owns every app row. This file holds the rest:
--
--   * the helpdesk schema and its audit trail (hd_audit_logs, append-only); the feature tables come
--     in the files after this one;
--   * its cp_app_schemas row, so activity-log retention finds helpdesk.hd_audit_logs;
--   * resource types, permissions (helpdesk|<resource>|<action>||any) for R0 and the roles:
--     Help Desk Admin is allowed by BEING the role and holds no helpdesk rows; the job roles carry
--     grants. Later releases add their resources and grants in their own files;
--   * which features each subscription tier includes (cp_app_feature_catalog);
--   * the reserved label "helpdesk" and the route rows for the website and the API.
--
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R0.md §1-§6 (it wins over the other documents).
-- Nothing here asserts on rows a module seed creates. Idempotent; safe to re-run.

BEGIN;

CREATE SCHEMA IF NOT EXISTS helpdesk;

INSERT INTO core_platform.cp_app_schemas (app_id, schema_name, description)
VALUES ('app-helpdesk', 'helpdesk', 'Help Desk audit logs')
ON CONFLICT (app_id) DO UPDATE SET schema_name = EXCLUDED.schema_name,
                                   description = EXCLUDED.description;

-- Who changed what, when, why, from where. Never updated or deleted, except by activity-log
-- retention (which deletes old rows by tenant_id and cdatetime, as a superuser-owned job).
CREATE TABLE IF NOT EXISTS helpdesk.hd_audit_logs (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    org_id       text,
    bus_id       text,
    entity_type  text NOT NULL,
    entity_id    text NOT NULL,
    action       text NOT NULL,
    changes      jsonb NOT NULL DEFAULT '{}',
    reason       text,
    source       text NOT NULL DEFAULT 'ui',
    actor_id     text,
    device_id    text,
    request_id   text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS hd_audit_entity_idx
    ON helpdesk.hd_audit_logs (tenant_id, entity_type, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS hd_audit_business_idx
    ON helpdesk.hd_audit_logs (bus_id, cdatetime DESC);

CREATE OR REPLACE FUNCTION helpdesk.hd_audit_logs_append_only() RETURNS trigger
LANGUAGE plpgsql AS $f$
BEGIN
    RAISE EXCEPTION 'hd_audit_logs is append-only: % is not allowed', TG_OP
        USING ERRCODE = 'integrity_constraint_violation';
END
$f$;
DROP TRIGGER IF EXISTS hd_audit_logs_append_only ON helpdesk.hd_audit_logs;
CREATE TRIGGER hd_audit_logs_append_only BEFORE UPDATE ON helpdesk.hd_audit_logs
    FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_audit_logs_append_only();

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-subscribed-app-helpdesk', 'HELP DESK APP', 'Help Desk Subscribed APP', NULL)
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-helpdesk-tickets',       'Help Desk Tickets',       'Tickets and requests: the record, its fields, its links',        'rt-subscribed-app-helpdesk'),
('rt-helpdesk-conversations', 'Help Desk Conversations', 'Public replies to the requester, on any channel',                'rt-subscribed-app-helpdesk'),
('rt-helpdesk-notes',         'Help Desk Notes',         'Internal notes the requester never sees',                        'rt-subscribed-app-helpdesk'),
('rt-helpdesk-portal',        'Help Desk Portal',        'The employee portal: raising and following one''s own requests', 'rt-subscribed-app-helpdesk'),
('rt-helpdesk-queues',        'Help Desk Queues',        'Shared queues and saved views',                                  'rt-subscribed-app-helpdesk'),
('rt-helpdesk-teams',         'Help Desk Teams',         'Departments, service teams, and agent membership',               'rt-subscribed-app-helpdesk'),
('rt-helpdesk-sla',           'Help Desk SLA',           'SLA policies, business calendars and holidays',                  'rt-subscribed-app-helpdesk'),
('rt-helpdesk-settings',      'Help Desk Settings',      'Statuses, categories, custom fields, templates, numbering',      'rt-subscribed-app-helpdesk'),
('rt-helpdesk-reports',       'Help Desk Reports',       'Dashboards and reports',                                         'rt-subscribed-app-helpdesk'),
('rt-helpdesk-logs',          'Help Desk Logs',          'The Help Desk audit trail',                                        'rt-subscribed-app-helpdesk')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

-- Verbs other apps may not have brought yet; asserted here so this file stands on its own. merge,
-- reply, submit and export are the contract's new verbs; manage, assign, resolve, reopen and delete
-- come from the CorePlatform module seed (00_actions.sql), which a shared file must not rely on.
INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('merge',   'Merge',   false, false),
('reply',   'Reply',   false, false),
('submit',  'Submit',  false, false),
('export',  'Export',  true,  false),
('manage',  'Manage',  false, false),
('assign',  'Assign',  false, false),
('resolve', 'Resolve', false, false),
('reopen',  'Reopen',  false, false),
('delete',  'Delete',  false, false)
ON CONFLICT (action) DO NOTHING;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('tickets',       'rt-helpdesk-tickets',       'get',     'View tickets and requests'),
    ('tickets',       'rt-helpdesk-tickets',       'create',  'Raise tickets on behalf of a requester'),
    ('tickets',       'rt-helpdesk-tickets',       'update',  'Change ticket fields, priority, status and links'),
    ('tickets',       'rt-helpdesk-tickets',       'assign',  'Assign tickets to an agent, team or queue'),
    ('tickets',       'rt-helpdesk-tickets',       'resolve', 'Resolve and close tickets'),
    ('tickets',       'rt-helpdesk-tickets',       'reopen',  'Reopen resolved tickets'),
    ('tickets',       'rt-helpdesk-tickets',       'merge',   'Merge duplicate tickets'),
    ('tickets',       'rt-helpdesk-tickets',       'delete',  'Delete tickets'),
    ('tickets',       'rt-helpdesk-tickets',       'export',  'Export tickets'),
    ('conversations', 'rt-helpdesk-conversations', 'get',     'View public replies to the requester'),
    ('conversations', 'rt-helpdesk-conversations', 'reply',   'Reply to the requester'),
    ('notes',         'rt-helpdesk-notes',         'get',     'View internal notes'),
    ('notes',         'rt-helpdesk-notes',         'create',  'Add internal notes'),
    ('portal',        'rt-helpdesk-portal',        'get',     'Follow one''s own requests in the portal'),
    ('portal',        'rt-helpdesk-portal',        'submit',  'Raise requests in the portal'),
    ('queues',        'rt-helpdesk-queues',        'get',     'View queues and saved views'),
    ('queues',        'rt-helpdesk-queues',        'manage',  'Set up shared queues and saved views'),
    ('teams',         'rt-helpdesk-teams',         'get',     'View departments, teams and their agents'),
    ('teams',         'rt-helpdesk-teams',         'manage',  'Set up departments, teams and agent membership'),
    ('sla',           'rt-helpdesk-sla',           'get',     'View SLA policies, business calendars and holidays'),
    ('sla',           'rt-helpdesk-sla',           'manage',  'Set up SLA policies, business calendars and holidays'),
    ('settings',      'rt-helpdesk-settings',      'get',     'View Help Desk settings'),
    ('settings',      'rt-helpdesk-settings',      'manage',  'Change statuses, categories, custom fields, templates and numbering'),
    ('reports',       'rt-helpdesk-reports',       'get',     'View dashboards and reports'),
    ('reports',       'rt-helpdesk-reports',       'export',  'Export reports'),
    ('logs',          'rt-helpdesk-logs',          'get',     'View the Help Desk audit trail'),
    ('logs',          'rt-helpdesk-logs',          'export',  'Export the Help Desk audit trail')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-helpdesk-' || spec.resource_key || '-' || spec.action,
       'Help Desk ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

-- Neither resource_key nor action holds a hyphen or an underscore today; the pattern allows a
-- later resource_key with an underscore, as Manufacturing's production_orders.
UPDATE core_platform.cp_permissions p
   SET app_prefix = 'helpdesk',
       resource_key = substring(p.id FROM '^permission-helpdesk-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-helpdesk-%'
   AND (p.app_prefix IS DISTINCT FROM 'helpdesk' OR p.action IS NULL);

-- ========================================================================== roles
-- role_name is unique per tenant across every app, so every name starts with "Help Desk".
INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-subscribed-app-helpdesk-admin', 'system-tenant-id', 'Help Desk Admin', 'Administrator of Help Desk: every Help Desk permission', 'rt-subscribed-app-helpdesk', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-helpdesk-service-manager', 'system-tenant-id', 'Help Desk Service Manager', 'Runs the service desk: tickets end to end, queues, teams, SLAs, settings, reports and the audit trail', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-helpdesk-agent',           'system-tenant-id', 'Help Desk Agent',           'Works tickets: raises, assigns, replies, resolves, reopens and merges them', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-helpdesk-collaborator',    'system-tenant-id', 'Help Desk Collaborator',    'Helps on a ticket with internal notes; never replies to the requester', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-helpdesk-requester',       'system-tenant-id', 'Help Desk Requester',       'Raises and follows their own requests in the portal', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-helpdesk-viewer',          'system-tenant-id', 'Help Desk Viewer',          'Reads Help Desk except settings; changes nothing and exports nothing', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name        = EXCLUDED.role_name,
                               description      = EXCLUDED.description,
                               resource_type_id = EXCLUDED.resource_type_id,
                               is_system        = EXCLUDED.is_system,
                               is_active        = EXCLUDED.is_active;

-- The grant matrix of R0.md §4.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-helpdesk-service-manager' AS role_id, p1.resource_key, p1.action
      FROM core_platform.cp_permissions p1
     WHERE p1.app_prefix = 'helpdesk'
       AND NOT (p1.resource_key = 'tickets' AND p1.action = 'delete')
    UNION ALL
    SELECT 'role-helpdesk-agent', k, a FROM (VALUES
        ('tickets', 'get'), ('tickets', 'create'), ('tickets', 'update'), ('tickets', 'assign'),
        ('tickets', 'resolve'), ('tickets', 'reopen'), ('tickets', 'merge'),
        ('conversations', 'get'), ('conversations', 'reply'), ('notes', 'get'), ('notes', 'create'),
        ('portal', 'get'), ('portal', 'submit'), ('queues', 'get'), ('teams', 'get'), ('sla', 'get'),
        ('settings', 'get'), ('reports', 'get')) AS ag(k, a)
    UNION ALL
    SELECT 'role-helpdesk-collaborator', k, a FROM (VALUES
        ('tickets', 'get'), ('conversations', 'get'), ('notes', 'get'), ('notes', 'create'),
        ('portal', 'get'), ('portal', 'submit'), ('teams', 'get')) AS co(k, a)
    UNION ALL
    SELECT 'role-helpdesk-requester', k, a FROM (VALUES
        ('portal', 'get'), ('portal', 'submit')) AS rq(k, a)
    UNION ALL
    SELECT 'role-helpdesk-viewer', p3.resource_key, p3.action
      FROM core_platform.cp_permissions p3
      JOIN core_platform.cp_actions a ON a.action = p3.action AND a.is_read_only AND p3.action <> 'export'
     WHERE p3.app_prefix = 'helpdesk' AND p3.resource_key <> 'settings'
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'helpdesk' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- The core-platform navigation block every app role seeds for itself.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', r.id, p.id
  FROM core_platform.cp_roles r
  JOIN core_platform.cp_permissions p
    ON p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations',
                'permission-user-get-locations')
 WHERE r.id IN ('role-subscribed-app-helpdesk-admin', 'role-helpdesk-service-manager', 'role-helpdesk-agent',
                'role-helpdesk-collaborator', 'role-helpdesk-requester', 'role-helpdesk-viewer')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ========================================================== features per tier
-- Tiers are cumulative (20260821-02): a business on rank R has every feature whose
-- min_tier_rank <= R. 1=BASIC 2=ADVANCE 3=PREMIUM 4=ENTERPRISE (never gated: it means
-- self-hosted). feature_key is the contract between this file, the API
-- (internal/apps/helpdesk/plan.go) and the UI. Placement is the contract's proposal
-- (R0.md §5); the owner sets prices and may move features.
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
-- ---- BASIC: run a service desk ------------------------------------------------------
('helpdesk.desk',         'app-helpdesk', 'Service Desk',                    1, 'Tickets, public replies, internal notes, queues and teams'),
('helpdesk.portal',       'app-helpdesk', 'Employee Portal',                 1, 'Employees raise and follow their own requests'),
('helpdesk.sla',          'app-helpdesk', 'SLAs and Business Hours',         1, 'SLA policies, business calendars and holidays'),
('helpdesk.email',        'app-helpdesk', 'Email Channel',                   1, 'Tickets raised and answered by email'),
('helpdesk.knowledge',    'app-helpdesk', 'Knowledge Base',                  1, 'Articles agents and requesters can search'),
-- ---- ADVANCE: serve more of the business -------------------------------------------
('helpdesk.departments',  'app-helpdesk', 'Multiple Departments',            2, 'IT, HR, facilities and other desks, each with its own settings'),
('helpdesk.catalog',      'app-helpdesk', 'Service Catalogue',               2, 'Request types with their own forms and fulfilment'),
('helpdesk.approvals',    'app-helpdesk', 'Approvals',                       2, 'Requests that wait for a manager or an approver group'),
('helpdesk.customers',    'app-helpdesk', 'Customer Portal and Contracts',   2, 'External customers, their contracts and entitlements'),
('helpdesk.automation',   'app-helpdesk', 'Automation Rules',                2, 'Triggers, routing and escalation rules'),
('helpdesk.assets',       'app-helpdesk', 'Asset Management',                2, 'Assets linked to the people and tickets that use them'),
('helpdesk.reports',      'app-helpdesk', 'Reports and Exports',             2, 'Dashboards, scheduled reports and exports'),
-- ---- PREMIUM: run IT service management --------------------------------------------
('helpdesk.itsm',         'app-helpdesk', 'Incidents, Problems and Changes', 3, 'ITIL incident, problem and change management'),
('helpdesk.cmdb',         'app-helpdesk', 'CMDB',                            3, 'Configuration items and their relationships'),
('helpdesk.status',       'app-helpdesk', 'Status Pages',                    3, 'Public and internal service status pages'),
('helpdesk.omnichannel',  'app-helpdesk', 'Chat, SMS and WhatsApp',          3, 'Tickets raised and answered on chat, SMS and WhatsApp'),
('helpdesk.workflow',     'app-helpdesk', 'Workflow Studio',                 3, 'Your own multi-step workflows'),
('helpdesk.msp',          'app-helpdesk', 'Multi-client (MSP)',              3, 'Serve several client organisations from one desk'),
('helpdesk.integrations', 'app-helpdesk', 'API, Webhooks and Integrations',  3, 'The public API, webhooks and connectors'),
('helpdesk.ai',           'app-helpdesk', 'Service Intelligence (AI)',       3, 'Suggested replies, triage and summaries from your own data')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

-- ================================================================ label and routes
INSERT INTO control_plane.ctl_reserved_labels (label, reason, created_by)
SELECT v.label, v.reason, 'migration:20261106-01'
  FROM (VALUES ('helpdesk', 'a product: helpdesk.dev.trovesuite.com, Help Desk')) AS v(label, reason)
 WHERE NOT EXISTS (SELECT 1 FROM control_plane.ctl_reserved_labels r WHERE r.label = v.label);

-- BOTH the website and the API host (TRAPS.md #8).
INSERT INTO control_plane.ctl_tenant_routes (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT h.host, NULL, 'POOLED', h.cell, 'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261106-01'
  FROM (VALUES ('helpdesk.dev.trovesuite.com',     'uksouth-dev'),
               ('api.helpdesk.dev.trovesuite.com', 'uksouth-dev')) AS h(host, cell)
 WHERE EXISTS (SELECT 1 FROM control_plane.ctl_cells c WHERE c.cell_key = h.cell)
ON CONFLICT (host) DO NOTHING;

-- ============================================================ billing, standalone, data
-- Help Desk stands alone: no other app is needed to subscribe (cp_apps.requires_app_id NULL,
-- 20261028-50). Billed per business until the owner prices agents. On unsubscribe its own schema
-- is purged after the grace period (20261028-60).
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'core_platform' AND table_name = 'cp_apps' AND column_name = 'billing_unit') THEN
        UPDATE core_platform.cp_apps SET billing_unit = 'BUSINESS'
         WHERE id = 'app-helpdesk' AND billing_unit IS DISTINCT FROM 'BUSINESS';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'core_platform' AND table_name = 'cp_apps' AND column_name = 'requires_app_id') THEN
        UPDATE core_platform.cp_apps SET requires_app_id = NULL
         WHERE id = 'app-helpdesk' AND requires_app_id IS NOT NULL;
    END IF;
    IF to_regclass('core_platform.cp_app_data_owners') IS NOT NULL THEN
        INSERT INTO core_platform.cp_app_data_owners (app_id, schema_name, fate, note)
        VALUES ('app-helpdesk', 'helpdesk', 'PURGE', 'Help Desk keeps its data in its own schema only; nothing is shared with another app.')
        ON CONFLICT (app_id) DO UPDATE SET schema_name = EXCLUDED.schema_name, fate = EXCLUDED.fate, note = EXCLUDED.note;
    END IF;
END $$;

-- ===================================================================== invariants
-- R0.md §4, numbered as there. Properties only, never counts.
DO $$
DECLARE n int;
BEGIN
    -- 1. Every Help Desk permission has its pair.
    SELECT count(*) INTO n FROM core_platform.cp_permissions
     WHERE id LIKE 'permission-helpdesk-%' AND (app_prefix <> 'helpdesk' OR resource_key IS NULL OR action IS NULL);
    IF n > 0 THEN
        RAISE EXCEPTION '% Help Desk permission(s) have no pair; nothing would match them', n;
    END IF;
    -- 2. The Viewer changes nothing.
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-helpdesk-viewer' AND p.app_prefix = 'helpdesk' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-helpdesk-viewer holds % Help Desk permission(s) that change data', n;
    END IF;
    -- 3. The Requester holds nothing outside the portal.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-helpdesk-requester' AND p.app_prefix = 'helpdesk' AND p.resource_key <> 'portal') THEN
        RAISE EXCEPTION 'Help Desk Requester holds a Help Desk permission outside the portal';
    END IF;
    -- 4. The Collaborator never replies to the requester.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-helpdesk-collaborator' AND p.app_prefix = 'helpdesk'
                  AND p.resource_key = 'conversations' AND p.action = 'reply') THEN
        RAISE EXCEPTION 'Help Desk Collaborator may reply to the requester';
    END IF;
    -- 5. Only the Service Manager exports (the Admin does by being the role).
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id <> 'role-helpdesk-service-manager' AND p.app_prefix = 'helpdesk'
                  AND p.resource_key IN ('tickets', 'reports', 'logs') AND p.action = 'export') THEN
        RAISE EXCEPTION 'a role other than Help Desk Service Manager may export tickets, reports or logs';
    END IF;
    -- 6. Help Desk Admin holds no rows of its own app.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-helpdesk-admin' AND permission_id LIKE 'permission-helpdesk-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-helpdesk-admin holds Help Desk permission rows';
    END IF;
    -- 7. Neither address belongs to a tenant or is a wildcard.
    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host IN ('helpdesk.dev.trovesuite.com', 'api.helpdesk.dev.trovesuite.com')
                  AND (tenant_id IS NOT NULL OR is_wildcard)) THEN
        RAISE EXCEPTION 'a Help Desk address has been given to a tenant or made a wildcard';
    END IF;
END $$;

COMMIT;
