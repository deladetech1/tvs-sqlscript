-- Whether stock is tracked one item at a time is a property of the DELIVERY,
-- not of the product.
--
-- A shop holds five sealed iPhone 12 Pro Max it counts, and five UK-used ones it
-- names by IMEI. Same product. Until now the product carried a single
-- tracking_type, so it had to be one or the other, and a shop with both was
-- forced into two catalogue rows for one phone.
--
-- Moving the flag to the batch makes the mixture expressible AND keeps the
-- guarantee exact — which is the part worth being careful about. The old check
-- compared, per product per branch, the shelf against the items standing on it.
-- Allowing a mixed product at that level would have meant weakening it to "items
-- never exceed the shelf", and a check that only catches one direction stops
-- catching a lost item row at all: the shelf simply looks like it holds one more
-- counted unit. That is the 112-against-113 drift, made invisible.
--
-- Scoped to the batch, nothing is given up:
--
--   a tracked delivery   must have exactly its shelf count in items, per branch;
--   a counted delivery   must have no items at all.
--
-- Both directions still fail loudly, and a product can now hold one of each.

ALTER TABLE mystoreguard.msg_purchase_batches
    ADD COLUMN IF NOT EXISTS tracks_items boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN mystoreguard.msg_purchase_batches.tracks_items IS
    'True when the units of this delivery are recorded one at a time, each with '
    'its own numbers. False when the delivery is a count. A product may hold '
    'both kinds of delivery; the check runs per delivery, not per product.';

-- Every delivery of a product that was serialised was, by definition, tracked.
UPDATE mystoreguard.msg_purchase_batches pb
   SET tracks_items = true
  FROM mystoreguard.msg_products p
 WHERE p.id = pb.product_id AND p.tenant_id = pb.tenant_id
   AND p.org_id = pb.org_id AND p.bus_id = pb.bus_id
   AND p.tracking_type = 'SERIALISED'
   AND pb.tracks_items = false;

-- Asked on every write to either table, so it wants an index.
CREATE INDEX IF NOT EXISTS ix_msg_purchase_batches_tracks_items
    ON mystoreguard.msg_purchase_batches (tenant_id, org_id, bus_id, product_id)
    WHERE tracks_items;


CREATE OR REPLACE FUNCTION mystoreguard.msg_check_serialised_stock()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
    v_batch_id   text;
    v_tracks     boolean;
    v_strays     integer;
    v_drift      record;
BEGIN
    -- Which delivery this row concerns, whichever table fired and whether the
    -- row was written or removed.
    IF TG_TABLE_NAME = 'msg_batch_locations' THEN
        v_batch_id := COALESCE(NEW.purchase_batche_id, OLD.purchase_batche_id);
    ELSE
        v_batch_id := COALESCE(NEW.batch_id, OLD.batch_id);
    END IF;

    IF v_batch_id IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT pb.tracks_items INTO v_tracks
      FROM mystoreguard.msg_purchase_batches pb
     WHERE pb.id = v_batch_id;

    -- A delivery that no longer exists takes its rows with it.
    IF v_tracks IS NULL THEN
        RETURN NULL;
    END IF;

    -- A counted delivery has no items, and an item on one is a contradiction:
    -- something recorded a handset against stock nobody is naming.
    IF NOT v_tracks THEN
        SELECT COUNT(*) INTO v_strays
          FROM mystoreguard.msg_product_units u
         WHERE u.batch_id = v_batch_id
           AND u.status IN ('IN_STOCK', 'RETURNED', 'RESERVED');

        IF v_strays > 0 THEN
            RAISE EXCEPTION
                'Delivery % is counted, so it cannot hold individually recorded items, but % were found. Either record every unit of this delivery, or record none.',
                v_batch_id, v_strays
                USING ERRCODE = 'integrity_constraint_violation';
        END IF;

        RETURN NULL;
    END IF;

    -- A tracked delivery: per branch, what its shelf claims against the items
    -- standing on it. FULL JOIN so a branch with items and no shelf row is
    -- caught as readily as a shelf row with no items.
    SELECT * INTO v_drift FROM (
        WITH shelf AS (
            SELECT bl.loc_id, SUM(bl.qty)::numeric AS on_shelf
              FROM mystoreguard.msg_batch_locations bl
             WHERE bl.purchase_batche_id = v_batch_id
             GROUP BY bl.loc_id
        ), items AS (
            SELECT u.loc_id, COUNT(*)::numeric AS units
              FROM mystoreguard.msg_product_units u
             WHERE u.batch_id = v_batch_id
               -- RESERVED counts as present, and that is the crux: an item
               -- spoken for by an instalment sits in the shop for months and
               -- the shelf still includes it. Counting only IN_STOCK would make
               -- every such sale look like drift and refuse it.
               AND u.status IN ('IN_STOCK', 'RETURNED', 'RESERVED')
               AND u.loc_id IS NOT NULL
             GROUP BY u.loc_id
        )
        SELECT COALESCE(s.loc_id, i.loc_id) AS loc_id,
               COALESCE(s.on_shelf, 0)      AS on_shelf,
               COALESCE(i.units, 0)         AS units
          FROM shelf s
          FULL OUTER JOIN items i ON i.loc_id = s.loc_id
         WHERE COALESCE(s.on_shelf, 0) <> COALESCE(i.units, 0)
         LIMIT 1
    ) drifted;

    IF FOUND THEN
        RAISE EXCEPTION
            'Stock and items disagree for delivery % at branch %: the shelf says % but % item(s) are recorded there. Whatever moved this stock has to move its items too — see ProductsService.move_units and allocate_units_to_location.',
            v_batch_id, COALESCE(v_drift.loc_id, '(unallocated)'),
            v_drift.on_shelf, v_drift.units
            USING ERRCODE = 'integrity_constraint_violation';
    END IF;

    RETURN NULL;
END;
$function$;

-- The triggers themselves are unchanged; recreated so applying this file alone
-- leaves a working invariant even where 20260907-01 has not run.
DROP TRIGGER IF EXISTS msg_batch_locations_serialised_check
    ON mystoreguard.msg_batch_locations;
CREATE CONSTRAINT TRIGGER msg_batch_locations_serialised_check
    AFTER INSERT OR UPDATE OR DELETE ON mystoreguard.msg_batch_locations
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION mystoreguard.msg_check_serialised_stock();

DROP TRIGGER IF EXISTS msg_product_units_serialised_check
    ON mystoreguard.msg_product_units;
CREATE CONSTRAINT TRIGGER msg_product_units_serialised_check
    AFTER INSERT OR UPDATE OR DELETE ON mystoreguard.msg_product_units
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION mystoreguard.msg_check_serialised_stock();
