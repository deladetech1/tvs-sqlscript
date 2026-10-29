-- Manufacturing: every column that holds a shared product (core_platform.cp_products) or a shared
-- party (core_platform.cp_parties), registered so the suite's merges re-point it and its
-- "in use" checks see it (docs/SHARED_PARTIES.md; 03-database-model.md §1, §8).
--
--   is_extension = true    Manufacturing's own settings for the product (item settings, unit
--                          conversions): moved by a merge, and not a use that stops the product
--                          being deleted
--   is_extension = false   everything else (revisions, BOMs and their lines, routings,
--                          instructions, orders and their components, floor requests, a
--                          subcontract supplier): a use
--
-- The partitioned tables (confirmations, downtime, genealogy) hold no product or party column.
-- Asserted below: every mfg column named product_id, component_id or *_party_id is registered,
-- so a later file that adds one must register it too. Idempotent; safe to re-run.

BEGIN;

INSERT INTO core_platform.cp_product_references (table_name, column_name, is_extension) VALUES
    ('mfg.mfg_item_settings',      'product_id',   true),
    ('mfg.mfg_uom_conversions',    'product_id',   true),
    ('mfg.mfg_item_revisions',     'product_id',   false),
    ('mfg.mfg_boms',               'product_id',   false),
    ('mfg.mfg_bom_lines',          'component_id', false),
    ('mfg.mfg_routings',           'product_id',   false),
    ('mfg.mfg_work_instructions',  'product_id',   false),
    ('mfg.mfg_production_orders',  'product_id',   false),
    ('mfg.mfg_order_components',   'component_id', false),
    ('mfg.mfg_floor_requests',     'product_id',   false)
ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;

INSERT INTO core_platform.cp_party_references (table_name, column_name, is_extension) VALUES
    ('mfg.mfg_operations',         'subcontract_party_id', false)
ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;

-- ===================================================================== invariants
DO $$
DECLARE missing text;
BEGIN
    SELECT string_agg(format('%s.%s', c.table_name, c.column_name), ', ' ORDER BY c.table_name) INTO missing
      FROM information_schema.columns c
      JOIN pg_class k ON k.oid = format('%I.%I', c.table_schema, c.table_name)::regclass
     WHERE c.table_schema = 'mfg' AND k.relkind IN ('r', 'p') AND NOT k.relispartition
       AND c.column_name IN ('product_id', 'component_id')
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

    -- Manufacturing's own settings move with a merged product; its documents are uses.
    IF EXISTS (SELECT 1 FROM core_platform.cp_product_references
                WHERE table_name LIKE 'mfg.%' AND is_extension
                  AND table_name NOT IN ('mfg.mfg_item_settings', 'mfg.mfg_uom_conversions')) THEN
        RAISE EXCEPTION 'a Manufacturing document table is registered as a product extension';
    END IF;
END $$;

COMMIT;
