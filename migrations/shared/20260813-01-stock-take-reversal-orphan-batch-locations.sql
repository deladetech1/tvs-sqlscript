-- =====================================================================
-- Repair: stock left behind by a stock-take reversal with no delivery
-- ---------------------------------------------------------------------
-- Reversing a written-off shortage works out how much to put back per
-- delivery by netting the original movements grouped by batch_id. Older
-- corrections were logged without one, so the restore ran against
-- purchase_batche_id = NULL, matched no row, and fell back to INSERTing a
-- msg_batch_locations row carrying a NULL batch — while the location's
-- current_qty was raised regardless.
--
-- That leaves stock belonging to no product. Product-level views reach the
-- ledger by joining through msg_purchase_batches, so the row is invisible
-- there and the location correctly reads 0, while current_qty — the figure
-- a new stock take snapshots as system_qty — reads high by that amount.
-- Every fresh take then reports a variance that isn't real.
--
-- This removes each such row and takes the same quantity back off the
-- location total it inflated. The owning product is recovered from the
-- STOCK_TAKE_ADJUSTMENT_REVERSAL movement written in the same transaction,
-- which carries the row's exact cdatetime.
--
-- Any DRAFT take that snapshotted the inflated figure afterwards is
-- re-snapshotted, since the edit screen reuses a line's original snapshot
-- and cannot refresh it. Lines that already booked a correction, and takes
-- that are COMPLETED, are left untouched — those are history.
--
-- The service now refuses to reverse an unattributed correction, so no new
-- rows of this shape are produced. Idempotent: once cleared, nothing
-- matches and re-running is a no-op.
-- =====================================================================

DO $$
DECLARE
    orphan       RECORD;
    owner_id     text;
    qty_table    text;
    old_qty      integer;
    new_qty      integer;
    lines_fixed  integer;
    total_rows   integer := 0;
    total_units  integer := 0;
BEGIN
    FOR orphan IN
        SELECT id, tenant_id, org_id, bus_id, loc_id, location_type, qty, cdatetime
        FROM mystoreguard.msg_batch_locations
        WHERE purchase_batche_id IS NULL
        ORDER BY cdatetime
    LOOP
        -- The reversal logged an IN movement in the same transaction as the row
        -- it created, so they share a timestamp. That movement knows the product.
        SELECT pm.product_id INTO owner_id
        FROM mystoreguard.msg_product_movements pm
        WHERE pm.tenant_id = orphan.tenant_id
          AND pm.org_id = orphan.org_id
          AND pm.bus_id = orphan.bus_id
          AND pm.reason = 'STOCK_TAKE_ADJUSTMENT_REVERSAL'
          AND pm.movement_type = 'IN'
          AND pm.location_type = orphan.location_type
          AND pm.location_id = orphan.loc_id
          AND pm.qty = orphan.qty
          AND pm.cdatetime BETWEEN orphan.cdatetime - interval '1 second'
                               AND orphan.cdatetime + interval '1 second'
        ORDER BY pm.cdatetime
        LIMIT 1;

        IF owner_id IS NULL THEN
            -- Still drop the row (stock under no batch is meaningless), but the
            -- inflated total can't be attributed, so flag it for a human.
            RAISE WARNING 'Orphan batch_location % (qty %, loc %) has no matching '
                          'reversal movement; deleting the row but current_qty could '
                          'not be corrected.', orphan.id, orphan.qty, orphan.loc_id;
        ELSE
            qty_table := CASE WHEN orphan.location_type = 'WAREHOUSE'
                              THEN 'mystoreguard.msg_warehouse_products'
                              ELSE 'mystoreguard.msg_store_products' END;

            EXECUTE format(
                'SELECT current_qty FROM %s
                 WHERE tenant_id = $1 AND org_id = $2 AND bus_id = $3
                   AND loc_id = $4 AND product_id = $5
                   AND delete_status = ''NOT_DELETED''', qty_table)
            INTO old_qty
            USING orphan.tenant_id, orphan.org_id, orphan.bus_id,
                  orphan.loc_id, owner_id;

            IF old_qty IS NOT NULL THEN
                new_qty := GREATEST(old_qty - orphan.qty, 0);

                EXECUTE format(
                    'UPDATE %s SET current_qty = $1
                     WHERE tenant_id = $2 AND org_id = $3 AND bus_id = $4
                       AND loc_id = $5 AND product_id = $6
                       AND delete_status = ''NOT_DELETED''', qty_table)
                USING new_qty, orphan.tenant_id, orphan.org_id, orphan.bus_id,
                      orphan.loc_id, owner_id;

                -- Re-snapshot open drafts that captured the inflated figure.
                UPDATE mystoreguard.msg_stock_take_items sti
                SET system_qty   = new_qty,
                    variance_qty = sti.counted_qty - new_qty,
                    match_status = CASE
                        WHEN sti.counted_qty - new_qty = 0 THEN 'MATCH'
                        WHEN sti.counted_qty - new_qty > 0 THEN 'OVER'
                        ELSE 'SHORT' END
                FROM mystoreguard.msg_stock_takes st
                WHERE st.id = sti.stock_take_id
                  AND st.tenant_id = sti.tenant_id AND st.org_id = sti.org_id
                  AND st.bus_id = sti.bus_id
                  AND st.delete_status = 'NOT_DELETED'
                  AND st.status = 'DRAFT'
                  AND st.loc_id = orphan.loc_id
                  AND st.location_type = orphan.location_type
                  AND st.cdatetime > orphan.cdatetime
                  AND sti.product_id = owner_id
                  AND sti.system_qty = old_qty
                  AND COALESCE(sti.adjustment_qty, 0) = 0
                  AND sti.resolution_status <> 'RESOLVED';

                GET DIAGNOSTICS lines_fixed = ROW_COUNT;
                RAISE NOTICE 'Product % at %: current_qty % -> %, % draft line(s) '
                             're-snapshotted.', owner_id, orphan.loc_id,
                             old_qty, new_qty, lines_fixed;
            END IF;
        END IF;

        DELETE FROM mystoreguard.msg_batch_locations WHERE id = orphan.id;
        total_rows  := total_rows + 1;
        total_units := total_units + orphan.qty;
    END LOOP;

    IF total_rows > 0 THEN
        RAISE NOTICE 'Cleared % orphan batch_location row(s) holding % unit(s).',
                     total_rows, total_units;
    END IF;
END $$;
