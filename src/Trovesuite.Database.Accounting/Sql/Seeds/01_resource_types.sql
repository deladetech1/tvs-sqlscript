SET search_path TO core_platform;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-subscribed-app-accounting', 'Accounting APP', 'Trovesuite Accounting subscribed app', null),
('rt-accounting-organisation', 'Accounting Organisation', 'Organisation setup and settings', 'rt-subscribed-app-accounting'),
('rt-accounting-accounts', 'Chart of Accounts', 'General ledger accounts', 'rt-subscribed-app-accounting'),
('rt-accounting-periods', 'Fiscal Periods', 'Accounting periods and locks', 'rt-subscribed-app-accounting'),
('rt-accounting-journals', 'Journals', 'Manual and system journal entries', 'rt-subscribed-app-accounting'),
('rt-accounting-audit', 'Accounting Audit Trail', 'Append-only accounting audit events', 'rt-subscribed-app-accounting')
ON CONFLICT (id) DO UPDATE SET
    resource_type_name = EXCLUDED.resource_type_name,
    description        = EXCLUDED.description,
    parent_resource_id = EXCLUDED.parent_resource_id;
