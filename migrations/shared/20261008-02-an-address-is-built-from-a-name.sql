-- ---------------------------------------------------------------------------
-- An address is built from a name, and can be changed afterwards.
--
-- Two things an operator should not have to do by hand.
--
-- TYPING THE WHOLE HOSTNAME. Creating a silo's address meant typing
-- kofi.dev.trovesuite.com, of which only "kofi" is a decision -- the rest is
-- ours and differs per environment. A typo produces a route nobody ever
-- reaches: the row is valid, no request arrives, and nothing says so.
--
-- CHANGING IT. There was no way at all. The pooled rename flow refuses to move
-- a silo's address (its address is tied to its infrastructure), and the
-- console's form disables the host once the row exists, because renaming has
-- to claim the new address before releasing the old or the client is
-- unreachable in between. So a silo's address was decided once, for ever, by
-- whoever typed it.
--
-- WHY claim_tenant_host IS NOT REUSED HERE
--
-- It derives tier and cell_key FROM THE PARENT and writes no database columns
-- at all -- deliberately, as its own comment says: "a silo is not created this
-- way at all". Pointed at a silo it would produce a POOLED route carrying a
-- silo's address, which is the failure the whole table exists to prevent: the
-- client's requests would quietly reach the shared database. So the move below
-- copies the silo's own columns instead, and the two functions stay apart.
-- ---------------------------------------------------------------------------

-- ------------------------------------------- 1. which address clients sit under
--
-- There are twenty-odd PLATFORM routes in a cell -- product sites, API hosts,
-- container-app hostnames -- and nothing said which one a client's address
-- hangs off. Signup never needed to know: it uses the host the request arrived
-- at. The console does, because it is composing an address for a client who
-- has not arrived anywhere yet.
--
-- A column rather than a flag on the routes, so a cell cannot accidentally
-- have two. NULL means addresses cannot be composed in that cell, and
-- bgclt-prod is NULL for the same reason it has no shared server: it is one
-- client's own installation, not somewhere we put clients.
ALTER TABLE control_plane.ctl_cells
    ADD COLUMN IF NOT EXISTS tenant_parent_host text;

COMMENT ON COLUMN control_plane.ctl_cells.tenant_parent_host IS
    'The PLATFORM address a client''s own address is composed under in this cell '
    '(kofi + dev.trovesuite.com). NULL means addresses cannot be composed here. '
    'Must name an ACTIVE PLATFORM route, which the composer re-checks.';

UPDATE control_plane.ctl_cells c
   SET tenant_parent_host = v.parent, udatetime = now(), updated_by = 'migration'
  FROM (VALUES ('uksouth-dev',     'dev.trovesuite.com'),
               ('uksouth-staging', 'staging.trovesuite.com'),
               ('uksouth-prod',    'trovesuite.com')) AS v(cell, parent)
 WHERE c.cell_key = v.cell
   AND c.tenant_parent_host IS DISTINCT FROM v.parent;

-- Each one must really be an active platform address, or the console would
-- offer a parent the claim then refuses. Asserted rather than assumed: the
-- seed above is three literals and this is what catches the fourth being
-- added wrongly later.
DO $$
DECLARE bad text;
BEGIN
    SELECT string_agg(format('%s -> %s', c.cell_key, c.tenant_parent_host), '; ')
      INTO bad
      FROM control_plane.ctl_cells c
     WHERE c.tenant_parent_host IS NOT NULL
       AND NOT EXISTS (
            SELECT 1 FROM control_plane.ctl_tenant_routes r
             WHERE r.host = c.tenant_parent_host
               AND r.route_kind = 'PLATFORM' AND r.status = 'ACTIVE');
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION
            'these cells name a parent that is not an active platform address: %', bad;
    END IF;
END $$;

-- ------------------------------------------------- 2. one slugifier, in SQL
--
-- The console needs to turn "Obeng Enterprises Ltd" into a label. So does
-- signup, which already does it in Python (sh_tenant_address.slugify). Two
-- implementations of the same rule drift, and the drift shows up as a form
-- promising an address the claim refuses -- exactly the bug 20261008-01 had to
-- fix between the pre-check and the claim.
--
-- So the rule lives here and the console calls it. The Python one is left
-- where it is -- rewriting the pooled signup path to call out to SQL is risk
-- for no gain -- and a test asserts the two agree on a list of names.
CREATE OR REPLACE FUNCTION control_plane.label_for_name(p_name text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $function$
DECLARE
    s   text := lower(btrim(coalesce(p_name, '')));
    cut integer;
BEGIN
    -- Anything that is not a letter or digit is a separator, so '&', '.', '_'
    -- and runs of whitespace all collapse the same way.
    s := regexp_replace(s, '[^a-z0-9]+', '-', 'g');
    s := btrim(s, '-');
    IF length(s) > 40 THEN
        s := left(s, 40);
        -- Cut at a word boundary when one is within reach, so
        -- 'bright-interior-decor-trade-limited' does not become
        -- '...trade-limit'. 24 is 60% of 40, as the Python does.
        cut := length(s) - position('-' in reverse(s)) + 1;
        IF position('-' in reverse(s)) > 0 AND cut > 24 THEN
            s := left(s, cut - 1);
        END IF;
    END IF;
    RETURN btrim(s, '-');
END
$function$;

COMMENT ON FUNCTION control_plane.label_for_name(text) IS
    'A client name as a DNS label, or '''' when nothing usable survives -- a trading '
    'name in a script with no Latin characters, or "&&&". Returns empty rather than '
    'inventing something the client would not recognise. Mirrors '
    'sh_tenant_address.slugify; scripts/test_one_slugifier.py asserts they agree.';

-- -------------------------------------------------- 3. changing an address
--
-- THE OLD ADDRESS KEEPS WORKING. That is the whole shape of this: the new row
-- is created ACTIVE beside the old one, both resolving to the same tenant and
-- the same database, and releasing the old one is a SEPARATE decision made
-- later. A client is never unreachable in between, their open sessions keep
-- working, and anything with the old address written down -- a bookmark, an
-- email, a webhook somebody configured -- keeps working until you say
-- otherwise.
--
-- One tenant may hold several addresses: ix_ctl_tenant_routes_tenant is not
-- unique, and that is relied on here.
--
-- THE SILO'S COLUMNS ARE COPIED, not recomposed. The new address must reach
-- the same database with the same credentials, so every column that decides
-- that is carried over verbatim. Anything added to this table later and NOT
-- added here is a column the new address silently loses -- which for a
-- database or storage column means the client's requests go somewhere else.
-- That is why this copies by name rather than by SELECT *, so adding a column
-- is a decision somebody makes rather than one they forget.
CREATE OR REPLACE FUNCTION control_plane.move_tenant_host(
    p_old_host  text,
    p_new_label text,
    p_expected_tenant_id text,
    p_moved_by  text DEFAULT NULL)
RETURNS control_plane.ctl_tenant_routes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = control_plane, pg_catalog
AS $function$
DECLARE
    old      control_plane.ctl_tenant_routes;
    parent   control_plane.ctl_tenant_routes;
    v_label  text := lower(btrim(coalesce(p_new_label, '')));
    v_parent text;
    v_host   text;
    v_word   text;
    r        control_plane.ctl_tenant_routes;
BEGIN
    SELECT * INTO old FROM control_plane.ctl_tenant_routes WHERE host = p_old_host;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'no route for host %', p_old_host
            USING ERRCODE = 'no_data_found';
    END IF;

    -- Only a client's address moves. A PLATFORM address is shared by every
    -- tenant, and "moving" one would take the hub, an API or a product site
    -- off the air for everybody.
    IF old.route_kind <> 'TENANT' THEN
        RAISE EXCEPTION
            '% is a % address, which belongs to the platform rather than to a client',
            p_old_host, old.route_kind
            USING ERRCODE = 'check_violation';
    END IF;

    -- WHOSE ADDRESS IT IS, confirmed by the caller. The console reads the row,
    -- shows the operator whose it is, and passes that back; if it changed in
    -- between -- a setup completing, another operator moving it -- this
    -- refuses rather than moving an address that now belongs to somebody else.
    IF old.tenant_id IS DISTINCT FROM p_expected_tenant_id THEN
        RAISE EXCEPTION
            'route % belongs to tenant %, not %', p_old_host,
            coalesce(old.tenant_id, '<none>'), coalesce(p_expected_tenant_id, '<none>')
            USING ERRCODE = 'check_violation';
    END IF;

    IF v_label !~ '^[a-z0-9]([a-z0-9-]{0,38}[a-z0-9])?$' THEN
        RAISE EXCEPTION 'label % is not a usable web address', p_new_label
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_word := control_plane.reserved_label(v_label);
    IF v_word IS NOT NULL THEN
        RAISE EXCEPTION 'label % contains the reserved word %', v_label, v_word
            USING ERRCODE = 'check_violation';
    END IF;

    -- THE PARENT COMES FROM THE OLD ADDRESS, not from the caller and not from
    -- the cell. A move changes which name a client answers to, never which of
    -- our domains they sit under -- and taking it from the old host means a
    -- caller cannot move a client onto a domain they were never on.
    v_parent := substring(old.host from position('.' in old.host) + 1);
    IF position('.' in old.host) = 0 OR v_parent = '' THEN
        RAISE EXCEPTION '% has no parent domain to move within', p_old_host
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    SELECT * INTO parent FROM control_plane.ctl_tenant_routes
     WHERE host = v_parent AND route_kind = 'PLATFORM' AND status = 'ACTIVE';
    IF NOT FOUND THEN
        RAISE EXCEPTION
            '% is not one of our active platform addresses, so nothing can be given a '
            'subdomain of it', v_parent
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_host := v_label || '.' || parent.host;
    IF v_host = old.host THEN
        -- Not an error. Asking for the address it already has is answered with
        -- the row, the same way reconcile_route_tenant answers a repeated bind.
        RETURN old;
    END IF;

    -- Copied by name. See the header: a column added to this table and not
    -- added here is one the new address loses.
    INSERT INTO control_plane.ctl_tenant_routes (
        host, tenant_id, tier, cell_key, silo_key,
        db_server_fqdn, db_name, db_secret_uri,
        storage_account, container_prefix, storage_secret_uri,
        api_base, status, is_wildcard, route_kind,
        cdate, ctime, cdatetime, created_by)
    VALUES (
        v_host, old.tenant_id, old.tier, old.cell_key, old.silo_key,
        old.db_server_fqdn, old.db_name, old.db_secret_uri,
        old.storage_account, old.container_prefix, old.storage_secret_uri,
        old.api_base, 'ACTIVE', old.is_wildcard, 'TENANT',
        CURRENT_DATE::text, CURRENT_TIME::text, now(),
        COALESCE(p_moved_by, session_user))
    RETURNING * INTO r;
    -- A host that is taken raises unique_violation from the primary key, which
    -- the caller tells apart from the refusals above. Not caught: swallowing it
    -- would let two clients believe they hold one address.

    -- The old row is deliberately NOT touched. Releasing it is the separate
    -- decision described in the header, and release_tenant_host already does
    -- it with the same whose-is-it check.
    RETURN r;
END
$function$;

COMMENT ON FUNCTION control_plane.move_tenant_host(text, text, text, text) IS
    'Give a client a second address under the same platform domain, carrying the same '
    'tier, cell, database and storage, and pointing at the same tenant. The OLD address '
    'is left ACTIVE: releasing it is a separate step, so nobody is cut off mid-move. '
    'Refuses a PLATFORM address, an address belonging to another tenant, a reserved or '
    'malformed label, and a host already taken.';

-- A new function is executable by everybody, which for a definer-rights
-- function is the whole attack surface.
REVOKE ALL ON FUNCTION control_plane.move_tenant_host(text, text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION control_plane.label_for_name(text) FROM PUBLIC;

-- THERE IS NO DATABASE-LEVEL BOUNDARY HERE, and saying so is the point.
--
-- The console connects as coreplatform_dev -- the same login core-platform
-- uses -- so the database cannot tell the console apart from the application,
-- and a grant cannot say "only the console may move an address". The first
-- version of this file granted to a `deladetech%` role that does not exist,
-- which would have left the console unable to move anything while reading as
-- though a boundary had been drawn.
--
-- So the grant goes to the app groups, like reconcile_route_tenant's, and what
-- actually restricts a move is the console's own capability check on the
-- endpoint plus the operator re-entering their password. If that is ever not
-- enough, the fix is a login of its own for the console, not a grant here.
--
-- What the function still enforces, whoever calls it: a PLATFORM address
-- cannot be moved, an address belonging to another tenant cannot be taken, the
-- parent comes from the old host rather than the caller, and a reserved or
-- malformed label is refused.
DO $$
DECLARE grp text;
BEGIN
    FOR grp IN SELECT rolname FROM pg_roles WHERE rolname LIKE 'tvs_app_%' LOOP
        EXECUTE format(
            'GRANT EXECUTE ON FUNCTION control_plane.label_for_name(text) TO %I', grp);
        EXECUTE format(
            'GRANT EXECUTE ON FUNCTION control_plane.move_tenant_host('
            'text, text, text, text) TO %I', grp);
    END LOOP;
END $$;
