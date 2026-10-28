-- MyEduGuard 10: inclusion and special educational needs -- support for every learner.
--
--   sms_sen_register           a learner's additional needs, their level of support, the strategies
--                              every teacher should use, the SENCo and the next review
--   sms_ieps, _iep_targets,    individual education plans: targets with success criteria, the
--   _iep_progress, _iep_reviews accommodations, progress on each target, and reviews with the family
--   sms_access_arrangements    exam access: extra time, a reader, a scribe, a separate room, rest
--                              breaks, a word processor -- used when the exams are seated
--   sms_gifted                 gifted and talented learners: the areas, the evidence, the provision
--   sms_eal, _eal_assessments  English language learners: first language, proficiency (A new to
--                              English .. E fluent) assessed over time, and the support given
--
-- Permissions sms|inclusion|get/manage; the role MyEduGuard SENCo. Teachers read (they need the
-- strategies and arrangements). Idempotent.

BEGIN;

CREATE TABLE IF NOT EXISTS sms.sms_sen_register (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    profile_id     text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id     text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    level          text NOT NULL DEFAULT 'monitoring',
    primary_need   text NOT NULL,
    other_needs    text[] NOT NULL DEFAULT '{}',
    details        text,
    strategies     text,
    diagnosed      boolean NOT NULL DEFAULT false,
    diagnosis_by   text,
    coordinator_id text,
    identified_on  date NOT NULL DEFAULT CURRENT_DATE,
    review_on      date,
    ended_on       date,
    end_reason     text,
    created_by     text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz
);
ALTER TABLE sms.sms_sen_register DROP CONSTRAINT IF EXISTS sms_sen_register_check2;
ALTER TABLE sms.sms_sen_register ADD CONSTRAINT sms_sen_register_check2
    CHECK (level IN ('monitoring', 'support', 'high_needs')
           AND primary_need IN ('learning', 'dyslexia', 'dyscalculia', 'speech_language', 'autism', 'adhd', 'social_emotional', 'hearing', 'visual',
                                'physical', 'medical', 'multiple', 'other')
           AND (ended_on IS NULL OR ended_on >= identified_on));
CREATE UNIQUE INDEX IF NOT EXISTS sms_sen_register_one_open ON sms.sms_sen_register (student_id) WHERE ended_on IS NULL;
CREATE INDEX IF NOT EXISTS sms_sen_register_idx ON sms.sms_sen_register (profile_id, ended_on);

CREATE TABLE IF NOT EXISTS sms.sms_ieps (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id      text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    title           text NOT NULL,
    starts_on       date NOT NULL,
    ends_on         date NOT NULL,
    review_on       date,
    status          text NOT NULL DEFAULT 'draft',
    strengths       text,
    accommodations  text[] NOT NULL DEFAULT '{}',
    family_views    text,
    student_views   text,
    created_by      text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz,
    CHECK (ends_on > starts_on)
);
ALTER TABLE sms.sms_ieps DROP CONSTRAINT IF EXISTS sms_ieps_status_check;
ALTER TABLE sms.sms_ieps ADD CONSTRAINT sms_ieps_status_check CHECK (status IN ('draft', 'active', 'closed'));
CREATE INDEX IF NOT EXISTS sms_ieps_student_idx ON sms.sms_ieps (student_id, starts_on DESC);

CREATE TABLE IF NOT EXISTS sms.sms_iep_targets (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    iep_id            text NOT NULL REFERENCES sms.sms_ieps(id) ON DELETE CASCADE,
    area              text NOT NULL,
    target            text NOT NULL,
    success_criteria  text,
    strategies        text,
    owner             text,
    due_on            date,
    status            text NOT NULL DEFAULT 'not_started',
    sort_order        integer NOT NULL DEFAULT 0
);
ALTER TABLE sms.sms_iep_targets DROP CONSTRAINT IF EXISTS sms_iep_targets_check2;
ALTER TABLE sms.sms_iep_targets ADD CONSTRAINT sms_iep_targets_check2
    CHECK (status IN ('not_started', 'progressing', 'achieved', 'not_achieved')
           AND area IN ('literacy', 'numeracy', 'communication', 'social', 'emotional', 'behaviour', 'independence', 'physical', 'sensory', 'other'));
CREATE INDEX IF NOT EXISTS sms_iep_targets_idx ON sms.sms_iep_targets (iep_id, sort_order);

CREATE TABLE IF NOT EXISTS sms.sms_iep_progress (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    target_id   text NOT NULL REFERENCES sms.sms_iep_targets(id) ON DELETE CASCADE,
    noted_on    date NOT NULL DEFAULT CURRENT_DATE,
    rating      integer NOT NULL,
    note        text,
    by_user     text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    CHECK (rating BETWEEN 0 AND 4)
);
CREATE INDEX IF NOT EXISTS sms_iep_progress_idx ON sms.sms_iep_progress (target_id, noted_on);

CREATE TABLE IF NOT EXISTS sms.sms_iep_reviews (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    iep_id       text NOT NULL REFERENCES sms.sms_ieps(id) ON DELETE CASCADE,
    reviewed_on  date NOT NULL,
    attended     text,
    summary      text NOT NULL,
    next_steps   text,
    by_user      text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sms.sms_access_arrangements (
    student_id      text PRIMARY KEY REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    extra_time_pct  integer NOT NULL DEFAULT 0,
    reader          boolean NOT NULL DEFAULT false,
    scribe          boolean NOT NULL DEFAULT false,
    separate_room   boolean NOT NULL DEFAULT false,
    rest_breaks     boolean NOT NULL DEFAULT false,
    word_processor  boolean NOT NULL DEFAULT false,
    enlarged_paper  boolean NOT NULL DEFAULT false,
    other           text,
    evidence        text,
    valid_until     date,
    approved_by     text,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CHECK (extra_time_pct BETWEEN 0 AND 100)
);
CREATE INDEX IF NOT EXISTS sms_access_arrangements_idx ON sms.sms_access_arrangements (profile_id);

CREATE TABLE IF NOT EXISTS sms.sms_gifted (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id    text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    areas         text[] NOT NULL,
    subject_ids   text[] NOT NULL DEFAULT '{}',
    evidence      text,
    provision     text,
    identified_on date NOT NULL DEFAULT CURRENT_DATE,
    review_on     date,
    ended_on      date,
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    CHECK (cardinality(areas) > 0)
);
CREATE UNIQUE INDEX IF NOT EXISTS sms_gifted_one_open ON sms.sms_gifted (student_id) WHERE ended_on IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_eal (
    student_id       text PRIMARY KEY REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    profile_id       text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    first_language   text NOT NULL,
    other_languages  text,
    level            text NOT NULL,
    arrived_on       date,
    support          text,
    ended_on         date,
    updated_by       text,
    updated_at       timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_eal DROP CONSTRAINT IF EXISTS sms_eal_level_check;
ALTER TABLE sms.sms_eal ADD CONSTRAINT sms_eal_level_check CHECK (level IN ('A', 'B', 'C', 'D', 'E'));

CREATE TABLE IF NOT EXISTS sms.sms_eal_assessments (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    student_id   text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    assessed_on  date NOT NULL,
    listening    text NOT NULL,
    speaking     text NOT NULL,
    reading      text NOT NULL,
    writing      text NOT NULL,
    overall      text NOT NULL,
    note         text,
    by_user      text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_eal_assessments DROP CONSTRAINT IF EXISTS sms_eal_assessments_check;
ALTER TABLE sms.sms_eal_assessments ADD CONSTRAINT sms_eal_assessments_check
    CHECK (listening IN ('A','B','C','D','E') AND speaking IN ('A','B','C','D','E') AND reading IN ('A','B','C','D','E')
           AND writing IN ('A','B','C','D','E') AND overall IN ('A','B','C','D','E'));
CREATE INDEX IF NOT EXISTS sms_eal_assessments_idx ON sms.sms_eal_assessments (student_id, assessed_on);

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-inclusion', 'MyEduGuard Inclusion', 'The SEN register, IEPs, exam access arrangements, gifted and talented, and English language learners', 'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, action, label) AS (VALUES
    ('inclusion', 'get',    'View the SEN register, IEPs, access arrangements, gifted and talented and EAL learners, and record IEP progress'),
    ('inclusion', 'manage', 'Keep the SEN register, write and review IEPs, and set access arrangements (the SENCo)')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-sms-' || spec.resource_key || '-' || spec.action,
       'MyEduGuard ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       'rt-sms-inclusion', spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
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
('role-sms-senco', 'system-tenant-id', 'MyEduGuard SENCo', 'The inclusion lead: keeps the SEN register, writes and reviews IEPs, sets exam access arrangements, gifted and talented, and EAL', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
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
    SELECT 'role-sms-teacher', k, a FROM (VALUES ('inclusion', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-registrar', k, a FROM (VALUES ('inclusion', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-counsellor', k, a FROM (VALUES ('inclusion', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-senco', k, a FROM (VALUES ('inclusion', 'get'), ('inclusion', 'manage'), ('students', 'get'), ('structure', 'get'),
        ('profiles', 'get'), ('exams', 'get'), ('grades', 'get'), ('reports', 'get'), ('health', 'get'), ('behaviour', 'get'), ('attendance', 'get'),
        ('safeguarding', 'create')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-viewer', p3.resource_key, p3.action
      FROM core_platform.cp_permissions p3
      JOIN core_platform.cp_actions a ON a.action = p3.action AND a.is_read_only AND p3.action <> 'export'
     WHERE p3.app_prefix = 'sms' AND p3.resource_key NOT IN ('counselling', 'safeguarding')
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'sms' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', 'role-sms-senco', p.id
  FROM core_platform.cp_permissions p
 WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.sen-register',         'app-sms', 'SEN Register',                     1, 'Learners with additional needs and their support levels'),
('sms.eal',                  'app-sms', 'English Language Learner Tracking', 1, 'EAL/ESL proficiency levels and support'),
('sms.ieps',                 'app-sms', 'Individual Education Plans (IEPs)', 2, 'Targets, accommodations, reviews and progress tracking'),
('sms.access-arrangements',  'app-sms', 'Exam Access Arrangements',         2, 'Extra time, readers and scribes linked to exam scheduling'),
('sms.gifted',               'app-sms', 'Gifted & Talented Tracking',       2, 'Identify and monitor high attaining learners')
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
                WHERE rp.role_id = 'role-sms-teacher' AND p.app_prefix = 'sms' AND p.action IN ('manage', 'approve')) THEN
        RAISE EXCEPTION 'an SMS Teacher manages and approves nothing';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id IN ('role-sms-viewer', 'role-sms-teacher', 'role-sms-registrar', 'role-sms-admissions', 'role-sms-nurse', 'role-sms-security', 'role-sms-senco')
                  AND p.app_prefix = 'sms' AND (p.resource_key = 'counselling' OR (p.resource_key = 'safeguarding' AND p.action <> 'create'))) THEN
        RAISE EXCEPTION 'counselling records and safeguarding cases are for counsellors, safeguarding leads and the head';
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
