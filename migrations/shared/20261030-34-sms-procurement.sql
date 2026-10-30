-- MyEduGuard: procurement, inventory and assets -- buying, storing and tracking school property.
--
--   sms_proc_settings      numbering (requests, orders, goods received notes, shop sales, asset tags)
--   sms_proc_suppliers     suppliers: contacts, terms, bank details; their performance is worked out
--                          from orders and deliveries
--   sms_proc_requests      purchase requests (a department's or a member of staff's), approved, then
--   sms_proc_request_lines ordered
--   sms_proc_orders        purchase orders to a supplier, received by goods received notes
--   sms_proc_order_lines   (sms_proc_receipts) and paid (sms_proc_supplier_payments)
--   sms_proc_items         the store: stationery, uniforms, books and supplies, with reorder levels,
--   sms_proc_moves         the average cost, and (for the shop) a selling price; every movement kept
--   sms_proc_sales         the school shop: sales to students, paid at the counter or put on their
--   sms_proc_sale_lines    fee account
--   sms_proc_assets        tagged property (barcode tags), where it is and who has it; IT devices
--   sms_proc_assignments   issued to students and staff and returned
--   sms_proc_audits        stock-takes of the assets: tags scanned, what is missing or misplaced
--   sms_proc_audit_scans
--
-- With the school's books set up (Finance), goods received, supplier payments, shop sales and
-- stores issued post to them. Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS sms.sms_proc_settings (
    profile_id      text PRIMARY KEY REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    request_prefix  text NOT NULL DEFAULT 'PR',
    next_request    integer NOT NULL DEFAULT 1,
    po_prefix       text NOT NULL DEFAULT 'PO',
    next_po         integer NOT NULL DEFAULT 1,
    grn_prefix      text NOT NULL DEFAULT 'GRN',
    next_grn        integer NOT NULL DEFAULT 1,
    sale_prefix     text NOT NULL DEFAULT 'SHP',
    next_sale       integer NOT NULL DEFAULT 1,
    tag_prefix      text NOT NULL DEFAULT 'AT',
    next_tag        integer NOT NULL DEFAULT 1,
    device_loan_days integer NOT NULL DEFAULT 365,
    updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sms.sms_proc_suppliers (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id         text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name               text NOT NULL,
    category           text,
    contact_name       text,
    phone              text,
    email              text,
    address            text,
    tax_number         text,
    payment_terms_days integer NOT NULL DEFAULT 30,
    bank_details       text,
    notes              text,
    archived_at        timestamptz,
    cdatetime          timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS sms_proc_suppliers_name_uq ON sms.sms_proc_suppliers (profile_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_proc_items (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id     text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    sku            text NOT NULL,
    name           text NOT NULL,
    category       text NOT NULL DEFAULT 'supplies',
    unit           text NOT NULL DEFAULT 'piece',
    reorder_level  numeric(12,2) NOT NULL DEFAULT 0,
    reorder_qty    numeric(12,2) NOT NULL DEFAULT 0,
    on_hand        numeric(12,2) NOT NULL DEFAULT 0,
    avg_cost       numeric(14,4) NOT NULL DEFAULT 0,
    sell_price     numeric(12,2),
    for_sale       boolean NOT NULL DEFAULT false,
    supplier_id    text REFERENCES sms.sms_proc_suppliers(id) ON DELETE SET NULL,
    barcode        text,
    archived_at    timestamptz,
    cdatetime      timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_proc_items', 'sms_proc_items_check', $q$'cleaning'$q$, $q$CHECK (
    category IN ('stationery', 'uniform', 'books', 'supplies', 'cleaning', 'ict', 'sports', 'lab', 'other') AND on_hand >= 0 AND reorder_level >= 0)$q$);
CREATE UNIQUE INDEX IF NOT EXISTS sms_proc_items_sku_uq ON sms.sms_proc_items (profile_id, lower(sku)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_proc_moves (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id        text NOT NULL,
    item_id           text NOT NULL REFERENCES sms.sms_proc_items(id) ON DELETE CASCADE,
    kind              text NOT NULL,
    qty               numeric(12,2) NOT NULL,
    unit_cost         numeric(14,4) NOT NULL DEFAULT 0,
    ref_type          text,
    ref_id            text,
    department_id     text REFERENCES sms.sms_departments(id) ON DELETE SET NULL,
    staff_id          text REFERENCES sms.sms_staff(id) ON DELETE SET NULL,
    student_id        text REFERENCES sms.sms_students(id) ON DELETE SET NULL,
    note              text,
    by_user           text,
    at                timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_proc_moves', 'sms_proc_moves_check', $q$'adjust'$q$, $q$CHECK (kind IN ('receipt', 'issue', 'sale', 'return', 'adjust') AND qty <> 0)$q$);
CREATE INDEX IF NOT EXISTS sms_proc_moves_item_idx ON sms.sms_proc_moves (item_id, at DESC);

CREATE TABLE IF NOT EXISTS sms.sms_proc_requests (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    number          text NOT NULL,
    title           text NOT NULL,
    requested_by    text,
    department_id   text REFERENCES sms.sms_departments(id) ON DELETE SET NULL,
    needed_by       date,
    justification   text,
    status          text NOT NULL DEFAULT 'pending',
    decided_by      text,
    decided_at      timestamptz,
    decision_note   text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (profile_id, number)
);
SELECT sms.widen_check('sms.sms_proc_requests', 'sms_proc_requests_check', $q$'cancelled'$q$, $q$CHECK (status IN ('pending', 'approved', 'rejected', 'ordered', 'cancelled'))$q$);

CREATE TABLE IF NOT EXISTS sms.sms_proc_request_lines (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    request_id   text NOT NULL REFERENCES sms.sms_proc_requests(id) ON DELETE CASCADE,
    item_id      text REFERENCES sms.sms_proc_items(id) ON DELETE SET NULL,
    description  text NOT NULL,
    qty          numeric(12,2) NOT NULL,
    unit_cost    numeric(12,2) NOT NULL DEFAULT 0,
    seq          integer NOT NULL DEFAULT 0
);
SELECT sms.widen_check('sms.sms_proc_request_lines', 'sms_proc_request_lines_check', $q$qty > 0$q$, $q$CHECK (qty > 0 AND unit_cost >= 0)$q$);

CREATE TABLE IF NOT EXISTS sms.sms_proc_orders (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    number        text NOT NULL,
    supplier_id   text NOT NULL REFERENCES sms.sms_proc_suppliers(id),
    request_id    text REFERENCES sms.sms_proc_requests(id) ON DELETE SET NULL,
    status        text NOT NULL DEFAULT 'open',
    ordered_on    date NOT NULL,
    expected_on   date,
    deliver_to    text,
    terms         text,
    note          text,
    created_by    text,
    cancel_reason text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    UNIQUE (profile_id, number)
);
SELECT sms.widen_check('sms.sms_proc_orders', 'sms_proc_orders_check', $q$'partial'$q$, $q$CHECK (status IN ('open', 'partial', 'received', 'cancelled'))$q$);

CREATE TABLE IF NOT EXISTS sms.sms_proc_order_lines (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    order_id      text NOT NULL REFERENCES sms.sms_proc_orders(id) ON DELETE CASCADE,
    item_id       text REFERENCES sms.sms_proc_items(id) ON DELETE SET NULL,
    description   text NOT NULL,
    qty           numeric(12,2) NOT NULL,
    unit_price    numeric(12,2) NOT NULL,
    received_qty  numeric(12,2) NOT NULL DEFAULT 0,
    rejected_qty  numeric(12,2) NOT NULL DEFAULT 0,
    account_id    text REFERENCES sms.sms_gl_accounts(id) ON DELETE SET NULL,
    seq           integer NOT NULL DEFAULT 0
);
SELECT sms.widen_check('sms.sms_proc_order_lines', 'sms_proc_order_lines_check', $q$received_qty >= 0$q$, $q$CHECK (qty > 0 AND unit_price >= 0 AND received_qty >= 0 AND rejected_qty >= 0)$q$);

CREATE TABLE IF NOT EXISTS sms.sms_proc_receipts (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    number          text NOT NULL,
    order_id        text NOT NULL REFERENCES sms.sms_proc_orders(id) ON DELETE CASCADE,
    received_on     date NOT NULL,
    received_by     text,
    delivery_ref    text,
    rating          integer,
    note            text,
    value           numeric(14,2) NOT NULL DEFAULT 0,
    journal_id      text REFERENCES sms.sms_gl_journals(id),
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (profile_id, number)
);
SELECT sms.widen_check('sms.sms_proc_receipts', 'sms_proc_receipts_check', $q$rating BETWEEN 1 AND 5$q$, $q$CHECK (rating IS NULL OR rating BETWEEN 1 AND 5)$q$);

CREATE TABLE IF NOT EXISTS sms.sms_proc_receipt_lines (
    receipt_id     text NOT NULL REFERENCES sms.sms_proc_receipts(id) ON DELETE CASCADE,
    order_line_id  text NOT NULL REFERENCES sms.sms_proc_order_lines(id) ON DELETE CASCADE,
    qty_received   numeric(12,2) NOT NULL DEFAULT 0,
    qty_rejected   numeric(12,2) NOT NULL DEFAULT 0,
    reason         text,
    PRIMARY KEY (receipt_id, order_line_id)
);

CREATE TABLE IF NOT EXISTS sms.sms_proc_supplier_payments (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id     text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    order_id       text NOT NULL REFERENCES sms.sms_proc_orders(id) ON DELETE CASCADE,
    paid_on        date NOT NULL,
    amount         numeric(14,2) NOT NULL,
    method         text NOT NULL DEFAULT 'bank',
    reference      text,
    paid_from_id   text REFERENCES sms.sms_gl_accounts(id),
    journal_id     text REFERENCES sms.sms_gl_journals(id),
    by_user        text,
    cdatetime      timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_proc_supplier_payments', 'sms_proc_supplier_payments_check', $q$amount > 0$q$, $q$CHECK (amount > 0)$q$);

CREATE TABLE IF NOT EXISTS sms.sms_proc_sales (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    number       text NOT NULL,
    student_id   text REFERENCES sms.sms_students(id) ON DELETE SET NULL,
    buyer_name   text,
    sold_on      date NOT NULL,
    total        numeric(14,2) NOT NULL,
    method       text NOT NULL,
    reference    text,
    invoice_id   text REFERENCES sms.sms_fee_invoices(id) ON DELETE SET NULL,
    status       text NOT NULL DEFAULT 'completed',
    void_reason  text,
    journal_id   text REFERENCES sms.sms_gl_journals(id),
    by_user      text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (profile_id, number)
);
SELECT sms.widen_check('sms.sms_proc_sales', 'sms_proc_sales_check', $q$'account'$q$, $q$CHECK (
    method IN ('cash', 'mobile_money', 'card', 'account') AND status IN ('completed', 'void') AND total >= 0)$q$);

CREATE TABLE IF NOT EXISTS sms.sms_proc_sale_lines (
    sale_id      text NOT NULL REFERENCES sms.sms_proc_sales(id) ON DELETE CASCADE,
    item_id      text NOT NULL REFERENCES sms.sms_proc_items(id),
    description  text NOT NULL,
    qty          numeric(12,2) NOT NULL,
    unit_price   numeric(12,2) NOT NULL,
    unit_cost    numeric(14,4) NOT NULL DEFAULT 0,
    seq          integer NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS sms.sms_proc_assets (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    tag             text NOT NULL,
    name            text NOT NULL,
    category        text NOT NULL DEFAULT 'furniture',
    is_device       boolean NOT NULL DEFAULT false,
    device_type     text,
    make            text,
    model           text,
    serial          text,
    os              text,
    identifier      text,
    condition       text NOT NULL DEFAULT 'good',
    status          text NOT NULL DEFAULT 'in_store',
    resource_id     text REFERENCES sms.sms_resources(id) ON DELETE SET NULL,
    location        text,
    staff_id        text REFERENCES sms.sms_staff(id) ON DELETE SET NULL,
    student_id      text REFERENCES sms.sms_students(id) ON DELETE SET NULL,
    value           numeric(14,2),
    acquired_on     date,
    warranty_until  date,
    supplier_id     text REFERENCES sms.sms_proc_suppliers(id) ON DELETE SET NULL,
    order_id        text REFERENCES sms.sms_proc_orders(id) ON DELETE SET NULL,
    notes           text,
    disposed_on     date,
    disposal_note   text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (profile_id, tag)
);
SELECT sms.widen_check('sms.sms_proc_assets', 'sms_proc_assets_check', $q$'kitchen'$q$, $q$CHECK (
    category IN ('furniture', 'ict', 'device', 'lab', 'sports', 'vehicle', 'kitchen', 'office', 'music', 'other')
    AND condition IN ('new', 'good', 'fair', 'poor', 'broken')
    AND status IN ('in_use', 'in_store', 'issued', 'repair', 'lost', 'disposed')
    AND (device_type IS NULL OR device_type IN ('laptop', 'tablet', 'desktop', 'phone', 'projector', 'printer', 'other')))$q$);
CREATE INDEX IF NOT EXISTS sms_proc_assets_status_idx ON sms.sms_proc_assets (profile_id, status);

CREATE TABLE IF NOT EXISTS sms.sms_proc_assignments (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    asset_id        text NOT NULL REFERENCES sms.sms_proc_assets(id) ON DELETE CASCADE,
    resource_id     text REFERENCES sms.sms_resources(id) ON DELETE SET NULL,
    staff_id        text REFERENCES sms.sms_staff(id) ON DELETE SET NULL,
    student_id      text REFERENCES sms.sms_students(id) ON DELETE SET NULL,
    location        text,
    out_at          timestamptz NOT NULL DEFAULT now(),
    due_back        date,
    returned_at     timestamptz,
    condition_out   text,
    condition_in    text,
    accessories     text,
    acknowledged    boolean NOT NULL DEFAULT false,
    note            text,
    by_user         text,
    returned_by     text
);
CREATE INDEX IF NOT EXISTS sms_proc_assignments_asset_idx ON sms.sms_proc_assignments (asset_id, out_at DESC);

CREATE TABLE IF NOT EXISTS sms.sms_proc_audits (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name         text NOT NULL,
    resource_id  text REFERENCES sms.sms_resources(id) ON DELETE SET NULL,
    status       text NOT NULL DEFAULT 'open',
    started_by   text,
    started_at   timestamptz NOT NULL DEFAULT now(),
    closed_at    timestamptz,
    note         text
);
SELECT sms.widen_check('sms.sms_proc_audits', 'sms_proc_audits_check', $q$'closed'$q$, $q$CHECK (status IN ('open', 'closed'))$q$);

CREATE TABLE IF NOT EXISTS sms.sms_proc_audit_scans (
    audit_id     text NOT NULL REFERENCES sms.sms_proc_audits(id) ON DELETE CASCADE,
    asset_id     text NOT NULL REFERENCES sms.sms_proc_assets(id) ON DELETE CASCADE,
    condition    text,
    scanned_at   timestamptz NOT NULL DEFAULT now(),
    by_user      text,
    PRIMARY KEY (audit_id, asset_id)
);

-- Goods received, supplier payments, shop sales and stores issued post to the books.
SELECT sms.widen_check('sms.sms_gl_journals', 'sms_gl_journals_check', $q$'stores'$q$, $q$CHECK (
    source IN ('manual', 'fees', 'expense', 'petty_cash', 'transfer', 'payroll', 'asset', 'depreciation', 'disposal', 'bank', 'opening', 'reversal',
        'purchase', 'supplier_payment', 'shop', 'stores')
    AND status IN ('posted', 'reversed'))$q$);

-- Procurement is a module a school can turn off (Settings, Modules).
SELECT sms.widen_check('sms.sms_profiles', 'sms_profiles_modules_check', $q$'procurement'$q$, $q$CHECK (modules IS NULL OR (cardinality(modules) > 0 AND modules <@ ARRAY[
    'admissions', 'teaching', 'scheduling', 'attendance', 'grading', 'learning', 'welfare', 'inclusion', 'boarding', 'library', 'activities', 'transport',
    'catering', 'hr', 'fees', 'finance', 'procurement']::text[]))$q$);

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-procurement', 'MyEduGuard Procurement', 'Suppliers, purchase requests and orders, the store and the school shop, and tagged assets and devices', 'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, action, label) AS (VALUES
    ('procurement', 'get',      'View suppliers, purchase requests and orders, the store, shop sales and assets'),
    ('procurement', 'transact', 'Receive goods, issue from the store, sell in the school shop, and issue and return assets and devices'),
    ('procurement', 'approve',  'Approve or reject purchase requests'),
    ('procurement', 'manage',   'Keep suppliers, items and assets, raise purchase orders, pay suppliers and run asset audits')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-sms-' || spec.resource_key || '-' || spec.action,
       'MyEduGuard ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       'rt-sms-procurement', spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
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
('role-sms-procurement', 'system-tenant-id', 'MyEduGuard Procurement Officer', 'Keeps suppliers, raises purchase orders, receives goods and pays suppliers, and keeps the store and the asset register', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-sms-storekeeper', 'system-tenant-id', 'MyEduGuard Storekeeper', 'Receives goods, issues from the store, runs the school shop, and issues and takes back assets and devices', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
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
    SELECT 'role-sms-procurement', k, a FROM (VALUES ('procurement', 'get'), ('procurement', 'transact'), ('procurement', 'manage'), ('students', 'get'),
        ('structure', 'get'), ('profiles', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-storekeeper', k, a FROM (VALUES ('procurement', 'get'), ('procurement', 'transact'), ('students', 'get'), ('structure', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-bursar', k, a FROM (VALUES ('procurement', 'get'), ('procurement', 'transact')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-accountant', k, a FROM (VALUES ('procurement', 'get'), ('procurement', 'approve')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-viewer', 'procurement', 'get'
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'sms' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', r.id, p.id
  FROM core_platform.cp_permissions p CROSS JOIN (VALUES ('role-sms-procurement'), ('role-sms-storekeeper')) AS r(id)
 WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.suppliers',       'app-sms', 'Vendors & Suppliers',              1, 'Supplier records, contacts and performance'),
('sms.purchasing',      'app-sms', 'Purchase Requests & Orders',       2, 'Requests, approvals, purchase orders and goods received notes'),
('sms.inventory',       'app-sms', 'Inventory & Stores',               1, 'Stationery, uniforms, books and supplies with reorder levels'),
('sms.school-shop',     'app-sms', 'School Shop & Uniform Sales',      1, 'Sell items to students and post to their accounts'),
('sms.asset-tracking',  'app-sms', 'Asset Tagging & Tracking',         2, 'Barcode tags, assignment to rooms or staff and audits'),
('sms.it-devices',      'app-sms', 'IT Asset & Device Management',     2, 'Laptops and tablets issued to students and staff')
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
                WHERE rp.role_id IN ('role-sms-procurement', 'role-sms-storekeeper') AND p.app_prefix = 'sms'
                  AND p.resource_key IN ('counselling', 'safeguarding', 'hr', 'finance')) THEN
        RAISE EXCEPTION 'counselling, safeguarding, staff records and the books are not the storekeeper''s';
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
