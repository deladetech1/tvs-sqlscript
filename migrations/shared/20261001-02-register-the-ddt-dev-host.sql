-- =====================================================================
-- ddt.dev.trovesuite.com joins the route table
-- ---------------------------------------------------------------------
-- The first host added to control_plane since the table was created, and the
-- first that was not seeded from the addresses already in tvs-iac.
--
-- POOLED, with no tenant named, because that is what is true today: the host
-- is an Amplify custom domain in front of the dev deployment, and whatever it
-- reads, it reads from dev-db like every other dev address. There is no ddt
-- tenant in cp_tenants and no database of its own, and the constraints would
-- refuse a silo row that claimed otherwise -- ck_ctl_routes_silo_has_db wants a
-- database and ck_ctl_routes_nonpooled_has_tenant wants a tenant.
--
-- That is the honest row, not a placeholder. When ddt becomes the first silo
-- tenant -- which is what it looks like it is for, and an internal one is
-- exactly the right first -- this row is UPDATEd rather than replaced: tier
-- becomes SILO_SHARED, tenant_id and db_name and db_secret_uri are filled in,
-- and the host never changes. Nothing else has to know.
--
-- Being in this table does not yet make the host work. Two things gate that
-- and neither lives here:
--
--   CORS       cp.dev.backend.trovesuite.com refuses an OPTIONS carrying
--              Origin: https://ddt.dev.trovesuite.com with a 400 and no
--              access-control-allow-origin, because cors_origins in
--              platform/dev/env.hcl does not list it. Static assets come from
--              CloudFront and need no CORS, so the page renders and every API
--              call from it fails.
--
--   WebAuthn   webauthn_origins does not list it either, so a passkey ceremony
--              from this address is refused. The RP ID does not need changing:
--              dev.trovesuite.com is a registrable suffix of this host, so
--              credentials already enrolled keep working once the origin is
--              allowed.
--
-- Both are env vars set by terragrunt and applied by hand, which is the thing
-- a per-request CORS resolver and a per-request RP ID are meant to replace.
--
-- Idempotent; safe to re-run on every deploy.
-- =====================================================================

INSERT INTO control_plane.ctl_tenant_routes
    (host, tenant_id, tier, cell_key, status, cdate, ctime, cdatetime, created_by)
VALUES
    ('ddt.dev.trovesuite.com', NULL, 'POOLED', 'uksouth-dev', 'ACTIVE',
     CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'migration')
ON CONFLICT (host) DO NOTHING;
