-- The Accounting frontend gets its address, the way every app's frontend has one.
--
-- tvs-accounting-ft is served at accounting.dev.trovesuite.com, the <app>.dev.trovesuite.com
-- shape of CRM, Projects, Invoicing and Expenses (and of loandrift. and zeloshr-admin. before
-- them). Without a row the hub's wildcard answers "Address not configured", and Core
-- Platform refuses the frontend's calls, because it resolves the tenant from the Origin.
--
-- Only the address and its label. Accounting's cp_apps row stays as the CorePlatform seed
-- has it (coming_soon, inactive) until launch; its schema, permissions and roles are its
-- own module's (src/Trovesuite.Database.Accounting).
--
-- The label "accounting" is reserved like every product's: a tenant may no longer take a
-- subdomain with an "accounting" token (abc-accounting.dev.trovesuite.com). Existing
-- tenant routes are not touched -- the trigger refuses the next insert or rename only --
-- and any already holding the token are named below as a NOTICE.
--
-- Idempotent; safe to re-run.

BEGIN;

INSERT INTO control_plane.ctl_reserved_labels (label, reason, created_by)
SELECT v.label, v.reason, 'migration:20261019-28'
  FROM (VALUES ('accounting', 'a product: accounting.dev.trovesuite.com, the books')) AS v(label, reason)
 WHERE NOT EXISTS (SELECT 1 FROM control_plane.ctl_reserved_labels r WHERE r.label = v.label);

INSERT INTO control_plane.ctl_tenant_routes (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT h.host, NULL, 'POOLED', h.cell, 'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261019-28'
  FROM (VALUES ('accounting.dev.trovesuite.com', 'uksouth-dev')) AS h(host, cell)
 WHERE EXISTS (SELECT 1 FROM control_plane.ctl_cells c WHERE c.cell_key = h.cell)
ON CONFLICT (host) DO NOTHING;

DO $$
DECLARE holders text;
BEGIN
    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host = 'accounting.dev.trovesuite.com' AND tenant_id IS NOT NULL) THEN
        RAISE EXCEPTION 'the Accounting address has been given to a tenant';
    END IF;
    SELECT string_agg(host, ', ' ORDER BY host) INTO holders
      FROM control_plane.ctl_tenant_routes
     WHERE route_kind = 'TENANT'
       AND control_plane.reserved_label(split_part(host, '.', 1)) = 'accounting';
    IF holders IS NOT NULL THEN
        RAISE NOTICE 'tenant routes already holding the reserved label "accounting" (kept): %', holders;
    END IF;
END $$;

COMMIT;
