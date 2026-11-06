-- Help Desk R2: permissions for the service catalogue, approvals, fulfilment tasks, the knowledge
-- base and automation rules, and what each Help Desk role is granted on them.
--
--   * five resource types under rt-subscribed-app-helpdesk;
--   * 15 pairs helpdesk|<resource>|<action>||any;
--   * grants per R2.md §1. Help Desk Admin still holds no rows: it is allowed by being the role;
--   * the R0 invariants re-asserted over every helpdesk pair. This file is the newest one that
--     touches the Requester rule, so it owns it: the Requester holds only portal, approvals (get,
--     approve) and knowledge.get. 20261106-01 checks only R0's own resources, so both files hold
--     on every re-run.
--
-- 20261106-01 derives two of its grants from whatever helpdesk pairs exist (the Service Manager
-- gets every pair but tickets.delete, the Viewer every read-only pair but export and settings), so
-- on re-run it gives those two roles these pairs too. That matches §1; the explicit grants below
-- make this file stand on its own.
--
-- `approve` alone never lets anyone decide: the code also requires being the task's approver or
-- their active delegate (R2.md §4).
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R2.md §1. Idempotent; safe to re-run.

BEGIN;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-helpdesk-catalog',    'Help Desk Catalog',    'The service catalogue: sections, items, request forms, eligibility and cost centres', 'rt-subscribed-app-helpdesk'),
('rt-helpdesk-approvals',  'Help Desk Approvals',  'Approval policies, requests, decisions and delegations',                           'rt-subscribed-app-helpdesk'),
('rt-helpdesk-tasks',      'Help Desk Tasks',      'Fulfilment tasks, their checklists, dependencies and time entries',                'rt-subscribed-app-helpdesk'),
('rt-helpdesk-knowledge',  'Help Desk Knowledge',  'Knowledge base articles, their versions, review and publication',                  'rt-subscribed-app-helpdesk'),
('rt-helpdesk-automation', 'Help Desk Automation', 'Automation rules and their run history',                                           'rt-subscribed-app-helpdesk')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

-- publish is new; approve and manage exist already. Asserted here so this file stands on its own.
INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('publish', 'Publish', false, false),
('approve', 'Approve', false, false),
('manage',  'Manage',  false, false)
ON CONFLICT (action) DO NOTHING;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('catalog',    'rt-helpdesk-catalog',    'get',     'View the service catalogue and cost centres'),
    ('catalog',    'rt-helpdesk-catalog',    'manage',  'Set up catalogue sections, items, request forms, eligibility and cost centres'),
    ('approvals',  'rt-helpdesk-approvals',  'get',     'View approval requests and policies'),
    ('approvals',  'rt-helpdesk-approvals',  'approve', 'Decide approval tasks assigned to oneself or delegated to oneself'),
    ('approvals',  'rt-helpdesk-approvals',  'manage',  'Set up approval policies and manage any approval request'),
    ('tasks',      'rt-helpdesk-tasks',      'get',     'View fulfilment tasks and time entries'),
    ('tasks',      'rt-helpdesk-tasks',      'create',  'Create fulfilment tasks'),
    ('tasks',      'rt-helpdesk-tasks',      'update',  'Work fulfilment tasks, checklists and time entries'),
    ('knowledge',  'rt-helpdesk-knowledge',  'get',     'Read knowledge base articles'),
    ('knowledge',  'rt-helpdesk-knowledge',  'create',  'Draft knowledge base articles'),
    ('knowledge',  'rt-helpdesk-knowledge',  'update',  'Edit knowledge base drafts and submit them for review'),
    ('knowledge',  'rt-helpdesk-knowledge',  'publish', 'Review and publish knowledge base articles'),
    ('knowledge',  'rt-helpdesk-knowledge',  'manage',  'Set up knowledge base categories and archive articles'),
    ('automation', 'rt-helpdesk-automation', 'get',     'View automation rules and their runs'),
    ('automation', 'rt-helpdesk-automation', 'manage',  'Create, change and switch automation rules')
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

-- The grant matrix of R2.md §1.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-helpdesk-service-manager' AS role_id, k AS resource_key, a AS action FROM (VALUES
        ('catalog', 'get'), ('catalog', 'manage'), ('approvals', 'get'), ('approvals', 'approve'), ('approvals', 'manage'),
        ('tasks', 'get'), ('tasks', 'create'), ('tasks', 'update'), ('knowledge', 'get'), ('knowledge', 'create'),
        ('knowledge', 'update'), ('knowledge', 'publish'), ('knowledge', 'manage'), ('automation', 'get'),
        ('automation', 'manage')) AS sm(k, a)
    UNION ALL
    SELECT 'role-helpdesk-agent', k, a FROM (VALUES
        ('catalog', 'get'), ('approvals', 'get'), ('approvals', 'approve'), ('tasks', 'get'), ('tasks', 'create'),
        ('tasks', 'update'), ('knowledge', 'get'), ('knowledge', 'create'), ('knowledge', 'update'),
        ('automation', 'get')) AS ag(k, a)
    UNION ALL
    SELECT 'role-helpdesk-collaborator', k, a FROM (VALUES
        ('catalog', 'get'), ('approvals', 'get'), ('approvals', 'approve'), ('tasks', 'get'), ('tasks', 'update'),
        ('knowledge', 'get')) AS co(k, a)
    UNION ALL
    SELECT 'role-helpdesk-requester', k, a FROM (VALUES
        ('approvals', 'get'), ('approvals', 'approve'), ('knowledge', 'get')) AS rq(k, a)
    UNION ALL
    SELECT 'role-helpdesk-viewer', k, 'get' FROM (VALUES
        ('catalog'), ('approvals'), ('tasks'), ('knowledge'), ('automation')) AS vw(k)
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'helpdesk' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ===================================================================== invariants
-- The R0 invariants over every helpdesk pair, and R2's. Properties only, never counts.
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
    -- The Requester rule, owned by this file (it replaces R0's "nothing outside the portal").
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-helpdesk-requester' AND p.app_prefix = 'helpdesk'
                  AND NOT (p.resource_key = 'portal'
                           OR (p.resource_key = 'approvals' AND p.action IN ('get', 'approve'))
                           OR (p.resource_key = 'knowledge' AND p.action = 'get'))) THEN
        RAISE EXCEPTION 'Help Desk Requester holds a Help Desk permission outside portal, approvals (get, approve) and knowledge.get';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-helpdesk-collaborator' AND p.app_prefix = 'helpdesk'
                  AND p.resource_key = 'conversations' AND p.action = 'reply') THEN
        RAISE EXCEPTION 'Help Desk Collaborator may reply to the requester';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id <> 'role-helpdesk-service-manager' AND p.app_prefix = 'helpdesk'
                  AND ((p.resource_key IN ('tickets', 'reports', 'logs') AND p.action = 'export')
                       OR (p.resource_key = 'knowledge' AND p.action = 'publish')
                       OR (p.resource_key IN ('automation', 'catalog', 'approvals') AND p.action = 'manage'))) THEN
        RAISE EXCEPTION 'a role other than Help Desk Service Manager holds an export, knowledge.publish, or catalog, approvals or automation manage';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-helpdesk-admin' AND permission_id LIKE 'permission-helpdesk-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-helpdesk-admin holds Help Desk permission rows';
    END IF;
END $$;

COMMIT;
