SET search_path TO core_platform;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-subscribed-app-accounting', 'Accounting APP', 'Trovesuite Accounting subscribed app', null),
('rt-accounting-organisation', 'Accounting Organisation', 'Organisation setup and settings', 'rt-subscribed-app-accounting'),
('rt-accounting-account', 'Chart of Accounts', 'General ledger accounts', 'rt-subscribed-app-accounting'),
('rt-accounting-fiscal-period', 'Fiscal Periods', 'Accounting periods and locks', 'rt-subscribed-app-accounting'),
('rt-accounting-journal', 'Journals', 'Manual and system journal entries', 'rt-subscribed-app-accounting'),
('rt-accounting-report', 'Reports', 'Trial balance, GL, income statement, balance sheet and related reports', 'rt-subscribed-app-accounting'),
('rt-accounting-dimension', 'Dimensions', 'Analysis codes: branch, cost centre, project, etc.', 'rt-subscribed-app-accounting'),
('rt-accounting-currency', 'Currencies', 'Organisation currencies for multi-currency books', 'rt-subscribed-app-accounting'),
('rt-accounting-tax-code', 'Tax Codes', 'VAT, exempt and withholding tax codes', 'rt-subscribed-app-accounting'),
('rt-accounting-rule', 'Accounting Rules', 'Integration posting rules', 'rt-subscribed-app-accounting'),
('rt-accounting-audit', 'Accounting Audit Trail', 'Append-only accounting audit events', 'rt-subscribed-app-accounting'),
('rt-accounting-customer', 'Customers', 'Accounts receivable parties', 'rt-subscribed-app-accounting'),
('rt-accounting-supplier', 'Suppliers', 'Accounts payable parties', 'rt-subscribed-app-accounting'),
('rt-accounting-invoice', 'Sales Invoices', 'Customer invoices', 'rt-subscribed-app-accounting'),
('rt-accounting-bill', 'Purchase Bills', 'Supplier bills', 'rt-subscribed-app-accounting'),
('rt-accounting-receipt', 'Receipts', 'Customer receipts', 'rt-subscribed-app-accounting'),
('rt-accounting-supplier-payment', 'Supplier Payments', 'Supplier payments', 'rt-subscribed-app-accounting'),
('rt-accounting-credit-note', 'Credit Notes', 'Customer credit notes', 'rt-subscribed-app-accounting'),
('rt-accounting-supplier-credit', 'Supplier Credits', 'Supplier credit notes', 'rt-subscribed-app-accounting'),
('rt-accounting-bank', 'Banking', 'Bank accounts, statements and reconciliation', 'rt-subscribed-app-accounting'),
('rt-accounting-exchange-rate', 'Exchange Rates', 'FX rates and revaluations', 'rt-subscribed-app-accounting'),
('rt-accounting-custom-field', 'Custom Fields', 'Custom field definitions', 'rt-subscribed-app-accounting'),
('rt-accounting-data-source', 'Data Sources', 'Integration data sources and field mappings', 'rt-subscribed-app-accounting'),
('rt-accounting-import', 'Imports', 'Import batches', 'rt-subscribed-app-accounting'),
('rt-accounting-user', 'Accounting Users', 'Tenant users visible in Accounting', 'rt-subscribed-app-accounting'),
('rt-accounting-opening-balance', 'Opening Balances', 'Conversion opening balances', 'rt-subscribed-app-accounting')
ON CONFLICT (id) DO UPDATE SET
    resource_type_name = EXCLUDED.resource_type_name,
    description        = EXCLUDED.description,
    parent_resource_id = EXCLUDED.parent_resource_id;
