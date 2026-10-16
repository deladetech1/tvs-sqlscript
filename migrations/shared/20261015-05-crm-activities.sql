-- CRM release 3: activities.
--
-- Tasks, calls, meetings, notes, visits and messages logged by hand, each linked to a
-- contact, company, deal or lead and owned by a person; reminders (in the app and by SMS
-- through the tenant's own gateway in core platform); follow-ups the CRM schedules itself
-- (a deal moving stage, a quote sent and not opened, a deal going cold); and the
-- notifications a person sees in the CRM's bell.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS crm.crm_activities (
    id                text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text        NOT NULL,
    org_id            text        NOT NULL,
    bus_id            text        NOT NULL,
    -- task | call | meeting | note | visit | email | sms | whatsapp
    kind              text        NOT NULL,
    subject           text        NOT NULL,
    body              text,
    -- open | done | cancelled. A note is done the moment it is written.
    status            text        NOT NULL DEFAULT 'open',
    -- low | normal | high
    priority          text        NOT NULL DEFAULT 'normal',
    -- When it is due (task), happens (call, meeting, visit) or was written (note).
    due_at            timestamptz,
    -- A meeting's end. NULL for everything else.
    ends_at           timestamptz,
    all_day           boolean     NOT NULL DEFAULT false,
    done_at           timestamptz,
    done_by           text,
    -- Calls: answered | no_answer | busy | left_message | wrong_number.
    -- Meetings and visits: held | no_show | rescheduled. Anything else: free text.
    outcome           text,
    -- in | out, for calls and messages.
    direction         text,
    duration_minutes  integer,
    location          text,
    owner_user_id     text,
    -- The other people of the organisation at a meeting.
    attendee_user_ids text[]      NOT NULL DEFAULT ARRAY[]::text[],
    contact_id        text,
    company_id        text,
    deal_id           text,
    lead_id           text,
    -- When to remind the owner, and how: any of app, sms.
    remind_at         timestamptz,
    remind_channels   text[]      NOT NULL DEFAULT ARRAY['app']::text[],
    reminded_at       timestamptz,
    -- A note kept at the top of a record.
    is_pinned         boolean     NOT NULL DEFAULT false,
    -- none | daily | weekly | monthly: completing one makes the next.
    recurrence        text        NOT NULL DEFAULT 'none',
    recurrence_until  date,
    series_id         text,
    -- manual, or the follow-up rule that made it.
    source            text        NOT NULL DEFAULT 'manual',
    -- Stops one rule making the same follow-up twice: "quote:<id>:unopened".
    auto_key          text,
    delete_status     text        NOT NULL DEFAULT 'NOT_DELETED',
    created_by        text,
    updated_by        text,
    deleted_by        text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_crm_activities_kind CHECK (kind IN ('task', 'call', 'meeting', 'note', 'visit', 'email', 'sms', 'whatsapp')),
    CONSTRAINT ck_crm_activities_status CHECK (status IN ('open', 'done', 'cancelled')),
    CONSTRAINT ck_crm_activities_priority CHECK (priority IN ('low', 'normal', 'high')),
    CONSTRAINT ck_crm_activities_direction CHECK (direction IS NULL OR direction IN ('in', 'out')),
    CONSTRAINT ck_crm_activities_recurrence CHECK (recurrence IN ('none', 'daily', 'weekly', 'monthly')),
    CONSTRAINT ck_crm_activities_ends CHECK (ends_at IS NULL OR due_at IS NULL OR ends_at >= due_at),
    CONSTRAINT ck_crm_activities_duration CHECK (duration_minutes IS NULL OR duration_minutes >= 0)
);
CREATE INDEX IF NOT EXISTS ix_crm_activities_scope   ON crm.crm_activities (tenant_id, bus_id, delete_status, status, due_at);
CREATE INDEX IF NOT EXISTS ix_crm_activities_owner   ON crm.crm_activities (tenant_id, owner_user_id, status, due_at);
CREATE INDEX IF NOT EXISTS ix_crm_activities_contact ON crm.crm_activities (contact_id) WHERE contact_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_crm_activities_company ON crm.crm_activities (company_id) WHERE company_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_crm_activities_deal    ON crm.crm_activities (deal_id) WHERE deal_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_crm_activities_lead    ON crm.crm_activities (lead_id) WHERE lead_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_crm_activities_remind  ON crm.crm_activities (remind_at) WHERE reminded_at IS NULL AND status = 'open' AND delete_status = 'NOT_DELETED';
CREATE UNIQUE INDEX IF NOT EXISTS ux_crm_activities_auto ON crm.crm_activities (tenant_id, bus_id, auto_key) WHERE auto_key IS NOT NULL;

-- What the CRM tells a person: a reminder, a follow-up made for them, something handed to them.
CREATE TABLE IF NOT EXISTS crm.crm_notifications (
    id           text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text        NOT NULL,
    bus_id       text        NOT NULL,
    user_id      text        NOT NULL,
    -- reminder | followup | assigned
    kind         text        NOT NULL,
    title        text        NOT NULL,
    body         text,
    -- Where it opens: /activities?id=..., /deals/..., ...
    link         text,
    activity_id  text,
    read_at      timestamptz,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_crm_notifications_user ON crm.crm_notifications (tenant_id, user_id, read_at, cdatetime DESC);

-- A reminder sent by SMS: one row per attempt, so a failure is visible and never resent blind.
CREATE TABLE IF NOT EXISTS crm.crm_reminder_sends (
    id           text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text        NOT NULL,
    bus_id       text        NOT NULL,
    activity_id  text        NOT NULL,
    user_id      text        NOT NULL,
    channel      text        NOT NULL,
    recipient    text,
    -- sent | failed | skipped
    status       text        NOT NULL,
    detail       text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_crm_reminder_sends_activity ON crm.crm_reminder_sends (activity_id);

-- A business's follow-up rules and reminder defaults.
CREATE TABLE IF NOT EXISTS crm.crm_activity_settings (
    tenant_id                 text        NOT NULL,
    bus_id                    text        NOT NULL,
    -- A deal moving to a new open stage gets a task for its owner, due the next day.
    followup_on_stage         boolean     NOT NULL DEFAULT true,
    -- A quote sent and not opened after this many days gets a call task. NULL: off.
    followup_quote_unopened_days integer  DEFAULT 3,
    -- A deal going cold (longer in its stage than the stage allows) gets a task.
    followup_on_cold_deal     boolean     NOT NULL DEFAULT true,
    -- How long before a timed activity its reminder goes, when none is chosen. NULL: none.
    default_reminder_minutes  integer     DEFAULT 15,
    -- Remind by SMS as well, when the person has a phone and the business an SMS gateway.
    sms_reminders             boolean     NOT NULL DEFAULT false,
    updated_by                text,
    updated_at                timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, bus_id),
    CONSTRAINT ck_crm_activity_settings_days CHECK (followup_quote_unopened_days IS NULL OR followup_quote_unopened_days BETWEEN 1 AND 60),
    CONSTRAINT ck_crm_activity_settings_minutes CHECK (default_reminder_minutes IS NULL OR default_reminder_minutes BETWEEN 0 AND 10080)
);

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-crm-activities', 'CRM Activities', 'Tasks, calls, meetings and notes, and the follow-up rules', 'rt-subscribed-app-crm')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('activities', 'rt-crm-activities', 'get',    'View tasks, calls, meetings and notes'),
    ('activities', 'rt-crm-activities', 'create', 'Add tasks, log calls, schedule meetings, write notes'),
    ('activities', 'rt-crm-activities', 'update', 'Edit and complete activities'),
    ('activities', 'rt-crm-activities', 'delete', 'Delete activities'),
    ('activities', 'rt-crm-activities', 'assign', 'Give activities to someone else'),
    ('activities', 'rt-crm-activities', 'manage', 'Set up follow-up rules and reminders')
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
    ON p.app_prefix = 'crm' AND p.resource_key = 'activities' AND p.action = spec.action
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
     WHERE p.app_prefix = 'crm' AND p.resource_key = 'activities' AND p.delete_status = 'NOT_DELETED'
       AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                        WHERE rp.role_id = 'role-crm-sales-manager' AND rp.permission_id = p.id);
    IF n > 0 THEN
        RAISE EXCEPTION 'role-crm-sales-manager lacks % activity permission(s)', n;
    END IF;
END $$;

COMMIT;
