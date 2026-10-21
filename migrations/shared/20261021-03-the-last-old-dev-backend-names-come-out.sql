-- The last two old dev backend names come out (owner's cleanup, 2026-10-21):
--
--   cp.dev.backend.trovesuite.com   now api.coreplatform.dev.trovesuite.com
--   msg.dev.backend.trovesuite.com  now api.mystoreguard.dev.trovesuite.com
--
-- 20261021-01 kept them because servers still called them. Those callers have moved
-- (tvs-iac core_platform_api_url, the console, the ZelosHR employee backend default, the
-- dev QPickStore shop), and the hostnames, certificates and DNS records go at the same time.
--
-- Deleted in every database: earlier seeds (20261002-05 and others) put these PLATFORM rows
-- into any database with the uksouth-dev cell, production included, and re-insert them on
-- every deploy. This file runs after them, so the later file wins. Only unclaimed PLATFORM
-- rows (tenant_id NULL) are touched.
--
-- Idempotent; safe to re-run.

BEGIN;

DELETE FROM control_plane.ctl_tenant_routes
 WHERE tenant_id IS NULL
   AND host IN ('cp.dev.backend.trovesuite.com', 'msg.dev.backend.trovesuite.com');

COMMIT;
