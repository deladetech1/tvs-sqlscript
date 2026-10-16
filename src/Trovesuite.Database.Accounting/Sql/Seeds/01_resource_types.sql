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
('rt-accounting-audit', 'Accounting Audit Trail', 'Append-only accounting audit events', 'rt-subscribed-app-accounting')
ON CONFLICT (id) DO UPDATE SET
    resource_type_name = EXCLUDED.resource_type_name,
    description        = EXCLUDED.description,
    parent_resource_id = EXCLUDED.parent_resource_id;
