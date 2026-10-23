-- What each plan includes in the CRM, Projects, Invoicing and Expenses.
--
-- Until now these four apps differed by plan only in how many users they allow. From here
-- each tier is a clearly bigger product:
--
--   BASIC   (1)  the core job, done well
--   ADVANCE (2)  automation and scale
--   PREMIUM (3)  advanced tools, links to the rest of TroveSuite, audit
--   ENTERPRISE (4) is the same product SELF-HOSTED: it includes everything PREMIUM does and
--   never gates a feature on its own. Nothing here is rank 4 (asserted below).
--
-- Tiers are cumulative (20260821-02): a business on rank R has every feature whose
-- min_tier_rank <= R, read through core_platform.cp_business_app_features.
--
-- feature_key is the contract between this file, the API (tvs-shared-apps-bk: the route
-- rules in internal/apps/<app>/plan.go and internal/platform/entitle) and each frontend's
-- padlocks (GET /<app>/v1/plan). title and description are shown to CUSTOMERS on the Core
-- Platform plan comparison, so they say what the feature does for them, not how it is built.
--
-- Rank 1 rows are listed so the plan page shows the whole offer; the API does not gate them.
-- Downgrading never deletes anything: a locked feature keeps what was made with it readable,
-- only creating and changing stop (and its background work pauses).
--
-- Idempotent: re-runs on every deploy; a later edit to a row here wins.

BEGIN;

INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
-- =============================================================================== CRM
-- ---- BASIC: run your sales ---------------------------------------------------------
('crm.contacts',          'app-crm', 'Contacts & Companies',            1, 'Everyone you sell to, with their full history in one place'),
('crm.leads',             'app-crm', 'Leads',                           1, 'Capture, qualify and convert new leads'),
('crm.deals',             'app-crm', 'Deals & Sales Pipeline',          1, 'A drag-and-drop deal board with stages, won and lost reasons'),
('crm.activities',        'app-crm', 'Tasks, Calls & Meetings',         1, 'Follow-ups, reminders and a shared calendar'),
('crm.quotes',            'app-crm', 'Quotes & Online Payment',         1, 'Send quotes your customers accept and pay online'),
('crm.products',          'app-crm', 'Products & Price List',           1, 'The products and services you sell, with prices and taxes'),
('crm.documents',         'app-crm', 'Documents',                       1, 'Keep and share files on every customer and deal'),
('crm.import-export',     'app-crm', 'Import & Export',                 1, 'Bring contacts in from a spreadsheet and take them out again'),
('crm.reports',           'app-crm', 'Standard Reports',                1, 'Ready-made sales, pipeline and activity reports'),
-- ---- ADVANCE: automate and grow ----------------------------------------------------
('crm.pipelines',         'app-crm', 'Multiple Pipelines',              2, 'Separate pipelines for each product line, team or process'),
('crm.segments',          'app-crm', 'Segments',                        2, 'Saved customer lists that keep themselves up to date'),
('crm.custom-fields',     'app-crm', 'Custom Fields',                   2, 'Record the details that matter to your business'),
('crm.lead-assignment',   'app-crm', 'Automatic Lead Assignment',       2, 'Share new leads out to your team automatically'),
('crm.duplicates',        'app-crm', 'Duplicate Finder & Merge',        2, 'Find the same customer entered twice and merge them'),
('crm.messaging',         'app-crm', 'Email & SMS from the CRM',        2, 'Message customers from their record, with reusable templates'),
('crm.tickets',           'app-crm', 'Help Desk & Tickets',             2, 'Customer support tickets, replies, categories and saved answers'),
('crm.forecast',          'app-crm', 'Sales Forecast & Targets',        2, 'What you expect to close, and targets for every rep'),
('crm.scheduled-reports', 'app-crm', 'Scheduled Report Emails',         2, 'Reports delivered to your inbox every day, week or month'),
('crm.report-export',     'app-crm', 'Report Export',                   2, 'Download any report to a spreadsheet'),
-- ---- PREMIUM: the whole customer picture -------------------------------------------
('crm.campaigns',         'app-crm', 'Email & SMS Campaigns',           3, 'Send marketing campaigns to whole segments, with opt-outs handled'),
('crm.customer-sync',     'app-crm', 'MyStoreGuard & LoanDrift Sync',   3, 'Customers from your shop and your loan book, kept in step automatically (needs that app too)'),
('crm.project-links',     'app-crm', 'Linked Projects',                 3, 'See the projects and work behind every deal and ticket (needs Projects too)'),
('crm.audit-trail',       'app-crm', 'Audit Trail & Activity Feed',     3, 'Who changed what, and when, across the whole CRM'),

-- ========================================================================== PROJECTS
-- ---- BASIC: plan and do the work ---------------------------------------------------
('projects.projects',       'app-projects', 'Projects, Boards & Lists',     1, 'Kanban boards, lists, folders and a backlog for every project'),
('projects.tasks',          'app-projects', 'Tasks, Subtasks & Checklists', 1, 'Assign work, set due dates, comment and track progress'),
('projects.sprints',        'app-projects', 'Sprints',                      1, 'Plan work in sprints and run them to the finish'),
('projects.docs',           'app-projects', 'Docs & Wiki',                  1, 'Write, share and version your team''s knowledge'),
('projects.files',          'app-projects', 'Files',                        1, 'Keep files with the work they belong to'),
('projects.chat',           'app-projects', 'Team Chat',                    1, 'Talk about the work where the work is'),
('projects.calendar',       'app-projects', 'Calendar & My Work',           1, 'Everything due, for you and your team, in one view'),
('projects.imports',        'app-projects', 'Imports',                      1, 'Move in from spreadsheets, Jira, Asana, Trello or monday.com'),
('projects.reminders',      'app-projects', 'Due-date Reminders',           1, 'Reminders before work is due and when it is late'),
-- ---- ADVANCE: automate and organise ------------------------------------------------
('projects.workspaces',     'app-projects', 'Multiple Workspaces',          2, 'Separate workspaces for each team, client or department'),
('projects.custom-fields',  'app-projects', 'Custom Fields',                2, 'Add your own fields to work items'),
('projects.views',          'app-projects', 'Saved Views & Advanced Filters', 2, 'Powerful filters and queries, saved and shared'),
('projects.automations',    'app-projects', 'Automations',                  2, 'Rules that move, assign and notify for you'),
('projects.approvals',      'app-projects', 'Approvals',                    2, 'Work that needs sign-off before it can be done'),
('projects.templates',      'app-projects', 'Templates',                    2, 'Reusable task and project templates'),
('projects.time-tracking',  'app-projects', 'Time Tracking & Timesheets',   2, 'Timers, logged hours and weekly timesheets'),
('projects.timeline',       'app-projects', 'Timeline & Roadmap',           2, 'Gantt timelines and a roadmap across projects'),
('projects.forms',          'app-projects', 'Forms',                        2, 'Public forms that turn answers into work items'),
('projects.whiteboards',    'app-projects', 'Whiteboards',                  2, 'Sketch, plan and brainstorm together'),
('projects.milestones',     'app-projects', 'Milestones & Status Updates',  2, 'Milestones, project health and weekly status updates'),
('projects.agile-reports',  'app-projects', 'Velocity & Flow Reports',      2, 'Burndown, velocity and cumulative flow'),
-- ---- PREMIUM: run the portfolio ----------------------------------------------------
('projects.workload',       'app-projects', 'Workload & Capacity',          3, 'See who is over or under loaded, including leave from ZelosHR'),
('projects.goals',          'app-projects', 'Goals & OKRs',                 3, 'Objectives and key results linked to the work'),
('projects.dashboards',     'app-projects', 'Custom Dashboards',            3, 'Build your own dashboards from any work query'),
('projects.money',          'app-projects', 'Budgets, Rates & Client Billing', 3, 'Billable time, rates, budgets, project expenses and invoices'),
('projects.client-portal',  'app-projects', 'Client Portal & Public Sharing', 3, 'Let clients follow progress and review work; share docs publicly'),
('projects.suite-links',    'app-projects', 'CRM, MyStoreGuard & LoanDrift Links', 3, 'Start projects from won deals and link work to tickets, loans and store tasks (needs that app too)'),

-- ========================================================================= INVOICING
-- ---- BASIC: bill and get paid ------------------------------------------------------
('invoicing.invoices',        'app-invoicing', 'Invoices',                    1, 'Create, send and track professional invoices'),
('invoicing.quotes',          'app-invoicing', 'Quotes & Estimates',          1, 'Quotes customers accept online, turned into invoices in one click'),
('invoicing.customers',       'app-invoicing', 'Customers & Items',           1, 'Your customers and the products and services you sell'),
('invoicing.online-payments', 'app-invoicing', 'Online Payments',             1, 'Customers pay by card or mobile money from the invoice link'),
('invoicing.payments',        'app-invoicing', 'Payments & Receipts',         1, 'Record payments and send receipts'),
('invoicing.credit-notes',    'app-invoicing', 'Credit Notes & Refunds',      1, 'Credit notes and refunds that keep your books straight'),
('invoicing.taxes',           'app-invoicing', 'Taxes for Any Country',       1, 'VAT, GST, sales tax, withholding and exemptions'),
('invoicing.designs',         'app-invoicing', 'Invoice Designs & PDF',       1, 'Ready-made designs in 80 languages, sent as PDF'),
('invoicing.reports',         'app-invoicing', 'Standard Reports',            1, 'Sales, unpaid invoices, aging and tax reports'),
-- ---- ADVANCE: automate getting paid ------------------------------------------------
('invoicing.recurring',       'app-invoicing', 'Recurring Invoices',          2, 'Invoices created and sent automatically on a schedule'),
('invoicing.reminders',       'app-invoicing', 'Automatic Payment Reminders', 2, 'Polite reminders before and after the due date'),
('invoicing.late-fees',       'app-invoicing', 'Late Fees',                   2, 'Charge a late fee automatically on overdue invoices'),
('invoicing.multi-currency',  'app-invoicing', 'Multiple Currencies',         2, 'Invoice in your customers'' currencies with exchange rates'),
('invoicing.payment-schedules','app-invoicing','Deposits & Instalments',      2, 'Split an invoice into a deposit and instalments'),
('invoicing.statements',      'app-invoicing', 'Customer Statements & Portal', 2, 'Statements of account and a portal for each customer'),
('invoicing.purchase-orders', 'app-invoicing', 'Purchase Orders',             2, 'Order from suppliers and track what was received'),
('invoicing.attachments',     'app-invoicing', 'File Attachments',            2, 'Attach timesheets, photos or contracts to any document'),
('invoicing.exports',         'app-invoicing', 'Exports & Accounting Software', 2, 'Spreadsheet exports and files for Xero, QuickBooks and Sage'),
('invoicing.imports',         'app-invoicing', 'Import from MyStoreGuard & LoanDrift', 2, 'Bring in customers and products you already have (needs that app too)'),
-- ---- PREMIUM: advanced billing -----------------------------------------------------
('invoicing.contracts',       'app-invoicing', 'Contracts & E-signatures',    3, 'Send contracts customers sign online, with a full signing record'),
('invoicing.custom-templates','app-invoicing', 'Custom Templates',            3, 'Design your own invoice and quote templates'),
('invoicing.bank-reconciliation','app-invoicing','Bank Reconciliation',       3, 'Match bank statement lines to payments automatically'),
('invoicing.e-invoicing',     'app-invoicing', 'E-invoicing',                 3, 'Peppol, ZATCA and India e-invoices'),
('invoicing.saved-cards',     'app-invoicing', 'Saved Cards & Autopay',       3, 'Charge a customer''s saved card when an invoice is due'),
('invoicing.mystoreguard',    'app-invoicing', 'MyStoreGuard Invoices & Orders', 3, 'Collect MyStoreGuard invoices and purchase orders here (needs MyStoreGuard too)'),
('invoicing.billable-work',   'app-invoicing', 'Bill Project Time & Expenses', 3, 'Invoice hours from Projects and expenses from Expenses (needs that app too)'),
('invoicing.activity-log',    'app-invoicing', 'Activity Log',                3, 'Every change across Invoicing, who made it and when'),

-- ========================================================================== EXPENSES
-- ---- BASIC: claim and reimburse ----------------------------------------------------
('expenses.expenses',         'app-expenses', 'Expenses & Receipts',         1, 'Record spending and keep every receipt'),
('expenses.claims',           'app-expenses', 'Claims & Approval',           1, 'Submit claims and have them approved'),
('expenses.reimbursements',   'app-expenses', 'Reimbursements',              1, 'Pay people back by mobile money, bank or by hand'),
('expenses.categories',       'app-expenses', 'Categories',                  1, 'Your own spending categories'),
('expenses.reports',          'app-expenses', 'Standard Reports',            1, 'Spending by person, category and month'),
-- ---- ADVANCE: control spending -----------------------------------------------------
('expenses.approval-workflows','app-expenses','Multi-step Approvals',        2, 'Approval routes through managers, department heads and finance'),
('expenses.policies',         'app-expenses', 'Spending Policies',           2, 'Limits and rules checked on every expense'),
('expenses.mileage',          'app-expenses', 'Mileage & Per Diem',          2, 'Claim distance travelled and daily allowances at your rates'),
('expenses.requests',         'app-expenses', 'Spend Requests',              2, 'Ask before spending and get approval up front'),
('expenses.advances',         'app-expenses', 'Cash Advances',               2, 'Pay advances and settle them against claims'),
('expenses.budgets',          'app-expenses', 'Budgets & Alerts',            2, 'Budgets with warnings and hard stops'),
('expenses.exports',          'app-expenses', 'Exports',                     2, 'Download your expenses for your accountant or software'),
-- ---- PREMIUM: finance automation ---------------------------------------------------
('expenses.bills',            'app-expenses', 'Supplier Bills',              3, 'Record, approve and pay supplier bills, including repeat bills'),
('expenses.statements',       'app-expenses', 'Card & Bank Statement Matching', 3, 'Import statements and match every line to an expense'),
('expenses.insights',         'app-expenses', 'Spend Insights',              3, 'Recurring costs, forecasts and tax you can reclaim'),
('expenses.receipt-reading',  'app-expenses', 'Automatic Receipt Reading',   3, 'Receipts read for you: amount, date, supplier and tax'),
('expenses.payroll',          'app-expenses', 'Reimburse Through Payroll',   3, 'Add reimbursements to the next ZelosHR payroll (needs ZelosHR too)')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

-- ===================================================================== invariants
DO $$
DECLARE bad text;
BEGIN
    -- ENTERPRISE is self-hosted PREMIUM: a rank-4 feature is sold to nobody.
    SELECT string_agg(feature_key, ', ') INTO bad FROM core_platform.cp_app_feature_catalog
     WHERE app_id IN ('app-crm', 'app-projects', 'app-invoicing', 'app-expenses') AND min_tier_rank > 3;
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'feature(s) gated at ENTERPRISE, which buys no features: %', bad;
    END IF;
    -- Every key names its own app: crm.* is app-crm, and nothing of app-crm is named otherwise.
    SELECT string_agg(feature_key || ' (' || app_id || ')', ', ') INTO bad FROM core_platform.cp_app_feature_catalog
     WHERE (app_id IN ('app-crm', 'app-projects', 'app-invoicing', 'app-expenses')
            OR feature_key ~ '^(crm|projects|invoicing|expenses)\.')
       AND split_part(feature_key, '.', 1) <> substring(app_id FROM '^app-(.+)$');
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'feature key(s) not prefixed by their app: %', bad;
    END IF;
    -- Customers read these on the plan comparison: no blank titles or descriptions.
    SELECT string_agg(feature_key, ', ') INTO bad FROM core_platform.cp_app_feature_catalog
     WHERE app_id IN ('app-crm', 'app-projects', 'app-invoicing', 'app-expenses')
       AND (btrim(title) = '' OR btrim(coalesce(description, '')) = '');
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'feature(s) without a customer-facing title or description: %', bad;
    END IF;
    -- Each app sells something at every hosted tier, so each step up is worth paying for.
    SELECT string_agg(a.app_id || ' rank ' || r.rank, ', ') INTO bad
      FROM (VALUES ('app-crm'), ('app-projects'), ('app-invoicing'), ('app-expenses')) AS a(app_id)
     CROSS JOIN (VALUES (1), (2), (3)) AS r(rank)
     WHERE NOT EXISTS (SELECT 1 FROM core_platform.cp_app_feature_catalog f
                        WHERE f.app_id = a.app_id AND f.min_tier_rank = r.rank AND f.is_active);
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'no active feature at: %', bad;
    END IF;
END $$;

COMMIT;
