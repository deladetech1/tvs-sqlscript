-- Expenses categories hand their tax and code to the Core category they were linked to.
--
-- 20261108-12 linked each Expenses category (expenses.exp_categories) to the Core Platform
-- category of its name, and from then on the Core category's tax and accounting code are what
-- Expenses uses. Where a linked Core category had NO tax (tax_rate_id NULL) or NO code
-- (account_code NULL), the Expenses category's own is copied into Core, so a tax default or code
-- set in Expenses is not lost. A value Core has is never overwritten. The tax is copied only when
-- the rate is one of the same tenant's (cp_tax_rates.tenant_id). When several businesses' rows
-- link to one Core category, the first made with a value gives it (live rows before archived).
--
-- Runs ONCE: the fill is marked on the index exp_categories_core_uq, so a tax or code someone
-- later clears in the hub stays cleared. Counts are printed (NOTICE) before and after.
--
-- Idempotent; safe to re-run on every deploy. A database without the link (no 20261108-12, no
-- Expenses app) skips it.

BEGIN;

DO $$
DECLARE
    marker constant text := 'expenses tax/code filled into Core (20261108-13)';
    tax_before int; code_before int; tax_filled int; code_filled int; tax_after int; code_after int;
BEGIN
    IF to_regclass('expenses.exp_categories_core_uq') IS NULL OR to_regclass('core_platform.cp_expense_categories') IS NULL
       OR to_regclass('core_platform.cp_tax_rates') IS NULL THEN
        RAISE NOTICE 'expenses tax/code to core: no Expenses-to-Core link here, nothing to do';
        RETURN;
    END IF;
    IF coalesce(obj_description('expenses.exp_categories_core_uq'::regclass, 'pg_class'), '') = marker THEN
        RAISE NOTICE 'expenses tax/code to core: already done, nothing to do';
        RETURN;
    END IF;

    -- What would be filled: a linked Core category with none, and an Expenses row with one.
    SELECT count(*) INTO tax_before FROM core_platform.cp_expense_categories x
     WHERE x.tax_rate_id IS NULL AND EXISTS (
           SELECT 1 FROM expenses.exp_categories k JOIN core_platform.cp_tax_rates t ON t.id = k.tax_rate_id AND t.tenant_id = x.tenant_id
            WHERE k.tenant_id = x.tenant_id AND k.core_category_id = x.id);
    SELECT count(*) INTO code_before FROM core_platform.cp_expense_categories x
     WHERE x.account_code IS NULL AND EXISTS (
           SELECT 1 FROM expenses.exp_categories k
            WHERE k.tenant_id = x.tenant_id AND k.core_category_id = x.id AND length(trim(k.code)) > 0);
    RAISE NOTICE 'expenses tax/code to core: before: % Core categories to get a tax, % to get a code', tax_before, code_before;

    UPDATE core_platform.cp_expense_categories x
       SET tax_rate_id = s.tax_rate_id, updated_at = now()
      FROM (SELECT DISTINCT ON (k.tenant_id, k.core_category_id) k.tenant_id, k.core_category_id, k.tax_rate_id
              FROM expenses.exp_categories k
              JOIN core_platform.cp_tax_rates t ON t.id = k.tax_rate_id AND t.tenant_id = k.tenant_id
             WHERE k.core_category_id IS NOT NULL
             ORDER BY k.tenant_id, k.core_category_id, (k.archived_at IS NULL) DESC, k.cdatetime, k.id) s
     WHERE x.tenant_id = s.tenant_id AND x.id = s.core_category_id AND x.tax_rate_id IS NULL;
    GET DIAGNOSTICS tax_filled = ROW_COUNT;

    UPDATE core_platform.cp_expense_categories x
       SET account_code = s.code, updated_at = now()
      FROM (SELECT DISTINCT ON (k.tenant_id, k.core_category_id) k.tenant_id, k.core_category_id, left(trim(k.code), 40) AS code
              FROM expenses.exp_categories k
             WHERE k.core_category_id IS NOT NULL AND length(trim(k.code)) > 0
             ORDER BY k.tenant_id, k.core_category_id, (k.archived_at IS NULL) DESC, k.cdatetime, k.id) s
     WHERE x.tenant_id = s.tenant_id AND x.id = s.core_category_id AND x.account_code IS NULL;
    GET DIAGNOSTICS code_filled = ROW_COUNT;

    SELECT count(*) INTO tax_after FROM core_platform.cp_expense_categories x
     WHERE x.tax_rate_id IS NULL AND EXISTS (
           SELECT 1 FROM expenses.exp_categories k JOIN core_platform.cp_tax_rates t ON t.id = k.tax_rate_id AND t.tenant_id = x.tenant_id
            WHERE k.tenant_id = x.tenant_id AND k.core_category_id = x.id);
    SELECT count(*) INTO code_after FROM core_platform.cp_expense_categories x
     WHERE x.account_code IS NULL AND EXISTS (
           SELECT 1 FROM expenses.exp_categories k
            WHERE k.tenant_id = x.tenant_id AND k.core_category_id = x.id AND length(trim(k.code)) > 0);
    RAISE NOTICE 'expenses tax/code to core: filled % taxes and % codes; after: % without a tax, % without a code',
        tax_filled, code_filled, tax_after, code_after;

    EXECUTE format('COMMENT ON INDEX expenses.exp_categories_core_uq IS %L', marker);
END
$$;

COMMIT;
