-- MyEduGuard: alumni and advancement -- lifelong relationships with the school community.
--
--   sms_alumni_settings          numbering (donation receipts, event tickets) and the alumni page
--   sms_alumni                   the alumni directory: graduates (from the school's records, or who
--                                joined themselves), their contact details, careers and engagement
--   sms_alumni_events            events and reunions, their ticket types, and registrations with
--   sms_alumni_ticket_types      ticket codes (paid online, or at the door) and check-in
--   sms_alumni_registrations
--   sms_campaigns                fundraising campaigns (a goal, dates, a public page) and donations,
--   sms_donations                online or recorded, each with its receipt (and in the books)
--   sms_destinations             university and career counselling: each student's applications,
--   sms_career_notes             offers and where they went, and the counsellor's notes
--
-- Online payments (tickets and donations) go through the organisation's gateway in Core Platform,
-- as fees do. Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS sms.sms_alumni_settings (
    profile_id        text PRIMARY KEY REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    receipt_prefix    text NOT NULL DEFAULT 'DON',
    next_receipt      integer NOT NULL DEFAULT 1,
    ticket_prefix     text NOT NULL DEFAULT 'TKT',
    next_ticket       integer NOT NULL DEFAULT 1,
    welcome           text,
    receipt_note      text,
    updated_at        timestamptz NOT NULL DEFAULT now()
);

-- =================================================================== the directory
CREATE TABLE IF NOT EXISTS sms.sms_alumni (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    bus_id             text NOT NULL,
    profile_id         text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id         text REFERENCES sms.sms_students(id) ON DELETE SET NULL,
    first_name         text NOT NULL,
    last_name          text NOT NULL,
    graduated_year     integer,
    last_class         text,
    email              text,
    phone              text,
    city               text,
    country            text,
    occupation         text,
    employer           text,
    industry           text,
    university         text,
    degree             text,
    linkedin           text,
    tags               text[] NOT NULL DEFAULT '{}',
    notes              text,
    consent_contact    boolean NOT NULL DEFAULT true,
    source             text NOT NULL DEFAULT 'school',
    verified           boolean NOT NULL DEFAULT true,
    self_token         text NOT NULL DEFAULT replace(gen_random_uuid()::text, '-', ''),
    last_contacted_at  timestamptz,
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_alumni', 'sms_alumni_check', $q$'self'$q$, $q$CHECK (source IN ('school', 'self'))$q$);
CREATE UNIQUE INDEX IF NOT EXISTS sms_alumni_student_uq ON sms.sms_alumni (student_id) WHERE student_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS sms_alumni_token_uq ON sms.sms_alumni (self_token);
CREATE INDEX IF NOT EXISTS sms_alumni_profile_idx ON sms.sms_alumni (profile_id, graduated_year);
CREATE INDEX IF NOT EXISTS sms_alumni_email_idx ON sms.sms_alumni (profile_id, lower(email));

-- =================================================================== events and reunions
CREATE TABLE IF NOT EXISTS sms.sms_alumni_events (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    title         text NOT NULL,
    kind          text NOT NULL DEFAULT 'reunion',
    starts_at     timestamptz NOT NULL,
    ends_at       timestamptz,
    venue         text,
    description   text,
    class_years   integer[] NOT NULL DEFAULT '{}',
    capacity      integer,
    status        text NOT NULL DEFAULT 'draft',
    closes_at     timestamptz,
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_alumni_events', 'sms_alumni_events_check', $q$'reunion'$q$, $q$CHECK (
    kind IN ('reunion', 'networking', 'sports', 'fundraiser', 'talk', 'other') AND status IN ('draft', 'open', 'closed', 'cancelled'))$q$);

CREATE TABLE IF NOT EXISTS sms.sms_alumni_ticket_types (
    id         text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    event_id   text NOT NULL REFERENCES sms.sms_alumni_events(id) ON DELETE CASCADE,
    name       text NOT NULL,
    price      numeric(12,2) NOT NULL DEFAULT 0,
    capacity   integer,
    position   integer NOT NULL DEFAULT 0
);
SELECT sms.widen_check('sms.sms_alumni_ticket_types', 'sms_alumni_ticket_types_check', $q$price >= 0$q$, $q$CHECK (price >= 0)$q$);

CREATE TABLE IF NOT EXISTS sms.sms_alumni_registrations (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    event_id        text NOT NULL REFERENCES sms.sms_alumni_events(id) ON DELETE CASCADE,
    ticket_type_id  text NOT NULL REFERENCES sms.sms_alumni_ticket_types(id) ON DELETE CASCADE,
    alumni_id       text REFERENCES sms.sms_alumni(id) ON DELETE SET NULL,
    code            text NOT NULL,
    name            text NOT NULL,
    email           text,
    phone           text,
    quantity        integer NOT NULL DEFAULT 1,
    amount          numeric(12,2) NOT NULL DEFAULT 0,
    currency        text NOT NULL,
    status          text NOT NULL,
    paid_via        text,
    payment_ref     text,
    checked_in_at   timestamptz,
    checked_in      integer NOT NULL DEFAULT 0,
    by_user         text,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_alumni_registrations', 'sms_alumni_registrations_check', $q$'awaiting_payment'$q$, $q$CHECK (
    status IN ('awaiting_payment', 'confirmed', 'cancelled') AND quantity BETWEEN 1 AND 20 AND amount >= 0)$q$);
CREATE UNIQUE INDEX IF NOT EXISTS sms_alumni_registrations_code_uq ON sms.sms_alumni_registrations (event_id, upper(code));

-- =================================================================== fundraising
CREATE TABLE IF NOT EXISTS sms.sms_campaigns (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    title         text NOT NULL,
    description   text,
    goal          numeric(14,2),
    currency      text NOT NULL,
    starts_on     date,
    ends_on       date,
    status        text NOT NULL DEFAULT 'draft',
    suggested     numeric(12,2)[] NOT NULL DEFAULT '{}',
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_campaigns', 'sms_campaigns_check', $q$'draft'$q$, $q$CHECK (status IN ('draft', 'open', 'closed') AND (goal IS NULL OR goal > 0))$q$);

CREATE TABLE IF NOT EXISTS sms.sms_donations (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    campaign_id     text REFERENCES sms.sms_campaigns(id) ON DELETE SET NULL,
    alumni_id       text REFERENCES sms.sms_alumni(id) ON DELETE SET NULL,
    donor_name      text NOT NULL,
    donor_email     text,
    donor_phone     text,
    anonymous       boolean NOT NULL DEFAULT false,
    amount          numeric(14,2) NOT NULL,
    currency        text NOT NULL,
    method          text NOT NULL,
    reference       text,
    received_on     date NOT NULL,
    receipt_number  text NOT NULL,
    message         text,
    note            text,
    journal_id      text,
    voided_at       timestamptz,
    void_reason     text,
    recorded_by     text,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_donations', 'sms_donations_check', $q$'online'$q$, $q$CHECK (
    amount > 0 AND method IN ('cash', 'mobile_money', 'bank', 'card', 'cheque', 'online'))$q$);
CREATE UNIQUE INDEX IF NOT EXISTS sms_donations_receipt_uq ON sms.sms_donations (profile_id, receipt_number);
CREATE INDEX IF NOT EXISTS sms_donations_campaign_idx ON sms.sms_donations (campaign_id);

-- =================================================================== university and career counselling
CREATE TABLE IF NOT EXISTS sms.sms_destinations (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    profile_id        text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id        text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    kind              text NOT NULL DEFAULT 'university',
    institution       text NOT NULL,
    country           text,
    course            text,
    deadline          date,
    submitted_on      date,
    status            text NOT NULL DEFAULT 'planning',
    offer_conditions  text,
    scholarship       text,
    decision_on       date,
    chosen            boolean NOT NULL DEFAULT false,
    notes             text,
    created_by        text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_destinations', 'sms_destinations_check', $q$'apprenticeship'$q$, $q$CHECK (
    kind IN ('university', 'college', 'apprenticeship', 'employment', 'gap_year', 'military', 'other')
    AND status IN ('planning', 'submitted', 'interview', 'conditional_offer', 'offer', 'rejected', 'waitlisted', 'accepted', 'declined', 'withdrawn', 'enrolled'))$q$);
CREATE INDEX IF NOT EXISTS sms_destinations_student_idx ON sms.sms_destinations (student_id);
CREATE INDEX IF NOT EXISTS sms_destinations_profile_idx ON sms.sms_destinations (profile_id, status);

CREATE TABLE IF NOT EXISTS sms.sms_career_notes (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id  text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    met_on      date NOT NULL,
    notes       text NOT NULL,
    next_steps  text,
    by_user     text,
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sms_career_notes_student_idx ON sms.sms_career_notes (student_id, met_on DESC);

-- =================================================================== paying online
-- Tickets and donations are paid online too, and are not a student's.
ALTER TABLE sms.sms_online_payments ALTER COLUMN student_id DROP NOT NULL;
-- Who is giving, and what for, until the payment is in.
ALTER TABLE sms.sms_online_payments ADD COLUMN IF NOT EXISTS details jsonb;
SELECT sms.widen_check('sms.sms_online_payments', 'sms_online_payments_check', $q$'donation'$q$, $q$CHECK (
    subject IN ('fees', 'trip', 'wallet', 'ticket', 'donation') AND status IN ('pending', 'paid', 'failed') AND amount_minor > 0)$q$);

-- Alumni and advancement is a module a school can turn off (Settings, Modules).
SELECT sms.widen_check('sms.sms_profiles', 'sms_profiles_modules_check', $q$'alumni'$q$, $q$CHECK (modules IS NULL OR (cardinality(modules) > 0 AND modules <@ ARRAY[
    'admissions', 'teaching', 'scheduling', 'attendance', 'grading', 'learning', 'welfare', 'inclusion', 'boarding', 'library', 'activities', 'transport',
    'catering', 'hr', 'fees', 'finance', 'procurement', 'campus', 'communication', 'alumni']::text[]))$q$);

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-advancement', 'MyEduGuard Alumni & Advancement', 'The alumni directory, events and reunions, fundraising and donations, and university and career counselling', 'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, action, label) AS (VALUES
    ('advancement',  'get',      'See the alumni directory, alumni events and their registrations, and campaigns and donations'),
    ('advancement',  'transact', 'Keep the alumni directory, run events and check people in, and record donations'),
    ('advancement',  'manage',   'Set up campaigns and events, void donations, and set up alumni and advancement'),
    ('destinations', 'get',      'See students'' university and career applications, offers and destinations'),
    ('destinations', 'manage',   'Keep students'' university and career applications, offers, destinations and counselling notes')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-sms-' || spec.resource_key || '-' || spec.action,
       'MyEduGuard ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       'rt-sms-advancement', spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
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
('role-sms-advancement', 'system-tenant-id', 'MyEduGuard Alumni & Advancement Officer', 'Keeps the alumni directory, runs alumni events and reunions, and runs fundraising campaigns and donations', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-sms-careers', 'system-tenant-id', 'MyEduGuard Careers Counsellor', 'Guides students on university and careers: their applications, offers and destinations', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
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
    SELECT 'role-sms-advancement', k, a FROM (VALUES ('advancement', 'get'), ('advancement', 'transact'), ('advancement', 'manage'), ('students', 'get'),
        ('structure', 'get'), ('profiles', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-careers', k, a FROM (VALUES ('destinations', 'get'), ('destinations', 'manage'), ('advancement', 'get'), ('students', 'get'),
        ('structure', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-viewer', k, a FROM (VALUES ('advancement', 'get'), ('destinations', 'get')) AS g(k, a)
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'sms' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', r.id, p.id
  FROM core_platform.cp_permissions p CROSS JOIN (VALUES ('role-sms-advancement'), ('role-sms-careers')) AS r(id)
 WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.alumni-directory',        'app-sms', 'Alumni Directory',                   2, 'Graduates'' contact details, careers and engagement'),
('sms.alumni-events',           'app-sms', 'Alumni Events & Reunions',           2, 'Event registration and ticketing'),
('sms.fundraising',             'app-sms', 'Fundraising & Donations',            2, 'Campaigns, online donations and receipts'),
('sms.university-counselling',  'app-sms', 'University & Career Counselling',    2, 'Track applications, offers and destinations')
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
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-sms-viewer' AND p.app_prefix = 'sms' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-sms-viewer holds % SMS permission(s) that change data', n;
    END IF;
END $$;

COMMIT;
