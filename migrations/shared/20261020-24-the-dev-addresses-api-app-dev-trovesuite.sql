-- The standard dev addresses (owner-approved naming, 2026-10-20):
--
--   frontends  <app>.dev.trovesuite.com
--   backends   api.<app>.dev.trovesuite.com
--
-- for coreplatform, mystoreguard, loandrift, zeloshr, crm, projects, invoicing, expenses and
-- accounting. The new names are ADDED; every old address (api.dev.trovesuite.com,
-- api.dev.mystoreguard.com, cp.dev.backend.trovesuite.com, the container-app FQDNs,
-- tapantabooks.dev.trovesuite.com, ...) keeps its row and keeps working.
--
--   api.coreplatform.dev.trovesuite.com  tvs-dev-core-platform-ca
--   api.mystoreguard.dev.trovesuite.com  tvs-dev-mystoreguard-ca
--   api.loandrift.dev.trovesuite.com     tvs-dev-loandrift-ca
--   api.zeloshr.dev.trovesuite.com       tvs-dev-zeloshr-admin-ca
--   api.crm.dev.trovesuite.com           tvs-dev-shared-apps-ca  (one container,
--   api.projects.dev.trovesuite.com      tvs-dev-shared-apps-ca   four products,
--   api.invoicing.dev.trovesuite.com     tvs-dev-shared-apps-ca   split by path)
--   api.expenses.dev.trovesuite.com      tvs-dev-shared-apps-ca
--   api.accounting.dev.trovesuite.com    tvs-dev-accounting-admin-ca
--   accounting.dev.trovesuite.com        Accounting's frontend (Amplify tvs-accounting-ft),
--                                        beside tapantabooks.dev.trovesuite.com
--
-- The other frontends (crm, projects, invoicing, expenses, mystoreguard, loandrift, zeloshr)
-- already have rows. The tenancy gate resolves the Host AND the Origin
-- (tenancy-gate-resolves-the-origin), so a backend host with no row answers 404 "This
-- address is not configured" and a frontend with no row has every API call refused.
--
-- accounting.dev.trovesuite.com was registered once before and taken out by 20261019-28,
-- which also released the label "accounting" so a tenant may own an "accounting" subdomain.
-- That release stands: this is a PLATFORM row (the reserved-label trigger only looks at
-- TENANT rows), and the host itself is now taken. 20261019-28's DELETE of the host was
-- removed in the same change, or every deploy would delete the row and this file put it
-- back a moment later.
--
-- PLATFORM rows: tenant_id NULL, POOLED, cell uksouth-dev, no silo, not a wildcard. DEV ONLY:
-- rows go in only where the uksouth-dev cell exists, so production, staging and any silo or
-- enterprise database without that cell skip quietly. ON CONFLICT DO NOTHING: an existing
-- row is left exactly as it is.
--
-- Idempotent; safe to re-run.

BEGIN;

INSERT INTO control_plane.ctl_tenant_routes (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT h.host, NULL, 'POOLED', h.cell, 'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261020-24'
  FROM (VALUES
        ('api.coreplatform.dev.trovesuite.com', 'uksouth-dev'),
        ('api.mystoreguard.dev.trovesuite.com', 'uksouth-dev'),
        ('api.loandrift.dev.trovesuite.com',    'uksouth-dev'),
        ('api.zeloshr.dev.trovesuite.com',      'uksouth-dev'),
        ('api.crm.dev.trovesuite.com',          'uksouth-dev'),
        ('api.projects.dev.trovesuite.com',     'uksouth-dev'),
        ('api.invoicing.dev.trovesuite.com',    'uksouth-dev'),
        ('api.expenses.dev.trovesuite.com',     'uksouth-dev'),
        ('api.accounting.dev.trovesuite.com',   'uksouth-dev'),
        ('accounting.dev.trovesuite.com',       'uksouth-dev')
       ) AS h(host, cell)
 WHERE EXISTS (SELECT 1 FROM control_plane.ctl_cells c WHERE c.cell_key = h.cell)
ON CONFLICT (host) DO NOTHING;

-- Invariants (not counts): none of these addresses may belong to a tenant, a silo or a wildcard.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host IN ('api.coreplatform.dev.trovesuite.com', 'api.mystoreguard.dev.trovesuite.com',
                               'api.loandrift.dev.trovesuite.com', 'api.zeloshr.dev.trovesuite.com',
                               'api.crm.dev.trovesuite.com', 'api.projects.dev.trovesuite.com',
                               'api.invoicing.dev.trovesuite.com', 'api.expenses.dev.trovesuite.com',
                               'api.accounting.dev.trovesuite.com', 'accounting.dev.trovesuite.com')
                  AND (tenant_id IS NOT NULL OR silo_key IS NOT NULL OR is_wildcard)) THEN
        RAISE EXCEPTION 'a dev product address has been given to a tenant, a silo or a wildcard';
    END IF;
END $$;

COMMIT;
