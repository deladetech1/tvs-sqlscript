-- Hospital, part 6: what a complete hospital system still lacked.
--
-- Clinical: the medication administration record (MAR), nursing (assessments, care plans, fluid
-- balance, handover, wounds), bed requests and transfers between facilities, order sets and a
-- formulary, referrals out and in, pathology (histology, cytology, cultures, blood gases),
-- certificates (birth and death notifications, sick notes, medical reports).
-- Front desk: the self check-in kiosk, online booking with a waiting list, wristbands.
-- Money: pre-authorisation, deposits held against an admission, packages, credit limits.
-- Staff and safety: duty rosters (licences checked), incidents, infection control, antibiotic
-- stewardship. Interoperability: HL7 FHIR export, DHIS2 monthly returns, lab analysers, PACS.
-- Performance: targets and forecasts.
--
-- The new record kinds live in hospital_entries (part 5); this file adds the modules, the few
-- tables that are not entries, the settings, the permissions and the plan features.
-- Idempotent; safe to re-run.

BEGIN;

SELECT hospital.widen_check('hospital.hospital_facilities', 'hospital_facilities_modules_check', $q$'integrations'$q$,
    $q$CHECK (modules IS NULL OR modules <@ ARRAY['appointments', 'queue', 'opd', 'lab', 'pharmacy', 'ipd', 'insurance',
      'theatre', 'maternity', 'child_health', 'icu', 'dialysis', 'dental', 'eye', 'mental_health', 'physio', 'programmes',
      'blood_bank', 'imaging', 'inventory', 'procurement', 'support', 'relations', 'telemedicine', 'portal', 'reports',
      'nursing', 'referrals', 'pathology', 'certificates', 'quality', 'rosters', 'integrations']::text[])$q$);

-- ======================================================================= the MAR
-- Each dose of a prescription given (or held, refused, missed) on the ward: due_at is the
-- scheduled time from the frequency, NULL for a when-needed (PRN) or one-off dose.
CREATE TABLE IF NOT EXISTS hospital.hospital_med_admin (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    facility_id   text NOT NULL REFERENCES hospital.hospital_facilities(id),
    order_id      text NOT NULL REFERENCES hospital.hospital_orders(id),
    encounter_id  text NOT NULL REFERENCES hospital.hospital_encounters(id),
    patient_id    text NOT NULL REFERENCES hospital.hospital_patients(id),
    due_at        timestamptz,
    status        text NOT NULL CHECK (status IN ('given', 'held', 'refused', 'missed', 'not_available')),
    dose          text,
    route         text,
    note          text,
    given_by      text,
    given_at      timestamptz NOT NULL DEFAULT now(),
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_med_admin_due_uq ON hospital.hospital_med_admin (order_id, due_at) WHERE due_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS hospital_med_admin_encounter_idx ON hospital.hospital_med_admin (encounter_id, given_at DESC);

-- ======================================================================= order sets and the formulary
CREATE TABLE IF NOT EXISTS hospital.hospital_order_sets (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    name         text NOT NULL,
    description  text,
    -- [{kind: lab|imaging|procedure|drug, item_id, name, dose, frequency, duration_days, route, quantity}]
    items        jsonb NOT NULL DEFAULT '[]',
    is_active    boolean NOT NULL DEFAULT true,
    created_by   text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_order_sets_name_uq ON hospital.hospital_order_sets (bus_id, lower(name));

ALTER TABLE hospital.hospital_drugs ADD COLUMN IF NOT EXISTS on_formulary boolean NOT NULL DEFAULT true;

-- ======================================================================= packages and payers
SELECT hospital.widen_check('hospital.hospital_services', 'hospital_services_category_check', $q$'package'$q$,
    $q$CHECK (category IN ('registration', 'consultation', 'procedure', 'imaging', 'nursing', 'theatre', 'bed', 'other', 'package'))$q$);
-- A package (a normal delivery, a caesarean, a cataract) is one price; what it includes (service
-- and lab test ids) is then charged at nothing on the same visit.
ALTER TABLE hospital.hospital_services ADD COLUMN IF NOT EXISTS package_items text[] NOT NULL DEFAULT '{}';
ALTER TABLE hospital.hospital_payers ADD COLUMN IF NOT EXISTS credit_limit numeric(14,2);

-- ======================================================================= settings and public links
-- options: the smaller settings (formulary only, admission deposit, doctors' share, booking
-- hours, PACS, DHIS2, analyser key, targets), read and written as one object by the API.
ALTER TABLE hospital.hospital_settings ADD COLUMN IF NOT EXISTS options jsonb NOT NULL DEFAULT '{}';
-- The DHIS2 password: kept apart, never sent back.
ALTER TABLE hospital.hospital_settings ADD COLUMN IF NOT EXISTS dhis2_secret text;
-- Online booking: the facility's public booking link (NULL: not offered).
ALTER TABLE hospital.hospital_facilities ADD COLUMN IF NOT EXISTS booking_token text;
CREATE UNIQUE INDEX IF NOT EXISTS hospital_facilities_booking_uq ON hospital.hospital_facilities (booking_token) WHERE booking_token IS NOT NULL;
-- Lab analysers post results with the facility's analyser key.
ALTER TABLE hospital.hospital_facilities ADD COLUMN IF NOT EXISTS analyser_key text;
CREATE UNIQUE INDEX IF NOT EXISTS hospital_facilities_analyser_uq ON hospital.hospital_facilities (analyser_key) WHERE analyser_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS hospital_lab_results_specimen_idx ON hospital.hospital_lab_results (specimen_no);

-- Appointments booked online say so.
ALTER TABLE hospital.hospital_appointments ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'staff';
SELECT hospital.widen_check('hospital.hospital_appointments', 'hospital_appointments_source_check', $q$'kiosk'$q$,
    $q$CHECK (source IN ('staff', 'online', 'portal', 'kiosk'))$q$);

-- ======================================================================= permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-hospital-quality', 'CloudHams Quality & Safety', 'Incidents, infection control, isolation and antibiotic stewardship', 'rt-subscribed-app-hospital'),
('rt-hospital-rosters', 'CloudHams Duty Rosters', 'Shifts and on-call, with licences checked', 'rt-subscribed-app-hospital')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name, description = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('quality', 'rt-hospital-quality', 'get',    'View incidents and infection control'),
    ('quality', 'rt-hospital-quality', 'manage', 'Report and investigate incidents, run infection control'),
    ('rosters', 'rt-hospital-rosters', 'get',    'View the duty rosters'),
    ('rosters', 'rt-hospital-rosters', 'manage', 'Plan shifts and on-call')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-hospital-' || spec.resource_key || '-' || spec.action,
       'CloudHams ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name = EXCLUDED.permission_name, resource_type_id = EXCLUDED.resource_type_id,
                               description = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'hospital', resource_key = substring(p.id FROM '^permission-hospital-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'), target = '', scope = 'any'
 WHERE p.id LIKE 'permission-hospital-%' AND (p.app_prefix IS DISTINCT FROM 'hospital' OR p.action IS NULL);

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description), CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (VALUES
    ('role-hospital-director', 'quality', 'get'), ('role-hospital-director', 'quality', 'manage'),
    ('role-hospital-director', 'rosters', 'get'), ('role-hospital-director', 'rosters', 'manage'),
    ('role-hospital-doctor', 'quality', 'get'), ('role-hospital-doctor', 'quality', 'manage'), ('role-hospital-doctor', 'rosters', 'get'),
    ('role-hospital-nurse', 'quality', 'get'), ('role-hospital-nurse', 'quality', 'manage'), ('role-hospital-nurse', 'rosters', 'get'),
    ('role-hospital-lab', 'quality', 'get'), ('role-hospital-pharmacist', 'quality', 'get'), ('role-hospital-pharmacist', 'quality', 'manage'),
    ('role-hospital-operations', 'rosters', 'get'), ('role-hospital-operations', 'rosters', 'manage'),
    ('role-hospital-relations', 'quality', 'get'),
    ('role-hospital-viewer', 'quality', 'get'), ('role-hospital-viewer', 'rosters', 'get'),
    ('role-hospital-records', 'rosters', 'get')
  ) AS spec(role_id, resource_key, action)
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p ON p.app_prefix = 'hospital' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ============================================================ features per tier
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('hospital.nursing',        'app-hospital', 'Nursing',                   1, 'Falls, pressure and pain assessments scored, care plans, fluid balance, handover and wound care'),
('hospital.referrals',      'app-hospital', 'Referrals',                 1, 'Referral letters out and referrals received, followed until the patient arrives'),
('hospital.certificates',   'app-hospital', 'Certificates',              1, 'Birth and death notifications, sick notes and medical reports, signed and printed'),
('hospital.order-sets',     'app-hospital', 'Order Sets',                1, 'Ready-made bundles of tests and medicines, ordered in one go'),
('hospital.formulary',      'app-hospital', 'Formulary',                 1, 'The medicines the facility allows; others only with a reason'),
('hospital.mar',            'app-hospital', 'Medication Administration', 2, 'The ward''s due doses, recorded given, held or refused; missed doses flagged'),
('hospital.pathology',      'app-hospital', 'Pathology',                 2, 'Histology, cytology, cultures with sensitivities and blood gases'),
('hospital.quality',        'app-hospital', 'Quality & Safety',          2, 'Incidents investigated to closure, infection surveillance, isolation and antibiotic stewardship'),
('hospital.rosters',        'app-hospital', 'Duty Rosters',              2, 'Shifts and on-call per ward, with clashes and expired licences refused'),
('hospital.packages',       'app-hospital', 'Packages',                  2, 'Fixed-price packages with what they include charged at nothing'),
('hospital.preauth',        'app-hospital', 'Pre-authorisation',         2, 'Insurer approval before an admission or surgery, with the code and amount'),
('hospital.kiosk',          'app-hospital', 'Self Check-in',             2, 'A kiosk or the patient''s phone (QR code) to check in and take a number'),
('hospital.online-booking', 'app-hospital', 'Online Booking',            2, 'A public booking page with free slots, a confirmation by SMS, and a waiting list'),
('hospital.performance',    'app-hospital', 'Performance & Forecasts',   2, 'Length of stay, readmissions, occupancy, waiting and revenue per bed against targets; bed, stock and no-show forecasts'),
('hospital.interop',        'app-hospital', 'Integrations',              3, 'HL7 FHIR records, DHIS2 monthly returns, lab analysers and PACS')
ON CONFLICT (feature_key) DO UPDATE SET app_id = EXCLUDED.app_id, title = EXCLUDED.title, min_tier_rank = EXCLUDED.min_tier_rank,
    description = EXCLUDED.description, is_active = true;

COMMIT;
