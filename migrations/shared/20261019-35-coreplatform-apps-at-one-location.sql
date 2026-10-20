-- =====================================================================
-- Apps a business uses at one location only
-- ---------------------------------------------------------------------
-- The CRM, Projects, Expenses and Invoicing work for the whole business, not
-- for a shop or branch, so a business places each of them at one location.
-- core_platform.cp_apps.max_locations says how many locations of a business an
-- app may be placed at (NULL: any number). Placing it at one more -- by
-- subscribing, by deploying it, by any path -- is refused here, in the
-- database, with a sentence the screens show as it is.
--
-- No business had one of these apps at more than one location when this was
-- written (dev and prod checked); a row already there is not touched.
--
-- Re-runs every deploy: idempotent.
-- =====================================================================
BEGIN;

ALTER TABLE core_platform.cp_apps ADD COLUMN IF NOT EXISTS max_locations integer CHECK (max_locations IS NULL OR max_locations > 0);

UPDATE core_platform.cp_apps SET max_locations = 1
 WHERE id IN ('app-crm', 'app-projects', 'app-expenses', 'app-invoicing') AND max_locations IS DISTINCT FROM 1;

CREATE OR REPLACE FUNCTION core_platform.cp_business_app_locations_limit() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE
    lim integer;
    used integer;
    app text;
BEGIN
    IF NEW.delete_status IS DISTINCT FROM 'NOT_DELETED' OR NEW.is_active IS NOT TRUE THEN
        RETURN NEW;
    END IF;
    SELECT max_locations, CASE WHEN app_name ~ '^[A-Z]{2,4}$' THEN app_name ELSE initcap(lower(app_name)) END INTO lim, app FROM core_platform.cp_apps WHERE id = NEW.app_id;
    IF lim IS NULL THEN
        RETURN NEW;
    END IF;
    -- One business's places for the app, other than this row (and this row's own location).
    SELECT count(DISTINCT loc_id) INTO used FROM core_platform.cp_business_app_locations
     WHERE tenant_id = NEW.tenant_id AND business_app_id = NEW.business_app_id AND id <> NEW.id
       AND loc_id <> NEW.loc_id AND delete_status = 'NOT_DELETED' AND is_active;
    IF used >= lim THEN
        RAISE EXCEPTION '% is used at % location of a business. Remove it from its location first to move it.',
            coalesce(app, 'This app'), lim USING ERRCODE = 'check_violation', HINT = 'APP_LOCATION_LIMIT';
    END IF;
    RETURN NEW;
END
$f$;

DO $$
BEGIN
    IF to_regclass('core_platform.cp_business_app_locations') IS NOT NULL THEN
        DROP TRIGGER IF EXISTS cp_business_app_locations_limit ON core_platform.cp_business_app_locations;
        CREATE TRIGGER cp_business_app_locations_limit BEFORE INSERT OR UPDATE OF loc_id, is_active, delete_status
            ON core_platform.cp_business_app_locations
            FOR EACH ROW EXECUTE FUNCTION core_platform.cp_business_app_locations_limit();
    END IF;
END $$;

COMMIT;
