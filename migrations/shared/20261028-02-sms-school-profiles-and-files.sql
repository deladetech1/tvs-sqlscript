-- SMS: school profiles and the file manager.
--
--   sms_profiles   one school each: how it appears on reports, receipts and the parent app
--                  (name, short name, logo, motto, year founded, registration number); what kind
--                  of institution it is (sector, type, the levels it runs); its classification
--                  (ownership, day or boarding, gender, delivery); where it is (its Core Platform
--                  location -- required, one school per location -- and its country, region,
--                  city and address); its currency (one of the organisation's in Core Platform),
--                  language and date format; and its contacts. A business runs as many schools as
--                  it has locations, and the person switches between them in the app (the
--                  sms-profile header). A profile saved as a draft can be finished later; the
--                  first finished one is the business's default and cannot be deleted. A deleted
--                  profile frees its location and cannot be opened again.
--   sms_files      images and documents for any SMS record, as HMS's: uploaded before or after
--                  the record (a new school's logo goes up while the form is open, then is
--                  attached), with a description, kept under images/ or documents/. A school's
--                  logo is its file with purpose 'logo'; a new one replaces the old.
--
-- The time zone is not stored: it is the organisation's, in Core Platform. Idempotent; safe to
-- re-run on every deploy.

BEGIN;

-- =================================================================== profiles
CREATE TABLE IF NOT EXISTS sms.sms_profiles (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    status           text NOT NULL DEFAULT 'draft',
    is_default       boolean NOT NULL DEFAULT false,
    -- 1. identity
    name             text NOT NULL,
    short_name       text,
    year_founded     int,
    motto            text,
    registration_no  text,
    -- 2. institution type
    sector           text,
    institution_type text,
    custom_type      text,
    -- 3. levels offered
    levels           text[] NOT NULL DEFAULT '{}',
    -- 4. classification
    ownership        text,
    residential      text,
    gender           text,
    delivery         text,
    -- 5. location and regional settings
    location_id      text NOT NULL,
    country          text,
    region           text,
    city             text,
    address          text,
    currency         text,
    language         text NOT NULL DEFAULT 'en',
    date_format      text NOT NULL DEFAULT 'DD/MM/YYYY',
    -- 6. contact
    phone            text,
    email            text,
    website          text,
    head_name        text,
    -- the record
    completed_at     timestamptz,
    deleted_at       timestamptz,
    deleted_by       text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz,
    created_by       text,
    updated_by       text
);

ALTER TABLE sms.sms_profiles DROP CONSTRAINT IF EXISTS sms_profiles_status_check;
ALTER TABLE sms.sms_profiles ADD CONSTRAINT sms_profiles_status_check CHECK (status IN ('draft', 'active'));
ALTER TABLE sms.sms_profiles DROP CONSTRAINT IF EXISTS sms_profiles_sector_check;
ALTER TABLE sms.sms_profiles ADD CONSTRAINT sms_profiles_sector_check
    CHECK (sector IS NULL OR sector IN ('k12', 'higher', 'tvet', 'other'));
ALTER TABLE sms.sms_profiles DROP CONSTRAINT IF EXISTS sms_profiles_ownership_check;
ALTER TABLE sms.sms_profiles ADD CONSTRAINT sms_profiles_ownership_check
    CHECK (ownership IS NULL OR ownership IN ('private', 'public', 'mission', 'community', 'international', 'ngo'));
ALTER TABLE sms.sms_profiles DROP CONSTRAINT IF EXISTS sms_profiles_residential_check;
ALTER TABLE sms.sms_profiles ADD CONSTRAINT sms_profiles_residential_check
    CHECK (residential IS NULL OR residential IN ('day', 'boarding', 'day_boarding'));
ALTER TABLE sms.sms_profiles DROP CONSTRAINT IF EXISTS sms_profiles_gender_check;
ALTER TABLE sms.sms_profiles ADD CONSTRAINT sms_profiles_gender_check
    CHECK (gender IS NULL OR gender IN ('coed', 'boys', 'girls'));
ALTER TABLE sms.sms_profiles DROP CONSTRAINT IF EXISTS sms_profiles_delivery_check;
ALTER TABLE sms.sms_profiles ADD CONSTRAINT sms_profiles_delivery_check
    CHECK (delivery IS NULL OR delivery IN ('in_person', 'online', 'hybrid'));
ALTER TABLE sms.sms_profiles DROP CONSTRAINT IF EXISTS sms_profiles_year_check;
ALTER TABLE sms.sms_profiles ADD CONSTRAINT sms_profiles_year_check
    CHECK (year_founded IS NULL OR year_founded BETWEEN 1000 AND 2200);
-- A finished school has everything the form marks required.
ALTER TABLE sms.sms_profiles DROP CONSTRAINT IF EXISTS sms_profiles_active_check;
ALTER TABLE sms.sms_profiles ADD CONSTRAINT sms_profiles_active_check
    CHECK (status = 'draft' OR deleted_at IS NOT NULL OR
           (sector IS NOT NULL AND institution_type IS NOT NULL AND cardinality(levels) > 0
            AND country IS NOT NULL AND phone IS NOT NULL AND email IS NOT NULL));

-- One default per business, one live school per name, one live school per location.
CREATE UNIQUE INDEX IF NOT EXISTS sms_profiles_default_uq ON sms.sms_profiles (bus_id) WHERE is_default AND deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS sms_profiles_name_uq ON sms.sms_profiles (bus_id, lower(name)) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS sms_profiles_location_uq ON sms.sms_profiles (bus_id, location_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS sms_profiles_business_idx ON sms.sms_profiles (tenant_id, bus_id) WHERE deleted_at IS NULL;

-- ===================================================================== files
CREATE TABLE IF NOT EXISTS sms.sms_files (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    entity_type   text,
    entity_id     text,
    kind          text NOT NULL DEFAULT 'image',
    purpose       text NOT NULL DEFAULT 'photo',
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

SELECT sms.widen_check('sms.sms_files', 'sms_files_kind_check', $q$'document'$q$, $q$CHECK (kind IN ('image', 'document'))$q$);
ALTER TABLE sms.sms_files DROP CONSTRAINT IF EXISTS sms_files_attached_check;
ALTER TABLE sms.sms_files ADD CONSTRAINT sms_files_attached_check CHECK ((entity_type IS NULL) = (entity_id IS NULL));
ALTER TABLE sms.sms_files DROP CONSTRAINT IF EXISTS sms_files_purpose_check;
ALTER TABLE sms.sms_files ADD CONSTRAINT sms_files_purpose_check
    CHECK (purpose IN ('photo', 'logo', 'avatar', 'id_document', 'signature', 'document'));
-- Created here; a later migration that adds records widens it and owns it from then on (every
-- file re-runs on each deploy, so this one must not narrow it back).
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'sms_files_entity_check' AND conrelid = 'sms.sms_files'::regclass) THEN
    ALTER TABLE sms.sms_files ADD CONSTRAINT sms_files_entity_check CHECK (entity_type IS NULL OR entity_type IN ('profile'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS sms_files_entity_idx ON sms.sms_files (bus_id, entity_type, entity_id, sort_order);
CREATE INDEX IF NOT EXISTS sms_files_unattached_idx ON sms.sms_files (bus_id, cdatetime) WHERE entity_type IS NULL;

-- ===================================================================== invariants
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM sms.sms_profiles WHERE deleted_at IS NULL GROUP BY bus_id, location_id HAVING count(*) > 1) THEN
        RAISE EXCEPTION 'a location runs more than one live school profile';
    END IF;
END $$;

COMMIT;
