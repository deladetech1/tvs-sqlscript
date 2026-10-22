-- The staging backend names come out of the route table (owner's cleanup, 2026-10-21):
--
--   cp.stage.backend.trovesuite.com, ld.stage.backend.trovesuite.com,
--   msg.stage.backend.trovesuite.com, zhr-admin.stage.backend.trovesuite.com
--
-- No staging environment is running and nothing serves these names. Earlier seeds put the
-- PLATFORM rows (cell uksouth-staging) into every database that has that cell, production
-- included, and re-insert them on every deploy; this file runs after them, so the later
-- file wins. Only unclaimed PLATFORM rows (tenant_id NULL) are touched.
--
-- Idempotent; safe to re-run.

BEGIN;

DELETE FROM control_plane.ctl_tenant_routes
 WHERE tenant_id IS NULL
   AND host IN ('cp.stage.backend.trovesuite.com', 'ld.stage.backend.trovesuite.com',
                'msg.stage.backend.trovesuite.com', 'zhr-admin.stage.backend.trovesuite.com');

COMMIT;
