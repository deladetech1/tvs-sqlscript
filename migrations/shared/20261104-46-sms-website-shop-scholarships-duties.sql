-- MyEduGuard: the school's website, uniform and book orders, scholarships and bursaries, and the
-- staff duty roster.
--
--   sms_website              the school's public site: its theme, the front page, what it shows
--   sms_website_pages        its pages (about, academics, admissions, contact...)
--   sms_website_posts        its news
--   sms_shop_orders          families' orders from the school shop (uniform, books, stationery),
--   sms_shop_order_lines     collected at the shop and paid there or put on the fee account
--   sms_scholarship_schemes  scholarships and bursaries the school offers, open for applications,
--   sms_scholarship_applications  and families' applications to them, scored and decided; an
--                            award becomes the student's fee award
--   sms_duties               the duties staff share (gate, dining hall, prep, assembly, break),
--   sms_duty_assignments     and who is on each, day by day
--
-- Certificates and testimonials are issued documents (kind 'certificate'); lesson note vetting and
-- continuous assessment sheets keep nothing of their own.
-- Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS sms.sms_website (
    profile_id     text PRIMARY KEY REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    published      boolean NOT NULL DEFAULT false,
    theme          text NOT NULL DEFAULT 'classic',
    tagline        text,
    hero_title     text,
    hero_text      text,
    welcome        text,
    show_news      boolean NOT NULL DEFAULT true,
    show_calendar  boolean NOT NULL DEFAULT true,
    show_admissions boolean NOT NULL DEFAULT true,
    socials        jsonb NOT NULL DEFAULT '{}',
    updated_at     timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_website', 'sms_website_theme_check', $q$'bold'$q$, $q$CHECK (theme IN ('classic', 'modern', 'bold'))$q$);

CREATE TABLE IF NOT EXISTS sms.sms_website_pages (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    slug        text NOT NULL,
    title       text NOT NULL,
    body        text NOT NULL DEFAULT '',
    sort_order  integer NOT NULL DEFAULT 0,
    in_menu     boolean NOT NULL DEFAULT true,
    published   boolean NOT NULL DEFAULT true,
    updated_at  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (profile_id, slug)
);

CREATE TABLE IF NOT EXISTS sms.sms_website_posts (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    slug          text NOT NULL,
    title         text NOT NULL,
    excerpt       text,
    body          text NOT NULL DEFAULT '',
    status        text NOT NULL DEFAULT 'draft',
    published_at  timestamptz,
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    UNIQUE (profile_id, slug)
);
SELECT sms.widen_check('sms.sms_website_posts', 'sms_website_posts_status_check', $q$'published'$q$, $q$CHECK (status IN ('draft', 'published'))$q$);

CREATE TABLE IF NOT EXISTS sms.sms_shop_orders (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    number      text NOT NULL,
    family_id   text NOT NULL REFERENCES sms.sms_families(id) ON DELETE CASCADE,
    student_id  text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    status      text NOT NULL DEFAULT 'placed',
    pay         text NOT NULL DEFAULT 'collection',
    total       numeric(12,2) NOT NULL DEFAULT 0,
    note        text,
    sale_id     text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_shop_orders', 'sms_shop_orders_check', $q$'cancelled'$q$, $q$CHECK (
    status IN ('placed', 'ready', 'collected', 'cancelled') AND pay IN ('collection', 'account'))$q$);
CREATE UNIQUE INDEX IF NOT EXISTS sms_shop_orders_number_uq ON sms.sms_shop_orders (profile_id, number);

CREATE TABLE IF NOT EXISTS sms.sms_shop_order_lines (
    id        text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    order_id  text NOT NULL REFERENCES sms.sms_shop_orders(id) ON DELETE CASCADE,
    item_id   text REFERENCES sms.sms_proc_items(id) ON DELETE SET NULL,
    name      text NOT NULL,
    qty       numeric(10,2) NOT NULL,
    price     numeric(12,2) NOT NULL,
    size      text,
    CHECK (qty > 0 AND price >= 0)
);

CREATE TABLE IF NOT EXISTS sms.sms_scholarship_schemes (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name         text NOT NULL,
    description  text,
    kind         text NOT NULL DEFAULT 'scholarship',
    basis        text NOT NULL DEFAULT 'percent',
    value        numeric(12,2) NOT NULL,
    opens_on     date,
    closes_on    date,
    places       integer,
    criteria     text,
    status       text NOT NULL DEFAULT 'open',
    created_by   text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_scholarship_schemes', 'sms_scholarship_schemes_check', $q$'closed'$q$, $q$CHECK (
    kind IN ('scholarship', 'bursary', 'merit', 'other') AND basis IN ('percent', 'amount') AND value > 0 AND (basis <> 'percent' OR value <= 100)
    AND status IN ('open', 'closed'))$q$);

CREATE TABLE IF NOT EXISTS sms.sms_scholarship_applications (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    scheme_id         text NOT NULL REFERENCES sms.sms_scholarship_schemes(id) ON DELETE CASCADE,
    student_id        text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    family_id         text NOT NULL REFERENCES sms.sms_families(id) ON DELETE CASCADE,
    statement         text NOT NULL,
    household_income  numeric(14,2),
    dependants        integer,
    status            text NOT NULL DEFAULT 'submitted',
    score             numeric(5,1),
    review_note       text,
    award_id          text REFERENCES sms.sms_fee_awards(id) ON DELETE SET NULL,
    reviewed_by       text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    UNIQUE (scheme_id, student_id)
);
SELECT sms.widen_check('sms.sms_scholarship_applications', 'sms_scholarship_applications_check', $q$'declined'$q$, $q$CHECK (
    status IN ('submitted', 'shortlisted', 'awarded', 'declined') AND (score IS NULL OR score BETWEEN 0 AND 100))$q$);

CREATE TABLE IF NOT EXISTS sms.sms_duties (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name          text NOT NULL,
    place         text,
    weekdays      integer[] NOT NULL DEFAULT '{1,2,3,4,5}',
    starts_at     time NOT NULL,
    ends_at       time NOT NULL,
    staff_needed  integer NOT NULL DEFAULT 1,
    category      text NOT NULL DEFAULT 'any',
    active        boolean NOT NULL DEFAULT true,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    CHECK (ends_at > starts_at)
);
SELECT sms.widen_check('sms.sms_duties', 'sms_duties_check', $q$'non_teaching'$q$, $q$CHECK (staff_needed BETWEEN 1 AND 50 AND category IN ('any', 'teaching', 'non_teaching'))$q$);

CREATE TABLE IF NOT EXISTS sms.sms_duty_assignments (
    id        text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    duty_id   text NOT NULL REFERENCES sms.sms_duties(id) ON DELETE CASCADE,
    on_date   date NOT NULL,
    staff_id  text NOT NULL REFERENCES sms.sms_staff(id) ON DELETE CASCADE,
    status    text NOT NULL DEFAULT 'assigned',
    note      text,
    UNIQUE (duty_id, on_date, staff_id)
);
SELECT sms.widen_check('sms.sms_duty_assignments', 'sms_duty_assignments_status_check', $q$'missed'$q$, $q$CHECK (status IN ('assigned', 'done', 'missed'))$q$);
CREATE INDEX IF NOT EXISTS sms_duty_assignments_day_idx ON sms.sms_duty_assignments (on_date, staff_id);

-- The website's pictures and scholarship applications' documents.
SELECT sms.widen_check('sms.sms_files', 'sms_files_entity_check', $q$'scholarship_application'$q$, $q$CHECK (entity_type IS NULL OR entity_type IN
    ('profile', 'application', 'enquiry', 'family', 'guardian', 'student', 'leave_request', 'assignment', 'submission', 'class_resource', 'pickup_person', 'incident',
     'safeguarding', 'achievement', 'service_hours', 'trip', 'staff', 'staff_document', 'staff_check', 'job_application', 'staff_leave', 'payslip',
     'staff_cpd', 'gl_expense', 'gl_asset', 'maintenance', 'hs_record', 'newsletter', 'announcement', 'data_request', 'website', 'scholarship_application'))$q$);

INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.school-website',  'app-sms', 'School Website',                 2, 'The school''s own site: pages, news, the calendar and admissions'),
('sms.lesson-vetting',  'app-sms', 'Lesson Notes Vetting',           1, 'Lesson notes submitted each week and vetted by heads of department'),
('sms.sba-sheets',      'app-sms', 'Continuous Assessment Sheets',   1, 'Class score and exam score sheets in the national format (GES SBA)'),
('sms.certificates',    'app-sms', 'Certificates & Testimonials',    1, 'Leaving certificates, testimonials and letters, checkable by their QR code'),
('sms.online-orders',   'app-sms', 'Uniform & Book Orders',          2, 'Families order from the school shop online'),
('sms.scholarships',    'app-sms', 'Scholarships & Bursaries',       2, 'Applications, scoring and awards that reduce fees'),
('sms.duty-roster',     'app-sms', 'Staff Duty Roster',              2, 'Gate, dining hall, prep and break duties shared out fairly')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id = EXCLUDED.app_id, title = EXCLUDED.title, min_tier_rank = EXCLUDED.min_tier_rank,
    description = EXCLUDED.description, is_active = true;

-- Drafted report comments were taken out (2026-11-04).
UPDATE core_platform.cp_app_feature_catalog SET is_active = false WHERE feature_key = 'sms.ai-comments';

COMMIT;
