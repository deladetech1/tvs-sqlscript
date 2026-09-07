-- Make the shelf and the items agree, or refuse the transaction.
--
-- A serialised product is counted twice over: once as a quantity on the shelf
-- (msg_batch_locations) and once as a set of physical items (msg_product_units).
-- Every path that moves stock has to move both, and the ones that did not moved
-- the quantity and left the handsets behind — sellable at a branch that no
-- longer had them, invisible at the one that did.
--
-- That had already been fixed twice, in transfers and then in allocation, and an
-- audit afterwards found nine more paths with no unit handling at all: updating
-- and deleting an invoice, updating and cancelling a sale, adjusting stock down
-- at a store or a warehouse, reversing a split, failing a stock take, and the
-- deferred deduction on a payment. Fixing nine is how the tenth gets missed.
--
-- So the rule lives here instead. It is a CONSTRAINT TRIGGER, DEFERRABLE
-- INITIALLY DEFERRED, which matters: a transaction is free to move the quantity
-- on one line and the items on the next, and is judged only at COMMIT, on the
-- state it actually leaves behind. What it cannot do is commit a disagreement.
--
-- Counted stock — which is nearly everything — never reaches the check.
--
-- The consequence is deliberate and worth stating plainly: a path that moves a
-- serialised product's stock without moving its items now FAILS. It does not
-- warn. A shop that cannot cancel a sale is a problem somebody notices and
-- reports in an afternoon; a shelf that quietly disagrees with the handsets on
-- it is a problem nobody notices until a customer is told their phone does not
-- exist.

CREATE OR REPLACE FUNCTION mystoreguard.msg_check_serialised_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_product_id text;
    v_tenant_id  text;
    v_org_id     text;
    v_bus_id     text;
    v_drift      record;
BEGIN
    -- Which product this row concerns, whichever table fired the trigger and
    -- whether the row was written or removed.
    IF TG_TABLE_NAME = 'msg_batch_locations' THEN
        SELECT pb.product_id, pb.tenant_id, pb.org_id, pb.bus_id
          INTO v_product_id, v_tenant_id, v_org_id, v_bus_id
          FROM mystoreguard.msg_purchase_batches pb
         WHERE pb.id = COALESCE(NEW.purchase_batche_id, OLD.purchase_batche_id);
    ELSE
        v_product_id := COALESCE(NEW.product_id, OLD.product_id);
        v_tenant_id  := COALESCE(NEW.tenant_id,  OLD.tenant_id);
        v_org_id     := COALESCE(NEW.org_id,     OLD.org_id);
        v_bus_id     := COALESCE(NEW.bus_id,     OLD.bus_id);
    END IF;

    IF v_product_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- Counted stock has no items to disagree with.
    IF NOT EXISTS (
        SELECT 1 FROM mystoreguard.msg_products
         WHERE id = v_product_id AND tenant_id = v_tenant_id
           AND org_id = v_org_id AND bus_id = v_bus_id
           AND tracking_type = 'SERIALISED'
    ) THEN
        RETURN NULL;
    END IF;

    -- Per branch: what the shelf claims, against the items standing on it.
    -- FULL JOIN so a branch with items and no shelf row is caught as readily as
    -- a branch with a shelf row and no items.
    SELECT * INTO v_drift FROM (
        WITH shelf AS (
            SELECT bl.loc_id, SUM(bl.qty)::numeric AS on_shelf
              FROM mystoreguard.msg_batch_locations bl
              JOIN mystoreguard.msg_purchase_batches pb
                ON pb.id = bl.purchase_batche_id
             WHERE pb.product_id = v_product_id AND pb.tenant_id = v_tenant_id
               AND pb.org_id = v_org_id AND pb.bus_id = v_bus_id
             GROUP BY bl.loc_id
        ), items AS (
            SELECT u.loc_id, COUNT(*)::numeric AS units
              FROM mystoreguard.msg_product_units u
             WHERE u.product_id = v_product_id AND u.tenant_id = v_tenant_id
               AND u.org_id = v_org_id AND u.bus_id = v_bus_id
               AND u.status IN ('IN_STOCK', 'RETURNED')
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
            'Stock and items disagree for product % at branch %: the shelf says % but % item(s) are recorded there. Whatever moved this stock has to move its items too — see ProductsService.move_units and allocate_units_to_location.',
            v_product_id, COALESCE(v_drift.loc_id, '(unallocated)'),
            v_drift.on_shelf, v_drift.units
            USING ERRCODE = 'integrity_constraint_violation';
    END IF;

    RETURN NULL;
END;
$$;

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
