-- Workflows (app-workflows) joins the platform as its own app. It was Settings > Workflows inside
-- Core Platform (20261109-81 .. 20261111-31), gated by Core's derived plan and Core's `workflow`
-- permission. Now a business subscribes to Workflows like CRM, Projects or Help Desk: billed per
-- business, its own tiers, roles and permissions. Owner's decision 2026-11-11; nobody was using it,
-- so nobody is moved.
--
-- The engine, tables and API stay Core Platform's (tvs-coreplatform-bk src/entities/workflows,
-- core_platform.cp_workflow*): only who may use them changes. The screens are served by the hub
-- at /workflows until Workflows has its own frontend (workflows.<domain>, held below).
-- Its cp_apps row, tier prices (placeholders, owned by the console) and the role-cp-admin
-- exclusion live in the CorePlatform seed (04_others.sql), which owns every app row. This file:
--
--   * resource types and permissions (workflows|<resource>|<action>||any);
--   * the four roles, each with the core-platform navigation block;
--   * which features each tier includes (cp_app_feature_catalog); the run limits per tier are
--     the backend's (wf_plan.LIMITS);
--   * billing per business, one location per business, standalone, data KEPT on unsubscribe (its
--     tables are in core_platform, which the purge never touches; workflows are paused instead);
--   * retires Core's own `workflow` permission (20261110-11) and the hub feature
--     workflows.designer (20261109-81), which no longer gate anything;
--   * the reserved label "workflows" and the website's route row.
--
-- Nothing here asserts on rows a module seed creates. Idempotent; safe to re-run on every deploy.

BEGIN;

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-subscribed-app-workflows', 'WORKFLOWS APP', 'Workflows Subscribed APP', NULL)
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-workflows-workflows',   'Workflows',                     'The business''s workflows: drafts, versions, publishing, pausing, webhook secrets', 'rt-subscribed-app-workflows'),
('rt-workflows-runs',        'Workflow Runs',                 'Run history, and running, retrying and cancelling runs',                            'rt-subscribed-app-workflows'),
('rt-workflows-templates',   'Workflow Templates',            'The template gallery',                                                               'rt-subscribed-app-workflows'),
('rt-workflows-connections', 'Workflow Connections',          'The organisation''s connections to outside services',                               'rt-subscribed-app-workflows'),
('rt-workflows-variables',   'Workflow Variables',            'The organisation''s variables and secrets for workflows',                           'rt-subscribed-app-workflows'),
('rt-workflows-accounts',    'Workflow Automation Accounts',  'The non-human accounts workflows act as in the other apps',                         'rt-subscribed-app-workflows'),
('rt-workflows-approvals',   'Workflow Approvals',            'Every approval a workflow asked for in the business',                               'rt-subscribed-app-workflows')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

-- Verbs asserted here so this file stands on its own (run comes from 20261110-11, manage from the
-- CorePlatform module seed, which a shared file must not rely on).
INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('run',    'Run',    false, false),
('manage', 'Manage', false, false)
ON CONFLICT (action) DO NOTHING;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('workflows',   'rt-workflows-workflows',   'get',    'See the business''s workflows and their versions'),
    ('workflows',   'rt-workflows-workflows',   'update', 'Build workflows: create, edit, publish, pause, delete, import, dry runs, tests and webhook secrets'),
    ('runs',        'rt-workflows-runs',        'get',    'See run history and every step of a run'),
    ('runs',        'rt-workflows-runs',        'run',    'Run a workflow now or on a list, and retry, replay or cancel its runs'),
    ('templates',   'rt-workflows-templates',   'get',    'Browse the template gallery'),
    ('connections', 'rt-workflows-connections', 'get',    'See the organisation''s connections (never their secrets)'),
    ('connections', 'rt-workflows-connections', 'manage', 'Add, change, test and remove connections'),
    ('variables',   'rt-workflows-variables',   'get',    'See the organisation''s variables (never secret values)'),
    ('variables',   'rt-workflows-variables',   'manage', 'Add, change and remove variables and secrets'),
    ('accounts',    'rt-workflows-accounts',    'get',    'See the automation accounts and what they may do'),
    ('accounts',    'rt-workflows-accounts',    'manage', 'Create automation accounts, grant them roles one holds, and end them'),
    ('approvals',   'rt-workflows-approvals',   'get',    'See every approval workflows asked for in the business')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-workflows-' || spec.resource_key || '-' || spec.action,
       'Workflows ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'workflows',
       resource_key = substring(p.id FROM '^permission-workflows-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-workflows-%'
   AND (p.app_prefix IS DISTINCT FROM 'workflows' OR p.action IS NULL);

-- ========================================================================== roles
-- role_name is unique per tenant across every app, so every name starts with "Workflows".
-- Unlike the other apps' role-subscribed-app-<app>-admin (allowed by BEING the role, which the
-- shared package must know), Workflows Admin holds its grants, so no package release is needed.
INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-workflows-admin',   'system-tenant-id', 'Workflows Admin',   'Every Workflows permission: workflows, runs, templates, connections, variables, automation accounts and approvals', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-workflows-builder', 'system-tenant-id', 'Workflows Builder', 'Builds, publishes and runs workflows; sets up connections and variables', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-workflows-runner',  'system-tenant-id', 'Workflows Runner',  'Runs workflows now, retries and cancels runs; changes no workflow', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-workflows-viewer',  'system-tenant-id', 'Workflows Viewer',  'Sees workflows, their runs and approvals; changes nothing', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name        = EXCLUDED.role_name,
                               description      = EXCLUDED.description,
                               resource_type_id = EXCLUDED.resource_type_id,
                               is_system        = EXCLUDED.is_system,
                               is_active        = EXCLUDED.is_active;

-- The grant matrix, pair by pair (never derived from every workflows pair that exists).
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (VALUES
        ('role-workflows-admin', 'workflows', 'get'), ('role-workflows-admin', 'workflows', 'update'),
        ('role-workflows-admin', 'runs', 'get'), ('role-workflows-admin', 'runs', 'run'),
        ('role-workflows-admin', 'templates', 'get'),
        ('role-workflows-admin', 'connections', 'get'), ('role-workflows-admin', 'connections', 'manage'),
        ('role-workflows-admin', 'variables', 'get'), ('role-workflows-admin', 'variables', 'manage'),
        ('role-workflows-admin', 'accounts', 'get'), ('role-workflows-admin', 'accounts', 'manage'),
        ('role-workflows-admin', 'approvals', 'get'),
        ('role-workflows-builder', 'workflows', 'get'), ('role-workflows-builder', 'workflows', 'update'),
        ('role-workflows-builder', 'runs', 'get'), ('role-workflows-builder', 'runs', 'run'),
        ('role-workflows-builder', 'templates', 'get'),
        ('role-workflows-builder', 'connections', 'get'), ('role-workflows-builder', 'connections', 'manage'),
        ('role-workflows-builder', 'variables', 'get'), ('role-workflows-builder', 'variables', 'manage'),
        ('role-workflows-builder', 'accounts', 'get'), ('role-workflows-builder', 'approvals', 'get'),
        ('role-workflows-runner', 'workflows', 'get'), ('role-workflows-runner', 'runs', 'get'),
        ('role-workflows-runner', 'runs', 'run'), ('role-workflows-runner', 'templates', 'get'),
        ('role-workflows-runner', 'connections', 'get'), ('role-workflows-runner', 'variables', 'get'),
        ('role-workflows-runner', 'approvals', 'get'),
        ('role-workflows-viewer', 'workflows', 'get'), ('role-workflows-viewer', 'runs', 'get'),
        ('role-workflows-viewer', 'templates', 'get'), ('role-workflows-viewer', 'approvals', 'get')
  ) AS spec(role_id, resource_key, action)
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'workflows' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND coalesce(p.delete_status, 'NOT_DELETED') = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- The core-platform navigation block every app role seeds for itself.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', r.id, p.id
  FROM core_platform.cp_roles r
  JOIN core_platform.cp_permissions p
    ON p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations',
                'permission-user-get-locations')
 WHERE r.id IN ('role-workflows-admin', 'role-workflows-builder', 'role-workflows-runner', 'role-workflows-viewer')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ============================================== Core's own `workflow` permission retires
-- 20261110-11 creates permission-workflow-{get,update,run} (app_prefix '') on every deploy and
-- leaves delete_status alone, so they are retired here, after it, every time: nothing checks them
-- now (the backend reads workflows|*), and a live row would show a dead "Workflows" line on Core's
-- permission screens. Their grants (its once-only backfill gave them to roles holding
-- settings|update) are removed; cp_resources loses the line 20261110-11 re-declares.
UPDATE core_platform.cp_permissions
   SET delete_status = 'DELETED'
 WHERE id IN ('permission-workflow-get', 'permission-workflow-update', 'permission-workflow-run')
   AND coalesce(delete_status, 'NOT_DELETED') <> 'DELETED';
DELETE FROM core_platform.cp_role_permissions
 WHERE permission_id IN ('permission-workflow-get', 'permission-workflow-update', 'permission-workflow-run');
DELETE FROM core_platform.cp_resources WHERE app_prefix = '' AND resource_key = 'workflow';

-- The hub feature that gated it (20261109-81 re-asserts it active on every deploy).
DO $$
BEGIN
    IF to_regclass('core_platform.cp_platform_feature_catalog') IS NOT NULL THEN
        UPDATE core_platform.cp_platform_feature_catalog SET is_active = false
         WHERE feature_key = 'workflows.designer' AND is_active;
    END IF;
END $$;

-- ========================================================== features per tier
-- Cumulative (20260821-02): a business on rank R has every feature whose min_tier_rank <= R.
-- 1=BASIC 2=ADVANCE 3=PREMIUM 4=ENTERPRISE (never gated: it means self-hosted). feature_key is
-- the contract between this file, the backend (wf_plan.FEATURES: which steps and triggers need
-- which key) and the screens. Run limits per tier (live workflows, runs a month) are the
-- backend's (wf_plan.LIMITS) and are stated in the descriptions for the plan comparison.
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
-- ---- BASIC: automate inside the business -----------------------------------------
('workflows.designer',    'app-workflows', 'Workflow Builder',       1, 'Start on any app''s event, on a schedule or by hand; conditions, email, SMS, bell notices, waits on working hours, variables and data steps, loops and sub-workflows. 3 live workflows and 500 runs a month'),
('workflows.approvals',   'app-workflows', 'Approvals',              1, 'Ask a named person, group or role to approve, with its own steps for each answer'),
-- ---- ADVANCE: act across the suite and beyond ------------------------------------
('workflows.app_actions', 'app-workflows', 'App Actions',            2, 'Act inside your other apps (each needs its own subscription) as an automation account. 10 live workflows and 2,000 runs a month'),
('workflows.connectors',  'app-workflows', 'Connectors',             2, 'Connections to outside services, their actions and their triggers'),
('workflows.ai',          'app-workflows', 'AI Steps',               2, 'Summarise, classify, extract and write with the organisation''s AI provider'),
('workflows.webhooks',    'app-workflows', 'Webhooks & HTTP',        2, 'Incoming webhooks, HTTP requests, signed outgoing webhooks and waiting for a callback'),
-- ---- PREMIUM: more, at once --------------------------------------------------------
('workflows.concurrency', 'app-workflows', 'Parallel Steps',         3, 'Parallel branches and for-each loops that work on many items at once'),
('workflows.scale',       'app-workflows', 'Higher Limits',          3, '50 live workflows and 20,000 runs a month')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

-- ============================================================ billing, standalone, data
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'core_platform' AND table_name = 'cp_apps' AND column_name = 'billing_unit') THEN
        UPDATE core_platform.cp_apps SET billing_unit = 'BUSINESS'
         WHERE id = 'app-workflows' AND billing_unit IS DISTINCT FROM 'BUSINESS';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'core_platform' AND table_name = 'cp_apps' AND column_name = 'requires_app_id') THEN
        UPDATE core_platform.cp_apps SET requires_app_id = NULL
         WHERE id = 'app-workflows' AND requires_app_id IS NOT NULL;
    END IF;
    -- One location per business, like the other per-business apps (20261019-35).
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'core_platform' AND table_name = 'cp_apps' AND column_name = 'max_locations') THEN
        UPDATE core_platform.cp_apps SET max_locations = 1
         WHERE id = 'app-workflows' AND max_locations IS DISTINCT FROM 1;
    END IF;
    -- KEPT: its tables are core_platform's, which the purge never touches. On unsubscribe the
    -- runtime pauses the business's workflows (pause_reason) instead; nothing is deleted.
    IF to_regclass('core_platform.cp_app_data_owners') IS NOT NULL THEN
        INSERT INTO core_platform.cp_app_data_owners (app_id, schema_name, fate, note)
        VALUES ('app-workflows', NULL, 'KEPT', 'Workflows keeps its data in Core Platform''s tables; on unsubscribe the business''s workflows are paused, never deleted.')
        ON CONFLICT (app_id) DO UPDATE SET schema_name = EXCLUDED.schema_name, fate = EXCLUDED.fate, note = EXCLUDED.note;
    END IF;
END $$;

-- ================================================================ label and route
INSERT INTO control_plane.ctl_reserved_labels (label, reason, created_by)
SELECT v.label, v.reason, 'migration:20261111-41'
  FROM (VALUES ('workflows', 'a product: workflows.dev.trovesuite.com, Workflows (its own frontend, later)')) AS v(label, reason)
 WHERE NOT EXISTS (SELECT 1 FROM control_plane.ctl_reserved_labels r WHERE r.label = v.label);

-- The website only: Workflows' API is Core Platform's (api.coreplatform.<domain>).
INSERT INTO control_plane.ctl_tenant_routes (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT h.host, NULL, 'POOLED', h.cell, 'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261111-41'
  FROM (VALUES ('workflows.dev.trovesuite.com', 'uksouth-dev')) AS h(host, cell)
 WHERE EXISTS (SELECT 1 FROM control_plane.ctl_cells c WHERE c.cell_key = h.cell)
ON CONFLICT (host) DO NOTHING;

-- ===================================================================== invariants
-- Properties only, never counts.
DO $$
DECLARE n int; bad text;
BEGIN
    -- 1. Every Workflows permission has its pair.
    SELECT count(*) INTO n FROM core_platform.cp_permissions
     WHERE id LIKE 'permission-workflows-%' AND (app_prefix <> 'workflows' OR resource_key IS NULL OR action IS NULL);
    IF n > 0 THEN
        RAISE EXCEPTION '% Workflows permission(s) have no pair; nothing would match them', n;
    END IF;
    -- 2. The Viewer changes nothing.
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-workflows-viewer' AND p.app_prefix = 'workflows' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-workflows-viewer holds % Workflows permission(s) that change data', n;
    END IF;
    -- 3. Only the Builder and the Admin change workflows; only the Admin manages automation accounts.
    SELECT string_agg(rp.role_id || ':' || p.resource_key || '-' || p.action, ', ') INTO bad
      FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
     WHERE rp.tenant_id = 'system-tenant-id' AND p.app_prefix = 'workflows'
       AND ((p.resource_key = 'workflows' AND p.action = 'update' AND rp.role_id NOT IN ('role-workflows-admin', 'role-workflows-builder'))
         OR (p.resource_key = 'accounts' AND p.action = 'manage' AND rp.role_id <> 'role-workflows-admin'))
       AND rp.role_id LIKE 'role-workflows-%';
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'a Workflows role holds more than its job: %', bad;
    END IF;
    -- 4. Every Workflows role is named for the app (role_name is unique across apps).
    IF EXISTS (SELECT 1 FROM core_platform.cp_roles WHERE id LIKE 'role-workflows-%' AND role_name NOT LIKE 'Workflows %') THEN
        RAISE EXCEPTION 'a Workflows role has a name that does not start with "Workflows"';
    END IF;
    -- 5. A feature at every sold tier, none at rank 4, every key the app's.
    IF EXISTS (SELECT 1 FROM core_platform.cp_app_feature_catalog WHERE app_id = 'app-workflows' AND (min_tier_rank > 3 OR feature_key NOT LIKE 'workflows.%')) THEN
        RAISE EXCEPTION 'a Workflows feature is gated at ENTERPRISE or is not named workflows.*';
    END IF;
    SELECT string_agg(r::text, ', ') INTO bad FROM generate_series(1, 3) r
     WHERE NOT EXISTS (SELECT 1 FROM core_platform.cp_app_feature_catalog
                        WHERE app_id = 'app-workflows' AND min_tier_rank = r AND is_active);
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'Workflows sells nothing at tier rank(s) %', bad;
    END IF;
    -- 6. Core's old workflow permission is retired and held by nobody.
    IF EXISTS (SELECT 1 FROM core_platform.cp_permissions
                WHERE id IN ('permission-workflow-get', 'permission-workflow-update', 'permission-workflow-run')
                  AND coalesce(delete_status, 'NOT_DELETED') <> 'DELETED')
       OR EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                   WHERE permission_id IN ('permission-workflow-get', 'permission-workflow-update', 'permission-workflow-run')) THEN
        RAISE EXCEPTION 'Core''s workflow permission is still live or granted';
    END IF;
    -- 7. The address belongs to no tenant or silo, and the label is held for this app.
    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host = 'workflows.dev.trovesuite.com' AND (tenant_id IS NOT NULL OR silo_key IS NOT NULL OR is_wildcard)) THEN
        RAISE EXCEPTION 'the Workflows address has been given to a tenant or a silo, or made a wildcard';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM control_plane.ctl_reserved_labels WHERE label = 'workflows' AND reason LIKE '%Workflows%') THEN
        RAISE EXCEPTION 'the reserved label "workflows" does not name the Workflows app';
    END IF;
END $$;

COMMIT;
