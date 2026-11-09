-- HMS expenses follow Core Platform's expense pattern: the category is Core's, with its tax.
--
-- Core Platform owns expense categories (core_platform.cp_expense_categories, 20261108-04;
-- Settings > Expenses > Categories), as MyStoreGuard already uses them. HMS keeps its own
-- hms_expense_categories as its BUDGET layer -- the department an expense counts against in the
-- profit and loss, and a monthly budget to warn at -- and each now LINKS to a Core category
-- (core_category_id). An expense names the Core category it is for (hms_expenses.core_category_id);
-- HMS finds the budget/department row through the link. The tax inside what was paid is one of
-- the business's Core tax rates (tax_rate_id) and its amount (tax_amount), prefilled from the
-- category's rate.
--
-- On the FIRST run only (the column did not exist yet), each existing HMS category is linked to
-- the Core category of the same name for that tenant (this business's, else the organisation's);
-- a live one with no such Core category gets one, organisation-wide (bus_id NULL), with a stable
-- id 'expcat-' || md5(tenant || '/hms/' || name). A tenant that had no Core categories at all is
-- first given Core's 15 defaults (as Core would on its first ask: once it has any, Core never
-- adds them). Existing expenses then take the Core category of their HMS category. Later runs
-- change nothing: a link a person removes stays removed.
--
-- No foreign keys: Core's categories and taxes live in another schema (as hospital_invoices.tax_id).
-- CloudHams keeps its expenses in hospital_entries' JSON and needs no column (its code reads
-- data->>'core_category_id').
--
-- Idempotent; safe to re-run on every deploy. A database without HMS skips it.

BEGIN;

DO $$
DECLARE
    first_run boolean;
BEGIN
    IF to_regclass('hms.hms_expenses') IS NULL OR to_regclass('hms.hms_expense_categories') IS NULL
       OR to_regclass('core_platform.cp_expense_categories') IS NULL THEN
        RAISE NOTICE 'hms expenses core categories: no HMS (or no Core categories) here, nothing to do';
        RETURN;
    END IF;

    first_run := NOT EXISTS (SELECT 1 FROM information_schema.columns
                              WHERE table_schema = 'hms' AND table_name = 'hms_expense_categories'
                                AND column_name = 'core_category_id');

    ALTER TABLE hms.hms_expense_categories ADD COLUMN IF NOT EXISTS core_category_id text;
    ALTER TABLE hms.hms_expenses ADD COLUMN IF NOT EXISTS core_category_id text;
    ALTER TABLE hms.hms_expenses ADD COLUMN IF NOT EXISTS tax_rate_id text;
    ALTER TABLE hms.hms_expenses ADD COLUMN IF NOT EXISTS tax_amount numeric(14, 2);

    ALTER TABLE hms.hms_expenses DROP CONSTRAINT IF EXISTS hms_expenses_tax_amount_check;
    ALTER TABLE hms.hms_expenses ADD CONSTRAINT hms_expenses_tax_amount_check
        CHECK (tax_amount IS NULL OR (tax_amount >= 0 AND tax_amount <= amount));

    CREATE INDEX IF NOT EXISTS hms_expense_categories_core_idx
        ON hms.hms_expense_categories (bus_id, core_category_id) WHERE core_category_id IS NOT NULL;
    CREATE INDEX IF NOT EXISTS hms_expenses_core_category_idx
        ON hms.hms_expenses (bus_id, core_category_id);

    IF NOT first_run THEN
        RETURN;
    END IF;

    -- Core's defaults for a tenant about to get its first Core category from here.
    INSERT INTO core_platform.cp_expense_categories (tenant_id, id, bus_id, name, icon, position)
    SELECT t.tenant_id, 'expcat-' || md5(t.tenant_id || '/default/' || lower(d.name)), NULL, d.name, d.icon, d.pos
      FROM (SELECT DISTINCT c.tenant_id FROM hms.hms_expense_categories c
             WHERE c.archived_at IS NULL
               AND NOT EXISTS (SELECT 1 FROM core_platform.cp_expense_categories x WHERE x.tenant_id = c.tenant_id)) t
     CROSS JOIN (VALUES ('Rent', 'home', 0), ('Utilities', 'zap', 1), ('Salaries & wages', 'users', 2),
                        ('Transport & fuel', 'truck', 3), ('Travel', 'map', 4), ('Meals & entertainment', 'coffee', 5),
                        ('Office supplies', 'paperclip', 6), ('Repairs & maintenance', 'tool', 7),
                        ('Internet & phone', 'phone', 8), ('Marketing', 'speaker', 9), ('Professional fees', 'briefcase', 10),
                        ('Bank charges', 'credit-card', 11), ('Insurance', 'shield', 12), ('Taxes & licences', 'file-text', 13),
                        ('Other', 'more-horizontal', 14)) AS d(name, icon, pos)
    ON CONFLICT DO NOTHING;

    -- A live HMS category with no Core category of its name gets one, organisation-wide.
    INSERT INTO core_platform.cp_expense_categories (tenant_id, id, bus_id, name, position)
    SELECT DISTINCT ON (c.tenant_id, lower(trim(c.name)))
           c.tenant_id, 'expcat-' || md5(c.tenant_id || '/hms/' || lower(trim(c.name))), NULL, trim(c.name), 100
      FROM hms.hms_expense_categories c
     WHERE c.archived_at IS NULL AND length(trim(c.name)) > 0
       AND NOT EXISTS (SELECT 1 FROM core_platform.cp_expense_categories x
                        WHERE x.tenant_id = c.tenant_id AND lower(trim(x.name)) = lower(trim(c.name))
                          AND (x.bus_id IS NULL OR x.bus_id = c.bus_id))
     ORDER BY c.tenant_id, lower(trim(c.name)), c.cdatetime
    ON CONFLICT DO NOTHING;

    -- The link: this business's Core category of the name first, then the organisation's.
    UPDATE hms.hms_expense_categories c
       SET core_category_id = (SELECT x.id FROM core_platform.cp_expense_categories x
                                WHERE x.tenant_id = c.tenant_id AND lower(trim(x.name)) = lower(trim(c.name))
                                  AND (x.bus_id IS NULL OR x.bus_id = c.bus_id)
                                ORDER BY (x.bus_id IS NOT NULL) DESC, x.is_active DESC, x.position, x.id
                                LIMIT 1)
     WHERE c.core_category_id IS NULL;

    UPDATE hms.hms_expenses e
       SET core_category_id = c.core_category_id
      FROM hms.hms_expense_categories c
     WHERE c.id = e.category_id AND e.core_category_id IS NULL AND c.core_category_id IS NOT NULL;
END
$$;

COMMIT;
