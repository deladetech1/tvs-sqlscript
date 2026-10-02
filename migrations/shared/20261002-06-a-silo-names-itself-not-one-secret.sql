-- =====================================================================================
-- A silo row names the SILO; each app resolves its own credential from that.
--
-- The two silo rows were written when a silo had ONE credential, so they carried one
-- db_secret_uri and ck_ctl_routes_silo_has_db required it. Provisioning the silos for
-- real ended that: a silo has a login role PER APP, because sharing one credential
-- across five apps means one leak reaches all of them, and sharing it across tenants
-- is the thing a silo exists to prevent. There are now five db-url-<app>-<silo>
-- secrets per silo plus a read-only one for the tenant, and no single URI can stand
-- for them.
--
-- So the row says WHICH SILO and the app says WHO IT IS:
--
--     secret name = db-url-<app-slug>-<silo_key>
--
-- which is the pooled db-url-<app-slug> plus a suffix. The row still never carries a
-- credential, and now it does not even carry a secret's address -- it carries a name
-- that an app combines with its own identity. Key Vault RBAC decides the rest.
--
-- db_secret_uri is kept, not dropped: a silo whose apps DO share one credential is
-- still expressible, and SELF_MANAGED rows may want it. The constraint now accepts
-- either form, and refuses a silo that offers neither -- which is the case that would
-- quietly fall back to the pooled database.
--
-- The rows are also repointed at infrastructure that exists. They were written against
-- hand-made resources that have since been deleted and replaced by Terraform:
--
--   silo-shared-test        -> silo-shared-dev
--   tvs-dev-silotest-sql    -> tvs-dev-silo-dedicated-sql   (the old server is deleted)
--   tvsdevsilotestsa        -> tvsdevsilodedicatedsa        (deleted with its RG)
--   silosharedtest          -> shared                       (container prefix)
--   tvsdevmsgsa             -> NULL                         (storage is per app)
--   silo-*-test-db-url      -> NULL                         (both secrets deleted)
--
-- Leaving them would have pointed two tiers at a server that no longer resolves.
-- =====================================================================================

ALTER TABLE control_plane.ctl_tenant_routes
    ADD COLUMN IF NOT EXISTS silo_key text;

COMMENT ON COLUMN control_plane.ctl_tenant_routes.silo_key IS
    'Which silo this row addresses, as the IaC roster keys it (platform/<env>/silos/<key>). '
    'An app composes its own credential name as db-url-<app-slug>-<silo_key>, so the row '
    'never holds a secret or even a secret address. NULL for POOLED.';

-- Either form is acceptable; neither is not.
ALTER TABLE control_plane.ctl_tenant_routes
    DROP CONSTRAINT IF EXISTS ck_ctl_routes_silo_has_db;

ALTER TABLE control_plane.ctl_tenant_routes
    ADD CONSTRAINT ck_ctl_routes_silo_has_db CHECK (
        tier NOT IN ('SILO_SHARED', 'SILO_DEDICATED')
        OR (db_name IS NOT NULL
            AND (db_secret_uri IS NOT NULL OR silo_key IS NOT NULL))
    );

--
-- SUPERSEDED, 2026-10-02: the row updates this file made belonged to the kind-named test
-- tenants (`shared`, `dedicated`), which are retired. 20261002-09 registers the real
-- ones, itech and accesspoint, and deletes these hosts. Every migration re-runs on each
-- deploy, so leaving the INSERT here meant each deploy re-created rows pointing at a
-- database and a server that have been deleted, for 09 to remove again moments later.
-- The seeding is gone; the header stays as the record of why the columns exist.

-- The silo_key column and the constraint above are still the schema.
SELECT 1;
