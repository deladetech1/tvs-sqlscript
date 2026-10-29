-- MyEduGuard 12: library and learning resources -- the physical and the digital library.
--
--   sms_library_settings      each school's rules: loan periods, how many at once, renewals, how
--                             long a hold waits, the daily fine and its cap, when reminders go
--   sms_library_titles        the catalogue: books, e-books and media, by ISBN, with the subject a
--                             textbook is for and what a lost copy costs
--   sms_library_copies        each physical copy with its barcode, condition and where it is
--   sms_library_loans         issued and returned; kind 'textbook' is a term's textbook rental,
--                             due back when the term ends
--   sms_library_reservations  holds on a title: waiting, then ready (a returned copy kept aside)
--   sms_library_fines         charges on a student's account: overdue days, a lost or damaged
--                             copy; paid at the desk or from the boarding wallet, or waived
--   sms_library_alerts        reminders sent (due soon, overdue, a hold ready): each once
--   sms_library_resources     the digital library: e-book platforms, databases and sites
--
-- A loan, reservation or fine is a student's or a member of staff's (user_id), never both.
-- Permissions sms|library|get/transact/manage; the role MyEduGuard Librarian. Idempotent.

BEGIN;

CREATE TABLE IF NOT EXISTS sms.sms_library_settings (
    profile_id          text PRIMARY KEY REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    loan_days           integer NOT NULL DEFAULT 14,
    staff_loan_days     integer NOT NULL DEFAULT 28,
    max_loans           integer NOT NULL DEFAULT 3,
    staff_max_loans     integer NOT NULL DEFAULT 10,
    max_renewals        integer NOT NULL DEFAULT 2,
    hold_days           integer NOT NULL DEFAULT 3,
    fine_per_day        numeric(10,2) NOT NULL DEFAULT 0,
    fine_cap            numeric(10,2),
    grace_days          integer NOT NULL DEFAULT 0,
    block_over          numeric(10,2),
    remind_before_days  integer NOT NULL DEFAULT 2,
    remind_every_days   integer NOT NULL DEFAULT 7,
    notify_sms          boolean NOT NULL DEFAULT true,
    notify_email        boolean NOT NULL DEFAULT true,
    barcode_prefix      text NOT NULL DEFAULT 'LIB',
    next_barcode        integer NOT NULL DEFAULT 1,
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CHECK (loan_days BETWEEN 1 AND 365 AND staff_loan_days BETWEEN 1 AND 365 AND max_loans BETWEEN 1 AND 50 AND staff_max_loans BETWEEN 1 AND 100
           AND max_renewals BETWEEN 0 AND 20 AND hold_days BETWEEN 1 AND 30 AND fine_per_day >= 0 AND (fine_cap IS NULL OR fine_cap >= 0)
           AND grace_days BETWEEN 0 AND 30 AND remind_before_days BETWEEN 0 AND 14 AND remind_every_days BETWEEN 1 AND 60)
);

CREATE TABLE IF NOT EXISTS sms.sms_library_titles (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    profile_id        text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    kind              text NOT NULL DEFAULT 'book',
    title             text NOT NULL,
    subtitle          text,
    authors           text,
    isbn              text,
    publisher         text,
    published_year    integer,
    edition           text,
    language          text,
    keywords          text,
    call_number       text,
    description       text,
    cover_url         text,
    digital_url       text,
    is_textbook       boolean NOT NULL DEFAULT false,
    subject_id        text REFERENCES sms.sms_subjects(id) ON DELETE SET NULL,
    replacement_cost  numeric(10,2),
    created_by        text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    archived_at       timestamptz,
    CHECK (published_year IS NULL OR published_year BETWEEN 1400 AND 2200),
    CHECK (replacement_cost IS NULL OR replacement_cost >= 0)
);
ALTER TABLE sms.sms_library_titles DROP CONSTRAINT IF EXISTS sms_library_titles_kind_check;
ALTER TABLE sms.sms_library_titles ADD CONSTRAINT sms_library_titles_kind_check
    CHECK (kind IN ('book', 'ebook', 'audiobook', 'magazine', 'journal', 'dvd', 'map', 'kit', 'other'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_library_titles_isbn_uq ON sms.sms_library_titles (profile_id, isbn) WHERE isbn IS NOT NULL AND archived_at IS NULL;
CREATE INDEX IF NOT EXISTS sms_library_titles_idx ON sms.sms_library_titles (profile_id, lower(title)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_library_copies (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    title_id     text NOT NULL REFERENCES sms.sms_library_titles(id) ON DELETE CASCADE,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    barcode      text NOT NULL,
    condition    text NOT NULL DEFAULT 'good',
    status       text NOT NULL DEFAULT 'available',
    location     text,
    acquired_on  date,
    price        numeric(10,2),
    note         text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    CHECK (price IS NULL OR price >= 0)
);
ALTER TABLE sms.sms_library_copies DROP CONSTRAINT IF EXISTS sms_library_copies_check2;
ALTER TABLE sms.sms_library_copies ADD CONSTRAINT sms_library_copies_check2
    CHECK (condition IN ('new', 'good', 'fair', 'poor', 'damaged') AND status IN ('available', 'on_loan', 'on_hold', 'lost', 'missing', 'repair', 'withdrawn'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_library_copies_barcode_uq ON sms.sms_library_copies (profile_id, upper(barcode));
CREATE INDEX IF NOT EXISTS sms_library_copies_title_idx ON sms.sms_library_copies (title_id);

CREATE TABLE IF NOT EXISTS sms.sms_library_loans (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    profile_id     text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    copy_id        text NOT NULL REFERENCES sms.sms_library_copies(id) ON DELETE CASCADE,
    title_id       text NOT NULL REFERENCES sms.sms_library_titles(id) ON DELETE CASCADE,
    student_id     text REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    user_id        text,
    kind           text NOT NULL DEFAULT 'loan',
    term_id        text REFERENCES sms.sms_terms(id) ON DELETE SET NULL,
    status         text NOT NULL DEFAULT 'open',
    issued_at      timestamptz NOT NULL DEFAULT now(),
    due_on         date NOT NULL,
    renewals       integer NOT NULL DEFAULT 0,
    returned_at    timestamptz,
    condition_out  text,
    condition_in   text,
    issued_by      text,
    returned_by    text,
    note           text,
    CHECK ((student_id IS NULL) <> (user_id IS NULL))
);
ALTER TABLE sms.sms_library_loans DROP CONSTRAINT IF EXISTS sms_library_loans_check2;
ALTER TABLE sms.sms_library_loans ADD CONSTRAINT sms_library_loans_check2
    CHECK (kind IN ('loan', 'textbook') AND status IN ('open', 'returned', 'lost'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_library_loans_open_copy ON sms.sms_library_loans (copy_id) WHERE status = 'open';
CREATE INDEX IF NOT EXISTS sms_library_loans_idx ON sms.sms_library_loans (profile_id, status, due_on);
CREATE INDEX IF NOT EXISTS sms_library_loans_student_idx ON sms.sms_library_loans (student_id, issued_at DESC) WHERE student_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS sms_library_loans_user_idx ON sms.sms_library_loans (user_id, issued_at DESC) WHERE user_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS sms.sms_library_reservations (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    title_id    text NOT NULL REFERENCES sms.sms_library_titles(id) ON DELETE CASCADE,
    student_id  text REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    user_id     text,
    status      text NOT NULL DEFAULT 'waiting',
    copy_id     text REFERENCES sms.sms_library_copies(id) ON DELETE SET NULL,
    placed_at   timestamptz NOT NULL DEFAULT now(),
    placed_by   text,
    ready_at    timestamptz,
    hold_until  date,
    closed_at   timestamptz,
    CHECK ((student_id IS NULL) <> (user_id IS NULL))
);
ALTER TABLE sms.sms_library_reservations DROP CONSTRAINT IF EXISTS sms_library_reservations_status_check;
ALTER TABLE sms.sms_library_reservations ADD CONSTRAINT sms_library_reservations_status_check
    CHECK (status IN ('waiting', 'ready', 'fulfilled', 'cancelled', 'expired'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_library_reservations_student_uq ON sms.sms_library_reservations (title_id, student_id)
    WHERE student_id IS NOT NULL AND status IN ('waiting', 'ready');
CREATE UNIQUE INDEX IF NOT EXISTS sms_library_reservations_user_uq ON sms.sms_library_reservations (title_id, user_id)
    WHERE user_id IS NOT NULL AND status IN ('waiting', 'ready');
CREATE INDEX IF NOT EXISTS sms_library_reservations_idx ON sms.sms_library_reservations (profile_id, status, placed_at);

CREATE TABLE IF NOT EXISTS sms.sms_library_fines (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id    text REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    user_id       text,
    loan_id       text REFERENCES sms.sms_library_loans(id) ON DELETE SET NULL,
    kind          text NOT NULL,
    amount        numeric(10,2) NOT NULL,
    days_late     integer,
    note          text,
    status        text NOT NULL DEFAULT 'unpaid',
    paid_at       timestamptz,
    paid_method   text,
    reference     text,
    settled_by    text,
    waive_reason  text,
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    CHECK (amount > 0),
    CHECK ((student_id IS NULL) <> (user_id IS NULL))
);
ALTER TABLE sms.sms_library_fines DROP CONSTRAINT IF EXISTS sms_library_fines_check2;
ALTER TABLE sms.sms_library_fines ADD CONSTRAINT sms_library_fines_check2
    CHECK (kind IN ('overdue', 'lost', 'damage', 'other') AND status IN ('unpaid', 'paid', 'waived')
           AND (paid_method IS NULL OR paid_method IN ('cash', 'mobile_money', 'bank', 'card', 'cheque', 'wallet')));
CREATE UNIQUE INDEX IF NOT EXISTS sms_library_fines_once ON sms.sms_library_fines (loan_id, kind) WHERE loan_id IS NOT NULL AND kind IN ('overdue', 'lost');
CREATE INDEX IF NOT EXISTS sms_library_fines_idx ON sms.sms_library_fines (profile_id, status, cdatetime DESC);
CREATE INDEX IF NOT EXISTS sms_library_fines_student_idx ON sms.sms_library_fines (student_id) WHERE student_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS sms.sms_library_alerts (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    ref_id      text NOT NULL,
    kind        text NOT NULL,
    alert_on    date NOT NULL,
    channel     text NOT NULL,
    to_address  text,
    body        text NOT NULL,
    status      text NOT NULL DEFAULT 'queued',
    error       text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (ref_id, kind, alert_on, channel)
);
ALTER TABLE sms.sms_library_alerts DROP CONSTRAINT IF EXISTS sms_library_alerts_check2;
ALTER TABLE sms.sms_library_alerts ADD CONSTRAINT sms_library_alerts_check2
    CHECK (kind IN ('due_soon', 'overdue', 'hold_ready') AND channel IN ('sms', 'email', 'portal') AND status IN ('queued', 'sent', 'failed'));
CREATE INDEX IF NOT EXISTS sms_library_alerts_idx ON sms.sms_library_alerts (profile_id, cdatetime DESC);

CREATE TABLE IF NOT EXISTS sms.sms_library_resources (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name            text NOT NULL,
    kind            text NOT NULL DEFAULT 'website',
    url             text NOT NULL,
    description     text,
    how_to_access   text,
    audience        text NOT NULL DEFAULT 'everyone',
    year_group_ids  text[] NOT NULL DEFAULT '{}',
    subject_id      text REFERENCES sms.sms_subjects(id) ON DELETE SET NULL,
    sort_order      integer NOT NULL DEFAULT 0,
    created_by      text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    archived_at     timestamptz
);
ALTER TABLE sms.sms_library_resources DROP CONSTRAINT IF EXISTS sms_library_resources_check2;
ALTER TABLE sms.sms_library_resources ADD CONSTRAINT sms_library_resources_check2
    CHECK (kind IN ('ebook_platform', 'database', 'website', 'video', 'audio', 'other') AND audience IN ('everyone', 'students', 'staff'));
CREATE INDEX IF NOT EXISTS sms_library_resources_idx ON sms.sms_library_resources (profile_id, sort_order) WHERE archived_at IS NULL;

-- The library is a module a school can turn off (Settings, Modules).
SELECT sms.widen_check('sms.sms_profiles', 'sms_profiles_modules_check', $q$'library'$q$, $q$CHECK (modules IS NULL OR (cardinality(modules) > 0 AND modules <@ ARRAY[
    'admissions', 'teaching', 'scheduling', 'attendance', 'grading', 'learning', 'welfare', 'inclusion', 'boarding', 'library']::text[]))$q$);

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-library', 'MyEduGuard Library', 'The catalogue and copies, loans, reservations, fines, textbook rental and the digital library', 'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, action, label) AS (VALUES
    ('library', 'get',      'View the library catalogue, loans, reservations, fines and the digital library'),
    ('library', 'transact', 'Issue, return and renew items, place and cancel reservations, issue and recover textbooks, and take fine payments'),
    ('library', 'manage',   'Keep the catalogue and copies, set the library''s rules, waive fines and keep the digital library')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-sms-' || spec.resource_key || '-' || spec.action,
       'MyEduGuard ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       'rt-sms-library', spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
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
('role-sms-librarian', 'system-tenant-id', 'MyEduGuard Librarian', 'Runs the library: the catalogue and copies, the desk, reservations, fines, textbook rental and the digital library', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
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
    SELECT 'role-sms-librarian', k, a FROM (VALUES ('library', 'get'), ('library', 'transact'), ('library', 'manage'), ('students', 'get'), ('structure', 'get'),
        ('profiles', 'get'), ('curriculum', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-teacher', k, a FROM (VALUES ('library', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-registrar', k, a FROM (VALUES ('library', 'get')) AS g(k, a)
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
SELECT 'system-tenant-id', 'role-sms-librarian', p.id
  FROM core_platform.cp_permissions p
 WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.library-catalogue',   'app-sms', 'Library Catalogue',            1, 'Books, e-books and media with ISBN lookup and barcodes'),
('sms.library-circulation', 'app-sms', 'Library Circulation',          1, 'Issue, return, renew and reserve items'),
('sms.library-fines',       'app-sms', 'Fines & Overdue Alerts',       2, 'Automatic reminders and fine billing to student accounts'),
('sms.textbook-rental',     'app-sms', 'Textbook Rental',              2, 'Issue and recover textbooks per term'),
('sms.digital-library',     'app-sms', 'Digital Library Integration',  2, 'Links to e-book platforms and online resources')
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
                WHERE rp.role_id = 'role-sms-librarian' AND p.app_prefix = 'sms' AND p.resource_key IN ('counselling', 'safeguarding')) THEN
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
