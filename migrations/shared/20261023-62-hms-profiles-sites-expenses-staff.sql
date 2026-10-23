-- HMS: profiles, websites, online payments, expenses, staff, extras, vouchers and tables.
--
--   hms_profiles             a business can run more than one operation (a resort and a town
--                            restaurant): each profile has its own kinds, modules and Core
--                            Platform locations, and its own properties -- so its bookings,
--                            orders, leases and stock start empty. hms_in_scope() is how
--                            every list is narrowed to one profile.
--   hms_sites                the public page of a property (hotel, restaurant): its template,
--                            words, what it shows, and whether people can book, order and pay
--   hms_expense_categories,
--   hms_expenses             money going out: what for, from where, by whom, the receipt,
--                            approved or not
--   hms_departments,
--   hms_staff                the people who work here (Core Platform users) and their jobs
--   hms_time_entries         clocking in and out
--   hms_leave_requests       time off, asked for and decided
--   hms_addons,
--   hms_reservation_addons   extras sold with a stay: breakfast, airport pick-up, late check-out
--   hms_vouchers,
--   hms_voucher_uses         gift vouchers sold, and spent on bills and orders
--   hms_table_bookings       restaurant table reservations and the waitlist
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

-- =================================================================== profiles
CREATE TABLE IF NOT EXISTS hms.hms_profiles (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    name            text NOT NULL,
    business_type   text NOT NULL,
    business_types  text[] NOT NULL DEFAULT '{}',
    modules         text[] NOT NULL DEFAULT '{}',
    location_ids    text[] NOT NULL DEFAULT '{}',
    is_default      boolean NOT NULL DEFAULT false,
    archived_at     timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_profiles_default_uq ON hms.hms_profiles (bus_id) WHERE is_default;
CREATE UNIQUE INDEX IF NOT EXISTS hms_profiles_name_uq ON hms.hms_profiles (bus_id, lower(name)) WHERE archived_at IS NULL;

ALTER TABLE hms.hms_properties ADD COLUMN IF NOT EXISTS profile_id text REFERENCES hms.hms_profiles (id);

-- Every onboarded business has its first profile, from its settings, holding its properties.
INSERT INTO hms.hms_profiles (tenant_id, bus_id, name, business_type, business_types, modules, is_default)
SELECT s.tenant_id, s.bus_id, coalesce(nullif(b.bus_name, ''), 'Main'), s.business_type,
       CASE WHEN cardinality(s.business_types) > 0 THEN s.business_types ELSE ARRAY[s.business_type] END, s.modules, true
  FROM hms.hms_settings s LEFT JOIN core_platform.cp_businesses b ON b.id = s.bus_id
 WHERE s.business_type IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM hms.hms_profiles p WHERE p.bus_id = s.bus_id AND p.is_default);
UPDATE hms.hms_properties pr SET profile_id = p.id
  FROM hms.hms_profiles p WHERE p.bus_id = pr.bus_id AND p.is_default AND pr.profile_id IS NULL;
CREATE INDEX IF NOT EXISTS hms_properties_profile_idx ON hms.hms_properties (profile_id);

-- A list's property filter: one property, every property of a profile ('profile:<id>'), or all.
CREATE OR REPLACE FUNCTION hms.hms_in_scope(prop text, sel text) RETURNS boolean
LANGUAGE sql STABLE AS $$
    SELECT coalesce(sel, '') = ''
        OR prop = sel
        OR (left(sel, 8) = 'profile:' AND EXISTS (SELECT 1 FROM hms.hms_properties p WHERE p.id = prop AND p.profile_id = substr(sel, 9)))
$$;

-- ================================================================== websites
CREATE TABLE IF NOT EXISTS hms.hms_sites (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    property_id     text NOT NULL REFERENCES hms.hms_properties (id),
    slug            text NOT NULL,
    template        text NOT NULL DEFAULT 'classic',
    accent          text NOT NULL DEFAULT '#0f766e',
    headline        text,
    tagline         text,
    about           text,
    show_rooms      boolean NOT NULL DEFAULT true,
    show_menu       boolean NOT NULL DEFAULT true,
    show_activities boolean NOT NULL DEFAULT true,
    show_events     boolean NOT NULL DEFAULT true,
    show_vouchers   boolean NOT NULL DEFAULT true,
    accept_orders   boolean NOT NULL DEFAULT false,
    accept_tables   boolean NOT NULL DEFAULT true,
    whatsapp        text,
    instagram       text,
    facebook        text,
    map_url         text,
    published       boolean NOT NULL DEFAULT false,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hms.hms_sites DROP CONSTRAINT IF EXISTS hms_sites_template_check;
ALTER TABLE hms.hms_sites ADD CONSTRAINT hms_sites_template_check CHECK (template IN ('classic', 'modern', 'minimal', 'bistro', 'resort'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_sites_property_uq ON hms.hms_sites (property_id);
CREATE UNIQUE INDEX IF NOT EXISTS hms_sites_slug_uq ON hms.hms_sites (lower(slug));

-- A table's QR code opens its menu for ordering from the table.
ALTER TABLE hms.hms_tables ADD COLUMN IF NOT EXISTS qr_token text;
CREATE UNIQUE INDEX IF NOT EXISTS hms_tables_qr_uq ON hms.hms_tables (qr_token) WHERE qr_token IS NOT NULL;
-- Orders placed from the website or a table's QR code.
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'pos';
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS customer_phone text;
ALTER TABLE hms.hms_orders ADD COLUMN IF NOT EXISTS public_token text;
CREATE UNIQUE INDEX IF NOT EXISTS hms_orders_public_uq ON hms.hms_orders (public_token) WHERE public_token IS NOT NULL;

-- Online payments for orders and vouchers too, and who started one from the desk.
ALTER TABLE hms.hms_payment_attempts DROP CONSTRAINT IF EXISTS hms_payment_attempts_subject_check;
ALTER TABLE hms.hms_payment_attempts ADD CONSTRAINT hms_payment_attempts_subject_check
    CHECK (subject_type IN ('lease', 'folio', 'reservation', 'order', 'voucher'));
ALTER TABLE hms.hms_payment_attempts ADD COLUMN IF NOT EXISTS started_by text;
ALTER TABLE hms.hms_payment_attempts ADD COLUMN IF NOT EXISTS checkout_url text;
ALTER TABLE hms.hms_payment_attempts ADD COLUMN IF NOT EXISTS email text;

-- A voucher is a way to pay; an extra is a charge of its own kind.
ALTER TABLE hms.hms_folio_lines DROP CONSTRAINT IF EXISTS hms_folio_lines_method_check;
ALTER TABLE hms.hms_folio_lines ADD CONSTRAINT hms_folio_lines_method_check
    CHECK (method IS NULL OR method IN ('cash', 'card', 'momo', 'bank', 'cheque', 'voucher', 'other'));
ALTER TABLE hms.hms_folio_lines DROP CONSTRAINT IF EXISTS hms_folio_lines_category_check;
ALTER TABLE hms.hms_folio_lines ADD CONSTRAINT hms_folio_lines_category_check CHECK (category IN
    ('room', 'restaurant', 'bar', 'minibar', 'laundry', 'service', 'damage', 'late_checkout', 'early_checkin',
     'tax', 'deposit', 'payment', 'refund', 'activity', 'event', 'discount', 'extra', 'other'));
ALTER TABLE hms.hms_order_payments DROP CONSTRAINT IF EXISTS hms_order_payments_method_check;
ALTER TABLE hms.hms_order_payments ADD CONSTRAINT hms_order_payments_method_check
    CHECK (method IN ('cash', 'card', 'momo', 'bank', 'voucher', 'other', 'room', 'company'));

-- ================================================================== expenses
CREATE TABLE IF NOT EXISTS hms.hms_expense_categories (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    name          text NOT NULL,
    department    text NOT NULL DEFAULT 'other',
    monthly_budget numeric(14,2),
    archived_at   timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hms.hms_expense_categories DROP CONSTRAINT IF EXISTS hms_expense_categories_department_check;
ALTER TABLE hms.hms_expense_categories ADD CONSTRAINT hms_expense_categories_department_check CHECK (department IN
    ('rooms', 'food_beverage', 'housekeeping', 'maintenance', 'rentals', 'activities_events', 'admin', 'marketing', 'utilities', 'payroll', 'other'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_expense_categories_name_uq ON hms.hms_expense_categories (bus_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS hms.hms_expenses (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    org_id          text,
    bus_id          text NOT NULL,
    property_id     text REFERENCES hms.hms_properties (id),
    category_id     text REFERENCES hms.hms_expense_categories (id),
    spent_on        date NOT NULL,
    amount          numeric(14,2) NOT NULL CHECK (amount > 0),
    paid_from       text NOT NULL DEFAULT 'cash',
    used_by         text,
    supplier_id     text,
    description     text NOT NULL,
    reference       text,
    status          text NOT NULL DEFAULT 'pending',
    decided_by      text,
    decided_at      timestamptz,
    reject_reason   text,
    cash_session_id text REFERENCES hms.hms_cash_sessions (id),
    voided_at       timestamptz,
    void_reason     text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
ALTER TABLE hms.hms_expenses DROP CONSTRAINT IF EXISTS hms_expenses_paid_from_check;
ALTER TABLE hms.hms_expenses ADD CONSTRAINT hms_expenses_paid_from_check CHECK (paid_from IN ('cash', 'petty_cash', 'bank', 'momo', 'card', 'cheque', 'owner', 'other'));
ALTER TABLE hms.hms_expenses DROP CONSTRAINT IF EXISTS hms_expenses_status_check;
ALTER TABLE hms.hms_expenses ADD CONSTRAINT hms_expenses_status_check CHECK (status IN ('pending', 'approved', 'rejected'));
CREATE INDEX IF NOT EXISTS hms_expenses_bus_idx ON hms.hms_expenses (bus_id, spent_on DESC);

-- ===================================================================== staff
CREATE TABLE IF NOT EXISTS hms.hms_departments (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    name          text NOT NULL,
    head_user_id  text,
    archived_at   timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_departments_name_uq ON hms.hms_departments (bus_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS hms.hms_staff (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    bus_id             text NOT NULL,
    user_id            text NOT NULL,
    department_id      text REFERENCES hms.hms_departments (id),
    property_id        text REFERENCES hms.hms_properties (id),
    job_title          text,
    employment_type    text NOT NULL DEFAULT 'full_time',
    pay_rate           numeric(14,2),
    pay_period         text NOT NULL DEFAULT 'month',
    phone              text,
    emergency_contact  text,
    started_on         date,
    active             boolean NOT NULL DEFAULT true,
    notes              text,
    archived_at        timestamptz,
    cdatetime          timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hms.hms_staff DROP CONSTRAINT IF EXISTS hms_staff_employment_check;
ALTER TABLE hms.hms_staff ADD CONSTRAINT hms_staff_employment_check CHECK (employment_type IN ('full_time', 'part_time', 'casual', 'contract', 'intern'));
ALTER TABLE hms.hms_staff DROP CONSTRAINT IF EXISTS hms_staff_pay_period_check;
ALTER TABLE hms.hms_staff ADD CONSTRAINT hms_staff_pay_period_check CHECK (pay_period IN ('hour', 'day', 'week', 'month'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_staff_user_uq ON hms.hms_staff (bus_id, user_id) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS hms.hms_time_entries (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    user_id       text NOT NULL,
    property_id   text REFERENCES hms.hms_properties (id),
    clock_in      timestamptz NOT NULL DEFAULT now(),
    clock_out     timestamptz,
    notes         text,
    edited_by     text,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hms_time_entries_open_uq ON hms.hms_time_entries (bus_id, user_id) WHERE clock_out IS NULL;
CREATE INDEX IF NOT EXISTS hms_time_entries_bus_idx ON hms.hms_time_entries (bus_id, clock_in DESC);

CREATE TABLE IF NOT EXISTS hms.hms_leave_requests (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    user_id       text NOT NULL,
    kind          text NOT NULL DEFAULT 'annual',
    starts_on     date NOT NULL,
    ends_on       date NOT NULL,
    reason        text,
    status        text NOT NULL DEFAULT 'pending',
    decided_by    text,
    decided_at    timestamptz,
    decision_note text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT hms_leave_dates_check CHECK (ends_on >= starts_on)
);
ALTER TABLE hms.hms_leave_requests DROP CONSTRAINT IF EXISTS hms_leave_kind_check;
ALTER TABLE hms.hms_leave_requests ADD CONSTRAINT hms_leave_kind_check CHECK (kind IN ('annual', 'sick', 'maternity', 'paternity', 'compassionate', 'unpaid', 'other'));
ALTER TABLE hms.hms_leave_requests DROP CONSTRAINT IF EXISTS hms_leave_status_check;
ALTER TABLE hms.hms_leave_requests ADD CONSTRAINT hms_leave_status_check CHECK (status IN ('pending', 'approved', 'declined', 'cancelled'));

-- ============================================================ extras (upsells)
CREATE TABLE IF NOT EXISTS hms.hms_addons (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    property_id   text NOT NULL REFERENCES hms.hms_properties (id),
    name          text NOT NULL,
    description   text,
    category      text NOT NULL DEFAULT 'service',
    price         numeric(14,2) NOT NULL DEFAULT 0 CHECK (price >= 0),
    per           text NOT NULL DEFAULT 'stay',
    show_online   boolean NOT NULL DEFAULT true,
    active        boolean NOT NULL DEFAULT true,
    sort_order    int NOT NULL DEFAULT 0,
    archived_at   timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hms.hms_addons DROP CONSTRAINT IF EXISTS hms_addons_per_check;
ALTER TABLE hms.hms_addons ADD CONSTRAINT hms_addons_per_check CHECK (per IN ('stay', 'night', 'guest', 'guest_night'));
ALTER TABLE hms.hms_addons DROP CONSTRAINT IF EXISTS hms_addons_category_check;
ALTER TABLE hms.hms_addons ADD CONSTRAINT hms_addons_category_check CHECK (category IN
    ('breakfast', 'meal', 'transport', 'early_checkin', 'late_checkout', 'spa', 'tour', 'celebration', 'parking', 'service', 'other'));

CREATE TABLE IF NOT EXISTS hms.hms_reservation_addons (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    reservation_id  text NOT NULL REFERENCES hms.hms_reservations (id),
    addon_id        text NOT NULL REFERENCES hms.hms_addons (id),
    quantity        int NOT NULL DEFAULT 1 CHECK (quantity > 0),
    amount          numeric(14,2) NOT NULL CHECK (amount >= 0),
    folio_line_id   text REFERENCES hms.hms_folio_lines (id),
    source          text NOT NULL DEFAULT 'desk',
    removed_at      timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS hms_reservation_addons_res_idx ON hms.hms_reservation_addons (reservation_id);

-- Online check-in before arrival: the guest's link, and when they did it.
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS precheckin_token text;
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS precheckin_at timestamptz;
CREATE UNIQUE INDEX IF NOT EXISTS hms_reservations_precheckin_uq ON hms.hms_reservations (precheckin_token) WHERE precheckin_token IS NOT NULL;

-- ================================================================== vouchers
CREATE TABLE IF NOT EXISTS hms.hms_vouchers (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    code            text NOT NULL,
    amount          numeric(14,2) NOT NULL CHECK (amount > 0),
    balance         numeric(14,2) NOT NULL CHECK (balance >= 0),
    buyer_name      text,
    buyer_email     text,
    buyer_phone     text,
    recipient_name  text,
    message         text,
    expires_on      date,
    status          text NOT NULL DEFAULT 'active',
    paid            boolean NOT NULL DEFAULT true,
    paid_method     text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
ALTER TABLE hms.hms_vouchers DROP CONSTRAINT IF EXISTS hms_vouchers_status_check;
ALTER TABLE hms.hms_vouchers ADD CONSTRAINT hms_vouchers_status_check CHECK (status IN ('unpaid', 'active', 'used', 'expired', 'cancelled'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_vouchers_code_uq ON hms.hms_vouchers (bus_id, upper(code));

CREATE TABLE IF NOT EXISTS hms.hms_voucher_uses (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    voucher_id      text NOT NULL REFERENCES hms.hms_vouchers (id),
    amount          numeric(14,2) NOT NULL CHECK (amount > 0),
    folio_line_id   text REFERENCES hms.hms_folio_lines (id),
    order_payment_id text REFERENCES hms.hms_order_payments (id),
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);

-- ============================================================ restaurant tables
CREATE TABLE IF NOT EXISTS hms.hms_table_bookings (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    property_id     text NOT NULL REFERENCES hms.hms_properties (id),
    table_id        text REFERENCES hms.hms_tables (id),
    name            text NOT NULL,
    phone           text,
    email           text,
    party_size      int NOT NULL DEFAULT 2 CHECK (party_size > 0),
    starts_at       timestamptz NOT NULL,
    minutes         int NOT NULL DEFAULT 90 CHECK (minutes BETWEEN 15 AND 600),
    status          text NOT NULL DEFAULT 'booked',
    source          text NOT NULL DEFAULT 'desk',
    notes           text,
    notified_at     timestamptz,
    guest_id        text REFERENCES hms.hms_guests (id),
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
ALTER TABLE hms.hms_table_bookings DROP CONSTRAINT IF EXISTS hms_table_bookings_status_check;
ALTER TABLE hms.hms_table_bookings ADD CONSTRAINT hms_table_bookings_status_check CHECK (status IN
    ('booked', 'waitlist', 'confirmed', 'seated', 'completed', 'cancelled', 'no_show'));
CREATE INDEX IF NOT EXISTS hms_table_bookings_day_idx ON hms.hms_table_bookings (property_id, starts_at);

-- ================================================================ permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-hms-expenses', 'HMS Expenses', 'Money going out, its receipts and approvals',            'rt-subscribed-app-hms'),
('rt-hms-staff',    'HMS Staff',    'Departments, staff, time clock and leave',               'rt-subscribed-app-hms'),
('rt-hms-website',  'HMS Website',  'The public pages, online ordering and gift vouchers',    'rt-subscribed-app-hms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('expenses', 'rt-hms-expenses', 'get',     'View expenses'),
    ('expenses', 'rt-hms-expenses', 'create',  'Record expenses'),
    ('expenses', 'rt-hms-expenses', 'approve', 'Approve or reject expenses'),
    ('staff',    'rt-hms-staff',    'get',     'View staff, time sheets and leave'),
    ('staff',    'rt-hms-staff',    'manage',  'Manage staff, time sheets and decide leave'),
    ('website',  'rt-hms-website',  'manage',  'Design and publish the public pages; sell vouchers')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-hms-' || spec.resource_key || '-' || spec.action,
       'HMS ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'hms',
       resource_key = substring(p.id FROM '^permission-hms-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-hms-%'
   AND (p.app_prefix IS DISTINCT FROM 'hms' OR p.action IS NULL);

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-hms-manager' AS role_id, p2.resource_key, p2.action
      FROM core_platform.cp_permissions p2 WHERE p2.app_prefix = 'hms'
    UNION ALL
    SELECT 'role-hms-viewer', p3.resource_key, p3.action
      FROM core_platform.cp_permissions p3 JOIN core_platform.cp_actions a ON a.action = p3.action AND a.is_read_only AND p3.action <> 'export'
     WHERE p3.app_prefix = 'hms'
    UNION ALL
    SELECT r2, k, a FROM (VALUES
        ('role-hms-frontdesk', 'expenses', 'create'), ('role-hms-frontdesk', 'staff', 'get'),
        ('role-hms-cashier', 'expenses', 'create'),
        ('role-hms-housekeeper', 'staff', 'get'),
        ('role-hms-maintenance', 'expenses', 'create'), ('role-hms-maintenance', 'staff', 'get'),
        ('role-hms-storekeeper', 'expenses', 'create'),
        ('role-hms-finance', 'expenses', 'get'), ('role-hms-finance', 'expenses', 'create'), ('role-hms-finance', 'expenses', 'approve'),
        ('role-hms-finance', 'staff', 'get')) AS x(r2, k, a)
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'hms' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ============================================================ plan features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('hms.website',       'app-hms', 'Website & Online Ordering', 2, 'Your own public pages with templates; bookings, orders and payment online'),
('hms.expenses',      'app-hms', 'Expenses',                  1, 'Money going out, receipts, approvals and spending reports'),
('hms.staff',         'app-hms', 'Staff & HR',                1, 'Departments, staff, time clock, leave and rosters'),
('hms.upsells',       'app-hms', 'Extras & Online Check-in',  2, 'Sell breakfast, transfers and late check-out; guests check in online'),
('hms.vouchers',      'app-hms', 'Gift Vouchers',             2, 'Sell and redeem gift vouchers'),
('hms.table-bookings','app-hms', 'Table Reservations',        1, 'Restaurant bookings and the waitlist'),
('hms.profiles',      'app-hms', 'Several Operations',        2, 'Run more than one operation, each with its own data')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

COMMIT;
