-- The Expenses app's categories are Core Platform's.
--
-- Core Platform owns expense categories (core_platform.cp_expense_categories, 20261108-04; hub:
-- Settings > Expenses > Categories), as MyStoreGuard, LoanDrift, HMS and CloudHams already use
-- them, so a category means the same thing in every app and in the books. The Expenses app keeps
-- expenses.exp_categories as its OWN SETTINGS on top of a Core category, per business: the kind
-- (expense / mileage / per diem), the icon, the receipt rule and the per-item limit. Each row now
-- LINKS to its Core category (core_category_id; at most one row per business and Core category).
-- Name, description, account code, tax and order are Core's; the app copies them onto its row
-- whenever it reads the list, so every existing join (reports, budgets, bills, events) keeps
-- working on exp_categories.id.
--
-- On the FIRST run only (the column did not exist yet), each existing Expenses category is linked
-- to the Core category of the same name for that tenant (this business's, else the
-- organisation's). A live one with no such Core category gets one, organisation-wide (bus_id
-- NULL), with a stable id 'expcat-' || md5(tenant || '/expenses/' || lower(name)), carrying its
-- tax rate, receipt rule, icon, code and description. A tenant that had no Core categories at all
-- is first given Core's 15 defaults (as Core would on its first ask: once it has any, Core never
-- adds them). Later runs link nothing: a link a person removes stays removed. Existing Core
-- categories are NOT changed (their tax and code win over what the Expenses row had).
--
-- exp_expenses.core_category_id: the Core category an expense counts under, for reporting across
-- apps, filled from the link and kept by a trigger whenever an expense's category is set. Each
-- expense keeps its Expenses category (category_id) as before.
--
-- Accounting events (exp.* , docs/POSTINGS.md §6): every line built by exp_acc_category now also
-- carries 'core_category_id' (NULL when unlinked or uncategorised), so Accounting can post every
-- app's spending on one EXPENSE_CATEGORY:<core id> account. Old keys are unchanged, and 'money'
-- (what decides a re-post) is unchanged, so nothing already in the books is re-posted.
--
-- No foreign keys to Core (another schema, as HMS). Idempotent; safe to re-run on every deploy.
-- A database without the Expenses app skips it.

BEGIN;

DO $$
DECLARE
    first_run boolean;
BEGIN
    IF to_regclass('expenses.exp_categories') IS NULL OR to_regclass('expenses.exp_expenses') IS NULL
       OR to_regclass('core_platform.cp_expense_categories') IS NULL THEN
        RAISE NOTICE 'expenses core categories: no Expenses app (or no Core categories) here, nothing to do';
        RETURN;
    END IF;

    first_run := NOT EXISTS (SELECT 1 FROM information_schema.columns
                              WHERE table_schema = 'expenses' AND table_name = 'exp_categories'
                                AND column_name = 'core_category_id');

    ALTER TABLE expenses.exp_categories ADD COLUMN IF NOT EXISTS core_category_id text;
    ALTER TABLE expenses.exp_expenses ADD COLUMN IF NOT EXISTS core_category_id text;

    -- Names are Core's now (two Core categories may share a name: the organisation's and a
    -- business's), so the Expenses row no longer enforces its own.
    DROP INDEX IF EXISTS expenses.exp_categories_name_uq;

    CREATE INDEX IF NOT EXISTS exp_expenses_core_category_idx
        ON expenses.exp_expenses (bus_id, core_category_id) WHERE core_category_id IS NOT NULL;

    IF first_run THEN
        -- Core's defaults for a tenant about to get its first Core category from here
        -- (core-platform ec.py DEFAULTS, same ids as 20261108-08).
        INSERT INTO core_platform.cp_expense_categories (tenant_id, id, bus_id, name, icon, position)
        SELECT t.tenant_id, 'expcat-' || md5(t.tenant_id || '/default/' || lower(d.name)), NULL, d.name, d.icon, d.pos
          FROM (SELECT DISTINCT c.tenant_id FROM expenses.exp_categories c
                 WHERE c.archived_at IS NULL
                   AND NOT EXISTS (SELECT 1 FROM core_platform.cp_expense_categories x WHERE x.tenant_id = c.tenant_id)) t
         CROSS JOIN (VALUES ('Rent', 'home', 0), ('Utilities', 'zap', 1), ('Salaries & wages', 'users', 2),
                            ('Transport & fuel', 'truck', 3), ('Travel', 'map', 4), ('Meals & entertainment', 'coffee', 5),
                            ('Office supplies', 'paperclip', 6), ('Repairs & maintenance', 'tool', 7),
                            ('Internet & phone', 'phone', 8), ('Marketing', 'speaker', 9), ('Professional fees', 'briefcase', 10),
                            ('Bank charges', 'credit-card', 11), ('Insurance', 'shield', 12), ('Taxes & licences', 'file-text', 13),
                            ('Other', 'more-horizontal', 14)) AS d(name, icon, pos)
        ON CONFLICT DO NOTHING;

        -- A live Expenses category with no Core category of its name gets one, organisation-wide,
        -- with what it carried (the first made, when several businesses had one of the name).
        INSERT INTO core_platform.cp_expense_categories (tenant_id, id, bus_id, name, description, icon, tax_rate_id,
                                                         account_code, receipt_required, position, created_by, updated_by)
        SELECT DISTINCT ON (c.tenant_id, lower(trim(c.name)))
               c.tenant_id, 'expcat-' || md5(c.tenant_id || '/expenses/' || lower(trim(c.name))), NULL, trim(c.name),
               nullif(trim(c.description), ''), nullif(trim(c.icon), ''), c.tax_rate_id, nullif(trim(c.code), ''),
               c.receipt_required, 100 + c.position, c.created_by, c.created_by
          FROM expenses.exp_categories c
         WHERE c.archived_at IS NULL AND length(trim(c.name)) > 0
           AND NOT EXISTS (SELECT 1 FROM core_platform.cp_expense_categories x
                            WHERE x.tenant_id = c.tenant_id AND lower(trim(x.name)) = lower(trim(c.name))
                              AND (x.bus_id IS NULL OR x.bus_id = c.bus_id))
         ORDER BY c.tenant_id, lower(trim(c.name)), c.cdatetime
        ON CONFLICT DO NOTHING;

        -- The link: this business's Core category of the name first, then the organisation's. One
        -- Expenses row per business and Core category: the live one, else the latest archived.
        WITH m AS (
            SELECT c.id, (SELECT x.id FROM core_platform.cp_expense_categories x
                           WHERE x.tenant_id = c.tenant_id AND lower(trim(x.name)) = lower(trim(c.name))
                             AND (x.bus_id IS NULL OR x.bus_id = c.bus_id)
                           ORDER BY (x.bus_id IS NOT NULL) DESC, x.is_active DESC, x.position, x.id
                           LIMIT 1) AS core_id, c.bus_id, c.archived_at, c.cdatetime
              FROM expenses.exp_categories c
             WHERE c.core_category_id IS NULL
        ), ranked AS (
            SELECT m.id, m.core_id,
                   row_number() OVER (PARTITION BY m.bus_id, m.core_id
                                      ORDER BY (m.archived_at IS NULL) DESC, m.archived_at DESC, m.cdatetime) AS rn
              FROM m WHERE m.core_id IS NOT NULL
        )
        UPDATE expenses.exp_categories c SET core_category_id = r.core_id
          FROM ranked r WHERE r.id = c.id AND r.rn = 1;

        UPDATE expenses.exp_expenses e
           SET core_category_id = c.core_category_id
          FROM expenses.exp_categories c
         WHERE c.id = e.category_id AND e.core_category_id IS NULL AND c.core_category_id IS NOT NULL;
    END IF;

    CREATE UNIQUE INDEX IF NOT EXISTS exp_categories_core_uq
        ON expenses.exp_categories (bus_id, core_category_id) WHERE core_category_id IS NOT NULL;
END
$$;

-- An expense counts under its category's Core category, whichever path saves it.
DO $$
BEGIN
    IF to_regclass('expenses.exp_expenses') IS NULL THEN
        RETURN;
    END IF;
    CREATE OR REPLACE FUNCTION expenses.exp_expense_core_category() RETURNS trigger
    LANGUAGE plpgsql AS $f$
    BEGIN
        IF TG_OP = 'INSERT' OR NEW.category_id IS DISTINCT FROM OLD.category_id THEN
            NEW.core_category_id := CASE WHEN NEW.category_id IS NULL THEN NULL
                ELSE (SELECT k.core_category_id FROM expenses.exp_categories k WHERE k.id = NEW.category_id) END;
        END IF;
        RETURN NEW;
    END
    $f$;
    DROP TRIGGER IF EXISTS exp_expenses_core_category ON expenses.exp_expenses;
    CREATE TRIGGER exp_expenses_core_category BEFORE INSERT OR UPDATE OF category_id ON expenses.exp_expenses
        FOR EACH ROW EXECUTE FUNCTION expenses.exp_expense_core_category();
END
$$;

-- A category as the books need it (20261019-42), now with the Core category it is: Accounting
-- posts every app's spending on one EXPENSE_CATEGORY:<core_category_id> account.
DO $$
BEGIN
    IF to_regclass('expenses.exp_categories') IS NULL THEN
        RETURN;
    END IF;
    CREATE OR REPLACE FUNCTION expenses.exp_acc_category(p_id text) RETURNS jsonb
    LANGUAGE sql STABLE AS $f$
        SELECT coalesce(
            (SELECT jsonb_build_object('category_id', k.id, 'category_name', k.name, 'category_code', nullif(k.code, ''),
                                       'category_kind', k.kind, 'core_category_id', k.core_category_id)
               FROM expenses.exp_categories k WHERE k.id = p_id),
            jsonb_build_object('category_id', NULL, 'category_name', 'Uncategorised', 'category_code', NULL,
                               'category_kind', 'expense', 'core_category_id', NULL))
    $f$;
END
$$;

COMMIT;
