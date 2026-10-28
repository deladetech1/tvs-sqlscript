-- SMS: learning management and online learning -- teaching and learning beyond the classroom.
--
--   sms_assignments, _submissions  assignments and homework set online, submitted from the
--                                  family's page (text and files), graded, returned with
--                                  feedback, checked for similarity, sent to the gradebook
--   sms_class_resources            notes, slides, videos and links per class and topic
--   sms_virtual_classes            live lessons on Zoom, Google Meet or Microsoft Teams
--   sms_quizzes, _questions,
--   _attempts                      short quizzes marked automatically, with instant feedback
--   sms_discussions, _posts        moderated class discussion boards
--   sms_lms_settings               plagiarism checking (built in, Turnitin), Zoom, moderation and
--                                  the school's Google / Microsoft domains
--   sms_lms_syncs                  roster exports (Microsoft School Data Sync, OneRoster for
--                                  Google Classroom) and grade imports
--   sms_students.email             the student's school account (Google or Microsoft)
--
-- Permissions sms|learning|get/create/manage; plan features. Idempotent.

BEGIN;

ALTER TABLE sms.sms_students ADD COLUMN IF NOT EXISTS email text;

-- =================================================================== assignments
CREATE TABLE IF NOT EXISTS sms.sms_assignments (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    profile_id        text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    class_id          text NOT NULL REFERENCES sms.sms_classes(id) ON DELETE CASCADE,
    subject_id        text NOT NULL REFERENCES sms.sms_subjects(id) ON DELETE CASCADE,
    term_id           text REFERENCES sms.sms_terms(id) ON DELETE SET NULL,
    topic_id          text REFERENCES sms.sms_scheme_topics(id) ON DELETE SET NULL,
    kind              text NOT NULL DEFAULT 'homework',
    title             text NOT NULL,
    instructions      text,
    due_at            timestamptz NOT NULL,
    max_score         numeric(8,2),
    accept_text       boolean NOT NULL DEFAULT true,
    accept_files      boolean NOT NULL DEFAULT true,
    allow_late        boolean NOT NULL DEFAULT true,
    check_similarity  boolean NOT NULL DEFAULT false,
    status            text NOT NULL DEFAULT 'draft',
    gradebook_item_id text REFERENCES sms.sms_gradebook_items(id) ON DELETE SET NULL,
    published_at      timestamptz,
    created_by        text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    archived_at       timestamptz
);
ALTER TABLE sms.sms_assignments DROP CONSTRAINT IF EXISTS sms_assignments_kind_check;
ALTER TABLE sms.sms_assignments ADD CONSTRAINT sms_assignments_kind_check CHECK (kind IN ('homework', 'assignment', 'project'));
ALTER TABLE sms.sms_assignments DROP CONSTRAINT IF EXISTS sms_assignments_status_check;
ALTER TABLE sms.sms_assignments ADD CONSTRAINT sms_assignments_status_check CHECK (status IN ('draft', 'published', 'closed'));
ALTER TABLE sms.sms_assignments DROP CONSTRAINT IF EXISTS sms_assignments_max_check;
ALTER TABLE sms.sms_assignments ADD CONSTRAINT sms_assignments_max_check CHECK (max_score IS NULL OR max_score > 0);
CREATE INDEX IF NOT EXISTS sms_assignments_class_idx ON sms.sms_assignments (class_id, due_at DESC);
CREATE INDEX IF NOT EXISTS sms_assignments_profile_idx ON sms.sms_assignments (profile_id, due_at DESC);

CREATE TABLE IF NOT EXISTS sms.sms_submissions (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    assignment_id  text NOT NULL REFERENCES sms.sms_assignments(id) ON DELETE CASCADE,
    student_id     text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    body           text,
    status         text NOT NULL DEFAULT 'submitted',
    submitted_at   timestamptz NOT NULL DEFAULT now(),
    late           boolean NOT NULL DEFAULT false,
    score          numeric(8,2),
    feedback       text,
    graded_by      text,
    graded_at      timestamptz,
    returned_at    timestamptz,
    similarity     numeric(5,2),
    similarity_detail jsonb,
    external_check jsonb,
    UNIQUE (assignment_id, student_id)
);
-- The text of the files handed in (plain text and Word), read at upload for similarity checks.
ALTER TABLE sms.sms_submissions ADD COLUMN IF NOT EXISTS file_text text;
ALTER TABLE sms.sms_submissions DROP CONSTRAINT IF EXISTS sms_submissions_status_check;
ALTER TABLE sms.sms_submissions ADD CONSTRAINT sms_submissions_status_check CHECK (status IN ('submitted', 'returned', 'resubmit'));

-- =================================================================== resources
CREATE TABLE IF NOT EXISTS sms.sms_class_resources (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    class_ids   text[] NOT NULL DEFAULT '{}',
    subject_id  text NOT NULL REFERENCES sms.sms_subjects(id) ON DELETE CASCADE,
    topic_id    text REFERENCES sms.sms_scheme_topics(id) ON DELETE SET NULL,
    kind        text NOT NULL,
    title       text NOT NULL,
    description text,
    url         text,
    is_published boolean NOT NULL DEFAULT true,
    created_by  text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    archived_at timestamptz
);
ALTER TABLE sms.sms_class_resources DROP CONSTRAINT IF EXISTS sms_class_resources_kind_check;
ALTER TABLE sms.sms_class_resources ADD CONSTRAINT sms_class_resources_kind_check CHECK (kind IN ('note', 'slides', 'video', 'link', 'document'));
CREATE INDEX IF NOT EXISTS sms_class_resources_subject_idx ON sms.sms_class_resources (profile_id, subject_id);

-- =================================================================== virtual classes
CREATE TABLE IF NOT EXISTS sms.sms_virtual_classes (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    class_ids     text[] NOT NULL DEFAULT '{}',
    subject_id    text REFERENCES sms.sms_subjects(id) ON DELETE SET NULL,
    title         text NOT NULL,
    provider      text NOT NULL,
    join_url      text NOT NULL,
    meeting_id    text,
    passcode      text,
    starts_at     timestamptz NOT NULL,
    minutes       integer NOT NULL DEFAULT 40,
    recording_url text,
    notes         text,
    created_via   text NOT NULL DEFAULT 'link',
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    cancelled_at  timestamptz
);
ALTER TABLE sms.sms_virtual_classes DROP CONSTRAINT IF EXISTS sms_virtual_classes_provider_check;
ALTER TABLE sms.sms_virtual_classes ADD CONSTRAINT sms_virtual_classes_provider_check CHECK (provider IN ('zoom', 'meet', 'teams', 'other'));
ALTER TABLE sms.sms_virtual_classes DROP CONSTRAINT IF EXISTS sms_virtual_classes_minutes_check;
ALTER TABLE sms.sms_virtual_classes ADD CONSTRAINT sms_virtual_classes_minutes_check CHECK (minutes BETWEEN 5 AND 480);
CREATE INDEX IF NOT EXISTS sms_virtual_classes_profile_idx ON sms.sms_virtual_classes (profile_id, starts_at);

-- =================================================================== quizzes
CREATE TABLE IF NOT EXISTS sms.sms_quizzes (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    profile_id        text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    class_id          text NOT NULL REFERENCES sms.sms_classes(id) ON DELETE CASCADE,
    subject_id        text NOT NULL REFERENCES sms.sms_subjects(id) ON DELETE CASCADE,
    term_id           text REFERENCES sms.sms_terms(id) ON DELETE SET NULL,
    topic_id          text REFERENCES sms.sms_scheme_topics(id) ON DELETE SET NULL,
    title             text NOT NULL,
    instructions      text,
    opens_at          timestamptz,
    closes_at         timestamptz,
    time_limit_min    integer,
    attempts_allowed  integer NOT NULL DEFAULT 1,
    show_answers      text NOT NULL DEFAULT 'immediately',
    shuffle           boolean NOT NULL DEFAULT false,
    status            text NOT NULL DEFAULT 'draft',
    gradebook_item_id text REFERENCES sms.sms_gradebook_items(id) ON DELETE SET NULL,
    created_by        text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    archived_at       timestamptz
);
ALTER TABLE sms.sms_quizzes DROP CONSTRAINT IF EXISTS sms_quizzes_status_check;
ALTER TABLE sms.sms_quizzes ADD CONSTRAINT sms_quizzes_status_check CHECK (status IN ('draft', 'published', 'closed'));
ALTER TABLE sms.sms_quizzes DROP CONSTRAINT IF EXISTS sms_quizzes_answers_check;
ALTER TABLE sms.sms_quizzes ADD CONSTRAINT sms_quizzes_answers_check CHECK (show_answers IN ('immediately', 'after_close', 'never'));
ALTER TABLE sms.sms_quizzes DROP CONSTRAINT IF EXISTS sms_quizzes_attempts_check;
ALTER TABLE sms.sms_quizzes ADD CONSTRAINT sms_quizzes_attempts_check CHECK (attempts_allowed BETWEEN 1 AND 10);
CREATE INDEX IF NOT EXISTS sms_quizzes_class_idx ON sms.sms_quizzes (class_id);

CREATE TABLE IF NOT EXISTS sms.sms_quiz_questions (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    quiz_id     text NOT NULL REFERENCES sms.sms_quizzes(id) ON DELETE CASCADE,
    kind        text NOT NULL,
    prompt      text NOT NULL,
    options     jsonb NOT NULL DEFAULT '[]',
    answer      jsonb NOT NULL,
    points      numeric(6,2) NOT NULL DEFAULT 1,
    explanation text,
    sort_order  integer NOT NULL DEFAULT 0
);
ALTER TABLE sms.sms_quiz_questions DROP CONSTRAINT IF EXISTS sms_quiz_questions_kind_check;
ALTER TABLE sms.sms_quiz_questions ADD CONSTRAINT sms_quiz_questions_kind_check CHECK (kind IN ('single', 'multiple', 'true_false', 'short', 'number'));
ALTER TABLE sms.sms_quiz_questions DROP CONSTRAINT IF EXISTS sms_quiz_questions_points_check;
ALTER TABLE sms.sms_quiz_questions ADD CONSTRAINT sms_quiz_questions_points_check CHECK (points > 0);
CREATE INDEX IF NOT EXISTS sms_quiz_questions_quiz_idx ON sms.sms_quiz_questions (quiz_id, sort_order);

CREATE TABLE IF NOT EXISTS sms.sms_quiz_attempts (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    quiz_id      text NOT NULL REFERENCES sms.sms_quizzes(id) ON DELETE CASCADE,
    student_id   text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    attempt_no   integer NOT NULL,
    started_at   timestamptz NOT NULL DEFAULT now(),
    submitted_at timestamptz,
    answers      jsonb,
    score        numeric(8,2),
    max_score    numeric(8,2),
    pct          numeric(5,1),
    detail       jsonb,
    UNIQUE (quiz_id, student_id, attempt_no)
);

-- =================================================================== discussions
CREATE TABLE IF NOT EXISTS sms.sms_discussions (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    class_id     text NOT NULL REFERENCES sms.sms_classes(id) ON DELETE CASCADE,
    subject_id   text REFERENCES sms.sms_subjects(id) ON DELETE SET NULL,
    title        text NOT NULL,
    body         text,
    premoderate  boolean NOT NULL DEFAULT true,
    pinned       boolean NOT NULL DEFAULT false,
    locked       boolean NOT NULL DEFAULT false,
    created_by   text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    archived_at  timestamptz
);
CREATE INDEX IF NOT EXISTS sms_discussions_class_idx ON sms.sms_discussions (class_id);

CREATE TABLE IF NOT EXISTS sms.sms_discussion_posts (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    discussion_id     text NOT NULL REFERENCES sms.sms_discussions(id) ON DELETE CASCADE,
    parent_id         text REFERENCES sms.sms_discussion_posts(id) ON DELETE CASCADE,
    author_user_id    text,
    author_student_id text REFERENCES sms.sms_students(id) ON DELETE SET NULL,
    author_name       text NOT NULL,
    body              text NOT NULL,
    status            text NOT NULL DEFAULT 'visible',
    moderated_by      text,
    moderated_at      timestamptz,
    hidden_reason     text,
    cdatetime         timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_discussion_posts DROP CONSTRAINT IF EXISTS sms_discussion_posts_status_check;
ALTER TABLE sms.sms_discussion_posts ADD CONSTRAINT sms_discussion_posts_status_check CHECK (status IN ('visible', 'pending', 'hidden'));
CREATE INDEX IF NOT EXISTS sms_discussion_posts_idx ON sms.sms_discussion_posts (discussion_id, cdatetime);

-- =================================================================== settings and sync
CREATE TABLE IF NOT EXISTS sms.sms_lms_settings (
    profile_id            text PRIMARY KEY REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    plagiarism_provider   text NOT NULL DEFAULT 'builtin',
    similarity_flag_pct   integer NOT NULL DEFAULT 40,
    turnitin_url          text,
    turnitin_key          text,
    zoom_account_id       text,
    zoom_client_id        text,
    zoom_client_secret    text,
    premoderate_posts     boolean NOT NULL DEFAULT true,
    google_domain         text,
    microsoft_domain      text,
    updated_at            timestamptz NOT NULL DEFAULT now(),
    updated_by            text
);
ALTER TABLE sms.sms_lms_settings DROP CONSTRAINT IF EXISTS sms_lms_settings_provider_check;
ALTER TABLE sms.sms_lms_settings ADD CONSTRAINT sms_lms_settings_provider_check CHECK (plagiarism_provider IN ('off', 'builtin', 'turnitin'));
ALTER TABLE sms.sms_lms_settings DROP CONSTRAINT IF EXISTS sms_lms_settings_flag_check;
ALTER TABLE sms.sms_lms_settings ADD CONSTRAINT sms_lms_settings_flag_check CHECK (similarity_flag_pct BETWEEN 5 AND 100);

CREATE TABLE IF NOT EXISTS sms.sms_lms_syncs (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    kind        text NOT NULL,
    provider    text NOT NULL,
    summary     jsonb,
    created_by  text,
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_lms_syncs DROP CONSTRAINT IF EXISTS sms_lms_syncs_kind_check;
ALTER TABLE sms.sms_lms_syncs ADD CONSTRAINT sms_lms_syncs_kind_check CHECK (kind IN ('roster_export', 'grades_import', 'grades_export'));

-- Files: assignment briefs, submissions and class resources; videos for resources.
ALTER TABLE sms.sms_files DROP CONSTRAINT IF EXISTS sms_files_entity_check;
ALTER TABLE sms.sms_files ADD CONSTRAINT sms_files_entity_check CHECK (entity_type IS NULL OR entity_type IN
    ('profile', 'application', 'enquiry', 'family', 'student', 'leave_request', 'assignment', 'submission', 'class_resource'));
ALTER TABLE sms.sms_files DROP CONSTRAINT IF EXISTS sms_files_kind_check;
ALTER TABLE sms.sms_files ADD CONSTRAINT sms_files_kind_check CHECK (kind IN ('image', 'document', 'video'));

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-learning', 'SMS Learning', 'Assignments, class resources, virtual classes, quizzes, discussions and learning integrations', 'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('learning', 'rt-sms-learning', 'get',    'View assignments, resources, live classes, quizzes and discussions'),
    ('learning', 'rt-sms-learning', 'create', 'Set and mark assignments, share resources, schedule live classes, write quizzes and moderate discussions'),
    ('learning', 'rt-sms-learning', 'manage', 'Configure plagiarism checking, Zoom and the Google / Microsoft sync, and work on every class')
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
    SELECT 'role-sms-teacher', k, a FROM (VALUES ('learning', 'get'), ('learning', 'create')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-registrar', k, a FROM (VALUES ('learning', 'get')) AS g(k, a)
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
('sms.assignments',     'app-sms', 'Assignments & Homework',      1, 'Set, submit, grade and return assignments online'),
('sms.class-resources', 'app-sms', 'Class Resources',             1, 'Notes, slides, videos and links per class and topic'),
('sms.quizzes',         'app-sms', 'Quizzes & Auto-marked Tasks', 1, 'Short quizzes with instant feedback'),
('sms.discussions',     'app-sms', 'Discussion Boards',           2, 'Moderated class discussions'),
('sms.virtual-classes', 'app-sms', 'Virtual Classes',             2, 'Live lessons on Zoom, Google Meet or Microsoft Teams'),
('sms.plagiarism',      'app-sms', 'Plagiarism Checking',         3, 'Similarity checks within the class, or through Turnitin'),
('sms.lms-sync',        'app-sms', 'Google Classroom & Microsoft 365 Sync', 3, 'Sync classes, rosters and grades')
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
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-sms-viewer' AND p.app_prefix = 'sms' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-sms-viewer holds % SMS permission(s) that change data', n;
    END IF;
END $$;

COMMIT;
