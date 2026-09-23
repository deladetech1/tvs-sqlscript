-- 20260923-05-loandrift-tier-features.sql
-- Which LoanDrift features each subscription tier includes.
--
-- Same model as MyStoreGuard (20260821-02): tiers are cumulative, so each feature
-- carries one number, the lowest tier rank that unlocks it. A business on rank R has
-- every feature whose min_tier_rank <= R. Ranks: 1=BASIC 2=ADVANCE 3=PREMIUM
-- 4=ENTERPRISE, from cp_subscription_platform_limits.
--
-- The offer itself is written up in tvs-loandrift-bk/docs/pricing.md. feature_key is
-- the contract between that document, the LoanDrift API (require_feature in
-- src/utils/plan.py) and the LoanDrift UI (src/data/planFeatures.ts). Renaming one is a
-- breaking change for the others.
--
-- ENTERPRISE unlocks no extra feature: what it adds (unlimited locations, dedicated
-- servers and database, a custom domain) is deployment, not a flag. Its rank still
-- inherits everything below it.
--
-- The cp_business_app_tier / cp_business_app_features views from 20260821-02 already
-- cover every app_id, so no view changes are needed.
--
-- Idempotent; safe to re-run on every deploy.

SET search_path TO core_platform;

INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES

-- ---- BASIC: lend -------------------------------------------------------------------
('loandrift.dashboard',          'app-loandrift', 'Dashboard',                    1, NULL),
('loandrift.clients',            'app-loandrift', 'Clients',                      1, 'Registration, KYC, guarantors, documents, profile photos'),
('loandrift.loans',              'app-loandrift', 'Loans',                        1, 'Registration, capture, approval, disbursement, activation, completion'),
('loandrift.repayments',         'app-loandrift', 'Repayments',                   1, 'Capture and receipts'),
('loandrift.penalties',          'app-loandrift', 'Penalties',                    1, 'Automatic charging on arrears. Waivers are ADVANCE.'),
('loandrift.loan-transactions',  'app-loandrift', 'Loan Transactions',            1, NULL),
('loandrift.calendar',           'app-loandrift', 'Calendar',                     1, NULL),
('loandrift.notifications',      'app-loandrift', 'Notifications',                1, 'Inbox and approvals queue'),
('loandrift.reports',            'app-loandrift', 'Reports',                      1, 'The module and the eight loan-cycle reports; other reports follow their module'),
('loandrift.settings',           'app-loandrift', 'Settings',                     1, 'Company profile, loan types, interest types, sectors, receipt'),
('loandrift.locations',          'app-loandrift', 'Locations',                    1, 'Plumbing: how many is a core-platform cap'),
('loandrift.currencies',         'app-loandrift', 'Currencies',                   1, 'Plumbing'),
('loandrift.files',              'app-loandrift', 'File Uploads',                 1, 'Plumbing'),

-- ---- ADVANCE: run the business -----------------------------------------------------
('loandrift.credit-score',       'app-loandrift', 'Credit Scoring',               2, 'Scores, the model settings, overrides, and the credit score reports'),
('loandrift.collections',        'app-loandrift', 'Collections',                  2, 'Arrears worklist, contact log, promises to pay, collections report'),
('loandrift.savings',            'app-loandrift', 'Savings',                      2, 'Products, accounts, transactions, and the savings reports'),
('loandrift.investments',        'app-loandrift', 'Investments',                  2, 'Products, accounts, transactions, and the investment reports'),
('loandrift.expenses',           'app-loandrift', 'Expenses',                     2, 'Expenses and the expense reports'),
('loandrift.penalty-waivers',    'app-loandrift', 'Penalty Waivers',              2, 'Request, approve and reject waivers'),
('loandrift.penalty-settings',   'app-loandrift', 'Penalty Settings',             2, NULL),
('loandrift.sms',                'app-loandrift', 'SMS Notifications',            2, 'SMS settings'),
('loandrift.online-repayments',  'app-loandrift', 'Online Repayments',            2, 'Payment gateway settings'),
('loandrift.audit-logs',         'app-loandrift', 'Audit Trail',                  2, NULL),
('loandrift.advanced-reports',   'app-loandrift', 'Advanced Loan Reports',        2, 'Disbursement chart, penalty status report'),
('loandrift.report-export',      'app-loandrift', 'Report Export',                2, 'PDF, Excel, Word and CSV downloads of reports'),
('loandrift.report-date-range',  'app-loandrift', 'Report Date Filtering',        2, 'Filtering reports by date range or period'),

-- ---- PREMIUM: account for it and prove it -----------------------------------------
('loandrift.accounting',         'app-loandrift', 'Accounting',                   3, 'Ledger, chart of accounts, journals, statements, fixed assets, prudential report'),
('loandrift.reconciliation',     'app-loandrift', 'Reconciliation',               3, 'Loan and bank reconciliation'),
('loandrift.credit-bureau',      'app-loandrift', 'Credit Bureau',                3, 'Bank of Ghana return, readiness check, CRB export'),
('loandrift.custom-reports',     'app-loandrift', 'Custom Report Builder',        3, NULL)

ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;
