-- The production addresses the browsers actually send as Origin that had no route:
-- ZelosHR's frontend and the QPickStore storefront.
--
--   zeloshr.trovesuite.com  ZelosHR's production frontend (Amplify tvs-zeloshr-admin-ft,
--                           d2ahmnxyl80jjh). Its sign-in page calls cp.prod.backend and
--                           zhr-admin.prod.backend; both refused it with 404 "This address
--                           is not configured", so nobody could sign in there. The dev
--                           twin (zeloshr.dev.trovesuite.com) has had a row since 20261002;
--                           20261002-01 registered only zeloshr-admin.trovesuite.com and
--                           admin.zeloshr.com for production.
--   qpickstore.com,         the storefront's production site. It calls
--   www.qpickstore.com      msg.prod.backend.trovesuite.com and has been refused there
--                           since 2026-10-11 (logs: "unrouted host 'qpickstore.com'
--                           (signal=origin)"). Dev registers dev.qpickstore.com the same way.
--
-- The tenancy gate resolves the Origin header, not only the Host
-- (tenancy-gate-resolves-the-origin), so every frontend address needs a row.
--
-- PLATFORM rows: tenant_id NULL, POOLED, cell uksouth-prod, no silo, not a wildcard --
-- exactly like 20261019-49. Rows go in only where the uksouth-prod cell exists; a silo or
-- enterprise database without it skips quietly. The labels are reserved (20261005-08,
-- 20261020-01), so no tenant can take them. A shop's own subdomain (<slug>.qpickstore.com)
-- is deliberately NOT covered: no wildcard is added here.
--
-- ON CONFLICT DO NOTHING and no tenant_id restated: a row that already exists is left
-- exactly as it is. Idempotent; safe to re-run.

BEGIN;

INSERT INTO control_plane.ctl_tenant_routes (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT h.host, NULL, 'POOLED', h.cell, 'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261020-02'
  FROM (VALUES
        ('zeloshr.trovesuite.com', 'uksouth-prod'),
        ('qpickstore.com',         'uksouth-prod'),
        ('www.qpickstore.com',     'uksouth-prod')
       ) AS h(host, cell)
 WHERE EXISTS (SELECT 1 FROM control_plane.ctl_cells c WHERE c.cell_key = h.cell)
ON CONFLICT (host) DO NOTHING;

-- Invariants (not counts): none of these addresses may belong to a tenant, a silo or a wildcard.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host IN ('zeloshr.trovesuite.com', 'qpickstore.com', 'www.qpickstore.com')
                  AND (tenant_id IS NOT NULL OR silo_key IS NOT NULL OR is_wildcard)) THEN
        RAISE EXCEPTION 'a production product address has been given to a tenant, a silo or a wildcard';
    END IF;
END $$;

COMMIT;
