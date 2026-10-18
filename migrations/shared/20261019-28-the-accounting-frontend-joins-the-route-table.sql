-- The Accounting frontend gets its address, the way every app's frontend has one.
--
-- tvs-accounting-ft is served at its public name, tapantabooks.dev.trovesuite.com (CRM,
-- Projects, Invoicing and Expenses use <app>.dev.trovesuite.com; Accounting's product name is
-- TapantaBooks). Without a row the hub's wildcard answers "Address not configured", and Core
-- Platform refuses the frontend's calls, because it resolves the tenant from the Origin.
--
-- Only the address and its label. Accounting's cp_apps row stays as the CorePlatform seed
-- has it (coming_soon, inactive) until launch; its schema, permissions and roles are its
-- own module's (src/Trovesuite.Database.Accounting).
--
-- The label "tapantabooks" is reserved like every product's. Existing tenant routes are not
-- touched -- the trigger refuses the next insert or rename only -- and any already holding
-- the token are named below as a NOTICE.
--
-- THE FIRST VERSION OF THIS FILE (deployed to saas-dev on 2026-10-18 for a few hours) used
-- accounting.dev.trovesuite.com and reserved "accounting". Nothing serves that host, so its
-- row comes out (only while it is still an unclaimed platform address, as 20261005-04 did
-- for the Amplify defaults), and "accounting" is RELEASED, not deleted (20261005-08): a
-- tenant may have an "accounting" subdomain -- accounting firms are likely customers.
--
-- Idempotent; safe to re-run.

BEGIN;

INSERT INTO control_plane.ctl_reserved_labels (label, reason, created_by)
SELECT v.label, v.reason, 'migration:20261019-28'
  FROM (VALUES ('tapantabooks', 'a product: tapantabooks.dev.trovesuite.com, Accounting')) AS v(label, reason)
 WHERE NOT EXISTS (SELECT 1 FROM control_plane.ctl_reserved_labels r WHERE r.label = v.label);

INSERT INTO control_plane.ctl_tenant_routes (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT h.host, NULL, 'POOLED', h.cell, 'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261019-28'
  FROM (VALUES ('tapantabooks.dev.trovesuite.com', 'uksouth-dev')) AS h(host, cell)
 WHERE EXISTS (SELECT 1 FROM control_plane.ctl_cells c WHERE c.cell_key = h.cell)
ON CONFLICT (host) DO NOTHING;

-- The first version's address and label.
DELETE FROM control_plane.ctl_tenant_routes
 WHERE host = 'accounting.dev.trovesuite.com'
   AND tier = 'POOLED'
   AND tenant_id IS NULL
   AND silo_key IS NULL;

UPDATE control_plane.ctl_reserved_labels
   SET released_at = now(), released_by = 'migration:20261019-28'
 WHERE label = 'accounting'
   AND created_by = 'migration:20261019-28'
   AND released_at IS NULL;

DO $$
DECLARE holders text;
BEGIN
    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host = 'tapantabooks.dev.trovesuite.com' AND tenant_id IS NOT NULL) THEN
        RAISE EXCEPTION 'the Accounting address has been given to a tenant';
    END IF;
    SELECT string_agg(host, ', ' ORDER BY host) INTO holders
      FROM control_plane.ctl_tenant_routes
     WHERE route_kind = 'TENANT'
       AND control_plane.reserved_label(split_part(host, '.', 1)) = 'tapantabooks';
    IF holders IS NOT NULL THEN
        RAISE NOTICE 'tenant routes already holding the reserved label "tapantabooks" (kept): %', holders;
    END IF;
END $$;

COMMIT;
