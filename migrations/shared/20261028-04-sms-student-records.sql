-- SMS: student information and records -- the single source of truth for every learner.
--
--   sms_divisions, sms_year_groups,
--   sms_classes, sms_subjects        the school's structure, without limits: divisions (Lower
--                                    Primary, JHS), year groups in order (each knows the next,
--                                    the last graduates), the classes of a year (Primary 1A,
--                                    1B) with a class teacher and room, and the subjects taught
--   sms_students (more columns)      bio data, medical notes, the year group and class, custom
--                                    fields, and how and when a student left; alumni,
--                                    transferred and withdrawn students keep their full record
--   sms_emergency_contacts           who to call, in order, and who may collect the child
--   sms_student_documents            the documents vault: birth certificates, passports, visas,
--                                    residence permits, reports, medical forms, with numbers and
--                                    expiry dates (the renewal reminders)
--   sms_student_history              every year of a student: the class, and enrolled, promoted,
--                                    repeated, graduated, transferred or withdrawn
--   sms_promotion_batches, _items    the year-end promotion: proposed, approved, applied
--   sms_student_movements            inter-campus transfers and withdrawals, with the reason,
--                                    a clearance checklist and the transfer certificate
--   sms_custom_fields                fields a school adds to its student record itself
--
-- Permissions sms|structure|get/manage and sms|students|approve; plan features. Idempotent.

BEGIN;

ALTER TABLE sms.sms_profiles ADD COLUMN IF NOT EXISTS current_year text;

-- =================================================================== structure
CREATE TABLE IF NOT EXISTS sms.sms_divisions (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles (id),
    name         text NOT NULL,
    head_id      text,
    sort_order   int NOT NULL DEFAULT 0,
    archived_at  timestamptz,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS sms_divisions_name_uq ON sms.sms_divisions (profile_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_year_groups (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    bus_id              text NOT NULL,
    profile_id          text NOT NULL REFERENCES sms.sms_profiles (id),
    division_id         text REFERENCES sms.sms_divisions (id),
    name                text NOT NULL,
    level               text,
    sort_order          int NOT NULL DEFAULT 0,
    next_year_group_id  text REFERENCES sms.sms_year_groups (id),
    archived_at         timestamptz,
    cdatetime           timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS sms_year_groups_name_uq ON sms.sms_year_groups (profile_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_classes (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    profile_id        text NOT NULL REFERENCES sms.sms_profiles (id),
    year_group_id     text NOT NULL REFERENCES sms.sms_year_groups (id),
    academic_year     text NOT NULL,
    name              text NOT NULL,
    class_teacher_id  text,
    room              text,
    capacity          int CHECK (capacity IS NULL OR capacity >= 0),
    archived_at       timestamptz,
    cdatetime         timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS sms_classes_name_uq ON sms.sms_classes (profile_id, academic_year, lower(name)) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS sms_classes_year_idx ON sms.sms_classes (profile_id, academic_year, year_group_id);

CREATE TABLE IF NOT EXISTS sms.sms_subjects (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles (id),
    name            text NOT NULL,
    code            text,
    is_core         boolean NOT NULL DEFAULT true,
    year_group_ids  text[] NOT NULL DEFAULT '{}',
    sort_order      int NOT NULL DEFAULT 0,
    archived_at     timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS sms_subjects_name_uq ON sms.sms_subjects (profile_id, lower(name)) WHERE archived_at IS NULL;

ALTER TABLE sms.sms_admission_classes ADD COLUMN IF NOT EXISTS year_group_id text REFERENCES sms.sms_year_groups (id);

-- =================================================================== students
ALTER TABLE sms.sms_students ADD COLUMN IF NOT EXISTS year_group_id text REFERENCES sms.sms_year_groups (id);
ALTER TABLE sms.sms_students ADD COLUMN IF NOT EXISTS class_group_id text REFERENCES sms.sms_classes (id);
ALTER TABLE sms.sms_students ADD COLUMN IF NOT EXISTS place_of_birth text;
ALTER TABLE sms.sms_students ADD COLUMN IF NOT EXISTS religion text;
ALTER TABLE sms.sms_students ADD COLUMN IF NOT EXISTS blood_group text;
ALTER TABLE sms.sms_students ADD COLUMN IF NOT EXISTS medical_notes text;
ALTER TABLE sms.sms_students ADD COLUMN IF NOT EXISTS allergies text;
ALTER TABLE sms.sms_students ADD COLUMN IF NOT EXISTS home_address text;
ALTER TABLE sms.sms_students ADD COLUMN IF NOT EXISTS home_language text;
ALTER TABLE sms.sms_students ADD COLUMN IF NOT EXISTS previous_school text;
ALTER TABLE sms.sms_students ADD COLUMN IF NOT EXISTS custom jsonb NOT NULL DEFAULT '{}';
ALTER TABLE sms.sms_students ADD COLUMN IF NOT EXISTS left_on date;
ALTER TABLE sms.sms_students ADD COLUMN IF NOT EXISTS leaving_reason text;
ALTER TABLE sms.sms_students ADD COLUMN IF NOT EXISTS leaving_destination text;
ALTER TABLE sms.sms_students ADD COLUMN IF NOT EXISTS graduated_year text;

SELECT sms.widen_check('sms.sms_students', 'sms_students_status_check', $q$'transferred'$q$, $q$CHECK (status IN ('active', 'withdrawn', 'transferred', 'graduated'))$q$);
ALTER TABLE sms.sms_students DROP CONSTRAINT IF EXISTS sms_students_blood_check;
ALTER TABLE sms.sms_students ADD CONSTRAINT sms_students_blood_check
    CHECK (blood_group IS NULL OR blood_group IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'));
CREATE INDEX IF NOT EXISTS sms_students_class_group_idx ON sms.sms_students (class_group_id);

CREATE TABLE IF NOT EXISTS sms.sms_emergency_contacts (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    student_id    text NOT NULL REFERENCES sms.sms_students (id) ON DELETE CASCADE,
    full_name     text NOT NULL,
    relationship  text,
    phone         text NOT NULL,
    alt_phone     text,
    can_pick_up   boolean NOT NULL DEFAULT false,
    priority      int NOT NULL DEFAULT 1,
    notes         text,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sms_emergency_contacts_idx ON sms.sms_emergency_contacts (student_id, priority);

CREATE TABLE IF NOT EXISTS sms.sms_student_documents (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    student_id       text NOT NULL REFERENCES sms.sms_students (id) ON DELETE CASCADE,
    doc_type         text NOT NULL,
    number           text,
    issuing_country  text,
    issued_on        date,
    expires_on       date,
    file_id          text REFERENCES sms.sms_files (id) ON DELETE SET NULL,
    notes            text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz,
    created_by       text
);
ALTER TABLE sms.sms_student_documents DROP CONSTRAINT IF EXISTS sms_student_documents_type_check;
ALTER TABLE sms.sms_student_documents ADD CONSTRAINT sms_student_documents_type_check CHECK (doc_type IN
    ('birth_certificate', 'passport', 'visa', 'residence_permit', 'national_id', 'previous_report', 'medical_form', 'immunisation', 'transfer_letter', 'other'));
CREATE INDEX IF NOT EXISTS sms_student_documents_idx ON sms.sms_student_documents (student_id);
CREATE INDEX IF NOT EXISTS sms_student_documents_expiry_idx ON sms.sms_student_documents (bus_id, expires_on) WHERE expires_on IS NOT NULL;

CREATE TABLE IF NOT EXISTS sms.sms_student_history (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    student_id      text NOT NULL REFERENCES sms.sms_students (id) ON DELETE CASCADE,
    profile_id      text NOT NULL,
    academic_year   text,
    class_id        text,
    class_name      text,
    year_group_id   text,
    outcome         text NOT NULL,
    on_date         date NOT NULL DEFAULT CURRENT_DATE,
    batch_id        text,
    note            text,
    recorded_by     text,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_student_history DROP CONSTRAINT IF EXISTS sms_student_history_outcome_check;
ALTER TABLE sms.sms_student_history ADD CONSTRAINT sms_student_history_outcome_check CHECK (outcome IN
    ('enrolled', 'placed', 'promoted', 'repeated', 'graduated', 'transferred_in', 'transferred_out', 'withdrawn', 'readmitted'));
CREATE INDEX IF NOT EXISTS sms_student_history_idx ON sms.sms_student_history (student_id, cdatetime);

-- =================================================================== promotion
CREATE TABLE IF NOT EXISTS sms.sms_promotion_batches (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles (id),
    from_year     text NOT NULL,
    to_year       text NOT NULL,
    status        text NOT NULL DEFAULT 'draft',
    note          text,
    submitted_by  text,
    submitted_at  timestamptz,
    decided_by    text,
    decided_at    timestamptz,
    decision_note text,
    applied_at    timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text
);
ALTER TABLE sms.sms_promotion_batches DROP CONSTRAINT IF EXISTS sms_promotion_batches_status_check;
ALTER TABLE sms.sms_promotion_batches ADD CONSTRAINT sms_promotion_batches_status_check
    CHECK (status IN ('draft', 'submitted', 'rejected', 'applied'));

CREATE TABLE IF NOT EXISTS sms.sms_promotion_items (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    batch_id       text NOT NULL REFERENCES sms.sms_promotion_batches (id) ON DELETE CASCADE,
    student_id     text NOT NULL REFERENCES sms.sms_students (id),
    from_class_id  text,
    action         text NOT NULL,
    to_class_id    text REFERENCES sms.sms_classes (id),
    note           text
);
ALTER TABLE sms.sms_promotion_items DROP CONSTRAINT IF EXISTS sms_promotion_items_action_check;
ALTER TABLE sms.sms_promotion_items ADD CONSTRAINT sms_promotion_items_action_check CHECK (action IN ('promote', 'repeat', 'graduate', 'skip'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_promotion_items_uq ON sms.sms_promotion_items (batch_id, student_id);

-- =================================================================== transfers and withdrawals
CREATE TABLE IF NOT EXISTS sms.sms_student_movements (
    id                   text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id            text NOT NULL,
    bus_id               text NOT NULL,
    profile_id           text NOT NULL REFERENCES sms.sms_profiles (id),
    student_id           text NOT NULL REFERENCES sms.sms_students (id),
    kind                 text NOT NULL,
    reason               text NOT NULL,
    effective_on         date NOT NULL,
    to_profile_id        text REFERENCES sms.sms_profiles (id),
    to_class_id          text REFERENCES sms.sms_classes (id),
    destination_school   text,
    notes                text,
    clearance            jsonb NOT NULL DEFAULT '[]',
    status               text NOT NULL DEFAULT 'pending',
    certificate_no       text,
    completed_by         text,
    completed_at         timestamptz,
    cdatetime            timestamptz NOT NULL DEFAULT now(),
    created_by           text
);
ALTER TABLE sms.sms_student_movements DROP CONSTRAINT IF EXISTS sms_student_movements_kind_check;
ALTER TABLE sms.sms_student_movements ADD CONSTRAINT sms_student_movements_kind_check CHECK (kind IN ('transfer', 'withdrawal'));
ALTER TABLE sms.sms_student_movements DROP CONSTRAINT IF EXISTS sms_student_movements_status_check;
ALTER TABLE sms.sms_student_movements ADD CONSTRAINT sms_student_movements_status_check CHECK (status IN ('pending', 'completed', 'cancelled'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_student_movements_open_uq ON sms.sms_student_movements (student_id) WHERE status = 'pending';
CREATE UNIQUE INDEX IF NOT EXISTS sms_student_movements_cert_uq ON sms.sms_student_movements (bus_id, certificate_no) WHERE certificate_no IS NOT NULL;

-- =================================================================== custom fields
CREATE TABLE IF NOT EXISTS sms.sms_custom_fields (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles (id),
    entity       text NOT NULL DEFAULT 'student',
    key          text NOT NULL,
    label        text NOT NULL,
    type         text NOT NULL DEFAULT 'text',
    options      text[] NOT NULL DEFAULT '{}',
    required     boolean NOT NULL DEFAULT false,
    section      text NOT NULL DEFAULT 'Other details',
    help         text,
    sort_order   int NOT NULL DEFAULT 0,
    is_active    boolean NOT NULL DEFAULT true,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_custom_fields DROP CONSTRAINT IF EXISTS sms_custom_fields_type_check;
ALTER TABLE sms.sms_custom_fields ADD CONSTRAINT sms_custom_fields_type_check CHECK (type IN ('text', 'textarea', 'number', 'date', 'select', 'yes_no'));
ALTER TABLE sms.sms_custom_fields DROP CONSTRAINT IF EXISTS sms_custom_fields_entity_check;
ALTER TABLE sms.sms_custom_fields ADD CONSTRAINT sms_custom_fields_entity_check CHECK (entity IN ('student'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_custom_fields_key_uq ON sms.sms_custom_fields (profile_id, entity, key);

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-structure', 'SMS Academic Structure', 'Divisions, year groups, classes and subjects', 'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('structure', 'rt-sms-structure', 'get',     'View divisions, year groups, classes and subjects'),
    ('structure', 'rt-sms-structure', 'manage',  'Set up divisions, year groups, classes and subjects'),
    ('students',  'rt-sms-students',  'approve', 'Approve the year-end promotion and complete transfers and withdrawals')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-sms-' || spec.resource_key || '-' || spec.action,
       'SMS ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
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

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-sms-head' AS role_id, p2.resource_key, p2.action
      FROM core_platform.cp_permissions p2 WHERE p2.app_prefix = 'sms'
    UNION ALL
    SELECT 'role-sms-registrar', k, a FROM (VALUES ('structure', 'get'), ('structure', 'manage')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-admissions', k, a FROM (VALUES ('structure', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-viewer', p3.resource_key, p3.action
      FROM core_platform.cp_permissions p3
      JOIN core_platform.cp_actions a ON a.action = p3.action AND a.is_read_only AND p3.action <> 'export'
     WHERE p3.app_prefix = 'sms'
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'sms' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.structure',       'app-sms', 'Academic Structure',        1, 'Divisions, year groups, classes and subjects, without limits'),
('sms.student-records', 'app-sms', 'Student Records',           1, 'Bio data, photos, guardians, emergency contacts, documents, alumni and withdrawn records, class lists'),
('sms.promotion',       'app-sms', 'Promotion & Rollover',      1, 'Bulk promote, repeat or graduate with approval; roll the academic year forward'),
('sms.transfers',       'app-sms', 'Transfers & Withdrawals',   1, 'Inter-campus transfers, withdrawal reasons, clearance checklists and transfer certificates'),
('sms.id-cards',        'app-sms', 'Student ID Cards',          1, 'ID cards with photo, barcode or QR code'),
('sms.custom-fields',   'app-sms', 'Custom Fields',             2, 'Fields a school adds to the student record itself'),
('sms.document-alerts', 'app-sms', 'Passport & Visa Tracking',  2, 'Passports, visas and residence permits with expiry and renewal reminders')
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
