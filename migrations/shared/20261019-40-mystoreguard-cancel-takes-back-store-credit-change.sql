-- =====================================================================
-- MyStoreGuard: a cancelled sale takes back the change it put on store credit
-- ---------------------------------------------------------------------
-- Since tvs-mystoreguard-bk 71ae82c, cancel_sale refunds every tender of the sale AND takes
-- back the change the sale had kept as store credit (overpay_to_store_credit), as much of it
-- as the customer still holds: StoreCreditService.apply_credit(..., -amount, 'ADJUST',
-- source_sale_id = the sale). The sale's own event credited that change to Customer store
-- credit (2410); the refunds reverse every tender in full (msg.payment_reversed). Without this
-- the books keep the credit the customer no longer has and the receivable it came out of.
--
-- msg.sale_voided now carries 'store_credit_change_reversed' (two-decimal string, 0.00 unless
-- the sale was CANCELLED and credit was taken back). Accounting posts Dr Customer store credit,
-- Cr Customer balances for it, the exact opposite of what the sale posted for that change.
--
-- The function is 20261019-38's msg_acc_sync_sale with only that field added. Both files run
-- on every deploy in order, so this later definition is the one that stands (later wins);
-- -38 stays as it is so a fresh database gets the same end state. Idempotent.
-- =====================================================================
BEGIN;

CREATE OR REPLACE FUNCTION mystoreguard.msg_acc_sync_sale(p_tenant text, p_org text, p_bus text, p_loc text, p_sale text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
    s mystoreguard.msg_sales;
    st mystoreguard.msg_acc_sale_state;
    found_sale boolean;
    now_recognised boolean;
    fig jsonb;
    ps record;
    p record;
    eff boolean;
    head jsonb;
    today date := mystoreguard.msg_acc_day(p_tenant, now());
    created_now boolean;
    folded jsonb := '[]'::jsonb;
    folded_total numeric := 0;
    folded_cash numeric := 0;
    deposits numeric;
    change_issued numeric := 0;
    change_given numeric := 0;
    receivable numeric;
    gross numeric;
    finance numeric;
    pen numeric;
    restocked boolean;
    rev integer;
    sale_date date;
BEGIN
    SELECT * INTO s FROM mystoreguard.msg_sales
     WHERE tenant_id = p_tenant AND org_id = p_org AND bus_id = p_bus AND loc_id = p_loc AND id = p_sale;
    found_sale := FOUND;

    SELECT * INTO st FROM mystoreguard.msg_acc_sale_state WHERE sale_id = p_sale FOR UPDATE;
    IF NOT FOUND THEN
        IF NOT found_sale THEN RETURN; END IF;
        INSERT INTO mystoreguard.msg_acc_sale_state (sale_id, tenant_id, bus_id, created_txid)
        VALUES (p_sale, p_tenant, p_bus, pg_current_xact_id())
        RETURNING * INTO st;
    END IF;
    created_now := st.created_txid IS NOT DISTINCT FROM pg_current_xact_id();

    IF found_sale THEN
        head := mystoreguard.msg_acc_sale_header(s);
    ELSE
        head := coalesce(st.figures -> 'header', '{}'::jsonb);
    END IF;
    head := head || jsonb_build_object('org_id', p_org, 'loc_id', p_loc);

    now_recognised := found_sale AND s.status IS DISTINCT FROM 'CANCELLED' AND s.fulfillment_status = 'FULFILLED';
    IF now_recognised THEN
        fig := mystoreguard.msg_acc_sale_figures(p_tenant, p_org, p_bus, p_loc, p_sale);
    END IF;

    -- 1. Published payments that no longer stand (refunded, deleted, reduced, or a gift card /
    --    loyalty tender cancel_sale put back): reverse them where they sit in the books.
    FOR ps IN SELECT * FROM mystoreguard.msg_acc_payment_state WHERE source = 'SALE' AND doc_id = p_sale ORDER BY payment_id LOOP
        SELECT * INTO p FROM mystoreguard.msg_sales_payments
         WHERE tenant_id = p_tenant AND org_id = p_org AND bus_id = p_bus AND loc_id = p_loc AND id = ps.payment_id;
        eff := FOUND AND found_sale AND p.payment_status = 'SUCCESS' AND p.deleted_at IS NULL
               AND NOT (s.status = 'CANCELLED' AND p.payment_method IN ('GIFT_CARD', 'LOYALTY_POINTS'))
               AND round(p.paid_amount, 2) = ps.amount AND p.payment_method = ps.method;
        IF NOT eff THEN
            PERFORM mystoreguard.msg_acc_publish(p_tenant, p_bus, 'msg.payment_reversed', ps.payment_id, head || jsonb_build_object(
                'date', today, 'payment_id', ps.payment_id, 'method', ps.method,
                'amount', mystoreguard.msg_acc_money(ps.amount), 'penalty', mystoreguard.msg_acc_money(ps.penalty),
                'applied', ps.applied,
                'reason', CASE WHEN NOT found_sale THEN 'SALE_DELETED' WHEN p.id IS NULL THEN 'DELETED'
                               WHEN p.payment_status = 'REFUNDED' THEN 'REFUNDED'
                               WHEN s.status = 'CANCELLED' THEN 'TENDER_RESTORED' ELSE 'CHANGED' END));
            DELETE FROM mystoreguard.msg_acc_payment_state WHERE payment_id = ps.payment_id;
        END IF;
    END LOOP;

    -- 2. A released sale cancelled, deleted, or whose figures changed: void what was published.
    IF st.recognised AND (NOT now_recognised
                          OR mystoreguard.msg_acc_fingerprint(fig) IS DISTINCT FROM mystoreguard.msg_acc_fingerprint(st.figures)) THEN
        restocked := found_sale AND s.status = 'CANCELLED' AND EXISTS (
            SELECT 1 FROM mystoreguard.msg_product_movements m
             WHERE m.tenant_id = p_tenant AND m.org_id = p_org AND m.bus_id = p_bus AND m.reference_id = p_sale
               AND m.movement_type = 'IN');
        PERFORM mystoreguard.msg_acc_publish(p_tenant, p_bus, 'msg.sale_voided', p_sale, head || jsonb_build_object(
            'date', CASE WHEN created_now AND found_sale THEN s.sale_date ELSE today END,
            'revision', st.revision,
            'reason', CASE WHEN NOT found_sale THEN 'DELETED' WHEN s.status = 'CANCELLED' THEN 'CANCELLED'
                           WHEN NOT now_recognised THEN 'UNRELEASED' ELSE 'CHANGED' END,
            'restocked', CASE WHEN found_sale AND now_recognised THEN true ELSE coalesce(restocked, false) END,
            -- Change this sale had put on store credit, taken back by cancel_sale (an ADJUST row
            -- with a negative amount, source_sale_id = the sale): positive, what comes off the credit.
            'store_credit_change_reversed', mystoreguard.msg_acc_money(CASE WHEN found_sale AND s.status = 'CANCELLED' THEN
                -(SELECT coalesce(sum(t.amount), 0) FROM mystoreguard.msg_store_credit_transactions t
                   WHERE t.tenant_id = p_tenant AND t.org_id = p_org AND t.bus_id = p_bus AND t.source_sale_id = p_sale
                     AND t.txn_type = 'ADJUST' AND t.amount < 0) ELSE 0 END),
            'figures', st.figures - 'header'));
        UPDATE mystoreguard.msg_acc_sale_state SET recognised = false, updated_at = now() WHERE sale_id = p_sale;
        st.recognised := false;
    END IF;

    -- 3. Payments not yet published.
    IF found_sale THEN
        FOR p IN SELECT sp.* FROM mystoreguard.msg_sales_payments sp
                  WHERE sp.tenant_id = p_tenant AND sp.org_id = p_org AND sp.bus_id = p_bus AND sp.loc_id = p_loc AND sp.sale_id = p_sale
                    AND sp.payment_status = 'SUCCESS' AND sp.deleted_at IS NULL
                    AND NOT (s.status = 'CANCELLED' AND sp.payment_method IN ('GIFT_CARD', 'LOYALTY_POINTS'))
                    AND NOT EXISTS (SELECT 1 FROM mystoreguard.msg_acc_payment_state x WHERE x.payment_id = sp.id)
                  ORDER BY sp.cdatetime, sp.id LOOP
            SELECT coalesce(sum(a.amount), 0) INTO pen FROM mystoreguard.msg_installment_allocations a
             WHERE a.tenant_id = p_tenant AND a.org_id = p_org AND a.bus_id = p_bus AND a.loc_id = p_loc
               AND a.payment_id = p.id AND a.allocation_type = 'PENALTY';
            pen := least(round(pen, 2), round(p.paid_amount, 2));
            IF now_recognised AND NOT st.recognised THEN
                -- Folded into the sale's own event below.
                folded := folded || jsonb_build_array(jsonb_build_object(
                    'payment_id', p.id, 'method', p.payment_method, 'amount', mystoreguard.msg_acc_money(p.paid_amount),
                    'penalty', mystoreguard.msg_acc_money(pen), 'gift_card_id', p.gift_card_id,
                    'reference', p.online_payment_reference));
                folded_total := folded_total + round(p.paid_amount, 2) - pen;
                IF p.payment_method = 'CASH' THEN folded_cash := folded_cash + round(p.paid_amount, 2); END IF;
                INSERT INTO mystoreguard.msg_acc_payment_state (payment_id, source, doc_id, tenant_id, bus_id, method, amount, penalty, applied)
                VALUES (p.id, 'SALE', p_sale, p_tenant, p_bus, p.payment_method, round(p.paid_amount, 2), pen, 'RECEIVABLE');
            ELSE
                PERFORM mystoreguard.msg_acc_publish(p_tenant, p_bus, 'msg.payment_received', p.id, head || jsonb_build_object(
                    'date', mystoreguard.msg_acc_day(p_tenant, p.cdatetime),
                    'payment_id', p.id, 'method', p.payment_method, 'amount', mystoreguard.msg_acc_money(p.paid_amount),
                    'penalty', mystoreguard.msg_acc_money(pen), 'gift_card_id', p.gift_card_id,
                    'reference', p.online_payment_reference,
                    'applied', CASE WHEN st.recognised THEN 'RECEIVABLE' ELSE 'DEPOSIT' END));
                INSERT INTO mystoreguard.msg_acc_payment_state (payment_id, source, doc_id, tenant_id, bus_id, method, amount, penalty, applied)
                VALUES (p.id, 'SALE', p_sale, p_tenant, p_bus, p.payment_method, round(p.paid_amount, 2), pen,
                        CASE WHEN st.recognised THEN 'RECEIVABLE' ELSE 'DEPOSIT' END);
            END IF;
        END LOOP;
    END IF;

    -- 4. Goods released (again): the sale's own event.
    IF now_recognised AND NOT st.recognised THEN
        rev := st.revision + 1;
        SELECT coalesce(sum(amount - penalty), 0) INTO deposits FROM mystoreguard.msg_acc_payment_state
         WHERE source = 'SALE' AND doc_id = p_sale AND applied = 'DEPOSIT';
        UPDATE mystoreguard.msg_acc_payment_state SET applied = 'RECEIVABLE', updated_at = now()
         WHERE source = 'SALE' AND doc_id = p_sale AND applied = 'DEPOSIT';
        gross := (fig ->> 'gross')::numeric;
        finance := (fig ->> 'finance_charge')::numeric - (fig ->> 'settlement_discount')::numeric;
        IF rev = 1 THEN change_issued := round(coalesce(s.store_credit_change_issued, 0), 2); END IF;
        receivable := gross + finance - deposits - folded_total + change_issued;
        -- Cash handed back as change, where the till recorded what was tendered.
        IF receivable < 0 AND folded_cash > 0 THEN
            change_given := least(-receivable, folded_cash);
            receivable := receivable + change_given;
        END IF;
        sale_date := CASE WHEN created_now THEN s.sale_date
                          ELSE mystoreguard.msg_acc_day(p_tenant, coalesce(s.fulfillment_date_time, now())) END;
        PERFORM mystoreguard.msg_acc_publish(p_tenant, p_bus, 'msg.sale_completed', p_sale, head || jsonb_build_object(
            'date', sale_date, 'revision', rev, 'status', s.status,
            'figures', fig,
            'payments', folded,
            'deposits_applied', mystoreguard.msg_acc_money(deposits),
            'store_credit_change_issued', mystoreguard.msg_acc_money(change_issued),
            'change_given', mystoreguard.msg_acc_money(change_given),
            'receivable', mystoreguard.msg_acc_money(receivable)));
        UPDATE mystoreguard.msg_acc_sale_state
           SET recognised = true, revision = rev, figures = fig || jsonb_build_object('header', head), updated_at = now()
         WHERE sale_id = p_sale;
    END IF;

    IF NOT found_sale THEN
        DELETE FROM mystoreguard.msg_acc_sale_state WHERE sale_id = p_sale;
    END IF;
END
$f$;

COMMIT;
