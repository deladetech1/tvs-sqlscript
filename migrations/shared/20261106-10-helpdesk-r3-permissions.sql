-- Help Desk R3: permissions for incidents, problems, changes, assets, the CMDB, vendors and status
-- pages, what each Help Desk role is granted on them, and two follow-ups.
--
--   * seven resource types under rt-subscribed-app-helpdesk;
--   * 22 pairs helpdesk|<resource>|<action>||any;
--   * grants per R3.md §1. Help Desk Admin still holds no rows: it is allowed by being the role;
--   * hd_notifications.article_id (the R2 follow-up) and a generic link_type / link_id pair;
--   * the invariants re-asserted. This file now owns the full Requester rule: portal, approvals (get,
--     approve), knowledge.get and status.get, nothing else. 20261106-01 and 20261106-05 check the
--     Requester only on their own resources, so every file holds on every re-run.
--
-- 20261106-01 now derives its Service Manager and Viewer grants from R0's resources only (edited in
-- place in the same change), so the grants below are the only way these pairs reach a role.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R3.md §1. Idempotent; safe to re-run.

BEGIN;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-helpdesk-incidents', 'Help Desk Incidents', 'Incident priority, major incidents, stakeholder updates and post-incident reviews', 'rt-subscribed-app-helpdesk'),
('rt-helpdesk-problems',  'Help Desk Problems',  'Problems, root cause analysis, known errors, workarounds and actions',              'rt-subscribed-app-helpdesk'),
('rt-helpdesk-changes',   'Help Desk Changes',   'Changes, templates, maintenance windows, the change calendar and reviews',          'rt-subscribed-app-helpdesk'),
('rt-helpdesk-assets',    'Help Desk Assets',    'Assets, asset types, assignment, warranty, licences and maintenance',               'rt-subscribed-app-helpdesk'),
('rt-helpdesk-cmdb',      'Help Desk CMDB',      'Configuration items and their relations',                                           'rt-subscribed-app-helpdesk'),
('rt-helpdesk-vendors',   'Help Desk Vendors',   'Vendor profiles on Core suppliers, contracts and performance',                      'rt-subscribed-app-helpdesk'),
('rt-helpdesk-status',    'Help Desk Status',    'Internal and public status pages, their events and subscribers',                   'rt-subscribed-app-helpdesk')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('manage', 'Manage', false, false)
ON CONFLICT (action) DO NOTHING;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('incidents', 'rt-helpdesk-incidents', 'get',    'View incidents, major incidents and their reviews'),
    ('incidents', 'rt-helpdesk-incidents', 'create', 'Raise incidents and post updates'),
    ('incidents', 'rt-helpdesk-incidents', 'update', 'Work incidents and major incidents'),
    ('incidents', 'rt-helpdesk-incidents', 'manage', 'Declare and close major incidents, complete reviews, set the priority matrix'),
    ('problems',  'rt-helpdesk-problems',  'get',    'View problems, root cause analyses and known errors'),
    ('problems',  'rt-helpdesk-problems',  'create', 'Raise problems'),
    ('problems',  'rt-helpdesk-problems',  'update', 'Investigate problems, record root causes, workarounds and actions'),
    ('problems',  'rt-helpdesk-problems',  'manage', 'Publish known errors and close problems'),
    ('changes',   'rt-helpdesk-changes',   'get',    'View changes, the change calendar and maintenance windows'),
    ('changes',   'rt-helpdesk-changes',   'create', 'Raise changes'),
    ('changes',   'rt-helpdesk-changes',   'update', 'Plan changes and submit them for approval'),
    ('changes',   'rt-helpdesk-changes',   'manage', 'Schedule, implement and close changes; manage templates and maintenance windows'),
    ('assets',    'rt-helpdesk-assets',    'get',    'View assets, licences and maintenance'),
    ('assets',    'rt-helpdesk-assets',    'create', 'Register assets'),
    ('assets',    'rt-helpdesk-assets',    'update', 'Assign, transfer and maintain assets'),
    ('assets',    'rt-helpdesk-assets',    'manage', 'Retire and dispose of assets; manage asset types'),
    ('cmdb',      'rt-helpdesk-cmdb',      'get',    'View configuration items, relations and impact'),
    ('cmdb',      'rt-helpdesk-cmdb',      'manage', 'Create and change configuration items and their relations'),
    ('vendors',   'rt-helpdesk-vendors',   'get',    'View vendor profiles and contracts'),
    ('vendors',   'rt-helpdesk-vendors',   'manage', 'Manage vendor profiles and contracts'),
    ('status',    'rt-helpdesk-status',    'get',    'View the internal status page'),
    ('status',    'rt-helpdesk-status',    'manage', 'Manage status pages, their events and subscribers')
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

-- The grant matrix of R3.md §1.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-helpdesk-service-manager' AS role_id, k AS resource_key, a AS action FROM (VALUES
        ('incidents', 'get'), ('incidents', 'create'), ('incidents', 'update'), ('incidents', 'manage'),
        ('problems', 'get'), ('problems', 'create'), ('problems', 'update'), ('problems', 'manage'),
        ('changes', 'get'), ('changes', 'create'), ('changes', 'update'), ('changes', 'manage'),
        ('assets', 'get'), ('assets', 'create'), ('assets', 'update'), ('assets', 'manage'),
        ('cmdb', 'get'), ('cmdb', 'manage'), ('vendors', 'get'), ('vendors', 'manage'),
        ('status', 'get'), ('status', 'manage')) AS sm(k, a)
    UNION ALL
    SELECT 'role-helpdesk-agent', k, a FROM (VALUES
        ('incidents', 'get'), ('incidents', 'create'), ('incidents', 'update'),
        ('problems', 'get'), ('problems', 'create'), ('problems', 'update'),
        ('changes', 'get'), ('changes', 'create'), ('changes', 'update'),
        ('assets', 'get'), ('assets', 'create'), ('assets', 'update'),
        ('cmdb', 'get'), ('vendors', 'get'), ('status', 'get')) AS ag(k, a)
    UNION ALL
    SELECT 'role-helpdesk-collaborator', k, 'get' FROM (VALUES
        ('incidents'), ('problems'), ('changes'), ('assets'), ('cmdb')) AS co(k)
    UNION ALL
    SELECT 'role-helpdesk-viewer', k, 'get' FROM (VALUES
        ('incidents'), ('problems'), ('changes'), ('assets'), ('cmdb'), ('vendors'), ('status')) AS vw(k)
    UNION ALL
    SELECT 'role-helpdesk-requester', 'status', 'get'
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'helpdesk' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ================================================================ notification links
-- What a notification is about besides a ticket: an article (R2), or any later kind by type and id.
ALTER TABLE helpdesk.hd_notifications ADD COLUMN IF NOT EXISTS article_id text REFERENCES helpdesk.hd_articles (id);
ALTER TABLE helpdesk.hd_notifications ADD COLUMN IF NOT EXISTS link_type text;
ALTER TABLE helpdesk.hd_notifications ADD COLUMN IF NOT EXISTS link_id text;
-- A link is a pair: both or neither.
ALTER TABLE helpdesk.hd_notifications DROP CONSTRAINT IF EXISTS hd_notifications_link_pair_check;
ALTER TABLE helpdesk.hd_notifications ADD CONSTRAINT hd_notifications_link_pair_check
    CHECK ((link_type IS NULL) = (link_id IS NULL));

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
    -- The full Requester rule, owned by this file.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-helpdesk-requester' AND p.app_prefix = 'helpdesk'
                  AND NOT (p.resource_key = 'portal'
                           OR (p.resource_key = 'approvals' AND p.action IN ('get', 'approve'))
                           OR (p.resource_key = 'knowledge' AND p.action = 'get')
                           OR (p.resource_key = 'status' AND p.action = 'get'))) THEN
        RAISE EXCEPTION 'Help Desk Requester holds a Help Desk permission outside portal, approvals (get, approve), knowledge.get and status.get';
    END IF;
    -- The Collaborator reads ITSM; it never changes it.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-helpdesk-collaborator' AND p.app_prefix = 'helpdesk'
                  AND p.resource_key IN ('incidents', 'problems', 'changes', 'assets', 'cmdb', 'vendors', 'status')
                  AND p.action <> 'get') THEN
        RAISE EXCEPTION 'Help Desk Collaborator may change incidents, problems, changes, assets, the CMDB, vendors or status pages';
    END IF;
    -- Only the Service Manager manages any R3 resource (the Admin does by being the role).
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id <> 'role-helpdesk-service-manager' AND p.app_prefix = 'helpdesk'
                  AND p.resource_key IN ('incidents', 'problems', 'changes', 'assets', 'cmdb', 'vendors', 'status')
                  AND p.action = 'manage') THEN
        RAISE EXCEPTION 'a role other than Help Desk Service Manager manages incidents, problems, changes, assets, the CMDB, vendors or status pages';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-helpdesk-admin' AND permission_id LIKE 'permission-helpdesk-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-helpdesk-admin holds Help Desk permission rows';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_notifications n JOIN helpdesk.hd_articles a ON a.id = n.article_id
                WHERE a.tenant_id <> n.tenant_id OR a.bus_id <> n.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk notification points at an article of another business';
    END IF;
END $$;

COMMIT;
