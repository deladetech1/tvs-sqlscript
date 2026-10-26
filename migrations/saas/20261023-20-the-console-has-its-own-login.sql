-- =====================================================================================
-- The Deladetech console gets its own database login, and exactly what it uses.
--
-- WHY
--
-- The console ran on core-platform's login (db-url-coreplatform), and its own tables
-- -- staff accounts (dlt_operators: password hashes and roles), their sessions
-- (dlt_operator_sessions: sha256 of the cookie) and the setup / clear records -- were
-- granted to the POOLED APP GROUP tvs_app_<env> (20261003-04, -06, 20261005-05).
-- Every application login is a member of that group: mystoreguard_<env>,
-- loandrift_<env>, the CRM's, every one. So any app's database credential (a leaked
-- secret, or SQL injection in any app) could insert a session row with a token it
-- chose, or set an operator's role to OWNER, and be a console OWNER: lock, clear and
-- re-price every client. CONSOLE-GAPS.md gap 1.
--
-- The fix is in three steps, in this order, so nothing breaks in between:
--
--   1. tvs-iac creates the login deladetech_<env> (applications/deladetech/db/role)
--      and its Key Vault secret. A migration cannot: the migrator has no CREATEROLE
--      (see sqlscript-migrator-not-superuser).
--   2. THIS FILE grants that login what the console uses -- and nothing to the app
--      group. Until the login exists it grants nothing and says so, so it is safe to
--      land before step 1 is applied. Migrations re-run every deploy, so the grants
--      arrive on the first deploy after the login exists, without a new file.
--   3. The console is switched to the new secret, and only THEN is the app group's
--      access to the console tables revoked (a later file, held until step 3).
--
-- WHAT THE CONSOLE TOUCHES (inventory from deladetech/backend: sql/queries/*.sql and
-- the hand-written SQL in internal/api/*.go, 2026-10-23)
--
--   deladetech     dlt_operators            S I U     sign-in, operators screen
--                  dlt_operator_sessions    S I U D   sessions (D: expired + sign-out)
--                  dlt_client_setups        S I U D   setups (D: a clear frees the host)
--                  dlt_client_clears        S I U     the clear's audit -- never D
--                  dlt_hosting_requests     S U       requests screen (core-platform
--                                                     inserts them; the console reads
--                                                     and changes their status)
--   control_plane  ctl_tenant_routes, ctl_cells, ctl_reserved_labels,
--                  ctl_platform_domains     S         hosting screens, address checks
--                  (+ S on whatever else in control_plane the pooled group reads: the
--                  route triggers read it as the console when it writes an address)
--                  ctl_tenant_routes_tenant S I U D   client addresses (granted by
--                                                     shared/20261007-05 already)
--                  ledger views, ctl_silo_*, ctl_storage_credentials
--                                           S (+I U on ctl_silo_charges): granted by
--                                           20261004-01/-03/-09/-12, 20261007-03 to
--                                           ^(coreplatform|deladetech)_ already
--                  route functions          EXECUTE (reconcile_route_tenant,
--                                           tenant_host_refusal, release_tenant_host,
--                                           label_for_name, move_tenant_host)
--   core_platform  cp_tenants               S U       lock / unlock (purge: below)
--                  cp_user_sessions         S U       a lock revokes open sessions
--                  cp_app_subscriptions     S U       agreed price / rate
--                  cp_app_tier_configs      S U       the price list
--                  cp_platform_charges      S I U     charges
--                  cp_bundle_subscriptions, cp_bundle_tier_configs   S U   (bundles)
--                  cp_price_list_changes    S I       price history (20261023-30)
--                  cp_app_tier_meter_prices S I U     HMS meter prices (20261026-11)
--                  cp_apps (volume_threshold, volume_discount)  U   the volume rule
--                  cp_apps, cp_subscriptions, cp_businesses, cp_business_apps,
--                  cp_business_app_locations, cp_users, cp_currencies,
--                  cp_billings_logs, cp_bundles, cp_bundle_apps      S
--
-- THE CLEAR
--
-- Clearing a POOLED client deletes every row with its tenant_id in every schema. That
-- is DELETE on every tenant table of every app -- and the DELETE triggers on them
-- (accounting events, stock invariants, shared parties) write to yet more tables as
-- whoever runs the statement. Granting the console all of that would be the app
-- group's privileges by another name. Instead control_plane.purge_tenant() below does
-- the purge as its owner (the migrator, who owns the tables), and only the console's
-- login may EXECUTE it. The console can purge one tenant, refused for the platform's
-- own; it cannot DELETE anything else. A silo client is still cleared through the
-- silo's own login (db-url-coreplatform-<silo>), unchanged.
--
-- Pooled only: the console's tables exist only in the pool (migrations/saas/), and the
-- logins are found with control_plane.app_logins_here('deladetech') -- this database's
-- deladetech_<env>, never a pattern over the cluster (silo-cross-tenant-pattern-grants).
--
-- Idempotent; safe on every deploy, before and after the login exists.
-- =====================================================================================

-- ------------------------------------------------------------- the purge, as a function
CREATE OR REPLACE FUNCTION control_plane.purge_tenant(p_tenant_id text)
RETURNS TABLE (purged_name text, purged_rows bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'control_plane', 'pg_catalog'
AS $fn$
DECLARE
    v_name     text;
    v_total    bigint := 0;
    v_n        bigint;
    v_pending  text[];
    v_blocked  text[];
    v_t        text;
    v_pass     integer := 0;
    v_progress boolean;
BEGIN
    -- The platform's own tenant is present in every database. Guarded on the id, not
    -- on is_system, which signup sets on every tenant.
    IF p_tenant_id IS NULL OR btrim(p_tenant_id) = '' OR p_tenant_id = 'system-tenant-id' THEN
        RAISE EXCEPTION 'refusing to purge tenant %', coalesce(p_tenant_id, '(null)')
            USING ERRCODE = '22023';
    END IF;

    SELECT coalesce(t.tenant_name, '') INTO v_name
      FROM core_platform.cp_tenants t WHERE t.id = p_tenant_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'no tenant % in this database', p_tenant_id USING ERRCODE = 'P0002';
    END IF;

    -- Every table with a tenant_id, from the catalogue -- not information_schema, which
    -- shows a role only the tables it holds a privilege on, so a missing grant would
    -- quietly leave that table's rows behind. The console's and the control plane's
    -- own schemas are never purged: the clear's audit, the routes.
    SELECT coalesce(array_agg(format('%I.%I', n.nspname, c.relname)
                              ORDER BY n.nspname, c.relname), '{}')
      INTO v_pending
      FROM pg_attribute a
      JOIN pg_class c     ON c.oid = a.attrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE a.attname = 'tenant_id' AND a.attnum > 0 AND NOT a.attisdropped
       AND c.relkind IN ('r', 'p')
       AND n.nspname NOT IN ('deladetech', 'control_plane', 'public',
                             'information_schema', 'pg_catalog', 'pg_toast')
       AND n.nspname !~ '^pg_'
       AND NOT (n.nspname = 'core_platform' AND c.relname = 'cp_tenants');

    -- Foreign keys between tenant tables decide the order, and nothing here knows it,
    -- so: delete what can be deleted, retry what a reference blocked, until a pass
    -- makes no progress. Each attempt is its own subtransaction (BEGIN ... EXCEPTION).
    -- Only a foreign-key refusal is retried; anything else aborts the whole purge.
    WHILE cardinality(v_pending) > 0 AND v_pass < 60 LOOP
        v_pass := v_pass + 1;
        v_blocked := '{}';
        v_progress := false;
        FOREACH v_t IN ARRAY v_pending LOOP
            BEGIN
                EXECUTE format('DELETE FROM %s WHERE tenant_id = $1', v_t) USING p_tenant_id;
                GET DIAGNOSTICS v_n = ROW_COUNT;
                v_total := v_total + v_n;
                v_progress := true;
            EXCEPTION WHEN foreign_key_violation OR restrict_violation THEN
                v_blocked := v_blocked || v_t;
            END;
        END LOOP;
        IF NOT v_progress THEN
            RAISE EXCEPTION 'could not delete tenant % from %: rows outside these tables '
                            'still reference them', p_tenant_id, array_to_string(v_blocked, ', ')
                USING ERRCODE = '23503';
        END IF;
        v_pending := v_blocked;
    END LOOP;
    IF cardinality(v_pending) > 0 THEN
        RAISE EXCEPTION 'gave up with % table(s) still holding rows of tenant %',
            cardinality(v_pending), p_tenant_id USING ERRCODE = '23503';
    END IF;

    DELETE FROM core_platform.cp_tenants WHERE id = p_tenant_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_total := v_total + v_n;

    -- Deferred constraint triggers (the accounting events, the stock invariant) would
    -- otherwise fire at COMMIT, after this function has returned -- as the CALLER, who
    -- holds none of those privileges. Fire them now, as the owner.
    SET CONSTRAINTS ALL IMMEDIATE;

    purged_name := v_name;
    purged_rows := v_total;
    RETURN NEXT;
END
$fn$;

COMMENT ON FUNCTION control_plane.purge_tenant(text) IS
    'Delete one tenant and every row carrying its tenant_id, as the owner. EXECUTE is '
    'granted to the Deladetech console login only (20261023-20); refuses the platform '
    'tenant. The console''s audit (deladetech) and the routes (control_plane) are kept.';

-- A new function is executable by PUBLIC. This one deletes customers.
REVOKE ALL ON FUNCTION control_plane.purge_tenant(text) FROM PUBLIC;

-- ------------------------------------------------------------------- the console login
DO $$
DECLARE
    v_unit   text := (control_plane.this_database_unit()).unit;
    r        text;
    n        integer := 0;
    obj      text;
    privs    text;
    -- table -> privileges. A table that does not exist in this database (an older
    -- one, before its migration) is skipped, not an error.
    tables   text[][] := ARRAY[
        ['deladetech.dlt_operators',                  'SELECT, INSERT, UPDATE'],
        ['deladetech.dlt_operator_sessions',          'SELECT, INSERT, UPDATE, DELETE'],
        ['deladetech.dlt_client_setups',              'SELECT, INSERT, UPDATE, DELETE'],
        ['deladetech.dlt_client_clears',              'SELECT, INSERT, UPDATE'],
        ['deladetech.dlt_hosting_requests',           'SELECT, UPDATE'],
        ['control_plane.ctl_tenant_routes',           'SELECT'],
        ['control_plane.ctl_cells',                   'SELECT'],
        ['control_plane.ctl_reserved_labels',         'SELECT'],
        ['control_plane.ctl_platform_domains',        'SELECT'],
        ['core_platform.cp_tenants',                  'SELECT, UPDATE'],
        ['core_platform.cp_user_sessions',            'SELECT, UPDATE'],
        ['core_platform.cp_app_subscriptions',        'SELECT, UPDATE'],
        ['core_platform.cp_app_tier_configs',         'SELECT, UPDATE'],
        ['core_platform.cp_platform_charges',         'SELECT, INSERT, UPDATE'],
        ['core_platform.cp_bundle_subscriptions',     'SELECT, UPDATE'],
        ['core_platform.cp_bundle_tier_configs',      'SELECT, UPDATE'],
        ['core_platform.cp_price_list_changes',       'SELECT, INSERT'],
        -- HMS meter prices and the volume rule (shared/20261026-11): the price list.
        ['core_platform.cp_app_tier_meter_prices',    'SELECT, INSERT, UPDATE'],
        ['core_platform.cp_apps',                     'SELECT, UPDATE (volume_threshold, volume_discount)'],
        ['core_platform.cp_subscriptions',            'SELECT'],
        ['core_platform.cp_businesses',               'SELECT'],
        ['core_platform.cp_business_apps',            'SELECT'],
        ['core_platform.cp_business_app_locations',   'SELECT'],
        ['core_platform.cp_users',                    'SELECT'],
        ['core_platform.cp_currencies',               'SELECT'],
        ['core_platform.cp_billings_logs',            'SELECT'],
        ['core_platform.cp_bundles',                  'SELECT'],
        ['core_platform.cp_bundle_apps',              'SELECT']
    ];
    funcs    text[] := ARRAY[
        'control_plane.reconcile_route_tenant(text, text, text, text)',
        'control_plane.tenant_host_refusal(text, text)',
        'control_plane.release_tenant_host(text, text, text)',
        'control_plane.label_for_name(text)',
        'control_plane.move_tenant_host(text, text, text, text)',
        'control_plane.purge_tenant(text)'
    ];
    i        integer;
BEGIN
    IF v_unit <> 'pooled' THEN
        RAISE NOTICE 'console login: % database, not the pool -- nothing to grant', v_unit;
        RETURN;
    END IF;

    FOR r IN SELECT control_plane.app_logins_here('deladetech') LOOP
        n := n + 1;
        EXECUTE format('GRANT USAGE ON SCHEMA deladetech, control_plane, core_platform TO %I', r);

        FOR i IN 1 .. array_length(tables, 1) LOOP
            obj := tables[i][1];
            privs := tables[i][2];
            IF to_regclass(obj) IS NOT NULL THEN
                EXECUTE format('GRANT %s ON %s TO %I', privs, obj, r);
            ELSE
                RAISE NOTICE 'console login: % does not exist here, skipped', obj;
            END IF;
        END LOOP;

        -- The rest of control_plane that every application may read (the route
        -- reference data: platform domains, reserved labels, cells...). Writing a client
        -- address through ctl_tenant_routes_tenant fires the route table's triggers AS
        -- THE CONSOLE, and they read these. Derived from what the pooled group may read,
        -- so a new reference table follows without editing this file -- and the ledger,
        -- which 20261004-01 revokes from the groups, is never picked up this way.
        FOR obj IN
            SELECT format('%I.%I', n.nspname, c.relname)
              FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE n.nspname = 'control_plane' AND c.relkind IN ('r', 'p', 'v', 'm')
               AND EXISTS (SELECT 1 FROM control_plane.app_groups_here(true) g
                            WHERE has_table_privilege(g, c.oid, 'SELECT'))
        LOOP
            EXECUTE format('GRANT SELECT ON %s TO %I', obj, r);
        END LOOP;

        FOREACH obj IN ARRAY funcs LOOP
            IF to_regprocedure(obj) IS NOT NULL THEN
                EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO %I', obj, r);
            ELSE
                RAISE NOTICE 'console login: function % does not exist here, skipped', obj;
            END IF;
        END LOOP;

        RAISE NOTICE 'console login %: granted', r;
    END LOOP;

    IF n = 0 THEN
        -- Expected until tvs-iac applies applications/deladetech/db/role. Not an error:
        -- this file is meant to land first.
        RAISE NOTICE 'console login: no deladetech_<env> login in this database yet; '
                     'nothing granted (the console still runs on core-platform''s)';
    END IF;
END $$;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE
    r text;
    g text;
BEGIN
    -- Nobody but the console's login may run the purge. PUBLIC was revoked above; an
    -- app group or app login holding it would be the hole this file closes, reopened.
    --
    -- Infrastructure is left out: superusers, roles that may create roles (the server
    -- admin, which also holds an ADMIN-only membership of every group it created), and
    -- anything that inherits the owner's own privileges (the admin is a member of the
    -- migrator). What is left and can run it is an application role, which is a hole.
    FOR g IN
        SELECT r.rolname FROM pg_roles r
         WHERE has_function_privilege(r.oid, 'control_plane.purge_tenant(text)', 'EXECUTE')
           AND NOT r.rolsuper AND NOT r.rolcreaterole
           AND r.rolname !~ '^deladetech_[a-z0-9]+$'
           AND r.rolname !~ '^(pg_|azure)'
           AND NOT pg_has_role(r.oid, current_user, 'USAGE')
           AND (r.rolname ~ '^tvs_app_' OR EXISTS (
                  SELECT 1 FROM pg_roles grp
                   WHERE grp.rolname ~ '^tvs_app_' AND NOT grp.rolcanlogin
                     AND pg_has_role(r.oid, grp.oid, 'USAGE')))
    LOOP
        RAISE EXCEPTION 'application role % may execute control_plane.purge_tenant', g;
    END LOOP;

    IF (control_plane.this_database_unit()).unit <> 'pooled' THEN
        RETURN;
    END IF;

    FOR r IN SELECT control_plane.app_logins_here('deladetech') LOOP
        -- The post-condition of this file's own grants: sign-in and the clear.
        IF NOT has_table_privilege(r, 'deladetech.dlt_operator_sessions', 'INSERT')
           OR NOT has_table_privilege(r, 'deladetech.dlt_operators', 'SELECT')
           OR NOT has_function_privilege(r, 'control_plane.purge_tenant(text)', 'EXECUTE') THEN
            RAISE EXCEPTION 'console login % is missing its grants', r;
        END IF;
        -- ...and never more than that on the audit trail.
        IF has_table_privilege(r, 'deladetech.dlt_client_clears', 'DELETE')
           OR has_table_privilege(r, 'deladetech.dlt_operators', 'DELETE') THEN
            RAISE EXCEPTION 'console login % may DELETE the clear audit or an operator', r;
        END IF;
        -- Least privilege: the console is not an application. In the app group it would
        -- inherit DML on every app's schema, which it does not use.
        IF EXISTS (SELECT 1 FROM pg_roles grp
                    WHERE grp.rolname ~ '^tvs_app_' AND NOT grp.rolcanlogin
                      AND pg_has_role(r, grp.oid, 'MEMBER')) THEN
            RAISE WARNING 'console login % is a member of an app group; it needs none', r;
        END IF;
    END LOOP;

    RAISE NOTICE 'console login: checks passed';
END $$;
