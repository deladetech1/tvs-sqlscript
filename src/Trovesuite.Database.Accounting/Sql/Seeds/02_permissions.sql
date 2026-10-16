SET search_path TO core_platform;

INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime) VALUES
('permission-accounting-organisation-get', 'Accounting Organisation Get', 'rt-accounting-organisation', 'Read organisation settings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-organisation-update', 'Accounting Organisation Update', 'rt-accounting-organisation', 'Update organisation settings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-organisation-setup', 'Accounting Organisation Setup', 'rt-accounting-organisation', 'Complete first-run organisation setup', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-accounts-create', 'Accounting Accounts Create', 'rt-accounting-accounts', 'Create ledger accounts', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-accounts-get', 'Accounting Accounts Get', 'rt-accounting-accounts', 'List and read ledger accounts', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-accounts-update', 'Accounting Accounts Update', 'rt-accounting-accounts', 'Update ledger accounts', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-periods-get', 'Accounting Periods Get', 'rt-accounting-periods', 'List fiscal periods', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-periods-update', 'Accounting Periods Update', 'rt-accounting-periods', 'Open, close or lock periods', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-journals-create', 'Accounting Journals Create', 'rt-accounting-journals', 'Create journal drafts', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-journals-get', 'Accounting Journals Get', 'rt-accounting-journals', 'List and read journals', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-journals-update', 'Accounting Journals Update', 'rt-accounting-journals', 'Edit draft journals', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-journals-submit', 'Accounting Journals Submit', 'rt-accounting-journals', 'Submit journals for approval or post', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-journals-approve', 'Accounting Journals Approve', 'rt-accounting-journals', 'Approve pending journals', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-journals-reverse', 'Accounting Journals Reverse', 'rt-accounting-journals', 'Reverse posted journals', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-journals-delete', 'Accounting Journals Delete', 'rt-accounting-journals', 'Delete draft journals', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-accounting-audit-get', 'Accounting Audit Get', 'rt-accounting-audit', 'Read the accounting audit trail', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET
    permission_name  = EXCLUDED.permission_name,
    resource_type_id = EXCLUDED.resource_type_id,
    description      = EXCLUDED.description;
