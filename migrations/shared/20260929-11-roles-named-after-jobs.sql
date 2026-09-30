-- Roles named after the job, not the screen
--
-- 87 of 119 roles were called "<App> <Thing> Admin" -- Mystoreguard Invoice Admin, Loandrift
-- Calender Admin, ZelosHR Lifecycle Admin. That names the screen somebody opens, not the
-- person doing the work, so staffing a store meant stacking six "Admin" roles onto one
-- person and hoping the set added up.
--
-- LoanDrift already showed the answer: Loan Officer, Cashier, Credit Risk Analyst, Collections
-- Manager, Call Centre Agent. Real jobs, each spanning the resources that job touches. This
-- brings the other two apps and Core Platform to the same footing, and drops the app name from
-- the front, because the role picker already groups by app and "Loandrift Cashier" reads as a
-- kind of Cashier that only exists in one product.
--
-- The prefix cannot simply be stripped: cp_roles has a unique index on (tenant_id, role_name),
-- and three roles were called "<App> Viewer Admin", three "<App> Reports Admin", two "File
-- Admin" and two "Settings Admin". Those are named for what they view or administer instead --
-- Store Viewer, Loan Book Viewer, Platform Viewer -- which is what the prefix was standing in
-- for anyway.
--
-- This is only safe because 20260929-10 dropped the auto-assign triggers. Until then a role's
-- NAME decided its permissions: 'Admin' exactly, LIKE '%Viewer Admin%', LIKE '%Store Sales
-- Personnel%'. Renaming Mystoreguard Viewer Admin to Store Viewer would have silently stopped
-- it gaining reads, and renaming Store Sales Personnel would have started it gaining writes it
-- was explicitly excluded from. Nothing reads a role name to decide anything any more.
--
-- Two names carried a real distinction that the old ones hid. 'Admin' and 'Core Platform
-- Admin' read as the same thing and are not: one covers every app, the other only Core
-- Platform. They become Suite Administrator and Platform Administrator.
--
-- MyStoreGuard's descriptions are rewritten too. Every one of them said "Administrator for X
-- management", which describes the screen again and tells a person choosing a role nothing.
-- LoanDrift's already said what the job does and are left alone.
--
-- Loandrift Calender Admin's misspelling goes with it. The resource_key `calender` is still
-- misspelled in the catalogue and is a separate change, since ids depend on it.
--
-- Tenant-created roles are untouched. They belong to the customer, not to us.
--
-- Cross-app grants are removed in the same pass. No role may hold another app's permissions:
-- a MyStoreGuard role could read LoanDrift's reports and a LoanDrift role could read
-- MyStoreGuard's. Core Platform Viewer Admin had collected reads across both apps, and File
-- Admin and Location Admin reached into LoanDrift -- all residue from the viewer reconcile
-- that 20260929-10 removed. Of the seven roles affected only Location Admin is assigned to
-- anybody, and it loses one read: LoanDrift locations, which a LoanDrift role should grant.
-- The `cp`-prefixed file permissions stay: that prefix exists precisely so file and log verbs
-- can be shared, and they are Core Platform's own.

BEGIN;

-- ------------------------------------------------------------------ cross-app grants removed
DELETE FROM core_platform.cp_role_permissions rp
 USING core_platform.cp_roles r
 WHERE r.id = rp.role_id
   AND (r.role_name, rp.permission_id) IN (
         ('Loandrift Reports Admin', 'permission-msg-reports-get'),
         ('Mystoreguard Reports Admin', 'permission-loandrift-reports-get'),
         ('Mystoreguard Viewer Admin', 'permission-loandrift-reports-get'),
         ('Core Platform Viewer Admin', 'permission-loandrift-groups-get'),
         ('Core Platform Viewer Admin', 'permission-loandrift-locations-get'),
         ('Core Platform Viewer Admin', 'permission-loandrift-logs-get'),
         ('Core Platform Viewer Admin', 'permission-msg-logs-get'),
         ('File Admin', 'permission-loandrift-file-delete'),
         ('File Admin', 'permission-loandrift-file-list-documents'),
         ('File Admin', 'permission-loandrift-file-update'),
         ('File Admin', 'permission-loandrift-file-upload-multiple'),
         ('Location Admin', 'permission-loandrift-locations-get'),
         ('Reports Admin', 'permission-loandrift-reports-get'),
         ('Reports Admin', 'permission-msg-reports-get')
       );

-- ------------------------------------------------------------------------------- the renames
UPDATE core_platform.cp_roles AS r
   SET role_name = v.new_name
  FROM (VALUES
         ('Admin', 'Suite Administrator'),
         ('App Admin', 'App Catalogue Administrator'),
         ('Billing Admin', 'Billing Administrator'),
         ('Business Admin', 'Business Administrator'),
         ('Business App Admin', 'App Subscription Administrator'),
         ('Core Platform Admin', 'Platform Administrator'),
         ('Core Platform Viewer Admin', 'Platform Viewer'),
         ('Expense Admin', 'Expense Administrator'),
         ('File Admin', 'File Administrator'),
         ('Group Admin', 'Group Administrator'),
         ('Loandrift Accounting Admin', 'Accounting Officer'),
         ('Loandrift Admin', 'LoanDrift Administrator'),
         ('Loandrift Agreements Admin', 'Loan Agreements Officer'),
         ('Loandrift Approval Admin', 'Loan Approver'),
         ('Loandrift Branch Manager', 'Branch Manager'),
         ('Loandrift Calender Admin', 'Repayment Calendar Manager'),
         ('Loandrift Call Center Agent', 'Call Centre Agent'),
         ('Loandrift Capturing Admin', 'Loan Data Capture Clerk'),
         ('Loandrift Cashier', 'Cashier'),
         ('Loandrift Client Admin', 'Client Records Officer'),
         ('Loandrift Collateral Admin', 'Collateral Officer'),
         ('Loandrift Collections Admin', 'Collections Supervisor'),
         ('Loandrift Collections Manager', 'Collections Manager'),
         ('Loandrift Collections Officer', 'Collections Officer'),
         ('Loandrift Compliance Officer', 'Compliance Officer'),
         ('Loandrift Credit Manager', 'Credit Manager'),
         ('Loandrift Credit Risk Analyst', 'Credit Risk Analyst'),
         ('Loandrift Credit Score Admin', 'Credit Scoring Officer'),
         ('Loandrift Dashboard Admin', 'LoanDrift Dashboard Viewer'),
         ('Loandrift Disbursement Admin', 'Disbursement Officer'),
         ('Loandrift Expense Admin', 'Expense Officer'),
         ('Loandrift File Admin', 'Loan Document Controller'),
         ('Loandrift Finance Manager', 'Finance Manager'),
         ('Loandrift Finance Officer', 'Finance Officer'),
         ('Loandrift Internal Auditor', 'Internal Auditor'),
         ('Loandrift Investment Admin', 'Investment Officer'),
         ('Loandrift Loan Officer', 'Loan Officer'),
         ('Loandrift Loan Registration Admin', 'Loan Registration Clerk'),
         ('Loandrift Penalty Admin', 'Penalty Administrator'),
         ('Loandrift Repayment Admin', 'Repayments Officer'),
         ('Loandrift Reports Admin', 'Loan Reports Viewer'),
         ('Loandrift Sales Executive', 'Sales Executive'),
         ('Loandrift Savings Admin', 'Savings Officer'),
         ('Loandrift Settings Admin', 'LoanDrift Configuration Manager'),
         ('Loandrift Viewer Admin', 'Loan Book Viewer'),
         ('Location Admin', 'Location Administrator'),
         ('Mystoreguard Admin', 'MyStoreGuard Administrator'),
         ('Mystoreguard Customers Admin', 'Customer Records Officer'),
         ('Mystoreguard Ecommerce Admin', 'Online Store Manager'),
         ('Mystoreguard Estimate Admin', 'Estimates Officer'),
         ('Mystoreguard Estimate Template Admin', 'Estimate Template Editor'),
         ('Mystoreguard Expenses Admin', 'Store Expense Officer'),
         ('Mystoreguard File Manager Admin', 'Store Document Controller'),
         ('Mystoreguard Guarantors Admin', 'Guarantor Officer'),
         ('Mystoreguard Installment Approver', 'Instalment Approver'),
         ('Mystoreguard Installment Plans Admin', 'Instalment Plan Officer'),
         ('Mystoreguard Installment Policies Admin', 'Instalment Policy Manager'),
         ('Mystoreguard Invoice Admin', 'Invoicing Officer'),
         ('Mystoreguard Loyalty Admin', 'Loyalty Programme Manager'),
         ('Mystoreguard Messaging Admin', 'Customer Messaging Officer'),
         ('Mystoreguard Pricing Rules Admin', 'Pricing Manager'),
         ('Mystoreguard Product Admin', 'Product Manager'),
         ('Mystoreguard Product Metadata Admin', 'Product Catalogue Editor'),
         ('Mystoreguard Product Prices Admin', 'Price List Officer'),
         ('Mystoreguard Purchase Backdate', 'Backdated Purchase Clerk'),
         ('Mystoreguard Reports Admin', 'Store Reports Viewer'),
         ('Mystoreguard Return Policies Admin', 'Return Policy Manager'),
         ('Mystoreguard Sales Backdate', 'Backdated Sales Clerk'),
         ('Mystoreguard Stock Takes Admin', 'Stock Take Officer'),
         ('Mystoreguard Store Admin', 'Store Manager'),
         ('Mystoreguard Store Configs Admin', 'Store Configuration Manager'),
         ('Mystoreguard Store Returns Admin', 'Returns Officer'),
         ('Mystoreguard Store Sales Admin', 'Sales Manager'),
         ('Mystoreguard Store Sales Personnel', 'Sales Assistant'),
         ('Mystoreguard Suppliers Admin', 'Supplier Manager'),
         ('Mystoreguard Tasks Admin', 'Task Coordinator'),
         ('Mystoreguard Tax Rules Admin', 'Tax Rule Manager'),
         ('Mystoreguard Taxes Admin', 'Tax Officer'),
         ('Mystoreguard Viewer Admin', 'Store Viewer'),
         ('Mystoreguard Warehouse Admin', 'Warehouse Manager'),
         ('Organization Admin', 'Organization Administrator'),
         ('Permission Admin', 'Permission Administrator'),
         ('Reports Admin', 'Suite Reports Viewer'),
         ('Role Admin', 'Role Administrator'),
         ('Settings Admin', 'Platform Settings Administrator'),
         ('User Admin', 'User Administrator'),
         ('ZelosHR Admin', 'ZelosHR Administrator')
       ) AS v(old_name, new_name)
 WHERE r.role_name = v.old_name
   AND r.tenant_id = 'system-tenant-id'
   AND r.delete_status = 'NOT_DELETED';

-- ------------------------------------------- MyStoreGuard descriptions say what the job is
UPDATE core_platform.cp_roles AS r
   SET description = v.description
  FROM (VALUES
         ('Backdated Purchase Clerk',
          'May record a purchase order with an earlier date. Separate for the same reason as backdated sales: it changes which period stock arrived in.'),
         ('Backdated Sales Clerk',
          'May record a sale with an earlier date. A deliberate exception for catching up after downtime, kept separate because it lets somebody change which period a sale lands in.'),
         ('Customer Messaging Officer',
          'Composes and sends messages to customers, and manages what has been sent.'),
         ('Customer Records Officer',
          'Maintains customer records and their contact details.'),
         ('Estimate Template Editor',
          'Maintains the blueprints estimates are built from, per domain. Changes here affect every estimate made afterwards.'),
         ('Estimates Officer',
          'Prepares and issues customer estimates and quotations, and turns an accepted one into an order.'),
         ('Expense Officer',
          'Records and manages expenses. Expenses belong to Core Platform, which is why this role holds no app permissions of its own.'),
         ('Guarantor Officer',
          'Records and maintains the guarantors who stand behind a customer''s instalment plan.'),
         ('Instalment Approver',
          'Approves or declines a customer''s request for an instalment plan.'),
         ('Instalment Plan Officer',
          'Sets up and manages a customer''s instalment plan and its schedule.'),
         ('Instalment Policy Manager',
          'Decides the rules instalment plans must follow -- deposits, terms and which products qualify.'),
         ('Invoicing Officer',
          'Raises and manages customer invoices, and records what has been billed.'),
         ('Loyalty Programme Manager',
          'Runs loyalty: points, tiers, earning rules, customer segments and campaigns.'),
         ('Online Store Manager',
          'Runs the storefront: which products are listed, their images and versions, and the promotions shown to shoppers.'),
         ('Price List Officer',
          'Maintains the actual prices on products, within the rules the Pricing Manager sets.'),
         ('Pricing Manager',
          'Sets the rules that decide a price: discounts, markups and promotional pricing.'),
         ('Product Catalogue Editor',
          'Maintains the descriptive metadata behind products -- categories, brands and attributes.'),
         ('Product Manager',
          'Owns the catalogue: creates and edits products, their packaging and their custom fields.'),
         ('Return Policy Manager',
          'Decides what may be returned, for how long, and on what terms.'),
         ('Returns Officer',
          'Handles goods coming back: records the return, approves it and processes the refund or exchange.'),
         ('Sales Assistant',
          'Serves customers and takes payment. Creates sales and looks up products, customers and prices, but cannot cancel or delete a completed sale.'),
         ('Sales Manager',
          'Owns the sales floor: sells, and can also cancel or delete a sale, which an assistant cannot. Handles escalations and corrections.'),
         ('Stock Take Officer',
          'Counts stock, investigates differences between the count and the system, and resolves the variance.'),
         ('Store Configuration Manager',
          'Configures how a store behaves -- its settings, not its stock.'),
         ('Store Document Controller',
          'Uploads, replaces and removes the documents and images attached to products, suppliers and deliveries.'),
         ('Store Expense Officer',
          'Records and manages store expenses.'),
         ('Store Manager',
          'Runs a store day to day: stock, sales, returns, staff tasks and the store''s own configuration. The senior role inside one store.'),
         ('Store Reports Viewer',
          'Reads MyStoreGuard''s reports and analytics. No access to the records behind them.'),
         ('Store Viewer',
          'Reads everything in MyStoreGuard and changes nothing. For owners, accountants and anyone who needs the numbers without the ability to move stock or money.'),
         ('Supplier Manager',
          'Maintains suppliers and their details, and is who a purchase order is raised against.'),
         ('Task Coordinator',
          'Creates and tracks tasks and multi-step workflows for store staff.'),
         ('Tax Officer',
          'Maintains the individual tax rates applied to sales.'),
         ('Tax Rule Manager',
          'Defines how tax is calculated: the rules, not the individual tax rates.'),
         ('Warehouse Manager',
          'Receives deliveries, moves stock between locations and runs the warehouse. Owns what is physically on hand.')
       ) AS v(role_name, description)
 WHERE r.role_name = v.role_name
   AND r.tenant_id = 'system-tenant-id'
   AND r.delete_status = 'NOT_DELETED';

-- ------------------------------------------------------------------------------- assertions
DO $$
DECLARE
    leftover integer;
    renamed  integer;
    leaks    integer;
BEGIN
    -- Nothing may still be called "<App> <Thing> Admin" among the system roles we renamed.
    SELECT count(*) INTO leftover
      FROM core_platform.cp_roles
     WHERE tenant_id = 'system-tenant-id' AND delete_status = 'NOT_DELETED'
       AND (role_name LIKE 'Mystoreguard %' OR role_name LIKE 'Loandrift %'
            OR role_name LIKE 'ZelosHR %Admin');

    SELECT count(*) INTO renamed
      FROM core_platform.cp_roles
     WHERE tenant_id = 'system-tenant-id' AND delete_status = 'NOT_DELETED'
       AND role_name IN ('Suite Administrator','Platform Administrator','Store Viewer',
                         'Loan Book Viewer','Cashier','Sales Assistant');

    -- No role may hold a permission belonging to an app it is not for.
    SELECT count(*) INTO leaks
      FROM core_platform.cp_roles r
      JOIN core_platform.cp_role_permissions rp
        ON rp.role_id = r.id AND rp.delete_status = 'NOT_DELETED'
     WHERE r.delete_status = 'NOT_DELETED'
       AND rp.app_prefix NOT IN ('', 'cp')
       AND r.id NOT LIKE 'role-subscribed-app-%'
       AND r.id NOT LIKE 'rid_%'
       AND rp.app_prefix <> CASE
             WHEN r.id LIKE 'role-msg%'       THEN 'msg'
             WHEN r.id LIKE 'role-loandrift%' THEN 'loandrift'
             WHEN r.id LIKE 'role-zeloshr%'   THEN 'zeloshr'
             WHEN r.id LIKE 'role-attendance%' THEN 'zeloshr'
             ELSE '-' END;

    IF leftover > 0 THEN
        RAISE EXCEPTION '% role(s) still carry an app prefix', leftover;
    END IF;
    IF renamed <> 6 THEN
        RAISE EXCEPTION 'expected 6 sample renames to land, found %', renamed;
    END IF;
    IF leaks > 0 THEN
        RAISE EXCEPTION '% cross-app grant(s) remain', leaks;
    END IF;

    RAISE NOTICE 'roles renamed; no app prefixes and no cross-app grants remain';
END $$;

COMMIT;
