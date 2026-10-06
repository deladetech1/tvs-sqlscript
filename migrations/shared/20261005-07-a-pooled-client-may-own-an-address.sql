-- =====================================================================================
-- A pooled client may own an address.
--
-- 20261003-07 wrote the rule "a customer's address is never pooled, and a pooled address
-- never belongs to one customer". The first half is still right. The second half has to
-- go: every tenant is moving to its own subdomain -- itech.trovesuite.com for a pooled
-- client exactly as accesspoint.dev.trovesuite.com for a silo one -- so the address can
-- say which tenant without saying which database.
--
-- WHY THAT IS WORTH CHANGING A GUARD FOR
-- With the tenant named by the address, signing in never has to ASK which tenant, and so
-- never has to show a person the list of clients they work for. That list was the one
-- disclosure the alternative design could not close. It also makes a pooled client's
-- upgrade to a silo invisible to them: the address stays, only the route's tier and
-- database change underneath.
--
-- WHAT STILL HAS TO HOLD, AND WHY THE REPLACEMENT IS NOT WEAKER
-- The danger the old rule guarded against was never "pooled" -- it was pinning a SHARED
-- address to one client and taking every other client off the air. dev.trovesuite.com is
-- where the public signup runs.
--
-- So the discriminator moves from the TIER to the KIND, which is what route_kind was
-- introduced for:
--
--     PLATFORM  = ours. Shared, serves everybody, NEVER names a tenant.
--     TENANT    = one client's own address. Always names a tenant. Any tier.
--
-- That is strictly more protective in one direction: before, nothing stopped a POOLED
-- PLATFORM route being given a tenant_id. Now a PLATFORM route may not have one at all,
-- which is what actually keeps dev.trovesuite.com safe. Every existing row already
-- satisfies it -- all 22 platform routes are POOLED with no tenant.
-- =====================================================================================

ALTER TABLE control_plane.ctl_tenant_routes
    DROP CONSTRAINT IF EXISTS ck_ctl_routes_tenant_kind_not_pooled;

ALTER TABLE control_plane.ctl_tenant_routes
    DROP CONSTRAINT IF EXISTS ck_ctl_routes_kind_owns_tenant;

ALTER TABLE control_plane.ctl_tenant_routes
    ADD CONSTRAINT ck_ctl_routes_kind_owns_tenant CHECK (
        (route_kind = 'PLATFORM' AND tenant_id IS NULL AND tier = 'POOLED')
        OR
        (route_kind = 'TENANT' AND tenant_id IS NOT NULL)
    );

COMMENT ON COLUMN control_plane.ctl_tenant_routes.route_kind IS
    'PLATFORM = one of ours: shared, serves every tenant, and may never name one -- that '
    'is what stops the signup host being pinned to a single client. TENANT = one '
    'client''s own address, which always names its tenant and may now be POOLED as well '
    'as silo.';

-- reconcile_route_tenant refused anything POOLED, for the same reason the old constraint
-- did. Re-keyed onto route_kind so a pooled client's own address can be pointed at its
-- tenant, while a PLATFORM route still cannot be pointed at anybody.
CREATE OR REPLACE FUNCTION control_plane.reconcile_route_tenant(
    p_host text, p_tenant_id text, p_expected text, p_updated_by text DEFAULT NULL)
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

-- --------------------------------------------------------- the first pooled address
-- BGCLT, the one pooled client that exists. Looked up by name rather than written as an
-- id, so this does nothing in a database that has no such tenant -- which is every silo,
-- and every environment where BGCLT is a different row.
--
-- bgclt.trovesuite.com already exists as a PLATFORM route and is deliberately left
-- alone: that is the production address, and this database's BGCLT is the dev one.
INSERT INTO control_plane.ctl_tenant_routes
    (host, tenant_id, tier, cell_key, status, is_wildcard, route_kind, created_by)
SELECT 'bgclt.dev.trovesuite.com', t.id, 'POOLED', r.cell_key, 'ACTIVE', false, 'TENANT',
       'migration:20261005-07'
  FROM core_platform.cp_tenants t
  CROSS JOIN LATERAL (
      SELECT cell_key FROM control_plane.ctl_tenant_routes
       WHERE host = 'dev.trovesuite.com' LIMIT 1) r
 WHERE t.tenant_name = 'BGCLT'
   AND t.delete_status = 'NOT_DELETED'
   AND NOT EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                    WHERE host = 'bgclt.dev.trovesuite.com')
 LIMIT 1;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer; detail text;
BEGIN
    -- The protection that matters: no shared address names a client.
    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE route_kind = 'PLATFORM' AND tenant_id IS NOT NULL;
    IF n > 0 THEN
        RAISE EXCEPTION '% platform route(s) name a tenant, so a shared address has '
                        'been pinned to one client', n;
    END IF;

    -- A pooled client's own address is now allowed. Proved by DOING it, because the
    -- whole point of this migration is that the database used to refuse it.
    BEGIN
        INSERT INTO control_plane.ctl_tenant_routes
            (host, tenant_id, tier, cell_key, status, is_wildcard, route_kind)
        VALUES ('probe-pooled.dev.trovesuite.com', 'tnt_probe', 'POOLED', 'uksouth-dev',
                'ACTIVE', false, 'TENANT');
    EXCEPTION WHEN check_violation THEN
        RAISE EXCEPTION 'a pooled client still cannot own an address, which is what '
                        'this migration exists to allow';
    END;

    -- ...and a shared one still cannot be handed over.
    BEGIN
        INSERT INTO control_plane.ctl_tenant_routes
            (host, tenant_id, tier, cell_key, status, is_wildcard, route_kind)
        VALUES ('probe-shared.dev.trovesuite.com', 'tnt_probe', 'POOLED', 'uksouth-dev',
                'ACTIVE', false, 'PLATFORM');
        RAISE EXCEPTION 'a PLATFORM route accepted a tenant id, so the signup host can '
                        'be pinned to one client';
    EXCEPTION WHEN check_violation THEN
        NULL;  -- refused, as it must be
    END;

    DELETE FROM control_plane.ctl_tenant_routes
     WHERE host IN ('probe-pooled.dev.trovesuite.com', 'probe-shared.dev.trovesuite.com');

    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE host LIKE 'probe-%';
    IF n > 0 THEN
        RAISE EXCEPTION '% probe route(s) survived and would answer for a tenant that '
                        'does not exist', n;
    END IF;

    -- The shared signup host is untouched and still shared.
    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE host = 'dev.trovesuite.com' AND route_kind = 'PLATFORM' AND tenant_id IS NULL;
    IF n <> 1 THEN
        RAISE EXCEPTION 'dev.trovesuite.com is no longer a shared platform address';
    END IF;

    SELECT COALESCE(string_agg(host, ', '), '(none here)') INTO detail
      FROM control_plane.ctl_tenant_routes
     WHERE route_kind = 'TENANT' AND tier = 'POOLED';
    RAISE NOTICE 'a pooled client may own an address; pooled tenant addresses: %', detail;
END $$;
