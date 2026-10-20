-- The production addresses of the apps that joined on dev: CRM, Projects, Invoicing,
-- Expenses and Accounting (TapantaBooks).
--
-- Each app's "joins the platform" migration (20261015-01, 20261016-01, 20261019-01,
-- 20261019-26, 20261019-28) gave its frontend a PLATFORM row for dev only
-- (<app>.dev.trovesuite.com, cell uksouth-dev). Production has none, so on prod the hub's
-- *.trovesuite.com wildcard answers those hosts, and Core Platform resolves the frontend's
-- Origin to no route. Prod runs with TENANCY_ENFORCE=false today, so that is pooled rather
-- than refused -- but the row has to exist before enforcement is switched on, and it
-- belongs next to the other prod product hosts (20261002-01).
--
-- Only *.trovesuite.com production hosts. The labels are already reserved by the
-- migrations above, so no tenant can take them. Rows go in only where the uksouth-prod
-- cell exists (it does in every pooled database; a silo or enterprise database without it
-- skips quietly, like the dev rows).
--
-- Idempotent; safe to re-run.

BEGIN;

INSERT INTO control_plane.ctl_tenant_routes (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT h.host, NULL, 'POOLED', h.cell, 'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261019-49'
  FROM (VALUES
        ('crm.trovesuite.com',          'uksouth-prod'),
        ('projects.trovesuite.com',     'uksouth-prod'),
        ('invoicing.trovesuite.com',    'uksouth-prod'),
        ('expenses.trovesuite.com',     'uksouth-prod'),
        ('tapantabooks.trovesuite.com', 'uksouth-prod')
       ) AS h(host, cell)
 WHERE EXISTS (SELECT 1 FROM control_plane.ctl_cells c WHERE c.cell_key = h.cell)
ON CONFLICT (host) DO NOTHING;

-- Invariants (not counts): none of these addresses may belong to a tenant.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host IN ('crm.trovesuite.com', 'projects.trovesuite.com', 'invoicing.trovesuite.com',
                               'expenses.trovesuite.com', 'tapantabooks.trovesuite.com')
                  AND (tenant_id IS NOT NULL OR silo_key IS NOT NULL OR is_wildcard)) THEN
        RAISE EXCEPTION 'a production product address has been given to a tenant, a silo or a wildcard';
    END IF;
END $$;

COMMIT;
