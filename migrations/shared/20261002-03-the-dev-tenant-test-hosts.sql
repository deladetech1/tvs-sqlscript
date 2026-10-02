-- =====================================================================================
-- The dev tenant test hosts, and the container apps' own addresses.
--
-- Enforcement was switched on, refused bidtl.dev.trovesuite.com, and was switched off
-- again on the assumption that a live client had broken. It had not: bidtl and ddt are
-- test hosts. Refusing a subdomain nobody has registered is exactly what enforcement is
-- FOR, so the fix is a row, not a retreat.
--
-- ddt.dev.trovesuite.com already had one (20261001-02). bidtl did not, because nothing
-- records which tenant subdomains exist -- *.dev.trovesuite.com is a wildcard CNAME to
-- the hub's CloudFront, so any subdomain serves the hub whether or not anybody meant it
-- to. That is still the real gap for PRODUCTION, where a tenant's host must get a row
-- when the tenant is created. In dev it is a one-line INSERT per host you want to test
-- with, which is the intended workflow rather than a workaround.
--
-- The five container app FQDNs are here for a smaller reason: under enforcement, GET /
-- against an app's own ingress hostname is refused every couple of minutes by something
-- inside the Container Apps network, and '/' cannot go in the exempt-path list because
-- every path begins with it. The refusals are harmless -- no HTTP probe is configured on
-- any of these apps, only the default TCP one -- but a warning that fires constantly is
-- a warning nobody reads, and it would bury the refusals that mean something.
--
-- All POOLED and unpinned, like every other row here.
-- =====================================================================================

INSERT INTO control_plane.ctl_tenant_routes
    (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT host, NULL, 'POOLED', 'uksouth-dev', 'ACTIVE', false,
       CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261002-03'
  FROM (VALUES
        -- tenant subdomains used for testing on dev
        ('bidtl.dev.trovesuite.com'),
        -- each app's own ingress hostname
        ('tvs-dev-core-platform-ca.victoriousmeadow-176f82b8.uksouth.azurecontainerapps.io'),
        ('tvs-dev-loandrift-ca.victoriousmeadow-176f82b8.uksouth.azurecontainerapps.io'),
        ('tvs-dev-mystoreguard-ca.victoriousmeadow-176f82b8.uksouth.azurecontainerapps.io'),
        ('tvs-dev-zeloshr-admin-ca.victoriousmeadow-176f82b8.uksouth.azurecontainerapps.io'),
        ('tvs-dev-zeloshr-employee-ca.victoriousmeadow-176f82b8.uksouth.azurecontainerapps.io')
       ) AS h(host)
ON CONFLICT (host) DO NOTHING;

DO $$
DECLARE
    missing text;
    n integer;
BEGIN
    SELECT coalesce(string_agg(h, ', ' ORDER BY h), ''), count(*) INTO missing, n
      FROM (VALUES
            ('bidtl.dev.trovesuite.com'), ('ddt.dev.trovesuite.com'),
            ('tvs-dev-core-platform-ca.victoriousmeadow-176f82b8.uksouth.azurecontainerapps.io'),
            ('tvs-dev-loandrift-ca.victoriousmeadow-176f82b8.uksouth.azurecontainerapps.io'),
            ('tvs-dev-mystoreguard-ca.victoriousmeadow-176f82b8.uksouth.azurecontainerapps.io'),
            ('tvs-dev-zeloshr-admin-ca.victoriousmeadow-176f82b8.uksouth.azurecontainerapps.io'),
            ('tvs-dev-zeloshr-employee-ca.victoriousmeadow-176f82b8.uksouth.azurecontainerapps.io')
           ) AS want(h)
     WHERE NOT EXISTS (
        SELECT 1 FROM control_plane.ctl_tenant_routes r
         WHERE r.status = 'ACTIVE'
           AND (r.host = want.h OR (r.is_wildcard AND want.h LIKE '%.' || r.host)));

    IF n > 0 THEN
        RAISE EXCEPTION 'still unrouted: %', missing;
    END IF;
    RAISE NOTICE 'dev test hosts and container app FQDNs all resolve';
END $$;
