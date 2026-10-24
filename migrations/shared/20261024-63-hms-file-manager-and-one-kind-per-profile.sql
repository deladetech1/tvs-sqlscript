-- HMS: a file manager as LoanDrift's, and one kind of business per profile.
--
--   hms_files       images and documents, uploaded before or after the record they belong to
--                   (a new guest's photo is uploaded while the form is open, then attached), with a
--                   description, kept under images/ or documents/; many more records take them:
--                   rooms and units, the menu and its categories, extras, activities, tables,
--                   stock items, staff.
--   hms_profiles    one kind of business each (a hotel; a restaurant is another profile), one
--                   profile per location, and deleted profiles.

BEGIN;

-- ================================================================== files
ALTER TABLE hms.hms_files ALTER COLUMN entity_type DROP NOT NULL;
ALTER TABLE hms.hms_files ALTER COLUMN entity_id DROP NOT NULL;
ALTER TABLE hms.hms_files ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'image';
ALTER TABLE hms.hms_files ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE hms.hms_files ADD COLUMN IF NOT EXISTS updated_at timestamptz;
UPDATE hms.hms_files SET kind = CASE WHEN content_type LIKE 'image/%' THEN 'image' ELSE 'document' END;

ALTER TABLE hms.hms_files DROP CONSTRAINT IF EXISTS hms_files_kind_check;
ALTER TABLE hms.hms_files ADD CONSTRAINT hms_files_kind_check CHECK (kind IN ('image', 'document'));
-- Created here; widened by a later migration, which owns it from then on (every file re-runs on each deploy).
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'hms_files_entity_check' AND conrelid = 'hms.hms_files'::regclass) THEN
    ALTER TABLE hms.hms_files ADD CONSTRAINT hms_files_entity_check CHECK (entity_type IS NULL OR entity_type IN
        ('property', 'unit_type', 'unit', 'guest', 'reservation', 'lease', 'renter', 'ticket', 'lost_item', 'asset', 'event', 'expense', 'staff',
         'menu_item', 'menu_category', 'addon', 'activity', 'table', 'stock_item', 'voucher', 'company', 'owner', 'site'));
  END IF;
END $$;
ALTER TABLE hms.hms_files DROP CONSTRAINT IF EXISTS hms_files_attached_check;
ALTER TABLE hms.hms_files ADD CONSTRAINT hms_files_attached_check CHECK ((entity_type IS NULL) = (entity_id IS NULL));
ALTER TABLE hms.hms_files DROP CONSTRAINT IF EXISTS hms_files_purpose_check;
ALTER TABLE hms.hms_files ADD CONSTRAINT hms_files_purpose_check CHECK (purpose IN ('photo', 'avatar', 'id_document', 'signature', 'document'));
CREATE INDEX IF NOT EXISTS hms_files_unattached_idx ON hms.hms_files (bus_id, cdatetime) WHERE entity_type IS NULL;

-- ================================================================ profiles
ALTER TABLE hms.hms_profiles ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
ALTER TABLE hms.hms_profiles ADD COLUMN IF NOT EXISTS deleted_by text;

-- One kind each: what a profile was showing is what it is.
UPDATE hms.hms_profiles SET business_types = ARRAY[business_type] WHERE cardinality(business_types) <> 1 OR business_types[1] <> business_type;
UPDATE hms.hms_settings SET business_types = ARRAY[business_type] WHERE cardinality(business_types) <> 1 OR business_types[1] <> business_type;

-- A location belongs to one profile: a later profile that shares one gives it up.
UPDATE hms.hms_profiles p SET location_ids = ARRAY(
    SELECT l FROM unnest(p.location_ids) l
     WHERE NOT EXISTS (SELECT 1 FROM hms.hms_profiles o WHERE o.bus_id = p.bus_id AND o.id <> p.id AND o.deleted_at IS NULL
                         AND l = ANY(o.location_ids) AND (o.is_default OR o.cdatetime < p.cdatetime)))
 WHERE p.deleted_at IS NULL AND NOT p.is_default;

COMMIT;
