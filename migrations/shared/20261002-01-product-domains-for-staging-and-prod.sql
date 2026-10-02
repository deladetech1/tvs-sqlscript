-- =====================================================================================
-- The product domains, in staging and production as well as dev.
--
-- 20261001-03 registered dev.loandrift.com, dev.mystoreguard.com and dev.zeloshr.com.
-- Nothing above dev was ever seeded, so the route table currently claims three hosts out
-- of the whole product-domain estate, and turning TENANCY_ENFORCE on anywhere but dev
-- would answer "This address is not configured" to every single request.
--
-- Frontend hosts only, the same rule as before: an API host is an app's address, not a
-- tenant's, and gets no row. The resolver reads Origin first for exactly this reason --
-- the browser is on dev.loandrift.com while the request goes to api.dev.loandrift.com.
--
-- zeloshr has two apps and one domain, and the split decided on 2026-10-02 is:
--     employee UI   <env>.zeloshr.com          (and *.<env>.zeloshr.com for portals)
--     admin UI      admin.<env>.zeloshr.com
--     employee API  api.<env>.zeloshr.com      -- no row, it is an app address
--     admin API     admin-api.<env>.zeloshr.com -- likewise
--
-- The portal wildcard goes on each environment's employee host, never on an apex that
-- must refuse unknown subdomains. 20261001-04 raises if anybody flags a trovesuite.com
-- host; the same reasoning applies to a product apex that is not a portal namespace.
--
-- Staging shares dev's database (see the tvs-iac environment notes), so staging rows
-- live in the same table as dev's and are distinguished only by cell_key.
-- =====================================================================================

INSERT INTO control_plane.ctl_tenant_routes
    (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
VALUES
    -- staging
    ('stage.loandrift.com',          NULL, 'POOLED', 'uksouth-staging', 'ACTIVE', false,
     CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261002-01'),
    ('stage.mystoreguard.com',       NULL, 'POOLED', 'uksouth-staging', 'ACTIVE', false,
     CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261002-01'),
    ('stage.zeloshr.com',            NULL, 'POOLED', 'uksouth-staging', 'ACTIVE', true,
     CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261002-01'),
    ('admin.stage.zeloshr.com',      NULL, 'POOLED', 'uksouth-staging', 'ACTIVE', false,
     CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261002-01'),
    -- production
    ('loandrift.com',                NULL, 'POOLED', 'uksouth-prod', 'ACTIVE', false,
     CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261002-01'),
    ('www.loandrift.com',            NULL, 'POOLED', 'uksouth-prod', 'ACTIVE', false,
     CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261002-01'),
    ('mystoreguard.com',             NULL, 'POOLED', 'uksouth-prod', 'ACTIVE', false,
     CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261002-01'),
    ('www.mystoreguard.com',         NULL, 'POOLED', 'uksouth-prod', 'ACTIVE', false,
     CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261002-01'),
    ('zeloshr.com',                  NULL, 'POOLED', 'uksouth-prod', 'ACTIVE', true,
     CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261002-01'),
    ('www.zeloshr.com',              NULL, 'POOLED', 'uksouth-prod', 'ACTIVE', false,
     CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261002-01'),
    ('admin.zeloshr.com',            NULL, 'POOLED', 'uksouth-prod', 'ACTIVE', false,
     CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261002-01'),
    -- dev's admin host, the one piece 20261001-03 could not know about
    ('admin.dev.zeloshr.com',        NULL, 'POOLED', 'uksouth-dev', 'ACTIVE', false,
     CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261002-01')
ON CONFLICT (host) DO NOTHING;

-- zeloshr.com and stage.zeloshr.com are portal namespaces, like dev.zeloshr.com. Set
-- here as well as in the INSERT, because a row already present from an earlier run
-- would have been skipped by ON CONFLICT DO NOTHING and never flagged.
UPDATE control_plane.ctl_tenant_routes
   SET is_wildcard = true, udatetime = now(), updated_by = 'migration 20261002-01'
 WHERE host IN ('zeloshr.com', 'stage.zeloshr.com', 'dev.zeloshr.com')
   AND is_wildcard IS DISTINCT FROM true;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE
    missing text;
    wildcards text;
BEGIN
    SELECT coalesce(string_agg(h, ', ' ORDER BY h), '') INTO missing
      FROM (VALUES
            ('loandrift.com'), ('mystoreguard.com'), ('zeloshr.com'),
            ('admin.zeloshr.com'), ('admin.dev.zeloshr.com'),
            ('stage.loandrift.com'), ('stage.mystoreguard.com'),
            ('stage.zeloshr.com'), ('admin.stage.zeloshr.com')
           ) AS want(h)
     WHERE NOT EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes r WHERE r.host = want.h);

    IF missing <> '' THEN
        RAISE EXCEPTION 'product-domain hosts still unrouted: %', missing;
    END IF;

    -- Every wildcard must be a portal namespace. An apex that is not one would
    -- serve the shared database to any unprovisioned subdomain.
    SELECT coalesce(string_agg(host, ', ' ORDER BY host), '(none)') INTO wildcards
      FROM control_plane.ctl_tenant_routes WHERE is_wildcard;

    IF EXISTS (
        SELECT 1 FROM control_plane.ctl_tenant_routes
         WHERE is_wildcard AND host NOT LIKE '%zeloshr.com'
    ) THEN
        RAISE EXCEPTION
            'a non-zeloshr host is flagged as a wildcard (%). Only the employee '
            'portal has a subdomain-per-tenant namespace.', wildcards;
    END IF;

    RAISE NOTICE 'product domains routed in dev, staging and prod; wildcards: %', wildcards;
END $$;
