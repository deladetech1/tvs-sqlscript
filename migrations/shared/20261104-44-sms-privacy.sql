-- MyEduGuard: privacy and data protection, under whichever law the school answers to (Ghana's
-- Act 843, NDPA, Kenya's DPA, POPIA, GDPR, FERPA...).
--
--   sms_privacy_settings   the law, the data protection officer, the privacy notice families and
--                          staff see, and what the school's records are kept for
--   sms_privacy_consents   consents given and withdrawn: photos, marketing, biometrics, sharing,
--                          medical treatment... for a student, a guardian or a member of staff
--   sms_data_requests      requests to see, correct, export or erase someone's data, each with
--                          the day the law says it must be answered by
--   sms_retention_rules    how long each kind of record is kept, and what happens after: made
--                          anonymous or deleted, by the daily round
--
-- A student whose record is erased keeps a row (the books need it) with nothing that names them:
-- sms_students.erased_at says so. Idempotent; safe to re-run.

BEGIN;

ALTER TABLE sms.sms_students ADD COLUMN IF NOT EXISTS erased_at timestamptz;
ALTER TABLE sms.sms_families ADD COLUMN IF NOT EXISTS erased_at timestamptz;

CREATE TABLE IF NOT EXISTS sms.sms_privacy_settings (
    profile_id      text PRIMARY KEY REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    law             text,
    authority       text,
    answer_days     integer NOT NULL DEFAULT 30,
    child_age       integer NOT NULL DEFAULT 18,
    dpo_name        text,
    dpo_email       text,
    dpo_phone       text,
    notice          text,
    purposes        jsonb NOT NULL DEFAULT '[]',
    registration_no text,
    updated_at      timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_privacy_settings', 'sms_privacy_settings_check', $q$child_age$q$, $q$CHECK (answer_days BETWEEN 1 AND 90 AND child_age BETWEEN 10 AND 21)$q$);

CREATE TABLE IF NOT EXISTS sms.sms_privacy_consents (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    subject_kind  text NOT NULL,
    subject_id    text NOT NULL,
    purpose       text NOT NULL,
    granted       boolean NOT NULL,
    given_by      text,
    relationship  text,
    method        text NOT NULL DEFAULT 'online',
    expires_on    date,
    notes         text,
    recorded_by   text,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_privacy_consents', 'sms_privacy_consents_check', $q$'verbal'$q$, $q$CHECK (
    subject_kind IN ('student', 'guardian', 'staff') AND method IN ('online', 'paper', 'email', 'verbal'))$q$);
CREATE INDEX IF NOT EXISTS sms_privacy_consents_subject_idx ON sms.sms_privacy_consents (subject_kind, subject_id, purpose, cdatetime DESC);

CREATE TABLE IF NOT EXISTS sms.sms_data_requests (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    number          text NOT NULL,
    kind            text NOT NULL,
    subject_kind    text NOT NULL,
    subject_id      text,
    subject_name    text NOT NULL,
    requester_name  text NOT NULL,
    requester_email text,
    requester_phone text,
    relationship    text,
    details         text,
    received_on     date NOT NULL DEFAULT CURRENT_DATE,
    due_on          date NOT NULL,
    status          text NOT NULL DEFAULT 'open',
    identity_checked boolean NOT NULL DEFAULT false,
    outcome         text,
    completed_on    date,
    handled_by      text,
    from_family     boolean NOT NULL DEFAULT false,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_data_requests', 'sms_data_requests_check', $q$'refused'$q$, $q$CHECK (
    kind IN ('access', 'export', 'rectify', 'erase', 'restrict', 'object') AND subject_kind IN ('student', 'guardian', 'staff', 'applicant', 'alumnus', 'other')
    AND status IN ('open', 'in_progress', 'completed', 'refused') AND due_on >= received_on)$q$);
CREATE UNIQUE INDEX IF NOT EXISTS sms_data_requests_number_uq ON sms.sms_data_requests (profile_id, number);

CREATE TABLE IF NOT EXISTS sms.sms_retention_rules (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    record        text NOT NULL,
    keep_months   integer NOT NULL,
    action        text NOT NULL DEFAULT 'anonymise',
    enabled       boolean NOT NULL DEFAULT false,
    last_run_at   timestamptz,
    last_count    integer,
    UNIQUE (profile_id, record)
);
SELECT sms.widen_check('sms.sms_retention_rules', 'sms_retention_rules_check', $q$'enquiries'$q$, $q$CHECK (
    keep_months BETWEEN 1 AND 1200 AND action IN ('anonymise', 'delete')
    AND record IN ('left_students', 'unsuccessful_applications', 'enquiries', 'visitors', 'gate_passes', 'messages', 'online_tests', 'audit_logs'))$q$);

-- Data requests carry the files sent in answer.
SELECT sms.widen_check('sms.sms_files', 'sms_files_entity_check', $q$'data_request'$q$, $q$CHECK (entity_type IS NULL OR entity_type IN
    ('profile', 'application', 'enquiry', 'family', 'guardian', 'student', 'leave_request', 'assignment', 'submission', 'class_resource', 'pickup_person', 'incident',
     'safeguarding', 'achievement', 'service_hours', 'trip', 'staff', 'staff_document', 'staff_check', 'job_application', 'staff_leave', 'payslip',
     'staff_cpd', 'gl_expense', 'gl_asset', 'maintenance', 'hs_record', 'newsletter', 'announcement', 'data_request'))$q$);

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-privacy', 'MyEduGuard Privacy & Data Protection', 'Consents, requests to see, correct or erase personal data, retention and the privacy notice', 'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, action, label) AS (VALUES
    ('privacy', 'get',    'See consents, data requests and the retention rules'),
    ('privacy', 'manage', 'Record consents, answer data requests (export and erase personal data), and set the privacy notice and retention rules')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-sms-' || spec.resource_key || '-' || spec.action,
       'MyEduGuard ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       'rt-sms-privacy', spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
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
('role-sms-dpo', 'system-tenant-id', 'MyEduGuard Data Protection Officer', 'Keeps the record of consents, answers requests to see, correct, export or erase personal data, and sets how long records are kept', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
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
    SELECT 'role-sms-dpo', k, a FROM (VALUES ('privacy', 'get'), ('privacy', 'manage'), ('students', 'get'), ('profiles', 'get'), ('structure', 'get'),
        ('admissions', 'get')) AS g(k, a)
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'sms' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', 'role-sms-dpo', p.id
  FROM core_platform.cp_permissions p
 WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.data-protection', 'app-sms', 'Data Protection Compliance', 1, 'The privacy notice, consents and the data protection officer, under the school''s own law'),
('sms.data-requests',   'app-sms', 'Consent & Data Subject Requests', 2, 'Requests to see, export, correct or erase personal data, answered on time'),
('sms.retention',       'app-sms', 'Data Retention Policies',   2, 'Old records made anonymous or deleted on schedule')
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
END $$;

COMMIT;
