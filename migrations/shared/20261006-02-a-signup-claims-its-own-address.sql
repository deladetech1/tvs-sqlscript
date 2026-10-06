-- =====================================================================================
-- A signup claims its own address.
--
-- Every tenant is reached at an address of its own, and until now only a migration or a
-- silo build ever created one -- bgclt.dev.trovesuite.com was written by hand. Pooled
-- signup created a tenant with no address at all.
--
-- That has become load-bearing rather than cosmetic. An email is unique per TENANT now
-- (20261005-09), so one person can hold accounts with several clients; sign-in resolves
-- which one from the address, and on the shared signup host it cannot, so it refuses.
-- A tenant with no address of its own is therefore a tenant whose users can be locked
-- out the moment any of them has a second account. Signup has to hand out the address.
--
-- WHY A FUNCTION AND NOT A GRANT
-- Application roles hold SELECT on ctl_tenant_routes and nothing else, deliberately: a
-- route row is what makes a host resolve to a database, so INSERT on that table lets any
-- app point any customer's address at any tenant. The same reasoning as
-- reconcile_route_tenant, which is why this is shaped like it -- SECURITY DEFINER, doing
-- one narrow thing, with every rule checked inside.
--
-- WHAT THE CALLER MAY NOT DECIDE
-- It passes a LABEL and a PARENT, never a whole host. The parent must already be an
-- ACTIVE PLATFORM route, and the host is composed here as label || '.' || parent. So a
-- client can only ever be given a subdomain of an address we already own; an app that
-- passed 'evil.example.com' gets a refusal rather than a route. Deriving the tier and
-- cell_key from that parent, rather than accepting them, closes the same door: a new
-- tenant lands in the cell its signup host belongs to and nowhere else.
--
-- THREE REFUSALS THE CALLER CAN ACT ON, each with its own SQLSTATE so signup can turn
-- them into different sentences:
--   invalid_parameter_value  the label is not a usable DNS label
--   check_violation          the label is reserved (20261005-08)
--   unique_violation         somebody already has that address
-- A caller that cannot tell them apart would say "that name is taken" to a client who
-- typed "api", which is both wrong and impossible to act on.
-- =====================================================================================

-- ---------------------------------------------------------------- ask before claiming
-- Read-only, so signup can refuse on the form before it has written anything. Returns
-- NULL when the label is free, or a sentence for the person. The same three rules as the
-- claim, which is the point -- a check that could disagree with the thing it predicts
-- would send somebody round a loop they cannot get out of.
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
    -- A DNS label: letters, digits and inner hyphens. Length capped well under the 63
    -- the protocol allows, because the whole host has to fit too.
    IF v_label !~ '^[a-z0-9]([a-z0-9-]{0,38}[a-z0-9])?$' THEN
        RETURN 'A web address may use only letters, numbers and hyphens, must start '
               'and end with a letter or number, and may be at most 40 characters.';
    END IF;

    v_word := control_plane.reserved_label(v_label);
    IF v_word IS NOT NULL THEN
        RETURN format('"%s" is a name the platform uses, so it cannot be part of your '
                      'web address. Please choose another.', v_word);
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
    'Applies the same three rules as claim_tenant_host so the two cannot disagree.';

-- ------------------------------------------------------------------------- the claim
CREATE OR REPLACE FUNCTION control_plane.claim_tenant_host(
    p_label       text,
    p_parent_host text,
    p_tenant_id   text,
    p_created_by  text DEFAULT NULL)
RETURNS control_plane.ctl_tenant_routes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'control_plane', 'pg_catalog'
AS $function$
DECLARE
    v_label  text := lower(btrim(coalesce(p_label, '')));
    v_parent control_plane.ctl_tenant_routes;
    v_host   text;
    v_word   text;
    r        control_plane.ctl_tenant_routes;
BEGIN
    IF p_tenant_id IS NULL OR btrim(p_tenant_id) = '' THEN
        RAISE EXCEPTION 'a tenant id is required';
    END IF;

    IF v_label !~ '^[a-z0-9]([a-z0-9-]{0,38}[a-z0-9])?$' THEN
        RAISE EXCEPTION 'label % is not a usable web address', p_label
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    -- THE PARENT MUST BE OURS. This is what stops a caller inventing a host: the only
    -- addresses on offer are subdomains of one we already serve.
    SELECT * INTO v_parent FROM control_plane.ctl_tenant_routes
     WHERE host = lower(btrim(coalesce(p_parent_host, '')))
       AND route_kind = 'PLATFORM'
       AND status = 'ACTIVE';
    IF NOT FOUND THEN
        RAISE EXCEPTION
            '% is not one of our active platform addresses, so nothing can be given a '
            'subdomain of it', p_parent_host
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_word := control_plane.reserved_label(v_label);
    IF v_word IS NOT NULL THEN
        RAISE EXCEPTION 'label % contains the reserved word %', v_label, v_word
            USING ERRCODE = 'check_violation';
    END IF;

    v_host := v_label || '.' || v_parent.host;

    -- The tier and the cell come from the parent, never from the caller. A pooled
    -- signup host yields a POOLED route in that host's cell; a silo is not created
    -- this way at all.
    INSERT INTO control_plane.ctl_tenant_routes
        (host, tenant_id, tier, cell_key, status, is_wildcard, route_kind, created_by)
    VALUES (v_host, p_tenant_id, v_parent.tier, v_parent.cell_key, 'ACTIVE', false,
            'TENANT', COALESCE(p_created_by, session_user))
    RETURNING * INTO r;
    -- A duplicate host raises unique_violation from the primary key, which the caller
    -- distinguishes from the two above. Not caught here: swallowing it would let two
    -- tenants believe they hold one address.

    RETURN r;
END
$function$;

COMMENT ON FUNCTION control_plane.claim_tenant_host(text, text, text, text) IS
    'Give a new tenant a subdomain of one of our platform addresses. Takes a LABEL and a '
    'PARENT, never a whole host, and derives tier and cell_key from that parent -- so an '
    'application cannot invent an address or place a tenant in another cell. Raises '
    'invalid_parameter_value, check_violation (reserved) or unique_violation (taken).';

-- ------------------------------------------------------------------------- the grant
DO $$
DECLARE grp text; n integer := 0;
BEGIN
    -- The pooled app group only, and not every tvs_app_% -- the same narrow shape as
    -- 20261003-04 and 20261005-05, for the same reason: this hands out addresses, and a
    -- retired tenant's group must not keep the privilege.
    FOR grp IN
        SELECT rolname FROM pg_roles
         WHERE rolname ~ '^tvs_app_[a-z0-9]+$' AND NOT rolcanlogin
    LOOP
        EXECUTE format('GRANT EXECUTE ON FUNCTION control_plane.claim_tenant_host('
                       'text, text, text, text) TO %I', grp);
        EXECUTE format('GRANT EXECUTE ON FUNCTION control_plane.tenant_host_refusal('
                       'text, text) TO %I', grp);
        n := n + 1;
    END LOOP;
    RAISE NOTICE 'a signup may claim an address: granted to % app group(s)', n;
END $$;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer; got text; r control_plane.ctl_tenant_routes; parent text;
BEGIN
    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE route_kind = 'PLATFORM' AND status = 'ACTIVE';
    IF n = 0 THEN
        RAISE NOTICE 'no active platform route here, so the claim cannot be exercised';
        RETURN;
    END IF;
    SELECT host INTO parent FROM control_plane.ctl_tenant_routes
     WHERE route_kind = 'PLATFORM' AND status = 'ACTIVE'
       AND host LIKE '%trovesuite.com' ORDER BY length(host) LIMIT 1;

    -- The read-only predictor and the claim must agree. Checked together, because the
    -- failure mode of disagreement is a form that says "available" and then refuses.
    got := control_plane.tenant_host_refusal('api', parent);
    IF got IS NULL THEN
        RAISE EXCEPTION 'the form would offer "api" to a client';
    END IF;
    BEGIN
        r := control_plane.claim_tenant_host('api', parent, 'tnt_probe_claim');
        RAISE EXCEPTION 'the claim handed over "api"';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    got := control_plane.tenant_host_refusal('Not A Label!', parent);
    IF got IS NULL THEN
        RAISE EXCEPTION 'the form accepted a string that is not a DNS label';
    END IF;
    BEGIN
        r := control_plane.claim_tenant_host('Not A Label!', parent, 'tnt_probe_claim');
        RAISE EXCEPTION 'the claim accepted a string that is not a DNS label';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- A caller may not invent a parent.
    BEGIN
        r := control_plane.claim_tenant_host('acme', 'evil.example.com',
                                             'tnt_probe_claim');
        RAISE EXCEPTION 'a tenant was given a subdomain of a host we do not serve';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- ...and an ordinary name works, lands under the parent, and is a TENANT route in
    -- the parent's own cell.
    got := control_plane.tenant_host_refusal('probeclaimco', parent);
    IF got IS NOT NULL THEN
        RAISE EXCEPTION 'an ordinary name was refused: %', got;
    END IF;
    r := control_plane.claim_tenant_host('probeclaimco', parent, 'tnt_probe_claim',
                                         'migration:20261006-02');
    IF r.host <> 'probeclaimco.' || parent THEN
        RAISE EXCEPTION 'the claimed host is %, not the label under the parent', r.host;
    END IF;
    IF r.route_kind <> 'TENANT' OR r.tenant_id <> 'tnt_probe_claim' THEN
        RAISE EXCEPTION 'the claimed route is % for %', r.route_kind, r.tenant_id;
    END IF;
    IF r.cell_key IS DISTINCT FROM (SELECT cell_key FROM control_plane.ctl_tenant_routes
                                     WHERE host = parent) THEN
        RAISE EXCEPTION 'the claimed route landed in cell %, not its parent''s',
            r.cell_key;
    END IF;

    -- Claiming it twice is refused, and distinguishably so.
    got := control_plane.tenant_host_refusal('probeclaimco', parent);
    IF got IS NULL THEN
        RAISE EXCEPTION 'the form still offers an address that is now taken';
    END IF;
    BEGIN
        r := control_plane.claim_tenant_host('probeclaimco', parent, 'tnt_probe_other');
        RAISE EXCEPTION 'two tenants were given one address';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;

    DELETE FROM control_plane.ctl_tenant_routes WHERE tenant_id LIKE 'tnt_probe_%';
    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE tenant_id LIKE 'tnt_probe_%';
    IF n > 0 THEN
        RAISE EXCEPTION '% probe route(s) survived and would answer for a tenant that '
                        'does not exist', n;
    END IF;

    RAISE NOTICE 'a signup claims its own address: parent %, % platform parent(s) '
                 'available', parent, (SELECT count(*) FROM control_plane.ctl_tenant_routes
                                        WHERE route_kind = 'PLATFORM' AND status = 'ACTIVE');
END $$;
