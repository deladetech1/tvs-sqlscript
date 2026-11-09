-- Core Platform: a location says where it is.
--
-- The create screen now asks for the country first (ISO 3166-1 alpha-2), then its state or
-- region, then the name, then what else is useful: town or city, street address, digital
-- address or postcode, phone, email, and the time zone (offered from the country).
-- All nullable: locations made before this, and by sign-up or the console, have none of it
-- until someone edits them; only the create screen requires country and region.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE core_platform.cp_locations ADD COLUMN IF NOT EXISTS country_code    text;
ALTER TABLE core_platform.cp_locations ADD COLUMN IF NOT EXISTS region          text;
ALTER TABLE core_platform.cp_locations ADD COLUMN IF NOT EXISTS city            text;
ALTER TABLE core_platform.cp_locations ADD COLUMN IF NOT EXISTS address_line    text;
ALTER TABLE core_platform.cp_locations ADD COLUMN IF NOT EXISTS digital_address text;
ALTER TABLE core_platform.cp_locations ADD COLUMN IF NOT EXISTS phone           text;
ALTER TABLE core_platform.cp_locations ADD COLUMN IF NOT EXISTS email           text;
ALTER TABLE core_platform.cp_locations ADD COLUMN IF NOT EXISTS timezone        text;

ALTER TABLE core_platform.cp_locations DROP CONSTRAINT IF EXISTS cp_locations_country_code_check;
ALTER TABLE core_platform.cp_locations ADD CONSTRAINT cp_locations_country_code_check
    CHECK (country_code IS NULL OR country_code ~ '^[A-Z]{2}$');

CREATE INDEX IF NOT EXISTS ix_cp_locations_tenant_country
    ON core_platform.cp_locations (tenant_id, country_code);

COMMIT;
