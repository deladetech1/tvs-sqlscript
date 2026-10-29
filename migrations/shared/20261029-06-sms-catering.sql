-- MyEduGuard 15: catering and canteen -- meals and cafeteria operations.
--
--   sms_catering_settings        each school's feeding fee (a day, a week), the days it feeds,
--                                and whether an allergen stops a sale
--   sms_menu_items               what the kitchen and canteen serve: price, allergens, diets, and
--                                the kitchen stock a sale uses
--   sms_menu_entries             the weekly menu: each day's breakfast, lunch, supper and snacks
--   sms_meal_plans, _subscriptions  meal plans (lunch every school day, full board) and the
--                                students on them, billed per term
--   sms_catering_charges         what plans bill: unpaid, paid (at the office or from the wallet)
--                                or waived
--   sms_feeding_payments         daily or weekly feeding fees paid for days of school, in cash,
--                                by mobile money or from the wallet
--   sms_feeding_exempt           students fed free (a bursary, staff children)
--   sms_meal_servings            each student served at the serving line, against what covers them
--   sms_canteen_cards            cards and wristbands (their RFID or QR code) a student pays with
--   sms_canteen_sales            the canteen's sales: what was bought, paid from the wallet or in
--                                cash; voided with a reason
--   sms_dietary_flags            a student's allergens and diet, shown (and checked) at the till
--   sms_kitchen_items, _moves    ingredients and supplies: on hand, reorder level, received, used,
--                                wasted, sold
--
-- The canteen spends from the student's one wallet (sms_wallets, 20261029-01): pocket money and
-- the canteen are the same balance, the same daily limit and the same family top-ups.
-- Permissions sms|catering|get/transact/manage; the roles MyEduGuard Catering Manager and
-- MyEduGuard Canteen Cashier. Idempotent.

BEGIN;

CREATE TABLE IF NOT EXISTS sms.sms_catering_settings (
    profile_id      text PRIMARY KEY REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    daily_fee       numeric(10,2),
    weekly_fee      numeric(10,2),
    feeding_days    integer[] NOT NULL DEFAULT '{1,2,3,4,5}',
    block_allergens boolean NOT NULL DEFAULT true,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CHECK ((daily_fee IS NULL OR daily_fee >= 0) AND (weekly_fee IS NULL OR weekly_fee >= 0)),
    CHECK (feeding_days <@ ARRAY[1,2,3,4,5,6,7])
);

CREATE TABLE IF NOT EXISTS sms.sms_menu_items (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    profile_id     text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name           text NOT NULL,
    category       text NOT NULL DEFAULT 'meal',
    description    text,
    price          numeric(10,2),
    allergens      text[] NOT NULL DEFAULT '{}',
    diets          text[] NOT NULL DEFAULT '{}',
    on_sale        boolean NOT NULL DEFAULT true,
    stock_item_id  text,
    stock_qty      numeric(10,3),
    archived_at    timestamptz,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    CHECK (price IS NULL OR price >= 0)
);
ALTER TABLE sms.sms_menu_items DROP CONSTRAINT IF EXISTS sms_menu_items_check2;
ALTER TABLE sms.sms_menu_items ADD CONSTRAINT sms_menu_items_check2
    CHECK (category IN ('meal', 'snack', 'drink', 'fruit', 'other')
           AND allergens <@ ARRAY['peanuts', 'tree_nuts', 'milk', 'eggs', 'fish', 'shellfish', 'wheat', 'soy', 'sesame']
           AND diets <@ ARRAY['vegetarian', 'vegan', 'halal', 'gluten_free', 'dairy_free']);
CREATE UNIQUE INDEX IF NOT EXISTS sms_menu_items_name_uq ON sms.sms_menu_items (profile_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_menu_entries (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    served_on   date NOT NULL,
    meal        text NOT NULL,
    item_id     text NOT NULL REFERENCES sms.sms_menu_items(id) ON DELETE CASCADE,
    sort_order  integer NOT NULL DEFAULT 0,
    UNIQUE (profile_id, served_on, meal, item_id)
);
ALTER TABLE sms.sms_menu_entries DROP CONSTRAINT IF EXISTS sms_menu_entries_meal_check;
ALTER TABLE sms.sms_menu_entries ADD CONSTRAINT sms_menu_entries_meal_check CHECK (meal IN ('breakfast', 'lunch', 'supper', 'snack'));
CREATE INDEX IF NOT EXISTS sms_menu_entries_idx ON sms.sms_menu_entries (profile_id, served_on);

CREATE TABLE IF NOT EXISTS sms.sms_meal_plans (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name         text NOT NULL,
    meals        text[] NOT NULL,
    price        numeric(10,2) NOT NULL,
    description  text,
    archived_at  timestamptz,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    CHECK (price >= 0 AND cardinality(meals) > 0 AND meals <@ ARRAY['breakfast', 'lunch', 'supper', 'snack'])
);
CREATE UNIQUE INDEX IF NOT EXISTS sms_meal_plans_name_uq ON sms.sms_meal_plans (profile_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_meal_subscriptions (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    plan_id     text NOT NULL REFERENCES sms.sms_meal_plans(id) ON DELETE CASCADE,
    student_id  text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    starts_on   date NOT NULL DEFAULT CURRENT_DATE,
    ends_on     date,
    added_by    text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    CHECK (ends_on IS NULL OR ends_on >= starts_on)
);
CREATE UNIQUE INDEX IF NOT EXISTS sms_meal_subscriptions_one ON sms.sms_meal_subscriptions (student_id, plan_id) WHERE ends_on IS NULL;
CREATE INDEX IF NOT EXISTS sms_meal_subscriptions_student_idx ON sms.sms_meal_subscriptions (student_id);

CREATE TABLE IF NOT EXISTS sms.sms_catering_charges (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id  text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    plan_id     text REFERENCES sms.sms_meal_plans(id) ON DELETE SET NULL,
    term_id     text NOT NULL REFERENCES sms.sms_terms(id) ON DELETE CASCADE,
    amount      numeric(10,2) NOT NULL,
    status      text NOT NULL DEFAULT 'unpaid',
    paid_at     timestamptz,
    method      text,
    reference   text,
    note        text,
    settled_by  text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    CHECK (amount > 0),
    UNIQUE (student_id, plan_id, term_id)
);
ALTER TABLE sms.sms_catering_charges DROP CONSTRAINT IF EXISTS sms_catering_charges_check2;
ALTER TABLE sms.sms_catering_charges ADD CONSTRAINT sms_catering_charges_check2
    CHECK (status IN ('unpaid', 'paid', 'waived') AND (method IS NULL OR method IN ('cash', 'mobile_money', 'bank', 'card', 'cheque', 'wallet')));
CREATE INDEX IF NOT EXISTS sms_catering_charges_idx ON sms.sms_catering_charges (profile_id, term_id, status);

CREATE TABLE IF NOT EXISTS sms.sms_feeding_payments (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id   text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    covers_from  date NOT NULL,
    covers_to    date NOT NULL,
    days         integer NOT NULL,
    amount       numeric(10,2) NOT NULL,
    method       text NOT NULL DEFAULT 'cash',
    reference    text,
    collected_by text,
    voided_at    timestamptz,
    void_reason  text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    CHECK (covers_to >= covers_from AND days > 0 AND amount >= 0)
);
ALTER TABLE sms.sms_feeding_payments DROP CONSTRAINT IF EXISTS sms_feeding_payments_method_check;
ALTER TABLE sms.sms_feeding_payments ADD CONSTRAINT sms_feeding_payments_method_check CHECK (method IN ('cash', 'mobile_money', 'wallet'));
CREATE INDEX IF NOT EXISTS sms_feeding_payments_idx ON sms.sms_feeding_payments (student_id, covers_to DESC);
CREATE INDEX IF NOT EXISTS sms_feeding_payments_day_idx ON sms.sms_feeding_payments (profile_id, cdatetime DESC);

CREATE TABLE IF NOT EXISTS sms.sms_feeding_exempt (
    student_id  text PRIMARY KEY REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    reason      text NOT NULL,
    until       date,
    added_by    text,
    cdatetime   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sms.sms_meal_servings (
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id  text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    served_on   date NOT NULL,
    meal        text NOT NULL,
    covered_by  text NOT NULL,
    served_by   text,
    at          timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (student_id, served_on, meal)
);
ALTER TABLE sms.sms_meal_servings DROP CONSTRAINT IF EXISTS sms_meal_servings_check2;
ALTER TABLE sms.sms_meal_servings ADD CONSTRAINT sms_meal_servings_check2
    CHECK (meal IN ('breakfast', 'lunch', 'supper', 'snack') AND covered_by IN ('plan', 'feeding', 'exempt', 'override'));
CREATE INDEX IF NOT EXISTS sms_meal_servings_idx ON sms.sms_meal_servings (profile_id, served_on, meal);

CREATE TABLE IF NOT EXISTS sms.sms_canteen_cards (
    code        text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id  text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    kind        text NOT NULL DEFAULT 'card',
    status      text NOT NULL DEFAULT 'active',
    issued_by   text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (profile_id, code)
);
ALTER TABLE sms.sms_canteen_cards DROP CONSTRAINT IF EXISTS sms_canteen_cards_check2;
ALTER TABLE sms.sms_canteen_cards ADD CONSTRAINT sms_canteen_cards_check2 CHECK (kind IN ('card', 'wristband', 'tag') AND status IN ('active', 'lost', 'blocked'));
CREATE INDEX IF NOT EXISTS sms_canteen_cards_student_idx ON sms.sms_canteen_cards (student_id);

CREATE TABLE IF NOT EXISTS sms.sms_canteen_sales (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    student_id   text REFERENCES sms.sms_students(id) ON DELETE SET NULL,
    lines        jsonb NOT NULL,
    total        numeric(10,2) NOT NULL,
    method       text NOT NULL,
    wallet_txn   text,
    overridden   text[] NOT NULL DEFAULT '{}',
    sold_by      text,
    voided_at    timestamptz,
    voided_by    text,
    void_reason  text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    CHECK (total >= 0)
);
ALTER TABLE sms.sms_canteen_sales DROP CONSTRAINT IF EXISTS sms_canteen_sales_method_check;
ALTER TABLE sms.sms_canteen_sales ADD CONSTRAINT sms_canteen_sales_method_check CHECK (method IN ('wallet', 'cash', 'mobile_money'));
CREATE INDEX IF NOT EXISTS sms_canteen_sales_idx ON sms.sms_canteen_sales (profile_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS sms_canteen_sales_student_idx ON sms.sms_canteen_sales (student_id, cdatetime DESC);

CREATE TABLE IF NOT EXISTS sms.sms_dietary_flags (
    student_id  text PRIMARY KEY REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    allergens   text[] NOT NULL DEFAULT '{}',
    diets       text[] NOT NULL DEFAULT '{}',
    note        text,
    updated_by  text,
    updated_at  timestamptz NOT NULL DEFAULT now(),
    CHECK (allergens <@ ARRAY['peanuts', 'tree_nuts', 'milk', 'eggs', 'fish', 'shellfish', 'wheat', 'soy', 'sesame']
           AND diets <@ ARRAY['vegetarian', 'vegan', 'halal', 'gluten_free', 'dairy_free'])
);

CREATE TABLE IF NOT EXISTS sms.sms_kitchen_items (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    profile_id     text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name           text NOT NULL,
    category       text NOT NULL DEFAULT 'ingredient',
    unit           text NOT NULL,
    on_hand        numeric(12,3) NOT NULL DEFAULT 0,
    reorder_level  numeric(12,3),
    unit_cost      numeric(12,2),
    supplier       text,
    archived_at    timestamptz,
    cdatetime      timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE sms.sms_kitchen_items DROP CONSTRAINT IF EXISTS sms_kitchen_items_category_check;
ALTER TABLE sms.sms_kitchen_items ADD CONSTRAINT sms_kitchen_items_category_check CHECK (category IN ('ingredient', 'drink', 'packaged', 'supply', 'other'));
CREATE UNIQUE INDEX IF NOT EXISTS sms_kitchen_items_name_uq ON sms.sms_kitchen_items (profile_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_kitchen_moves (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    item_id     text NOT NULL REFERENCES sms.sms_kitchen_items(id) ON DELETE CASCADE,
    kind        text NOT NULL,
    qty         numeric(12,3) NOT NULL,
    on_hand     numeric(12,3) NOT NULL,
    unit_cost   numeric(12,2),
    note        text,
    sale_id     text REFERENCES sms.sms_canteen_sales(id) ON DELETE SET NULL,
    by_user     text,
    at          timestamptz NOT NULL DEFAULT now(),
    CHECK (qty <> 0)
);
ALTER TABLE sms.sms_kitchen_moves DROP CONSTRAINT IF EXISTS sms_kitchen_moves_kind_check;
ALTER TABLE sms.sms_kitchen_moves ADD CONSTRAINT sms_kitchen_moves_kind_check CHECK (kind IN ('receive', 'use', 'waste', 'count', 'sale', 'void'));
CREATE INDEX IF NOT EXISTS sms_kitchen_moves_idx ON sms.sms_kitchen_moves (item_id, at DESC);

ALTER TABLE sms.sms_menu_items DROP CONSTRAINT IF EXISTS sms_menu_items_stock_fk;
ALTER TABLE sms.sms_menu_items ADD CONSTRAINT sms_menu_items_stock_fk FOREIGN KEY (stock_item_id) REFERENCES sms.sms_kitchen_items(id) ON DELETE SET NULL;

-- Catering is a module a school can turn off (Settings, Modules).
SELECT sms.widen_check('sms.sms_profiles', 'sms_profiles_modules_check', $q$'catering'$q$, $q$CHECK (modules IS NULL OR (cardinality(modules) > 0 AND modules <@ ARRAY[
    'admissions', 'teaching', 'scheduling', 'attendance', 'grading', 'learning', 'welfare', 'inclusion', 'boarding', 'library', 'activities', 'transport',
    'catering']::text[]))$q$);

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-catering', 'MyEduGuard Catering', 'Menus and meal plans, feeding fees, the canteen and its wallet, dietary flags and kitchen stock', 'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, action, label) AS (VALUES
    ('catering', 'get',    'View menus, meal plans, feeding fees, canteen sales, dietary flags and kitchen stock'),
    ('catering', 'transact',   'Sell at the canteen, serve meals at the line, collect feeding fees and take wallet top-ups at the counter'),
    ('catering', 'manage', 'Keep the menu, meal plans and fees, bill plans, confirm family top-ups, void sales, keep dietary flags and the kitchen''s stock')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-sms-' || spec.resource_key || '-' || spec.action,
       'MyEduGuard ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       'rt-sms-catering', spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
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
('role-sms-caterer', 'system-tenant-id', 'MyEduGuard Catering Manager', 'Runs catering: menus and meal plans, feeding fees, the canteen and its wallet, dietary flags and the kitchen''s stock', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-sms-cashier', 'system-tenant-id', 'MyEduGuard Canteen Cashier', 'Sells at the canteen, serves at the line and collects feeding fees', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
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
    SELECT 'role-sms-caterer', k, a FROM (VALUES ('catering', 'get'), ('catering', 'transact'), ('catering', 'manage'), ('students', 'get'), ('structure', 'get'),
        ('profiles', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-cashier', k, a FROM (VALUES ('catering', 'get'), ('catering', 'transact')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-teacher', k, a FROM (VALUES ('catering', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-housemaster', k, a FROM (VALUES ('catering', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-matron', k, a FROM (VALUES ('catering', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-nurse', k, a FROM (VALUES ('catering', 'get')) AS g(k, a)
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
SELECT 'system-tenant-id', r.id, p.id
  FROM core_platform.cp_permissions p, (VALUES ('role-sms-caterer'), ('role-sms-cashier')) AS r(id)
 WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.meal-plans',     'app-sms', 'Meal Plans & Menus',         1, 'Weekly menus and meal plan subscriptions'),
('sms.feeding-fees',   'app-sms', 'Daily Feeding Fee Collection', 1, 'Daily or weekly feeding fees, common in African schools'),
('sms.canteen-wallet', 'app-sms', 'Cashless Canteen Wallet',    2, 'Card or wristband payments with parent top ups and spending limits'),
('sms.dietary',        'app-sms', 'Dietary Restrictions',       1, 'Allergy and dietary flags visible at the point of sale'),
('sms.kitchen-stock',  'app-sms', 'Kitchen Stock',              2, 'Ingredients and supplies inventory')
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
                WHERE rp.role_id = 'role-sms-cashier' AND p.app_prefix = 'sms' AND (p.resource_key <> 'catering' OR p.action = 'manage')) THEN
        RAISE EXCEPTION 'a cashier sells and serves, and nothing else';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-sms-caterer' AND p.app_prefix = 'sms' AND p.resource_key IN ('counselling', 'safeguarding')) THEN
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
