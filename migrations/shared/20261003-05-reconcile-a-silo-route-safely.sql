-- =====================================================================================
-- Let an application point a silo's route at the tenant that now exists in it,
-- without letting it rewrite the route table.
--
-- THE PROBLEM
-- A silo's route row is written when its infrastructure is built, which is before
-- anybody has an account in it, so tenant_id starts as a placeholder derived from the
-- silo key ('tnt_itech'). Creating the first account produces a tenant with a generated
-- id, and until the route is repointed the two disagree -- which is what a tenant
-- pinning check compares.
--
-- The console does that repointing, and could not: application roles have SELECT on
-- ctl_tenant_routes and nothing else, so the update failed with
-- "permission denied for table ctl_tenant_routes". It had worked in testing because
-- that ran with the migrator credential, which owns the table.
--
-- WHY NOT JUST GRANT UPDATE
-- Because the grant would be to tvs_app_<env>, the group every application belongs to.
-- A route row is what makes a host resolve to a database; UPDATE on it means any
-- application could point any customer's address at any tenant, including its own.
-- That is a much larger privilege than the problem needs.
--
-- WHAT THIS DOES INSTEAD
-- One SECURITY DEFINER function, owned by the table's owner, that performs exactly the
-- reconciliation and refuses everything else. The caller cannot choose which columns to
-- write, cannot touch a route that already belongs to a real tenant, and cannot touch a
-- POOLED route at all.
--
-- The pooled rule matters most. dev.trovesuite.com serves EVERY pooled tenant and its
-- tenant_id is NULL by design -- which looks identical to a silo waiting for its first
-- account. Pinning it to one customer would take every other pooled customer off the
-- air. The application already refuses this; putting it here too means a second
-- implementation cannot get it wrong.
-- =====================================================================================

CREATE OR REPLACE FUNCTION control_plane.reconcile_route_tenant(
    p_host        text,
    p_tenant_id   text,
    p_expected    text,
    p_updated_by  text DEFAULT NULL
)
RETURNS control_plane.ctl_tenant_routes
LANGUAGE plpgsql
SECURITY DEFINER
-- Resolution is pinned so a caller cannot shadow anything referenced below with
-- objects of their own: the usual precaution for a definer-rights function.
SET search_path = control_plane, pg_catalog
AS $$
DECLARE
    r control_plane.ctl_tenant_routes;
BEGIN
    IF p_tenant_id IS NULL OR btrim(p_tenant_id) = '' THEN
        RAISE EXCEPTION 'a tenant id is required';
    END IF;

    SELECT * INTO r FROM control_plane.ctl_tenant_routes WHERE host = p_host;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'no route for host %', p_host
            USING ERRCODE = 'no_data_found';
    END IF;

    -- Only a silo's route may be bound to one tenant. A POOLED host is shared.
    IF r.tier NOT IN ('SILO_SHARED', 'SILO_DEDICATED', 'SELF_MANAGED') THEN
        RAISE EXCEPTION
            'route % is %, which is shared by every pooled tenant and cannot be '
            'assigned to one client', p_host, r.tier
            USING ERRCODE = 'check_violation';
    END IF;

    -- Only from the placeholder (or nothing) to a real tenant. Never off a tenant
    -- that exists: that is one customer being handed another's address.
    IF r.tenant_id IS NOT NULL
       AND r.tenant_id <> ''
       AND r.tenant_id IS DISTINCT FROM p_expected THEN
        RAISE EXCEPTION
            'route % already points at tenant %', p_host, r.tenant_id
            USING ERRCODE = 'check_violation';
    END IF;

    UPDATE control_plane.ctl_tenant_routes
       SET tenant_id  = p_tenant_id,
           udatetime  = now(),
           updated_by = COALESCE(p_updated_by, session_user)
     WHERE host = p_host
    RETURNING * INTO r;

    RETURN r;
END;
$$;

COMMENT ON FUNCTION control_plane.reconcile_route_tenant(text, text, text, text) IS
    'Point a silo route at the tenant now in it. SECURITY DEFINER so applications can '
    'do this without UPDATE on ctl_tenant_routes. Refuses pooled routes and routes '
    'already bound to a real tenant.';

-- EXECUTE is revoked from PUBLIC first: a new function is executable by everybody by
-- default, which for a definer-rights function is the whole attack surface.
REVOKE ALL ON FUNCTION control_plane.reconcile_route_tenant(text, text, text, text)
    FROM PUBLIC;

DO $$
DECLARE grp text;
BEGIN
    FOR grp IN
        SELECT rolname FROM pg_roles
         WHERE rolname ~ '^tvs_app_[a-z0-9_]+$' AND NOT rolcanlogin
    LOOP
        EXECUTE format(
            'GRANT EXECUTE ON FUNCTION control_plane.reconcile_route_tenant'
            '(text, text, text, text) TO %I', grp);
        RAISE NOTICE 'reconcile_route_tenant: execute granted to %', grp;
    END LOOP;
END $$;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE
    r       control_plane.ctl_tenant_routes;
    v_host  text := 'probe-reconcile.example.invalid';
    v_pool  text := 'probe-pooled.example.invalid';
BEGIN
    -- A silo route carries more than a host. ck_ctl_routes_silo_has_db wants a
    -- database, and ck_ctl_routes_silo_storage wants a SHARED silo to have a
    -- container_prefix and NO storage account of its own -- because a shared
    -- silo's containers live inside each app's account. The probe rows have to
    -- be real routes or they never reach the function being tested.
    -- WHY THIS IS WRITTEN TWICE
    --
    -- route_kind is added by 20261003-07, which is LATER than this file. On a fresh
    -- database this runs first and the column does not exist, so naming it fails. On
    -- every later deploy -- migrations re-run -- the column and its check ARE there,
    -- and a SILO_SHARED probe row taking the default 'PLATFORM' is refused. Either
    -- single version of this statement breaks one of the two cases, and the one it
    -- breaks is a migration whose only job is to prove a function works.
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'control_plane'
           AND table_name   = 'ctl_tenant_routes'
           AND column_name  = 'route_kind'
    ) THEN
        INSERT INTO control_plane.ctl_tenant_routes
            (host, tenant_id, tier, cell_key, silo_key, status, is_wildcard,
             db_server_fqdn, db_name, container_prefix, route_kind)
        VALUES (v_host, 'tnt_probe', 'SILO_SHARED', 'uksouth-dev', 'probe', 'ACTIVE',
                false, 'probe.postgres.database.azure.com', 'probe-db', 'probe',
                'TENANT'),
               (v_pool, NULL, 'POOLED', 'uksouth-dev', NULL, 'ACTIVE', false,
                NULL, NULL, NULL, 'PLATFORM');
    ELSE
        INSERT INTO control_plane.ctl_tenant_routes
            (host, tenant_id, tier, cell_key, silo_key, status, is_wildcard,
             db_server_fqdn, db_name, container_prefix)
        VALUES (v_host, 'tnt_probe', 'SILO_SHARED', 'uksouth-dev', 'probe', 'ACTIVE',
                false, 'probe.postgres.database.azure.com', 'probe-db', 'probe'),
               (v_pool, NULL, 'POOLED', 'uksouth-dev', NULL, 'ACTIVE', false,
                NULL, NULL, NULL);
    END IF;

    -- The reconciliation it exists for.
    r := control_plane.reconcile_route_tenant(v_host, 'tnt_real_one', 'tnt_probe', 'checks');
    IF r.tenant_id <> 'tnt_real_one' THEN
        RAISE EXCEPTION 'the placeholder was not replaced';
    END IF;

    -- ...and the three things it must refuse.
    BEGIN
        PERFORM control_plane.reconcile_route_tenant(v_host, 'tnt_someone_else', 'tnt_probe', 'checks');
        RAISE EXCEPTION 'a route bound to a real tenant was repointed';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    BEGIN
        PERFORM control_plane.reconcile_route_tenant(v_pool, 'tnt_real_one', NULL, 'checks');
        RAISE EXCEPTION 'a POOLED route was pinned to one tenant';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    BEGIN
        PERFORM control_plane.reconcile_route_tenant('nothing.example.invalid', 'tnt_x', NULL, 'checks');
        RAISE EXCEPTION 'an unknown host was accepted';
    EXCEPTION WHEN no_data_found THEN NULL;
    END;

    DELETE FROM control_plane.ctl_tenant_routes WHERE host IN (v_host, v_pool);
    RAISE NOTICE 'reconcile_route_tenant behaves';
END $$;
