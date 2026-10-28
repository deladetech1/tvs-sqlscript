-- 20261028-10-msg-audit-logs-loc-id.sql
-- MyStoreGuard audit logs get the BRANCH they happened at.
--
-- The 38 per-entity audit tables (and the sign-in history) were scoped to the
-- business only, so a branch's admin read every other branch's sales, stock
-- takes, transfers and settings changes (found by the 2026-10-28 isolation run).
--
-- 1. Every msg_*_audit_logs table gets a nullable loc_id and an index on
--    (tenant_id, bus_id, loc_id, cdatetime DESC). NULL means "business-wide":
--    products, customers, suppliers, gift cards, policies... stay visible to the
--    whole business, as their screens are.
-- 2. Rows of the BRANCH-SCOPED trails are backfilled from the audited record's own
--    location (the sale's loc_id, the transfer's source_loc_id, ...). The
--    snapshots cannot be used for this: the writer replaces loc_id in them with
--    the location's NAME. A snapshot value that is still a raw id ('loc_...') is
--    used as a fallback.
--
-- Idempotent and safe to re-run on every deploy: ADD COLUMN / CREATE INDEX IF
-- NOT EXISTS, and the backfill only touches rows whose loc_id is still NULL.
-- Every step checks that its tables and columns exist first, so a database
-- without MyStoreGuard (or without one of the audited modules) is skipped,
-- never failed. The backend reads the column only once it exists, so this can
-- land before or after the app.

DO $$
DECLARE
    t text;
BEGIN
    FOR t IN
        SELECT c.relname
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = 'mystoreguard'
           AND c.relkind = 'r'
           AND c.relname LIKE 'msg\_%\_audit\_logs'
    LOOP
        EXECUTE format('ALTER TABLE mystoreguard.%I ADD COLUMN IF NOT EXISTS loc_id text', t);
        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS %I ON mystoreguard.%I (tenant_id, bus_id, loc_id, cdatetime DESC)',
            'idx_' || t || '_loc', t);
    END LOOP;
END $$;

-- Backfill: (audit table, audited table, its location column).
DO $$
DECLARE
    m record;
    has_cols boolean;
BEGIN
    FOR m IN
        SELECT * FROM (VALUES
            ('msg_sale_audit_logs',               'mystoreguard',  'msg_sales',               'loc_id'),
            ('msg_store_return_audit_logs',       'mystoreguard',  'msg_returns',             'loc_id'),
            ('msg_store_product_audit_logs',      'mystoreguard',  'msg_store_products',      'loc_id'),
            ('msg_warehouse_product_audit_logs',  'mystoreguard',  'msg_warehouse_products',  'loc_id'),
            ('msg_store_transfer_audit_logs',     'mystoreguard',  'msg_product_transfers',   'source_loc_id'),
            ('msg_warehouse_transfer_audit_logs', 'mystoreguard',  'msg_product_transfers',   'source_loc_id'),
            ('msg_stock_take_audit_logs',         'mystoreguard',  'msg_stock_takes',         'loc_id'),
            ('msg_store_config_audit_logs',       'mystoreguard',  'msg_store_configs',       'loc_id'),
            ('msg_warehouse_config_audit_logs',   'mystoreguard',  'msg_warehouse_configs',   'loc_id'),
            ('msg_delivery_audit_logs',           'mystoreguard',  'msg_deliveries',          'loc_id'),
            ('msg_invoice_audit_logs',            'mystoreguard',  'msg_invoices',            'loc_id'),
            ('msg_appointment_audit_logs',        'mystoreguard',  'msg_appointments',        'loc_id'),
            ('msg_installment_plan_audit_logs',   'mystoreguard',  'msg_installment_plans',   'loc_id'),
            ('msg_product_split_audit_logs',      'mystoreguard',  'msg_product_splits',      'loc_id'),
            ('msg_expense_audit_logs',            'core_platform', 'cp_expense',              'loc_id')
        ) AS v(audit_table, src_schema, src_table, src_col)
    LOOP
        SELECT count(*) = 3 INTO has_cols FROM (
            SELECT 1 FROM information_schema.columns
             WHERE table_schema = 'mystoreguard' AND table_name = m.audit_table AND column_name = 'loc_id'
            UNION ALL
            SELECT 1 FROM information_schema.columns
             WHERE table_schema = m.src_schema AND table_name = m.src_table AND column_name = 'id'
            UNION ALL
            SELECT 1 FROM information_schema.columns
             WHERE table_schema = m.src_schema AND table_name = m.src_table AND column_name = m.src_col
        ) present;
        IF NOT has_cols THEN
            RAISE NOTICE 'audit loc_id backfill: skipping % (it, or its source %.%.%, is not present)',
                m.audit_table, m.src_schema, m.src_table, m.src_col;
            CONTINUE;
        END IF;

        EXECUTE format(
            'UPDATE mystoreguard.%I a
                SET loc_id = s.%I
               FROM %I.%I s
              WHERE a.loc_id IS NULL
                AND s.id = a.entity_id
                AND s.tenant_id = a.tenant_id
                AND s.%I IS NOT NULL',
            m.audit_table, m.src_col, m.src_schema, m.src_table, m.src_col);

        -- The audited record may be gone (hard-deleted); a snapshot that still
        -- holds the raw location id says where it was.
        EXECUTE format(
            'UPDATE mystoreguard.%I a
                SET loc_id = COALESCE(
                        CASE WHEN a.new_data->>%L LIKE ''loc\_%%'' THEN a.new_data->>%L END,
                        CASE WHEN a.old_data->>%L LIKE ''loc\_%%'' THEN a.old_data->>%L END,
                        CASE WHEN a.new_data->>''loc_id'' LIKE ''loc\_%%'' THEN a.new_data->>''loc_id'' END,
                        CASE WHEN a.old_data->>''loc_id'' LIKE ''loc\_%%'' THEN a.old_data->>''loc_id'' END)
              WHERE a.loc_id IS NULL
                AND (a.new_data IS NOT NULL OR a.old_data IS NOT NULL)',
            m.audit_table, m.src_col, m.src_col, m.src_col, m.src_col);
    END LOOP;
END $$;

-- Invariant: every audit table has the column and its index.
DO $$
DECLARE
    missing text;
BEGIN
    SELECT string_agg(c.relname, ', ') INTO missing
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'mystoreguard' AND c.relkind = 'r'
       AND c.relname LIKE 'msg\_%\_audit\_logs'
       AND (NOT EXISTS (SELECT 1 FROM information_schema.columns ic
                         WHERE ic.table_schema = 'mystoreguard' AND ic.table_name = c.relname
                           AND ic.column_name = 'loc_id')
            OR NOT EXISTS (SELECT 1 FROM pg_indexes pi
                            WHERE pi.schemaname = 'mystoreguard' AND pi.tablename = c.relname
                              AND pi.indexname = 'idx_' || c.relname || '_loc'));
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'audit logs without loc_id or its index: %', missing;
    END IF;
END $$;
