-- MyEduGuard: examinations and external boards.
--
--   sms_question_bank      reusable questions by subject, topic and difficulty: choice, true or
--                          false, short answers, numbers and essays
--   sms_cbt_tests          computer based tests: timed, drawn from the bank at random or fixed,
--                          shuffled per student, marked at once (essays by the teacher); class
--                          tests, exams, mocks and admissions' entrance exams
--   sms_cbt_attempts       one per candidate: the questions they were given, their answers, how
--                          often they left the test page, and the marks
--   sms_board_series       an external board's series the school enters candidates for (WAEC
--                          WASSCE May/June 2027, Cambridge IGCSE November...), with its fees
--   sms_board_subjects     the board's subjects in that series, with their codes
--   sms_board_entries      a candidate's entry: candidate and index numbers, subjects, fees
--                          billed to the fee account, and the results imported back
--   sms_predicted_grades   mock and predicted grades per student and subject, for university
--                          applications
--
-- Exam sessions say what they are (internal, mock, external, entrance). Idempotent; safe to re-run.

BEGIN;

ALTER TABLE sms.sms_exam_sessions ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'internal';
SELECT sms.widen_check('sms.sms_exam_sessions', 'sms_exam_sessions_kind_check', $q$'entrance'$q$, $q$CHECK (kind IN ('internal', 'mock', 'external', 'entrance'))$q$);

-- =================================================================== the question bank
CREATE TABLE IF NOT EXISTS sms.sms_question_bank (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    profile_id     text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    subject_id     text NOT NULL REFERENCES sms.sms_subjects(id) ON DELETE CASCADE,
    year_group_id  text REFERENCES sms.sms_year_groups(id) ON DELETE SET NULL,
    topic          text,
    difficulty     text NOT NULL DEFAULT 'medium',
    kind           text NOT NULL,
    prompt         text NOT NULL,
    options        jsonb NOT NULL DEFAULT '[]',
    answer         jsonb NOT NULL DEFAULT '{}',
    points         numeric(6,2) NOT NULL DEFAULT 1,
    explanation    text,
    tags           text[] NOT NULL DEFAULT '{}',
    source         text,
    status         text NOT NULL DEFAULT 'active',
    used_count     integer NOT NULL DEFAULT 0,
    right_count    integer NOT NULL DEFAULT 0,
    created_by     text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_question_bank', 'sms_question_bank_check', $q$'essay'$q$, $q$CHECK (
    difficulty IN ('easy', 'medium', 'hard') AND status IN ('active', 'retired') AND points > 0 AND points <= 100
    AND kind IN ('single', 'multiple', 'true_false', 'short', 'number', 'essay'))$q$);
CREATE INDEX IF NOT EXISTS sms_question_bank_subject_idx ON sms.sms_question_bank (profile_id, subject_id, topic, difficulty) WHERE status = 'active';

-- =================================================================== computer based tests
CREATE TABLE IF NOT EXISTS sms.sms_cbt_tests (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    bus_id              text NOT NULL,
    profile_id          text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    title               text NOT NULL,
    purpose             text NOT NULL DEFAULT 'class_test',
    subject_id          text REFERENCES sms.sms_subjects(id) ON DELETE SET NULL,
    class_ids           text[] NOT NULL DEFAULT '{}',
    admission_class_ids text[] NOT NULL DEFAULT '{}',
    session_id          text REFERENCES sms.sms_exam_sessions(id) ON DELETE SET NULL,
    term_id             text REFERENCES sms.sms_terms(id) ON DELETE SET NULL,
    instructions        text,
    opens_at            timestamptz,
    closes_at           timestamptz,
    duration_min        integer NOT NULL DEFAULT 30,
    shuffle_questions   boolean NOT NULL DEFAULT true,
    shuffle_options     boolean NOT NULL DEFAULT true,
    question_ids        text[] NOT NULL DEFAULT '{}',
    draws               jsonb NOT NULL DEFAULT '[]',
    pass_pct            numeric(5,2) NOT NULL DEFAULT 50,
    show_results        text NOT NULL DEFAULT 'after_close',
    access_code         text,
    full_screen         boolean NOT NULL DEFAULT false,
    status              text NOT NULL DEFAULT 'draft',
    gradebook_item_id   text REFERENCES sms.sms_gradebook_items(id) ON DELETE SET NULL,
    created_by          text,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_cbt_tests', 'sms_cbt_tests_check', $q$'entrance'$q$, $q$CHECK (
    purpose IN ('class_test', 'exam', 'mock', 'entrance') AND status IN ('draft', 'published', 'closed')
    AND show_results IN ('immediately', 'after_close', 'never') AND duration_min BETWEEN 1 AND 600
    AND pass_pct BETWEEN 0 AND 100 AND (closes_at IS NULL OR opens_at IS NULL OR closes_at > opens_at))$q$);
CREATE INDEX IF NOT EXISTS sms_cbt_tests_profile_idx ON sms.sms_cbt_tests (profile_id, status, opens_at DESC);

CREATE TABLE IF NOT EXISTS sms.sms_cbt_attempts (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    test_id         text NOT NULL REFERENCES sms.sms_cbt_tests(id) ON DELETE CASCADE,
    student_id      text REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    application_id  text REFERENCES sms.sms_applications(id) ON DELETE CASCADE,
    started_at      timestamptz NOT NULL DEFAULT now(),
    deadline        timestamptz NOT NULL,
    submitted_at    timestamptz,
    questions       jsonb NOT NULL DEFAULT '[]',
    answers         jsonb NOT NULL DEFAULT '{}',
    marks           jsonb NOT NULL DEFAULT '{}',
    auto_score      numeric(8,2) NOT NULL DEFAULT 0,
    manual_score    numeric(8,2),
    max_score       numeric(8,2) NOT NULL DEFAULT 0,
    pct             numeric(5,1),
    status          text NOT NULL DEFAULT 'in_progress',
    left_page       integer NOT NULL DEFAULT 0,
    marked_by       text,
    marked_at       timestamptz,
    CHECK ((student_id IS NULL) <> (application_id IS NULL))
);
SELECT sms.widen_check('sms.sms_cbt_attempts', 'sms_cbt_attempts_status_check', $q$'marked'$q$, $q$CHECK (status IN ('in_progress', 'submitted', 'marked'))$q$);
CREATE UNIQUE INDEX IF NOT EXISTS sms_cbt_attempts_student_uq ON sms.sms_cbt_attempts (test_id, student_id) WHERE student_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS sms_cbt_attempts_applicant_uq ON sms.sms_cbt_attempts (test_id, application_id) WHERE application_id IS NOT NULL;

-- =================================================================== external boards
CREATE TABLE IF NOT EXISTS sms.sms_board_series (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    board           text NOT NULL,
    name            text NOT NULL,
    year            integer NOT NULL,
    centre_number   text,
    entry_closes_on date,
    fee_base        numeric(14,2) NOT NULL DEFAULT 0,
    fee_per_subject numeric(14,2) NOT NULL DEFAULT 0,
    bill_fees       boolean NOT NULL DEFAULT false,
    status          text NOT NULL DEFAULT 'open',
    notes           text,
    created_by      text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_board_series', 'sms_board_series_check', $q$'results'$q$, $q$CHECK (
    status IN ('open', 'closed', 'submitted', 'results') AND fee_base >= 0 AND fee_per_subject >= 0 AND year BETWEEN 2000 AND 2100)$q$);
CREATE INDEX IF NOT EXISTS sms_board_series_profile_idx ON sms.sms_board_series (profile_id, year DESC);

CREATE TABLE IF NOT EXISTS sms.sms_board_subjects (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    series_id   text NOT NULL REFERENCES sms.sms_board_series(id) ON DELETE CASCADE,
    code        text NOT NULL,
    name        text NOT NULL,
    level       text,
    subject_id  text REFERENCES sms.sms_subjects(id) ON DELETE SET NULL,
    fee         numeric(14,2),
    compulsory  boolean NOT NULL DEFAULT false,
    UNIQUE (series_id, code)
);

CREATE TABLE IF NOT EXISTS sms.sms_board_entries (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    series_id           text NOT NULL REFERENCES sms.sms_board_series(id) ON DELETE CASCADE,
    student_id          text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    candidate_number    text,
    index_number        text,
    subject_codes       text[] NOT NULL DEFAULT '{}',
    status              text NOT NULL DEFAULT 'entered',
    fee_amount          numeric(14,2) NOT NULL DEFAULT 0,
    invoice_id          text REFERENCES sms.sms_fee_invoices(id) ON DELETE SET NULL,
    access_arrangements text,
    results             jsonb NOT NULL DEFAULT '[]',
    results_on          date,
    notes               text,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    UNIQUE (series_id, student_id)
);
SELECT sms.widen_check('sms.sms_board_entries', 'sms_board_entries_status_check', $q$'withdrawn'$q$, $q$CHECK (status IN ('entered', 'withdrawn'))$q$);
CREATE UNIQUE INDEX IF NOT EXISTS sms_board_entries_candidate_uq ON sms.sms_board_entries (series_id, candidate_number) WHERE candidate_number IS NOT NULL;

-- =================================================================== mock and predicted grades
CREATE TABLE IF NOT EXISTS sms.sms_predicted_grades (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id      text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    subject_id      text NOT NULL REFERENCES sms.sms_subjects(id) ON DELETE CASCADE,
    qualification   text NOT NULL,
    mock_grade      text,
    mock_pct        numeric(5,1),
    predicted_grade text,
    confidence      text NOT NULL DEFAULT 'medium',
    comment         text,
    status          text NOT NULL DEFAULT 'draft',
    teacher_id      text,
    approved_by     text,
    approved_at     timestamptz,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (student_id, subject_id, qualification)
);
SELECT sms.widen_check('sms.sms_predicted_grades', 'sms_predicted_grades_check', $q$'approved'$q$, $q$CHECK (
    confidence IN ('low', 'medium', 'high') AND status IN ('draft', 'submitted', 'approved'))$q$);
CREATE INDEX IF NOT EXISTS sms_predicted_grades_profile_idx ON sms.sms_predicted_grades (profile_id, qualification);

-- =================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.question-bank',     'app-sms', 'Question Bank',                   2, 'Reusable questions by subject, topic and difficulty'),
('sms.cbt',               'app-sms', 'Computer Based Testing',          3, 'Online exams with timers, randomisation and auto marking'),
('sms.board-entries',     'app-sms', 'External Exam Board Entries',     3, 'Candidate registration, exports and results for WAEC, Cambridge, Pearson Edexcel, IB, College Board and national boards'),
('sms.predicted-grades',  'app-sms', 'Mock Exams & Predicted Grades',   2, 'Mocks and predicted grades for university applications'),
('sms.admit-cards',       'app-sms', 'Admit Cards',                     1, 'Candidate admit cards with seats and papers'),
('sms.exam-generator',    'app-sms', 'Exam Timetable Generator',        2, 'Papers placed without clashes, invigilators shared out fairly')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id = EXCLUDED.app_id, title = EXCLUDED.title, min_tier_rank = EXCLUDED.min_tier_rank,
    description = EXCLUDED.description, is_active = true;

COMMIT;
