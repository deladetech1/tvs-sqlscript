-- MyEduGuard: fee management and billing.
--
--   sms_fee_settings        a school's rules: invoice and receipt numbering, the default currency,
--                           tax and payment plan, late fees and their grace, reminders, and the
--                           fee clearance rules (what a family cannot open while it owes)
--   sms_fee_items           what is charged: tuition, registration, a deposit (refundable or not),
--                           boarding, transport, books, exams... each taxable or not
--   sms_fee_categories      special categories of student (boarders, international, staff
--                           children...); auto ones are worked out, the rest have members
--   sms_fee_category_members
--   sms_fee_rates           an item's amount for a year: for every student, or a year group, a
--                           class, a category, new or continuing students; the most precise wins
--   sms_fee_discounts       discounts applied automatically: sibling (the second child on), a
--                           category (a staff child), paying early
--   sms_fee_awards          a student's scholarship, bursary or merit award for a year
--   sms_fee_plans           payment plans: an invoice split into scheduled instalments
--   sms_fee_sponsors        companies, embassies and sponsors who pay for some students
--   sms_fee_sponsorships    a student's sponsor for a year, and the share they pay
--   sms_fee_invoices        an invoice to a student's family or their sponsor, in a currency
--                           (with its exchange rate to the school's), and its lines
--   sms_fee_invoice_lines   and instalments (sms_fee_installments)
--   sms_fee_payments        money received (a receipt), or reported by a family for the bursar
--                           to confirm; allocated to invoices (sms_fee_allocations), what is not
--                           allocated is credit on the account
--   sms_fee_adjustments     credit notes, write-offs and refunds
--
-- Taxes are Core Platform's (cp_tax_rates, read through coretax); currencies too (cp_currencies).
-- Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS sms.sms_fee_settings (
    profile_id            text PRIMARY KEY REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    invoice_prefix        text NOT NULL DEFAULT 'INV',
    next_invoice_number   integer NOT NULL DEFAULT 1,
    receipt_prefix        text NOT NULL DEFAULT 'RCT',
    next_receipt_number   integer NOT NULL DEFAULT 1,
    currency              text,
    tax_id                text,
    tax_number            text,
    default_plan_id       text,
    due_days              integer NOT NULL DEFAULT 14,
    late_fee_kind         text NOT NULL DEFAULT 'none',
    late_fee_value        numeric(12,2) NOT NULL DEFAULT 0,
    grace_days            integer NOT NULL DEFAULT 7,
    remind_days_before    integer NOT NULL DEFAULT 3,
    remind_overdue        boolean NOT NULL DEFAULT true,
    clearance_on          boolean NOT NULL DEFAULT false,
    clearance_threshold   numeric(12,2) NOT NULL DEFAULT 0,
    clearance_reports     boolean NOT NULL DEFAULT true,
    pay_instructions      text,
    updated_at            timestamptz NOT NULL DEFAULT now()
);
-- The nationality that is not "international" (for the international category): "Ghanaian", "Ghana".
ALTER TABLE sms.sms_fee_settings ADD COLUMN IF NOT EXISTS home_nationality text;
SELECT sms.widen_check('sms.sms_fee_settings', 'sms_fee_settings_check2', $q$'percent'$q$, $q$CHECK (
    late_fee_kind IN ('none', 'flat', 'percent') AND late_fee_value >= 0 AND grace_days BETWEEN 0 AND 365 AND due_days BETWEEN 0 AND 365
    AND remind_days_before BETWEEN 0 AND 60 AND clearance_threshold >= 0)$q$);

CREATE TABLE IF NOT EXISTS sms.sms_fee_items (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name         text NOT NULL,
    code         text,
    kind         text NOT NULL DEFAULT 'tuition',
    frequency    text NOT NULL DEFAULT 'term',
    refundable   boolean NOT NULL DEFAULT false,
    taxable      boolean NOT NULL DEFAULT false,
    tax_id       text,
    discountable boolean NOT NULL DEFAULT true,
    optional     boolean NOT NULL DEFAULT false,
    sort_order   integer NOT NULL DEFAULT 0,
    archived_at  timestamptz,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_fee_items', 'sms_fee_items_check2', $q$'other'$q$, $q$CHECK (
    kind IN ('tuition', 'registration', 'deposit', 'boarding', 'transport', 'feeding', 'books', 'uniform', 'exam', 'activity', 'ict', 'levy', 'other')
    AND frequency IN ('term', 'year', 'once'))$q$);
CREATE UNIQUE INDEX IF NOT EXISTS sms_fee_items_name_uq ON sms.sms_fee_items (profile_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_fee_categories (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name         text NOT NULL,
    auto_rule    text,
    description  text,
    archived_at  timestamptz,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_fee_categories', 'sms_fee_categories_check2', $q$'international'$q$, $q$CHECK (
    auto_rule IS NULL OR auto_rule IN ('boarders', 'day', 'international', 'local'))$q$);
CREATE UNIQUE INDEX IF NOT EXISTS sms_fee_categories_name_uq ON sms.sms_fee_categories (profile_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_fee_category_members (
    category_id  text NOT NULL REFERENCES sms.sms_fee_categories(id) ON DELETE CASCADE,
    student_id   text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (category_id, student_id)
);

CREATE TABLE IF NOT EXISTS sms.sms_fee_rates (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    item_id        text NOT NULL REFERENCES sms.sms_fee_items(id) ON DELETE CASCADE,
    year_id        text NOT NULL REFERENCES sms.sms_academic_years(id) ON DELETE CASCADE,
    year_group_id  text,
    class_group_id text,
    category_id    text REFERENCES sms.sms_fee_categories(id) ON DELETE CASCADE,
    applies_to     text NOT NULL DEFAULT 'all',
    amount         numeric(12,2) NOT NULL,
    currency       text,
    cdatetime      timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_fee_rates', 'sms_fee_rates_check2', $q$'continuing'$q$, $q$CHECK (applies_to IN ('all', 'new', 'continuing') AND amount >= 0)$q$);
CREATE INDEX IF NOT EXISTS sms_fee_rates_idx ON sms.sms_fee_rates (item_id, year_id);

CREATE TABLE IF NOT EXISTS sms.sms_fee_discounts (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name          text NOT NULL,
    kind          text NOT NULL,
    basis         text NOT NULL DEFAULT 'percent',
    value         numeric(12,2) NOT NULL,
    min_position  integer NOT NULL DEFAULT 2,
    category_id   text REFERENCES sms.sms_fee_categories(id) ON DELETE CASCADE,
    early_days    integer NOT NULL DEFAULT 0,
    item_kinds    text[] NOT NULL DEFAULT '{tuition}',
    active        boolean NOT NULL DEFAULT true,
    archived_at   timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_fee_discounts', 'sms_fee_discounts_check2', $q$'early_payment'$q$, $q$CHECK (
    kind IN ('sibling', 'category', 'early_payment') AND basis IN ('percent', 'amount') AND value >= 0
    AND (basis <> 'percent' OR value <= 100) AND min_position BETWEEN 2 AND 20 AND early_days >= 0)$q$);

CREATE TABLE IF NOT EXISTS sms.sms_fee_awards (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id   text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    year_id      text NOT NULL REFERENCES sms.sms_academic_years(id) ON DELETE CASCADE,
    name         text NOT NULL,
    kind         text NOT NULL DEFAULT 'scholarship',
    basis        text NOT NULL DEFAULT 'percent',
    value        numeric(12,2) NOT NULL,
    item_kinds   text[] NOT NULL DEFAULT '{tuition}',
    note         text,
    awarded_by   text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_fee_awards', 'sms_fee_awards_check2', $q$'bursary'$q$, $q$CHECK (
    kind IN ('scholarship', 'bursary', 'merit', 'other') AND basis IN ('percent', 'amount') AND value >= 0 AND (basis <> 'percent' OR value <= 100))$q$);
CREATE INDEX IF NOT EXISTS sms_fee_awards_idx ON sms.sms_fee_awards (student_id, year_id);

CREATE TABLE IF NOT EXISTS sms.sms_fee_plans (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name         text NOT NULL,
    parts        jsonb NOT NULL,
    archived_at  timestamptz,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sms.sms_fee_sponsors (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name         text NOT NULL,
    kind         text NOT NULL DEFAULT 'company',
    contact_name text,
    email        text,
    phone        text,
    address      text,
    tax_number   text,
    archived_at  timestamptz,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_fee_sponsors', 'sms_fee_sponsors_check2', $q$'embassy'$q$, $q$CHECK (
    kind IN ('company', 'embassy', 'government', 'ngo', 'church', 'individual', 'other'))$q$);

CREATE TABLE IF NOT EXISTS sms.sms_fee_sponsorships (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    sponsor_id   text NOT NULL REFERENCES sms.sms_fee_sponsors(id) ON DELETE CASCADE,
    student_id   text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    year_id      text NOT NULL REFERENCES sms.sms_academic_years(id) ON DELETE CASCADE,
    share_pct    numeric(5,2) NOT NULL DEFAULT 100,
    item_kinds   text[] NOT NULL DEFAULT '{}',
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (student_id, year_id)
);
SELECT sms.widen_check('sms.sms_fee_sponsorships', 'sms_fee_sponsorships_check2', $q$share_pct$q$, $q$CHECK (share_pct > 0 AND share_pct <= 100)$q$);

CREATE TABLE IF NOT EXISTS sms.sms_fee_invoices (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    number          text NOT NULL,
    student_id      text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    sponsor_id      text REFERENCES sms.sms_fee_sponsors(id) ON DELETE SET NULL,
    year_id         text REFERENCES sms.sms_academic_years(id) ON DELETE SET NULL,
    term_id         text,
    kind            text NOT NULL DEFAULT 'fees',
    issued_on       date NOT NULL,
    due_on          date NOT NULL,
    currency        text NOT NULL,
    exchange_rate   numeric(18,6) NOT NULL DEFAULT 1,
    subtotal        numeric(12,2) NOT NULL DEFAULT 0,
    discount_total  numeric(12,2) NOT NULL DEFAULT 0,
    tax_total       numeric(12,2) NOT NULL DEFAULT 0,
    total           numeric(12,2) NOT NULL DEFAULT 0,
    paid            numeric(12,2) NOT NULL DEFAULT 0,
    adjusted        numeric(12,2) NOT NULL DEFAULT 0,
    status          text NOT NULL DEFAULT 'open',
    late_fee_on     date,
    reminded_on     date,
    note            text,
    batch_id        text,
    created_by      text,
    voided_at       timestamptz,
    void_reason     text,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_fee_invoices', 'sms_fee_invoices_check2', $q$'written_off'$q$, $q$CHECK (
    kind IN ('fees', 'registration', 'deposit', 'adhoc') AND status IN ('open', 'part_paid', 'paid', 'void', 'written_off')
    AND due_on >= issued_on AND exchange_rate > 0)$q$);
CREATE UNIQUE INDEX IF NOT EXISTS sms_fee_invoices_number_uq ON sms.sms_fee_invoices (profile_id, number);
CREATE INDEX IF NOT EXISTS sms_fee_invoices_student_idx ON sms.sms_fee_invoices (student_id, issued_on DESC);
CREATE INDEX IF NOT EXISTS sms_fee_invoices_status_idx ON sms.sms_fee_invoices (profile_id, status, due_on);
-- One term's fees for a student (and their sponsor's share) are billed once in each currency.
DROP INDEX IF EXISTS sms.sms_fee_invoices_term_uq;
CREATE UNIQUE INDEX IF NOT EXISTS sms_fee_invoices_term_cur_uq ON sms.sms_fee_invoices (student_id, term_id, coalesce(sponsor_id, ''), currency)
    WHERE kind = 'fees' AND term_id IS NOT NULL AND status <> 'void';

CREATE TABLE IF NOT EXISTS sms.sms_fee_invoice_lines (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    invoice_id       text NOT NULL REFERENCES sms.sms_fee_invoices(id) ON DELETE CASCADE,
    item_id          text REFERENCES sms.sms_fee_items(id) ON DELETE SET NULL,
    kind             text NOT NULL DEFAULT 'other',
    description      text NOT NULL,
    quantity         numeric(10,2) NOT NULL DEFAULT 1,
    unit_amount      numeric(12,2) NOT NULL,
    discount_amount  numeric(12,2) NOT NULL DEFAULT 0,
    discount_note    text,
    tax_id           text,
    tax_name         text,
    tax_rate         numeric(6,3) NOT NULL DEFAULT 0,
    tax_amount       numeric(12,2) NOT NULL DEFAULT 0,
    amount           numeric(12,2) NOT NULL,
    refundable       boolean NOT NULL DEFAULT false,
    late_fee         boolean NOT NULL DEFAULT false,
    sort_order       integer NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS sms_fee_invoice_lines_idx ON sms.sms_fee_invoice_lines (invoice_id, sort_order);

CREATE TABLE IF NOT EXISTS sms.sms_fee_installments (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    invoice_id   text NOT NULL REFERENCES sms.sms_fee_invoices(id) ON DELETE CASCADE,
    seq          integer NOT NULL,
    due_on       date NOT NULL,
    amount       numeric(12,2) NOT NULL,
    reminded_on  date,
    UNIQUE (invoice_id, seq)
);

CREATE TABLE IF NOT EXISTS sms.sms_fee_payments (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    receipt_number  text,
    student_id      text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    sponsor_id      text REFERENCES sms.sms_fee_sponsors(id) ON DELETE SET NULL,
    received_on     date NOT NULL,
    amount          numeric(12,2) NOT NULL,
    currency        text NOT NULL,
    method          text NOT NULL,
    reference       text,
    payer_name      text,
    note            text,
    status          text NOT NULL DEFAULT 'confirmed',
    recorded_by     text,
    confirmed_by    text,
    confirmed_at    timestamptz,
    voided_at       timestamptz,
    void_reason     text,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_fee_payments', 'sms_fee_payments_check2', $q$'wallet'$q$, $q$CHECK (
    method IN ('cash', 'mobile_money', 'bank', 'cheque', 'card', 'wallet', 'credit') AND status IN ('pending', 'confirmed', 'rejected', 'void') AND amount > 0)$q$);
CREATE UNIQUE INDEX IF NOT EXISTS sms_fee_payments_receipt_uq ON sms.sms_fee_payments (profile_id, receipt_number) WHERE receipt_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS sms_fee_payments_student_idx ON sms.sms_fee_payments (student_id, received_on DESC);

CREATE TABLE IF NOT EXISTS sms.sms_fee_allocations (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    payment_id   text NOT NULL REFERENCES sms.sms_fee_payments(id) ON DELETE CASCADE,
    invoice_id   text NOT NULL REFERENCES sms.sms_fee_invoices(id) ON DELETE CASCADE,
    amount       numeric(12,2) NOT NULL,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sms_fee_allocations_invoice_idx ON sms.sms_fee_allocations (invoice_id);
CREATE INDEX IF NOT EXISTS sms_fee_allocations_payment_idx ON sms.sms_fee_allocations (payment_id);

CREATE TABLE IF NOT EXISTS sms.sms_fee_adjustments (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id   text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    invoice_id   text REFERENCES sms.sms_fee_invoices(id) ON DELETE CASCADE,
    kind         text NOT NULL,
    amount       numeric(12,2) NOT NULL,
    currency     text NOT NULL,
    reason       text NOT NULL,
    method       text,
    reference    text,
    by_user      text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_fee_adjustments', 'sms_fee_adjustments_check2', $q$'early_payment'$q$, $q$CHECK (
    kind IN ('credit_note', 'write_off', 'refund', 'early_payment') AND amount > 0)$q$);
CREATE INDEX IF NOT EXISTS sms_fee_adjustments_student_idx ON sms.sms_fee_adjustments (student_id, cdatetime DESC);

-- An allocation puts part of a payment against an invoice, or against a refund paid back out of it.
ALTER TABLE sms.sms_fee_allocations ALTER COLUMN invoice_id DROP NOT NULL;
ALTER TABLE sms.sms_fee_allocations ADD COLUMN IF NOT EXISTS adjustment_id text REFERENCES sms.sms_fee_adjustments(id) ON DELETE CASCADE;
SELECT sms.widen_check('sms.sms_fee_allocations', 'sms_fee_allocations_check2', $q$adjustment_id$q$, $q$CHECK (amount > 0 AND (invoice_id IS NOT NULL) <> (adjustment_id IS NOT NULL))$q$);

-- A student the bursar lets through the fee clearance rules, until a date.
CREATE TABLE IF NOT EXISTS sms.sms_fee_clearances (
    student_id   text PRIMARY KEY REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    until_on     date NOT NULL,
    reason       text NOT NULL,
    by_user      text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);

-- Fees is a module a school can turn off (Settings, Modules).
SELECT sms.widen_check('sms.sms_profiles', 'sms_profiles_modules_check', $q$'fees'$q$, $q$CHECK (modules IS NULL OR (cardinality(modules) > 0 AND modules <@ ARRAY[
    'admissions', 'teaching', 'scheduling', 'attendance', 'grading', 'learning', 'welfare', 'inclusion', 'boarding', 'library', 'activities', 'transport',
    'catering', 'hr', 'fees']::text[]))$q$);

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-fees', 'MyEduGuard Fees', 'Fee structure, billing, payments, discounts, scholarships, sponsors and statements of account', 'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, action, label) AS (VALUES
    ('fees', 'get',      'View fees, invoices, payments, balances and statements of account'),
    ('fees', 'transact', 'Take payments and issue receipts, and confirm the payments families report'),
    ('fees', 'manage',   'Set the fee structure, discounts and scholarships, bill, credit, refund and write off, and keep sponsors')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-sms-' || spec.resource_key || '-' || spec.action,
       'MyEduGuard ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       'rt-sms-fees', spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
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
('role-sms-bursar', 'system-tenant-id', 'MyEduGuard Bursar', 'Runs the school''s fees: the fee structure, billing, payments and receipts, discounts and scholarships, sponsors, credits, refunds and write-offs', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-sms-accounts', 'system-tenant-id', 'MyEduGuard Accounts Clerk', 'Takes fee payments, issues receipts and confirms the payments families report', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
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
    SELECT 'role-sms-bursar', k, a FROM (VALUES ('fees', 'get'), ('fees', 'transact'), ('fees', 'manage'), ('students', 'get'), ('families', 'get'), ('structure', 'get'),
        ('profiles', 'get'), ('catering', 'get'), ('transport', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-accounts', k, a FROM (VALUES ('fees', 'get'), ('fees', 'transact'), ('students', 'get'), ('families', 'get'), ('structure', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-registrar', k, a FROM (VALUES ('fees', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-viewer', 'fees', 'get'
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'sms' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', r.id, p.id
  FROM core_platform.cp_permissions p CROSS JOIN (VALUES ('role-sms-bursar'), ('role-sms-accounts')) AS r(id)
 WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.fee-structure',   'app-sms', 'Advanced Fee Configuration',     1, 'Fees per item, class and student status, plus scholarships and special categories'),
('sms.billing',         'app-sms', 'Batch & Individual Billing',     1, 'Custom billable items, full or partial payments and arrears management'),
('sms.fee-discounts',   'app-sms', 'Discounts & Scholarships',       2, 'Sibling, staff child, early payment and merit discounts applied automatically'),
('sms.installments',    'app-sms', 'Installment & Payment Plans',    2, 'Split fees into scheduled installments with reminders'),
('sms.fee-adjustments', 'app-sms', 'Fee Credits, Refunds & Write-offs', 1, 'Credits, refunds, write offs and statements of account'),
('sms.late-fees',       'app-sms', 'Late Payment Penalties',         2, 'Configurable late fees and grace periods'),
('sms.deposits',        'app-sms', 'Deposits & Registration Fees',   1, 'Admission deposits and refundable deposits'),
('sms.sponsors',        'app-sms', 'Sponsor & Third Party Billing',  3, 'Bill companies, embassies or sponsors for some students'),
('sms.fee-clearance',   'app-sms', 'Fee Clearance Rules',            2, 'Optional rules linking fee status to services such as report downloads'),
('sms.multi-currency',  'app-sms', 'Multi Currency Billing',         3, 'Bill in local and foreign currencies with exchange rates'),
('sms.fee-tax',         'app-sms', 'Tax & VAT on Fees',              2, 'Apply VAT or GST where applicable and issue tax invoices')
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
                WHERE rp.role_id IN ('role-sms-bursar', 'role-sms-accounts') AND p.app_prefix = 'sms' AND p.resource_key IN ('counselling', 'safeguarding', 'hr')) THEN
        RAISE EXCEPTION 'counselling, safeguarding and staff records are not the bursar''s';
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
