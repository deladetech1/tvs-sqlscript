-- MyStoreGuard <-> Supply Chain (SCM), phase 5: SCM's stock in the books, and one view of stock
-- everywhere (apps-setup/msg-scm-integration-plan.md §4 phase 5; phases 2-3 in 20261102-50/-60).
--
-- 1. SCM POSTS ITS STOCK TO ACCOUNTING (docs/POSTINGS.md §11), on the scm-accounting link (Core
--    Platform catalogue; the RECEIVER, Accounting's PostingRun, checks it and fails closed; every
--    business starts OFF). As MyStoreGuard does (20261019-38/-39), the database publishes: a
--    DEFERRABLE constraint trigger on scm.scm_inventory_movements runs at COMMIT and publishes ONE
--    event per document per transaction (every movement of the same reference_type/reference_id
--    not yet published), so whatever writes the ledger -- SCM's handlers, a later phase's documents
--    -- is covered without Go changes. scm.scm_acc_moves records which movements an event carried,
--    so nothing is published twice. Accounting posts one journal per event (evt:<id>).
--
--    reference_type          event                              Accounting (ScmPostingRules)
--    receipt                 scm.goods_received                 Dr Inventory / Cr Goods received not invoiced
--    return                  scm.return_posted                  customer (+): Dr Inventory / Cr Cost of sales;
--                                                               to supplier (-): Dr GRNI / Cr Inventory
--    shipment                scm.goods_shipped                  Dr Cost of sales / Cr Inventory
--    adjustment, stock_count scm.stock_adjusted                 +/- against Stock adjustments, or Stock written
--                                                               off when the reason says damaged/expired/scrap...
--    branch_shipment         scm.branch_shipment_dispatched     Dr Stock transfers clearing (1250) / Cr Inventory,
--                                                               at the cost SENT TO MyStoreGuard (the shipment's
--                                                               parts, base currency) so it nets with MSG's confirm
--    branch_* / msg_*        scm.branch_stock_received          Dr Inventory / Cr Stock transfers clearing (the
--                            (stock back from a branch;         mirror: MyStoreGuard posts Cr Inventory / Dr 1250)
--                            phase 4 names its reference so)
--    anything else           scm.stock_posted                   by each line's movement kind (issue -> Stock used,
--                                                               scrap -> written off, ...)
--    transfer, mfg_*         nothing: a transfer between SCM warehouses stays in Inventory; Manufacturing's own
--                            documents are Manufacturing's to post
--
--    A branch shipment MyStoreGuard answers received or short publishes scm.branch_shipment_short
--    (once per shipment, on scm.scm_branch_shipments, also deferred): per part, what was sent less
--    what MyStoreGuard took in, each rounded as MyStoreGuard rounds its own posting, so
--    Dr Stock lost in transit / Cr 1250 leaves the clearing account at exactly zero. A rejected
--    shipment posts nothing: its stock stays in the clearing account and SCM's reconciliation
--    report lists it until it is dealt with.
--
--    Lines are per product and currency: a lot's cost in the lot's own currency (Accounting
--    converts at the books' rate, as for MyStoreGuard's batches); a branch shipment's in the
--    shipment's currency (the business's base, converted at dispatch at the Core Platform rate).
--    An event that cannot be built is published as scm.posting_error with the reason; SCM's own
--    work never fails because of the books.
--
-- 2. ONE VIEW OF STOCK (read-only, each side through the other's published function, never its
--    tables or code):
--      mystoreguard.msg_stock_for_scm(tenant, bus)  MyStoreGuard's branch stock per product, place
--                                                   and side, with its value per batch currency
--      scm.scm_stock_for_msg(tenant, bus)           SCM's warehouse stock, what is in transit to each
--                                                   branch, what is on order for it, and which warehouse
--                                                   supplies which branch
--    The callers gate them: both subscriptions and the scm-mystoreguard link on.
--
-- Existing movements and answered shipments are the baseline (nothing before this migration is
-- published), recorded once: on the run that creates the triggers. Idempotent; safe to re-run.

BEGIN;

-- ===================================================================== MyStoreGuard's side
-- What each branch holds, per product, place and side (msg_batch_locations is the truth per batch;
-- a batch's unplaced pool is not at a place and is left out), valued at each batch's cost in the
-- batch's currency. A product is MyStoreGuard's (an SCM variant arrives as its parent).
CREATE OR REPLACE FUNCTION mystoreguard.msg_stock_for_scm(p_tenant text, p_bus text)
RETURNS TABLE (product_id text, loc_id text, loc_name text, side text, qty bigint, value numeric, currency text)
LANGUAGE sql STABLE AS $f$
    SELECT b.product_id, bl.loc_id, max(l.loc_name),
           CASE WHEN upper(coalesce(bl.location_type, 'STORE')) = 'WAREHOUSE' THEN 'WAREHOUSE' ELSE 'STORE' END,
           sum(bl.qty)::bigint,
           round(sum(bl.qty * coalesce(b.cost_price, 0)), 2),
           coalesce((SELECT upper(c.code) FROM core_platform.cp_currencies c WHERE c.tenant_id = p_tenant AND c.id = b.currency_id LIMIT 1),
                    (SELECT upper(c.code) FROM core_platform.cp_currencies c
                      WHERE c.tenant_id = p_tenant AND c.is_default AND coalesce(c.delete_status, 'NOT_DELETED') = 'NOT_DELETED'
                      ORDER BY c.cdatetime DESC NULLS LAST LIMIT 1), '')
      FROM mystoreguard.msg_batch_locations bl
      JOIN mystoreguard.msg_purchase_batches b ON b.tenant_id = bl.tenant_id AND b.id = bl.purchase_batche_id
      LEFT JOIN core_platform.cp_locations l ON l.tenant_id = bl.tenant_id AND l.id = bl.loc_id
     WHERE bl.tenant_id = p_tenant AND bl.bus_id = p_bus AND bl.qty <> 0
       AND coalesce(b.delete_status, 'NOT_DELETED') <> 'DELETED'
     GROUP BY b.product_id, bl.loc_id, 4, b.currency_id
$f$;
COMMENT ON FUNCTION mystoreguard.msg_stock_for_scm(text, text) IS
    'MSG-SCM phase 5: MyStoreGuard''s branch stock for SCM''s combined view (20261102-85). SCM calls this, never the tables.';

-- ===================================================================== SCM
DO $do$
DECLARE first_run boolean;
BEGIN
    IF to_regclass('scm.scm_inventory_movements') IS NULL OR to_regclass('scm.scm_branch_shipments') IS NULL THEN
        RAISE NOTICE 'msg-scm phase 5: no SCM schema (or not at phase 3) here: its postings come with it';
        RETURN;
    END IF;
    first_run := NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'scm_acc_movement'
                               AND tgrelid = 'scm.scm_inventory_movements'::regclass);

    -- Which movements an event carried (event_id NULL: the baseline, or a kind that posts nothing).
    CREATE TABLE IF NOT EXISTS scm.scm_acc_moves (
        movement_id text PRIMARY KEY,
        tenant_id   text NOT NULL,
        bus_id      text NOT NULL,
        event_id    bigint,
        cdatetime   timestamptz NOT NULL DEFAULT now()
    );
    -- A branch shipment's shortage, published once.
    CREATE TABLE IF NOT EXISTS scm.scm_acc_shipments (
        shipment_id text PRIMARY KEY,
        tenant_id   text NOT NULL,
        bus_id      text NOT NULL,
        event_id    bigint,
        cdatetime   timestamptz NOT NULL DEFAULT now()
    );

    EXECUTE $sql$
    CREATE OR REPLACE FUNCTION scm.scm_acc_day(p_tenant text, p_at timestamptz) RETURNS date
    LANGUAGE plpgsql STABLE AS $f$
    DECLARE z text;
    BEGIN
        IF to_regclass('core_platform.cp_timezone_settings') IS NOT NULL THEN
            SELECT timezone INTO z FROM core_platform.cp_timezone_settings
             WHERE tenant_id = p_tenant AND is_active ORDER BY cdatetime DESC NULLS LAST LIMIT 1;
        END IF;
        BEGIN
            RETURN (coalesce(p_at, now()) AT TIME ZONE coalesce(nullif(z, ''), 'UTC'))::date;
        EXCEPTION WHEN invalid_parameter_value THEN
            RETURN (coalesce(p_at, now()) AT TIME ZONE 'UTC')::date;
        END;
    END
    $f$;
    $sql$;

    EXECUTE $sql$
    CREATE OR REPLACE FUNCTION scm.scm_acc_publish(p_tenant text, p_bus text, p_kind text, p_subject text, p_payload jsonb)
    RETURNS bigint LANGUAGE sql AS $f$
        SELECT core_platform.cp_event_publish(p_tenant, p_bus, 'scm', p_kind, p_subject,
                                              jsonb_build_object('version', 1, 'app', 'scm') || p_payload)
    $f$;
    $sql$;

    -- A money amount as MyStoreGuard writes it (2 decimals, a string).
    EXECUTE $sql$
    CREATE OR REPLACE FUNCTION scm.scm_acc_money(v numeric) RETURNS text
    LANGUAGE sql IMMUTABLE AS $f$ SELECT to_char(round(coalesce(v, 0), 2), 'FM9999999999999990.00') $f$;
    $sql$;

    -- A document's number, for the journal's reference.
    EXECUTE $sql$
    CREATE OR REPLACE FUNCTION scm.scm_acc_number(p_ref_type text, p_ref_id text) RETURNS text
    LANGUAGE plpgsql STABLE AS $f$
    DECLARE t text; n text;
    BEGIN
        t := CASE p_ref_type
                 WHEN 'receipt' THEN 'scm_receipts' WHEN 'return' THEN 'scm_returns' WHEN 'shipment' THEN 'scm_shipments'
                 WHEN 'adjustment' THEN 'scm_adjustments' WHEN 'stock_count' THEN 'scm_stock_counts'
                 WHEN 'branch_shipment' THEN 'scm_branch_shipments' WHEN 'transfer' THEN 'scm_transfers'
                 ELSE 'scm_' || p_ref_type || 's' END;
        IF to_regclass('scm.' || t) IS NULL OR NOT EXISTS (
            SELECT 1 FROM information_schema.columns WHERE table_schema = 'scm' AND table_name = t AND column_name = 'number') THEN
            RETURN p_ref_id;
        END IF;
        EXECUTE format('SELECT number FROM scm.%I WHERE id = $1', t) INTO n USING p_ref_id;
        RETURN coalesce(n, p_ref_id);
    EXCEPTION WHEN OTHERS THEN
        RETURN p_ref_id;
    END
    $f$;
    $sql$;

    -- Publishes the document's movements not yet published (one event), and records them.
    EXECUTE $sql$
    CREATE OR REPLACE FUNCTION scm.scm_acc_publish_reference(p_tenant text, p_bus text, p_ref_type text, p_ref_id text)
    RETURNS bigint LANGUAGE plpgsql AS $f$
    DECLARE
        ids text[]; ev_kind text; base text; org text; ev bigint; head jsonb; lines jsonb;
        reason text; wh text; supplier text; customer text; missing int; today date;
    BEGIN
        SELECT array_agg(m.id ORDER BY m.cdatetime, m.id), max(m.org_id), min(m.reason), min(m.warehouse_id)
          INTO ids, org, reason, wh
          FROM scm.scm_inventory_movements m
         WHERE m.bus_id = p_bus AND m.tenant_id = p_tenant AND m.reference_type = p_ref_type AND m.reference_id = p_ref_id
           AND NOT EXISTS (SELECT 1 FROM scm.scm_acc_moves s WHERE s.movement_id = m.id);
        IF ids IS NULL THEN
            RETURN NULL;
        END IF;

        -- Nothing for the books: stock between SCM's own warehouses, and Manufacturing's documents.
        IF p_ref_type = 'transfer' OR p_ref_type LIKE 'mfg\_%' THEN
            INSERT INTO scm.scm_acc_moves (movement_id, tenant_id, bus_id, event_id)
            SELECT unnest(ids), p_tenant, p_bus, NULL ON CONFLICT (movement_id) DO NOTHING;
            RETURN NULL;
        END IF;

        base := upper(coalesce((SELECT base_currency FROM scm.scm_settings WHERE bus_id = p_bus AND tenant_id = p_tenant), ''));
        today := scm.scm_acc_day(p_tenant, now());
        ev_kind := CASE
            WHEN p_ref_type = 'receipt' THEN 'scm.goods_received'
            WHEN p_ref_type = 'return' THEN 'scm.return_posted'
            WHEN p_ref_type = 'shipment' THEN 'scm.goods_shipped'
            WHEN p_ref_type IN ('adjustment', 'stock_count') THEN 'scm.stock_adjusted'
            WHEN p_ref_type = 'branch_shipment' THEN 'scm.branch_shipment_dispatched'
            WHEN p_ref_type LIKE 'branch\_%' OR p_ref_type LIKE 'msg\_%' THEN 'scm.branch_stock_received'
            ELSE 'scm.stock_posted' END;

        IF ev_kind = 'scm.branch_shipment_dispatched' AND EXISTS (SELECT 1 FROM scm.scm_branch_shipment_parts WHERE shipment_id = p_ref_id) THEN
            -- Exactly what MyStoreGuard was sent: each part at its unit cost as the event to MyStoreGuard
            -- carried it (4 decimals, the shipment's currency).
            SELECT jsonb_agg(jsonb_build_object(
                       'kind', 'transfer_out', 'product_id', l.product_id,
                       'product_name', coalesce(p.name, l.product_id), 'part_id', pt.id, 'lot_number', pt.lot_number,
                       'quantity', (-pt.qty)::text, 'currency', upper(coalesce(nullif(bs.currency, ''), base)),
                       'unit_cost', round(coalesce(pt.unit_cost, 0), 4)::text,
                       'amount', scm.scm_acc_money(-round(pt.qty * round(coalesce(pt.unit_cost, 0), 4), 2)))
                   ORDER BY pt.part_no),
                   count(*) FILTER (WHERE pt.unit_cost IS NULL)
              INTO lines, missing
              FROM scm.scm_branch_shipment_parts pt
              JOIN scm.scm_branch_shipment_lines l ON l.id = pt.line_id
              JOIN scm.scm_branch_shipments bs ON bs.id = pt.shipment_id
              LEFT JOIN core_platform.cp_products p ON p.id = l.product_id
             WHERE pt.shipment_id = p_ref_id;
        ELSE
            -- What the stock cost, lot by lot (the cost ledger), per product, movement kind and currency.
            WITH mv AS (
                SELECT m.id, m.kind, m.product_id, m.qty, m.unit_cost FROM scm.scm_inventory_movements m WHERE m.id = ANY (ids)
            ), parts AS (
                SELECT mv.kind, mv.product_id, coalesce(upper(nullif(lt.currency, '')), base) AS cur,
                       lm.qty, lm.qty * coalesce(lm.unit_cost, 0) AS value, (lm.unit_cost IS NULL) AS nocost
                  FROM mv JOIN scm.scm_lot_moves lm ON lm.movement_id = mv.id
                  LEFT JOIN scm.scm_lots lt ON lt.id = lm.lot_id
                UNION ALL
                -- A movement the cost ledger has nothing for (written before costing began) at its own cost.
                SELECT mv.kind, mv.product_id, base, mv.qty, mv.qty * coalesce(mv.unit_cost, 0), mv.unit_cost IS NULL
                  FROM mv WHERE NOT EXISTS (SELECT 1 FROM scm.scm_lot_moves lm WHERE lm.movement_id = mv.id)
            ), g AS (
                SELECT kind, product_id, cur, sum(qty) AS qty, round(sum(value), 2) AS value, bool_or(nocost) AS nocost
                  FROM parts GROUP BY kind, product_id, cur
            )
            SELECT jsonb_agg(jsonb_build_object(
                       'kind', g.kind, 'product_id', g.product_id, 'product_name', coalesce(p.name, g.product_id),
                       'quantity', g.qty::text, 'currency', g.cur,
                       'unit_cost', CASE WHEN g.qty <> 0 THEN round(g.value / g.qty, 4)::text END,
                       'amount', scm.scm_acc_money(g.value), 'cost_missing', g.nocost)
                   ORDER BY coalesce(p.name, g.product_id), g.kind, g.cur),
                   count(*) FILTER (WHERE g.nocost)
              INTO lines, missing
              FROM g LEFT JOIN core_platform.cp_products p ON p.id = g.product_id
             WHERE g.kind NOT IN ('transfer_in', 'transfer_out') OR ev_kind = 'scm.branch_stock_received';
        END IF;

        IF p_ref_type = 'receipt' THEN
            SELECT po.supplier_id INTO supplier FROM scm.scm_receipts r JOIN scm.scm_purchase_orders po ON po.id = r.po_id WHERE r.id = p_ref_id;
        ELSIF p_ref_type = 'return' THEN
            SELECT r.supplier_id, r.customer_id INTO supplier, customer FROM scm.scm_returns r WHERE r.id = p_ref_id;
        END IF;

        head := jsonb_build_object(
            'org_id', org, 'date', today, 'currency', base,
            'document_type', p_ref_type, 'document_id', p_ref_id, 'document_number', scm.scm_acc_number(p_ref_type, p_ref_id),
            'warehouse_id', wh, 'warehouse_name', (SELECT w.code || ' · ' || w.name FROM scm.scm_warehouses w WHERE w.id = wh),
            'reason', reason,
            'adjustment_kind', CASE WHEN p_ref_type IN ('adjustment', 'stock_count')
                                      AND coalesce(reason, '') ~* '(damag|expir|scrap|spoil|broken|write.?off|written off|stolen|theft)'
                                    THEN 'WRITE_OFF' WHEN p_ref_type = 'stock_count' THEN 'COUNT' ELSE 'ADJUSTMENT' END,
            'supplier_id', supplier,
            'supplier_name', (SELECT x.name FROM core_platform.cp_parties x WHERE x.id = supplier),
            'customer_id', customer,
            'customer_name', (SELECT x.name FROM core_platform.cp_parties x WHERE x.id = customer),
            'cost_missing_lines', coalesce(missing, 0),
            'lines', coalesce(lines, '[]'::jsonb));
        IF p_ref_type = 'branch_shipment' THEN
            head := head || (SELECT jsonb_build_object('loc_id', bs.loc_id, 'side', bs.side,
                                         'location_name', (SELECT l.loc_name FROM core_platform.cp_locations l WHERE l.id = bs.loc_id LIMIT 1),
                                         'currency', upper(coalesce(nullif(bs.currency, ''), base)))
                               FROM scm.scm_branch_shipments bs WHERE bs.id = p_ref_id);
        END IF;

        ev := NULL;
        IF jsonb_array_length(coalesce(lines, '[]'::jsonb)) > 0 THEN
            ev := scm.scm_acc_publish(p_tenant, p_bus, ev_kind, p_ref_id, head);
        END IF;
        INSERT INTO scm.scm_acc_moves (movement_id, tenant_id, bus_id, event_id)
        SELECT unnest(ids), p_tenant, p_bus, ev ON CONFLICT (movement_id) DO NOTHING;
        RETURN ev;
    END
    $f$;
    $sql$;

    -- A branch shipment MyStoreGuard answered: what did not arrive, per part, rounded as each side
    -- rounds its own posting (sent less received), so the clearing account is left at zero.
    EXECUTE $sql$
    CREATE OR REPLACE FUNCTION scm.scm_acc_publish_shortage(p_shipment text) RETURNS bigint
    LANGUAGE plpgsql AS $f$
    DECLARE bs scm.scm_branch_shipments; lines jsonb; ev bigint; base text;
    BEGIN
        SELECT * INTO bs FROM scm.scm_branch_shipments WHERE id = p_shipment;
        IF NOT FOUND OR bs.status NOT IN ('received', 'short')
           OR EXISTS (SELECT 1 FROM scm.scm_acc_shipments WHERE shipment_id = p_shipment) THEN
            RETURN NULL;
        END IF;
        base := upper(coalesce(nullif(bs.currency, ''), (SELECT base_currency FROM scm.scm_settings WHERE bus_id = bs.bus_id), ''));
        SELECT jsonb_agg(jsonb_build_object(
                   'product_id', l.product_id, 'product_name', coalesce(p.name, l.product_id), 'part_id', pt.id,
                   'lot_number', pt.lot_number, 'quantity', coalesce(pt.qty_short, pt.qty - coalesce(pt.qty_received, 0))::text,
                   'reason', pt.short_reason, 'currency', base,
                   'unit_cost', round(coalesce(pt.unit_cost, 0), 4)::text,
                   'amount', scm.scm_acc_money(round(pt.qty * round(coalesce(pt.unit_cost, 0), 4), 2)
                                                - round(coalesce(pt.qty_received, 0) * round(coalesce(pt.unit_cost, 0), 4), 2)))
               ORDER BY pt.part_no)
          INTO lines
          FROM scm.scm_branch_shipment_parts pt
          JOIN scm.scm_branch_shipment_lines l ON l.id = pt.line_id
          LEFT JOIN core_platform.cp_products p ON p.id = l.product_id
         WHERE pt.shipment_id = p_shipment
           AND round(pt.qty * round(coalesce(pt.unit_cost, 0), 4), 2) <> round(coalesce(pt.qty_received, 0) * round(coalesce(pt.unit_cost, 0), 4), 2);
        ev := NULL;
        IF lines IS NOT NULL THEN
            ev := scm.scm_acc_publish(bs.tenant_id, bs.bus_id, 'scm.branch_shipment_short', bs.id, jsonb_build_object(
                'org_id', bs.org_id, 'date', scm.scm_acc_day(bs.tenant_id, now()), 'currency', base,
                'document_type', 'branch_shipment', 'document_id', bs.id, 'document_number', bs.number,
                'loc_id', bs.loc_id, 'location_name', (SELECT l.loc_name FROM core_platform.cp_locations l WHERE l.id = bs.loc_id LIMIT 1),
                'msg_delivery_id', bs.msg_delivery_id, 'note', bs.received_note, 'lines', lines));
        END IF;
        INSERT INTO scm.scm_acc_shipments (shipment_id, tenant_id, bus_id, event_id) VALUES (bs.id, bs.tenant_id, bs.bus_id, ev)
        ON CONFLICT (shipment_id) DO NOTHING;
        RETURN ev;
    END
    $f$;
    $sql$;

    -- The books never stop SCM's work: a failure is published as scm.posting_error (Accounting
    -- lists it as failed, with the reason) and the movements are marked so it is not retried blind.
    EXECUTE $sql$
    CREATE OR REPLACE FUNCTION scm.scm_acc_on_movement() RETURNS trigger
    LANGUAGE plpgsql AS $f$
    DECLARE ev bigint;
    BEGIN
        IF EXISTS (SELECT 1 FROM scm.scm_acc_moves WHERE movement_id = NEW.id) THEN
            RETURN NULL;
        END IF;
        BEGIN
            PERFORM scm.scm_acc_publish_reference(NEW.tenant_id, NEW.bus_id, NEW.reference_type, NEW.reference_id);
        EXCEPTION WHEN OTHERS THEN
            ev := scm.scm_acc_publish(NEW.tenant_id, NEW.bus_id, 'scm.posting_error', NEW.reference_id, jsonb_build_object(
                'org_id', NEW.org_id, 'date', scm.scm_acc_day(NEW.tenant_id, now()), 'document_type', NEW.reference_type,
                'document_id', NEW.reference_id, 'document_number', NEW.reference_id, 'error', SQLERRM));
            INSERT INTO scm.scm_acc_moves (movement_id, tenant_id, bus_id, event_id)
            SELECT m.id, m.tenant_id, m.bus_id, ev FROM scm.scm_inventory_movements m
             WHERE m.bus_id = NEW.bus_id AND m.reference_type = NEW.reference_type AND m.reference_id = NEW.reference_id
            ON CONFLICT (movement_id) DO NOTHING;
        END;
        RETURN NULL;
    END
    $f$;
    $sql$;

    EXECUTE $sql$
    CREATE OR REPLACE FUNCTION scm.scm_acc_on_shipment() RETURNS trigger
    LANGUAGE plpgsql AS $f$
    DECLARE ev bigint;
    BEGIN
        BEGIN
            PERFORM scm.scm_acc_publish_shortage(NEW.id);
        EXCEPTION WHEN OTHERS THEN
            ev := scm.scm_acc_publish(NEW.tenant_id, NEW.bus_id, 'scm.posting_error', NEW.id, jsonb_build_object(
                'org_id', NEW.org_id, 'date', scm.scm_acc_day(NEW.tenant_id, now()), 'document_type', 'branch_shipment',
                'document_id', NEW.id, 'document_number', NEW.number, 'error', SQLERRM));
            INSERT INTO scm.scm_acc_shipments (shipment_id, tenant_id, bus_id, event_id) VALUES (NEW.id, NEW.tenant_id, NEW.bus_id, ev)
            ON CONFLICT (shipment_id) DO NOTHING;
        END;
        RETURN NULL;
    END
    $f$;
    $sql$;

    -- The baseline, once: nothing that happened before SCM posted belongs to these events (it is in
    -- the books' opening balances, if anywhere).
    IF first_run THEN
        INSERT INTO scm.scm_acc_moves (movement_id, tenant_id, bus_id, event_id)
        SELECT id, tenant_id, bus_id, NULL FROM scm.scm_inventory_movements
        ON CONFLICT (movement_id) DO NOTHING;
        INSERT INTO scm.scm_acc_shipments (shipment_id, tenant_id, bus_id, event_id)
        SELECT id, tenant_id, bus_id, NULL FROM scm.scm_branch_shipments WHERE status IN ('received', 'short', 'rejected')
        ON CONFLICT (shipment_id) DO NOTHING;
    END IF;

    DROP TRIGGER IF EXISTS scm_acc_movement ON scm.scm_inventory_movements;
    CREATE CONSTRAINT TRIGGER scm_acc_movement AFTER INSERT ON scm.scm_inventory_movements
        DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION scm.scm_acc_on_movement();
    DROP TRIGGER IF EXISTS scm_acc_shipment ON scm.scm_branch_shipments;
    CREATE CONSTRAINT TRIGGER scm_acc_shipment AFTER UPDATE OF status ON scm.scm_branch_shipments
        DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
        WHEN (NEW.status IN ('received', 'short') AND OLD.status IS DISTINCT FROM NEW.status)
        EXECUTE FUNCTION scm.scm_acc_on_shipment();

    -- SCM's side of the combined view: what MyStoreGuard may read.
    --   warehouse   stock on hand and available (on hand less reserved) per product and warehouse
    --   in_transit  dispatched branch shipments not yet answered, per product and branch place
    --   on_order    SCM purchase orders a supplier delivers straight to a branch, not yet answered
    --   supply      which warehouse supplies which branch place (scm_branch_supply)
    -- product_id is MyStoreGuard's: a variant is its parent, with kind the variant.
    EXECUTE $sql$
    CREATE OR REPLACE FUNCTION scm.scm_stock_for_msg(p_tenant text, p_bus text)
    RETURNS TABLE (row_kind text, product_id text, kind text, warehouse_id text, warehouse_code text, warehouse_name text,
                   loc_id text, side text, qty numeric, available numeric, reference text)
    LANGUAGE sql STABLE AS $f$
        WITH prod AS (
            SELECT p.id, coalesce(nullif(p.parent_id, ''), p.id) AS msg_id,
                   CASE WHEN nullif(p.parent_id, '') IS NOT NULL THEN nullif(p.variant, '') END AS kind
              FROM core_platform.cp_products p WHERE p.bus_id = p_bus
        )
        SELECT 'warehouse', pr.msg_id, pr.kind, w.id, w.code, w.name, NULL::text, NULL::text,
               sum(b.on_hand), sum(b.on_hand - b.reserved), NULL::text
          FROM scm.scm_stock_balances b
          JOIN scm.scm_warehouses w ON w.id = b.warehouse_id AND w.archived_at IS NULL
          JOIN prod pr ON pr.id = b.product_id
         WHERE b.tenant_id = p_tenant AND b.bus_id = p_bus
         GROUP BY pr.msg_id, pr.kind, w.id, w.code, w.name
        HAVING sum(b.on_hand) <> 0
        UNION ALL
        SELECT 'in_transit', pr.msg_id, pr.kind, w.id, w.code, w.name, bs.loc_id, bs.side, sum(pt.qty), NULL, bs.number
          FROM scm.scm_branch_shipments bs
          JOIN scm.scm_branch_shipment_parts pt ON pt.shipment_id = bs.id
          JOIN scm.scm_branch_shipment_lines l ON l.id = pt.line_id
          JOIN scm.scm_warehouses w ON w.id = bs.warehouse_id
          JOIN prod pr ON pr.id = l.product_id
         WHERE bs.tenant_id = p_tenant AND bs.bus_id = p_bus AND bs.status = 'dispatched'
         GROUP BY pr.msg_id, pr.kind, w.id, w.code, w.name, bs.loc_id, bs.side, bs.number
        UNION ALL
        SELECT 'on_order', pr.msg_id, pr.kind, NULL, NULL, NULL, po.deliver_to_loc_id, po.deliver_to_side,
               sum(greatest(ol.qty_ordered - ol.qty_received, 0)), NULL, po.number
          FROM scm.scm_purchase_orders po
          JOIN scm.scm_purchase_order_lines ol ON ol.po_id = po.id
          JOIN prod pr ON pr.id = ol.product_id
         WHERE po.tenant_id = p_tenant AND po.bus_id = p_bus AND po.deliver_to_loc_id IS NOT NULL
           AND po.branch_status = 'awaiting' AND po.status NOT IN ('cancelled', 'closed', 'received')
         GROUP BY pr.msg_id, pr.kind, po.deliver_to_loc_id, po.deliver_to_side, po.number
        HAVING sum(greatest(ol.qty_ordered - ol.qty_received, 0)) > 0
        UNION ALL
        SELECT 'supply', NULL, NULL, w.id, w.code, w.name, s.loc_id, s.side, NULL, NULL, NULL
          FROM scm.scm_branch_supply s JOIN scm.scm_warehouses w ON w.id = s.warehouse_id
         WHERE s.tenant_id = p_tenant AND s.bus_id = p_bus
    $f$;
    $sql$;
    COMMENT ON FUNCTION scm.scm_stock_for_msg(text, text) IS
        'MSG-SCM phase 5: SCM''s warehouse stock, in transit and on order for MyStoreGuard''s Warehouse stock panel (20261102-85). MyStoreGuard calls this, never the tables.';
END $do$;

-- ===================================================================== checks (invariants, not counts)
DO $$
DECLARE bad text;
BEGIN
    IF to_regclass('scm.scm_inventory_movements') IS NULL OR to_regclass('scm.scm_branch_shipments') IS NULL THEN
        RETURN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'scm_acc_movement' AND tgrelid = 'scm.scm_inventory_movements'::regclass AND tgdeferrable)
       OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'scm_acc_shipment' AND tgrelid = 'scm.scm_branch_shipments'::regclass AND tgdeferrable) THEN
        RAISE EXCEPTION 'msg-scm phase 5: SCM''s posting triggers are missing or not deferred';
    END IF;
    -- Every movement committed is accounted for (published, baseline, or nothing to post).
    SELECT string_agg(m.id, ', ') INTO bad FROM (
        SELECT m.id FROM scm.scm_inventory_movements m
         WHERE NOT EXISTS (SELECT 1 FROM scm.scm_acc_moves s WHERE s.movement_id = m.id) LIMIT 5) m;
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'msg-scm phase 5: movements no event accounts for: %', bad;
    END IF;
    -- An event named for movements is one SCM published.
    SELECT string_agg(DISTINCT s.event_id::text, ', ') INTO bad FROM scm.scm_acc_moves s
     WHERE s.event_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM core_platform.cp_events e WHERE e.id = s.event_id AND e.source_app = 'scm');
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'msg-scm phase 5: scm_acc_moves names events SCM did not publish: %', bad;
    END IF;
END $$;

COMMIT;
