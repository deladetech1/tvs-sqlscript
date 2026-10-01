-- =====================================================================
-- The product domains become addresses the platform recognises
-- ---------------------------------------------------------------------
-- Each product has its own domain now -- dev.loandrift.com,
-- dev.mystoreguard.com, dev.zeloshr.com -- rather than a subdomain of
-- trovesuite.com. The reason is the one that made this necessary in the first
-- place: mystoreguard.trovesuite.com occupies a single-label name under the
-- suite domain, which is exactly the space a tenant's own address needs, so a
-- tenant called "mystoreguard" or "loandrift" would have collided with an app.
-- Moving the apps onto their own domains empties that space.
--
-- FRONTEND hosts only, deliberately. api.dev.loandrift.com and its siblings are
-- NOT here and must not be: the API is reached at its own address, so its Host
-- names the app rather than a tenant, and a route row for it would make an app
-- address resolve as though it were a tenant's. The tenant signal at the API is
-- the Origin header, which carries the FRONTEND host -- which is what these rows
-- are for. See 1.0.50 in tvs-package.
--
-- All POOLED. These are the suite's own addresses rather than any one tenant's,
-- so they name no tenant and serve dev-db like every other dev address.
--
-- The old <app>.dev.trovesuite.com rows stay. Nothing is being cut over, and a
-- frontend still reachable at its old address must still resolve there.
--
-- Idempotent; safe to re-run on every deploy.
-- =====================================================================

INSERT INTO control_plane.ctl_tenant_routes
    (host, tenant_id, tier, cell_key, status, cdate, ctime, cdatetime, created_by)
VALUES
    ('dev.loandrift.com',    NULL, 'POOLED', 'uksouth-dev', 'ACTIVE',
     CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration'),
    ('dev.mystoreguard.com', NULL, 'POOLED', 'uksouth-dev', 'ACTIVE',
     CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration'),
    ('dev.zeloshr.com',      NULL, 'POOLED', 'uksouth-dev', 'ACTIVE',
     CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration')
ON CONFLICT (host) DO NOTHING;
