-- Permissions and plan tiers for collateral management and loan agreements
-- (tables in 20260927-01). Safe to rerun.

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-loandrift-collateral', 'LoanDrift Collateral',
 'Assets pledged as security: valuation, lien, release and recovery', 'rt-subscribed-app-loandrift'),
('rt-loandrift-agreements', 'LoanDrift Loan Agreements',
 'Loan agreements, offer letters, schedules and their signatures', 'rt-subscribed-app-loandrift')
ON CONFLICT (id) DO UPDATE SET resource_type_name=EXCLUDED.resource_type_name,
    description=EXCLUDED.description, parent_resource_id=EXCLUDED.parent_resource_id;

INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime) VALUES
('permission-loandrift-collateral-get', 'Loandrift Collateral Get', 'rt-loandrift-collateral',
 'Can see collateral, its valuations, documents and history', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-collateral-create', 'Loandrift Collateral Create', 'rt-loandrift-collateral',
 'Can register collateral and record a valuation', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-collateral-update', 'Loandrift Collateral Update', 'rt-loandrift-collateral',
 'Can edit collateral, verify it, pledge it, and record its lien, release and recovery', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-collateral-delete', 'Loandrift Collateral Delete', 'rt-loandrift-collateral',
 'Can remove collateral that is not pledged', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-agreements-get', 'Loandrift Agreements Get', 'rt-loandrift-agreements',
 'Can see and download loan agreements and their documents', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-agreements-create', 'Loandrift Agreements Create', 'rt-loandrift-agreements',
 'Can generate the agreement documents for an approved loan', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-agreements-sign', 'Loandrift Agreements Sign', 'rt-loandrift-agreements',
 'Can capture the borrower''s, a guarantor''s and the lender''s signature on an agreement', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-agreements-share', 'Loandrift Agreements Share', 'rt-loandrift-agreements',
 'Can email an agreement''s documents to the borrower, a guarantor or anyone else', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-agreements-void', 'Loandrift Agreements Void', 'rt-loandrift-agreements',
 'Can void an agreement so a new one can be generated', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET permission_name=EXCLUDED.permission_name,
    resource_type_id=EXCLUDED.resource_type_id, description=EXCLUDED.description;

INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-loandrift-collateral-admin', 'system-tenant-id', 'Loandrift Collateral Admin',
 'Register, value and track collateral through lien, release and recovery',
 'rt-loandrift-collateral', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-loandrift-agreements-admin', 'system-tenant-id', 'Loandrift Agreements Admin',
 'Generate loan agreements and capture signatures',
 'rt-loandrift-agreements', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name=EXCLUDED.role_name, description=EXCLUDED.description,
    resource_type_id=EXCLUDED.resource_type_id;

-- Roles with app-wide access get everything, as for collections.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT r.tenant_id, r.id, p.id, r.role_name || ' can ' || lower(p.permission_name),
       CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
FROM core_platform.cp_roles r
JOIN core_platform.cp_permissions p ON p.id IN (
  'permission-loandrift-collateral-get', 'permission-loandrift-collateral-create',
  'permission-loandrift-collateral-update', 'permission-loandrift-collateral-delete',
  'permission-loandrift-agreements-get', 'permission-loandrift-agreements-create',
  'permission-loandrift-agreements-sign', 'permission-loandrift-agreements-void',
  'permission-loandrift-agreements-share')
WHERE r.is_system = true
  AND r.id IN ('role-owner', 'role-admin', 'role-subscribed-app-loandrift-admin')
ON CONFLICT DO NOTHING;

-- Each module's own admin role gets its own permissions.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT r.tenant_id, r.id, p.id, r.role_name || ' can ' || lower(p.permission_name),
       CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
FROM core_platform.cp_roles r
JOIN core_platform.cp_permissions p
  ON (r.id = 'role-loandrift-collateral-admin' AND p.id LIKE 'permission-loandrift-collateral-%')
  OR (r.id = 'role-loandrift-agreements-admin' AND p.id LIKE 'permission-loandrift-agreements-%')
WHERE r.is_system = true
ON CONFLICT DO NOTHING;

-- A viewer reads both and changes neither.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT r.tenant_id, r.id, p.id, r.role_name || ' can read ' || lower(p.permission_name),
       CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
FROM core_platform.cp_roles r
JOIN core_platform.cp_permissions p ON p.id IN ('permission-loandrift-collateral-get', 'permission-loandrift-agreements-get')
WHERE r.is_system = true AND r.id = 'role-loandrift-viewer-admin'
ON CONFLICT DO NOTHING;

-- Plans (see 20260923-05). An agreement is part of lending itself, so every plan
-- has it; managing collateral as its own record is an Advance feature, beside
-- collections.
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('loandrift.loan-agreements', 'app-loandrift', 'Loan Agreements', 1,
 'Agreement, repayment schedule, offer letter, guarantor and collateral agreements, signing and storage'),
('loandrift.collaterals', 'app-loandrift', 'Collateral Management', 2,
 'Collateral records with valuations, documents, photos, lien, release and recovery')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id = EXCLUDED.app_id, title = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank, description = EXCLUDED.description, is_active = true;
