-- Manufacturing: the indexes behind GET /mfg/v1/search (contract R3.md D20), on Manufacturing's own
-- tables only. Search reads the tables live (no mfg_search_index yet):
--
--   a number      prefix match on lower(number): lower(number) LIKE 'mo-%' plus the significant
--                 digits, so each number gets a (bus_id, lower(number) text_pattern_ops) index
--                 (text_pattern_ops makes LIKE 'prefix%' use it whatever the collation)
--   a name        contains, case-insensitive: lower(name) / lower(title), indexed per business so
--                 the equality and prefix cases are fast; a contains scan stays within one business
--
--   production orders   number              NCRs                number, title
--   documents           title               assets              code, name
--   maintenance orders  number, title       buy orders          number
--
-- Items and lots are not here: an item's name is Core's (cp_products) and a lot is the shared
-- ledger's (D26: R3 adds nothing on SCM tables). Idempotent; safe to re-run.

BEGIN;

CREATE INDEX IF NOT EXISTS mfg_production_orders_search_number_idx
    ON mfg.mfg_production_orders (bus_id, lower(number) text_pattern_ops);

CREATE INDEX IF NOT EXISTS mfg_ncrs_search_number_idx ON mfg.mfg_ncrs (bus_id, lower(number) text_pattern_ops);
CREATE INDEX IF NOT EXISTS mfg_ncrs_search_title_idx ON mfg.mfg_ncrs (bus_id, lower(title));

CREATE INDEX IF NOT EXISTS mfg_documents_search_title_idx
    ON mfg.mfg_documents (bus_id, lower(title)) WHERE archived_at IS NULL;

CREATE INDEX IF NOT EXISTS mfg_assets_search_code_idx ON mfg.mfg_assets (bus_id, lower(code) text_pattern_ops);
CREATE INDEX IF NOT EXISTS mfg_assets_search_name_idx ON mfg.mfg_assets (bus_id, lower(name));

CREATE INDEX IF NOT EXISTS mfg_maintenance_orders_search_number_idx
    ON mfg.mfg_maintenance_orders (bus_id, lower(number) text_pattern_ops);
CREATE INDEX IF NOT EXISTS mfg_maintenance_orders_search_title_idx
    ON mfg.mfg_maintenance_orders (bus_id, lower(title));

CREATE INDEX IF NOT EXISTS mfg_buy_orders_search_number_idx
    ON mfg.mfg_buy_orders (bus_id, lower(number) text_pattern_ops);

-- ===================================================================== invariants
DO $$
DECLARE i text;
BEGIN
    FOREACH i IN ARRAY ARRAY['mfg_production_orders_search_number_idx', 'mfg_ncrs_search_number_idx',
                             'mfg_assets_search_code_idx', 'mfg_maintenance_orders_search_number_idx',
                             'mfg_buy_orders_search_number_idx'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'mfg' AND indexname = i) THEN
            RAISE EXCEPTION 'search index mfg.% is missing', i;
        END IF;
    END LOOP;
END $$;

COMMIT;
