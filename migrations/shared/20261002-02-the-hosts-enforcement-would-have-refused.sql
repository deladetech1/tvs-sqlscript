-- =====================================================================================
-- The seven hosts TENANCY_ENFORCE would have refused.
--
-- With the product domains routed, the switch looked ready. It was not. Resolving every
-- known client host through the real resolver found seven that no row claimed:
--
--     dev.dfzxotrr84aq5.amplifyapp.com   core platform
--     dev.d19llexij7xvh3.amplifyapp.com  loandrift
--     dev.d1q82h5ftqrr6o.amplifyapp.com  mystoreguard
--     dev.d9tar2cmup9bx.amplifyapp.com   zeloshr admin
--     dev.d2vojxowprew1a.amplifyapp.com  zeloshr employees
--     dev.d308li0zuofobf.amplifyapp.com  commerce
--     dev.qpickstore.com                 commerce's own domain
--
-- Every one of them is in cors_origins, which is the project's own statement that they
-- are legitimate clients -- the Amplify default domains are what you open when a custom
-- domain is mid-change, which is exactly when you least want a 404 you cannot explain.
--
-- A row for a host nobody uses costs a row. A missing row for a host somebody uses is an
-- outage, and under enforcement it is an outage that reads "This address is not
-- configured", which sends whoever hits it looking at DNS rather than at this table.
-- That asymmetry is already why cors_origins lists hosts before they exist.
--
-- POOLED and unpinned, like every other row here: these are alternative addresses for
-- frontends that serve all tenants, and the token says which.
-- =====================================================================================

INSERT INTO control_plane.ctl_tenant_routes
    (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT host, NULL, 'POOLED', 'uksouth-dev', 'ACTIVE', false,
       CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261002-02'
  FROM (VALUES
        ('dev.dfzxotrr84aq5.amplifyapp.com'),
        ('dev.d19llexij7xvh3.amplifyapp.com'),
        ('dev.d1q82h5ftqrr6o.amplifyapp.com'),
        ('dev.d9tar2cmup9bx.amplifyapp.com'),
        ('dev.d2vojxowprew1a.amplifyapp.com'),
        ('dev.d308li0zuofobf.amplifyapp.com'),
        ('dev.qpickstore.com')
       ) AS h(host)
ON CONFLICT (host) DO NOTHING;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE
    unrouted text;
    n integer;
BEGIN
    -- Every origin the backends are configured to accept should resolve, or
    -- enforcement refuses a caller the project has already blessed. Checked here
    -- rather than trusted, because the whole point of this file is that the last
    -- check of this kind was done by eye and missed seven.
    SELECT coalesce(string_agg(h, ', ' ORDER BY h), ''), count(*) INTO unrouted, n
      FROM (VALUES
            ('dev.trovesuite.com'), ('dev.loandrift.com'), ('dev.mystoreguard.com'),
            ('dev.zeloshr.com'), ('admin.dev.zeloshr.com'), ('dev.qpickstore.com'),
            ('loandrift.dev.trovesuite.com'), ('mystoreguard.dev.trovesuite.com'),
            ('zeloshr-admin.dev.trovesuite.com'), ('zeloshr.dev.trovesuite.com'),
            ('ddt.dev.trovesuite.com'), ('localhost'),
            ('dev.dfzxotrr84aq5.amplifyapp.com'), ('dev.d19llexij7xvh3.amplifyapp.com'),
            ('dev.d1q82h5ftqrr6o.amplifyapp.com'), ('dev.d9tar2cmup9bx.amplifyapp.com'),
            ('dev.d2vojxowprew1a.amplifyapp.com'), ('dev.d308li0zuofobf.amplifyapp.com')
           ) AS want(h)
     WHERE NOT EXISTS (
        SELECT 1 FROM control_plane.ctl_tenant_routes r
         WHERE r.status = 'ACTIVE'
           AND (r.host = want.h
                OR (r.is_wildcard AND want.h LIKE '%.' || r.host)));

    IF n > 0 THEN
        RAISE EXCEPTION 'TENANCY_ENFORCE would still refuse % known dev host(s): %', n, unrouted;
    END IF;

    RAISE NOTICE 'every known dev client host resolves; enforcement is safe to enable on dev';
END $$;
