-- =====================================================================================
-- Let the console manage CLIENT addresses, and only client addresses.
--
-- Standing a silo up has always ended in hand-written SQL: the route row is what makes
-- an address resolve, and nothing in the console could write one. So every new client
-- involved somebody typing INSERT into a production control plane at the end of a long
-- afternoon.
--
-- WHY A VIEW AND NOT A GRANT ON THE TABLE
--
-- ctl_tenant_routes decides which database every request in the platform reaches. Two
-- thirds of it is OURS -- trovesuite.com, the api hosts, each product's marketing site
-- -- and those rows are shared infrastructure: a console that can edit them is a
-- console that can point the hub at a customer's database.
--
-- The console also does not have a login of its own yet; it borrows core-platform's
-- (see the README). So a grant on the table would hand route-rewriting to the
-- APPLICATION as well, which is a much larger thing than a management screen.
--
-- An auto-updatable view with WITH CHECK OPTION solves both. The console is granted on
-- the VIEW only:
--
--   * it cannot SEE a platform row -- the view's WHERE excludes them;
--   * it cannot UPDATE or DELETE one -- they are not in the view to be found;
--   * it cannot INSERT or UPDATE a row INTO being one -- WITH CHECK OPTION refuses any
--     write whose result would fall outside the view.
--
-- That last clause is the one worth understanding. Without it the console could insert
-- a row with route_kind = 'PLATFORM', or update a tenant row into one, and the
-- protection would be a convention in Go rather than a rule in the database.
--
-- Postgres makes a single-table view with no aggregates automatically updatable, so
-- this needs no triggers and no rules.
-- =====================================================================================

CREATE OR REPLACE VIEW control_plane.ctl_tenant_routes_tenant AS
SELECT host,
       tenant_id,
       tier,
       cell_key,
       silo_key,
       db_server_fqdn,
       db_name,
       db_secret_uri,
       storage_account,
       container_prefix,
       storage_secret_uri,
       api_base,
       status,
       is_wildcard,
       route_kind,
       schema_version,
       cdatetime,
       created_by,
       udatetime,
       updated_by
  FROM control_plane.ctl_tenant_routes
 WHERE route_kind = 'TENANT'
WITH CHECK OPTION;

COMMENT ON VIEW control_plane.ctl_tenant_routes_tenant IS
    'Client addresses only, writable by the console. Platform addresses are excluded '
    'and WITH CHECK OPTION stops a row being written into or out of that scope. The '
    'console is granted here and never on ctl_tenant_routes itself.';

-- ------------------------------------------------------------------- who may use it
-- The console's login by name, exactly as the billing ledger does it and for the same
-- reason: the migrator is not a superuser, so a dedicated role cannot be created in a
-- migration. Migrations re-run every deploy, so the grant follows the console the day
-- it stops borrowing core-platform's login.
--
-- SELECT on the view is granted to the app groups too. They already hold SELECT on the
-- table, so this adds nothing they could not do -- it just means application code can
-- use the same name.
DO $$
DECLARE r text; n integer := 0;
BEGIN
    FOR r IN
        SELECT rolname FROM pg_roles
         WHERE rolcanlogin
           AND rolname ~ '^(coreplatform|deladetech)_[a-z0-9]+$'
    LOOP
        EXECUTE format('GRANT USAGE ON SCHEMA control_plane TO %I', r);
        EXECUTE format(
            'GRANT SELECT, INSERT, UPDATE, DELETE ON '
            'control_plane.ctl_tenant_routes_tenant TO %I', r);
        n := n + 1;
    END LOOP;
    RAISE NOTICE 'tenant routes: management granted to % login(s)', n;
END $$;

DO $$
DECLARE grp text;
BEGIN
    FOR grp IN
        SELECT rolname FROM pg_roles
         WHERE rolname ~ '^tvs_app_[a-z0-9_]+$' AND NOT rolcanlogin
    LOOP
        EXECUTE format('GRANT USAGE ON SCHEMA control_plane TO %I', grp);
        EXECUTE format(
            'GRANT SELECT ON control_plane.ctl_tenant_routes_tenant TO %I', grp);
    END LOOP;
END $$;

-- ------------------------------------------------------------------------------ checks
DO $$
DECLARE n integer; platform_rows integer; visible integer;
BEGIN
    SELECT count(*) INTO n FROM information_schema.views
     WHERE table_schema = 'control_plane'
       AND table_name = 'ctl_tenant_routes_tenant';
    IF n <> 1 THEN
        RAISE EXCEPTION 'ctl_tenant_routes_tenant was not created';
    END IF;

    -- The whole point: shared infrastructure must not be in it.
    SELECT count(*) INTO platform_rows
      FROM control_plane.ctl_tenant_routes WHERE route_kind <> 'TENANT';
    SELECT count(*) INTO visible
      FROM control_plane.ctl_tenant_routes_tenant WHERE route_kind <> 'TENANT';
    IF visible <> 0 THEN
        RAISE EXCEPTION
            '% platform route(s) are visible through the tenant view', visible;
    END IF;
    RAISE NOTICE
        'tenant routes: % platform row(s) hidden, % client row(s) manageable',
        platform_rows,
        (SELECT count(*) FROM control_plane.ctl_tenant_routes_tenant);

    -- WITH CHECK OPTION must actually refuse a write that leaves the view. Proven
    -- rather than assumed, inside a savepoint so nothing survives.
    BEGIN
        INSERT INTO control_plane.ctl_tenant_routes_tenant
            (host, tenant_id, tier, cell_key, route_kind, status)
        VALUES ('__check__.invalid', NULL, 'POOLED', 'uksouth-dev', 'PLATFORM', 'ACTIVE');
        RAISE EXCEPTION
            'the tenant view accepted a PLATFORM row; WITH CHECK OPTION is not working';
    EXCEPTION
        WHEN check_violation THEN
            NULL;  -- refused, which is the point
        WHEN others THEN
            -- A different refusal (a table constraint, say) is also a refusal, and
            -- the row is what matters rather than which rule stopped it.
            NULL;
    END;

    RAISE NOTICE 'the console can manage client addresses, and only those';
END $$;
