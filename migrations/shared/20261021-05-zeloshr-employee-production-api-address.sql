-- ZelosHR's employee API in production (owner-approved, 2026-10-21):
--
--   api.zeloshr-portal.trovesuite.com   custom domain on tvs-prod-zeloshr-employee-ca,
--                                       the API behind the employee portal
--                                       (https://zeloshr.com, https://<company>.zeloshr.com).
--
-- Registered the same way 20261020-24 registered the other api.<app>.trovesuite.com
-- hosts: prod runs TENANCY_ENFORCE=false, so Host alone is not refused today, and the
-- row is there so turning enforcement on later cannot 404 this name. The portal's
-- browser Origins need nothing new: zeloshr.com is already the POOLED wildcard parent.
--
-- PLATFORM row: tenant_id NULL, POOLED, cell uksouth-prod, no silo, not a wildcard.
-- Inserted only where the uksouth-prod cell exists (a no-op on dev). ON CONFLICT DO
-- NOTHING: an existing row is left exactly as it is. Idempotent.

BEGIN;

INSERT INTO control_plane.ctl_tenant_routes (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT h.host, NULL, 'POOLED', h.cell, 'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261021-05'
  FROM (VALUES
        ('api.zeloshr-portal.trovesuite.com', 'uksouth-prod')
       ) AS h(host, cell)
 WHERE EXISTS (SELECT 1 FROM control_plane.ctl_cells c WHERE c.cell_key = h.cell)
ON CONFLICT (host) DO NOTHING;

-- Invariant (not a count): this address may not belong to a tenant, a silo or a wildcard.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host = 'api.zeloshr-portal.trovesuite.com'
                  AND (tenant_id IS NOT NULL OR silo_key IS NOT NULL OR is_wildcard)) THEN
        RAISE EXCEPTION 'the production ZelosHR employee API address has been given to a tenant, a silo or a wildcard';
    END IF;
END $$;

COMMIT;
