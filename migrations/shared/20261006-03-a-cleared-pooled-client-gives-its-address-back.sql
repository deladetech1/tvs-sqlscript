-- =====================================================================================
-- A cleared pooled client gives its address back.
--
-- 20261006-02 gave every signup an address of its own. The console's clear was written
-- when a pooled client had none, and says so:
--
--     "Only a silo has one to reset. A pooled client shares the host with every other
--      pooled tenant, so there is nothing here to free"
--
-- That was true in the morning and is not true now. Clearing a pooled client today
-- deletes the tenant and leaves acme-ltd.trovesuite.com in the route table pointing at a
-- tenant that no longer exists -- an address that resolves to nothing, and a name that
-- can never be used again, including by the same company signing up a second time.
--
-- WHY DELETE AND NOT RESET
-- A silo's route is reset to its placeholder because the INFRASTRUCTURE survives the
-- clear: the database, the server and the storage are all still there waiting for the
-- next tenant. A pooled client's address is not infrastructure. Nothing is left behind
-- to point it at, so the row goes and the name returns to the pool.
--
-- Which is why this REFUSES a silo route rather than handling both. A function that
-- deleted a silo's row would take that silo off the air and leave its database
-- unreachable, with nothing in the route table to say it existed.
--
-- WHY A FUNCTION
-- Application roles hold SELECT on ctl_tenant_routes and nothing else. Same reasoning as
-- reconcile_route_tenant and claim_tenant_host: a route row is what makes a host resolve
-- to a database, so DELETE on that table lets any app take any customer off the air.
--
-- THE EXPECTED TENANT IS REQUIRED, not optional. Freeing an address is indistinguishable
-- from taking a live client offline if the caller is working from stale state -- the
-- clear reads the route, purges the tenant, then comes back here, and in between a
-- different tenant could hold that host. Passing the id it believes is there turns that
-- race into a refusal instead of an outage.
-- =====================================================================================

CREATE OR REPLACE FUNCTION control_plane.release_tenant_host(
    p_host text, p_expected_tenant_id text, p_released_by text DEFAULT NULL)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'control_plane', 'pg_catalog'
AS $function$
DECLARE
    r control_plane.ctl_tenant_routes;
BEGIN
    IF p_expected_tenant_id IS NULL OR btrim(p_expected_tenant_id) = '' THEN
        RAISE EXCEPTION 'the tenant this address belongs to must be stated';
    END IF;

    SELECT * INTO r FROM control_plane.ctl_tenant_routes
     WHERE host = lower(btrim(coalesce(p_host, '')));
    IF NOT FOUND THEN
        -- Not an error. The clear is idempotent by design and may be retried after a
        -- partial failure, so an address that is already gone is the wanted state.
        RETURN NULL;
    END IF;

    -- NEVER one of ours. dev.trovesuite.com is where signup runs; deleting it takes
    -- every pooled client off the air at once.
    IF r.route_kind <> 'TENANT' THEN
        RAISE EXCEPTION
            'route % is a % address, shared by every tenant, and cannot be released',
            r.host, r.route_kind
            USING ERRCODE = 'check_violation';
    END IF;

    -- A SILO keeps its row. The database and server outlive the tenant, and the route
    -- is how anything finds them -- it is reset to its placeholder by
    -- reconcile_route_tenant, not deleted.
    IF r.silo_key IS NOT NULL AND btrim(r.silo_key) <> '' THEN
        RAISE EXCEPTION
            'route % belongs to silo %, whose infrastructure outlives the tenant -- '
            'reset it with reconcile_route_tenant instead of releasing it',
            r.host, r.silo_key
            USING ERRCODE = 'check_violation';
    END IF;

    -- The race the clear can actually lose.
    IF r.tenant_id IS DISTINCT FROM p_expected_tenant_id THEN
        RAISE EXCEPTION
            'route % belongs to tenant %, not %, so releasing it would take a '
            'different client off the air',
            r.host, COALESCE(r.tenant_id, '(none)'), p_expected_tenant_id
            USING ERRCODE = 'check_violation';
    END IF;

    DELETE FROM control_plane.ctl_tenant_routes WHERE host = r.host;
    RAISE NOTICE 'released % from tenant % (by %)',
        r.host, p_expected_tenant_id, COALESCE(p_released_by, session_user);
    RETURN r.host;
END
$function$;

COMMENT ON FUNCTION control_plane.release_tenant_host(text, text, text) IS
    'Give a pooled tenant''s own address back when the tenant is cleared, so the name can '
    'be used again. Refuses a PLATFORM route and refuses a SILO route -- a silo''s '
    'infrastructure outlives its tenant and its row is reset, not removed. The expected '
    'tenant id is required: it turns a stale call into a refusal rather than an outage.';

-- ------------------------------------------------------------------------- the grant
DO $$
DECLARE grp text; n integer := 0;
BEGIN
    FOR grp IN
        SELECT rolname FROM pg_roles
         WHERE rolname ~ '^tvs_app_[a-z0-9]+$' AND NOT rolcanlogin
    LOOP
        EXECUTE format('GRANT EXECUTE ON FUNCTION control_plane.release_tenant_host('
                       'text, text, text) TO %I', grp);
        n := n + 1;
    END LOOP;
    RAISE NOTICE 'a clear may release an address: granted to % app group(s)', n;
END $$;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE parent text; got text; n integer; before_count integer;
BEGIN
    SELECT count(*) INTO before_count FROM control_plane.ctl_tenant_routes;

    SELECT host INTO parent FROM control_plane.ctl_tenant_routes
     WHERE route_kind = 'PLATFORM' AND status = 'ACTIVE'
       AND host LIKE '%trovesuite.com' ORDER BY length(host) LIMIT 1;
    IF parent IS NULL THEN
        RAISE NOTICE 'no platform parent here; the release cannot be exercised';
        RETURN;
    END IF;

    -- A pooled client's own address goes, and the name comes back.
    PERFORM control_plane.claim_tenant_host('probereleaseco', parent, 'tnt_probe_rel');
    got := control_plane.tenant_host_refusal('probereleaseco', parent);
    IF got IS NULL THEN
        RAISE EXCEPTION 'the name is still free while a route holds it';
    END IF;

    got := control_plane.release_tenant_host('probereleaseco.' || parent,
                                             'tnt_probe_rel', 'migration');
    IF got IS DISTINCT FROM 'probereleaseco.' || parent THEN
        RAISE EXCEPTION 'the release returned %, not the host it freed', got;
    END IF;
    IF control_plane.tenant_host_refusal('probereleaseco', parent) IS NOT NULL THEN
        RAISE EXCEPTION 'the name did not come back after the address was released';
    END IF;

    -- Releasing something already gone is fine -- the clear may be retried.
    IF control_plane.release_tenant_host('probereleaseco.' || parent,
                                          'tnt_probe_rel') IS NOT NULL THEN
        RAISE EXCEPTION 'releasing an absent address claimed to free something';
    END IF;

    -- A STALE caller is refused rather than taking a live client off the air.
    PERFORM control_plane.claim_tenant_host('probereleaseco', parent, 'tnt_probe_rel2');
    BEGIN
        PERFORM control_plane.release_tenant_host('probereleaseco.' || parent,
                                                   'tnt_probe_rel');
        RAISE EXCEPTION 'an address was released out from under the tenant that holds it';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    PERFORM control_plane.release_tenant_host('probereleaseco.' || parent,
                                               'tnt_probe_rel2');

    -- OUR OWN ADDRESS is refused. This is the one that would be an outage.
    BEGIN
        PERFORM control_plane.release_tenant_host(parent, 'anything');
        RAISE EXCEPTION 'a PLATFORM address was released, taking every pooled client '
                        'off the air';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- A SILO's route is refused: its database outlives the tenant.
    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE silo_key IS NOT NULL AND route_kind = 'TENANT';
    IF n > 0 THEN
        DECLARE sh text; st text;
        BEGIN
            SELECT host, tenant_id INTO sh, st FROM control_plane.ctl_tenant_routes
             WHERE silo_key IS NOT NULL AND route_kind = 'TENANT' LIMIT 1;
            BEGIN
                PERFORM control_plane.release_tenant_host(sh, st);
                RAISE EXCEPTION 'silo route % was deleted, so that database is now '
                                'unreachable', sh;
            EXCEPTION WHEN check_violation THEN NULL;
            END;
        END;
    END IF;

    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes;
    IF n <> before_count THEN
        RAISE EXCEPTION 'the route table went from % to % rows', before_count, n;
    END IF;

    RAISE NOTICE 'a cleared pooled client gives its address back';
END $$;
