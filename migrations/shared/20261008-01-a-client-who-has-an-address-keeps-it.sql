-- ---------------------------------------------------------------------------
-- A client who already has an address keeps it.
--
-- THE BUG
--
-- Signup claims a subdomain of the host the request arrived at. For a pooled
-- signup that is right: the request comes to trovesuite.com, and the tenant is
-- given kofi.trovesuite.com beneath it.
--
-- A silo client's signup does NOT arrive there. It has to arrive at their own
-- address -- that is what routes their tenant into their own database rather
-- than the pooled one -- so signup composed
--
--     obeng.kofi.trovesuite.com
--
-- a subdomain of the client's own address, which claim_tenant_host refuses
-- because the parent is not one of OUR platform addresses. The refusal is
-- raised inside signup's transaction, so the tenant and the owner's account
-- roll back and the client is never set up. Confirmed by execution against
-- dev: resolving itech.dev.trovesuite.com and asking what signup would claim
-- yields exactly that host, and claiming it raises.
--
-- Nobody had hit it: the last silo was set up 2026-10-04 and the claim landed
-- 2026-10-06.
--
-- WHAT THIS FILE FIXES, and what it does not
--
-- The decision of WHICH path to take belongs in signup, because only there is
-- the resolved route known -- and it must come from the route rather than from
-- the caller, or any public signup could ask to skip the claim and create a
-- tenant with no address at all. That change is in lp_service.py.
--
-- Two things in the database have to be true first:
--
--   1. tenant_host_refusal must stop disagreeing with claim_tenant_host. Its
--      own comment says it "applies the same three rules so the two cannot
--      disagree" -- but the claim has a FOURTH rule, that the parent is an
--      active PLATFORM address, and the pre-check never mirrored it. So the
--      form said the name was fine, the OTP email went out, and only then did
--      the claim refuse. A check that disagrees with the thing it predicts
--      sends somebody round a loop they cannot get out of.
--
--   2. reconcile_route_tenant must be idempotent. Signup will now bind the
--      route itself, and the console pins it again after signup returns -- it
--      has always done that, and it passes the PLACEHOLDER as the expected
--      tenant. Once signup has bound the real one, that second call would
--      raise 'route already points at tenant X' and fail a setup that had in
--      fact just succeeded.
-- ---------------------------------------------------------------------------

-- --------------------------------------------- 1. the pre-check tells the truth
CREATE OR REPLACE FUNCTION control_plane.tenant_host_refusal(
    p_label text, p_parent_host text)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'control_plane', 'pg_catalog'
AS $function$
DECLARE
    v_label text := lower(btrim(coalesce(p_label, '')));
    v_word  text;
    v_host  text;
BEGIN
    IF v_label = '' THEN
        RETURN 'A web address is required.';
    END IF;
    IF v_label !~ '^[a-z0-9]([a-z0-9-]{0,38}[a-z0-9])?$' THEN
        RETURN 'A web address may use only letters, numbers and hyphens, must start '
               'and end with a letter or number, and may be at most 40 characters.';
    END IF;

    v_word := control_plane.reserved_label(v_label);
    IF v_word IS NOT NULL THEN
        RETURN format('"%s" is a name the platform uses, so it cannot be part of your '
                      'web address. Please choose another.', v_word);
    END IF;

    -- THE FOURTH RULE, which this function was missing. Same predicate as the
    -- claim: host, route_kind = 'PLATFORM', status = 'ACTIVE'. Worded for the
    -- operator rather than the client, because a client can never cause it --
    -- their signup arrives at whichever host we published. It happens when
    -- something asks for a subdomain of an address that is not ours to give
    -- out, which is a wiring mistake, not a bad name.
    IF NOT EXISTS (
        SELECT 1 FROM control_plane.ctl_tenant_routes
         WHERE host = lower(btrim(coalesce(p_parent_host, '')))
           AND route_kind = 'PLATFORM'
           AND status = 'ACTIVE')
    THEN
        RETURN format('%s is not one of our active platform addresses, so nothing '
                      'can be given a subdomain of it.', p_parent_host);
    END IF;

    v_host := v_label || '.' || lower(btrim(coalesce(p_parent_host, '')));
    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes WHERE host = v_host) THEN
        RETURN 'That web address is already taken. Please choose another.';
    END IF;

    RETURN NULL;
END
$function$;

COMMENT ON FUNCTION control_plane.tenant_host_refusal(text, text) IS
    'Why a label may not be used, or NULL when it may. Read-only, for the signup form. '
    'Applies the same FOUR rules as claim_tenant_host -- shape, reserved word, an '
    'active PLATFORM parent, and uniqueness -- so the two cannot disagree. The parent '
    'rule was missing until 20261008-01, which let an OTP go out before the refusal.';

-- ------------------------------------- 2. binding the same tenant twice is fine
--
-- Replaced in full rather than patched, because CREATE OR REPLACE FUNCTION
-- takes the whole body. Everything here is as it was -- the route must exist,
-- it must be a TENANT address (the KIND, not the tier, so it has always been
-- right for SILO_BYOD), and it may only move from the placeholder to a real
-- tenant, never off a tenant that exists -- with one case added.
CREATE OR REPLACE FUNCTION control_plane.reconcile_route_tenant(
    p_host       text,
    p_tenant_id  text,
    p_expected   text,
    p_updated_by text DEFAULT NULL)
RETURNS control_plane.ctl_tenant_routes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'control_plane', 'pg_catalog'
AS $function$
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

    -- THE KIND, not the tier. A PLATFORM route is shared by every tenant -- the signup
    -- host, the API, a product's marketing address -- and handing one to a client takes
    -- everybody else off the air.
    IF r.route_kind <> 'TENANT' THEN
        RAISE EXCEPTION
            'route % is a % address, which is shared by every tenant and cannot be '
            'assigned to one client', p_host, r.route_kind
            USING ERRCODE = 'check_violation';
    END IF;

    -- ALREADY DONE IS NOT AN ERROR. Signup binds the route itself now, and the
    -- console pins it again when signup returns, passing the PLACEHOLDER as the
    -- expected tenant -- so without this the second call would read the real
    -- tenant, find it is not the placeholder, and fail a setup that had just
    -- succeeded. Returning the row unchanged is also the honest answer to
    -- "make this route point at this tenant": it already does.
    --
    -- This does not widen anything. The refusal below still fires for any OTHER
    -- tenant, which is the case it exists for: one customer being handed
    -- another's address.
    IF r.tenant_id = p_tenant_id THEN
        RETURN r;
    END IF;

    -- Only from the placeholder (or nothing) to a real tenant. Never off a tenant that
    -- exists: that is one customer being handed another's address.
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
END
$function$;

COMMENT ON FUNCTION control_plane.reconcile_route_tenant(text, text, text, text) IS
    'Point a silo route at the tenant now in it. SECURITY DEFINER so applications can '
    'do this without UPDATE on ctl_tenant_routes. Refuses PLATFORM routes and routes '
    'already bound to a DIFFERENT tenant; binding the same tenant again is a no-op, '
    'because signup and the console both do it.';

-- Replacing a function does not change its privileges, so the grants made when
-- it was created still stand. Re-asserted anyway: a REPLACE that silently lost
-- EXECUTE would break every silo setup, and the cost of being sure is one
-- statement.
REVOKE ALL ON FUNCTION control_plane.reconcile_route_tenant(text, text, text, text)
    FROM PUBLIC;
DO $$
DECLARE grp text;
BEGIN
    FOR grp IN
        SELECT rolname FROM pg_roles WHERE rolname LIKE 'tvs_app_%'
    LOOP
        EXECUTE format(
            'GRANT EXECUTE ON FUNCTION control_plane.reconcile_route_tenant('
            'text, text, text, text) TO %I', grp);
        EXECUTE format(
            'GRANT EXECUTE ON FUNCTION control_plane.tenant_host_refusal(text, text) '
            'TO %I', grp);
    END LOOP;
END $$;
