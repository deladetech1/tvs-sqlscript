-- =====================================================================
-- The CRM and Projects pick their taxes from Core Platform
-- ---------------------------------------------------------------------
-- Core Platform is the ONE place a tax is defined (core_platform.cp_tax_rates,
-- 20261019-24; owner's decision 2026-10-19, 20261019-47). Invoicing and
-- MyStoreGuard already point at Core's taxes. The CRM (product, deal and quote
-- lines) and Projects (an invoice's tax) still had a percentage typed by hand.
-- From now on their screens pick one of the business's Core taxes, and the
-- document keeps BOTH:
--
--   tax_rate_id   the Core tax picked (same id for ever; NULL = none picked,
--                 which is every row written before this file)
--   tax_rate      (existing column) the percentage as it was when saved: the
--                 history. A later change of rate in Core never rewrites a sent
--                 quote or invoice.
--
-- Existing rows keep their typed percentage untouched, with no tax_rate_id: no
-- guessing which Core tax a typed "15" meant.
--
--   * crm.crm_deal_lines, crm.crm_quote_lines, projects.prj_invoices: a column.
--   * crm.crm_products is a VIEW (20261019-31, re-created on every deploy with
--     CREATE OR REPLACE, so it must keep its columns). The column goes on the
--     table under it, crm.crm_product_settings, which the CRM writes directly;
--     the view's trigger updates named columns only, so it never clears it.
--
-- The keys are ON DELETE SET NULL: Core refuses to delete a tax still in use
-- (it lists these columns), and if one goes anyway the snapshot rate stays.
-- Each table is touched only where it exists (a silo without the CRM).
-- Re-runs every deploy: idempotent.
-- =====================================================================
BEGIN;

DO $$
DECLARE
    t record;
BEGIN
    IF to_regclass('core_platform.cp_tax_rates') IS NULL THEN
        RETURN;
    END IF;
    FOR t IN SELECT * FROM (VALUES
                 ('crm.crm_deal_lines',        'crm_deal_lines_cp_tax_fk'),
                 ('crm.crm_quote_lines',       'crm_quote_lines_cp_tax_fk'),
                 ('crm.crm_product_settings',  'crm_product_settings_cp_tax_fk'),
                 ('projects.prj_invoices',     'prj_invoices_cp_tax_fk')) v(tbl, fk) LOOP
        IF to_regclass(t.tbl) IS NULL
           OR (SELECT relkind FROM pg_class WHERE oid = to_regclass(t.tbl)) <> 'r' THEN
            CONTINUE;
        END IF;
        EXECUTE format('ALTER TABLE %s ADD COLUMN IF NOT EXISTS tax_rate_id text', t.tbl);
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = to_regclass(t.tbl) AND conname = t.fk) THEN
            EXECUTE format('ALTER TABLE %s ADD CONSTRAINT %I FOREIGN KEY (tax_rate_id) REFERENCES core_platform.cp_tax_rates (id) ON DELETE SET NULL',
                           t.tbl, t.fk);
        END IF;
        -- Core's "where is this tax used" and its delete check look it up by (tenant, tax).
        EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON %s (tenant_id, tax_rate_id) WHERE tax_rate_id IS NOT NULL',
                       replace(t.fk, '_cp_tax_fk', '_tax_rate_idx'), t.tbl);
    END LOOP;
END $$;

COMMIT;
