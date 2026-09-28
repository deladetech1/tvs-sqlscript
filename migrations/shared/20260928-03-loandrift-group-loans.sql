-- Group loans (joint-liability groups).
--
-- 1. ld_client_groups: a group of clients who borrow together and meet on a
--    regular day with their loan officer.
-- 2. ld_client_group_members: who is in it, with their role (chairperson,
--    secretary, treasurer, member). A client is in at most one active group.
-- 3. ld_group_loans: one application for the group, on shared terms, with
--    whether members are jointly liable. Each member still gets their own loan
--    (ld_loan_details.group_loan_id, origin GROUP) so it is approved,
--    disbursed, repaid and reported like any other, and the group can be
--    approved, disbursed and collected from in one go.
--
-- Idempotent; safe to re-run on every deploy.

CREATE TABLE IF NOT EXISTS loandrift.ld_client_groups (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    org_id TEXT NOT NULL,
    bus_id TEXT NOT NULL,
    loc_id TEXT NOT NULL,
    name TEXT NOT NULL,
    code TEXT,
    meeting_day TEXT CHECK (meeting_day IS NULL OR meeting_day IN ('MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY','SATURDAY','SUNDAY')),
    meeting_frequency TEXT NOT NULL DEFAULT 'WEEKLY' CHECK (meeting_frequency IN ('WEEKLY','BI_WEEKLY','MONTHLY')),
    meeting_place TEXT,
    officer_id TEXT,
    formed_on DATE,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','INACTIVE')),
    notes TEXT,
    cdatetime TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT,
    udatetime TIMESTAMPTZ,
    updated_by TEXT
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_ld_client_groups_code ON loandrift.ld_client_groups (tenant_id, loc_id, lower(code)) WHERE code IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_ld_client_groups_name ON loandrift.ld_client_groups (tenant_id, loc_id, lower(name));

CREATE TABLE IF NOT EXISTS loandrift.ld_client_group_members (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    group_id TEXT NOT NULL REFERENCES loandrift.ld_client_groups (id) ON DELETE CASCADE,
    client_id TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'MEMBER' CHECK (role IN ('CHAIRPERSON','SECRETARY','TREASURER','MEMBER')),
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','LEFT')),
    joined_on DATE NOT NULL DEFAULT CURRENT_DATE,
    left_on DATE,
    cdatetime TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_ld_client_group_members_active ON loandrift.ld_client_group_members (tenant_id, client_id) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_ld_client_group_members_group ON loandrift.ld_client_group_members (group_id);

CREATE SEQUENCE IF NOT EXISTS loandrift.ld_group_loan_reference_seq;
CREATE TABLE IF NOT EXISTS loandrift.ld_group_loans (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    org_id TEXT NOT NULL,
    bus_id TEXT NOT NULL,
    loc_id TEXT NOT NULL,
    group_id TEXT NOT NULL REFERENCES loandrift.ld_client_groups (id),
    reference TEXT NOT NULL DEFAULT ('GL-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('loandrift.ld_group_loan_reference_seq')::text, 4, '0')),
    joint_liability BOOLEAN NOT NULL DEFAULT true,
    purpose TEXT,
    -- The shared terms, as applied to every member's loan.
    terms JSONB NOT NULL DEFAULT '{}'::jsonb,
    cdatetime TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT
);
CREATE INDEX IF NOT EXISTS idx_ld_group_loans_group ON loandrift.ld_group_loans (tenant_id, group_id);

ALTER TABLE loandrift.ld_loan_details ADD COLUMN IF NOT EXISTS group_loan_id TEXT;
CREATE INDEX IF NOT EXISTS idx_ld_loan_details_group_loan ON loandrift.ld_loan_details (tenant_id, group_loan_id) WHERE group_loan_id IS NOT NULL;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, cdate, ctime, cdatetime)
SELECT 'rt-loandrift-groups', 'Loandrift Groups', 'Borrower groups and group loans', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
WHERE NOT EXISTS (SELECT 1 FROM core_platform.cp_resource_types WHERE id = 'rt-loandrift-groups');

INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime) VALUES
('permission-loandrift-groups-get', 'Loandrift Groups Get', 'rt-loandrift-groups', 'Can see borrower groups and group loans', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-groups-create', 'Loandrift Groups Create', 'rt-loandrift-groups', 'Can form groups and apply for group loans', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-groups-update', 'Loandrift Groups Update', 'rt-loandrift-groups', 'Can change a group and its members', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET permission_name=EXCLUDED.permission_name, description=EXCLUDED.description, resource_type_id=EXCLUDED.resource_type_id;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT r.tenant_id, r.id, p.id, r.role_name || ' can ' || lower(p.permission_name), CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
FROM core_platform.cp_roles r JOIN core_platform.cp_permissions p ON p.id LIKE 'permission-loandrift-groups-%'
WHERE r.is_system = true AND r.id IN ('role-owner', 'role-admin', 'role-subscribed-app-loandrift-admin', 'role-loandrift-capturing-admin', 'role-loandrift-client-admin')
ON CONFLICT DO NOTHING;
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT r.tenant_id, r.id, 'permission-loandrift-groups-get', r.role_name || ' can read groups', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
FROM core_platform.cp_roles r WHERE r.is_system = true AND r.id = 'role-loandrift-viewer-admin'
ON CONFLICT DO NOTHING;

INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('loandrift.group-loans', 'app-loandrift', 'Group Loans', 2, 'Borrower groups, group applications with joint liability, group approval, disbursement and collection')
ON CONFLICT (feature_key) DO UPDATE SET app_id = EXCLUDED.app_id, title = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank, description = EXCLUDED.description, is_active = true;
