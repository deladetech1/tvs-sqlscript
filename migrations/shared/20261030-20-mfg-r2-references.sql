-- Manufacturing Release 2: every new column that holds a shared product (core_platform.cp_products)
-- or a shared party (core_platform.cp_parties), registered so the suite's merges re-point it and its
-- "in use" checks see it (docs/SHARED_PARTIES.md; 03-database-model.md §1, §8). R1's are in
-- 20261029-47, whose invariant (every mfg product_id, component_id and *_party_id column is
-- registered) re-runs on every deploy and so covers these tables too.
--
--   is_extension = true    planning state derived per product (the net-change queue and the item
--                          plan state): moved by a merge (a clash on the merged key drops the
--                          dropped product's row, which the next re-net rebuilds), and not a use
--                          that stops the product being deleted
--   is_extension = false   everything else: demands, planned orders, pegging, MRP messages,
--                          inspection plans and inspections, holds, NCRs (and a line's regrade
--                          product), item costs and roll-up inputs, ECO items; a demand's
--                          customer, a planned buy's supplier, an NCR's supplier or customer
--
-- The views of 20261030-16 are not registered (they are SCM's columns). Idempotent; safe to re-run.

BEGIN;

INSERT INTO core_platform.cp_product_references (table_name, column_name, is_extension) VALUES
    ('mfg.mfg_mrp_dirty',               'product_id',          true),
    ('mfg.mfg_item_plan_state',         'product_id',          true),
    ('mfg.mfg_demands',                 'product_id',          false),
    ('mfg.mfg_planned_orders',          'product_id',          false),
    ('mfg.mfg_pegging',                 'product_id',          false),
    ('mfg.mfg_mrp_messages',            'product_id',          false),
    ('mfg.mfg_inspection_plans',        'product_id',          false),
    ('mfg.mfg_inspections',             'product_id',          false),
    ('mfg.mfg_holds',                   'product_id',          false),
    ('mfg.mfg_ncrs',                    'product_id',          false),
    ('mfg.mfg_ncr_lines',               'regrade_product_id',  false),
    ('mfg.mfg_recall_lots',             'product_id',          false),
    ('mfg.mfg_item_costs',              'product_id',          false),
    ('mfg.mfg_cost_rollup_lines',       'product_id',          false),
    ('mfg.mfg_cost_rollup_lines',       'component_id',        false),
    ('mfg.mfg_eco_items',               'product_id',          false)
ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;

INSERT INTO core_platform.cp_party_references (table_name, column_name, is_extension) VALUES
    ('mfg.mfg_demands',                 'party_id',            false),
    ('mfg.mfg_planned_orders',          'supplier_party_id',   false),
    ('mfg.mfg_ncrs',                    'party_id',            false)
ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;

-- ===================================================================== invariants
DO $$
DECLARE missing text;
BEGIN
    -- Every mfg column holding a product or party, by any name ending in product_id or party_id or
    -- named component_id, is registered (20261029-47 checks the exact names; this also catches
    -- regrade_product_id and the like).
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

    -- Only Manufacturing's own settings and derived planning state are extensions.
    IF EXISTS (SELECT 1 FROM core_platform.cp_product_references
                WHERE table_name LIKE 'mfg.%' AND is_extension
                  AND table_name NOT IN ('mfg.mfg_item_settings', 'mfg.mfg_uom_conversions',
                                         'mfg.mfg_mrp_dirty', 'mfg.mfg_item_plan_state')) THEN
        RAISE EXCEPTION 'a Manufacturing document table is registered as a product extension';
    END IF;
END $$;

COMMIT;
