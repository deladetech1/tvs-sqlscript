SET search_path TO core_platform;

INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime) VALUES
('permission-accounting-organisation-get', 'Accounting Organisation Get', 'rt-accounting-organisation', 'Read organisation settings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-organisation-update', 'Accounting Organisation Update', 'rt-accounting-organisation', 'Update organisation settings and first-run setup', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-account-list', 'Accounting Account List', 'rt-accounting-account', 'List ledger accounts', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-account-get', 'Accounting Account Get', 'rt-accounting-account', 'Read a ledger account', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-account-add', 'Accounting Account Add', 'rt-accounting-account', 'Create ledger accounts', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-account-update', 'Accounting Account Update', 'rt-accounting-account', 'Update ledger accounts', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-fiscal-period-list', 'Accounting Fiscal Period List', 'rt-accounting-fiscal-period', 'List fiscal periods', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-fiscal-period-update', 'Accounting Fiscal Period Update', 'rt-accounting-fiscal-period', 'Open, lock or close periods', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-journal-list', 'Accounting Journal List', 'rt-accounting-journal', 'List journals', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-journal-get', 'Accounting Journal Get', 'rt-accounting-journal', 'Read a journal', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-journal-add', 'Accounting Journal Add', 'rt-accounting-journal', 'Create journals', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-journal-update', 'Accounting Journal Update', 'rt-accounting-journal', 'Edit draft journals', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-journal-post', 'Accounting Journal Post', 'rt-accounting-journal', 'Submit or post journals', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-journal-approve', 'Accounting Journal Approve', 'rt-accounting-journal', 'Approve or reject pending journals', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-journal-reverse', 'Accounting Journal Reverse', 'rt-accounting-journal', 'Reverse posted journals', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-journal-delete', 'Accounting Journal Delete', 'rt-accounting-journal', 'Delete draft journals', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-report-get', 'Accounting Report Get', 'rt-accounting-report', 'Run trial balance, GL, income statement, balance sheet and related reports', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-dimension-list', 'Accounting Dimension List', 'rt-accounting-dimension', 'List analysis dimensions', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-dimension-add', 'Accounting Dimension Add', 'rt-accounting-dimension', 'Create analysis dimensions', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-dimension-update', 'Accounting Dimension Update', 'rt-accounting-dimension', 'Update analysis dimensions', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-currency-list', 'Accounting Currency List', 'rt-accounting-currency', 'List organisation currencies', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-currency-add', 'Accounting Currency Add', 'rt-accounting-currency', 'Add organisation currencies', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-currency-update', 'Accounting Currency Update', 'rt-accounting-currency', 'Update organisation currencies', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-tax-code-list', 'Accounting Tax Code List', 'rt-accounting-tax-code', 'List tax codes', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-tax-code-get', 'Accounting Tax Code Get', 'rt-accounting-tax-code', 'Read a tax code', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-tax-code-update', 'Accounting Tax Code Update', 'rt-accounting-tax-code', 'Update tax codes', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-customer-list', 'Accounting Customer List', 'rt-accounting-customer', 'List customers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-customer-get', 'Accounting Customer Get', 'rt-accounting-customer', 'Read a customer', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-customer-add', 'Accounting Customer Add', 'rt-accounting-customer', 'Create customers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-customer-update', 'Accounting Customer Update', 'rt-accounting-customer', 'Update customers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-customer-delete', 'Accounting Customer Delete', 'rt-accounting-customer', 'Delete customers (refused while the books use one; archived when another app does)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-supplier-list', 'Accounting Supplier List', 'rt-accounting-supplier', 'List suppliers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-supplier-get', 'Accounting Supplier Get', 'rt-accounting-supplier', 'Read a supplier', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-supplier-add', 'Accounting Supplier Add', 'rt-accounting-supplier', 'Create suppliers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-supplier-update', 'Accounting Supplier Update', 'rt-accounting-supplier', 'Update suppliers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-supplier-delete', 'Accounting Supplier Delete', 'rt-accounting-supplier', 'Delete suppliers (refused while the books use one; archived when another app does)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-invoice-list', 'Accounting Invoice List', 'rt-accounting-invoice', 'List invoices', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-invoice-get', 'Accounting Invoice Get', 'rt-accounting-invoice', 'Read an invoice', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-invoice-add', 'Accounting Invoice Add', 'rt-accounting-invoice', 'Create invoices', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-invoice-update', 'Accounting Invoice Update', 'rt-accounting-invoice', 'Update draft invoices', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-invoice-approve', 'Accounting Invoice Approve', 'rt-accounting-invoice', 'Approve invoices', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-invoice-void', 'Accounting Invoice Void', 'rt-accounting-invoice', 'Void invoices', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-invoice-delete', 'Accounting Invoice Delete', 'rt-accounting-invoice', 'Delete draft invoices', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-bill-list', 'Accounting Bill List', 'rt-accounting-bill', 'List bills', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-bill-get', 'Accounting Bill Get', 'rt-accounting-bill', 'Read a bill', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-bill-add', 'Accounting Bill Add', 'rt-accounting-bill', 'Create bills', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-bill-update', 'Accounting Bill Update', 'rt-accounting-bill', 'Update draft bills', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-bill-approve', 'Accounting Bill Approve', 'rt-accounting-bill', 'Approve bills', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-bill-void', 'Accounting Bill Void', 'rt-accounting-bill', 'Void bills', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-bill-delete', 'Accounting Bill Delete', 'rt-accounting-bill', 'Delete draft bills', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-receipt-list', 'Accounting Receipt List', 'rt-accounting-receipt', 'List receipts', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-receipt-get', 'Accounting Receipt Get', 'rt-accounting-receipt', 'Read a receipt', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-receipt-add', 'Accounting Receipt Add', 'rt-accounting-receipt', 'Record receipts', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-receipt-void', 'Accounting Receipt Void', 'rt-accounting-receipt', 'Void receipts', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-supplier-payment-list', 'Accounting Supplier Payment List', 'rt-accounting-supplier-payment', 'List supplier payments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-supplier-payment-get', 'Accounting Supplier Payment Get', 'rt-accounting-supplier-payment', 'Read a supplier payment', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-supplier-payment-add', 'Accounting Supplier Payment Add', 'rt-accounting-supplier-payment', 'Record supplier payments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-supplier-payment-void', 'Accounting Supplier Payment Void', 'rt-accounting-supplier-payment', 'Void supplier payments', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-credit-note-list', 'Accounting Credit Note List', 'rt-accounting-credit-note', 'List credit notes', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-credit-note-get', 'Accounting Credit Note Get', 'rt-accounting-credit-note', 'Read a credit note', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-credit-note-add', 'Accounting Credit Note Add', 'rt-accounting-credit-note', 'Issue credit notes', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-credit-note-void', 'Accounting Credit Note Void', 'rt-accounting-credit-note', 'Void credit notes', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-supplier-credit-list', 'Accounting Supplier Credit List', 'rt-accounting-supplier-credit', 'List supplier credits', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-supplier-credit-get', 'Accounting Supplier Credit Get', 'rt-accounting-supplier-credit', 'Read a supplier credit', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-supplier-credit-add', 'Accounting Supplier Credit Add', 'rt-accounting-supplier-credit', 'Record supplier credits', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-supplier-credit-void', 'Accounting Supplier Credit Void', 'rt-accounting-supplier-credit', 'Void supplier credits', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-exchange-rate-list', 'Accounting Exchange Rate List', 'rt-accounting-exchange-rate', 'List exchange rates and revaluations', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-exchange-rate-add', 'Accounting Exchange Rate Add', 'rt-accounting-exchange-rate', 'Add exchange rates and run revaluations', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-exchange-rate-delete', 'Accounting Exchange Rate Delete', 'rt-accounting-exchange-rate', 'Delete manual exchange rates', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-custom-field-list', 'Accounting Custom Field List', 'rt-accounting-custom-field', 'List custom fields', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-custom-field-add', 'Accounting Custom Field Add', 'rt-accounting-custom-field', 'Create custom fields', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-custom-field-update', 'Accounting Custom Field Update', 'rt-accounting-custom-field', 'Update custom fields and values', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-custom-field-delete', 'Accounting Custom Field Delete', 'rt-accounting-custom-field', 'Delete unused custom fields', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-data-source-list', 'Accounting Data Source List', 'rt-accounting-data-source', 'List data sources and field mappings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-data-source-update', 'Accounting Data Source Update', 'rt-accounting-data-source', 'Connect, sync and edit data sources', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-data-source-delete', 'Accounting Data Source Delete', 'rt-accounting-data-source', 'Delete data sources and mappings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-import-list', 'Accounting Import List', 'rt-accounting-import', 'List import batches', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-import-get', 'Accounting Import Get', 'rt-accounting-import', 'Read an import batch', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-import-add', 'Accounting Import Add', 'rt-accounting-import', 'Create import batches', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-import-update', 'Accounting Import Update', 'rt-accounting-import', 'Post or correct import rows', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-import-delete', 'Accounting Import Delete', 'rt-accounting-import', 'Discard unposted import batches', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-user-list', 'Accounting User List', 'rt-accounting-user', 'List tenant users for Accounting', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-opening-balance-get', 'Accounting Opening Balance Get', 'rt-accounting-opening-balance', 'Read opening balances', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-opening-balance-update', 'Accounting Opening Balance Update', 'rt-accounting-opening-balance', 'Update opening balances', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-bank-statement-list', 'Accounting Bank Statement List', 'rt-accounting-bank', 'List bank statement lines and bank activity', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-bank-statement-import', 'Accounting Bank Statement Import', 'rt-accounting-bank', 'Import, preview and undo bank statement files', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-bank-statement-exclude', 'Accounting Bank Statement Exclude', 'rt-accounting-bank', 'Exclude or restore bank statement lines', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-bank-statement-delete', 'Accounting Bank Statement Delete', 'rt-accounting-bank', 'Delete bank statement lines from a file', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-import-post', 'Accounting Import Post', 'rt-accounting-import', 'Post import batches', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-data-source-sync', 'Accounting Data Source Sync', 'rt-accounting-data-source', 'Run a manual sync of a data source', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-field-mapping-update', 'Accounting Field Mapping Update', 'rt-accounting-data-source', 'Update field mappings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-field-mapping-delete', 'Accounting Field Mapping Delete', 'rt-accounting-data-source', 'Delete field mappings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-accounting-rule-create', 'Accounting Accounting Rule Create', 'rt-accounting-rule', 'Create accounting rule (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-accounting-rule-delete', 'Accounting Accounting Rule Delete', 'rt-accounting-rule', 'Delete accounting rule (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-accounting-rule-list', 'Accounting Accounting Rule List', 'rt-accounting-rule', 'List accounting rules (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-accounting-rule-update', 'Accounting Accounting Rule Update', 'rt-accounting-rule', 'Update accounting rule (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-audit-log-list', 'Accounting Audit Log List', 'rt-accounting-audit', 'List audit logs (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-bank-account-create', 'Accounting Bank Account Create', 'rt-accounting-bank', 'Create bank account (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-bank-account-get', 'Accounting Bank Account Get', 'rt-accounting-bank', 'Read bank account (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-bank-account-list', 'Accounting Bank Account List', 'rt-accounting-bank', 'List bank accounts (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-bank-account-transfer', 'Accounting Bank Account Transfer', 'rt-accounting-bank', 'Transfer between bank account (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-bank-account-update', 'Accounting Bank Account Update', 'rt-accounting-bank', 'Update bank account (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-data-source-create', 'Accounting Data Source Create', 'rt-accounting-data-source', 'Create data source (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-field-mapping-add', 'Accounting Field Mapping Add', 'rt-accounting-data-source', 'Create field mapping (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-field-mapping-list', 'Accounting Field Mapping List', 'rt-accounting-data-source', 'List field mappings (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-fiscal-period-add', 'Accounting Fiscal Period Add', 'rt-accounting-fiscal-period', 'Create fiscal period (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-fiscal-period-get', 'Accounting Fiscal Period Get', 'rt-accounting-fiscal-period', 'Read fiscal period (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-fiscal-year-close', 'Accounting Fiscal Year Close', 'rt-accounting-fiscal-period', 'Close fiscal year (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-fiscal-year-reopen', 'Accounting Fiscal Year Reopen', 'rt-accounting-fiscal-period', 'Reopen fiscal year (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-reconciliation-complete', 'Accounting Reconciliation Complete', 'rt-accounting-bank', 'Complete reconciliation (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-reconciliation-get', 'Accounting Reconciliation Get', 'rt-accounting-bank', 'Read reconciliation (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-reconciliation-reopen', 'Accounting Reconciliation Reopen', 'rt-accounting-bank', 'Reopen reconciliation (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-reconciliation-update', 'Accounting Reconciliation Update', 'rt-accounting-bank', 'Update reconciliation (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-revaluation-add', 'Accounting Revaluation Add', 'rt-accounting-exchange-rate', 'Create revaluation (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-revaluation-get', 'Accounting Revaluation Get', 'rt-accounting-exchange-rate', 'Read revaluation (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-revaluation-list', 'Accounting Revaluation List', 'rt-accounting-exchange-rate', 'List revaluations (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-tax-code-create', 'Accounting Tax Code Create', 'rt-accounting-tax-code', 'Create tax code (contract id)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET
    permission_name  = EXCLUDED.permission_name,
    resource_type_id = EXCLUDED.resource_type_id,
    description      = EXCLUDED.description;

-- Catalogue metadata (app_prefix, resource_key, action) that Core Platform's Admin and Viewer Admin
-- reconciliation reads. Accounting arrived after migrations/shared/20260928-05 backfilled other modules,
-- so it is derived here from the id: permission-accounting-RESOURCE-VERB. Every accounting verb is one
-- word, and the cp_actions foreign key fails the deploy if a new verb is missing from 00_actions.sql.
UPDATE core_platform.cp_permissions SET
    app_prefix   = 'accounting',
    resource_key = substring(id FROM '^permission-accounting-(.+)-[a-z]+$'),
    action       = substring(id FROM '-([a-z]+)$')
WHERE id LIKE 'permission-accounting-%'
  AND (app_prefix <> 'accounting'
       OR resource_key IS DISTINCT FROM substring(id FROM '^permission-accounting-(.+)-[a-z]+$')
       OR action IS DISTINCT FROM substring(id FROM '-([a-z]+)$'));

-- Grants keep a copy of that metadata (migrations/shared/20260929-01) and copy it only when written, so
-- refresh the copies on accounting grants. On a fresh database this seed runs before that migration adds
-- the columns, and the migration's own backfill covers it then.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'core_platform' AND table_name = 'cp_role_permissions'
                 AND column_name = 'app_prefix') THEN
        UPDATE core_platform.cp_role_permissions rp
           SET app_prefix = p.app_prefix, resource_key = p.resource_key, action = p.action
          FROM core_platform.cp_permissions p
         WHERE p.id = rp.permission_id
           AND p.id LIKE 'permission-accounting-%'
           AND (rp.app_prefix IS DISTINCT FROM p.app_prefix
                OR rp.resource_key IS DISTINCT FROM p.resource_key
                OR rp.action IS DISTINCT FROM p.action);
    END IF;
END $$;

-- While accounting permissions had no app_prefix they read as platform permissions, so other apps'
-- system roles (role-cp-admin in particular) were given them. No role may hold another app's permission
-- (the cross-app check in migrations/shared/20260929-11), so those grants are removed. Accounting's own
-- roles, the subscribed-app roles and tenant custom roles (rid_*) keep theirs.
DELETE FROM core_platform.cp_role_permissions rp
 WHERE rp.permission_id LIKE 'permission-accounting-%'
   AND rp.role_id NOT LIKE 'role-accounting%'
   AND rp.role_id NOT LIKE 'role-subscribed-app-%'
   AND rp.role_id NOT LIKE 'rid_%';
