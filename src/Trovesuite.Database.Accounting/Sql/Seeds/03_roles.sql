SET search_path TO core_platform;

INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_active, is_system, cdate, ctime, cdatetime) VALUES
('role-accounting-admin', 'system-tenant-id', 'Accounting Admin', 'Administrator for Accounting app', 'rt-subscribed-app-accounting', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-accounting-organisation-admin', 'system-tenant-id', 'Accounting Organisation Admin', 'Organisation setup and settings', 'rt-accounting-organisation', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-accounting-accounts-admin', 'system-tenant-id', 'Accounting Accounts Admin', 'Chart of accounts', 'rt-accounting-accounts', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-accounting-periods-admin', 'system-tenant-id', 'Accounting Periods Admin', 'Fiscal periods', 'rt-accounting-periods', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-accounting-journals-admin', 'system-tenant-id', 'Accounting Journals Admin', 'Journal entries', 'rt-accounting-journals', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-accounting-audit-admin', 'system-tenant-id', 'Accounting Audit Admin', 'Audit trail read', 'rt-accounting-audit', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET
    role_name        = EXCLUDED.role_name,
    description      = EXCLUDED.description,
    resource_type_id = EXCLUDED.resource_type_id,
    is_active        = EXCLUDED.is_active,
    is_system        = EXCLUDED.is_system;
