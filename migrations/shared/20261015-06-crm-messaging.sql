-- CRM release 4: messaging.
--
-- SMS, email and WhatsApp to the people in the CRM: one at a time from a record, or to a
-- whole segment as a campaign. SMS and email go out through the tenant's own gateway and
-- sender in core platform; WhatsApp opens on the sender's own phone. Every message is a
-- row here, written before it is handed over, so what was sent, to whom, and what became
-- of it can always be answered -- and a message is never sent twice by a retry that could
-- not tell whether the first attempt landed.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

-- Reusable wording with merge fields ({first_name}, {quote_link}, ...).
CREATE TABLE IF NOT EXISTS crm.crm_message_templates (
    id            text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text        NOT NULL,
    org_id        text        NOT NULL,
    bus_id        text        NOT NULL,
    name          text        NOT NULL,
    -- sms | email | whatsapp
    channel       text        NOT NULL,
    -- marketing | service. Marketing goes only to people who have not said no, and
    -- carries a way to say no; service (a receipt, a reminder) is something they asked for.
    category      text        NOT NULL DEFAULT 'marketing',
    subject       text,
    body          text        NOT NULL,
    is_active     boolean     NOT NULL DEFAULT true,
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    delete_status text        NOT NULL DEFAULT 'NOT_DELETED',
    CONSTRAINT ck_crm_message_templates_channel  CHECK (channel IN ('sms', 'email', 'whatsapp')),
    CONSTRAINT ck_crm_message_templates_category CHECK (category IN ('marketing', 'service'))
);
CREATE INDEX IF NOT EXISTS ix_crm_message_templates_bus ON crm.crm_message_templates (tenant_id, bus_id, channel);

-- A message to many: who it is for (a segment, or a filter), what it says, and when.
CREATE TABLE IF NOT EXISTS crm.crm_campaigns (
    id               text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text        NOT NULL,
    org_id           text        NOT NULL,
    bus_id           text        NOT NULL,
    name             text        NOT NULL,
    -- sms | email
    channel          text        NOT NULL,
    category         text        NOT NULL DEFAULT 'marketing',
    template_id      text,
    subject          text,
    body             text        NOT NULL DEFAULT '',
    segment_id       text,
    -- Laid over the segment's own filter, or the whole audience when there is no segment.
    filters          jsonb       NOT NULL DEFAULT '{}'::jsonb,
    -- opted_in: only people who said yes on this channel. not_opted_out: everyone except
    -- those who said no. Nobody who said no is ever sent to, whichever is chosen.
    audience_rule    text        NOT NULL DEFAULT 'opted_in',
    -- draft | scheduled | sending | sent | cancelled
    status           text        NOT NULL DEFAULT 'draft',
    scheduled_at     timestamptz,
    started_at       timestamptz,
    finished_at      timestamptz,
    -- Filled in when the audience is drawn, then kept current as messages go.
    recipients       integer     NOT NULL DEFAULT 0,
    skipped          integer     NOT NULL DEFAULT 0,
    -- The CRM's address when it was sent, for the links in each message.
    link_base        text,
    created_by       text,
    sent_by          text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    delete_status    text        NOT NULL DEFAULT 'NOT_DELETED',
    CONSTRAINT ck_crm_campaigns_channel  CHECK (channel IN ('sms', 'email')),
    CONSTRAINT ck_crm_campaigns_category CHECK (category IN ('marketing', 'service')),
    CONSTRAINT ck_crm_campaigns_rule     CHECK (audience_rule IN ('opted_in', 'not_opted_out')),
    CONSTRAINT ck_crm_campaigns_status   CHECK (status IN ('draft', 'scheduled', 'sending', 'sent', 'cancelled'))
);
CREATE INDEX IF NOT EXISTS ix_crm_campaigns_bus ON crm.crm_campaigns (tenant_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS ix_crm_campaigns_due ON crm.crm_campaigns (status, scheduled_at) WHERE status = 'scheduled';

-- Every message, one row per recipient. Also the send queue: queued rows are picked up by
-- the CRM's worker, so a send at 9pm for 8am, a campaign of five thousand, and a retry
-- after the gateway was down are all the same thing.
CREATE TABLE IF NOT EXISTS crm.crm_messages (
    id               text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text        NOT NULL,
    org_id           text        NOT NULL,
    bus_id           text        NOT NULL,
    campaign_id      text,
    template_id      text,
    -- sms | email | whatsapp
    channel          text        NOT NULL,
    category         text        NOT NULL DEFAULT 'service',
    contact_id       text,
    company_id       text,
    deal_id          text,
    lead_id          text,
    quote_id         text,
    -- The phone number or address it went to, as it was at the time.
    to_address       text,
    to_name          text,
    subject          text,
    body             text        NOT NULL,
    -- queued | sending | sent | delivered | failed | skipped | cancelled.
    -- sending is held only while the gateway is being called: a row found in it later
    -- was interrupted, and is reported, never resent, because it may have gone.
    status           text        NOT NULL DEFAULT 'queued',
    -- Why it was not sent: opted_out, not_opted_in, no_address, duplicate, ...
    skip_reason      text,
    error            text,
    -- What core platform calls it, to ask after delivery.
    provider_ref     text,
    segments         integer,
    attempts         integer     NOT NULL DEFAULT 0,
    next_attempt_at  timestamptz NOT NULL DEFAULT now(),
    sent_at          timestamptz,
    delivered_at     timestamptz,
    -- When the gateway was last asked what became of it.
    checked_at       timestamptz,
    -- A link in the message that lets the person say no more, at the CRM's address.
    optout_token     text,
    link_base        text,
    activity_id      text,
    sent_by          text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_crm_messages_channel CHECK (channel IN ('sms', 'email', 'whatsapp')),
    CONSTRAINT ck_crm_messages_status  CHECK (status IN ('queued', 'sending', 'sent', 'delivered', 'failed', 'skipped', 'cancelled'))
);
CREATE INDEX IF NOT EXISTS ix_crm_messages_queue    ON crm.crm_messages (next_attempt_at) WHERE status = 'queued';
CREATE INDEX IF NOT EXISTS ix_crm_messages_tracking ON crm.crm_messages (sent_at) WHERE status = 'sent' AND provider_ref IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_crm_messages_bus      ON crm.crm_messages (tenant_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS ix_crm_messages_contact  ON crm.crm_messages (contact_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS ix_crm_messages_deal     ON crm.crm_messages (deal_id) WHERE deal_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_crm_messages_campaign ON crm.crm_messages (campaign_id, status) WHERE campaign_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS ux_crm_messages_optout ON crm.crm_messages (optout_token) WHERE optout_token IS NOT NULL;
-- One message per person per campaign, however often the audience is drawn.
CREATE UNIQUE INDEX IF NOT EXISTS ux_crm_messages_campaign_contact ON crm.crm_messages (campaign_id, contact_id)
    WHERE campaign_id IS NOT NULL AND contact_id IS NOT NULL;

-- How a business sends.
CREATE TABLE IF NOT EXISTS crm.crm_messaging_settings (
    tenant_id            text        NOT NULL,
    bus_id               text        NOT NULL,
    -- What one SMS segment costs, to show a campaign's cost before it is sent.
    sms_segment_cost     numeric(12,4),
    cost_currency        text,
    -- Shown as the sender of emails, with replies going to reply_to.
    email_from_name      text,
    email_reply_to       text,
    email_signature      text,
    -- Add a short opt-out link to marketing SMS. Email always carries one.
    sms_optout_link      boolean     NOT NULL DEFAULT false,
    -- Campaigns send only between these local hours; outside them they wait.
    send_window_start    smallint    NOT NULL DEFAULT 8,
    send_window_end      smallint    NOT NULL DEFAULT 20,
    updated_by           text,
    updated_at           timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, bus_id),
    CONSTRAINT ck_crm_messaging_settings_window CHECK (send_window_start BETWEEN 0 AND 23 AND send_window_end BETWEEN 1 AND 24 AND send_window_start < send_window_end),
    CONSTRAINT ck_crm_messaging_settings_cost   CHECK (sms_segment_cost IS NULL OR sms_segment_cost >= 0)
);

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-crm-messages',  'CRM Messages',  'SMS, email and WhatsApp to customers, and the templates', 'rt-subscribed-app-crm'),
('rt-crm-campaigns', 'CRM Campaigns', 'Messages to a whole segment at once',                    'rt-subscribed-app-crm')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('messages',  'rt-crm-messages',  'get',    'See messages sent to customers'),
    ('messages',  'rt-crm-messages',  'send',   'Send SMS, email and WhatsApp to a customer'),
    ('messages',  'rt-crm-messages',  'manage', 'Manage message templates and how the business sends'),
    ('campaigns', 'rt-crm-campaigns', 'get',    'See campaigns and how they did'),
    ('campaigns', 'rt-crm-campaigns', 'create', 'Write and edit campaigns'),
    ('campaigns', 'rt-crm-campaigns', 'send',   'Send or schedule a campaign to its audience'),
    ('campaigns', 'rt-crm-campaigns', 'delete', 'Delete draft campaigns')
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
        ('role-crm-user', 'messages', 'get'), ('role-crm-user', 'messages', 'send'),
        ('role-crm-user', 'campaigns', 'get'), ('role-crm-user', 'campaigns', 'create'),
        ('role-crm-viewer', 'messages', 'get'), ('role-crm-viewer', 'campaigns', 'get'),
        ('role-crm-sales-manager', 'messages', 'get'), ('role-crm-sales-manager', 'messages', 'send'),
        ('role-crm-sales-manager', 'messages', 'manage'),
        ('role-crm-sales-manager', 'campaigns', 'get'), ('role-crm-sales-manager', 'campaigns', 'create'),
        ('role-crm-sales-manager', 'campaigns', 'send'), ('role-crm-sales-manager', 'campaigns', 'delete')
       ) AS spec(role_id, resource_key, action)
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'crm' AND p.resource_key = spec.resource_key AND p.action = spec.action
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
     WHERE p.app_prefix = 'crm' AND p.resource_key IN ('messages', 'campaigns') AND p.delete_status = 'NOT_DELETED'
       AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                        WHERE rp.role_id = 'role-crm-sales-manager' AND rp.permission_id = p.id);
    IF n > 0 THEN
        RAISE EXCEPTION 'role-crm-sales-manager lacks % messaging permission(s)', n;
    END IF;
END $$;

COMMIT;
