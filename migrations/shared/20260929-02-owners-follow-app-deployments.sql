-- =====================================================================================
-- An owner reaches every location their apps are deployed to.
--
-- Permissions and locations are separate gates, and only the first one knows about owners.
-- The permission check answers true for the Owner role before it looks at anything
-- (tvs-package 1.0.42), but the platform-context check asks a different question: is this
-- org/business/location/app one this user has been given? That is cp_user_locations, and
-- nothing ever wrote an owner into it.
--
-- On saas-dev that left 29 deployed app locations and ONE owner location row between two
-- owners. The owner could pass every permission check in the platform and still be refused
-- with "Invalid platform context" before reaching one -- which is exactly what happened
-- when ZelosHR was tested.
--
-- So deployment now carries the owner with it. Deploy an app to a location and every owner
-- in that tenant is given it; withdraw the deployment and they lose it again, because an
-- owner should not keep access to something that is no longer there.
--
-- A trigger rather than application code, for the same reason the grant pair is one: this
-- table is written by the deployment flow, by seeds, and by migrations, and teaching each
-- of them separately is a standing invitation for one to be missed. A hard DELETE needs no
-- handling at all -- cp_user_locations.bus_app_loc_id is ON DELETE CASCADE.
--
-- Not covered here, deliberately: a user who BECOMES an owner later gets nothing
-- retroactively. Owners are created with the tenant, and a trigger on cp_users for a case
-- that does not occur is a trigger nobody would ever see run.
--
-- Safe to rerun.
-- =====================================================================================

CREATE OR REPLACE FUNCTION core_platform.cp_deployment_follows_owners()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    now_ts timestamptz := now();
BEGIN
    -- Withdrawn: take it off the owners too. Their access came from the deployment, so it
    -- should not outlive it.
    IF TG_OP = 'UPDATE'
       AND NEW.delete_status IS DISTINCT FROM OLD.delete_status
       AND NEW.delete_status <> 'NOT_DELETED' THEN
        UPDATE core_platform.cp_user_locations ul
           SET delete_status = NEW.delete_status,
               is_active     = false
          FROM core_platform.cp_users u
         WHERE ul.bus_app_loc_id = NEW.id
           AND ul.tenant_id      = NEW.tenant_id
           AND u.id              = ul.user_id
           AND u.tenant_id       = ul.tenant_id
           AND COALESCE(u.is_owner, false)
           AND ul.delete_status  = 'NOT_DELETED';
        RETURN NEW;
    END IF;

    -- Deployed, or restored after being withdrawn.
    IF NEW.delete_status <> 'NOT_DELETED' THEN
        RETURN NEW;
    END IF;

    -- Put back a row that was withdrawn with the deployment.
    UPDATE core_platform.cp_user_locations ul
       SET delete_status = 'NOT_DELETED',
           is_active     = true
      FROM core_platform.cp_users u
     WHERE ul.bus_app_loc_id = NEW.id
       AND ul.tenant_id      = NEW.tenant_id
       AND u.id              = ul.user_id
       AND u.tenant_id       = ul.tenant_id
       AND COALESCE(u.is_owner, false)
       AND ul.delete_status <> 'NOT_DELETED';

    -- And add one for any owner who does not have it. There is no unique constraint on
    -- (tenant_id, user_id, bus_app_loc_id), so NOT EXISTS does the work ON CONFLICT would.
    INSERT INTO core_platform.cp_user_locations
        (id, tenant_id, user_id, bus_app_loc_id, org_id, bus_id, app_id,
         cdate, ctime, cdatetime, delete_status, is_active, description)
    SELECT 'ulid_' || md5(NEW.id || ':' || u.id),
           NEW.tenant_id, u.id, NEW.id, NEW.org_id, NEW.bus_id, NEW.app_id,
           to_char(now_ts, 'FMDay FMDDth FMMonth, YYYY'),
           to_char(now_ts, 'HH12:MI AM'),
           now_ts, 'NOT_DELETED', true,
           'Owner follows the app deployment'
      FROM core_platform.cp_users u
     WHERE u.tenant_id = NEW.tenant_id
       AND COALESCE(u.is_owner, false)
       AND u.delete_status = 'NOT_DELETED'
       AND NOT EXISTS (
             SELECT 1 FROM core_platform.cp_user_locations ul
              WHERE ul.tenant_id = NEW.tenant_id
                AND ul.user_id = u.id
                AND ul.bus_app_loc_id = NEW.id
           );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_cp_deployment_follows_owners
    ON core_platform.cp_business_app_locations;
CREATE TRIGGER trg_cp_deployment_follows_owners
    AFTER INSERT OR UPDATE OF delete_status ON core_platform.cp_business_app_locations
    FOR EACH ROW EXECUTE FUNCTION core_platform.cp_deployment_follows_owners();

-- Backfill: the trigger only fires on new writes, and every deployment that already exists
-- is one an owner cannot currently reach.
INSERT INTO core_platform.cp_user_locations
    (id, tenant_id, user_id, bus_app_loc_id, org_id, bus_id, app_id,
     cdate, ctime, cdatetime, delete_status, is_active, description)
SELECT 'ulid_' || md5(bal.id || ':' || u.id),
       bal.tenant_id, u.id, bal.id, bal.org_id, bal.bus_id, bal.app_id,
       to_char(now(), 'FMDay FMDDth FMMonth, YYYY'),
       to_char(now(), 'HH12:MI AM'),
       now(), 'NOT_DELETED', true,
       'Owner follows the app deployment'
  FROM core_platform.cp_business_app_locations bal
  JOIN core_platform.cp_users u
    ON u.tenant_id = bal.tenant_id
   AND COALESCE(u.is_owner, false)
   AND u.delete_status = 'NOT_DELETED'
 WHERE bal.delete_status = 'NOT_DELETED'
   AND NOT EXISTS (
         SELECT 1 FROM core_platform.cp_user_locations ul
          WHERE ul.tenant_id = bal.tenant_id
            AND ul.user_id = u.id
            AND ul.bus_app_loc_id = bal.id
       );
