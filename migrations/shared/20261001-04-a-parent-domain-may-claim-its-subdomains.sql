-- =====================================================================================
-- A route row may claim every subdomain of its host.
--
-- The employee portal reaches a tenant at <subdomain>.dev.zeloshr.com, and the
-- subdomain comes from zeloshr.zhr_employee_portal_subdomain, which maps it to
-- tenant_id, org_id, bus_id and loc_id. That table is a tenant route table for one
-- app, and it predates this one. The control plane has a row for dev.zeloshr.com and
-- none for any portal, so driving the employee API with TENANCY_ENFORCE=true refuses
-- deladetech.dev.zeloshr.com -- the one portal that actually exists on dev -- with
-- "This address is not configured".
--
-- Three ways to fix that, and the first two are worse:
--
--   * let the app INSERT a route row when a portal is created. The app would need
--     write access to the control plane, and every app that grows a subdomain would
--     need it too. Apps resolve routes; they do not get to invent them.
--   * keep the two tables in sync with a trigger. No app grant needed, but the
--     trigger has to know the environment's portal domain -- dev.zeloshr.com here,
--     zeloshr.com in production -- and this migration file runs in every
--     environment, so it cannot know which one it is in.
--   * say once, on the parent row, that it answers for its subdomains too.
--
-- The third needs no per-tenant row at all, which is right because there is nothing
-- per-tenant to say: every portal today is POOLED, served by the one database, and
-- WHICH tenant is a question the token already answers. A row per portal would be a
-- row that repeats the parent's every column and drifts from it.
--
-- It also leaves the silo path intact, and this is the part worth being careful
-- about. When deladetech moves to its own database it gets an explicit row for
-- deladetech.dev.zeloshr.com, tier SILO_*, tenant_id set -- and the resolver prefers
-- an exact host over any wildcard, so that row takes over for that one tenant while
-- every other portal keeps falling through to the parent. The flag is what makes the
-- first silo a one-row change instead of a backfill.
--
-- WHAT NOT TO FLAG, because it would quietly undo the tier design: trovesuite.com
-- and its environment hosts. company.trovesuite.com means "that company's own
-- database", so a subdomain nobody has provisioned must be refused, not served from
-- the pool. A wildcard there would turn every typo into a working login page for the
-- shared database. Flag a parent domain only when every subdomain of it is, by
-- design, the same tenancy answer.
-- =====================================================================================

ALTER TABLE control_plane.ctl_tenant_routes
    ADD COLUMN IF NOT EXISTS is_wildcard boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN control_plane.ctl_tenant_routes.is_wildcard IS
    'This row also answers for every subdomain of host. An exact row always wins, '
    'so a tenant moving to its own database gets its own row and takes precedence. '
    'Only for a parent domain whose subdomains all share one tenancy answer.';

-- A single-label host has no subdomains worth claiming, and `localhost` as a
-- wildcard would claim every single-label name in a developer's hosts file.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conname = 'ck_ctl_routes_wildcard_has_a_dot'
           AND conrelid = 'control_plane.ctl_tenant_routes'::regclass
    ) THEN
        ALTER TABLE control_plane.ctl_tenant_routes
            ADD CONSTRAINT ck_ctl_routes_wildcard_has_a_dot CHECK (
                NOT is_wildcard OR position('.' in host) > 0
            );
    END IF;
END $$;

-- The employee portal is the one place this is true today. dev.zeloshr.com is the
-- employee app's host and EmployeePortalDomain in its settings, so *.dev.zeloshr.com
-- is exactly the set of portals.
UPDATE control_plane.ctl_tenant_routes
   SET is_wildcard = true,
       udatetime   = now(),
       updated_by  = 'migration 20261001-04'
 WHERE host = 'dev.zeloshr.com'
   AND is_wildcard IS DISTINCT FROM true;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE
    wildcards   text;
    n_wildcard  integer;
    portal_subs integer;
BEGIN
    SELECT count(*), coalesce(string_agg(host, ', ' ORDER BY host), '(none)')
      INTO n_wildcard, wildcards
      FROM control_plane.ctl_tenant_routes
     WHERE is_wildcard;

    -- Loud if somebody flags an apex that must refuse unknown subdomains.
    IF EXISTS (
        SELECT 1 FROM control_plane.ctl_tenant_routes
         WHERE is_wildcard
           AND (host = 'trovesuite.com' OR host LIKE '%.trovesuite.com')
    ) THEN
        RAISE EXCEPTION
            'A trovesuite.com host is flagged as a wildcard. company.trovesuite.com '
            'means that company''s own database, so an unprovisioned subdomain must be '
            'refused rather than served from the pool.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM control_plane.ctl_tenant_routes
         WHERE host = 'dev.zeloshr.com' AND is_wildcard
    ) THEN
        RAISE EXCEPTION 'dev.zeloshr.com is not flagged; employee portals would still be refused';
    END IF;

    -- Counted only if the table is there. This file runs in every environment and
    -- the employee portal schema is not guaranteed to have reached all of them;
    -- a missing table must not fail a migration that does not depend on it.
    IF to_regclass('zeloshr.zhr_employee_portal_subdomain') IS NOT NULL THEN
        EXECUTE 'SELECT count(*) FROM zeloshr.zhr_employee_portal_subdomain'
           INTO portal_subs;
    ELSE
        portal_subs := -1;
    END IF;

    RAISE NOTICE
        'wildcard route(s): % [%]; % portal subdomain(s) now resolve through the parent row',
        n_wildcard, wildcards, portal_subs;
END $$;
