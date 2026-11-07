-- Help Desk R5: permissions for Workflow Studio, custom reports, the integration platform, imports,
-- service intelligence and the AI scaffold, and what each Help Desk role is granted on them.
--
--   * five resource types under rt-subscribed-app-helpdesk (reports has one since R0);
--   * 11 pairs helpdesk|<resource>|<action>||any: reports.manage, and the workflows, integrations,
--     imports, insights and ai pairs;
--   * explicit grants per R5.md §1. The Requester gets nothing; Help Desk Admin still holds no rows;
--   * the four R5 plan features, only where missing: 20261106-01 created helpdesk.workflow,
--     helpdesk.reports, helpdesk.integrations and helpdesk.ai already, and the owner may have moved
--     them since, so an existing row is left as it is;
--   * the invariants re-asserted.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R5.md §1. Idempotent; safe to re-run.

BEGIN;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-helpdesk-workflows',    'Help Desk Workflows',    'Workflow Studio: workflows, versions, runs and test runs',            'rt-subscribed-app-helpdesk'),
('rt-helpdesk-integrations', 'Help Desk Integrations', 'API tokens, webhooks, deliveries and integration errors',             'rt-subscribed-app-helpdesk'),
('rt-helpdesk-imports',      'Help Desk Imports',      'CSV imports: mapping, validation, history and rollback',              'rt-subscribed-app-helpdesk'),
('rt-helpdesk-insights',     'Help Desk Insights',     'Service intelligence: recurring issues, risks, workload and gaps',    'rt-subscribed-app-helpdesk'),
('rt-helpdesk-ai',           'Help Desk AI',           'AI settings and the AI usage log',                                    'rt-subscribed-app-helpdesk')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

-- execute exists (Manufacturing) and manage too; asserted so this file stands on its own.
INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('execute', 'Execute', false, false),
('manage',  'Manage',  false, false)
ON CONFLICT (action) DO NOTHING;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('workflows',    'rt-helpdesk-workflows',    'get',     'View workflows and their runs'),
    ('workflows',    'rt-helpdesk-workflows',    'manage',  'Design, test and publish workflows'),
    ('workflows',    'rt-helpdesk-workflows',    'execute', 'Start manual workflows'),
    ('reports',      'rt-helpdesk-reports',      'manage',  'Build custom reports and dashboards, and schedule reports'),
    ('integrations', 'rt-helpdesk-integrations', 'get',     'View API tokens, webhooks, deliveries and integration errors'),
    ('integrations', 'rt-helpdesk-integrations', 'manage',  'Issue and revoke API tokens; manage webhooks'),
    ('imports',      'rt-helpdesk-imports',      'get',     'View imports and their rows'),
    ('imports',      'rt-helpdesk-imports',      'manage',  'Run and roll back imports'),
    ('insights',     'rt-helpdesk-insights',     'get',     'View service insights'),
    ('ai',           'rt-helpdesk-ai',           'get',     'View AI settings and usage'),
    ('ai',           'rt-helpdesk-ai',           'manage',  'Change AI settings')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-helpdesk-' || spec.resource_key || '-' || spec.action,
       'Help Desk ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'helpdesk',
       resource_key = substring(p.id FROM '^permission-helpdesk-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-helpdesk-%'
   AND (p.app_prefix IS DISTINCT FROM 'helpdesk' OR p.action IS NULL);

-- The grant matrix of R5.md §1, explicit.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-helpdesk-service-manager' AS role_id, k AS resource_key, a AS action FROM (VALUES
        ('workflows', 'get'), ('workflows', 'manage'), ('workflows', 'execute'), ('reports', 'manage'),
        ('integrations', 'get'), ('integrations', 'manage'), ('imports', 'get'), ('imports', 'manage'),
        ('insights', 'get'), ('ai', 'get'), ('ai', 'manage')) AS sm(k, a)
    UNION ALL
    SELECT 'role-helpdesk-agent', k, a FROM (VALUES
        ('workflows', 'get'), ('workflows', 'execute'), ('insights', 'get')) AS ag(k, a)
    UNION ALL
    SELECT 'role-helpdesk-collaborator', 'insights', 'get'
    UNION ALL
    SELECT 'role-helpdesk-viewer', k, 'get' FROM (VALUES
        ('workflows'), ('integrations'), ('imports'), ('insights'), ('ai')) AS vw(k)
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'helpdesk' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ===================================================================== plan features
-- Only where missing: an existing row keeps the owner's placement.
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('helpdesk.workflow',     'app-helpdesk', 'Workflow Studio',                3, 'Your own multi-step workflows'),
('helpdesk.reports',      'app-helpdesk', 'Reports and Exports',            2, 'Dashboards, scheduled reports, exports, imports and service insights'),
('helpdesk.integrations', 'app-helpdesk', 'API, Webhooks and Integrations', 3, 'The public API, webhooks and connectors'),
('helpdesk.ai',           'app-helpdesk', 'Service Intelligence (AI)',      3, 'Suggested replies, triage and summaries from your own data')
ON CONFLICT (feature_key) DO NOTHING;

-- ===================================================================== invariants
-- Properties only, never counts.
DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions
     WHERE id LIKE 'permission-helpdesk-%' AND (app_prefix <> 'helpdesk' OR resource_key IS NULL OR action IS NULL);
    IF n > 0 THEN
        RAISE EXCEPTION '% Help Desk permission(s) have no pair; nothing would match them', n;
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-helpdesk-viewer' AND p.app_prefix = 'helpdesk' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-helpdesk-viewer holds % Help Desk permission(s) that change data', n;
    END IF;
    -- The Requester gets nothing in R5.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-helpdesk-requester' AND p.app_prefix = 'helpdesk'
                  AND (p.resource_key IN ('workflows', 'integrations', 'imports', 'insights', 'ai')
                       OR (p.resource_key = 'reports' AND p.action = 'manage'))) THEN
        RAISE EXCEPTION 'Help Desk Requester holds a permission on workflows, reports, integrations, imports, insights or AI';
    END IF;
    -- The Collaborator only reads insights among the R5 resources.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-helpdesk-collaborator' AND p.app_prefix = 'helpdesk'
                  AND (p.resource_key IN ('workflows', 'integrations', 'imports', 'ai')
                       OR (p.resource_key = 'reports' AND p.action = 'manage'))) THEN
        RAISE EXCEPTION 'Help Desk Collaborator holds a permission on workflows, report design, integrations, imports or AI';
    END IF;
    -- Only the Service Manager manages any R5 resource (the Admin does by being the role).
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id <> 'role-helpdesk-service-manager' AND p.app_prefix = 'helpdesk'
                  AND p.resource_key IN ('workflows', 'reports', 'integrations', 'imports', 'ai') AND p.action = 'manage') THEN
        RAISE EXCEPTION 'a role other than Help Desk Service Manager manages workflows, reports, integrations, imports or AI';
    END IF;
    -- Only the Service Manager and the Agent start workflows.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id NOT IN ('role-helpdesk-service-manager', 'role-helpdesk-agent') AND p.app_prefix = 'helpdesk'
                  AND p.resource_key = 'workflows' AND p.action = 'execute') THEN
        RAISE EXCEPTION 'a role other than Help Desk Service Manager or Agent may start workflows';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-helpdesk-admin' AND permission_id LIKE 'permission-helpdesk-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-helpdesk-admin holds Help Desk permission rows';
    END IF;
    -- Nothing is gated at ENTERPRISE (rank 4): it means self-hosted, not a bigger plan.
    IF EXISTS (SELECT 1 FROM core_platform.cp_app_feature_catalog
                WHERE app_id = 'app-helpdesk' AND min_tier_rank >= 4) THEN
        RAISE EXCEPTION 'a Help Desk feature is gated at ENTERPRISE';
    END IF;
END $$;

COMMIT;
