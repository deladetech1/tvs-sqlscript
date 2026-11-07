-- Hospital, part 2: facility profiles, settings, the file manager and the notices.
--
-- A business runs one facility per Core Platform location (a clinic, a hospital, a branch of a
-- group), each with its own profile: what kind of facility it is, where, its licences and the
-- modules it uses. Patients are the BUSINESS's, not a facility's: one record per patient across
-- every branch (hospital_patients, part 3).
--
-- Files (images and documents for any record: a facility's logo, a patient's photo, scanned
-- referral letters, consent forms, wound photos, a lab report) are as LoanDrift's file manager:
-- the bytes in the app's private storage (container hospital-files), a row here per file.
-- Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS hospital.hospital_facilities (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    org_id             text,
    bus_id             text NOT NULL,
    status             text NOT NULL DEFAULT 'draft',
    is_default         boolean NOT NULL DEFAULT false,
    name               text NOT NULL,
    short_name         text,
    facility_type      text,
    ownership          text,
    registration_no    text,
    licence_no         text,
    licence_expires_on date,
    beds_licensed      int,
    location_id        text NOT NULL,
    country            text,
    region             text,
    city               text,
    address            text,
    currency           text,
    phone              text,
    email              text,
    website            text,
    emergency_phone    text,
    director_name      text,
    modules            text[],
    -- The waiting-room screen's own address (/display/<token>): no sign-in, names never shown.
    display_token      text NOT NULL DEFAULT replace(gen_random_uuid()::text, '-', ''),
    completed_at       timestamptz,
    deleted_at         timestamptz,
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz,
    created_by         text
);
SELECT hospital.widen_check('hospital.hospital_facilities', 'hospital_facilities_status_check', $q$'active'$q$,
    $q$CHECK (status IN ('draft', 'active'))$q$);
SELECT hospital.widen_check('hospital.hospital_facilities', 'hospital_facilities_modules_check', $q$'insurance'$q$,
    $q$CHECK (modules IS NULL OR modules <@ ARRAY['appointments', 'queue', 'opd', 'lab', 'pharmacy', 'ipd', 'insurance']::text[])$q$);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_facilities_location_uq ON hospital.hospital_facilities (bus_id, location_id) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS hospital_facilities_display_uq ON hospital.hospital_facilities (display_token);
CREATE INDEX IF NOT EXISTS hospital_facilities_business_idx ON hospital.hospital_facilities (bus_id) WHERE deleted_at IS NULL;

-- The business's own way of numbering and identifying patients: one record across facilities.
CREATE TABLE IF NOT EXISTS hospital.hospital_settings (
    bus_id            text PRIMARY KEY,
    tenant_id         text NOT NULL,
    mrn_prefix        text NOT NULL DEFAULT 'MRN',
    mrn_digits        int NOT NULL DEFAULT 6,
    -- [{key, label, required, unique}]: the identity documents patients carry in this country.
    identifier_types  jsonb NOT NULL DEFAULT '[]',
    country           text,
    -- Whether outpatients pay before a service (cash patients) or are billed after.
    pay_first         boolean NOT NULL DEFAULT false,
    updated_at        timestamptz,
    updated_by        text
);

-- Counters: the next number for a business's series (patients, visits, receipts, claims...).
CREATE TABLE IF NOT EXISTS hospital.hospital_counters (
    bus_id   text NOT NULL,
    series   text NOT NULL,
    n        bigint NOT NULL DEFAULT 0,
    PRIMARY KEY (bus_id, series)
);

CREATE TABLE IF NOT EXISTS hospital.hospital_notifications (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    facility_id text,
    user_id     text NOT NULL,
    title       text NOT NULL,
    body        text,
    link        text,
    read_at     timestamptz,
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS hospital_notifications_user_idx ON hospital.hospital_notifications (bus_id, user_id, cdatetime DESC);

-- ============================================================================ files
CREATE TABLE IF NOT EXISTS hospital.hospital_files (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    entity_type   text,
    entity_id     text,
    kind          text NOT NULL DEFAULT 'image',
    purpose       text NOT NULL DEFAULT 'photo',
    category      text,
    description   text,
    path          text NOT NULL,
    file_name     text NOT NULL,
    content_type  text NOT NULL,
    size_bytes    bigint NOT NULL DEFAULT 0,
    sort_order    int NOT NULL DEFAULT 0,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz,
    created_by    text
);
SELECT hospital.widen_check('hospital.hospital_files', 'hospital_files_kind_check', $q$'document'$q$,
    $q$CHECK (kind IN ('image', 'document'))$q$);
ALTER TABLE hospital.hospital_files DROP CONSTRAINT IF EXISTS hospital_files_attached_check;
ALTER TABLE hospital.hospital_files ADD CONSTRAINT hospital_files_attached_check CHECK ((entity_type IS NULL) = (entity_id IS NULL));
SELECT hospital.widen_check('hospital.hospital_files', 'hospital_files_purpose_check', $q$'signature'$q$,
    $q$CHECK (purpose IN ('photo', 'logo', 'avatar', 'id_document', 'document', 'clinical_image', 'scan', 'consent', 'report', 'referral', 'signature'))$q$);
SELECT hospital.widen_check('hospital.hospital_files', 'hospital_files_entity_check', $q$'order'$q$,
    $q$CHECK (entity_type IS NULL OR entity_type IN ('facility', 'patient', 'encounter', 'order'))$q$);
CREATE INDEX IF NOT EXISTS hospital_files_entity_idx ON hospital.hospital_files (bus_id, entity_type, entity_id, sort_order);
CREATE INDEX IF NOT EXISTS hospital_files_unattached_idx ON hospital.hospital_files (bus_id, cdatetime) WHERE entity_type IS NULL;

-- ======================================================================= invariants
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM hospital.hospital_facilities WHERE deleted_at IS NULL GROUP BY bus_id, location_id HAVING count(*) > 1) THEN
        RAISE EXCEPTION 'a location runs more than one live facility';
    END IF;
    IF EXISTS (SELECT 1 FROM hospital.hospital_facilities WHERE deleted_at IS NULL AND is_default GROUP BY bus_id HAVING count(*) > 1) THEN
        RAISE EXCEPTION 'a business has more than one default facility';
    END IF;
END $$;

COMMIT;
