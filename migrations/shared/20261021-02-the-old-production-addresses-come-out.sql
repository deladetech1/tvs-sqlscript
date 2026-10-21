-- =====================================================================================
-- The old production addresses come out (2026-10-21).
--
-- Prod moved to api.<app>.trovesuite.com / <app>.trovesuite.com on 2026-10-20/21
-- (20261020-24). These prod-cell PLATFORM rows name addresses that no longer serve
-- anything we run:
--   tapantabooks.trovesuite.com   Accounting's old name; it is accounting.trovesuite.com now
--   zeloshr-admin.trovesuite.com  never resolved; ZelosHR's site is zeloshr.trovesuite.com
--   cp|ld|msg|zhr-admin.backend.trovesuite.com   API names that were never in DNS
--   api.trovesuite.com, api.mystoreguard.com, api.loandrift.com   never bound to an API
--   mystoreguard.com, www.mystoreguard.com, loandrift.com, www.loandrift.com
--                                 apexes with no record in prod; only dev.* is delegated
--
-- WHY A LATER MIGRATION: every shared file re-runs on every deploy, so 20261001-01,
-- 20261002-01, 20261002-05 and 20261019-49 re-insert these rows (ON CONFLICT DO NOTHING) and
-- this file deletes them again. Later wins. Rollback = revert this file; the next deploy's
-- seeds put every row back exactly as it was.
--
-- Reserved labels (control_plane.reserved_label) are NOT touched: "tapantabooks", "cp",
-- "msg", ... stay reserved, so no client can sign up as one of our old names.
-- Guarded like 20261005-04: only unclaimed platform rows. A row that has somehow become
-- a tenant's is spared.
-- =====================================================================================
BEGIN;

DELETE FROM control_plane.ctl_tenant_routes
 WHERE host IN (
        'tapantabooks.trovesuite.com',
        'zeloshr-admin.trovesuite.com',
        'cp.backend.trovesuite.com', 'ld.backend.trovesuite.com',
        'msg.backend.trovesuite.com', 'zhr-admin.backend.trovesuite.com',
        'api.trovesuite.com', 'api.mystoreguard.com', 'api.loandrift.com',
        'mystoreguard.com', 'www.mystoreguard.com',
        'loandrift.com', 'www.loandrift.com')
   AND route_kind = 'PLATFORM'
   AND tier = 'POOLED'
   AND tenant_id IS NULL
   AND silo_key IS NULL
   AND NOT is_wildcard;

-- ----------------------------------------------------------------------------- checks
-- Invariants, not counts (a later migration may add rows).
DO $$
DECLARE survivors text; missing text;
BEGIN
    SELECT COALESCE(string_agg(host, ', '), '') INTO survivors
      FROM control_plane.ctl_tenant_routes
     WHERE host IN ('tapantabooks.trovesuite.com', 'zeloshr-admin.trovesuite.com',
                    'cp.backend.trovesuite.com', 'ld.backend.trovesuite.com',
                    'msg.backend.trovesuite.com', 'zhr-admin.backend.trovesuite.com',
                    'api.trovesuite.com', 'api.mystoreguard.com', 'api.loandrift.com',
                    'mystoreguard.com', 'www.mystoreguard.com', 'loandrift.com', 'www.loandrift.com')
       AND tenant_id IS NULL AND silo_key IS NULL;
    IF survivors <> '' THEN
        RAISE EXCEPTION 'old production address(es) survived: %', survivors;
    END IF;

    -- The replacements must still be here, in every database that has prod rows.
    IF EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes WHERE cell_key = 'uksouth-prod') THEN
        SELECT COALESCE(string_agg(h, ', '), '') INTO missing
          FROM (VALUES ('trovesuite.com'), ('accounting.trovesuite.com'), ('zeloshr.trovesuite.com'),
                       ('api.coreplatform.trovesuite.com'), ('api.mystoreguard.trovesuite.com'),
                       ('api.zeloshr.trovesuite.com'), ('api.accounting.trovesuite.com'),
                       ('qpickstore.com'), ('zeloshr.com')) AS w(h)
         WHERE NOT EXISTS (SELECT 1 FROM control_plane.ctl_tenant_routes r
                            WHERE r.host = w.h AND r.status = 'ACTIVE');
        IF missing <> '' THEN
            RAISE EXCEPTION 'a current production address is missing: %', missing;
        END IF;
    END IF;
END $$;

COMMIT;
