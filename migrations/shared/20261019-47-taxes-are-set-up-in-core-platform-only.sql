-- =====================================================================
-- Taxes are set up in Core Platform only
-- ---------------------------------------------------------------------
-- 20261019-24 moved WHAT the taxes are into core_platform.cp_tax_rates and made
-- mystoreguard.msg_taxes a view of them, with an INSTEAD OF trigger so
-- MyStoreGuard's own tax screens could still create, edit and delete taxes
-- through the view. The owner decided (2026-10-19) that Core Platform is the
-- ONE place a tax is defined: MyStoreGuard keeps its tax RULES (which Core tax
-- applies to which product, category or location) and reads the taxes, but no
-- longer writes them. Its create/update/delete endpoints and screens are gone,
-- and so is the write path here:
--
--   * the trigger and its function are dropped, so the view is read-only and an
--     INSERT/UPDATE/DELETE on msg_taxes fails ("cannot insert into view").
--     20261019-24 re-creates them on every deploy (it re-runs), and this file,
--     sorting after it, drops them again: later migration wins.
--   * mystoreguard.msg_taxes_legacy (MyStoreGuard's old table, kept by -24) is
--     dropped. Every row was copied into cp_tax_rates under its own id by -24,
--     and the rules' foreign keys point at cp_tax_rates, so nothing can still
--     name a legacy-only row. Dev had 0 rows; the owner says nobody uses
--     MyStoreGuard's taxes yet. A legacy row whose id is NOT in Core (none
--     expected) is counted in a NOTICE and dropped with the table.
--
-- Re-runs every deploy: idempotent.
-- =====================================================================
BEGIN;

DO $$
DECLARE
    f record;
    missing integer;
BEGIN
    IF to_regclass('mystoreguard.msg_taxes') IS NOT NULL
       AND (SELECT relkind FROM pg_class WHERE oid = 'mystoreguard.msg_taxes'::regclass) = 'v' THEN
        DROP TRIGGER IF EXISTS msg_taxes_write ON mystoreguard.msg_taxes;
    END IF;
    -- Every overload, whatever shape this database holds.
    FOR f IN SELECT p.oid::regprocedure AS sig FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'mystoreguard' AND p.proname = 'msg_taxes_write' LOOP
        EXECUTE format('DROP FUNCTION IF EXISTS %s', f.sig);
    END LOOP;

    IF to_regclass('mystoreguard.msg_taxes_legacy') IS NOT NULL THEN
        EXECUTE 'SELECT count(*) FROM mystoreguard.msg_taxes_legacy t
                  WHERE NOT EXISTS (SELECT 1 FROM core_platform.cp_tax_rates r WHERE r.id = t.id)'
           INTO missing;
        IF missing > 0 THEN
            RAISE NOTICE 'Dropping % MyStoreGuard tax row(s) that never reached Core Platform (nothing references them)', missing;
        END IF;
        DROP TABLE mystoreguard.msg_taxes_legacy;
    END IF;
END $$;

COMMIT;
