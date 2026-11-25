-- =====================================================================================
-- Every shop's own address reaches the API: <shop>.qpickstore.com is a wildcard.
--
-- A storefront lives at <slug>.qpickstore.com (dev: <slug>.dev.qpickstore.com), and the
-- browser sends that as Origin. The tenancy gate resolves the Origin
-- (tenancy-gate-resolves-the-origin), and only the apexes had rows (20261002-02,
-- 20261020-02), so every shop answered "This address is not configured" and rendered
-- blank. Found on testapp.dev.qpickstore.com, 2026-11-25.
--
-- A wildcard is right here for the same reason it is for the employee portal
-- (20261001-04): every shop subdomain is, by design, the same answer. The shop is named
-- by the slug in the path (/storefront/{slug}/...), not by the route, and a slug that
-- names no shop is refused by the storefront itself, so a typo opens nothing. A shop
-- that later moves to its own database gets an exact TENANT row, and an exact row always
-- beats the wildcard.
--
-- The rows stay PLATFORM / POOLED / no tenant. Only where the row exists (dev:
-- dev.qpickstore.com, prod: qpickstore.com); a database without them skips quietly.
-- Idempotent; safe to re-run.
-- =====================================================================================

BEGIN;

UPDATE control_plane.ctl_tenant_routes
   SET is_wildcard = true,
       udatetime   = now(),
       updated_by  = 'migration 20261125-02'
 WHERE host IN ('dev.qpickstore.com', 'stage.qpickstore.com', 'qpickstore.com')
   AND is_wildcard IS DISTINCT FROM true;

-- Invariants: a shop-namespace wildcard is ours, pooled and pinned to nobody.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes
                WHERE host IN ('dev.qpickstore.com', 'stage.qpickstore.com', 'qpickstore.com')
                  AND (NOT is_wildcard OR route_kind <> 'PLATFORM' OR tier <> 'POOLED'
                       OR tenant_id IS NOT NULL OR silo_key IS NOT NULL)) THEN
        RAISE EXCEPTION 'a shop domain is not a pooled platform wildcard';
    END IF;
END $$;

COMMIT;
