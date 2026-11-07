-- Hospital, part 5: the rest of the modules.
--
-- Specialty care (theatre, maternity, child health and immunisation, ICU, dialysis, dentistry, eye
-- care, mental health, physiotherapy, chronic programmes), the blood bank, imaging, stores and
-- procurement, support services (housekeeping, maintenance, assets, diet, laundry and CSSD,
-- mortuary, ambulance, staff licences), patient relations (complaints, surveys, visitors),
-- telemedicine, the patient portal, reports and decision support.
--
-- Most of them are entries in one register (hospital_entries): a kind of record (an ANC visit,
-- a partograph reading, a theatre booking, a blood unit, a complaint) with its own fields, kept as
-- data and defined in the API (internal/apps/hospital/defs.go), with its status changes in
-- hospital_entry_events. A signed clinical entry is final, as notes are.
-- Idempotent; safe to re-run.

BEGIN;

SELECT hospital.widen_check('hospital.hospital_facilities', 'hospital_facilities_modules_check', $q$'reports'$q$,
    $q$CHECK (modules IS NULL OR modules <@ ARRAY['appointments', 'queue', 'opd', 'lab', 'pharmacy', 'ipd', 'insurance',
      'theatre', 'maternity', 'child_health', 'icu', 'dialysis', 'dental', 'eye', 'mental_health', 'physio', 'programmes',
      'blood_bank', 'imaging', 'inventory', 'procurement', 'support', 'relations', 'telemedicine', 'portal', 'reports']::text[])$q$);

CREATE TABLE IF NOT EXISTS hospital.hospital_entries (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    facility_id   text NOT NULL REFERENCES hospital.hospital_facilities(id),
    module        text NOT NULL,
    kind          text NOT NULL,
    number        text NOT NULL,
    patient_id    text REFERENCES hospital.hospital_patients(id),
    encounter_id  text REFERENCES hospital.hospital_encounters(id),
    status        text NOT NULL,
    title         text,
    data          jsonb NOT NULL DEFAULT '{}',
    computed      jsonb NOT NULL DEFAULT '{}',
    starts_at     timestamptz,
    ends_at       timestamptz,
    assigned_to   text,
    signed_at     timestamptz,
    signed_by     text,
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_entries_number_uq ON hospital.hospital_entries (bus_id, number);
CREATE INDEX IF NOT EXISTS hospital_entries_kind_idx ON hospital.hospital_entries (facility_id, kind, cdatetime DESC);
CREATE INDEX IF NOT EXISTS hospital_entries_patient_idx ON hospital.hospital_entries (patient_id, kind, cdatetime DESC);
CREATE INDEX IF NOT EXISTS hospital_entries_schedule_idx ON hospital.hospital_entries (facility_id, kind, starts_at) WHERE starts_at IS NOT NULL;

CREATE TABLE IF NOT EXISTS hospital.hospital_entry_events (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    entry_id     text NOT NULL REFERENCES hospital.hospital_entries(id) ON DELETE CASCADE,
    from_status  text,
    to_status    text NOT NULL,
    note         text,
    actor_id     text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS hospital_entry_events_entry_idx ON hospital.hospital_entry_events (entry_id, cdatetime);

CREATE OR REPLACE FUNCTION hospital.signed_entry_is_final() RETURNS trigger
LANGUAGE plpgsql AS $f$
BEGIN
    IF coalesce(current_setting('hospital.purge', true), '') = 'on' THEN
        RETURN coalesce(NEW, OLD);
    END IF;
    IF OLD.signed_at IS NOT NULL AND (TG_OP = 'DELETE' OR NEW.data IS DISTINCT FROM OLD.data) THEN
        RAISE EXCEPTION 'a signed record cannot be changed' USING ERRCODE = 'check_violation';
    END IF;
    RETURN coalesce(NEW, OLD);
END
$f$;
DROP TRIGGER IF EXISTS hospital_entries_signed_final ON hospital.hospital_entries;
CREATE TRIGGER hospital_entries_signed_final BEFORE UPDATE OR DELETE ON hospital.hospital_entries
    FOR EACH ROW EXECUTE FUNCTION hospital.signed_entry_is_final();

-- Stores: non-medicine items (consumables, reagents, surgical supplies, linen...) live beside the
-- medicines, with the same batches, receiving and counts.
ALTER TABLE hospital.hospital_drugs ADD COLUMN IF NOT EXISTS item_category text NOT NULL DEFAULT 'medicine';
SELECT hospital.widen_check('hospital.hospital_drugs', 'hospital_drugs_item_category_check', $q$'stationery'$q$,
    $q$CHECK (item_category IN ('medicine', 'consumable', 'reagent', 'surgical', 'linen', 'cleaning', 'stationery', 'equipment', 'food', 'other'))$q$);

-- The patient portal: a private link per patient. Telemedicine: the meeting address template.
ALTER TABLE hospital.hospital_patients ADD COLUMN IF NOT EXISTS portal_token text;
CREATE UNIQUE INDEX IF NOT EXISTS hospital_patients_portal_uq ON hospital.hospital_patients (portal_token) WHERE portal_token IS NOT NULL;
ALTER TABLE hospital.hospital_settings ADD COLUMN IF NOT EXISTS tele_url text;

-- Merging moves entries too (patients.go patientTables).

-- ======================================================================= permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-hospital-operations', 'CloudHams Operations', 'Stores, procurement, housekeeping, maintenance, assets, diet, CSSD, mortuary, ambulance, licences', 'rt-subscribed-app-hospital'),
('rt-hospital-relations',  'CloudHams Patient Relations', 'Complaints, surveys and visitors', 'rt-subscribed-app-hospital'),
('rt-hospital-bloodbank',  'CloudHams Blood Bank', 'Donors, blood units, cross-matching and transfusions', 'rt-subscribed-app-hospital')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name, description = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('operations', 'rt-hospital-operations', 'get',    'View stores, procurement and support services'),
    ('operations', 'rt-hospital-operations', 'manage', 'Run stores, procurement and support services'),
    ('operations', 'rt-hospital-operations', 'approve','Approve requisitions and purchase orders'),
    ('relations',  'rt-hospital-relations',  'get',    'View complaints, surveys and visitors'),
    ('relations',  'rt-hospital-relations',  'manage', 'Handle complaints, surveys and visitors'),
    ('bloodbank',  'rt-hospital-bloodbank',  'get',    'View the blood bank'),
    ('bloodbank',  'rt-hospital-bloodbank',  'manage', 'Run the blood bank: units, cross-matches and issues')
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

INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-hospital-operations', 'system-tenant-id', 'CloudHams Operations Officer', 'Stores, procurement, housekeeping, maintenance, assets, diet, CSSD, mortuary and ambulances', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-hospital-relations',  'system-tenant-id', 'CloudHams Patient Relations Officer', 'Complaints, surveys, visitors and the patient portal', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name = EXCLUDED.role_name, description = EXCLUDED.description,
                               resource_type_id = EXCLUDED.resource_type_id, is_system = EXCLUDED.is_system, is_active = EXCLUDED.is_active;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description), CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (VALUES
    ('role-hospital-director', 'operations', 'get'), ('role-hospital-director', 'operations', 'manage'), ('role-hospital-director', 'operations', 'approve'),
    ('role-hospital-director', 'relations', 'get'), ('role-hospital-director', 'relations', 'manage'),
    ('role-hospital-director', 'bloodbank', 'get'), ('role-hospital-director', 'bloodbank', 'manage'),
    ('role-hospital-operations', 'profiles', 'get'), ('role-hospital-operations', 'operations', 'get'), ('role-hospital-operations', 'operations', 'manage'),
    ('role-hospital-operations', 'pharmacy', 'get'), ('role-hospital-operations', 'pharmacy', 'transact'), ('role-hospital-operations', 'patients', 'get'),
    ('role-hospital-relations', 'profiles', 'get'), ('role-hospital-relations', 'patients', 'get'), ('role-hospital-relations', 'relations', 'get'),
    ('role-hospital-relations', 'relations', 'manage'), ('role-hospital-relations', 'appointments', 'get'),
    ('role-hospital-doctor', 'bloodbank', 'get'), ('role-hospital-doctor', 'operations', 'get'),
    ('role-hospital-nurse', 'bloodbank', 'get'), ('role-hospital-nurse', 'operations', 'get'), ('role-hospital-nurse', 'relations', 'get'),
    ('role-hospital-lab', 'bloodbank', 'get'), ('role-hospital-lab', 'bloodbank', 'manage'),
    ('role-hospital-pharmacist', 'operations', 'get'),
    ('role-hospital-records', 'relations', 'get'), ('role-hospital-records', 'relations', 'manage'),
    ('role-hospital-viewer', 'operations', 'get'), ('role-hospital-viewer', 'relations', 'get'), ('role-hospital-viewer', 'bloodbank', 'get')
  ) AS spec(role_id, resource_key, action)
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p ON p.app_prefix = 'hospital' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', r.id, p.id FROM core_platform.cp_roles r
  JOIN core_platform.cp_permissions p ON p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
       'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
 WHERE r.id IN ('role-hospital-operations', 'role-hospital-relations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ============================================================ features per tier
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('hospital.maternity',     'app-hospital', 'Maternity',               1, 'Antenatal care, the partograph, deliveries, newborns, postnatal care and family planning'),
('hospital.child-health',  'app-hospital', 'Child Health',            1, 'Growth monitoring, the immunisation schedule with due and overdue doses'),
('hospital.imaging',       'app-hospital', 'Imaging',                 1, 'The imaging worklist, reports and images'),
('hospital.reports',       'app-hospital', 'Reports',                 1, 'Attendance, morbidity, admissions, maternity, revenue and statutory returns'),
('hospital.theatre',       'app-hospital', 'Operating Theatre',       2, 'Theatre bookings without clashes, the WHO checklist, anaesthesia and operation notes'),
('hospital.dental',        'app-hospital', 'Dentistry',               2, 'The odontogram, periodontal chart, treatment plans and procedures'),
('hospital.eye',           'app-hospital', 'Eye Care',                2, 'Eye examinations right and left, refraction, IOP, surgery and spectacles'),
('hospital.mental-health', 'app-hospital', 'Mental Health',           2, 'Assessments, mental state examinations and PHQ-9/GAD-7 scored'),
('hospital.physio',        'app-hospital', 'Physiotherapy',           2, 'Assessments, goals and sessions'),
('hospital.programmes',    'app-hospital', 'Chronic Care Programmes', 2, 'Registers for hypertension, diabetes, HIV, TB, sickle cell and more, with follow-up'),
('hospital.blood-bank',    'app-hospital', 'Blood Bank',              2, 'Donors, blood units by group and component, cross-matches and transfusion reactions'),
('hospital.inventory',     'app-hospital', 'Stores & Inventory',      2, 'Consumables, reagents and supplies with batches, requisitions and counts'),
('hospital.procurement',   'app-hospital', 'Procurement',             2, 'Purchase requests, quotations and purchase orders, approved before ordering'),
('hospital.support',       'app-hospital', 'Support Services',        2, 'Housekeeping, maintenance, assets, diet, laundry and CSSD, mortuary, ambulances and licences'),
('hospital.relations',     'app-hospital', 'Patient Relations',       2, 'Complaints to resolution, satisfaction surveys and visitors'),
('hospital.telemedicine',  'app-hospital', 'Telemedicine',            2, 'Video consultations from appointments'),
('hospital.portal',        'app-hospital', 'Patient Portal',          2, 'A private link for each patient: appointments, results, bills and paying online'),
('hospital.cdss',          'app-hospital', 'Decision Support',        2, 'Drug interactions, pregnancy warnings, sepsis and pre-eclampsia screening'),
('hospital.icu',           'app-hospital', 'Intensive Care',          3, 'ICU flowsheets, ventilation, fluid balance and severity'),
('hospital.dialysis',      'app-hospital', 'Dialysis',                3, 'Dialysis sessions, dry weight, ultrafiltration and machines')
ON CONFLICT (feature_key) DO UPDATE SET app_id = EXCLUDED.app_id, title = EXCLUDED.title, min_tier_rank = EXCLUDED.min_tier_rank,
    description = EXCLUDED.description, is_active = true;

COMMIT;
