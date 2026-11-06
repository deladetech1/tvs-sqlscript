-- Help Desk R4: permissions for customers, contracts, web chat, channels and MSP clients, and what
-- each Help Desk role is granted on them.
--
--   * five resource types under rt-subscribed-app-helpdesk;
--   * 14 pairs helpdesk|<resource>|<action>||any;
--   * explicit grants per R4.md §1; nothing is derived from "every pair that exists". The Requester
--     gets nothing new, and Help Desk Admin still holds no rows (allowed by being the role);
--   * the invariants re-asserted. The full Requester rule stays as 20261106-10 owns it (R4 adds
--     nothing to it); this file asserts the Requester holds nothing on R4 resources.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R4.md §1. Idempotent; safe to re-run.

BEGIN;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-helpdesk-customers', 'Help Desk Customers', 'Customer companies, contacts and customer groups',                      'rt-subscribed-app-helpdesk'),
('rt-helpdesk-contracts', 'Help Desk Contracts', 'Support contracts, entitlements and customer-specific SLAs',            'rt-subscribed-app-helpdesk'),
('rt-helpdesk-chat',      'Help Desk Chat',      'Web chat: taking and answering chats, widget settings',                 'rt-subscribed-app-helpdesk'),
('rt-helpdesk-channels',  'Help Desk Channels',  'Mailboxes, inbound keys and SMS settings',                              'rt-subscribed-app-helpdesk'),
('rt-helpdesk-clients',   'Help Desk Clients',   'MSP client accounts, client-scoped agents and client branding',         'rt-subscribed-app-helpdesk')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('reply',  'Reply',  false, false),
('manage', 'Manage', false, false)
ON CONFLICT (action) DO NOTHING;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('customers', 'rt-helpdesk-customers', 'get',    'View customers, contacts and customer groups'),
    ('customers', 'rt-helpdesk-customers', 'create', 'Add customers and contacts'),
    ('customers', 'rt-helpdesk-customers', 'update', 'Change customers and contacts'),
    ('customers', 'rt-helpdesk-customers', 'manage', 'Merge and delete customers and contacts; manage customer groups'),
    ('contracts', 'rt-helpdesk-contracts', 'get',    'View contracts, entitlements and their usage'),
    ('contracts', 'rt-helpdesk-contracts', 'manage', 'Create and change contracts and entitlements'),
    ('chat',      'rt-helpdesk-chat',      'get',    'View web chats'),
    ('chat',      'rt-helpdesk-chat',      'reply',  'Take and answer web chats'),
    ('chat',      'rt-helpdesk-chat',      'manage', 'Set up chat widgets'),
    ('channels',  'rt-helpdesk-channels',  'get',    'View mailboxes, the inbound log and SMS settings'),
    ('channels',  'rt-helpdesk-channels',  'manage', 'Set up mailboxes, inbound keys and SMS settings'),
    ('clients',   'rt-helpdesk-clients',   'get',    'View MSP client accounts'),
    ('clients',   'rt-helpdesk-clients',   'manage', 'Manage MSP client accounts, client agents and branding')
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

-- The grant matrix of R4.md §1, explicit.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-helpdesk-service-manager' AS role_id, k AS resource_key, a AS action FROM (VALUES
        ('customers', 'get'), ('customers', 'create'), ('customers', 'update'), ('customers', 'manage'),
        ('contracts', 'get'), ('contracts', 'manage'), ('chat', 'get'), ('chat', 'reply'), ('chat', 'manage'),
        ('channels', 'get'), ('channels', 'manage'), ('clients', 'get'), ('clients', 'manage')) AS sm(k, a)
    UNION ALL
    SELECT 'role-helpdesk-agent', k, a FROM (VALUES
        ('customers', 'get'), ('customers', 'create'), ('customers', 'update'), ('contracts', 'get'),
        ('chat', 'get'), ('chat', 'reply'), ('channels', 'get'), ('clients', 'get')) AS ag(k, a)
    UNION ALL
    SELECT 'role-helpdesk-collaborator', k, 'get' FROM (VALUES
        ('customers'), ('contracts'), ('chat'), ('clients')) AS co(k)
    UNION ALL
    SELECT 'role-helpdesk-viewer', k, 'get' FROM (VALUES
        ('customers'), ('contracts'), ('chat'), ('channels'), ('clients')) AS vw(k)
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'helpdesk' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

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
    -- The Requester gets nothing in R4.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-helpdesk-requester' AND p.app_prefix = 'helpdesk'
                  AND p.resource_key IN ('customers', 'contracts', 'chat', 'channels', 'clients')) THEN
        RAISE EXCEPTION 'Help Desk Requester holds a permission on customers, contracts, chat, channels or clients';
    END IF;
    -- The Collaborator reads R4 resources; it never answers a chat (as it never replies to a requester).
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-helpdesk-collaborator' AND p.app_prefix = 'helpdesk'
                  AND p.resource_key IN ('customers', 'contracts', 'chat', 'channels', 'clients') AND p.action <> 'get') THEN
        RAISE EXCEPTION 'Help Desk Collaborator may change customers, contracts, chat, channels or clients';
    END IF;
    -- Only the Service Manager manages any R4 resource (the Admin does by being the role).
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id <> 'role-helpdesk-service-manager' AND p.app_prefix = 'helpdesk'
                  AND p.resource_key IN ('customers', 'contracts', 'chat', 'channels', 'clients') AND p.action = 'manage') THEN
        RAISE EXCEPTION 'a role other than Help Desk Service Manager manages customers, contracts, chat, channels or clients';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-helpdesk-admin' AND permission_id LIKE 'permission-helpdesk-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-helpdesk-admin holds Help Desk permission rows';
    END IF;
END $$;

COMMIT;
