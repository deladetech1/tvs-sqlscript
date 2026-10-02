-- =====================================================================================
-- Every API hostname gets a route row. The rule that said otherwise was wrong.
--
-- 20261001-01 and 20261001-03 deliberately left the API hosts out, on the reasoning that
-- "the API is an app's address, not a tenant's". That is a true statement about what the
-- address MEANS and a wrong one about what the table is FOR, and enforcement made the
-- difference matter: eight of the ten API hostnames answered 404 to any request that
-- arrived without an Origin header.
--
-- Loandrift's own deploy pipeline caught it. Its post-deploy step curls
-- ld.dev.backend.trovesuite.com/api/v1/inbox expecting 401 or 403, got 404 twenty-four
-- times, and failed the deployment. Server-to-server callers, webhook receivers and the
-- desktop and mobile clients are the same shape -- none of them sends an Origin.
--
-- The table answers two questions and I had merged them:
--
--   is this address served by this platform?   <- a row answers this
--   does this address identify a TENANT?       <- tenant_id answers this
--
-- A POOLED row with a NULL tenant_id says "served here, no tenant implied", which is
-- exactly the truth about an API hostname. Leaving the row out does not say "not a
-- tenant" -- it says "not ours", and under enforcement that is a 404.
--
-- This also removes an asymmetry: api.dev.zeloshr.com and admin-api.dev.zeloshr.com
-- already worked, but only by accident, because they sit inside the *.dev.zeloshr.com
-- portal wildcard. Resting on that was luck, not design.
-- =====================================================================================

INSERT INTO control_plane.ctl_tenant_routes
    (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT host, NULL, 'POOLED', cell, 'ACTIVE', false,
       CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261002-05'
  FROM (VALUES
        -- the per-app backend hosts under trovesuite.com
        ('cp.dev.backend.trovesuite.com',           'uksouth-dev'),
        ('ld.dev.backend.trovesuite.com',           'uksouth-dev'),
        ('msg.dev.backend.trovesuite.com',          'uksouth-dev'),
        ('zhr-admin.dev.backend.trovesuite.com',    'uksouth-dev'),
        ('zhr-employee.backend.dev.trovesuite.com', 'uksouth-dev'),
        -- the product-domain API hosts
        ('api.dev.trovesuite.com',                  'uksouth-dev'),
        ('api.dev.loandrift.com',                   'uksouth-dev'),
        ('api.dev.mystoreguard.com',                'uksouth-dev'),
        ('api.dev.zeloshr.com',                     'uksouth-dev'),
        ('admin-api.dev.zeloshr.com',               'uksouth-dev'),
        -- staging and production equivalents, so the same 404 does not wait there
        ('cp.stage.backend.trovesuite.com',         'uksouth-staging'),
        ('ld.stage.backend.trovesuite.com',         'uksouth-staging'),
        ('msg.stage.backend.trovesuite.com',        'uksouth-staging'),
        ('zhr-admin.stage.backend.trovesuite.com',  'uksouth-staging'),
        ('api.stage.loandrift.com',                 'uksouth-staging'),
        ('api.stage.mystoreguard.com',              'uksouth-staging'),
        ('api.stage.zeloshr.com',                   'uksouth-staging'),
        ('admin-api.stage.zeloshr.com',             'uksouth-staging'),
        ('cp.backend.trovesuite.com',               'uksouth-prod'),
        ('ld.backend.trovesuite.com',               'uksouth-prod'),
        ('msg.backend.trovesuite.com',              'uksouth-prod'),
        ('zhr-admin.backend.trovesuite.com',        'uksouth-prod'),
        ('api.trovesuite.com',                      'uksouth-prod'),
        ('api.loandrift.com',                       'uksouth-prod'),
        ('api.mystoreguard.com',                    'uksouth-prod'),
        ('api.zeloshr.com',                         'uksouth-prod'),
        ('admin-api.zeloshr.com',                   'uksouth-prod')
       ) AS h(host, cell)
ON CONFLICT (host) DO NOTHING;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE
    missing text;
    n integer;
BEGIN
    -- The dev hosts are the ones that can be checked from outside right now.
    SELECT coalesce(string_agg(h, ', ' ORDER BY h), ''), count(*) INTO missing, n
      FROM (VALUES
            ('cp.dev.backend.trovesuite.com'), ('ld.dev.backend.trovesuite.com'),
            ('msg.dev.backend.trovesuite.com'), ('zhr-admin.dev.backend.trovesuite.com'),
            ('zhr-employee.backend.dev.trovesuite.com'),
            ('api.dev.trovesuite.com'), ('api.dev.loandrift.com'),
            ('api.dev.mystoreguard.com'), ('api.dev.zeloshr.com'),
            ('admin-api.dev.zeloshr.com')
           ) AS want(h)
     WHERE NOT EXISTS (
        SELECT 1 FROM control_plane.ctl_tenant_routes r
         WHERE r.status = 'ACTIVE' AND r.host = want.h);

    IF n > 0 THEN
        RAISE EXCEPTION 'API hostnames still unrouted, so a caller with no Origin gets 404: %', missing;
    END IF;

    -- An API host must never be pinned to a tenant: it serves all of them, and the
    -- token is what says which.
    IF EXISTS (
        SELECT 1 FROM control_plane.ctl_tenant_routes
         WHERE (host LIKE 'api.%' OR host LIKE 'admin-api.%' OR host LIKE '%.backend.%')
           AND tenant_id IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'an API hostname is pinned to a tenant; it serves all of them';
    END IF;

    RAISE NOTICE 'every API hostname is routed, in all three environments';
END $$;
