-- The standard production addresses (owner-approved naming, 2026-10-20):
--
--   api.<app>.trovesuite.com   each product's API, bound as a custom domain on its
--                              prod container app next to the old address:
--                                coreplatform -> tvs-prod-core-platform-ca  (was cp.prod.backend)
--                                mystoreguard -> tvs-prod-mystoreguard-ca   (was msg.prod.backend)
--                                loandrift    -> tvs-prod-loandrift-ca      (was ld.prod.backend)
--                                zeloshr      -> tvs-prod-zeloshr-admin-ca  (was zhr-admin.prod.backend)
--                                crm, projects, invoicing, expenses -> tvs-prod-shared-apps-ca
--                                accounting   -> tvs-prod-accounting-admin-ca
--   accounting.trovesuite.com  Accounting's frontend under its product name, served by
--                              the same Amplify app as tapantabooks.trovesuite.com
--                              (which stays). A browser on it sends it as Origin, and the
--                              tenancy gate resolves the Origin (tenancy-gate-resolves-
--                              the-origin), so it needs a row before anyone signs in there.
--
-- ADDITIVE ONLY: every old address keeps its row. The API hosts are registered as well
-- although prod runs TENANCY_ENFORCE=false (Host alone is not refused there), so that
-- turning enforcement on later cannot 404 the new names.
--
-- PLATFORM rows: tenant_id NULL, POOLED, cell uksouth-prod, no silo, not a wildcard --
-- exactly like 20261019-49 and 20261020-02. Rows go in only where the uksouth-prod cell
-- exists. ON CONFLICT DO NOTHING: an existing row is left exactly as it is. Idempotent.

BEGIN;

INSERT INTO control_plane.ctl_tenant_routes (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT h.host, NULL, 'POOLED', h.cell, 'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261020-24'
  FROM (VALUES
        ('accounting.trovesuite.com',       'uksouth-prod'),
        ('api.coreplatform.trovesuite.com', 'uksouth-prod'),
        ('api.mystoreguard.trovesuite.com', 'uksouth-prod'),
        ('api.loandrift.trovesuite.com',    'uksouth-prod'),
        ('api.zeloshr.trovesuite.com',      'uksouth-prod'),
        ('api.crm.trovesuite.com',          'uksouth-prod'),
        ('api.projects.trovesuite.com',     'uksouth-prod'),
        ('api.invoicing.trovesuite.com',    'uksouth-prod'),
        ('api.expenses.trovesuite.com',     'uksouth-prod'),
        ('api.accounting.trovesuite.com',   'uksouth-prod')
       ) AS h(host, cell)
 WHERE EXISTS (SELECT 1 FROM control_plane.ctl_cells c WHERE c.cell_key = h.cell)
ON CONFLICT (host) DO NOTHING;

-- Invariants (not counts): none of these addresses may belong to a tenant, a silo or a wildcard.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host IN ('accounting.trovesuite.com',
                               'api.coreplatform.trovesuite.com', 'api.mystoreguard.trovesuite.com',
                               'api.loandrift.trovesuite.com', 'api.zeloshr.trovesuite.com',
                               'api.crm.trovesuite.com', 'api.projects.trovesuite.com',
                               'api.invoicing.trovesuite.com', 'api.expenses.trovesuite.com',
                               'api.accounting.trovesuite.com')
                  AND (tenant_id IS NOT NULL OR silo_key IS NOT NULL OR is_wildcard)) THEN
        RAISE EXCEPTION 'a production product address has been given to a tenant, a silo or a wildcard';
    END IF;
END $$;

COMMIT;
