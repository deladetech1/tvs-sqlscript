-- 20261022-85-accounting-plan-features.sql
-- Which Accounting features each subscription tier includes (app-accounting).
--
-- Same model as MyStoreGuard (20260821-02), LoanDrift (20260923-05) and HMS (20261022-61):
-- tiers are cumulative, so a feature carries one number, the lowest tier rank that unlocks
-- it (1=BASIC 2=ADVANCE 3=PREMIUM). ENTERPRISE (4) is the same product self-hosted, not a
-- bigger plan, so nothing here is ever rank 4 (asserted below).
--
-- feature_key is the contract between this file, the Accounting API
-- (tvs-accounting-bk app/src/Shared/Plan/AccountingFeatures.cs, [RequiresFeature]) and the UI
-- (tvs-accounting-ft src/core/plan.ts). Renaming one is a breaking change for the others.
-- Titles and descriptions are read by Core Platform's subscribe page as the plan comparison,
-- so they are written for the customer.
--
-- Downgrading never hides data: what a business already recorded stays readable, and only
-- creating or changing records of a locked feature is refused. Automatic postings from other
-- TroveSuite apps are on every plan: they are governed by Connected apps and by the other
-- app's own subscription, and gating them would leave the books silently incomplete.
--
-- Idempotent; safe to re-run.

BEGIN;

INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
-- ---- BASIC: keep the books ----------------------------------------------------------
('accounting.dashboard',          'app-accounting', 'Dashboard',                                1, 'Cash, money owed to you and by you, and what needs your attention, at a glance'),
('accounting.chart-of-accounts',  'app-accounting', 'Chart of accounts',                        1, 'A ready-made chart of accounts you can extend with your own'),
('accounting.journals',           'app-accounting', 'Journals and general ledger',              1, 'Manual journals with approval and reversal, and every account''s ledger'),
('accounting.sales',              'app-accounting', 'Invoices, receipts and credit notes',      1, 'Bill customers, record what they pay and issue credit notes'),
('accounting.purchases',          'app-accounting', 'Bills, payments and supplier credits',     1, 'Record supplier bills, pay them and track supplier credits'),
('accounting.banking',            'app-accounting', 'Bank accounts and transfers',              1, 'Every bank and cash account, with transfers between them'),
('accounting.reconciliation',     'app-accounting', 'Bank reconciliation',                      1, 'Import bank statements and match every line to the books'),
('accounting.tax',                'app-accounting', 'VAT and tax',                              1, 'Your Core Platform taxes on every line, with a tax summary report'),
('accounting.reports',            'app-accounting', 'Financial statements',                     1, 'Trial balance, profit and loss, balance sheet, cash flow, ageing and customer and supplier statements'),
('accounting.opening-balances',   'app-accounting', 'Opening balances',                         1, 'Start from the balances of your previous system'),
('accounting.periods',            'app-accounting', 'Fiscal years and period locking',          1, 'Close periods and years so posted figures cannot change'),
('accounting.imports',            'app-accounting', 'Spreadsheet imports',                      1, 'Bring invoices, bills and journals in from a spreadsheet'),
('accounting.app-postings',       'app-accounting', 'Automatic postings from your other apps',  1, 'Sales, loans, payroll, expenses, invoices and projects from your other TroveSuite apps post themselves'),
-- ---- ADVANCE: run the books on autopilot --------------------------------------------
('accounting.recurring',          'app-accounting', 'Recurring invoices and bills',             2, 'Templates that issue invoices and bills on schedule by themselves'),
('accounting.fixed-assets',       'app-accounting', 'Fixed assets and depreciation',            2, 'An asset register with automatic monthly depreciation and disposals'),
('accounting.budgets',            'app-accounting', 'Budgets vs actual',                        2, 'Monthly budgets by account, with versions, approval and variance against actual'),
('accounting.custom-fields',      'app-accounting', 'Custom fields',                            2, 'Your own fields on invoices, bills, customers, suppliers and more'),
('accounting.dimensions',         'app-accounting', 'Departments and cost centres',             2, 'Tag lines by department, cost centre or project and report on them'),
('accounting.accounting-rules',   'app-accounting', 'Accounting rules',                         2, 'Rules that code imported lines to the right accounts automatically'),
-- ---- PREMIUM: international, analytical, auditable ----------------------------------
('accounting.multi-currency',     'app-accounting', 'Multi-currency',                           3, 'Invoices, bills, bank accounts and journals in foreign currencies, with exchange rates'),
('accounting.fx-revaluation',     'app-accounting', 'Currency revaluation',                     3, 'Month-end revaluation of foreign balances, with unrealised gains and losses'),
('accounting.asset-revaluation',  'app-accounting', 'Asset revaluation',                        3, 'Revalue fixed assets to fair value, with a revaluation surplus (IAS 16)'),
('accounting.project-profitability','app-accounting','Project profitability',                   3, 'Income, costs and margin for every project'),
('accounting.audit-trail',        'app-accounting', 'Audit trail',                              3, 'Who changed what in the books, and when')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

-- Invariants, whatever later files add.
DO $$
DECLARE n integer;
BEGIN
    -- ENTERPRISE is self-hosted, not a bigger plan: a rank-4 feature is one nobody hosted can buy.
    SELECT count(*) INTO n FROM core_platform.cp_app_feature_catalog
     WHERE app_id = 'app-accounting' AND is_active AND min_tier_rank > 3;
    IF n > 0 THEN
        RAISE EXCEPTION '% Accounting feature(s) are gated at ENTERPRISE; cap min_tier_rank at 3', n;
    END IF;

    -- The keys the API gates on must exist and be live, or the API falls back to its own copy.
    SELECT count(*) INTO n
      FROM unnest(ARRAY['accounting.recurring','accounting.fixed-assets','accounting.budgets',
                        'accounting.custom-fields','accounting.dimensions','accounting.accounting-rules',
                        'accounting.multi-currency','accounting.fx-revaluation','accounting.asset-revaluation',
                        'accounting.project-profitability','accounting.audit-trail']) AS k(key)
     WHERE NOT EXISTS (SELECT 1 FROM core_platform.cp_app_feature_catalog f
                        WHERE f.feature_key = k.key AND f.app_id = 'app-accounting' AND f.is_active);
    IF n > 0 THEN
        RAISE EXCEPTION '% gated Accounting feature(s) are missing from the catalogue', n;
    END IF;

    -- Automatic postings stay on every plan (see header).
    IF EXISTS (SELECT 1 FROM core_platform.cp_app_feature_catalog
                WHERE feature_key = 'accounting.app-postings' AND min_tier_rank <> 1) THEN
        RAISE EXCEPTION 'accounting.app-postings must stay on BASIC';
    END IF;

    -- Every Accounting row says something to the customer on the subscribe page.
    IF EXISTS (SELECT 1 FROM core_platform.cp_app_feature_catalog
                WHERE app_id = 'app-accounting' AND is_active
                  AND (btrim(coalesce(description, '')) = '' OR feature_key NOT LIKE 'accounting.%')) THEN
        RAISE EXCEPTION 'an Accounting feature has no description or is not keyed accounting.*';
    END IF;

    SELECT count(*) INTO n FROM core_platform.cp_app_feature_catalog WHERE app_id = 'app-accounting' AND is_active;
    RAISE NOTICE 'Accounting plan features: % live', n;
END $$;

COMMIT;
