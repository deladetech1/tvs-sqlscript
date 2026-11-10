"""Do MyStoreGuard and LoanDrift tell the workflow designer, once, and never fail the change?

# WHY THIS EXISTS

20261110-35 publishes MyStoreGuard and LoanDrift lifecycle events (mystoreguard.*, loandrift.*)
from deferred triggers. This writes synthetic rows under a made-up tenant into a THROWAWAY
database that has the app schemas and 20261110-35 applied, COMMITS for real (the triggers fire at
commit), and checks after each step:

  - the step published exactly the events it should, once, with "v": 1 and the facts a workflow
    tests (totals, statuses, names) -- and none of the sensitive ones (phone, email, codes);
  - a status that moved on again inside the same transaction publishes nothing;
  - a failed publish (cp_events refusing the row) never fails the change: the change commits,
    no event, no half-written state.

FKs are skipped with session_replication_role = replica (the triggers are ENABLE ALWAYS, so they
still fire, as they do for replica-role writers in production). Everything written is deleted at
the end.

Run (the DSN must be a throwaway database; it COMMITS):

    python3 scripts/test_msg_ld_workflow_events.py "host=127.0.0.1 port=5432 user=debrah dbname=wf3_events"
"""
import json
import sys
import uuid

import psycopg2
from psycopg2.extras import RealDictCursor

DSN = sys.argv[1]
T = "wftest_" + uuid.uuid4().hex[:8]
ORG, BUS, LOC = T + "_org", T + "_bus", T + "_loc"
fails, passes = [], 0


def check(label, ok, detail=""):
    global passes
    print(f"  {'PASS' if ok else 'FAIL'}  {label}" + ("" if ok else f": {detail}"))
    if ok:
        passes += 1
    else:
        fails.append(label)


def tx(*statements):
    """One transaction: the statements, then COMMIT (the deferred triggers fire here)."""
    with psycopg2.connect(DSN) as c, c.cursor() as cur:
        cur.execute("SET session_replication_role = replica")
        for s in statements:
            if isinstance(s, tuple):
                cur.execute(*s)
            else:
                cur.execute(s)


def q(sql, params=()):
    with psycopg2.connect(DSN) as c, c.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, params)
        return [dict(r) for r in cur.fetchall()] if cur.description else []


_seen = 0


def new_events():
    """Events of the test tenant since the last call."""
    global _seen
    rows = q("SELECT id, kind, subject_id, source_app, bus_id, payload FROM core_platform.cp_events "
             "WHERE tenant_id = %s AND id > %s AND kind ~ '^(mystoreguard|loandrift)\\.' ORDER BY id", (T, _seen))
    if rows:
        _seen = rows[-1]["id"]
    return rows


def kinds(rows):
    return sorted(r["kind"] for r in rows)


SENSITIVE = ("phone", "email", "contact", "gift_card_code", "id_number", "address", "salary", "description", "notes")


def clean(rows):
    return all(not any(s in json.dumps(r["payload"]) for s in SENSITIVE) for r in rows)


def setup():
    tx(("INSERT INTO core_platform.cp_locations (tenant_id, id, loc_name) VALUES (%s, %s, 'Osu branch')", (T, LOC)),
       ("INSERT INTO core_platform.cp_currencies (tenant_id, id, name, code, symbol, is_default) "
        "VALUES (%s, %s, 'Cedi', 'ghs', 'GH₵', true)", (T, T + "_cur")),
       # msg_customers is a view over Core's shared parties.
       ("INSERT INTO core_platform.cp_parties (tenant_id, org_id, bus_id, id, name, phone, email, is_customer, source_app) "
        "VALUES (%s, %s, %s, 'cus1', 'Ama Mensah', '0240000000', 'ama@example.com', true, 'mystoreguard')", (T, ORG, BUS)),
       ("INSERT INTO loandrift.ld_clients (tenant_id, org_id, bus_id, loc_id, id, fullname, contact, email) "
        "VALUES (%s, %s, %s, %s, 'cl1', 'Kofi Boateng', '0550000000', 'kofi@example.com')", (T, ORG, BUS, LOC)))
    new_events()


def sale_sql(sid, mode, fulfil, description="Till sale", status="PAID", total=1250):
    return ("INSERT INTO mystoreguard.msg_sales (tenant_id, org_id, bus_id, loc_id, id, sale_number, sale_mode, status, "
            "fulfillment_status, description, total_amount, payable_amount, paid_amount, balance_amount, customer_id, sale_date) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'cus1', CURRENT_DATE)",
            (T, ORG, BUS, LOC, sid, "S-" + sid, mode, status, fulfil, description, total, total,
             total if status == "PAID" else 0, 0 if status == "PAID" else total))


def test_msg_sales():
    print("MyStoreGuard sales")
    tx(sale_sql("s1", "INSTANT", "FULFILLED"))
    ev = new_events()
    check("a till sale: sale_recorded + goods_released", kinds(ev) == ["mystoreguard.goods_released", "mystoreguard.sale_recorded"], kinds(ev))
    rec = next((e for e in ev if e["kind"] == "mystoreguard.sale_recorded"), {"payload": {}})
    p = rec["payload"]
    check("payload v1 with the facts", p.get("v") == 1 and p.get("total") == "1250.00" and p.get("customer_name") == "Ama Mensah"
          and p.get("currency") == "GHS" and p.get("location_name") == "Osu branch" and p.get("channel") == "STORE", p)
    check("source app and business", rec.get("source_app") == "app-mystoreguard" and rec.get("bus_id") == BUS, rec)
    check("no phone, email or notes", clean(ev), ev)

    tx(sale_sql("s2", "INSTANT", "PENDING", description="Online order · Ama Mensah", status="QUEUED"))
    ev = new_events()
    check("an online order: sale_recorded + online_order_placed, goods not released",
          kinds(ev) == ["mystoreguard.online_order_placed", "mystoreguard.sale_recorded"], kinds(ev))
    tx("UPDATE mystoreguard.msg_sales SET fulfillment_status = 'FULFILLED' WHERE id = 's2'")
    ev = new_events()
    check("released later: goods_released", kinds(ev) == ["mystoreguard.goods_released"], kinds(ev))
    tx("UPDATE mystoreguard.msg_sales SET fulfillment_status = 'PENDING' WHERE id = 's2'",
       "UPDATE mystoreguard.msg_sales SET fulfillment_status = 'FULFILLED' WHERE id = 's2'")
    check("released again: never twice", kinds(new_events()) == [])

    tx(sale_sql("s3", "INSTANT", "FULFILLED"), "UPDATE mystoreguard.msg_sales SET status = 'CANCELLED' WHERE id = 's3'")
    check("a sale cancelled in its own transaction: nothing", kinds(new_events()) == [])


def test_msg_instalments():
    print("MyStoreGuard instalments")
    tx(sale_sql("s4", "INSTALLMENT", "PENDING", status="PARTIALLY_PAID"))
    new_events()
    tx(("INSERT INTO mystoreguard.msg_installment_plans (tenant_id, org_id, bus_id, loc_id, id, sale_id, start_date, term_count, "
        "frequency, policy_snapshot, policy_id, status, total_payable, goods_amount, financed_amount, amount_paid) "
        "VALUES (%s, %s, %s, %s, 'pl1', 's4', CURRENT_DATE - 40, 3, 'MONTHLY', '{}', 'pol1', 'ACTIVE', 900, 900, 900, 300)", (T, ORG, BUS, LOC)),
       ("INSERT INTO mystoreguard.msg_installment_schedule (tenant_id, org_id, bus_id, loc_id, id, plan_id, period_no, due_date, amount, "
        "paid_amount, status) VALUES (%s, %s, %s, %s, 'sc1', 'pl1', 2, CURRENT_DATE - 3, 300, 100, 'PARTIALLY_PAID')", (T, ORG, BUS, LOC)))
    check("a new period: nothing", kinds(new_events()) == [])
    tx("UPDATE mystoreguard.msg_installment_schedule SET status = 'OVERDUE' WHERE id = 'sc1'")
    ev = new_events()
    check("turned OVERDUE: instalment_overdue", kinds(ev) == ["mystoreguard.instalment_overdue"], kinds(ev))
    p = ev[0]["payload"] if ev else {}
    check("its facts", p.get("days_overdue") == 3 and p.get("balance") == "200.00" and p.get("plan_balance") == "600.00"
          and p.get("customer_name") == "Ama Mensah" and p.get("sale_number") == "S-s4" and p.get("period_no") == 2, p)
    tx("UPDATE mystoreguard.msg_installment_schedule SET status = 'PARTIALLY_PAID' WHERE id = 'sc1'",
       "UPDATE mystoreguard.msg_installment_schedule SET status = 'OVERDUE' WHERE id = 'sc1'")
    check("the same period and due date again: never twice", kinds(new_events()) == [])


def test_msg_stock():
    print("MyStoreGuard stock")
    # msg_products is a view over Core's shared products and MyStoreGuard's profile of them.
    tx(("INSERT INTO core_platform.cp_products (tenant_id, org_id, bus_id, id, name, sku) VALUES (%s, %s, %s, 'p1', 'Rice 5kg', 'R5')", (T, ORG, BUS)),
       ("INSERT INTO mystoreguard.msg_product_profiles (tenant_id, org_id, bus_id, product_id) VALUES (%s, %s, %s, 'p1')", (T, ORG, BUS)),
       ("INSERT INTO mystoreguard.msg_store_products (tenant_id, org_id, bus_id, loc_id, product_id, current_qty, reorder_level, reorder_quantity) "
        "VALUES (%s, %s, %s, %s, 'p1', 0, 5, 20)", (T, ORG, BUS, LOC)),
       ("INSERT INTO mystoreguard.msg_purchase_batches (tenant_id, org_id, bus_id, id, product_id, batch_number, currency_id, qty_received, "
        "qty_remaining_for_purchase_order, qty_remaining, status, cdate, ctime) "
        "VALUES (%s, %s, %s, 'b1', 'p1', 'B1', 'c', 10, 0, 10, 'RECEIVED', '2026-11-10', '10:00')", (T, ORG, BUS)),
       ("INSERT INTO mystoreguard.msg_batch_locations (tenant_id, org_id, bus_id, id, loc_id, location_type, purchase_batche_id, qty) "
        "VALUES (%s, %s, %s, 'bl1', %s, 'STORE', 'b1', 10)", (T, ORG, BUS, LOC)))
    check("a delivery of 10 (level 5): nothing", kinds(new_events()) == [])
    tx("UPDATE mystoreguard.msg_batch_locations SET qty = 6 WHERE id = 'bl1'")
    check("down to 6: nothing", kinds(new_events()) == [])
    tx("UPDATE mystoreguard.msg_batch_locations SET qty = 5 WHERE id = 'bl1'")
    ev = new_events()
    check("down to 5 (at the level): stock_low", kinds(ev) == ["mystoreguard.stock_low"], kinds(ev))
    p = ev[0]["payload"] if ev else {}
    check("its facts", p.get("quantity") == 5 and p.get("reorder_level") == 5 and p.get("product_name") == "Rice 5kg"
          and p.get("location_type") == "STORE" and p.get("out_of_stock") is False, p)
    tx("UPDATE mystoreguard.msg_batch_locations SET qty = 3 WHERE id = 'bl1'")
    check("down to 3: never twice", kinds(new_events()) == [])
    tx("UPDATE mystoreguard.msg_batch_locations SET qty = 4 WHERE id = 'bl1'")
    check("up to 4, still low: nothing", kinds(new_events()) == [])
    tx("UPDATE mystoreguard.msg_batch_locations SET qty = 12 WHERE id = 'bl1'")
    check("restocked to 12: nothing", kinds(new_events()) == [])
    tx("UPDATE mystoreguard.msg_batch_locations SET qty = 2 WHERE id = 'bl1'")
    check("straight down to 2 after the restock: told again", kinds(new_events()) == ["mystoreguard.stock_low"])
    tx("UPDATE mystoreguard.msg_batch_locations SET qty = 9 WHERE id = 'bl1'",
       "UPDATE mystoreguard.msg_batch_locations SET qty = 1 WHERE id = 'bl1'")
    check("up and down again inside one transaction: still low at commit, never twice", kinds(new_events()) == [])
    tx("UPDATE mystoreguard.msg_batch_locations SET qty = 9 WHERE id = 'bl1'")
    tx("DELETE FROM mystoreguard.msg_batch_locations WHERE id = 'bl1'")
    ev = new_events()
    check("restocked, then the row leaves: out of stock is told",
          kinds(ev) == ["mystoreguard.stock_low"] and ev[0]["payload"].get("out_of_stock") is True, ev)


def loan_sql(lid, status="REGISTERED"):
    return ("INSERT INTO loandrift.ld_loan_details (tenant_id, org_id, bus_id, loc_id, id, client_id, status, requested_amount, "
            "payment_type, delete_status, loan_reference, currency_id) VALUES (%s, %s, %s, %s, %s, 'cl1', %s, 5000, 'MONTHLY', "
            "'NOT_DELETED', %s, %s)", (T, ORG, BUS, LOC, lid, status, "LN-" + lid, T + "_cur"))


def status(lid, s):
    return (f"UPDATE loandrift.ld_loan_details SET status = '{s}' WHERE id = '{lid}' AND tenant_id = '{T}'")


def test_ld_loans():
    print("LoanDrift loans")
    tx(loan_sql("ln1"),
       ("INSERT INTO loandrift.ld_loan_calculations (tenant_id, org_id, bus_id, loc_id, loan_id, repayment_weeks, loan_repayment_amount, "
        "first_payment_date) VALUES (%s, %s, %s, %s, 'ln1', 6, 1000, '2026-12-01')", (T, ORG, BUS, LOC)))
    ev = new_events()
    check("registered: loan_applied", kinds(ev) == ["loandrift.loan_applied"], kinds(ev))
    p = ev[0]["payload"] if ev else {}
    check("its facts (read at commit: the calculation written after the loan)",
          p.get("v") == 1 and p.get("client_name") == "Kofi Boateng" and p.get("requested_amount") == "5000.00"
          and p.get("installment_amount") == "1000.00" and p.get("repayment_count") == 6 and p.get("currency") == "GHS", p)
    check("no contact or email", clean(ev), ev)
    check("source app", ev and ev[0]["source_app"] == "app-loandrift", ev)

    tx(status("ln1", "CAPTURED"))
    check("captured: nothing", kinds(new_events()) == [])
    tx(status("ln1", "APPROVED"), status("ln1", "CAPTURED"))
    check("approved then sent back in one transaction: nothing", kinds(new_events()) == [])
    tx(status("ln1", "APPROVED"),
       ("INSERT INTO loandrift.ld_loan_approvals (tenant_id, org_id, bus_id, loc_id, loan_id, approved_amount) "
        "VALUES (%s, %s, %s, %s, 'ln1', 5000)", (T, ORG, BUS, LOC)),
       ("INSERT INTO loandrift.ld_client_financial_info (tenant_id, org_id, bus_id, loc_id, loan_id, interest_amount) "
        "VALUES (%s, %s, %s, %s, 'ln1', 1000)", (T, ORG, BUS, LOC)))
    ev = new_events()
    check("approved: loan_approved with the approved amount", kinds(ev) == ["loandrift.loan_approved"]
          and ev[0]["payload"].get("approved_amount") == "5000.00" and ev[0]["payload"].get("total_payable") == "6000.00"
          and ev[0]["payload"].get("from_status") == "CAPTURED", ev)
    tx(status("ln1", "DISBURSED"))
    check("disbursed: loan_disbursed", kinds(new_events()) == ["loandrift.loan_disbursed"])
    tx(("INSERT INTO loandrift.ld_repayments (tenant_id, org_id, bus_id, loc_id, id, client_id, loan_id, paid_amount, balance, "
        "payment_method, penalty_paid, delete_status, next_payment_date) "
        "VALUES (%s, %s, %s, %s, 'rp1', 'cl1', 'ln1', 1000, 5000, 'MOMO', 0, 'NOT_DELETED', '2027-01-01')", (T, ORG, BUS, LOC)),
       status("ln1", "ACTIVE"))
    ev = new_events()
    check("first repayment (DISBURSED -> ACTIVE): repayment_received only", kinds(ev) == ["loandrift.repayment_received"], kinds(ev))
    p = ev[0]["payload"] if ev else {}
    check("repayment facts", p.get("amount") == "1000.00" and p.get("balance") == "5000.00" and p.get("payment_method") == "MOMO"
          and p.get("loan_reference") == "LN-ln1" and p.get("paid_off") is False, p)
    tx(status("ln1", "DEFAULTED"))
    ev = new_events()
    check("defaulted (the cron): loan_defaulted with the balance", kinds(ev) == ["loandrift.loan_defaulted"]
          and ev[0]["payload"].get("balance") == "5000.00", ev)
    tx(status("ln1", "ACTIVE"))
    check("recovered (the gate): nothing, and not 'disbursed' again", kinds(new_events()) == [])
    tx(status("ln1", "DEFAULTED"))
    check("defaulted again: told again", kinds(new_events()) == ["loandrift.loan_defaulted"])
    tx(status("ln1", "COMPLETED"))
    check("completed: loan_repaid", kinds(new_events()) == ["loandrift.loan_repaid"])
    tx(status("ln1", "ACTIVE"), status("ln1", "COMPLETED"))
    check("completed again: never twice", kinds(new_events()) == [])


def test_failed_publish_never_fails_the_change():
    print("A failed publish")
    q("ALTER TABLE core_platform.cp_events ADD CONSTRAINT wftest_refuse CHECK (tenant_id <> '" + T + "' OR kind !~ '^(mystoreguard|loandrift)[.]') NOT VALID")
    try:
        tx(sale_sql("s9", "INSTANT", "FULFILLED"), loan_sql("ln9"))
        check("the sale and the loan still committed",
              len(q("SELECT 1 FROM mystoreguard.msg_sales WHERE tenant_id = %s AND id = 's9'", (T,))) == 1
              and len(q("SELECT 1 FROM loandrift.ld_loan_details WHERE tenant_id = %s AND id = 'ln9'", (T,))) == 1)
        check("no event", kinds(new_events()) == [])
        check("no half-written state (the savepoint took it back)",
              not q("SELECT 1 FROM mystoreguard.msg_wf_event_state WHERE key = 's9'")
              and not q("SELECT 1 FROM loandrift.ld_wf_event_state WHERE key = 'ln9'"))
    finally:
        q("ALTER TABLE core_platform.cp_events DROP CONSTRAINT IF EXISTS wftest_refuse")


def cleanup():
    tables = ["mystoreguard.msg_sales", "mystoreguard.msg_installment_plans", "mystoreguard.msg_installment_schedule",
              "mystoreguard.msg_product_profiles", "core_platform.cp_products", "mystoreguard.msg_store_products", "mystoreguard.msg_purchase_batches",
              "mystoreguard.msg_batch_locations", "core_platform.cp_parties", "mystoreguard.msg_wf_event_state",
              "loandrift.ld_loan_details", "loandrift.ld_loan_calculations", "loandrift.ld_loan_approvals",
              "loandrift.ld_client_financial_info", "loandrift.ld_repayments", "loandrift.ld_clients",
              "loandrift.ld_wf_event_state", "core_platform.cp_events", "core_platform.cp_locations",
              "core_platform.cp_currencies", "mystoreguard.msg_acc_sale_state", "mystoreguard.msg_acc_payment_state",
              "mystoreguard.msg_acc_document_state"]
    stmts = [f"DELETE FROM {t} WHERE tenant_id = '{T}'" for t in tables]
    with psycopg2.connect(DSN) as c, c.cursor() as cur:
        cur.execute("SET session_replication_role = replica")
        for s in stmts:
            try:
                cur.execute("SAVEPOINT x")
                cur.execute(s)
                cur.execute("RELEASE SAVEPOINT x")
            except psycopg2.Error:
                cur.execute("ROLLBACK TO SAVEPOINT x")


if __name__ == "__main__":
    try:
        setup()
        test_msg_sales()
        test_msg_instalments()
        test_msg_stock()
        test_ld_loans()
        test_failed_publish_never_fails_the_change()
    finally:
        cleanup()
    print(f"\n{passes} passed, {len(fails)} failed" + (": " + ", ".join(fails) if fails else ""))
    sys.exit(1 if fails else 0)
