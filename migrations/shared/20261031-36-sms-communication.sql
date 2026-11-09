-- MyEduGuard: communication and engagement -- keeping every stakeholder informed.
--
--   sms_comms_settings          the languages a school writes in, whether families may start a
--                               conversation, and what replies they can expect
--   sms_families.language       each family's preferred language
--   sms_messages                messages to parents, students and staff by SMS, email and in the
--   sms_message_recipients      app (bulk or to one person); emergency alerts and newsletters go out
--                               the same way. Each recipient's delivery is kept.
--   sms_announcements           the notice board: targeted by campus (school), class or year group,
--   sms_announcement_reads      and role (parents, students, staff, staff roles)
--   sms_conversations           secure two-way messages between a family and a teacher
--   sms_conversation_messages
--   sms_ptm_events              parent-teacher meetings: the evening, the teachers and their slots,
--   sms_ptm_teachers            booked online by families
--   sms_ptm_bookings
--   sms_consent_forms           trip, media, medical and other consents signed in the app
--   sms_consent_responses
--   sms_surveys                 parent, student and staff surveys, with results
--   sms_survey_questions
--   sms_survey_responses
--   sms_newsletters             designed newsletters (blocks), sent by email and read in the app
--   sms_online_payments         fees, trip places and wallet top-ups paid online through the
--                               organisation's gateway in Core Platform
--
-- SMS, email and payments go through the organisation's providers in Core Platform.
-- Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS sms.sms_comms_settings (
    profile_id        text PRIMARY KEY REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    languages         text[] NOT NULL DEFAULT ARRAY['en']::text[],
    family_messages   boolean NOT NULL DEFAULT true,
    reply_note        text,
    sms_signature     text,
    updated_at        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE sms.sms_families ADD COLUMN IF NOT EXISTS language text;

-- =================================================================== messages
CREATE TABLE IF NOT EXISTS sms.sms_messages (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    profile_id       text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    kind             text NOT NULL DEFAULT 'message',
    subject          text NOT NULL,
    body             text NOT NULL,
    translations     jsonb NOT NULL DEFAULT '{}'::jsonb,
    channels         text[] NOT NULL,
    audience         jsonb NOT NULL DEFAULT '{}'::jsonb,
    audience_label   text,
    status           text NOT NULL DEFAULT 'sent',
    emergency_kind   text,
    resolved_at      timestamptz,
    resolved_by      text,
    newsletter_id    text,
    recipients       integer NOT NULL DEFAULT 0,
    sms_sent         integer NOT NULL DEFAULT 0,
    email_sent       integer NOT NULL DEFAULT 0,
    app_sent         integer NOT NULL DEFAULT 0,
    failed           integer NOT NULL DEFAULT 0,
    sent_by          text,
    sent_at          timestamptz NOT NULL DEFAULT now(),
    cdatetime        timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_messages', 'sms_messages_check', $q$'newsletter'$q$, $q$CHECK (
    kind IN ('message', 'emergency', 'newsletter') AND status IN ('sending', 'sent')
    AND channels <@ ARRAY['sms', 'email', 'app']::text[] AND cardinality(channels) > 0
    AND (emergency_kind IS NULL OR emergency_kind IN ('closure', 'lockdown', 'evacuation', 'weather', 'medical', 'security', 'other')))$q$);
-- A newsletter's designed email.
ALTER TABLE sms.sms_messages ADD COLUMN IF NOT EXISTS html text;
CREATE INDEX IF NOT EXISTS sms_messages_profile_idx ON sms.sms_messages (profile_id, sent_at DESC);
CREATE INDEX IF NOT EXISTS sms_messages_emergency_idx ON sms.sms_messages (profile_id) WHERE kind = 'emergency' AND resolved_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_message_recipients (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    message_id     text NOT NULL REFERENCES sms.sms_messages(id) ON DELETE CASCADE,
    kind           text NOT NULL,
    ref_id         text NOT NULL,
    family_id      text,
    student_id     text,
    user_id        text,
    name           text,
    phone          text,
    email          text,
    language       text,
    sms_ref        text,
    sms_status     text,
    email_status   text,
    in_app         boolean NOT NULL DEFAULT false,
    read_at        timestamptz,
    error          text,
    UNIQUE (message_id, kind, ref_id)
);
SELECT sms.widen_check('sms.sms_message_recipients', 'sms_message_recipients_check', $q$'guardian'$q$, $q$CHECK (kind IN ('guardian', 'student', 'staff'))$q$);
CREATE INDEX IF NOT EXISTS sms_message_recipients_family_idx ON sms.sms_message_recipients (family_id) WHERE family_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS sms_message_recipients_user_idx ON sms.sms_message_recipients (user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS sms_message_recipients_sms_idx ON sms.sms_message_recipients (sms_ref) WHERE sms_ref IS NOT NULL;

-- =================================================================== the notice board
CREATE TABLE IF NOT EXISTS sms.sms_announcements (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    profile_id       text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    profile_ids      text[] NOT NULL DEFAULT '{}',
    title            text NOT NULL,
    body             text NOT NULL,
    translations     jsonb NOT NULL DEFAULT '{}'::jsonb,
    for_parents      boolean NOT NULL DEFAULT true,
    for_students     boolean NOT NULL DEFAULT false,
    for_staff        boolean NOT NULL DEFAULT false,
    class_ids        text[] NOT NULL DEFAULT '{}',
    year_group_ids   text[] NOT NULL DEFAULT '{}',
    role_ids         text[] NOT NULL DEFAULT '{}',
    pinned           boolean NOT NULL DEFAULT false,
    publish_at       timestamptz NOT NULL DEFAULT now(),
    expires_on       date,
    created_by       text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_announcements', 'sms_announcements_check', $q$for_parents$q$, $q$CHECK (for_parents OR for_students OR for_staff)$q$);
CREATE INDEX IF NOT EXISTS sms_announcements_bus_idx ON sms.sms_announcements (bus_id, publish_at DESC);

CREATE TABLE IF NOT EXISTS sms.sms_announcement_reads (
    announcement_id  text NOT NULL REFERENCES sms.sms_announcements(id) ON DELETE CASCADE,
    reader           text NOT NULL,
    read_at          timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (announcement_id, reader)
);

-- =================================================================== two-way messages
CREATE TABLE IF NOT EXISTS sms.sms_conversations (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    family_id     text NOT NULL REFERENCES sms.sms_families(id) ON DELETE CASCADE,
    student_id    text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    staff_id      text NOT NULL REFERENCES sms.sms_staff(id) ON DELETE CASCADE,
    subject       text NOT NULL,
    started_by    text NOT NULL,
    last_at       timestamptz NOT NULL DEFAULT now(),
    closed_at     timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_conversations', 'sms_conversations_check', $q$'family'$q$, $q$CHECK (started_by IN ('family', 'staff'))$q$);
CREATE INDEX IF NOT EXISTS sms_conversations_family_idx ON sms.sms_conversations (family_id, last_at DESC);
CREATE INDEX IF NOT EXISTS sms_conversations_staff_idx ON sms.sms_conversations (staff_id, last_at DESC);

CREATE TABLE IF NOT EXISTS sms.sms_conversation_messages (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    conversation_id  text NOT NULL REFERENCES sms.sms_conversations(id) ON DELETE CASCADE,
    from_family      boolean NOT NULL,
    author_user      text,
    author_name      text NOT NULL,
    body             text NOT NULL,
    read_at          timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sms_conversation_messages_idx ON sms.sms_conversation_messages (conversation_id, cdatetime);

-- =================================================================== parent-teacher meetings
CREATE TABLE IF NOT EXISTS sms.sms_ptm_events (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    profile_id       text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    title            text NOT NULL,
    held_on          date NOT NULL,
    starts_at        time NOT NULL,
    ends_at          time NOT NULL,
    slot_minutes     integer NOT NULL DEFAULT 10,
    gap_minutes      integer NOT NULL DEFAULT 0,
    location         text,
    notes            text,
    class_ids        text[] NOT NULL DEFAULT '{}',
    year_group_ids   text[] NOT NULL DEFAULT '{}',
    status           text NOT NULL DEFAULT 'draft',
    closes_at        timestamptz,
    created_by       text,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_ptm_events', 'sms_ptm_events_check', $q$'draft'$q$, $q$CHECK (
    status IN ('draft', 'open', 'closed', 'cancelled') AND ends_at > starts_at AND slot_minutes BETWEEN 3 AND 60 AND gap_minutes BETWEEN 0 AND 30)$q$);

CREATE TABLE IF NOT EXISTS sms.sms_ptm_teachers (
    event_id     text NOT NULL REFERENCES sms.sms_ptm_events(id) ON DELETE CASCADE,
    staff_id     text NOT NULL REFERENCES sms.sms_staff(id) ON DELETE CASCADE,
    room         text,
    starts_at    time,
    ends_at      time,
    PRIMARY KEY (event_id, staff_id)
);

CREATE TABLE IF NOT EXISTS sms.sms_ptm_bookings (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    event_id        text NOT NULL REFERENCES sms.sms_ptm_events(id) ON DELETE CASCADE,
    staff_id        text NOT NULL REFERENCES sms.sms_staff(id) ON DELETE CASCADE,
    slot_at         time NOT NULL,
    student_id      text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    family_id       text,
    booked_by_name  text,
    by_user         text,
    note            text,
    attended        boolean,
    cancelled_at    timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS sms_ptm_bookings_slot_uq ON sms.sms_ptm_bookings (event_id, staff_id, slot_at) WHERE cancelled_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS sms_ptm_bookings_once_uq ON sms.sms_ptm_bookings (event_id, staff_id, student_id) WHERE cancelled_at IS NULL;

-- =================================================================== consent forms
CREATE TABLE IF NOT EXISTS sms.sms_consent_forms (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    profile_id       text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    kind             text NOT NULL,
    title            text NOT NULL,
    body             text NOT NULL,
    due_on           date,
    class_ids        text[] NOT NULL DEFAULT '{}',
    year_group_ids   text[] NOT NULL DEFAULT '{}',
    student_ids      text[] NOT NULL DEFAULT '{}',
    status           text NOT NULL DEFAULT 'open',
    created_by       text,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_consent_forms', 'sms_consent_forms_check', $q$'media'$q$, $q$CHECK (
    kind IN ('trip', 'media', 'medical', 'activity', 'data', 'other') AND status IN ('open', 'closed'))$q$);

CREATE TABLE IF NOT EXISTS sms.sms_consent_responses (
    form_id        text NOT NULL REFERENCES sms.sms_consent_forms(id) ON DELETE CASCADE,
    student_id     text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    answer         text NOT NULL,
    signed_name    text NOT NULL,
    relationship   text,
    note           text,
    via            text NOT NULL DEFAULT 'family',
    by_user        text,
    signed_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (form_id, student_id)
);
SELECT sms.widen_check('sms.sms_consent_responses', 'sms_consent_responses_check', $q$'given'$q$, $q$CHECK (answer IN ('given', 'declined') AND via IN ('family', 'office'))$q$);

-- =================================================================== surveys
CREATE TABLE IF NOT EXISTS sms.sms_surveys (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    profile_id       text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    title            text NOT NULL,
    intro            text,
    audience         text NOT NULL,
    class_ids        text[] NOT NULL DEFAULT '{}',
    year_group_ids   text[] NOT NULL DEFAULT '{}',
    anonymous        boolean NOT NULL DEFAULT false,
    closes_on        date,
    status           text NOT NULL DEFAULT 'draft',
    created_by       text,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_surveys', 'sms_surveys_check', $q$'parents'$q$, $q$CHECK (
    audience IN ('parents', 'students', 'staff') AND status IN ('draft', 'open', 'closed'))$q$);

CREATE TABLE IF NOT EXISTS sms.sms_survey_questions (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    survey_id   text NOT NULL REFERENCES sms.sms_surveys(id) ON DELETE CASCADE,
    position    integer NOT NULL,
    kind        text NOT NULL,
    text        text NOT NULL,
    options     text[] NOT NULL DEFAULT '{}',
    required    boolean NOT NULL DEFAULT true
);
SELECT sms.widen_check('sms.sms_survey_questions', 'sms_survey_questions_check', $q$'rating'$q$, $q$CHECK (kind IN ('rating', 'choice', 'multi', 'yes_no', 'text'))$q$);

CREATE TABLE IF NOT EXISTS sms.sms_survey_responses (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    survey_id        text NOT NULL REFERENCES sms.sms_surveys(id) ON DELETE CASCADE,
    respondent       text NOT NULL,
    respondent_name  text,
    answers          jsonb NOT NULL,
    submitted_at     timestamptz NOT NULL DEFAULT now(),
    UNIQUE (survey_id, respondent)
);

-- =================================================================== newsletters
CREATE TABLE IF NOT EXISTS sms.sms_newsletters (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    profile_id     text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    title          text NOT NULL,
    intro          text,
    blocks         jsonb NOT NULL DEFAULT '[]'::jsonb,
    accent         text,
    status         text NOT NULL DEFAULT 'draft',
    public_token   text NOT NULL DEFAULT replace(gen_random_uuid()::text, '-', ''),
    sent_at        timestamptz,
    message_id     text,
    created_by     text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_newsletters', 'sms_newsletters_check', $q$'draft'$q$, $q$CHECK (status IN ('draft', 'sent'))$q$);
CREATE UNIQUE INDEX IF NOT EXISTS sms_newsletters_token_uq ON sms.sms_newsletters (public_token);

-- =================================================================== paying online
CREATE TABLE IF NOT EXISTS sms.sms_online_payments (
    reference      text PRIMARY KEY,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    profile_id     text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    subject        text NOT NULL,
    subject_id     text,
    student_id     text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    family_id      text,
    amount_minor   bigint NOT NULL,
    currency       text NOT NULL,
    status         text NOT NULL DEFAULT 'pending',
    checkout_url   text,
    payer          text,
    method         text,
    recorded_id    text,
    checked_at     timestamptz,
    cdatetime      timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_online_payments', 'sms_online_payments_check', $q$'wallet'$q$, $q$CHECK (
    subject IN ('fees', 'trip', 'wallet') AND status IN ('pending', 'paid', 'failed') AND amount_minor > 0)$q$);
CREATE INDEX IF NOT EXISTS sms_online_payments_pending_idx ON sms.sms_online_payments (cdatetime) WHERE status = 'pending';

-- Pictures in a newsletter; papers with an announcement.
SELECT sms.widen_check('sms.sms_files', 'sms_files_entity_check', $q$'newsletter'$q$, $q$CHECK (entity_type IS NULL OR entity_type IN
    ('profile', 'application', 'enquiry', 'family', 'student', 'leave_request', 'assignment', 'submission', 'class_resource', 'pickup_person', 'incident',
     'safeguarding', 'achievement', 'service_hours', 'trip', 'staff', 'staff_document', 'staff_check', 'job_application', 'staff_leave', 'payslip',
     'staff_cpd', 'gl_expense', 'gl_asset', 'maintenance', 'hs_record', 'newsletter', 'announcement'))$q$);

-- Communication is a module a school can turn off (Settings, Modules).
SELECT sms.widen_check('sms.sms_profiles', 'sms_profiles_modules_check', $q$'communication'$q$, $q$CHECK (modules IS NULL OR (cardinality(modules) > 0 AND modules <@ ARRAY[
    'admissions', 'teaching', 'scheduling', 'attendance', 'grading', 'learning', 'welfare', 'inclusion', 'boarding', 'library', 'activities', 'transport',
    'catering', 'hr', 'fees', 'finance', 'procurement', 'campus', 'communication']::text[]))$q$);

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-communication', 'MyEduGuard Communication', 'Messages, announcements, parent conversations, meetings, consent forms, surveys, newsletters and emergency alerts', 'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, action, label) AS (VALUES
    ('communication', 'get',      'See the messages sent, the notice board, consent forms, surveys and their results, and newsletters'),
    ('communication', 'transact', 'Send messages, post announcements, and run consent forms, surveys, newsletters and parents'' evenings'),
    ('communication', 'manage',   'Send emergency alerts, read every parent conversation, and set up communication')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-sms-' || spec.resource_key || '-' || spec.action,
       'MyEduGuard ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       'rt-sms-communication', spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'sms',
       resource_key = substring(p.id FROM '^permission-sms-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-sms-%'
   AND (p.app_prefix IS DISTINCT FROM 'sms' OR p.action IS NULL);

INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-sms-comms', 'system-tenant-id', 'MyEduGuard Communications Officer', 'Sends messages and newsletters, keeps the notice board, and runs consent forms, surveys and parents'' evenings', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name        = EXCLUDED.role_name,
                               description      = EXCLUDED.description,
                               resource_type_id = EXCLUDED.resource_type_id,
                               is_system        = EXCLUDED.is_system,
                               is_active        = EXCLUDED.is_active;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-sms-head' AS role_id, p2.resource_key, p2.action
      FROM core_platform.cp_permissions p2 WHERE p2.app_prefix = 'sms'
    UNION ALL
    SELECT 'role-sms-comms', k, a FROM (VALUES ('communication', 'get'), ('communication', 'transact'), ('students', 'get'), ('structure', 'get'),
        ('profiles', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-reception', 'communication', 'get'
    UNION ALL
    SELECT 'role-sms-viewer', 'communication', 'get'
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'sms' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', 'role-sms-comms', p.id
  FROM core_platform.cp_permissions p
 WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.messaging',        'app-sms', 'Bulk & Individual Messaging',  1, 'SMS, email and in-app messages to parents, students and staff'),
('sms.announcements',    'app-sms', 'Announcements & Notice Board', 1, 'Targeted announcements by class, campus or role'),
('sms.conversations',    'app-sms', 'Two-Way Messaging',            1, 'Secure parent and teacher conversations'),
('sms.ptm-booking',      'app-sms', 'Parent-Teacher Meeting Booking', 2, 'Parents book conference slots online'),
('sms.consent-forms',    'app-sms', 'Digital Consent Forms',        1, 'Trip, media and medical consents signed in the app'),
('sms.surveys',          'app-sms', 'Surveys & Feedback',           2, 'Parent, student and staff surveys with results'),
('sms.newsletters',      'app-sms', 'Newsletters',                  2, 'Designed newsletters sent by email and in the app'),
('sms.emergency-alerts', 'app-sms', 'Emergency Alerts',             1, 'Instant broadcasts for closures and emergencies'),
('sms.multilingual',     'app-sms', 'Multilingual Messaging',       3, 'Messages delivered in each family''s preferred language')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id = EXCLUDED.app_id, title = EXCLUDED.title, min_tier_rank = EXCLUDED.min_tier_rank,
    description = EXCLUDED.description, is_active = true;

-- =================================================================== invariants
DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions p
     WHERE p.app_prefix = 'sms' AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                        WHERE rp.role_id = 'role-sms-head' AND rp.permission_id = p.id);
    IF n > 0 THEN
        RAISE EXCEPTION 'role-sms-head lacks % SMS permission(s)', n;
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-sms-comms' AND p.app_prefix = 'sms'
                  AND p.resource_key IN ('counselling', 'safeguarding', 'hr', 'finance', 'fees')) THEN
        RAISE EXCEPTION 'counselling, safeguarding, staff records and money are not the communications officer''s';
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-sms-viewer' AND p.app_prefix = 'sms' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-sms-viewer holds % SMS permission(s) that change data', n;
    END IF;
END $$;

COMMIT;
