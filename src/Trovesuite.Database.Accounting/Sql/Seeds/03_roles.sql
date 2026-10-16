SET search_path TO core_platform;

INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_active, is_system, cdate, ctime, cdatetime) VALUES
('role-accounting-admin', 'system-tenant-id', 'Accounting Admin', 'Administrator for Accounting app', 'rt-subscribed-app-accounting', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-accounting-organisation-admin', 'system-tenant-id', 'Accounting Organisation Admin', 'Organisation setup and settings', 'rt-accounting-organisation', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-accounting-account-admin', 'system-tenant-id', 'Accounting Account Admin', 'Chart of accounts', 'rt-accounting-account', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-accounting-fiscal-period-admin', 'system-tenant-id', 'Accounting Fiscal Period Admin', 'Fiscal periods', 'rt-accounting-fiscal-period', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-accounting-journal-admin', 'system-tenant-id', 'Accounting Journal Admin', 'Journal entries', 'rt-accounting-journal', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-accounting-audit-admin', 'system-tenant-id', 'Accounting Audit Admin', 'Audit trail read', 'rt-accounting-audit', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET
    role_name        = EXCLUDED.role_name,
    description      = EXCLUDED.description,
    resource_type_id = EXCLUDED.resource_type_id,
    is_active        = EXCLUDED.is_active,
    is_system        = EXCLUDED.is_system;
