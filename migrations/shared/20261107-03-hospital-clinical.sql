-- Hospital, part 3: the clinical record.
--
--   * patients: the master patient index, one record per patient for the whole business (every
--     branch), with identifiers (whatever documents people carry in the country: a national ID, a
--     passport, an insurance number), contacts and next of kin, allergies and alerts;
--   * departments, service points (where a queue forms), appointments and queue tokens;
--   * encounters (visits: outpatient, emergency, inpatient, telemedicine) -- the hub every vital
--     sign, note, diagnosis, order and charge belongs to;
--   * notes are immutable once signed (a trigger): changes after that are addenda;
--   * the laboratory (test catalogue, results), the pharmacy (medicines, batches, stock moves)
--     and the wards (wards, beds, admissions, bed moves).
-- Idempotent; safe to re-run.

BEGIN;

-- ========================================================================== patients
CREATE TABLE IF NOT EXISTS hospital.hospital_patients (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    home_facility_id text,
    mrn             text NOT NULL,
    first_name      text NOT NULL,
    middle_name     text,
    last_name       text NOT NULL,
    full_name       text NOT NULL,
    sex             text NOT NULL DEFAULT 'unknown' CHECK (sex IN ('female', 'male', 'other', 'unknown')),
    date_of_birth   date,
    dob_estimated   boolean NOT NULL DEFAULT false,
    phone           text,
    alt_phone       text,
    email           text,
    address         text,
    city            text,
    region          text,
    country         text,
    nationality     text,
    occupation      text,
    marital_status  text,
    blood_group     text,
    language        text,
    category        text NOT NULL DEFAULT 'self_pay'
                    CHECK (category IN ('self_pay', 'insured', 'corporate', 'staff', 'vip', 'exempt')),
    flags           text[] NOT NULL DEFAULT '{}',
    consents        jsonb NOT NULL DEFAULT '{}',
    -- An unknown patient (brought in unconscious): a temporary record to be merged later.
    is_unknown      boolean NOT NULL DEFAULT false,
    status          text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'merged', 'deceased')),
    merged_into     text REFERENCES hospital.hospital_patients(id),
    deceased_on     date,
    notes           text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz,
    created_by      text
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_patients_mrn_uq ON hospital.hospital_patients (bus_id, mrn);
CREATE INDEX IF NOT EXISTS hospital_patients_name_idx ON hospital.hospital_patients (bus_id, lower(full_name));
CREATE INDEX IF NOT EXISTS hospital_patients_phone_idx ON hospital.hospital_patients (bus_id, right(regexp_replace(coalesce(phone, ''), '\D', '', 'g'), 9));

CREATE TABLE IF NOT EXISTS hospital.hospital_patient_identifiers (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    bus_id      text NOT NULL,
    patient_id  text NOT NULL REFERENCES hospital.hospital_patients(id) ON DELETE CASCADE,
    kind        text NOT NULL,
    value       text NOT NULL,
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_identifiers_uq ON hospital.hospital_patient_identifiers (bus_id, kind, lower(value));
CREATE INDEX IF NOT EXISTS hospital_identifiers_patient_idx ON hospital.hospital_patient_identifiers (patient_id);

CREATE TABLE IF NOT EXISTS hospital.hospital_patient_contacts (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    patient_id    text NOT NULL REFERENCES hospital.hospital_patients(id) ON DELETE CASCADE,
    full_name     text NOT NULL,
    relationship  text,
    phone         text,
    email         text,
    is_emergency  boolean NOT NULL DEFAULT true,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS hospital_contacts_patient_idx ON hospital.hospital_patient_contacts (patient_id);

CREATE TABLE IF NOT EXISTS hospital.hospital_allergies (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    patient_id  text NOT NULL REFERENCES hospital.hospital_patients(id) ON DELETE CASCADE,
    allergen    text NOT NULL,
    kind        text NOT NULL DEFAULT 'drug' CHECK (kind IN ('drug', 'food', 'environment', 'other')),
    reaction    text,
    severity    text NOT NULL DEFAULT 'moderate' CHECK (severity IN ('mild', 'moderate', 'severe')),
    status      text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'resolved')),
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text
);
CREATE INDEX IF NOT EXISTS hospital_allergies_patient_idx ON hospital.hospital_allergies (patient_id);

-- ================================================================ departments and queues
CREATE TABLE IF NOT EXISTS hospital.hospital_departments (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    facility_id  text NOT NULL REFERENCES hospital.hospital_facilities(id),
    name         text NOT NULL,
    kind         text NOT NULL DEFAULT 'clinical' CHECK (kind IN ('clinical', 'diagnostic', 'support', 'administrative')),
    is_active    boolean NOT NULL DEFAULT true,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_departments_name_uq ON hospital.hospital_departments (facility_id, lower(name));

CREATE TABLE IF NOT EXISTS hospital.hospital_service_points (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    facility_id  text NOT NULL REFERENCES hospital.hospital_facilities(id),
    name         text NOT NULL,
    kind         text NOT NULL DEFAULT 'consultation'
                 CHECK (kind IN ('reception', 'triage', 'consultation', 'lab', 'imaging', 'pharmacy', 'cashier', 'procedure', 'other')),
    prefix       text NOT NULL DEFAULT 'A',
    sort_order   int NOT NULL DEFAULT 0,
    is_active    boolean NOT NULL DEFAULT true,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_points_name_uq ON hospital.hospital_service_points (facility_id, lower(name));

CREATE TABLE IF NOT EXISTS hospital.hospital_appointments (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    facility_id      text NOT NULL REFERENCES hospital.hospital_facilities(id),
    patient_id       text NOT NULL REFERENCES hospital.hospital_patients(id),
    practitioner_id  text,
    department_id    text REFERENCES hospital.hospital_departments(id),
    starts_at        timestamptz NOT NULL,
    duration_min     int NOT NULL DEFAULT 15 CHECK (duration_min BETWEEN 5 AND 480),
    kind             text NOT NULL DEFAULT 'new' CHECK (kind IN ('new', 'review', 'procedure', 'telemedicine')),
    reason           text,
    status           text NOT NULL DEFAULT 'booked'
                     CHECK (status IN ('booked', 'confirmed', 'arrived', 'in_progress', 'completed', 'cancelled', 'no_show')),
    cancel_reason    text,
    encounter_id     text,
    reminded_at      timestamptz,
    notes            text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz,
    created_by       text
);
CREATE INDEX IF NOT EXISTS hospital_appointments_day_idx ON hospital.hospital_appointments (facility_id, starts_at);
CREATE INDEX IF NOT EXISTS hospital_appointments_patient_idx ON hospital.hospital_appointments (patient_id, starts_at DESC);

CREATE TABLE IF NOT EXISTS hospital.hospital_queue_tokens (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    facility_id       text NOT NULL REFERENCES hospital.hospital_facilities(id),
    service_point_id  text NOT NULL REFERENCES hospital.hospital_service_points(id),
    patient_id        text REFERENCES hospital.hospital_patients(id),
    encounter_id      text,
    day               date NOT NULL,
    token_no          int NOT NULL,
    label             text NOT NULL,
    priority          text NOT NULL DEFAULT 'normal'
                      CHECK (priority IN ('emergency', 'elderly', 'pregnant', 'disabled', 'child', 'vip', 'normal')),
    status            text NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting', 'called', 'serving', 'done', 'skipped')),
    room              text,
    called_at         timestamptz,
    done_at           timestamptz,
    served_by         text,
    cdatetime         timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_tokens_no_uq ON hospital.hospital_queue_tokens (service_point_id, day, token_no);
CREATE INDEX IF NOT EXISTS hospital_tokens_board_idx ON hospital.hospital_queue_tokens (facility_id, day, status);

-- ======================================================================== encounters
CREATE TABLE IF NOT EXISTS hospital.hospital_encounters (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    facility_id      text NOT NULL REFERENCES hospital.hospital_facilities(id),
    patient_id       text NOT NULL REFERENCES hospital.hospital_patients(id),
    number           text NOT NULL,
    kind             text NOT NULL DEFAULT 'outpatient' CHECK (kind IN ('outpatient', 'emergency', 'inpatient', 'telemedicine', 'day_case')),
    status           text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'admitted', 'closed', 'cancelled')),
    department_id    text REFERENCES hospital.hospital_departments(id),
    practitioner_id  text,
    appointment_id   text,
    -- Who pays: the patient themself (NULL) or one of their insurance policies (part 4).
    policy_id        text,
    chief_complaint  text,
    triage_category  text CHECK (triage_category IN ('immediate', 'very_urgent', 'urgent', 'standard', 'non_urgent')),
    triage_at        timestamptz,
    outcome          text CHECK (outcome IN ('discharged', 'admitted', 'referred', 'transferred', 'dama', 'absconded', 'died')),
    referral_to      text,
    started_at       timestamptz NOT NULL DEFAULT now(),
    closed_at        timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz,
    created_by       text
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_encounters_number_uq ON hospital.hospital_encounters (bus_id, number);
CREATE INDEX IF NOT EXISTS hospital_encounters_patient_idx ON hospital.hospital_encounters (patient_id, started_at DESC);
CREATE INDEX IF NOT EXISTS hospital_encounters_open_idx ON hospital.hospital_encounters (facility_id, status, started_at DESC);

CREATE TABLE IF NOT EXISTS hospital.hospital_vitals (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    encounter_id   text NOT NULL REFERENCES hospital.hospital_encounters(id),
    patient_id     text NOT NULL REFERENCES hospital.hospital_patients(id),
    taken_at       timestamptz NOT NULL DEFAULT now(),
    temp_c         numeric(4,1),
    pulse          int,
    resp_rate      int,
    bp_sys         int,
    bp_dia         int,
    spo2           int,
    on_oxygen      boolean NOT NULL DEFAULT false,
    consciousness  text CHECK (consciousness IN ('alert', 'confusion', 'voice', 'pain', 'unresponsive')),
    weight_kg      numeric(5,1),
    height_cm      numeric(5,1),
    bmi            numeric(4,1),
    pain_score     int CHECK (pain_score BETWEEN 0 AND 10),
    glucose_mmol   numeric(4,1),
    news2          int,
    flags          text[] NOT NULL DEFAULT '{}',
    note           text,
    taken_by       text
);
CREATE INDEX IF NOT EXISTS hospital_vitals_patient_idx ON hospital.hospital_vitals (patient_id, taken_at DESC);
CREATE INDEX IF NOT EXISTS hospital_vitals_encounter_idx ON hospital.hospital_vitals (encounter_id, taken_at DESC);

CREATE TABLE IF NOT EXISTS hospital.hospital_notes (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    encounter_id  text NOT NULL REFERENCES hospital.hospital_encounters(id),
    patient_id    text NOT NULL REFERENCES hospital.hospital_patients(id),
    kind          text NOT NULL DEFAULT 'consultation'
                  CHECK (kind IN ('consultation', 'progress', 'nursing', 'procedure', 'discharge', 'referral', 'other')),
    subjective    text,
    objective     text,
    assessment    text,
    plan          text,
    body          text,
    -- An addendum: written after its note was signed, about it.
    parent_id     text REFERENCES hospital.hospital_notes(id),
    author_id     text,
    signed_at     timestamptz,
    signed_by     text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz
);
CREATE INDEX IF NOT EXISTS hospital_notes_encounter_idx ON hospital.hospital_notes (encounter_id, cdatetime);

-- A signed note is the record: it is never changed or deleted. hospital.purge = on (a module's
-- data deleted on purpose) lets it go.
CREATE OR REPLACE FUNCTION hospital.signed_note_is_final() RETURNS trigger
LANGUAGE plpgsql AS $f$
BEGIN
    IF coalesce(current_setting('hospital.purge', true), '') = 'on' THEN
        RETURN coalesce(NEW, OLD);
    END IF;
    IF OLD.signed_at IS NOT NULL THEN
        RAISE EXCEPTION 'a signed note cannot be changed: write an addendum' USING ERRCODE = 'check_violation';
    END IF;
    RETURN coalesce(NEW, OLD);
END
$f$;
DROP TRIGGER IF EXISTS hospital_notes_signed_final ON hospital.hospital_notes;
CREATE TRIGGER hospital_notes_signed_final BEFORE UPDATE OR DELETE ON hospital.hospital_notes
    FOR EACH ROW EXECUTE FUNCTION hospital.signed_note_is_final();

CREATE TABLE IF NOT EXISTS hospital.hospital_diagnoses (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    encounter_id  text NOT NULL REFERENCES hospital.hospital_encounters(id),
    patient_id    text NOT NULL REFERENCES hospital.hospital_patients(id),
    code          text,
    description   text NOT NULL,
    kind          text NOT NULL DEFAULT 'primary' CHECK (kind IN ('primary', 'secondary')),
    certainty     text NOT NULL DEFAULT 'provisional' CHECK (certainty IN ('provisional', 'confirmed')),
    is_chronic    boolean NOT NULL DEFAULT false,
    removed_at    timestamptz,
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS hospital_diagnoses_encounter_idx ON hospital.hospital_diagnoses (encounter_id);
CREATE INDEX IF NOT EXISTS hospital_diagnoses_patient_idx ON hospital.hospital_diagnoses (patient_id) WHERE removed_at IS NULL;

-- ====================================================================== laboratory
CREATE TABLE IF NOT EXISTS hospital.hospital_lab_tests (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    code           text NOT NULL,
    name           text NOT NULL,
    department     text NOT NULL DEFAULT 'chemistry'
                   CHECK (department IN ('haematology', 'chemistry', 'microbiology', 'serology', 'immunology', 'urinalysis',
                                         'parasitology', 'histopathology', 'molecular', 'other')),
    specimen       text NOT NULL DEFAULT 'blood'
                   CHECK (specimen IN ('blood', 'serum', 'plasma', 'urine', 'stool', 'swab', 'sputum', 'csf', 'tissue', 'other')),
    result_type    text NOT NULL DEFAULT 'numeric' CHECK (result_type IN ('numeric', 'text', 'choice')),
    choices        text[] NOT NULL DEFAULT '{}',
    abnormal_choices text[] NOT NULL DEFAULT '{}',
    unit           text,
    ref_low        numeric,
    ref_high       numeric,
    critical_low   numeric,
    critical_high  numeric,
    ref_text       text,
    tat_hours      int NOT NULL DEFAULT 24,
    price          numeric(14,2) NOT NULL DEFAULT 0,
    is_active      boolean NOT NULL DEFAULT true,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_lab_tests_code_uq ON hospital.hospital_lab_tests (bus_id, lower(code));

-- ========================================================================= pharmacy
CREATE TABLE IF NOT EXISTS hospital.hospital_drugs (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    code           text,
    generic_name   text NOT NULL,
    brand_name     text,
    strength       text,
    form           text NOT NULL DEFAULT 'tablet'
                   CHECK (form IN ('tablet', 'capsule', 'syrup', 'suspension', 'injection', 'infusion', 'cream', 'ointment', 'drops',
                                   'inhaler', 'suppository', 'patch', 'powder', 'device', 'other')),
    route          text,
    unit           text NOT NULL DEFAULT 'tablet',
    atc_code       text,
    price          numeric(14,2) NOT NULL DEFAULT 0,
    reorder_level  numeric NOT NULL DEFAULT 0,
    is_controlled  boolean NOT NULL DEFAULT false,
    is_active      boolean NOT NULL DEFAULT true,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz
);
CREATE INDEX IF NOT EXISTS hospital_drugs_name_idx ON hospital.hospital_drugs (bus_id, lower(generic_name));

CREATE TABLE IF NOT EXISTS hospital.hospital_stock_batches (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    facility_id   text NOT NULL REFERENCES hospital.hospital_facilities(id),
    drug_id       text NOT NULL REFERENCES hospital.hospital_drugs(id),
    batch_no      text NOT NULL,
    expires_on    date NOT NULL,
    quantity      numeric NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    received_qty  numeric NOT NULL DEFAULT 0,
    unit_cost     numeric(14,4) NOT NULL DEFAULT 0,
    supplier      text,
    received_at   timestamptz NOT NULL DEFAULT now(),
    received_by   text
);
CREATE INDEX IF NOT EXISTS hospital_batches_fefo_idx ON hospital.hospital_stock_batches (facility_id, drug_id, expires_on) WHERE quantity > 0;

CREATE TABLE IF NOT EXISTS hospital.hospital_stock_moves (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    facility_id  text NOT NULL,
    drug_id      text NOT NULL REFERENCES hospital.hospital_drugs(id),
    batch_id     text REFERENCES hospital.hospital_stock_batches(id),
    kind         text NOT NULL CHECK (kind IN ('receive', 'dispense', 'adjust', 'return', 'expire', 'damage')),
    quantity     numeric NOT NULL,
    order_id     text,
    reason       text,
    created_by   text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS hospital_moves_drug_idx ON hospital.hospital_stock_moves (facility_id, drug_id, cdatetime DESC);

-- =========================================================================== orders
CREATE TABLE IF NOT EXISTS hospital.hospital_orders (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    facility_id   text NOT NULL REFERENCES hospital.hospital_facilities(id),
    encounter_id  text NOT NULL REFERENCES hospital.hospital_encounters(id),
    patient_id    text NOT NULL REFERENCES hospital.hospital_patients(id),
    number        text NOT NULL,
    kind          text NOT NULL CHECK (kind IN ('lab', 'imaging', 'procedure', 'drug')),
    -- The lab test, the medicine, or the service (imaging and procedures) ordered.
    item_id       text,
    name          text NOT NULL,
    quantity      numeric NOT NULL DEFAULT 1,
    details       jsonb NOT NULL DEFAULT '{}',
    priority      text NOT NULL DEFAULT 'routine' CHECK (priority IN ('routine', 'urgent', 'stat')),
    status        text NOT NULL DEFAULT 'ordered'
                  CHECK (status IN ('ordered', 'collected', 'in_progress', 'resulted', 'released', 'dispensed', 'completed', 'cancelled')),
    notes         text,
    cancel_reason text,
    ordered_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_orders_number_uq ON hospital.hospital_orders (bus_id, number);
CREATE INDEX IF NOT EXISTS hospital_orders_encounter_idx ON hospital.hospital_orders (encounter_id);
CREATE INDEX IF NOT EXISTS hospital_orders_worklist_idx ON hospital.hospital_orders (facility_id, kind, status, cdatetime);

CREATE TABLE IF NOT EXISTS hospital.hospital_lab_results (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    order_id        text NOT NULL UNIQUE REFERENCES hospital.hospital_orders(id),
    test_id         text REFERENCES hospital.hospital_lab_tests(id),
    specimen_no     text,
    collected_at    timestamptz,
    collected_by    text,
    rejected_reason text,
    value_num       numeric,
    value_text      text,
    flag            text CHECK (flag IN ('normal', 'low', 'high', 'critical_low', 'critical_high', 'abnormal')),
    comment         text,
    entered_by      text,
    entered_at      timestamptz,
    validated_by    text,
    validated_at    timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_lab_specimen_uq ON hospital.hospital_lab_results (specimen_no) WHERE specimen_no IS NOT NULL;

-- ============================================================================ wards
CREATE TABLE IF NOT EXISTS hospital.hospital_wards (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    facility_id  text NOT NULL REFERENCES hospital.hospital_facilities(id),
    name         text NOT NULL,
    kind         text NOT NULL DEFAULT 'general'
                 CHECK (kind IN ('general', 'private', 'maternity', 'paediatric', 'surgical', 'icu', 'hdu', 'isolation', 'emergency', 'other')),
    gender       text NOT NULL DEFAULT 'any' CHECK (gender IN ('any', 'female', 'male')),
    daily_rate   numeric(14,2) NOT NULL DEFAULT 0,
    is_active    boolean NOT NULL DEFAULT true,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_wards_name_uq ON hospital.hospital_wards (facility_id, lower(name));

CREATE TABLE IF NOT EXISTS hospital.hospital_beds (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    facility_id  text NOT NULL REFERENCES hospital.hospital_facilities(id),
    ward_id      text NOT NULL REFERENCES hospital.hospital_wards(id),
    code         text NOT NULL,
    status       text NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'occupied', 'cleaning', 'reserved', 'blocked')),
    is_active    boolean NOT NULL DEFAULT true,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_beds_code_uq ON hospital.hospital_beds (ward_id, lower(code));

CREATE TABLE IF NOT EXISTS hospital.hospital_admissions (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    bus_id             text NOT NULL,
    facility_id        text NOT NULL REFERENCES hospital.hospital_facilities(id),
    encounter_id       text NOT NULL REFERENCES hospital.hospital_encounters(id),
    patient_id         text NOT NULL REFERENCES hospital.hospital_patients(id),
    ward_id            text NOT NULL REFERENCES hospital.hospital_wards(id),
    bed_id             text REFERENCES hospital.hospital_beds(id),
    attending_id       text,
    reason             text,
    status             text NOT NULL DEFAULT 'admitted' CHECK (status IN ('admitted', 'discharged')),
    admitted_at        timestamptz NOT NULL DEFAULT now(),
    admitted_by        text,
    discharged_at      timestamptz,
    discharged_by      text,
    outcome            text CHECK (outcome IN ('discharged', 'referred', 'transferred', 'dama', 'absconded', 'died')),
    discharge_summary  text,
    bed_days_billed    int NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_admissions_open_uq ON hospital.hospital_admissions (encounter_id) WHERE status = 'admitted';
CREATE UNIQUE INDEX IF NOT EXISTS hospital_admissions_bed_uq ON hospital.hospital_admissions (bed_id) WHERE status = 'admitted';

CREATE TABLE IF NOT EXISTS hospital.hospital_bed_moves (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    admission_id  text NOT NULL REFERENCES hospital.hospital_admissions(id),
    from_bed_id   text,
    to_bed_id     text,
    reason        text,
    moved_by      text,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);

COMMIT;
