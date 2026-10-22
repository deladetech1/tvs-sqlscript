-- =====================================================================================
-- A reserved name is ours only on OUR domains.
--
-- 20261005-08 refuses a TENANT route whose first label contains a platform word (api,
-- msg, cp, mystoreguard, ...). The point was never the word itself: it was that a
-- client's subdomain is built inside OUR namespace -- "API Solutions" would have been
-- handed api.trovesuite.com, and with it every app's API. That risk only exists under a
-- domain we own.
--
-- On a client's own domain it is the client's namespace, and they may call their hosts
-- whatever they like. BGCLT, moving from ENTERPRISE (self-hosted) to SILO_BYOD, serves
-- its MyStoreGuard frontend at mystoreguard.frontend.bgclt.com and msg.app.frontend
-- .bgclt.com, and its APIs at cp.prod.backend.bgclt.com and msg.prod.backend.bgclt.com.
-- The browsers send those as Origin, and the tenancy gate resolves the Origin
-- (tenancy-gate-resolves-the-origin), so each must be a TENANT route naming BGCLT --
-- and the trigger refused all four. The only rows the trigger allowed were PLATFORM,
-- which the constraints force to POOLED: BGCLT's users would have been served out of
-- the shared database.
--
-- So the check now applies to a host only when it is one of our domains or a subdomain
-- of one. The list is a TABLE, not a literal in the function, for the same reason the
-- words are: every writer of a route goes through the database, and a list kept anywhere
-- else is a list somebody forgets.
--
-- Everything else is unchanged: same words, same whole-token match, TENANT routes only,
-- INSERT and rename. control_plane.reserved_label() and host_label() keep their meaning
-- (signup builds labels under our own parents, so they are always on our domains).
--
-- 20261005-08 re-runs on every deploy and CREATE OR REPLACEs the trigger function with
-- its old body; this file sorts after it and replaces it again, so this body is the one
-- in force once a deploy finishes (later migration wins).
--
-- Idempotent; safe to re-run.
-- =====================================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS control_plane.ctl_platform_domains (
    domain     text        NOT NULL,
    reason     text        NOT NULL,
    cdatetime  timestamptz NOT NULL DEFAULT now(),
    created_by text,
    CONSTRAINT pk_ctl_platform_domains PRIMARY KEY (domain),
    -- Lowercase, no leading/trailing dot, no scheme: compared to a normalised host.
    CONSTRAINT ck_ctl_platform_domains_shape CHECK (domain ~ '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$')
);

COMMENT ON TABLE control_plane.ctl_platform_domains IS
    'Domains the platform owns. A client''s address under one of these is built in our '
    'namespace, so ctl_reserved_labels applies to it; on any other domain (a client''s '
    'own, e.g. *.bgclt.com) the client may use any label. A host matches when it IS the '
    'domain or ends in "." plus the domain.';

-- NOT EXISTS, so a domain removed on purpose by a later migration is not silently put
-- back by a seed that predates it -- but nothing here should ever be removed lightly:
-- dropping a domain frees every reserved word under it.
INSERT INTO control_plane.ctl_platform_domains (domain, reason, created_by)
SELECT v.domain, v.reason, 'migration:20261020-01'
  FROM (VALUES
    ('trovesuite.com',        'the suite: hub, APIs, every client subdomain'),
    ('mystoreguard.com',      'a product domain (dev.mystoreguard.com, ...)'),
    ('loandrift.com',         'a product domain (dev.loandrift.com, ...)'),
    ('zeloshr.com',           'a product domain, including the employee portal subdomains'),
    ('qpickstore.com',        'a product domain'),
    ('deladetech.com',        'the company, and the console (api.dev.deladetech.com)'),
    ('azurecontainerapps.io', 'our container apps'' default addresses'),
    ('amplifyapp.com',        'our frontends'' default addresses'),
    ('localhost',             'a developer''s machine')
  ) AS v(domain, reason)
 WHERE NOT EXISTS (SELECT 1 FROM control_plane.ctl_platform_domains d
                    WHERE d.domain = v.domain);

-- The normalised host: lowercase, trimmed of whitespace and of a trailing dot (an FQDN
-- written absolutely is the same name).
CREATE OR REPLACE FUNCTION control_plane.normalise_host(p_host text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path TO 'pg_catalog'
AS $function$
    SELECT rtrim(lower(btrim(coalesce(p_host, ''))), '.');
$function$;

-- platform_domain: which of our domains a host is under, or NULL when it is not ours.
-- The longest match wins, which only matters for a report; any match means "ours".
CREATE OR REPLACE FUNCTION control_plane.platform_domain(p_host text)
RETURNS text
LANGUAGE sql
STABLE
SET search_path TO 'control_plane', 'pg_catalog'
AS $function$
    SELECT d.domain
      FROM control_plane.ctl_platform_domains d
     WHERE control_plane.normalise_host(p_host) = d.domain
        OR right(control_plane.normalise_host(p_host), length(d.domain) + 1) = '.' || d.domain
     ORDER BY length(d.domain) DESC
     LIMIT 1;
$function$;

COMMENT ON FUNCTION control_plane.platform_domain(text) IS
    'The domain of ours (ctl_platform_domains) a host is, or is under, or NULL when the '
    'host is on somebody else''s domain.';

-- reserved_tenant_host: the reserved word that stops a CLIENT holding this host, or NULL.
-- This is the question the trigger and the console both ask.
CREATE OR REPLACE FUNCTION control_plane.reserved_tenant_host(p_host text)
RETURNS text
LANGUAGE sql
STABLE
SET search_path TO 'control_plane', 'pg_catalog'
AS $function$
    SELECT CASE
             WHEN control_plane.platform_domain(p_host) IS NULL THEN NULL
             ELSE control_plane.reserved_label(control_plane.host_label(p_host))
           END;
$function$;

COMMENT ON FUNCTION control_plane.reserved_tenant_host(text) IS
    'The reserved word that stops a client holding this host, or NULL. Only hosts on our '
    'own domains (ctl_platform_domains) are checked: on a client''s own domain any label '
    'is theirs to use.';

CREATE OR REPLACE FUNCTION control_plane.refuse_reserved_tenant_host()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'control_plane', 'pg_catalog'
AS $function$
DECLARE word text;
BEGIN
    word := control_plane.reserved_tenant_host(NEW.host);
    IF word IS NOT NULL THEN
        RAISE EXCEPTION
            'host % cannot belong to a client: % is reserved (%)',
            NEW.host, word,
            (SELECT reason FROM control_plane.ctl_reserved_labels WHERE label = word)
            USING ERRCODE = 'check_violation',
                  HINT = 'Pick a different subdomain, or release the word with '
                         'UPDATE control_plane.ctl_reserved_labels SET released_at = '
                         'now() WHERE label = ... -- not DELETE, which the next '
                         'deploy undoes. Only hosts on our own domains '
                         '(ctl_platform_domains) are checked.';
    END IF;
    RETURN NEW;
END
$function$;

-- The trigger itself (20261005-08) is unchanged: BEFORE INSERT OR UPDATE OF host,
-- WHEN route_kind = 'TENANT'. It calls the function above by name.

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer; before_count integer; h text; cell text;
BEGIN
    SELECT count(*) INTO before_count FROM control_plane.ctl_tenant_routes;
    -- Any cell this database knows; the probes are rolled back regardless.
    SELECT cell_key INTO cell FROM control_plane.ctl_cells ORDER BY cell_key LIMIT 1;
    IF cell IS NULL THEN
        RAISE NOTICE 'no cells in this database; trigger probes skipped';
    END IF;

    -- The function, on its own.
    IF control_plane.reserved_tenant_host('api2.dev.trovesuite.com') IS NULL
       OR control_plane.reserved_tenant_host('msg.dev.mystoreguard.com') IS NULL
       OR control_plane.reserved_tenant_host('API.TroveSuite.com.') IS NULL
       OR control_plane.reserved_tenant_host('admin.zeloshr.com') IS NULL THEN
        RAISE EXCEPTION 'a platform name on one of our domains is no longer caught';
    END IF;
    FOREACH h IN ARRAY ARRAY['mystoreguard.frontend.bgclt.com', 'msg.app.frontend.bgclt.com',
                             'cp.prod.backend.bgclt.com', 'msg.prod.backend.bgclt.com',
                             -- not under trovesuite.com: the dot is the boundary
                             'api.nottrovesuite.com', 'api.trovesuite.com.evil.example']
    LOOP
        IF control_plane.reserved_tenant_host(h) IS NOT NULL THEN
            RAISE EXCEPTION '% is on a client''s own domain and was still refused (%)',
                h, control_plane.reserved_tenant_host(h);
        END IF;
    END LOOP;
    IF control_plane.reserved_tenant_host('apinnovations.dev.trovesuite.com') IS NOT NULL THEN
        RAISE EXCEPTION 'an ordinary client name on our domain is refused';
    END IF;

    -- The trigger, by DOING it, each probe in its own subtransaction and rolled back.
    IF cell IS NOT NULL THEN
        BEGIN
            INSERT INTO control_plane.ctl_tenant_routes
                (host, tenant_id, tier, cell_key, status, is_wildcard, route_kind)
            VALUES ('api2.dev.trovesuite.com', 'tnt_probe', 'POOLED', cell, 'ACTIVE', false, 'TENANT');
            RAISE EXCEPTION 'a client was given api2.dev.trovesuite.com';
        EXCEPTION WHEN check_violation THEN NULL;
        END;

        BEGIN
            INSERT INTO control_plane.ctl_tenant_routes
                (host, tenant_id, tier, cell_key, status, is_wildcard, route_kind)
            -- (A made-up client domain, not bgclt.com: in BGCLT's own database its
            -- real hosts exist as PLATFORM rows and would collide on the key.)
            VALUES ('mystoreguard.frontend.probe-client.example', 'tnt_probe', 'POOLED', cell, 'ACTIVE', false, 'TENANT');
            RAISE EXCEPTION 'rollback the probe';
        EXCEPTION
            WHEN raise_exception THEN
                IF SQLERRM <> 'rollback the probe' THEN RAISE; END IF;
            WHEN check_violation THEN
                RAISE EXCEPTION 'a client''s own host was refused as a tenant route: %', SQLERRM;
        END;

        -- BGCLT's actual row shape: a SILO_BYOD TENANT route on the client's own domain,
        -- a reserved first label, silo_key and NO db_secret_uri (each app composes
        -- db-url-<app>-<silo>; ck_ctl_routes_silo_has_db accepts either since 20261007-06).
        BEGIN
            INSERT INTO control_plane.ctl_tenant_routes
                (host, tenant_id, tier, cell_key, status, is_wildcard, route_kind,
                 db_server_fqdn, db_name, db_secret_uri, silo_key,
                 storage_account, storage_secret_uri, container_prefix)
            VALUES ('cp.prod.backend.probe-client.example', 'tnt_probe', 'SILO_BYOD', cell,
                    'ACTIVE', false, 'TENANT', 'their.postgres.example', 'theirdb', NULL,
                    'probe', 'theirsa', 'https://v.vault.azure.net/secrets/storage-byod-probe', NULL);
            RAISE EXCEPTION 'rollback the probe';
        EXCEPTION
            WHEN raise_exception THEN
                IF SQLERRM <> 'rollback the probe' THEN RAISE; END IF;
            WHEN check_violation THEN
                RAISE EXCEPTION 'a BYOD route on a client''s own domain, naming its silo '
                                'rather than one secret, was refused: %', SQLERRM;
        END;

        -- A rename from a client domain onto ours is still caught.
        BEGIN
            INSERT INTO control_plane.ctl_tenant_routes
                (host, tenant_id, tier, cell_key, status, is_wildcard, route_kind)
            VALUES ('msg.app.probe-client.example', 'tnt_probe', 'POOLED', cell, 'ACTIVE', false, 'TENANT');
            UPDATE control_plane.ctl_tenant_routes SET host = 'msg.app.dev.trovesuite.com'
             WHERE host = 'msg.app.probe-client.example';
            RAISE EXCEPTION 'a client route was renamed onto msg.app.dev.trovesuite.com';
        EXCEPTION WHEN check_violation THEN NULL;
        END;
    END IF;

    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes;
    IF n <> before_count THEN
        RAISE EXCEPTION 'the route table went from % rows to % -- a probe survived',
            before_count, n;
    END IF;

    -- Every platform host that is reserved today is on one of our domains -- otherwise
    -- this file just stopped protecting it.
    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE route_kind = 'PLATFORM'
       AND control_plane.reserved_label(control_plane.host_label(host)) IS NOT NULL
       AND control_plane.platform_domain(host) IS NULL
       AND host NOT LIKE '%.bgclt.com';   -- BGCLT's enterprise-era rows, theirs
    IF n > 0 THEN
        RAISE NOTICE '% platform host(s) carry a reserved word but are on no domain in '
                     'ctl_platform_domains: %', n,
            (SELECT string_agg(host, ', ' ORDER BY host) FROM control_plane.ctl_tenant_routes
              WHERE route_kind = 'PLATFORM'
                AND control_plane.reserved_label(control_plane.host_label(host)) IS NOT NULL
                AND control_plane.platform_domain(host) IS NULL
                AND host NOT LIKE '%.bgclt.com');
    END IF;

    RAISE NOTICE 'reserved names apply on % domain(s) of ours; a client''s own domain is theirs',
        (SELECT count(*) FROM control_plane.ctl_platform_domains);
END $$;

COMMIT;
