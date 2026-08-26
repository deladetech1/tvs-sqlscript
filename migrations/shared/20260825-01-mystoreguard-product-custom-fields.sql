-- Custom fields: one "products" module, not one per place a product turns up.
--
-- "Store Items" and "Warehouse Items" were separate modules, so the same
-- question had to be defined three times and each copy collected its own
-- answers. A product custom field is now answered against the product itself,
-- and that answer follows the product into the store, the warehouse, a purchase
-- order and every line item that names it.
--
-- Definitions move their module entry to 'products'; answers already given move
-- with them, re-keyed from the store/warehouse row's id to the product it is
-- for. A product holds one answer per field, so where several rows answered the
-- same field for the same product — the same product stocked at two locations,
-- or in both a store and a warehouse — the newest answer is kept and the rest
-- are dropped. An answer the product already held wins over all of them: it is
-- the one the product screen was showing.
--
-- Idempotent: re-running finds nothing left on the retired module keys.

DO $$
DECLARE
    pair text[];
    stock_table text;
    retired_key text;
BEGIN
    IF to_regclass('mystoreguard.msg_custom_fields') IS NULL
       OR to_regclass('mystoreguard.msg_custom_field_values') IS NULL THEN
        RAISE NOTICE 'custom field tables not present yet; nothing to migrate';
        RETURN;
    END IF;

    FOREACH pair SLICE 1 IN ARRAY ARRAY[
        ARRAY['mystoreguard.msg_store_products', 'store_products'],
        ARRAY['mystoreguard.msg_warehouse_products', 'warehouse_items']
    ] LOOP
        stock_table := pair[1];
        retired_key := pair[2];
        CONTINUE WHEN to_regclass(stock_table) IS NULL;

        -- Drop every answer but the newest for each (field, product). Without
        -- this the re-key below would try to write two rows to one key.
        EXECUTE format($f$
            DELETE FROM mystoreguard.msg_custom_field_values v
            USING (
                SELECT a.id,
                       row_number() OVER (
                           PARTITION BY a.tenant_id, a.org_id, a.bus_id,
                                        a.field_id, s.product_id
                           ORDER BY COALESCE(a.udatetime, a.cdatetime) DESC
                                    NULLS LAST, a.id
                       ) AS rn
                FROM mystoreguard.msg_custom_field_values a
                JOIN %s s
                  ON s.id = a.record_id AND s.tenant_id = a.tenant_id
                 AND s.org_id = a.org_id AND s.bus_id = a.bus_id
                WHERE a.module = %L
            ) ranked
            WHERE v.id = ranked.id AND ranked.rn > 1
        $f$, stock_table, retired_key);

        EXECUTE format($f$
            UPDATE mystoreguard.msg_custom_field_values v
            SET module = 'products', record_id = s.product_id, udatetime = NOW()
            FROM %s s
            WHERE v.module = %L
              AND s.id = v.record_id
              AND s.tenant_id = v.tenant_id
              AND s.org_id = v.org_id
              AND s.bus_id = v.bus_id
              AND NOT EXISTS (
                  SELECT 1 FROM mystoreguard.msg_custom_field_values held
                  WHERE held.tenant_id = v.tenant_id
                    AND held.org_id = v.org_id
                    AND held.bus_id = v.bus_id
                    AND held.field_id = v.field_id
                    AND held.module = 'products'
                    AND held.record_id = s.product_id
              )
        $f$, stock_table, retired_key);
    END LOOP;

    -- Anything still on a retired key duplicates an answer the product already
    -- holds, or points at a stock row that no longer exists.
    DELETE FROM mystoreguard.msg_custom_field_values
    WHERE module IN ('store_products', 'warehouse_items');

    -- Point the definitions at 'products' and drop the retired keys. A field
    -- that named both store and warehouse collapses to a single entry.
    UPDATE mystoreguard.msg_custom_fields
    SET modules = (
            SELECT ARRAY(
                SELECT DISTINCT m
                FROM unnest(
                    array_replace(
                        array_replace(modules, 'store_products', 'products'),
                        'warehouse_items', 'products'
                    )
                ) AS m
                ORDER BY m
            )
        ),
        udatetime = NOW()
    WHERE modules && ARRAY['store_products', 'warehouse_items'];
END $$;
