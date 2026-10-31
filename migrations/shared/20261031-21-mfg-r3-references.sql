-- Manufacturing Release 3: every new column that holds a shared product (core_platform.cp_products)
-- or a shared party (core_platform.cp_parties), registered so the suite's merges re-point it and its
-- "in use" checks see it (docs/SHARED_PARTIES.md; 03-database-model.md §1, §8). R1's are in
-- 20261029-47 and R2's in 20261030-20; both invariants re-run on every deploy and so cover these
-- tables too.
--
--   is_extension = false   spare parts issued to a maintenance order, forecast lines, buy-order
--                          lines; a buy order's supplier. No R3 table is an extension: the applied
--                          20261029-47 allows only item settings and unit conversions
--   not registered         the OEE day cache keeps its product in item_id, deliberately
--                          (20261031-14), as R2's planning state does; asserted below. A PM plan's
--                          parts are JSON (no column to register); an import row's target and a
--                          sample record are ids by type (20261031-16)
--
-- Idempotent; safe to re-run.

BEGIN;

INSERT INTO core_platform.cp_product_references (table_name, column_name, is_extension) VALUES
    ('mfg.mfg_maintenance_parts',       'product_id',          false),
    ('mfg.mfg_forecast_lines',          'product_id',          false),
    ('mfg.mfg_buy_order_lines',         'product_id',          false)
ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;

INSERT INTO core_platform.cp_party_references (table_name, column_name, is_extension) VALUES
    ('mfg.mfg_buy_orders',              'supplier_party_id',   false)
ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;

-- ===================================================================== invariants
DO $$
DECLARE missing text;
BEGIN
    -- Every mfg column holding a product or party, by any name ending in product_id or party_id or
    -- named component_id, is registered (as 20261030-20, re-checked after the R3 tables exist).
    SELECT string_agg(format('%s.%s', c.table_name, c.column_name), ', ' ORDER BY c.table_name) INTO missing
      FROM information_schema.columns c
      JOIN pg_class k ON k.oid = format('%I.%I', c.table_schema, c.table_name)::regclass
     WHERE c.table_schema = 'mfg' AND k.relkind IN ('r', 'p') AND NOT k.relispartition
       AND (c.column_name LIKE '%product_id' OR c.column_name = 'component_id')
       AND NOT EXISTS (SELECT 1 FROM core_platform.cp_product_references r
                        WHERE r.table_name = 'mfg.' || c.table_name AND r.column_name = c.column_name);
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'Manufacturing product column(s) not in cp_product_references: %', missing;
    END IF;

    SELECT string_agg(format('%s.%s', c.table_name, c.column_name), ', ' ORDER BY c.table_name) INTO missing
      FROM information_schema.columns c
      JOIN pg_class k ON k.oid = format('%I.%I', c.table_schema, c.table_name)::regclass
     WHERE c.table_schema = 'mfg' AND k.relkind IN ('r', 'p') AND NOT k.relispartition
       AND c.column_name LIKE '%party_id'
       AND NOT EXISTS (SELECT 1 FROM core_platform.cp_party_references r
                        WHERE r.table_name = 'mfg.' || c.table_name AND r.column_name = c.column_name);
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'Manufacturing party column(s) not in cp_party_references: %', missing;
    END IF;

    IF EXISTS (SELECT 1 FROM core_platform.cp_product_references
                WHERE table_name LIKE 'mfg.%' AND is_extension
                  AND table_name NOT IN ('mfg.mfg_item_settings', 'mfg.mfg_uom_conversions')) THEN
        RAISE EXCEPTION 'a Manufacturing document table is registered as a product extension';
    END IF;
    -- The OEE cache stays unregistered and keeps no product_id column (20261031-14).
    IF EXISTS (SELECT 1 FROM core_platform.cp_product_references WHERE table_name = 'mfg.mfg_oee_days') THEN
        RAISE EXCEPTION 'mfg.mfg_oee_days is a cache keyed on its product; it must not be registered (20261031-14)';
    END IF;
END $$;

COMMIT;
