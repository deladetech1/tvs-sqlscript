-- The old dev addresses nobody uses any more come out of the route table (owner's
-- cleanup, 2026-10-21). Dev moved to the standard names on 2026-10-20 (20261020-24):
--
--   frontends  <app>.dev.trovesuite.com
--   backends   api.<app>.dev.trovesuite.com
--
-- and these are the leftovers: old backend hostnames, the old website addresses of
-- MyStoreGuard, Loandrift, ZelosHR admin and Accounting, and two names nothing serves.
-- Their Azure hostnames, Amplify domains and DNS records are removed at the same time.
--
-- The delete runs in EVERY database, not only dev: earlier seeds put these PLATFORM rows
-- into any database that has the uksouth-dev cell, and production has that cell too, so
-- production carries them as well while serving none of them. Earlier migrations re-insert
-- some of them on every deploy; this file runs after them, so the later file wins.
--
-- Only PLATFORM rows (tenant_id NULL) are touched; a client's own row is never deleted.
--
-- The guard that every address still in use keeps its route runs only in dev-db, the one
-- database that serves those dev addresses. It must never stop a production deploy.
--
-- Idempotent; safe to re-run.

BEGIN;

DELETE FROM control_plane.ctl_tenant_routes r
 WHERE r.tenant_id IS NULL
   AND r.host IN ('api.dev.trovesuite.com', 'api.dev.mystoreguard.com', 'api.dev.loandrift.com',
                  'admin-api.dev.zeloshr.com', 'ld.dev.backend.trovesuite.com',
                  'zhr-admin.dev.backend.trovesuite.com', 'zhr-employee.backend.dev.trovesuite.com',
                  'admin.dev.zeloshr.com', 'zeloshr-admin.dev.trovesuite.com',
                  'tapantabooks.dev.trovesuite.com', 'dev.loandrift.com', 'dev.mystoreguard.com',
                  'msg.dev.mystoreguard.com', 'msg.app.dev.trovesuite.com');

DO $$
DECLARE missing text;
BEGIN
    IF current_database() <> 'dev-db' THEN RETURN; END IF;
    SELECT coalesce(string_agg(want.h, ', ' ORDER BY want.h), '') INTO missing
      FROM (VALUES ('dev.trovesuite.com'), ('cp.dev.backend.trovesuite.com'), ('msg.dev.backend.trovesuite.com'),
                   ('api.dev.zeloshr.com'), ('dev.zeloshr.com'), ('dev.qpickstore.com'),
                   ('api.coreplatform.dev.trovesuite.com'), ('api.mystoreguard.dev.trovesuite.com'),
                   ('api.loandrift.dev.trovesuite.com'), ('api.zeloshr.dev.trovesuite.com'),
                   ('api.accounting.dev.trovesuite.com'), ('accounting.dev.trovesuite.com'),
                   ('mystoreguard.dev.trovesuite.com'), ('loandrift.dev.trovesuite.com'),
                   ('zeloshr.dev.trovesuite.com')) AS want(h)
     WHERE NOT EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes r WHERE r.host = want.h);
    IF missing <> '' THEN
        RAISE EXCEPTION 'a dev address still in use has no route: %', missing;
    END IF;
END $$;

COMMIT;
