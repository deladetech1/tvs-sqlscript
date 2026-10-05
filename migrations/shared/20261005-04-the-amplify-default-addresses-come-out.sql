-- =====================================================================================
-- The Amplify default addresses come out of dev.
--
-- 20261002-02 registered six vendor-default hostnames so TENANCY_ENFORCE would not
-- refuse them:
--
--     dev.dfzxotrr84aq5.amplifyapp.com   core platform
--     dev.d19llexij7xvh3.amplifyapp.com  loandrift
--     dev.d1q82h5ftqrr6o.amplifyapp.com  mystoreguard
--     dev.d9tar2cmup9bx.amplifyapp.com   zeloshr admin
--     dev.d2vojxowprew1a.amplifyapp.com  zeloshr employees
--     dev.d308li0zuofobf.amplifyapp.com  commerce
--
-- They WORKED -- the page served and the API admitted the origin, verified before this
-- was written. They were the way in when a custom domain was the broken thing, which is
-- not hypothetical: renaming the console's domain on 2026-10-05 took its custom address
-- offline for several minutes.
--
-- Removed anyway, on a deliberate call: every product now has a custom domain, and a
-- second public front door that nobody uses is a second thing to remember in every
-- security review, every CORS list and every host allow-list. Four places had to agree
-- about them, which is four places that could disagree.
--
-- WHAT IS LOST, said plainly so nobody has to rediscover it: if a frontend's custom
-- domain or certificate breaks, there is now no alternative address for that app. The
-- fix is to repair the domain. That is an accepted cost, not an oversight.
--
-- WHAT IS NOT TOUCHED: the five *.azurecontainerapps.io rows. Those are load-bearing --
-- the console reaches core-platform at its container-app FQDN (deladetech's
-- azure-containerapp.tf), so deleting them would 404 every tenant-creation call. They
-- are also not public front doors; nobody signs in at one.
--
-- WHY A LATER MIGRATION RATHER THAN EDITING 20261002-02
-- Every migration re-runs on every deploy, so the insert there runs again and this
-- deletes again -- later wins, which is the convention this tree already uses for the
-- retired test hosts in 20261003-07. Editing a shipped migration to change what it did
-- would make the file disagree with every database that has already applied it.
--
-- THE OTHER THREE PLACES, which must be changed with this or they disagree:
--   * cors_origins in general/tvs-iac/platform/dev/env.hcl
--   * HUB_HOSTS in coreplatform-ft/src/utils/hubHost.ts
--   * the same list again in coreplatform-ft/src/middleware.ts (edge runtime, own bundle)
-- =====================================================================================

-- Guarded the same way the test hosts were: only rows that are still unclaimed
-- platform addresses. If one of these has somehow become a real tenant's route, it is
-- left alone rather than cutting a customer off.
DELETE FROM control_plane.ctl_tenant_routes
 WHERE host LIKE '%.amplifyapp.com'
   AND tier = 'POOLED'
   AND tenant_id IS NULL
   AND silo_key IS NULL;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer; survivors text;
BEGIN
    SELECT count(*), COALESCE(string_agg(host, ', '), '')
      INTO n, survivors
      FROM control_plane.ctl_tenant_routes
     WHERE host LIKE '%.amplifyapp.com';
    IF n > 0 THEN
        RAISE EXCEPTION '% amplify route(s) survived: %. If one is now a real '
                        'tenant route the guard above spared it, which is correct -- '
                        'say so here rather than widening the DELETE', n, survivors;
    END IF;

    -- THE CONTAINER-APP ROWS STAY. They are not a second front door, they are how the
    -- console reaches core-platform, and a future tidy-up that treats "vendor hostname"
    -- as one category would take them out with the others and break tenant creation.
    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE host LIKE '%.azurecontainerapps.io';
    IF n = 0 THEN
        RAISE EXCEPTION 'the container-app routes went too -- the console reaches '
                        'core-platform at its FQDN and tenant creation will 404';
    END IF;

    -- And the real front doors are untouched. Deleting a product's custom domain is
    -- the one mistake here that would be an outage rather than a tidy-up.
    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE host IN ('dev.trovesuite.com', 'api.dev.trovesuite.com',
                    'mystoreguard.dev.trovesuite.com', 'loandrift.dev.trovesuite.com',
                    'zeloshr.dev.trovesuite.com', 'zeloshr-admin.dev.trovesuite.com');
    IF n <> 6 THEN
        RAISE EXCEPTION 'only % of the 6 custom front doors remain', n;
    END IF;

    RAISE NOTICE 'the amplify default addresses are out; % container-app routes kept',
        (SELECT count(*) FROM control_plane.ctl_tenant_routes
          WHERE host LIKE '%.azurecontainerapps.io');
END $$;
