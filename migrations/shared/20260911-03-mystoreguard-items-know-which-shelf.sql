-- An item knows which shelf it is standing on, not just which branch.
--
-- A location has no type. cp_locations is a place — "East Legon Accra" — and
-- the same place holds BOTH a store and a warehouse: msg_store_products and
-- msg_warehouse_products are each keyed by loc_id, and msg_batch_locations
-- carries a location_type to say which of the two a quantity is sitting on.
--
-- msg_product_units did not. An item had a loc_id and nothing else, so for a
-- branch whose store and warehouse share a location:
--
--   * transferring a tracked item from the store to the warehouse moved it
--     from loc_id X to loc_id X. Nothing changed. The quantity moved and the
--     item did not follow, because there was nowhere for it to follow to.
--
--   * asking "what is on this warehouse shelf" got the store's items as well,
--     since the only thing that could be filtered on was the branch.
--
-- The column is nullable on purpose. Null means "at this branch, shelf not
-- recorded" — which is every item taken in before this ran, and is the honest
-- answer rather than a guess. Reads treat null as matching either shelf, so
-- nothing that works today stops working.

ALTER TABLE mystoreguard.msg_product_units
    ADD COLUMN IF NOT EXISTS location_type text;

COMMENT ON COLUMN mystoreguard.msg_product_units.location_type IS
    'Which shelf at loc_id this item is on: STORE or WAREHOUSE. A branch has '
    'both, and they are different shelves. Null for an item recorded before '
    'this was tracked, and for an item not yet placed anywhere; reads treat '
    'null as matching either shelf.';

ALTER TABLE mystoreguard.msg_product_units
    DROP CONSTRAINT IF EXISTS ck_msg_product_units_location_type;
ALTER TABLE mystoreguard.msg_product_units
    ADD CONSTRAINT ck_msg_product_units_location_type
    CHECK (location_type IS NULL OR location_type IN ('STORE', 'WAREHOUSE'));

-- Where a delivery sits on exactly one kind of shelf at a branch, its items are
-- on that shelf — there is nowhere else they could be. Where a delivery
-- straddles both, nothing is guessed and the items keep their null.
UPDATE mystoreguard.msg_product_units u
   SET location_type = shelf.location_type
  FROM (
      SELECT bl.purchase_batche_id, bl.loc_id,
             MIN(bl.location_type) AS location_type
        FROM mystoreguard.msg_batch_locations bl
       WHERE bl.qty > 0
       GROUP BY bl.purchase_batche_id, bl.loc_id
      HAVING COUNT(DISTINCT bl.location_type) = 1
  ) shelf
 WHERE u.batch_id = shelf.purchase_batche_id
   AND u.loc_id = shelf.loc_id
   AND u.location_type IS NULL;

-- Asked on every till read: "the items on THIS shelf, at this branch".
CREATE INDEX IF NOT EXISTS ix_msg_product_units_shelf
    ON mystoreguard.msg_product_units (tenant_id, org_id, bus_id, product_id,
                                       loc_id, location_type);

-- ---------------------------------------------------------------------------
-- The invariant has to count the same way.
-- ---------------------------------------------------------------------------
-- msg_check_serialised_stock compares a delivery's shelf quantity against the
-- items standing on it, per branch. Now that a branch has two shelves, per
-- branch is the wrong grain: a delivery with three items in the store and two
-- in the warehouse would be compared as five against five and pass, whichever
-- shelf they were actually on.
--
-- Items whose shelf is not recorded are counted at the branch, so the check
-- stays true of everything taken in before the column existed.
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

    -- A tracked delivery: per branch AND per shelf, what the shelf claims
    -- against the items standing on it.
    SELECT * INTO v_drift FROM (
        WITH shelf AS (
            SELECT bl.loc_id, bl.location_type, SUM(bl.qty)::numeric AS on_shelf
              FROM mystoreguard.msg_batch_locations bl
             WHERE bl.purchase_batche_id = v_batch_id
             GROUP BY bl.loc_id, bl.location_type
        ), items AS (
            SELECT u.loc_id, u.location_type, COUNT(*)::numeric AS units
              FROM mystoreguard.msg_product_units u
             WHERE u.batch_id = v_batch_id
               -- RESERVED counts as present, and that is the crux: an item
               -- spoken for by an instalment sits in the shop for months and
               -- the shelf still includes it.
               AND u.status IN ('IN_STOCK', 'RETURNED', 'RESERVED')
               AND u.loc_id IS NOT NULL
             GROUP BY u.loc_id, u.location_type
        ), paired AS (
            -- Items whose shelf was never recorded answer for the branch as a
            -- whole, so stock taken in before this column existed is neither
            -- double-counted nor reported as drift.
            SELECT COALESCE(s.loc_id, i.loc_id) AS loc_id,
                   COALESCE(s.location_type, i.location_type) AS location_type,
                   COALESCE(s.on_shelf, 0) AS on_shelf,
                   COALESCE(i.units, 0)    AS units
              FROM shelf s
              FULL OUTER JOIN items i
                ON i.loc_id = s.loc_id
               AND (i.location_type = s.location_type OR i.location_type IS NULL)
        )
        SELECT loc_id, location_type,
               SUM(on_shelf) AS on_shelf, SUM(units) AS units
          FROM paired
         GROUP BY loc_id, location_type
        HAVING SUM(on_shelf) <> SUM(units)
         LIMIT 1
    ) drifted;

    IF FOUND THEN
        RAISE EXCEPTION
            'Stock and items disagree for delivery % at branch % (%): the shelf says % but % item(s) are recorded there. Whatever moved this stock has to move its items too — see ProductsService.move_units and allocate_units_to_location.',
            v_batch_id, COALESCE(v_drift.loc_id, '(unallocated)'),
            COALESCE(v_drift.location_type, 'shelf not recorded'),
            v_drift.on_shelf, v_drift.units
            USING ERRCODE = 'integrity_constraint_violation';
    END IF;

    RETURN NULL;
END;
$function$;
