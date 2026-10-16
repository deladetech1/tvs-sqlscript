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
('permission-accounting-audit-get', 'Accounting Audit Get', 'rt-accounting-audit', 'Read the accounting audit trail', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET
    permission_name  = EXCLUDED.permission_name,
    resource_type_id = EXCLUDED.resource_type_id,
    description      = EXCLUDED.description;
