-- Hospital joins the platform: hospital and clinic management for any country -- clinics,
-- maternity homes, health centres, diagnostic centres, district, private and teaching hospitals,
-- and groups of them.
--
-- Served by the shared apps backend (deladetech1/tvs-shared-apps-bk, module "hospital") like the
-- CRM, HMS, SCM and SMS; frontend tvs-hospital-management-system-ft. Its cp_apps row, tier prices
-- and the role-cp-admin exclusion live in the CorePlatform seed (04_others.sql), which owns every
-- app row. Billed per LOCATION (the default in 20261022-70): one facility profile is one Core
-- Platform location. This file holds the rest:
--
--   * the hospital schema, widen_check and the audit trail (hospital_audit_logs);
--   * its cp_app_schemas row, so activity-log retention finds hospital.hospital_audit_logs;
--   * resource types, permissions (hospital|<resource>|<action>||any) and the roles: Hospital
--     Admin is allowed by BEING the role and holds no hospital rows; the job roles carry grants;
--   * which features each subscription tier includes (cp_app_feature_catalog);
--   * the reserved label "hospital" and the route rows for the website and the API;
--   * the old placeholder app-hams (a hospital system "coming soon", never sold) is removed.
--
-- Not app-hms, which is hospitality (hotels, restaurants, rentals). Idempotent; safe to re-run.

BEGIN;

CREATE SCHEMA IF NOT EXISTS hospital;

-- widen_check: (re)defines a CHECK constraint, unless it already holds `token` -- the value the
-- calling migration introduced. Every migration re-runs on each deploy, oldest first, so a
-- constraint that later migrations widened must not be put back to an older, narrower list.
CREATE OR REPLACE FUNCTION hospital.widen_check(tbl regclass, name text, token text, def text) RETURNS void
LANGUAGE plpgsql AS $f$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint c WHERE c.conrelid = tbl AND c.conname = name
                AND position(token IN pg_get_constraintdef(c.oid)) > 0) THEN
        RETURN;
    END IF;
    EXECUTE format('ALTER TABLE %s DROP CONSTRAINT IF EXISTS %I', tbl, name);
    EXECUTE format('ALTER TABLE %s ADD CONSTRAINT %I %s', tbl, name, def);
END
$f$;

INSERT INTO core_platform.cp_app_schemas (app_id, schema_name, description)
VALUES ('app-hospital', 'hospital', 'Hospital (clinic and hospital management) audit logs')
ON CONFLICT (app_id) DO UPDATE SET schema_name = EXCLUDED.schema_name,
                                   description = EXCLUDED.description;

CREATE TABLE IF NOT EXISTS hospital.hospital_audit_logs (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    org_id       text,
    bus_id       text,
    facility_id  text,
    entity_type  text NOT NULL,
    entity_id    text NOT NULL,
    action       text NOT NULL,
    changes      jsonb NOT NULL DEFAULT '{}',
    actor_id     text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS hospital_audit_entity_idx
    ON hospital.hospital_audit_logs (tenant_id, entity_type, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS hospital_audit_business_idx
    ON hospital.hospital_audit_logs (bus_id, cdatetime DESC);

-- ======================================================================= permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-subscribed-app-hospital', 'HOSPITAL APP', 'Hospital (clinic and hospital management) Subscribed APP', NULL)
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-hospital-profiles',     'Hospital Facilities',    'Each facility''s identity, type, location, licences and contacts',             'rt-subscribed-app-hospital'),
('rt-hospital-settings',     'Hospital Settings',      'How the hospital system is set up: modules, numbering, identifiers',            'rt-subscribed-app-hospital'),
('rt-hospital-logs',         'Hospital Logs',          'The audit trail of the hospital system',                                        'rt-subscribed-app-hospital'),
('rt-hospital-patients',     'Hospital Patients',      'Registration, the master patient index, identifiers, allergies and documents',  'rt-subscribed-app-hospital'),
('rt-hospital-appointments', 'Hospital Appointments',  'Booking and running appointments',                                              'rt-subscribed-app-hospital'),
('rt-hospital-queue',        'Hospital Queues',        'Tokens and service points',                                                     'rt-subscribed-app-hospital'),
('rt-hospital-clinical',     'Hospital Clinical',      'Visits, triage and vitals, notes, diagnoses and orders',                        'rt-subscribed-app-hospital'),
('rt-hospital-lab',          'Hospital Laboratory',    'Tests, samples, results and their release',                                     'rt-subscribed-app-hospital'),
('rt-hospital-pharmacy',     'Hospital Pharmacy',      'Medicines, stock and dispensing',                                               'rt-subscribed-app-hospital'),
('rt-hospital-wards',        'Hospital Wards',         'Wards, beds, admissions, transfers and discharges',                             'rt-subscribed-app-hospital'),
('rt-hospital-billing',      'Hospital Billing',       'Prices, charges, bills, payments, waivers and refunds',                         'rt-subscribed-app-hospital'),
('rt-hospital-claims',       'Hospital Claims',        'Payers, insurance policies and claims',                                         'rt-subscribed-app-hospital'),
('rt-hospital-reports',      'Hospital Reports',       'Dashboards and reports',                                                        'rt-subscribed-app-hospital')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('profiles',     'rt-hospital-profiles',     'get',      'View facility profiles'),
    ('profiles',     'rt-hospital-profiles',     'manage',   'Set up, change and delete facility profiles'),
    ('settings',     'rt-hospital-settings',     'get',      'View the hospital settings'),
    ('settings',     'rt-hospital-settings',     'manage',   'Change the hospital settings and modules'),
    ('logs',         'rt-hospital-logs',         'get',      'View the hospital audit trail'),
    ('patients',     'rt-hospital-patients',     'get',      'Find and view patients'),
    ('patients',     'rt-hospital-patients',     'create',   'Register patients'),
    ('patients',     'rt-hospital-patients',     'manage',   'Change patient records and their documents'),
    ('patients',     'rt-hospital-patients',     'merge',    'Merge duplicate patient records'),
    ('appointments', 'rt-hospital-appointments', 'get',      'View appointments'),
    ('appointments', 'rt-hospital-appointments', 'manage',   'Book, move and cancel appointments'),
    ('queue',        'rt-hospital-queue',        'get',      'View the queues'),
    ('queue',        'rt-hospital-queue',        'manage',   'Issue, call and move tokens; set up service points'),
    ('clinical',     'rt-hospital-clinical',     'get',      'Read visits, notes, diagnoses and orders'),
    ('clinical',     'rt-hospital-clinical',     'create',   'Open visits, take vitals, write notes and place orders'),
    ('clinical',     'rt-hospital-clinical',     'sign',     'Sign clinical notes, diagnose and prescribe'),
    ('lab',          'rt-hospital-lab',          'get',      'View the laboratory worklist and results'),
    ('lab',          'rt-hospital-lab',          'enter',    'Collect samples and enter results'),
    ('lab',          'rt-hospital-lab',          'release',  'Validate and release results'),
    ('lab',          'rt-hospital-lab',          'manage',   'Set up the test catalogue'),
    ('pharmacy',     'rt-hospital-pharmacy',     'get',      'View medicines, stock and prescriptions'),
    ('pharmacy',     'rt-hospital-pharmacy',     'transact', 'Dispense, receive and adjust stock'),
    ('pharmacy',     'rt-hospital-pharmacy',     'manage',   'Set up the medicines list and prices'),
    ('wards',        'rt-hospital-wards',        'get',      'View the bed board and admissions'),
    ('wards',        'rt-hospital-wards',        'transact', 'Admit, transfer and discharge'),
    ('wards',        'rt-hospital-wards',        'manage',   'Set up wards and beds'),
    ('billing',      'rt-hospital-billing',      'get',      'View bills and payments'),
    ('billing',      'rt-hospital-billing',      'transact', 'Take payments and issue receipts'),
    ('billing',      'rt-hospital-billing',      'manage',   'Set prices and post or reverse charges'),
    ('billing',      'rt-hospital-billing',      'waive',    'Approve waivers and discounts'),
    ('billing',      'rt-hospital-billing',      'refund',   'Void payments and refund'),
    ('claims',       'rt-hospital-claims',       'get',      'View payers, policies and claims'),
    ('claims',       'rt-hospital-claims',       'manage',   'Set up payers and prepare, submit and settle claims'),
    ('reports',      'rt-hospital-reports',      'get',      'View the dashboards and reports')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-hospital-' || spec.resource_key || '-' || spec.action,
       'Hospital ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'hospital',
       resource_key = substring(p.id FROM '^permission-hospital-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-hospital-%'
   AND (p.app_prefix IS DISTINCT FROM 'hospital' OR p.action IS NULL);

-- ============================================================================ roles
INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-subscribed-app-hospital-admin', 'system-tenant-id', 'Hospital Admin', 'Administrator of the hospital system: every Hospital permission', 'rt-subscribed-app-hospital', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-hospital-director',   'system-tenant-id', 'Hospital Medical Director',    'Runs the facility: every Hospital permission',                                              'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-hospital-doctor',     'system-tenant-id', 'Hospital Doctor',              'Consults, diagnoses, orders and prescribes, admits and discharges',                          'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-hospital-nurse',      'system-tenant-id', 'Hospital Nurse',               'Triage and vitals, nursing notes, the ward and its beds',                                    'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-hospital-records',    'system-tenant-id', 'Hospital Front Desk',          'Registers patients, books appointments, runs the queues and keeps records',                 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-hospital-cashier',    'system-tenant-id', 'Hospital Cashier',             'Takes payments and issues receipts',                                                        'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-hospital-billing',    'system-tenant-id', 'Hospital Billing Officer',     'Prices, bills, waivers and insurance claims',                                               'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-hospital-lab',        'system-tenant-id', 'Hospital Laboratory Scientist','Samples, results and their release, and the test catalogue',                                'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-hospital-pharmacist', 'system-tenant-id', 'Hospital Pharmacist',          'Dispensing, stock and the medicines list',                                                  'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-hospital-viewer',     'system-tenant-id', 'Hospital Viewer',              'Reads everything outside the clinical record; changes nothing',                             'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name        = EXCLUDED.role_name,
                               description      = EXCLUDED.description,
                               resource_type_id = EXCLUDED.resource_type_id,
                               is_system        = EXCLUDED.is_system,
                               is_active        = EXCLUDED.is_active;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-hospital-director' AS role_id, p2.resource_key, p2.action
      FROM core_platform.cp_permissions p2 WHERE p2.app_prefix = 'hospital'
    UNION ALL
    SELECT 'role-hospital-doctor', k, a FROM (VALUES
        ('profiles', 'get'), ('patients', 'get'), ('patients', 'create'), ('patients', 'manage'),
        ('appointments', 'get'), ('appointments', 'manage'), ('queue', 'get'), ('queue', 'manage'),
        ('clinical', 'get'), ('clinical', 'create'), ('clinical', 'sign'), ('lab', 'get'), ('pharmacy', 'get'),
        ('wards', 'get'), ('wards', 'transact'), ('billing', 'get'), ('claims', 'get'), ('reports', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-hospital-nurse', k, a FROM (VALUES
        ('profiles', 'get'), ('patients', 'get'), ('patients', 'create'), ('appointments', 'get'), ('queue', 'get'),
        ('queue', 'manage'), ('clinical', 'get'), ('clinical', 'create'), ('lab', 'get'), ('pharmacy', 'get'),
        ('wards', 'get'), ('wards', 'transact'), ('billing', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-hospital-records', k, a FROM (VALUES
        ('profiles', 'get'), ('patients', 'get'), ('patients', 'create'), ('patients', 'manage'), ('patients', 'merge'),
        ('appointments', 'get'), ('appointments', 'manage'), ('queue', 'get'), ('queue', 'manage'), ('wards', 'get'),
        ('billing', 'get'), ('claims', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-hospital-cashier', k, a FROM (VALUES
        ('profiles', 'get'), ('patients', 'get'), ('queue', 'get'), ('queue', 'manage'), ('billing', 'get'),
        ('billing', 'transact')) AS g(k, a)
    UNION ALL
    SELECT 'role-hospital-billing', k, a FROM (VALUES
        ('profiles', 'get'), ('patients', 'get'), ('billing', 'get'), ('billing', 'transact'), ('billing', 'manage'),
        ('billing', 'waive'), ('billing', 'refund'), ('claims', 'get'), ('claims', 'manage'), ('reports', 'get'),
        ('wards', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-hospital-lab', k, a FROM (VALUES
        ('profiles', 'get'), ('patients', 'get'), ('queue', 'get'), ('queue', 'manage'), ('clinical', 'get'),
        ('lab', 'get'), ('lab', 'enter'), ('lab', 'release'), ('lab', 'manage')) AS g(k, a)
    UNION ALL
    SELECT 'role-hospital-pharmacist', k, a FROM (VALUES
        ('profiles', 'get'), ('patients', 'get'), ('queue', 'get'), ('queue', 'manage'), ('clinical', 'get'),
        ('pharmacy', 'get'), ('pharmacy', 'transact'), ('pharmacy', 'manage'), ('billing', 'get')) AS g(k, a)
    UNION ALL
    -- The viewer reads everything but the clinical record and the lab's results, which are
    -- confidential to those treating the patient.
    SELECT 'role-hospital-viewer', p3.resource_key, p3.action
      FROM core_platform.cp_permissions p3
      JOIN core_platform.cp_actions a ON a.action = p3.action AND a.is_read_only AND p3.action <> 'export'
     WHERE p3.app_prefix = 'hospital' AND p3.resource_key NOT IN ('clinical', 'lab')
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'hospital' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- The core-platform navigation block every app role seeds for itself.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', r.id, p.id
  FROM core_platform.cp_roles r
  JOIN core_platform.cp_permissions p
    ON p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations',
                'permission-user-get-locations')
 WHERE r.id IN ('role-subscribed-app-hospital-admin', 'role-hospital-director', 'role-hospital-doctor', 'role-hospital-nurse',
                'role-hospital-records', 'role-hospital-cashier', 'role-hospital-billing', 'role-hospital-lab',
                'role-hospital-pharmacist', 'role-hospital-viewer')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ============================================================ features per tier
-- Tiers are cumulative (20260821-02): a business on rank R has every feature whose
-- min_tier_rank <= R. 1=BASIC 2=ADVANCE 3=PREMIUM 4=ENTERPRISE. feature_key is the contract
-- between this file, the API (internal/apps/hospital/plan.go) and the UI (src/data/modules.ts).
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
-- ---- BASIC: a clinic -----------------------------------------------------------------------
('hospital.dashboard',       'app-hospital', 'Dashboard',              1, 'The facility at a glance'),
('hospital.profile',         'app-hospital', 'Facility Profile',       1, 'Identity, type, location, licences and contacts'),
('hospital.settings',        'app-hospital', 'Settings',               1, 'Modules, numbering and patient identifiers'),
('hospital.patients',        'app-hospital', 'Patients & Records',     1, 'Registration, one record per patient, identifiers, allergies, alerts and documents'),
('hospital.appointments',    'app-hospital', 'Appointments',           1, 'Booking by doctor and clinic, arrivals and no-shows'),
('hospital.queue',           'app-hospital', 'Queues',                 1, 'Tokens per service point, priorities and the waiting-room screen'),
('hospital.opd',             'app-hospital', 'Outpatients',            1, 'Visits, triage and vitals, notes, diagnoses and orders'),
('hospital.lab',             'app-hospital', 'Laboratory',             1, 'Test catalogue, samples, results with reference ranges, validation and release'),
('hospital.pharmacy',        'app-hospital', 'Pharmacy',               1, 'Medicines, batches and expiry, prescriptions and dispensing'),
('hospital.billing',         'app-hospital', 'Billing & Payments',     1, 'Prices, charges from every service, bills, payments and receipts'),
-- ---- ADVANCE: a hospital -------------------------------------------------------------------
('hospital.multi-facility',  'app-hospital', 'Several Facilities',     2, 'More than one facility profile, one per location, sharing one patient record'),
('hospital.ipd',             'app-hospital', 'Wards & Admissions',     2, 'Wards and beds, the bed board, admissions, transfers and discharge'),
('hospital.insurance',       'app-hospital', 'Insurance & Claims',     2, 'Payers and schemes, patients'' policies, coverage and claims'),
('hospital.online-payments', 'app-hospital', 'Pay Online',             2, 'Payment links through the organisation''s gateway in TroveSuite'),
('hospital.reminders',       'app-hospital', 'Reminders',              2, 'Appointment reminders by SMS and email'),
-- ---- PREMIUM: governance -------------------------------------------------------------------
('hospital.audit-logs',      'app-hospital', 'Audit Trail',            3, 'Who changed what, and when')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

-- ==================================================================== label and routes
INSERT INTO control_plane.ctl_reserved_labels (label, reason, created_by)
SELECT v.label, v.reason, 'migration:20261107-01'
  FROM (VALUES ('hospital', 'a product: hospital.dev.trovesuite.com, hospital and clinic management')) AS v(label, reason)
 WHERE NOT EXISTS (SELECT 1 FROM control_plane.ctl_reserved_labels r WHERE r.label = v.label);

-- Both the website and the API host, dev only (the WHERE EXISTS on the dev cell keeps these
-- rows out of production).
INSERT INTO control_plane.ctl_tenant_routes (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT h.host, NULL, 'POOLED', h.cell, 'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261107-01'
  FROM (VALUES ('hospital.dev.trovesuite.com',     'uksouth-dev'),
               ('api.hospital.dev.trovesuite.com', 'uksouth-dev')) AS h(host, cell)
 WHERE EXISTS (SELECT 1 FROM control_plane.ctl_cells c WHERE c.cell_key = h.cell)
ON CONFLICT (host) DO NOTHING;

-- ==================================================================== the old placeholder
-- app-hams was the app store's "coming soon" hospital system, never sold. app-hospital is it.
-- Removed when nothing was ever bought on it; otherwise left alone (and inactive).
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM core_platform.cp_apps WHERE id = 'app-hams')
       AND NOT EXISTS (SELECT 1 FROM core_platform.cp_app_subscriptions WHERE app_id = 'app-hams') THEN
        BEGIN
            DELETE FROM core_platform.cp_app_tier_configs WHERE app_id = 'app-hams';
            DELETE FROM core_platform.cp_apps WHERE id = 'app-hams';
        EXCEPTION WHEN foreign_key_violation THEN
            UPDATE core_platform.cp_apps SET is_active = false, status = 'coming_soon' WHERE id = 'app-hams';
        END;
    END IF;
END $$;

-- ====================================================================== unsubscribing
-- Medical records are not deleted when a business unsubscribes: health-records law in most
-- countries keeps them for years (often 10 or more). KEPT, like Accounting's books, until the
-- account itself is closed. Only where the register exists (20261028-60).
DO $$
BEGIN
    IF to_regclass('core_platform.cp_app_data_owners') IS NOT NULL THEN
        INSERT INTO core_platform.cp_app_data_owners (app_id, schema_name, fate, note)
        VALUES ('app-hospital', 'hospital', 'KEPT', 'Medical records are kept as health-records law requires, until the account is closed.')
        ON CONFLICT (app_id) DO UPDATE SET schema_name = EXCLUDED.schema_name, fate = EXCLUDED.fate, note = EXCLUDED.note;
    END IF;
END $$;

-- ======================================================================= invariants
DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions
     WHERE id LIKE 'permission-hospital-%'
       AND (app_prefix IS DISTINCT FROM 'hospital' OR resource_key IS NULL OR action IS NULL
            OR coalesce(target, '') <> '' OR scope IS DISTINCT FROM 'any');
    IF n > 0 THEN
        RAISE EXCEPTION '% Hospital permission(s) have no pair; nothing would match them', n;
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-hospital-viewer' AND p.app_prefix = 'hospital' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-hospital-viewer holds % Hospital permission(s) that change data', n;
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_permissions p
     WHERE p.app_prefix = 'hospital' AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                        WHERE rp.role_id = 'role-hospital-director' AND rp.permission_id = p.id);
    IF n > 0 THEN
        RAISE EXCEPTION 'role-hospital-director lacks % Hospital permission(s)', n;
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-hospital-admin' AND permission_id LIKE 'permission-hospital-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-hospital-admin holds Hospital permission rows';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-hospital-viewer' AND p.app_prefix = 'hospital' AND p.resource_key IN ('clinical', 'lab')) THEN
        RAISE EXCEPTION 'role-hospital-viewer reads the clinical record';
    END IF;
END $$;

COMMIT;
