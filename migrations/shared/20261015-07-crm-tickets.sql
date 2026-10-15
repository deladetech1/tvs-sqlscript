-- CRM release 5: tickets.
--
-- Complaints, requests and returns, from first contact to resolved: who has it, how urgent
-- it is, the conversation with the customer (by SMS or email, through messaging) and the
-- notes they never see, response-time targets per priority measured in the business's
-- working hours, the customer's own page to follow and answer it, and their rating once
-- it is done.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS crm.crm_ticket_categories (
    id            text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text        NOT NULL,
    bus_id        text        NOT NULL,
    name          text        NOT NULL,
    position      integer     NOT NULL DEFAULT 0,
    is_active     boolean     NOT NULL DEFAULT true,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_crm_ticket_categories_name ON crm.crm_ticket_categories (tenant_id, bus_id, lower(name));

CREATE TABLE IF NOT EXISTS crm.crm_tickets (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,
    -- T-000001, per business.
    number                 text        NOT NULL,
    subject                text        NOT NULL,
    description            text,
    -- open | pending (waiting on the customer) | resolved | closed
    status                 text        NOT NULL DEFAULT 'open',
    -- low | normal | high | urgent
    priority               text        NOT NULL DEFAULT 'normal',
    category_id            text,
    -- How it reached us: phone | walk_in | email | sms | whatsapp | web | other
    channel                text        NOT NULL DEFAULT 'phone',
    contact_id             text,
    company_id             text,
    deal_id                text,
    -- What it is about in another app, as the customer quotes it: a receipt, a loan number.
    source_app             text,
    source_ref             text,
    assignee_user_id       text,
    -- Response-time targets, set from the business's rules when the ticket is opened (or its
    -- priority changes), in its working hours.
    first_response_due_at  timestamptz,
    resolution_due_at      timestamptz,
    first_responded_at     timestamptz,
    resolved_at            timestamptz,
    closed_at              timestamptz,
    -- While waiting on the customer the resolution clock stops; it restarts with the time
    -- spent waiting added on.
    paused_at              timestamptz,
    -- Set once, when a target is missed, so the alert goes once.
    first_response_breached boolean    NOT NULL DEFAULT false,
    resolution_breached    boolean     NOT NULL DEFAULT false,
    reopened_count         integer     NOT NULL DEFAULT 0,
    last_customer_reply_at timestamptz,
    last_agent_reply_at    timestamptz,
    -- The customer's own page.
    public_token           text        NOT NULL,
    -- 1 bad | 2 okay | 3 good
    csat_score             smallint,
    csat_comment           text,
    csat_at                timestamptz,
    created_by             text,
    cdatetime              timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now(),
    delete_status          text        NOT NULL DEFAULT 'NOT_DELETED',
    CONSTRAINT ck_crm_tickets_status   CHECK (status IN ('open', 'pending', 'resolved', 'closed')),
    CONSTRAINT ck_crm_tickets_priority CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    CONSTRAINT ck_crm_tickets_channel  CHECK (channel IN ('phone', 'walk_in', 'email', 'sms', 'whatsapp', 'web', 'other')),
    CONSTRAINT ck_crm_tickets_csat     CHECK (csat_score IS NULL OR csat_score BETWEEN 1 AND 3)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_crm_tickets_number ON crm.crm_tickets (tenant_id, bus_id, number);
CREATE UNIQUE INDEX IF NOT EXISTS ux_crm_tickets_token  ON crm.crm_tickets (public_token);
CREATE INDEX IF NOT EXISTS ix_crm_tickets_bus      ON crm.crm_tickets (tenant_id, bus_id, status, cdatetime DESC);
CREATE INDEX IF NOT EXISTS ix_crm_tickets_assignee ON crm.crm_tickets (tenant_id, assignee_user_id, status);
CREATE INDEX IF NOT EXISTS ix_crm_tickets_contact  ON crm.crm_tickets (contact_id);
CREATE INDEX IF NOT EXISTS ix_crm_tickets_due      ON crm.crm_tickets (status, first_response_due_at, resolution_due_at) WHERE status IN ('open', 'pending');

-- The conversation and everything that happened to the ticket.
CREATE TABLE IF NOT EXISTS crm.crm_ticket_events (
    id            text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text        NOT NULL,
    ticket_id     text        NOT NULL REFERENCES crm.crm_tickets(id) ON DELETE CASCADE,
    -- created | reply | note | customer_reply | status | assigned | priority | category | rating
    kind          text        NOT NULL,
    body          text,
    -- A reply that went to the customer, and how.
    channel       text,
    message_id    text,
    -- Shown on the customer's page.
    is_public     boolean     NOT NULL DEFAULT false,
    actor_id      text,
    -- A customer has no user id: their name as they gave it.
    actor_name    text,
    detail        jsonb       NOT NULL DEFAULT '{}'::jsonb,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_crm_ticket_events_ticket ON crm.crm_ticket_events (ticket_id, cdatetime);

-- Answers used again and again.
CREATE TABLE IF NOT EXISTS crm.crm_saved_replies (
    id            text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text        NOT NULL,
    bus_id        text        NOT NULL,
    name          text        NOT NULL,
    body          text        NOT NULL,
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    delete_status text        NOT NULL DEFAULT 'NOT_DELETED'
);
CREATE INDEX IF NOT EXISTS ix_crm_saved_replies_bus ON crm.crm_saved_replies (tenant_id, bus_id);

-- Response-time targets, per priority. NULL: no target.
CREATE TABLE IF NOT EXISTS crm.crm_sla_targets (
    tenant_id                text     NOT NULL,
    bus_id                   text     NOT NULL,
    priority                 text     NOT NULL,
    first_response_minutes   integer,
    resolution_minutes       integer,
    PRIMARY KEY (tenant_id, bus_id, priority),
    CONSTRAINT ck_crm_sla_targets_priority CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    CONSTRAINT ck_crm_sla_targets_minutes  CHECK ((first_response_minutes IS NULL OR first_response_minutes > 0)
                                              AND (resolution_minutes IS NULL OR resolution_minutes > 0))
);

CREATE TABLE IF NOT EXISTS crm.crm_ticket_settings (
    tenant_id              text        NOT NULL,
    bus_id                 text        NOT NULL,
    -- Targets count only working time.
    business_hours_only    boolean     NOT NULL DEFAULT true,
    work_start             smallint    NOT NULL DEFAULT 8,
    work_end               smallint    NOT NULL DEFAULT 17,
    -- ISO days: 1 Monday .. 7 Sunday.
    work_days              smallint[]  NOT NULL DEFAULT '{1,2,3,4,5}',
    -- Tell the customer a ticket was opened, and when it is resolved (with a rating link).
    notify_on_create       boolean     NOT NULL DEFAULT true,
    notify_on_resolve      boolean     NOT NULL DEFAULT true,
    ask_rating             boolean     NOT NULL DEFAULT true,
    -- A resolved ticket closes itself after this many days without the customer coming back.
    auto_close_days        integer     DEFAULT 3,
    -- New tickets shared out in turn among these people.
    auto_assign            boolean     NOT NULL DEFAULT false,
    assign_user_ids        text[]      NOT NULL DEFAULT '{}',
    assign_last_index      integer     NOT NULL DEFAULT -1,
    next_number            integer     NOT NULL DEFAULT 1,
    updated_by             text,
    updated_at             timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, bus_id),
    CONSTRAINT ck_crm_ticket_settings_hours CHECK (work_start BETWEEN 0 AND 23 AND work_end BETWEEN 1 AND 24 AND work_start < work_end),
    CONSTRAINT ck_crm_ticket_settings_close CHECK (auto_close_days IS NULL OR auto_close_days BETWEEN 1 AND 90)
);

-- Messages a ticket sent (its replies, its notices) belong to it.
ALTER TABLE crm.crm_messages ADD COLUMN IF NOT EXISTS ticket_id text;
CREATE INDEX IF NOT EXISTS ix_crm_messages_ticket ON crm.crm_messages (ticket_id) WHERE ticket_id IS NOT NULL;

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-crm-tickets', 'CRM Tickets', 'Complaints and requests, their response-time targets and saved replies', 'rt-subscribed-app-crm')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('tickets', 'rt-crm-tickets', 'get',    'See tickets and the service dashboard'),
    ('tickets', 'rt-crm-tickets', 'create', 'Open tickets'),
    ('tickets', 'rt-crm-tickets', 'update', 'Work tickets: reply, note, change status'),
    ('tickets', 'rt-crm-tickets', 'delete', 'Delete tickets'),
    ('tickets', 'rt-crm-tickets', 'assign', 'Give tickets to someone else'),
    ('tickets', 'rt-crm-tickets', 'manage', 'Set response-time targets, categories, saved replies and service rules')
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
        ('role-crm-user', 'get'), ('role-crm-user', 'create'), ('role-crm-user', 'update'),
        ('role-crm-viewer', 'get'),
        ('role-crm-sales-manager', 'get'), ('role-crm-sales-manager', 'create'), ('role-crm-sales-manager', 'update'),
        ('role-crm-sales-manager', 'delete'), ('role-crm-sales-manager', 'assign'), ('role-crm-sales-manager', 'manage')
       ) AS spec(role_id, action)
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'crm' AND p.resource_key = 'tickets' AND p.action = spec.action
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
     WHERE p.app_prefix = 'crm' AND p.resource_key = 'tickets' AND p.delete_status = 'NOT_DELETED'
       AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                        WHERE rp.role_id = 'role-crm-sales-manager' AND rp.permission_id = p.id);
    IF n > 0 THEN
        RAISE EXCEPTION 'role-crm-sales-manager lacks % ticket permission(s)', n;
    END IF;
END $$;

COMMIT;
