-- MyStoreGuard and LoanDrift join the workflow designer: their lifecycle events
-- (tvs-coreplatform-bk docs/workflows/DESIGN.md §10; slice 2 was 20261110-11).
--
-- WHAT. Plain, versioned payloads ({"v": 1, ...}) in core_platform.cp_events, source
-- 'app-mystoreguard' / 'app-loandrift', for Core's workflow designer (reader 'core-workflows')
-- and anyone else reading the log. Not link envelopes, not accounting events: the msg.* and ld.*
-- kinds Accounting reads are untouched. New prefixes 'mystoreguard.' and 'loandrift.' (like
-- zhr.* vs zeloshr.*), so a lifecycle kind never collides with an accounting one.
--
--   mystoreguard.sale_recorded        a sale was written (any channel); a "large sale" workflow
--                                     tests payload.total in its condition
--   mystoreguard.online_order_placed  a storefront order (the checkout's sale, "Online order ...")
--   mystoreguard.goods_released       a sale's goods went out (fulfillment FULFILLED), once per sale
--   mystoreguard.instalment_overdue   an instalment-plan period turned OVERDUE (the instalment job's
--                                     mark_overdue_rows), once per period and due date
--   mystoreguard.stock_low            a product's stock at a store or warehouse fell to or below its
--                                     reorder level there (MyStoreGuard's own "needs reorder" rule,
--                                     reorder_level > 0 AND qty <= reorder_level, qty from the
--                                     deliveries' batch stock); once until it is restocked above it
--   (a gift card sold is the existing msg.gift_card_issued, issued_as SOLD; catalogued in Core)
--
--   loandrift.loan_applied            a loan was registered (inserted, any status)
--   loandrift.loan_approved           a loan moved to APPROVED
--   loandrift.loan_disbursed          a loan moved to DISBURSED or ACTIVE from before disbursement,
--                                     once per loan
--   loandrift.repayment_received      a repayment row was written (counter, online, automatic)
--   loandrift.loan_defaulted          a loan moved to DEFAULTED, by either source (the defaulter
--                                     cron or the payment gate keeping it there never re-sends;
--                                     a loan that recovers and defaults again is told again)
--   loandrift.loan_repaid             a loan moved to COMPLETED (balance cleared), once per loan
--   loandrift.instalment_overdue      published by the LoanDrift API's overdue scan (tvs-loandrift-bk
--                                     entities/suite_events), not here: it is the arrears rule of
--                                     installment_summary, which lives in Python. Only its state
--                                     table and catalogue row are here.
--
-- WHY TRIGGERS. Same reason as 20261019-38 and -41: neither app has one place its sales, loans or
-- stock go through (the till, storefront, auctions, instalment jobs and Azure functions all write
-- them), and the LoanDrift defaulter cron flips status in SQL. A trigger fires for every path.
-- DEFERRED (at COMMIT) so the payload reads the record as it finally stands (a sale's totals and a
-- loan's calculations are written after its header); a write that rolls back publishes nothing.
-- A status event is published only if the record is STILL in that status at commit.
--
-- NEVER FAILS THE CHANGE. Every trigger body runs inside BEGIN ... EXCEPTION (a savepoint): an
-- error rolls back only the event and its state row, raises a WARNING, and the change commits.
--
-- NO SENSITIVE DATA. Names, numbers, amounts, statuses, places and dates only: never a phone,
-- email, address, id document, gift card code, salary or bank detail, note or description text.
--
-- Starts from now (nothing is back-published). Idempotent; re-runs on every deploy. This file
-- owns the catalogue rows of the kinds it names.

BEGIN;

-- ============================================================================ MyStoreGuard
CREATE TABLE IF NOT EXISTS mystoreguard.msg_wf_event_state (
    kind       text NOT NULL,
    key        text NOT NULL,
    tenant_id  text NOT NULL,
    cdatetime  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (kind, key)
);

-- Once per (kind, key): true the first time, false after.
CREATE OR REPLACE FUNCTION mystoreguard.msg_wf_once(p_kind text, p_key text, p_tenant text)
RETURNS boolean LANGUAGE plpgsql AS $f$
BEGIN
    INSERT INTO mystoreguard.msg_wf_event_state (kind, key, tenant_id) VALUES (p_kind, p_key, p_tenant)
    ON CONFLICT DO NOTHING;
    RETURN FOUND;
END
$f$;

CREATE OR REPLACE FUNCTION mystoreguard.msg_wf_publish(p_tenant text, p_bus text, p_kind text, p_subject text, p_payload jsonb)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
    -- A workflow belongs to a business: an event naming none starts nothing.
    IF coalesce(p_tenant, '') = '' OR coalesce(p_bus, '') = '' THEN
        RETURN;
    END IF;
    PERFORM core_platform.cp_event_publish(p_tenant, p_bus, 'app-mystoreguard', p_kind, p_subject,
                                           jsonb_strip_nulls(coalesce(p_payload, '{}'::jsonb) || jsonb_build_object('v', 1)));
END
$f$;

CREATE OR REPLACE FUNCTION mystoreguard.msg_wf_money(v numeric) RETURNS text
LANGUAGE sql IMMUTABLE AS $f$ SELECT to_char(round(coalesce(v, 0), 2), 'FM9999999999999990.00') $f$;

CREATE OR REPLACE FUNCTION mystoreguard.msg_wf_currency(p_tenant text, p_currency_id text DEFAULT NULL) RETURNS text
LANGUAGE sql STABLE AS $f$
    SELECT coalesce(
        (SELECT upper(code) FROM core_platform.cp_currencies
          WHERE tenant_id = p_tenant AND p_currency_id IS NOT NULL AND id = p_currency_id LIMIT 1),
        (SELECT upper(code) FROM core_platform.cp_currencies
          WHERE tenant_id = p_tenant AND is_default AND coalesce(delete_status, 'NOT_DELETED') = 'NOT_DELETED'
          ORDER BY cdatetime DESC NULLS LAST LIMIT 1),
        '')
$f$;

CREATE OR REPLACE FUNCTION mystoreguard.msg_wf_location_name(p_tenant text, p_loc text) RETURNS text
LANGUAGE sql STABLE AS $f$
    SELECT l.loc_name FROM core_platform.cp_locations l WHERE l.id = p_loc AND l.tenant_id = p_tenant LIMIT 1
$f$;

-- --------------------------------------------------------------------- sales
CREATE OR REPLACE FUNCTION mystoreguard.msg_wf_sale_trigger() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE s record; p jsonb; online boolean;
BEGIN
    BEGIN
        SELECT * INTO s FROM mystoreguard.msg_sales WHERE id = NEW.id AND tenant_id = NEW.tenant_id;
        IF NOT FOUND OR coalesce(s.status, '') = 'CANCELLED' OR s.deleted_by IS NOT NULL THEN
            RETURN NULL;
        END IF;
        online := coalesce(s.description, '') LIKE 'Online order%';
        p := jsonb_build_object(
            'sale_id', s.id, 'sale_number', s.sale_number, 'sale_mode', s.sale_mode,
            'channel', CASE WHEN online THEN 'ONLINE' ELSE 'STORE' END,
            'status', s.status, 'fulfillment_status', s.fulfillment_status,
            'total', mystoreguard.msg_wf_money(coalesce(s.payable_amount, s.total_amount)),
            'goods_total', mystoreguard.msg_wf_money(s.total_amount),
            'paid', mystoreguard.msg_wf_money(s.paid_amount),
            'balance', mystoreguard.msg_wf_money(s.balance_amount),
            'currency', mystoreguard.msg_wf_currency(s.tenant_id),
            'customer_id', s.customer_id,
            'customer_name', (SELECT c.fullname FROM mystoreguard.msg_customers c
                               WHERE c.id = s.customer_id AND c.tenant_id = s.tenant_id LIMIT 1),
            'location_id', s.loc_id, 'location_name', mystoreguard.msg_wf_location_name(s.tenant_id, s.loc_id),
            'items', (SELECT count(*) FROM mystoreguard.msg_sales_items i WHERE i.sale_id = s.id),
            'sale_date', left(s.sale_date::text, 10), 'created_by', s.created_by);

        IF TG_OP = 'INSERT' AND mystoreguard.msg_wf_once('sale_recorded', s.id, s.tenant_id) THEN
            PERFORM mystoreguard.msg_wf_publish(s.tenant_id, s.bus_id, 'mystoreguard.sale_recorded', s.id, p);
            IF online THEN
                PERFORM mystoreguard.msg_wf_publish(s.tenant_id, s.bus_id, 'mystoreguard.online_order_placed', s.id, p);
            END IF;
        END IF;

        IF s.fulfillment_status = 'FULFILLED' AND mystoreguard.msg_wf_once('goods_released', s.id, s.tenant_id) THEN
            PERFORM mystoreguard.msg_wf_publish(s.tenant_id, s.bus_id, 'mystoreguard.goods_released', s.id,
                p || jsonb_build_object('released_at', s.fulfillment_date_time));
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'mystoreguard workflow event (sale %): % (%)', NEW.id, SQLERRM, SQLSTATE;
    END;
    RETURN NULL;
END
$f$;

-- --------------------------------------------------------------------- instalment periods
CREATE OR REPLACE FUNCTION mystoreguard.msg_wf_schedule_trigger() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE r record; pl record; s record; due date;
BEGIN
    BEGIN
        SELECT * INTO r FROM mystoreguard.msg_installment_schedule WHERE id = NEW.id AND tenant_id = NEW.tenant_id;
        IF NOT FOUND OR r.status IS DISTINCT FROM 'OVERDUE' THEN
            RETURN NULL;
        END IF;
        due := left(r.due_date::text, 10)::date;
        IF NOT mystoreguard.msg_wf_once('instalment_overdue', r.id || ':' || coalesce(due::text, ''), r.tenant_id) THEN
            RETURN NULL;
        END IF;
        SELECT * INTO pl FROM mystoreguard.msg_installment_plans WHERE id = r.plan_id AND tenant_id = r.tenant_id;
        SELECT id, sale_number, customer_id INTO s FROM mystoreguard.msg_sales WHERE id = pl.sale_id AND tenant_id = r.tenant_id;
        PERFORM mystoreguard.msg_wf_publish(r.tenant_id, r.bus_id, 'mystoreguard.instalment_overdue', r.id, jsonb_build_object(
            'schedule_id', r.id, 'plan_id', r.plan_id, 'period_no', r.period_no,
            'term_count', pl.term_count, 'frequency', pl.frequency, 'plan_status', pl.status,
            'due_date', due, 'days_overdue', CASE WHEN due IS NULL THEN NULL ELSE current_date - due END,
            'amount', mystoreguard.msg_wf_money(r.amount), 'paid', mystoreguard.msg_wf_money(r.paid_amount),
            'balance', mystoreguard.msg_wf_money(greatest(coalesce(r.amount, 0) - coalesce(r.paid_amount, 0), 0)),
            'plan_balance', mystoreguard.msg_wf_money(greatest(coalesce(pl.total_payable, 0) - coalesce(pl.amount_paid, 0), 0)),
            'currency', mystoreguard.msg_wf_currency(r.tenant_id),
            'sale_id', s.id, 'sale_number', s.sale_number, 'customer_id', s.customer_id,
            'customer_name', (SELECT c.fullname FROM mystoreguard.msg_customers c
                               WHERE c.id = s.customer_id AND c.tenant_id = r.tenant_id LIMIT 1),
            'location_id', r.loc_id, 'location_name', mystoreguard.msg_wf_location_name(r.tenant_id, r.loc_id)));
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'mystoreguard workflow event (instalment %): % (%)', NEW.id, SQLERRM, SQLSTATE;
    END;
    RETURN NULL;
END
$f$;

-- --------------------------------------------------------------------- stock at or below reorder level
CREATE OR REPLACE FUNCTION mystoreguard.msg_wf_stock_trigger() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE b record; pid text; lvl integer; rq integer; qty numeric; pname text; k text; rising boolean;
BEGIN
    BEGIN
        IF TG_OP = 'DELETE' THEN b := OLD; ELSE b := NEW; END IF;
        -- A delivery or a rise can only re-arm (back above the level); only a fall is told.
        rising := TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND NEW.qty > OLD.qty);
        IF coalesce(b.location_type, '') NOT IN ('STORE', 'WAREHOUSE') THEN
            RETURN NULL;
        END IF;
        SELECT pb.product_id INTO pid FROM mystoreguard.msg_purchase_batches pb
         WHERE pb.id = b.purchase_batche_id AND pb.tenant_id = b.tenant_id;
        IF pid IS NULL THEN
            RETURN NULL;
        END IF;
        IF b.location_type = 'STORE' THEN
            SELECT sp.reorder_level, sp.reorder_quantity INTO lvl, rq FROM mystoreguard.msg_store_products sp
             WHERE sp.tenant_id = b.tenant_id AND sp.org_id = b.org_id AND sp.bus_id = b.bus_id
               AND sp.loc_id = b.loc_id AND sp.product_id = pid AND sp.delete_status = 'NOT_DELETED' LIMIT 1;
        ELSE
            SELECT wp.reorder_level, wp.reorder_quantity INTO lvl, rq FROM mystoreguard.msg_warehouse_products wp
             WHERE wp.tenant_id = b.tenant_id AND wp.org_id = b.org_id AND wp.bus_id = b.bus_id
               AND wp.loc_id = b.loc_id AND wp.product_id = pid AND wp.delete_status = 'NOT_DELETED' LIMIT 1;
        END IF;
        IF coalesce(lvl, 0) <= 0 THEN
            RETURN NULL;
        END IF;
        SELECT coalesce(sum(bl.qty), 0) INTO qty
          FROM mystoreguard.msg_batch_locations bl
          JOIN mystoreguard.msg_purchase_batches pb
            ON pb.id = bl.purchase_batche_id AND pb.tenant_id = bl.tenant_id AND pb.org_id = bl.org_id AND pb.bus_id = bl.bus_id
         WHERE bl.tenant_id = b.tenant_id AND bl.org_id = b.org_id AND bl.bus_id = b.bus_id
           AND bl.loc_id = b.loc_id AND bl.location_type = b.location_type AND pb.product_id = pid
           AND pb.status NOT IN ('VOID', 'CANCELLED') AND pb.delete_status = 'NOT_DELETED';
        k := b.tenant_id || ':' || b.location_type || ':' || b.loc_id || ':' || pid;
        IF qty > lvl THEN
            -- Above the level (restocked): the next fall to it is told again.
            DELETE FROM mystoreguard.msg_wf_event_state WHERE kind = 'stock_low' AND key = k;
            RETURN NULL;
        END IF;
        IF rising OR NOT mystoreguard.msg_wf_once('stock_low', k, b.tenant_id) THEN
            RETURN NULL;
        END IF;
        SELECT p.name INTO pname FROM mystoreguard.msg_products p WHERE p.id = pid AND p.tenant_id = b.tenant_id;
        PERFORM mystoreguard.msg_wf_publish(b.tenant_id, b.bus_id, 'mystoreguard.stock_low', pid, jsonb_build_object(
            'product_id', pid, 'product_name', pname, 'location_type', b.location_type,
            'location_id', b.loc_id, 'location_name', mystoreguard.msg_wf_location_name(b.tenant_id, b.loc_id),
            'quantity', qty, 'reorder_level', lvl, 'reorder_quantity', rq,
            'out_of_stock', qty <= 0));
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'mystoreguard workflow event (stock): % (%)', SQLERRM, SQLSTATE;
    END;
    RETURN NULL;
END
$f$;

DO $$
BEGIN
    IF to_regclass('mystoreguard.msg_sales') IS NOT NULL THEN
        DROP TRIGGER IF EXISTS msg_wf_sale_created ON mystoreguard.msg_sales;
        CREATE CONSTRAINT TRIGGER msg_wf_sale_created AFTER INSERT ON mystoreguard.msg_sales
            DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION mystoreguard.msg_wf_sale_trigger();
        ALTER TABLE mystoreguard.msg_sales ENABLE ALWAYS TRIGGER msg_wf_sale_created;
        DROP TRIGGER IF EXISTS msg_wf_sale_released ON mystoreguard.msg_sales;
        CREATE CONSTRAINT TRIGGER msg_wf_sale_released AFTER UPDATE OF fulfillment_status ON mystoreguard.msg_sales
            DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
            WHEN (NEW.fulfillment_status = 'FULFILLED' AND OLD.fulfillment_status IS DISTINCT FROM 'FULFILLED')
            EXECUTE FUNCTION mystoreguard.msg_wf_sale_trigger();
        ALTER TABLE mystoreguard.msg_sales ENABLE ALWAYS TRIGGER msg_wf_sale_released;
    END IF;
    IF to_regclass('mystoreguard.msg_installment_schedule') IS NOT NULL THEN
        DROP TRIGGER IF EXISTS msg_wf_instalment_overdue ON mystoreguard.msg_installment_schedule;
        CREATE CONSTRAINT TRIGGER msg_wf_instalment_overdue AFTER UPDATE OF status ON mystoreguard.msg_installment_schedule
            DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
            WHEN (NEW.status = 'OVERDUE' AND OLD.status IS DISTINCT FROM 'OVERDUE')
            EXECUTE FUNCTION mystoreguard.msg_wf_schedule_trigger();
        ALTER TABLE mystoreguard.msg_installment_schedule ENABLE ALWAYS TRIGGER msg_wf_instalment_overdue;
    END IF;
    IF to_regclass('mystoreguard.msg_batch_locations') IS NOT NULL THEN
        DROP TRIGGER IF EXISTS msg_wf_stock_low ON mystoreguard.msg_batch_locations;
        DROP TRIGGER IF EXISTS msg_wf_stock_low_out ON mystoreguard.msg_batch_locations;
        DROP TRIGGER IF EXISTS msg_wf_stock_low_in ON mystoreguard.msg_batch_locations;
        -- A change of a row's stock (a fall tells, a rise re-arms), a row leaving (a fall), a
        -- delivery arriving (re-arms).
        CREATE CONSTRAINT TRIGGER msg_wf_stock_low AFTER UPDATE OF qty ON mystoreguard.msg_batch_locations
            DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
            WHEN (NEW.qty IS DISTINCT FROM OLD.qty)
            EXECUTE FUNCTION mystoreguard.msg_wf_stock_trigger();
        CREATE CONSTRAINT TRIGGER msg_wf_stock_low_in AFTER INSERT ON mystoreguard.msg_batch_locations
            DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
            EXECUTE FUNCTION mystoreguard.msg_wf_stock_trigger();
        ALTER TABLE mystoreguard.msg_batch_locations ENABLE ALWAYS TRIGGER msg_wf_stock_low_in;
        ALTER TABLE mystoreguard.msg_batch_locations ENABLE ALWAYS TRIGGER msg_wf_stock_low;
        CREATE CONSTRAINT TRIGGER msg_wf_stock_low_out AFTER DELETE ON mystoreguard.msg_batch_locations
            DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
            EXECUTE FUNCTION mystoreguard.msg_wf_stock_trigger();
        ALTER TABLE mystoreguard.msg_batch_locations ENABLE ALWAYS TRIGGER msg_wf_stock_low_out;
    END IF;
END $$;

-- ============================================================================ LoanDrift
CREATE TABLE IF NOT EXISTS loandrift.ld_wf_event_state (
    kind       text NOT NULL,
    key        text NOT NULL,
    tenant_id  text NOT NULL,
    cdatetime  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (kind, key)
);

CREATE OR REPLACE FUNCTION loandrift.ld_wf_once(p_kind text, p_key text, p_tenant text)
RETURNS boolean LANGUAGE plpgsql AS $f$
BEGIN
    INSERT INTO loandrift.ld_wf_event_state (kind, key, tenant_id) VALUES (p_kind, p_key, p_tenant)
    ON CONFLICT DO NOTHING;
    RETURN FOUND;
END
$f$;

CREATE OR REPLACE FUNCTION loandrift.ld_wf_publish(p_tenant text, p_bus text, p_kind text, p_subject text, p_payload jsonb)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
    IF coalesce(p_tenant, '') = '' OR coalesce(p_bus, '') = '' THEN
        RETURN;
    END IF;
    PERFORM core_platform.cp_event_publish(p_tenant, p_bus, 'app-loandrift', p_kind, p_subject,
                                           jsonb_strip_nulls(coalesce(p_payload, '{}'::jsonb) || jsonb_build_object('v', 1)));
END
$f$;

CREATE OR REPLACE FUNCTION loandrift.ld_wf_money(v numeric) RETURNS text
LANGUAGE sql IMMUTABLE AS $f$ SELECT to_char(round(coalesce(v, 0), 2), 'FM9999999999999990.00') $f$;

-- A loan's facts for an event: who, what, how much, where. No contact, id or income details.
CREATE OR REPLACE FUNCTION loandrift.ld_wf_loan_facts(p_tenant text, p_loan text) RETURNS jsonb
LANGUAGE sql STABLE AS $f$
    SELECT jsonb_build_object(
        'loan_id', d.id, 'loan_reference', d.loan_reference, 'status', d.status,
        'client_id', d.client_id, 'client_name', c.fullname,
        'loan_type', coalesce((SELECT t.type_name FROM loandrift.ld_loan_types t
                                WHERE t.id = d.loan_type AND t.tenant_id = d.tenant_id LIMIT 1), d.loan_type),
        'payment_type', d.payment_type, 'repayment_count', lc.repayment_weeks,
        'requested_amount', loandrift.ld_wf_money(d.requested_amount),
        'approved_amount', CASE WHEN la.approved_amount IS NULL THEN NULL ELSE loandrift.ld_wf_money(la.approved_amount) END,
        'total_payable', CASE WHEN la.approved_amount IS NULL THEN NULL
                              ELSE loandrift.ld_wf_money(la.approved_amount + coalesce(cfi.interest_amount, 0)) END,
        'installment_amount', CASE WHEN lc.loan_repayment_amount IS NULL THEN NULL ELSE loandrift.ld_wf_money(lc.loan_repayment_amount) END,
        'first_payment_date', left(lc.first_payment_date::text, 10),
        'disbursement_date', left(dis.disbursement_date::text, 10), 'disbursement_mode', dis.mode,
        'currency', coalesce(
            (SELECT upper(cur.code) FROM core_platform.cp_currencies cur
              WHERE cur.tenant_id = d.tenant_id AND cur.id = d.currency_id LIMIT 1),
            (SELECT upper(cur.code) FROM core_platform.cp_currencies cur
              WHERE cur.tenant_id = d.tenant_id AND cur.is_default AND coalesce(cur.delete_status, 'NOT_DELETED') = 'NOT_DELETED'
              ORDER BY cur.cdatetime DESC NULLS LAST LIMIT 1)),
        'location_id', d.loc_id,
        'location_name', (SELECT l.loc_name FROM core_platform.cp_locations l WHERE l.id = d.loc_id AND l.tenant_id = d.tenant_id LIMIT 1))
      FROM loandrift.ld_loan_details d
      LEFT JOIN loandrift.ld_clients c ON c.id = d.client_id AND c.tenant_id = d.tenant_id
      LEFT JOIN loandrift.ld_loan_calculations lc ON lc.loan_id = d.id AND lc.tenant_id = d.tenant_id
      LEFT JOIN loandrift.ld_loan_approvals la ON la.loan_id = d.id AND la.tenant_id = d.tenant_id
      LEFT JOIN loandrift.ld_client_financial_info cfi ON cfi.loan_id = d.id AND cfi.tenant_id = d.tenant_id
      LEFT JOIN loandrift.ld_loan_disbursements dis ON dis.loan_id = d.id AND dis.tenant_id = d.tenant_id
     WHERE d.tenant_id = p_tenant AND d.id = p_loan
     LIMIT 1
$f$;

-- The latest live repayment's balance, else what is payable (nothing paid yet).
CREATE OR REPLACE FUNCTION loandrift.ld_wf_balance(p_tenant text, p_loan text) RETURNS numeric
LANGUAGE sql STABLE AS $f$
    SELECT (SELECT r.balance FROM loandrift.ld_repayments r
             WHERE r.tenant_id = p_tenant AND r.loan_id = p_loan AND r.delete_status = 'NOT_DELETED'
             ORDER BY r.cdatetime DESC LIMIT 1)
$f$;

CREATE OR REPLACE FUNCTION loandrift.ld_wf_loan_trigger() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE d record; k text; facts jsonb; bal numeric;
BEGIN
    BEGIN
        SELECT id, tenant_id, bus_id, status, delete_status INTO d FROM loandrift.ld_loan_details
         WHERE id = NEW.id AND tenant_id = NEW.tenant_id;
        IF NOT FOUND OR d.delete_status IS DISTINCT FROM 'NOT_DELETED' THEN
            RETURN NULL;
        END IF;
        IF TG_OP = 'INSERT' THEN
            k := 'loandrift.loan_applied';
            IF NOT loandrift.ld_wf_once(k, d.id, d.tenant_id) THEN RETURN NULL; END IF;
        ELSE
            -- Told only if it is still where this change put it when the transaction commits.
            IF d.status IS DISTINCT FROM NEW.status THEN
                RETURN NULL;
            END IF;
            IF NEW.status = 'APPROVED' THEN
                k := 'loandrift.loan_approved';
            ELSIF NEW.status IN ('DISBURSED', 'ACTIVE')
                  AND coalesce(OLD.status, '') NOT IN ('DISBURSED', 'ACTIVE', 'DEFAULTED', 'COMPLETED', 'WRITTEN_OFF') THEN
                k := 'loandrift.loan_disbursed';
                IF NOT loandrift.ld_wf_once(k, d.id, d.tenant_id) THEN RETURN NULL; END IF;
            ELSIF NEW.status = 'DEFAULTED' THEN
                k := 'loandrift.loan_defaulted';
            ELSIF NEW.status = 'COMPLETED' THEN
                k := 'loandrift.loan_repaid';
                IF NOT loandrift.ld_wf_once(k, d.id, d.tenant_id) THEN RETURN NULL; END IF;
            ELSE
                RETURN NULL;
            END IF;
        END IF;
        facts := loandrift.ld_wf_loan_facts(d.tenant_id, d.id);
        IF k IN ('loandrift.loan_defaulted', 'loandrift.loan_repaid') THEN
            bal := loandrift.ld_wf_balance(d.tenant_id, d.id);
            facts := facts || jsonb_build_object('balance', CASE WHEN bal IS NULL THEN facts->>'total_payable'
                                                                 ELSE loandrift.ld_wf_money(bal) END);
        END IF;
        IF TG_OP = 'UPDATE' THEN
            facts := facts || jsonb_build_object('from_status', OLD.status);
        END IF;
        PERFORM loandrift.ld_wf_publish(d.tenant_id, d.bus_id, k, d.id, facts);
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'loandrift workflow event (loan %): % (%)', NEW.id, SQLERRM, SQLSTATE;
    END;
    RETURN NULL;
END
$f$;

CREATE OR REPLACE FUNCTION loandrift.ld_wf_repayment_trigger() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE r record;
BEGIN
    BEGIN
        SELECT * INTO r FROM loandrift.ld_repayments WHERE id = NEW.id AND tenant_id = NEW.tenant_id;
        IF NOT FOUND OR r.delete_status IS DISTINCT FROM 'NOT_DELETED' THEN
            RETURN NULL;
        END IF;
        IF NOT loandrift.ld_wf_once('loandrift.repayment_received', r.id, r.tenant_id) THEN
            RETURN NULL;
        END IF;
        PERFORM loandrift.ld_wf_publish(r.tenant_id, r.bus_id, 'loandrift.repayment_received', r.id,
            coalesce(loandrift.ld_wf_loan_facts(r.tenant_id, r.loan_id), '{}'::jsonb) || jsonb_build_object(
                'repayment_id', r.id, 'amount', loandrift.ld_wf_money(r.paid_amount),
                'penalty_paid', loandrift.ld_wf_money(r.penalty_paid),
                'balance', loandrift.ld_wf_money(r.balance), 'payment_method', r.payment_method,
                'next_payment_date', left(r.next_payment_date::text, 10),
                'paid_off', coalesce(r.balance, 0) <= 0, 'date', left(r.cdatetime::text, 10)));
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'loandrift workflow event (repayment %): % (%)', NEW.id, SQLERRM, SQLSTATE;
    END;
    RETURN NULL;
END
$f$;

DO $$
BEGIN
    IF to_regclass('loandrift.ld_loan_details') IS NOT NULL THEN
        DROP TRIGGER IF EXISTS ld_wf_loan_created ON loandrift.ld_loan_details;
        CREATE CONSTRAINT TRIGGER ld_wf_loan_created AFTER INSERT ON loandrift.ld_loan_details
            DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION loandrift.ld_wf_loan_trigger();
        ALTER TABLE loandrift.ld_loan_details ENABLE ALWAYS TRIGGER ld_wf_loan_created;
        DROP TRIGGER IF EXISTS ld_wf_loan_status ON loandrift.ld_loan_details;
        CREATE CONSTRAINT TRIGGER ld_wf_loan_status AFTER UPDATE OF status ON loandrift.ld_loan_details
            DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
            WHEN (NEW.status IS DISTINCT FROM OLD.status)
            EXECUTE FUNCTION loandrift.ld_wf_loan_trigger();
        ALTER TABLE loandrift.ld_loan_details ENABLE ALWAYS TRIGGER ld_wf_loan_status;
    END IF;
    IF to_regclass('loandrift.ld_repayments') IS NOT NULL THEN
        DROP TRIGGER IF EXISTS ld_wf_repayment ON loandrift.ld_repayments;
        CREATE CONSTRAINT TRIGGER ld_wf_repayment AFTER INSERT ON loandrift.ld_repayments
            DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION loandrift.ld_wf_repayment_trigger();
        ALTER TABLE loandrift.ld_repayments ENABLE ALWAYS TRIGGER ld_wf_repayment;
    END IF;
END $$;

-- ============================================================================ event catalogue
DO $$
BEGIN
    IF to_regclass('core_platform.cp_event_schemas') IS NULL THEN
        RAISE NOTICE 'msg/ld workflow events: no event catalogue here (20261102-50 not applied); skipping its rows';
        RETURN;
    END IF;

    WITH s AS (
        SELECT '{"v":{"type":"integer","minimum":1},"sale_id":{"type":"string"},"sale_number":{"type":"string"},
                 "sale_mode":{"type":"string"},"channel":{"enum":["STORE","ONLINE"]},"status":{"type":"string"},
                 "fulfillment_status":{"type":"string"},"total":{"type":"string"},"goods_total":{"type":"string"},
                 "paid":{"type":"string"},"balance":{"type":"string"},"currency":{"type":"string"},
                 "customer_id":{"type":"string"},"customer_name":{"type":"string"},"location_id":{"type":"string"},
                 "location_name":{"type":"string"},"items":{"type":"integer"},"sale_date":{"type":"string","format":"date"},
                 "created_by":{"type":"string"}}'::jsonb AS p
    ), l AS (
        SELECT '{"v":{"type":"integer","minimum":1},"loan_id":{"type":"string"},"loan_reference":{"type":"string"},
                 "status":{"type":"string"},"from_status":{"type":"string"},"client_id":{"type":"string"},
                 "client_name":{"type":"string"},"loan_type":{"type":"string"},"payment_type":{"type":"string"},
                 "repayment_count":{"type":"integer"},"requested_amount":{"type":"string"},"approved_amount":{"type":"string"},
                 "total_payable":{"type":"string"},"installment_amount":{"type":"string"},
                 "first_payment_date":{"type":"string","format":"date"},"disbursement_date":{"type":"string","format":"date"},
                 "disbursement_mode":{"type":"string"},"currency":{"type":"string"},"location_id":{"type":"string"},
                 "location_name":{"type":"string"},"balance":{"type":"string"}}'::jsonb AS p
    ), kinds (kind, source_app, description, props, required) AS (
        SELECT 'mystoreguard.sale_recorded', 'app-mystoreguard', 'A sale was recorded (till, invoice, instalment or online).',
               (SELECT p FROM s), '["v","sale_id"]'::jsonb
        UNION ALL SELECT 'mystoreguard.online_order_placed', 'app-mystoreguard', 'A shopper placed an order on the online shop.',
               (SELECT p FROM s), '["v","sale_id"]'::jsonb
        UNION ALL SELECT 'mystoreguard.goods_released', 'app-mystoreguard', 'A sale''s goods were released (told once per sale).',
               (SELECT p FROM s) || '{"released_at":{"type":"string","format":"date-time"}}'::jsonb, '["v","sale_id"]'::jsonb
        UNION ALL SELECT 'mystoreguard.instalment_overdue', 'app-mystoreguard', 'An instalment-plan payment passed its due date unpaid (once per period).',
               '{"v":{"type":"integer","minimum":1},"schedule_id":{"type":"string"},"plan_id":{"type":"string"},
                 "period_no":{"type":"integer"},"term_count":{"type":"integer"},"frequency":{"type":"string"},
                 "plan_status":{"type":"string"},"due_date":{"type":"string","format":"date"},"days_overdue":{"type":"integer"},
                 "amount":{"type":"string"},"paid":{"type":"string"},"balance":{"type":"string"},"plan_balance":{"type":"string"},
                 "currency":{"type":"string"},"sale_id":{"type":"string"},"sale_number":{"type":"string"},
                 "customer_id":{"type":"string"},"customer_name":{"type":"string"},"location_id":{"type":"string"},
                 "location_name":{"type":"string"}}'::jsonb, '["v","schedule_id","plan_id","due_date"]'::jsonb
        UNION ALL SELECT 'mystoreguard.stock_low', 'app-mystoreguard', 'A product fell to or below its reorder level at a store or warehouse.',
               '{"v":{"type":"integer","minimum":1},"product_id":{"type":"string"},"product_name":{"type":"string"},
                 "location_type":{"enum":["STORE","WAREHOUSE"]},"location_id":{"type":"string"},"location_name":{"type":"string"},
                 "quantity":{"type":"number"},"reorder_level":{"type":"integer"},"reorder_quantity":{"type":"integer"},
                 "out_of_stock":{"type":"boolean"}}'::jsonb, '["v","product_id","location_id","quantity","reorder_level"]'::jsonb
        UNION ALL SELECT 'loandrift.loan_applied', 'app-loandrift', 'A loan application was registered.',
               (SELECT p FROM l), '["v","loan_id"]'::jsonb
        UNION ALL SELECT 'loandrift.loan_approved', 'app-loandrift', 'A loan was approved.',
               (SELECT p FROM l), '["v","loan_id"]'::jsonb
        UNION ALL SELECT 'loandrift.loan_disbursed', 'app-loandrift', 'A loan was disbursed (told once per loan).',
               (SELECT p FROM l), '["v","loan_id"]'::jsonb
        UNION ALL SELECT 'loandrift.repayment_received', 'app-loandrift', 'A repayment was recorded on a loan.',
               (SELECT p FROM l) || '{"repayment_id":{"type":"string"},"amount":{"type":"string"},"penalty_paid":{"type":"string"},
                                      "payment_method":{"type":"string"},"next_payment_date":{"type":"string","format":"date"},
                                      "paid_off":{"type":"boolean"},"date":{"type":"string","format":"date"}}'::jsonb,
               '["v","loan_id","repayment_id","amount"]'::jsonb
        UNION ALL SELECT 'loandrift.loan_defaulted', 'app-loandrift', 'A loan was marked defaulted.',
               (SELECT p FROM l), '["v","loan_id"]'::jsonb
        UNION ALL SELECT 'loandrift.loan_repaid', 'app-loandrift', 'A loan was fully repaid (told once per loan).',
               (SELECT p FROM l), '["v","loan_id"]'::jsonb
        UNION ALL SELECT 'loandrift.instalment_overdue', 'app-loandrift',
               'A loan instalment passed its due date unpaid (LoanDrift''s arrears rule; once per instalment and due date).',
               (SELECT p FROM l) || '{"installment_number":{"type":"integer"},"due_date":{"type":"string","format":"date"},
                                      "days_overdue":{"type":"integer"},"installment_due":{"type":"string"},
                                      "installment_unpaid":{"type":"string"},"arrears":{"type":"string"},
                                      "overdue_installments":{"type":"integer"}}'::jsonb,
               '["v","loan_id","installment_number","due_date"]'::jsonb
    )
    INSERT INTO core_platform.cp_event_schemas (kind, version, link_key, source_app, target_app, phase, description, schema, updated_at)
    SELECT k.kind, 1, 'suite-events', k.source_app, 'app-coreplatform', 1, k.description,
           jsonb_build_object('$schema', 'https://json-schema.org/draft/2020-12/schema', 'type', 'object',
                              'title', k.kind || ' v1', 'required', k.required, 'properties', k.props), now()
      FROM kinds k
    ON CONFLICT (kind, version) DO UPDATE SET
        link_key = EXCLUDED.link_key, source_app = EXCLUDED.source_app, target_app = EXCLUDED.target_app,
        phase = EXCLUDED.phase, description = EXCLUDED.description, schema = EXCLUDED.schema,
        updated_at = CASE WHEN core_platform.cp_event_schemas.schema IS DISTINCT FROM EXCLUDED.schema
                            OR core_platform.cp_event_schemas.description IS DISTINCT FROM EXCLUDED.description
                          THEN now() ELSE core_platform.cp_event_schemas.updated_at END;
END $$;

COMMIT;
