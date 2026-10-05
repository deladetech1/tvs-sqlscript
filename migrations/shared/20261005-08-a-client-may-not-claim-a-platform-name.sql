-- =====================================================================================
-- A client may not claim a platform name.
--
-- Every tenant is getting an address of its own -- itech.dev.trovesuite.com for a silo
-- client, bgclt.dev.trovesuite.com for a pooled one (20261005-07). That address is built
-- from a name the CLIENT supplies, and it lands in the same namespace the platform lives
-- in: api.trovesuite.com is this system's backend, www.trovesuite.com its marketing site,
-- cp.backend.trovesuite.com the hub. A company that signed up as "API Solutions" would be
-- handed api.trovesuite.com, and with it every app's API.
--
-- WHY THE DATABASE AND NOT THE SIGNUP FORM
-- Nothing in any application inserts a route. Silo routes are written by this tree when
-- the infrastructure is provisioned; the console only ever repoints one through
-- reconcile_route_tenant (its role holds SELECT and nothing else), and signup is about to
-- become a third writer. A list kept in one of those three is a list the other two do not
-- have -- the same failure as the Amplify hostnames, which needed four places to agree
-- and got it wrong twice. The table is the one thing every writer goes through.
--
-- WHOLE TOKENS, NOT A PREFIX AND NOT AN EXACT SET
-- An exact set lets api2, www-1 and cp-staging through, and those are the ones nobody
-- thinks of until one is taken. Raw prefix matching is far worse in the other direction:
-- "app" would refuse Appleseed and Apparel Hub, "ns" would refuse Nsano, "ld" would
-- refuse anything beginning in those two letters. Refusing a real customer's name is not
-- a smaller mistake than this migration is preventing -- it is the same mistake pointed
-- at the person paying.
--
-- So the label is split into tokens on dashes, underscores and digits, and a token is
-- refused only when it IS a reserved word:
--
--     api2         -> api, 2         refused
--     api-dev      -> api, dev       refused
--     zeloshr-admin-> zeloshr, admin refused
--     apinnovations-> apinnovations  allowed
--     nsano        -> nsano          allowed
--     accesspoint  -> accesspoint    allowed (and is a live client)
--
-- Because a reserved word only ever matches a whole token, two-letter entries like ld,
-- cp and ns are safe to list -- which is what makes it possible to list the short forms
-- that are real hosts today.
--
-- TENANT ROUTES ONLY. api.dev.trovesuite.com and the other 60-odd PLATFORM rows are ours
-- and must keep working; the trigger's WHEN clause is what keeps this migration from
-- being an outage. The rule is not "this name is forbidden", it is "a client may not be
-- the one holding it".
-- =====================================================================================

CREATE TABLE IF NOT EXISTS control_plane.ctl_reserved_labels (
    label      text        NOT NULL,
    reason     text        NOT NULL,
    -- RELEASED, NOT DELETED. A word is handed to a customer who turns out to want it by
    -- setting this, and the row stays. Deleting it does not work: every migration
    -- re-runs on every deploy, so the seed below would simply put the word back, and
    -- the word coming back does not break the route that already exists -- the trigger
    -- only fires on INSERT and on a rename. It breaks the NEXT one. A client cleared
    -- and set up again at the same address, which is a thing that has happened three
    -- times to itech, would be refused their own name by a word nobody remembers
    -- releasing.
    released_at timestamptz,
    released_by text,
    cdatetime  timestamptz NOT NULL DEFAULT now(),
    created_by text,
    CONSTRAINT pk_ctl_reserved_labels PRIMARY KEY (label),
    -- ONE TOKEN, lowercase letters only. Not decoration: the comparison tokenises the
    -- client's label, so an entry containing a dash or a digit could never match
    -- anything. 'zeloshr-admin' looks like it would work and would silently protect
    -- nothing -- it is covered by 'zeloshr' instead. Refused here rather than accepted
    -- and ignored.
    CONSTRAINT ck_ctl_reserved_labels_token CHECK (label ~ '^[a-z]{1,30}$')
);

COMMENT ON TABLE control_plane.ctl_reserved_labels IS
    'Words no client may have in the subdomain they are given. Matched as whole tokens '
    'after the label is split on dashes, underscores and digits, so api2 and api-dev are '
    'refused while apinnovations is not. Enforced by a trigger on ctl_tenant_routes for '
    'TENANT routes only -- the platform''s own hosts are these names. To hand a word '
    'over, SET released_at = now(); do not DELETE the row, or the next deploy re-seeds '
    'it.';

COMMENT ON COLUMN control_plane.ctl_reserved_labels.released_at IS
    'When this word was given up, or NULL while it is still held. A released row is '
    'ignored by reserved_label and is what stops the seed re-reserving the word on the '
    'next deploy.';

COMMENT ON COLUMN control_plane.ctl_reserved_labels.reason IS
    'Why it is held back, so that whoever is deciding whether to release one to a '
    'customer knows what breaks. "api" is an outage; "beta" is a name we might want.';

-- ------------------------------------------------------------------------- the words
-- Seeded with NOT EXISTS, not ON CONFLICT, and the NOT EXISTS does not look at
-- released_at: a word that has been given to a customer is still a row here, so the
-- re-run finds it and leaves it alone. That is the whole reason release is a column
-- rather than a DELETE.
INSERT INTO control_plane.ctl_reserved_labels (label, reason, created_by)
SELECT v.label, v.reason, 'migration:20261005-08'
  FROM (VALUES
    -- Hosts that exist. Handing one of these over is an outage, today, not a theory.
    ('api',          'the platform API: api.trovesuite.com and every product API'),
    ('www',          'the marketing site'),
    ('cp',           'the hub backend: cp.backend.trovesuite.com'),
    ('ld',           'loandrift backend: ld.backend.trovesuite.com'),
    ('msg',          'mystoreguard backend: msg.backend.trovesuite.com'),
    ('zhr',          'zeloshr backend: zhr-admin.backend.trovesuite.com'),
    ('admin',        'zeloshr admin: admin.zeloshr.com, admin-api.zeloshr.com'),
    ('backend',      'the backend subdomain every product API sits under'),
    ('localhost',    'resolves to the developer''s own machine'),
    -- Environments. A client called "Staging Ltd" would take staging.trovesuite.com.
    ('dev',          'the development environment'),
    ('stage',        'the staging environment'),
    ('staging',      'staging.trovesuite.com'),
    ('prod',         'the production environment'),
    ('production',   'the production environment'),
    ('test',         'test environments, and the retired test hosts'),
    ('testing',      'test environments'),
    ('uat',          'acceptance environments'),
    ('qa',           'acceptance environments'),
    ('sandbox',      'where a trial environment would go'),
    ('preview',      'where a preview deployment would go'),
    ('local',        'a developer''s machine'),
    -- The products, including the short forms used in real hosts.
    ('trovesuite',   'the platform itself'),
    ('tvs',          'the platform''s short form, used in every resource name'),
    ('loandrift',    'a product: loandrift.trovesuite.com'),
    ('mystoreguard', 'a product: mystoreguard.trovesuite.com'),
    ('zeloshr',      'a product: zeloshr.trovesuite.com, zeloshr-admin.trovesuite.com'),
    ('qpickstore',   'a product: qpickstore.com'),
    ('commerce',     'a product'),
    ('attendance',   'a product'),
    ('deladetech',   'the company, and the console''s own domain'),
    ('ddt',          'the company''s short form'),
    -- Where the platform would put things next. Cheaper to hold now than to take back
    -- from a customer who has printed it on their letterhead.
    ('app',          'where a tenant-facing app would be served'),
    ('apps',         'where a tenant-facing app would be served'),
    ('console',      'the operations console'),
    ('portal',       'the employee portal pattern zeloshr already uses'),
    ('auth',         'sign-in'),
    ('login',        'sign-in'),
    ('signup',       'sign-up'),
    ('sso',          'single sign-on'),
    ('oauth',        'the OAuth callback host'),
    ('account',      'account management'),
    ('accounts',     'account management'),
    ('billing',      'invoices and payment'),
    ('pay',          'payment collection'),
    ('payments',     'payment collection'),
    ('checkout',     'payment collection'),
    ('docs',         'documentation'),
    ('help',         'support'),
    ('support',      'support'),
    ('status',       'the status page: the one host that must answer when nothing does'),
    ('blog',         'publishing'),
    ('news',         'publishing'),
    ('internal',     'staff-only tooling'),
    ('platform',     'the platform itself'),
    ('system',       'the system tenant'),
    ('root',         'reads as the administrator'),
    ('secure',       'reads as the platform''s own'),
    ('tenant',       'reads as the platform''s own'),
    ('tenants',      'reads as the platform''s own'),
    ('client',       'reads as the platform''s own'),
    ('clients',      'the console: cportal is the client-management tool'),
    ('customer',     'reads as the platform''s own'),
    ('customers',    'reads as the platform''s own'),
    -- Infrastructure names. A subdomain that looks like mail or DNS makes a client's
    -- address usable for things a client's address should not be usable for.
    ('mail',         'mail'),
    ('email',        'mail'),
    ('smtp',         'mail'),
    ('imap',         'mail'),
    ('mx',           'mail'),
    ('ns',           'DNS'),
    ('dns',          'DNS'),
    ('cdn',          'content delivery'),
    ('static',       'static assets'),
    ('assets',       'static assets'),
    ('media',        'uploaded files'),
    ('files',        'uploaded files'),
    ('storage',      'blob storage'),
    ('db',           'the database'),
    ('database',     'the database'),
    ('cache',        'infrastructure'),
    ('queue',        'infrastructure'),
    ('logs',         'infrastructure'),
    ('monitor',      'monitoring'),
    ('metrics',      'monitoring'),
    ('grafana',      'monitoring'),
    ('vpn',          'network access'),
    ('ftp',          'file transfer'),
    ('webhook',      'inbound callbacks'),
    ('webhooks',     'inbound callbacks'),
    ('graphql',      'an API surface'),
    -- RFC 2142 and the CA/Browser Forum's approver addresses. A certificate authority
    -- will issue for a domain to whoever answers at these names; a client who held one
    -- would be able to prove control of a name that is not theirs.
    ('postmaster',   'RFC 2142: a certificate approver address'),
    ('hostmaster',   'RFC 2142: a certificate approver address'),
    ('webmaster',    'RFC 2142: a certificate approver address'),
    ('abuse',        'RFC 2142'),
    ('security',     'RFC 2142, and security.txt'),
    ('noc',          'RFC 2142'),
    ('autodiscover', 'claimed by mail clients'),
    ('autoconfig',   'claimed by mail clients')
  ) AS v(label, reason)
 WHERE NOT EXISTS (SELECT 1 FROM control_plane.ctl_reserved_labels x
                    WHERE x.label = v.label);

-- --------------------------------------------------------------------- the comparison
-- host_label: the first label of a host. 'itech' out of 'itech.dev.trovesuite.com'.
CREATE OR REPLACE FUNCTION control_plane.host_label(p_host text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path TO 'pg_catalog'
AS $function$
    SELECT split_part(lower(btrim(coalesce(p_host, ''))), '.', 1);
$function$;

COMMENT ON FUNCTION control_plane.host_label(text) IS
    'The first label of a host. The rest is one of our domains, so it is the first label '
    'the client chooses.';

-- reserved_label: the reserved word a label contains, or NULL. Returns the WORD rather
-- than a boolean so the error can name it -- "api" is a sentence an operator can act on,
-- "that name is not available" is a support ticket.
CREATE OR REPLACE FUNCTION control_plane.reserved_label(p_label text)
RETURNS text
LANGUAGE sql
STABLE
SET search_path TO 'control_plane', 'pg_catalog'
AS $function$
    SELECT r.label
      FROM unnest(
             -- Digits and underscores become separators, then split on runs of dashes.
             -- api2 -> {api}, www-1 -> {www}, cp_staging -> {cp,staging}. Empty tokens
             -- fall out of the join, so a trailing separator costs nothing.
             regexp_split_to_array(
                 regexp_replace(lower(btrim(coalesce(p_label, ''))), '[0-9_]+', '-', 'g'),
                 '-+')) AS t(token)
      JOIN control_plane.ctl_reserved_labels r
        ON r.label = t.token AND r.released_at IS NULL
     ORDER BY r.label
     LIMIT 1;
$function$;

COMMENT ON FUNCTION control_plane.reserved_label(text) IS
    'The reserved word in a subdomain label, or NULL when there is none. Whole tokens '
    'after splitting on dashes, underscores and digits -- api2 and api-dev are refused, '
    'apinnovations is not. Call it from signup to refuse a name while the person is '
    'still typing, rather than after the tenant has been created.';

-- ------------------------------------------------------------------------- the trigger
CREATE OR REPLACE FUNCTION control_plane.refuse_reserved_tenant_host()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'control_plane', 'pg_catalog'
AS $function$
DECLARE word text;
BEGIN
    word := control_plane.reserved_label(control_plane.host_label(NEW.host));
    IF word IS NOT NULL THEN
        RAISE EXCEPTION
            'host % cannot belong to a client: % is reserved (%)',
            NEW.host, word,
            (SELECT reason FROM control_plane.ctl_reserved_labels WHERE label = word)
            USING ERRCODE = 'check_violation',
                  HINT = 'Pick a different subdomain, or release the word with '
                         'UPDATE control_plane.ctl_reserved_labels SET released_at = '
                         'now() WHERE label = ... -- not DELETE, which the next '
                         'deploy undoes.';
    END IF;
    RETURN NEW;
END
$function$;

DROP TRIGGER IF EXISTS trg_ctl_routes_reserved_host ON control_plane.ctl_tenant_routes;

-- TENANT only, and the WHEN clause is the load-bearing part: every one of the platform's
-- own hosts is a reserved name, so a trigger without it would refuse the next deploy's
-- re-run of the migrations that create them.
CREATE TRIGGER trg_ctl_routes_reserved_host
    BEFORE INSERT OR UPDATE OF host ON control_plane.ctl_tenant_routes
    FOR EACH ROW
    WHEN (NEW.route_kind = 'TENANT')
    EXECUTE FUNCTION control_plane.refuse_reserved_tenant_host();

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer; before_count integer; word text; detail text;
BEGIN
    SELECT count(*) INTO before_count FROM control_plane.ctl_tenant_routes;

    SELECT count(*) INTO n FROM control_plane.ctl_reserved_labels;
    IF n < 50 THEN
        RAISE EXCEPTION 'only % reserved label(s) -- the seed did not land', n;
    END IF;

    -- THE LIVE CLIENTS COME FIRST. If this migration refuses a name a customer already
    -- has, it is wrong, and finding that out from the customer is not acceptable.
    SELECT COALESCE(string_agg(host || ' (' || control_plane.reserved_label(
                        control_plane.host_label(host)) || ')', ', '), '')
      INTO detail
      FROM control_plane.ctl_tenant_routes
     WHERE route_kind = 'TENANT'
       AND control_plane.reserved_label(control_plane.host_label(host)) IS NOT NULL;
    IF detail <> '' THEN
        RAISE EXCEPTION 'this would refuse address(es) a client already holds: %. '
                        'Remove that word from the seed rather than the route', detail;
    END IF;

    -- The three shapes that matter, checked through the function so the reasoning above
    -- is tested and not just asserted.
    IF control_plane.reserved_label('api') IS NULL THEN
        RAISE EXCEPTION 'the exact word api is allowed';
    END IF;
    IF control_plane.reserved_label('api2') IS NULL THEN
        RAISE EXCEPTION 'api2 is allowed -- digits are not splitting the label, which is '
                        'the whole reason this is not an exact-match list';
    END IF;
    IF control_plane.reserved_label('cp-staging') IS NULL THEN
        RAISE EXCEPTION 'cp-staging is allowed -- dashes are not splitting the label';
    END IF;
    IF control_plane.reserved_label('zeloshr-admin') IS NULL THEN
        RAISE EXCEPTION 'zeloshr-admin is allowed';
    END IF;
    -- ...and the other direction, which is the one that costs a customer.
    FOREACH word IN ARRAY ARRAY['apinnovations', 'nsano', 'appleseed', 'accesspoint',
                                'bgclt', 'itech', 'ldfoods', 'stationery', 'testament']
    LOOP
        IF control_plane.reserved_label(word) IS NOT NULL THEN
            RAISE EXCEPTION 'the real name % is refused, because % is matched as a '
                            'prefix rather than a whole token',
                            word, control_plane.reserved_label(word);
        END IF;
    END LOOP;

    -- An entry that could never match is refused, rather than sitting there looking
    -- like protection.
    BEGIN
        INSERT INTO control_plane.ctl_reserved_labels (label, reason)
        VALUES ('probe-two-tokens', 'probe');
        RAISE EXCEPTION 'a multi-token reserved label was accepted, and would protect '
                        'nothing while appearing to';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    -- ---------------------------------------------------------------- the trigger
    -- Proved by DOING it: a trigger that exists and a trigger that fires are different
    -- claims, and the WHEN clause means the second does not follow from the first.
    BEGIN
        INSERT INTO control_plane.ctl_tenant_routes
            (host, tenant_id, tier, cell_key, status, is_wildcard, route_kind)
        VALUES ('api2.dev.trovesuite.com', 'tnt_probe', 'POOLED', 'uksouth-dev',
                'ACTIVE', false, 'TENANT');
        RAISE EXCEPTION 'a client was given api2.dev.trovesuite.com';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    -- A client''s own address with an ordinary name still works. This is the case
    -- 20261005-07 opened up, and a reserved-name trigger is the obvious way to close it
    -- again by accident.
    BEGIN
        INSERT INTO control_plane.ctl_tenant_routes
            (host, tenant_id, tier, cell_key, status, is_wildcard, route_kind)
        VALUES ('apinnovations.dev.trovesuite.com', 'tnt_probe', 'POOLED', 'uksouth-dev',
                'ACTIVE', false, 'TENANT');
    EXCEPTION WHEN check_violation THEN
        RAISE EXCEPTION 'an ordinary client name was refused: %', SQLERRM;
    END;

    -- Renaming an existing route into a reserved name is the same mistake arriving by
    -- UPDATE, which is why the trigger lists UPDATE OF host.
    BEGIN
        UPDATE control_plane.ctl_tenant_routes
           SET host = 'www.dev.trovesuite.com'
         WHERE host = 'apinnovations.dev.trovesuite.com';
        RAISE EXCEPTION 'a client route was renamed onto www';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    DELETE FROM control_plane.ctl_reserved_labels WHERE label LIKE 'probe%';
    DELETE FROM control_plane.ctl_tenant_routes
     WHERE host IN ('api2.dev.trovesuite.com', 'apinnovations.dev.trovesuite.com');

    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes;
    IF n <> before_count THEN
        RAISE EXCEPTION 'the route table went from % rows to % -- a probe survived or a '
                        'real route was removed', before_count, n;
    END IF;

    -- OUR OWN HOSTS ARE ALL RESERVED NAMES, so this is the check that would have caught
    -- a trigger written without its WHEN clause.
    SELECT count(*) INTO n FROM control_plane.ctl_tenant_routes
     WHERE route_kind = 'PLATFORM'
       AND control_plane.reserved_label(control_plane.host_label(host)) IS NOT NULL;
    IF n = 0 THEN
        RAISE EXCEPTION 'no platform host matches a reserved word, which cannot be '
                        'right -- api.dev.trovesuite.com is one of them';
    END IF;
    BEGIN
        INSERT INTO control_plane.ctl_tenant_routes
            (host, tenant_id, tier, cell_key, status, is_wildcard, route_kind)
        VALUES ('api-probe.dev.trovesuite.com', NULL, 'POOLED', 'uksouth-dev',
                'ACTIVE', false, 'PLATFORM');
    EXCEPTION WHEN check_violation THEN
        RAISE EXCEPTION 'the trigger fired on a PLATFORM route, so the next deploy''s '
                        're-run of the migrations that create our own hosts would fail';
    END;
    DELETE FROM control_plane.ctl_tenant_routes WHERE host = 'api-probe.dev.trovesuite.com';

    RAISE NOTICE 'a client may not claim a platform name: % words held, % of our own '
                 'hosts use one',
        (SELECT count(*) FROM control_plane.ctl_reserved_labels),
        (SELECT count(*) FROM control_plane.ctl_tenant_routes
          WHERE route_kind = 'PLATFORM'
            AND control_plane.reserved_label(control_plane.host_label(host)) IS NOT NULL);
END $$;
