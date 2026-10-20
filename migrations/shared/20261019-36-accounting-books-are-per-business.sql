-- Accounting's books are per business (EF migration BooksPerBusiness, module 6): every
-- accounting.acc_* table carries bus_id NOT NULL, and every key that identified a record in an
-- organisation's books now identifies it in a business's.
--
-- 20261019-29 registers the audit trail with has_bus_id = false and re-runs on every deploy
-- before this file, so the truth about the column is written here (later migration wins).
--
-- Idempotent; safe to re-run. Shared files run on every deploy of every module, so the invariants
-- below only hold once the Accounting module's BooksPerBusiness migration has run in this database;
-- before that (no Accounting module here, or a deploy that did not select it) this file only notes it.

BEGIN;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'accounting' AND table_name = 'acc_audit_events' AND column_name = 'bus_id') THEN
        UPDATE core_platform.cp_activity_log_sources
           SET has_bus_id = true
         WHERE schema_name = 'accounting' AND table_name = 'acc_audit_events' AND NOT has_bus_id;
    END IF;
END $$;

-- ===================================================================== invariants
DO $$
DECLARE missing text;
BEGIN
    IF to_regclass('accounting."__EFMigrationsHistory"') IS NULL
       OR NOT EXISTS (SELECT 1 FROM accounting."__EFMigrationsHistory"
                       WHERE migration_id = '20261019053109_BooksPerBusiness') THEN
        RAISE NOTICE 'Accounting''s BooksPerBusiness migration has not run in this database; nothing to check';
        RETURN;
    END IF;

    -- Every Accounting table scoped to an organisation names the business too, and never blank. Tables only:
    -- a view's columns always read as nullable (acc_customers / acc_suppliers are views of cp_parties, 20261019-37).
    SELECT string_agg(c.table_name, ', ' ORDER BY c.table_name) INTO missing
      FROM information_schema.columns c
      JOIN information_schema.tables t ON t.table_schema = c.table_schema AND t.table_name = c.table_name AND t.table_type = 'BASE TABLE'
     WHERE c.table_schema = 'accounting' AND c.column_name = 'org_id' AND c.table_name LIKE 'acc\_%'
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns b
                        WHERE b.table_schema = c.table_schema AND b.table_name = c.table_name
                          AND b.column_name = 'bus_id' AND b.is_nullable = 'NO');
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'Accounting tables without a NOT NULL bus_id (the books are per business): %', missing;
    END IF;

    -- No unique key of the books identifies a record by organisation alone.
    SELECT string_agg(i.indexname, ', ' ORDER BY i.indexname) INTO missing
      FROM pg_indexes i
     WHERE i.schemaname = 'accounting' AND i.indexdef LIKE 'CREATE UNIQUE INDEX%'
       AND i.indexdef LIKE '%org_id%' AND i.indexdef NOT LIKE '%bus_id%';
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'Accounting unique keys scoped by organisation, not business: %', missing;
    END IF;

    IF to_regclass('accounting.acc_audit_events') IS NOT NULL
       AND EXISTS (SELECT 1 FROM core_platform.cp_activity_log_sources
                    WHERE schema_name = 'accounting' AND table_name = 'acc_audit_events' AND NOT has_bus_id) THEN
        RAISE EXCEPTION 'acc_audit_events has bus_id but is registered without it';
    END IF;
END $$;

COMMIT;
