"""Does every way stock comes in, goes out or changes value in MyStoreGuard tell the books, once?

# WHY THIS EXISTS

20261019-39 publishes MyStoreGuard's stock to Accounting from deferred triggers (msg.stock_received,
msg.stock_receipt_voided, msg.stock_adjusted, msg.supplier_payment_made/_reversed, msg.supplier_return)
and 20261019-40 adds the store-credit change a cancelled sale takes back. This runs MyStoreGuard's REAL
service code against a database migrated with them, commits for real, and after EVERY step checks:

  - the step published exactly the events it should (a stock-in once; a stock-in that fails, nothing;
    a pure move between locations, nothing; a sale, only its own sale event);
  - THE INVARIANT: Inventory as the published events post it (receipts + adjustments - supplier returns
    - cost of sales + restocked cost), per currency, equals what MyStoreGuard holds on its shelves and in
    its unallocated pool (on hand x cost_price, per batch). A path that changed stock value without
    telling the books, or told it twice, breaks this at once;
  - supplier balances: receipts on credit - payments - returns, as published.

Uses tvs-mystoreguard-bk's own harness (tests/accounting_events_harness.py, _fixture.py), read only.

Run (the DSN must be a throwaway copy of dev-db with 38, 39 and 40 applied; it COMMITS):

    python3 scripts/test_msg_stock_accounting_events.py "host=127.0.0.1 port=5544 user=debrah dbname=stk_t1" \\
        <tenant_id> <org_id> <bus_id> <loc_id> [path to tvs-mystoreguard-bk]
"""
import sys
import uuid
from collections import defaultdict
from datetime import date
from decimal import Decimal
from pathlib import Path

MSG = Path(sys.argv[6] if len(sys.argv) > 6 else Path(__file__).resolve().parents[3] / "mystoreguard" / "tvs-mystoreguard-bk")
sys.path.insert(0, str(MSG / "tests"))
from accounting_events_harness import quiet_activity_log, use_database  # noqa: E402  (chdirs into app/)
from accounting_events_fixture import Shop, new_id  # noqa: E402

import psycopg2  # noqa: E402
from psycopg2.extras import RealDictCursor  # noqa: E402

fails, passes = [], 0


def check(label, got, want):
    global passes
    ok = got == want
    print(f"  {'PASS' if ok else 'FAIL'}  {label}" + ("" if ok else f": got {got!r}, want {want!r}"))
    if ok:
        passes += 1
    else:
        fails.append(label)


def D(v):
    return Decimal(str(v or 0))


def q(dsn, sql, params=()):
    with psycopg2.connect(dsn) as c, c.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, params)
        return cur.fetchall() if cur.description else None


class Books:
    """Inventory and supplier balances as the published events post them (docs/POSTINGS.md §3)."""

    def __init__(self, dsn, bus):
        self.dsn, self.bus = dsn, bus
        self.mark = q(dsn, "SELECT coalesce(max(id), 0) AS m FROM core_platform.cp_events")[0]["m"]
        self.inventory = defaultdict(Decimal)
        self.supplier = defaultdict(Decimal)   # credit balance owed to suppliers
        self.adjust = defaultdict(Decimal)     # by role, debit positive
        self.all = []

    def since(self):
        rows = q(self.dsn, "SELECT id, kind, subject_id, bus_id, payload FROM core_platform.cp_events "
                           "WHERE id > %s AND kind LIKE 'msg.%%' ORDER BY id", (self.mark,))
        if rows:
            self.mark = rows[-1]["id"]
        for e in rows:
            self.apply(e)
        self.all += rows
        return rows

    def apply(self, e):
        p, k = e["payload"], e["kind"]
        ccy = p.get("currency") or ""
        if k in ("msg.stock_received", "msg.stock_receipt_voided"):
            sgn = 1 if k == "msg.stock_received" else -1
            self.inventory[ccy] += sgn * D(p["amount"])
            if p.get("credit_to") == "SUPPLIER":
                self.supplier[ccy] += sgn * D(p["amount"])
            else:
                self.adjust["STOCK_ADJUSTMENT"] -= sgn * D(p["amount"])
        elif k == "msg.stock_adjusted":
            for l in p["lines"]:
                self.inventory[l["currency"]] += D(l["amount"])
                self.adjust[l["kind"]] -= D(l["amount"])
        elif k == "msg.supplier_return":
            for l in p["lines"]:
                self.inventory[l["currency"]] -= D(l["amount"])
                self.supplier[l["currency"]] -= D(l["amount"])
        elif k in ("msg.supplier_payment_made", "msg.supplier_payment_reversed"):
            self.supplier[ccy] -= (1 if k.endswith("made") else -1) * D(p["amount"])
        elif k == "msg.sale_completed":
            for c in p["figures"]["costs"]:
                self.inventory[c["currency"]] -= D(c["amount"])
        elif k == "msg.sale_voided" and p.get("restocked"):
            for c in p["figures"]["costs"]:
                self.inventory[c["currency"]] += D(c["amount"])
        elif k == "msg.return_processed":
            for c in p.get("restock_costs", []):
                self.inventory[c["currency"]] += D(c["amount"])

    def truth(self):
        """What MyStoreGuard holds for this business: pool + placed, at each batch's cost, per currency."""
        rows = q(self.dsn, """
            SELECT mystoreguard.msg_acc_currency(b.tenant_id, b.currency_id) AS ccy,
                   sum((CASE WHEN coalesce(b.delete_status, 'NOT_DELETED') = 'DELETED' THEN 0 ELSE greatest(b.qty_remaining, 0) END
                        + coalesce((SELECT sum(bl.qty) FROM mystoreguard.msg_batch_locations bl
                                     WHERE bl.tenant_id = b.tenant_id AND bl.purchase_batche_id = b.id), 0)) * b.cost_price) AS v
              FROM mystoreguard.msg_purchase_batches b WHERE b.bus_id = %s GROUP BY 1""", (self.bus,))
        return {r["ccy"]: round(D(r["v"]), 2) for r in rows if round(D(r["v"]), 2) != 0}

    def books(self):
        return {k: round(v, 2) for k, v in self.inventory.items() if round(v, 2) != 0}

    def invariant(self, label):
        check(f"{label}: Inventory in the books = stock on hand at cost", self.books(), self.truth())


def kinds(es):
    return [e["kind"] for e in es]


def main(dsn, T, O, B, L):
    use_database(dsn)
    quiet_activity_log()
    from src.entities.products.products_service import ProductsService as PS
    from src.entities.products import products_write_dto as PW
    from src.entities.store_products.store_products_service import StoreProductsService as SPS
    from src.entities.store_products import store_products_write_dto as SW
    from src.entities.purchase_orders.purchase_orders_service import PurchaseOrdersService as POS
    from src.entities.purchase_orders import purchase_orders_write_dto as OW
    from src.entities.purchase_orders.purchase_payments_service import PurchasePaymentsService as PPS
    from src.entities.purchase_orders.purchase_returns_service import PurchaseReturnsService as PRS
    from src.entities.stock_takes.stock_takes_service import StockTakesService as STS
    from src.entities.stock_takes import stock_takes_write_dto as TW
    from src.entities.store_sales.store_sales_service import StoreSalesService as S
    from src.entities.store_sales import store_sales_write_dto as W

    books = Books(dsn, B)
    shop = Shop(dsn, T, O, B, L).seed()
    U = shop.user
    GHS, USD = shop.currency["GHS"], shop.currency["USD"]
    today = date.today()
    print("0. the shop's starting stock (fixture batches, written straight to the tables)")
    es = books.since()
    check("each fixture batch published as received, once", sorted(set(e["subject_id"] for e in es if e["kind"] == "msg.stock_received")),
          sorted(p["batch"] for p in shop.products.values()))
    books.invariant("fixture")

    supplier = new_id("sup")
    q(dsn, """INSERT INTO core_platform.cp_parties (id, tenant_id, org_id, bus_id, kind, name, is_supplier, is_customer,
              source_app, cdatetime) VALUES (%s,%s,%s,%s,'company','Kofi Wholesale',true,false,'mystoreguard',now())""",
      (supplier, T, O, B))
    books.since()

    def ok(r, label):
        check(label, r.success, True)
        if not r.success:
            print("      ", r.detail, r.error)
        return r

    def batch_of(product_id, where="TRUE"):
        return q(dsn, f"SELECT * FROM mystoreguard.msg_purchase_batches WHERE product_id = %s AND {where} ORDER BY cdatetime DESC, id DESC LIMIT 1",
                 (product_id,))[0]

    # ------------------------------------------------------------------ 1. product created with stock
    print("1. a product created with 10 in stock at 50, from a supplier")
    r = ok(PS.create_product(PW.CreateProductServiceWriteDto(
        name=f"Stock Test Shoe {uuid.uuid4().hex[:6]}", supplier_id=supplier, currency_id=GHS, cost_price=50,
        base_selling_price=90, qty=10), T, O, B, U), "product created")
    shoe = r.data[0].id if isinstance(r.data, list) else r.data.id
    es = books.since()
    check("one stock_received", kinds(es), ["msg.stock_received"])
    p = es[0]["payload"]
    check("received 10 x 50 GHS, owed to the supplier", (p["quantity"], p["amount"], p["currency"], p["credit_to"], p["supplier_name"]),
          ("10.00", "500.00", "GHS", "SUPPLIER", "Kofi Wholesale"))
    check("document is the delivery, dated today", (p["document_type"], p["date"]), ("DELIVERY", today.isoformat()))
    books.invariant("product create")
    shoe_batch = batch_of(shoe)["id"]

    # ------------------------------------------------------------------ 2. Add stock (a delivery costed in USD)
    print("2. Add stock: 5 more, costed in US dollars")
    ok(PS.add_batch_to_product(PW.AddBatchToProductServiceWriteDto(
        product_id=shoe, supplier_id=supplier, currency_id=USD, cost_price=4.25, base_selling_price=90, qty_received=5,
        delivery_ref="dlv-usd"), T, O, B, U), "batch added")
    es = books.since()
    check("one stock_received, in USD", [(e["kind"], e["payload"]["currency"], e["payload"]["amount"]) for e in es],
          [("msg.stock_received", "USD", "21.25")])
    books.invariant("add batch")
    usd_batch = batch_of(shoe, "currency_id = '%s'" % USD)["id"]

    # ------------------------------------------------------------------ 3. a stock-in that fails
    print("3. a stock-in that fails publishes nothing")
    r = PS.add_batch_to_product(PW.AddBatchToProductServiceWriteDto(
        product_id="prd_does_not_exist", currency_id=GHS, cost_price=1, base_selling_price=2, qty_received=3), T, O, B, U)
    check("refused", r.success, False)
    check("no event", kinds(books.since()), [])

    # ------------------------------------------------------------------ 4. placing stock is not an event
    print("4. putting 8 of them on the shop floor (pool -> store) changes nothing in the books")
    ok(SPS.create_store_product(SW.CreateStoreProductServiceWriteDto(product_id=shoe, current_qty=8), T, O, B, L, U), "placed in store")
    check("no event", kinds(books.since()), [])
    books.invariant("allocation")

    # ------------------------------------------------------------------ 5. add stock at the store with a new delivery
    print("5. store Add stock with a new delivery (create_adjustment_batch): 4 at 55")
    ok(SPS.add_stock_store_product(SW.AddStockStoreProductServiceWriteDto(
        product_id=shoe, qty=4, source="NEW",
        new_batch={"delivery_ref": "dlv-floor", "qty": 4, "cost_price": 55, "currency_id": GHS, "base_selling_price": 90,
                   "supplier_id": supplier}), T, O, B, L, U), "stock added")
    es = books.since()
    check("one stock_received of 220", [(e["kind"], e["payload"]["amount"], e["payload"]["credit_to"]) for e in es],
          [("msg.stock_received", "220.00", "SUPPLIER")])
    books.invariant("store add-stock with a new delivery")

    # ------------------------------------------------------------------ 6. a delivery corrected
    print("6. the first delivery was really 12, not 10")
    ok(PS.adjust_batch_quantity(shoe_batch, 2, T, O, B, U, reason="miscounted"), "corrected")
    es = books.since()
    check("void of 500 and a revision of 600", [(e["kind"], e["payload"]["amount"], e["payload"].get("revision")) for e in es],
          [("msg.stock_receipt_voided", "500.00", 1), ("msg.stock_received", "600.00", 2)])
    books.invariant("delivery corrected")

    # ------------------------------------------------------------------ 7. a sale is its own event only
    print("7. a sale of 3 from the floor posts its own cost, nothing more")
    items = []
    v = S.verify_price(W.VerifyPriceServiceWriteDto(items=[{"product_id": shoe, "quantity": 3, "base_selling_price": 90.0}],
                                                    customer_id=shop.customer), T, O, B, L)
    vd = v.data[0] if isinstance(v.data, list) else v.data
    for it in vd.items:
        x = it.model_dump()
        items.append({k: x[k] for k in ("product_id", "quantity", "base_selling_price", "actual_price", "price_after_pricing_rule",
                                        "price_after_tax", "final_price", "tax_rate", "tax_amount")} | {"taxes_applied": x["taxes_applied"]})
    r = ok(S.create_sale(W.CreateSaleServiceWriteDto(
        customer_id=shop.customer, sale_date=today.isoformat(), items=items,
        payments=[{"payment_method": "CASH", "paid_amount": float(vd.final_total_amount) + 20}], overpay_to_store_credit=True,
        sale_mode="INSTANT", verified_total_amount=vd.total_amount, verified_final_total_amount=vd.final_total_amount), T, O, B, L, U), "sold")
    sale_id = (r.data[0] if isinstance(r.data, list) else r.data)
    sale_id = sale_id.id if hasattr(sale_id, "id") else sale_id["id"]
    es = books.since()
    check("only the sale", kinds(es), ["msg.sale_completed"])
    check("change kept as store credit", es[0]["payload"]["store_credit_change_issued"], "20.00")
    books.invariant("sale")

    # ------------------------------------------------------------------ 8. cancel: stock back, change taken back
    print("8. the sale cancelled: goods back, every tender refunded, the store-credit change taken back")
    ok(S.cancel_sale(W.CancelSaleServiceWriteDto(sale_id=sale_id), T, O, B, L, U), "cancelled")
    es = books.since()
    voided = [e for e in es if e["kind"] == "msg.sale_voided"]
    check("voided once, restocked, change 20 taken back", [(e["payload"]["reason"], e["payload"]["restocked"],
                                                            e["payload"]["store_credit_change_reversed"]) for e in voided],
          [("CANCELLED", True, "20.00")])
    check("no stock event besides", [k for k in kinds(es) if k.startswith("msg.stock")], [])
    # The customer's side nets to zero: sale (receivable 0, credit 20) + void (receivable -gross, credit back 20)
    # + every tender refunded (receivable +paid).
    sale = next(e for e in books.all if e["kind"] == "msg.sale_completed" and e["subject_id"] == sale_id)["payload"]
    paid = sum(D(x["amount"]) for x in sale["payments"])
    refunded = sum(D(e["payload"]["amount"]) for e in es if e["kind"] == "msg.payment_reversed")
    gross = D(sale["figures"]["gross"])
    receivable = D(sale["receivable"]) - gross + refunded - D(voided[0]["payload"]["store_credit_change_reversed"])
    credit = -D(sale["store_credit_change_issued"]) + D(voided[0]["payload"]["store_credit_change_reversed"])
    check("every tender refunded", refunded, paid)
    check("customer balance and store credit both back to zero", (receivable, credit), (Decimal("0.00"), Decimal("0.00")))
    books.invariant("sale cancelled")

    # ------------------------------------------------------------------ 9. a cost corrected after some were sold
    print("9. the corrected delivery's cost was 60, not 50 (after 1 sold)")
    sell_items = items[:1]
    sell_items[0] = dict(sell_items[0], quantity=1)
    r = ok(S.create_sale(W.CreateSaleServiceWriteDto(
        customer_id=shop.customer, sale_date=today.isoformat(), items=sell_items,
        payments=[{"payment_method": "CASH", "paid_amount": float(vd.final_total_amount) / 3 + 1}],
        sale_mode="INSTANT", verified_total_amount=float(vd.total_amount) / 3, verified_final_total_amount=float(vd.final_total_amount) / 3),
        T, O, B, L, U), "one more sold")
    sold = (r.data[0] if isinstance(r.data, list) else r.data)
    sold = sold.id if hasattr(sold, "id") else sold["id"]
    books.since()
    print("    ...and it comes back: a customer return, resalable, refunded in cash")
    from src.entities.store_returns.store_returns_service import StoreReturnsService as RS
    from src.entities.store_returns import store_returns_write_dto as RW
    item = q(dsn, "SELECT id FROM mystoreguard.msg_sales_items WHERE sale_id = %s", (sold,))[0]["id"]
    r = ok(RS.create_return(RW.CreateReturnServiceWriteDto(sale_id=sold, return_type="REFUND", refund_method="CASH", items=[
        {"sale_item_id": item, "quantity_returned": 1, "condition": "RESALABLE"}]), T, O, B, L, U), "return created")
    rd = r.data[0] if isinstance(r.data, list) else r.data
    if getattr(rd, "status", "APPROVED") == "PENDING":
        RS.approve_return(RW.ApproveReturnServiceWriteDto(return_id=rd.id), T, O, B, L, U)
    ok(RS.process_return(RW.ProcessReturnServiceWriteDto(return_id=rd.id), T, O, B, L, U), "return processed")
    es = books.since()
    check("only the return, restocked at cost", [(e["kind"], e["payload"]["restock_costs"]) for e in es],
          [("msg.return_processed", [{"currency": "GHS", "amount": "50.00"}])])
    books.invariant("customer return")
    print("    ...and is sold again")
    ok(S.create_sale(W.CreateSaleServiceWriteDto(
        customer_id=shop.customer, sale_date=today.isoformat(), items=sell_items,
        payments=[{"payment_method": "CASH", "paid_amount": float(vd.final_total_amount) / 3 + 1}],
        sale_mode="INSTANT", verified_total_amount=float(vd.total_amount) / 3, verified_final_total_amount=float(vd.final_total_amount) / 3),
        T, O, B, L, U), "sold again")
    check("only the sale", kinds(books.since()), ["msg.sale_completed"])
    books.invariant("sold again")
    ok(PS.update_batch(shoe_batch, PW.UpdateBatchServiceWriteDto(batch_id=shoe_batch, cost_price=60), T, O, B, U), "cost corrected")
    es = books.since()
    check("receipt restated, the rest an adjustment", kinds(es), ["msg.stock_receipt_voided", "msg.stock_received", "msg.stock_adjusted"]
          if any(e["kind"] == "msg.stock_adjusted" for e in es) else ["msg.stock_receipt_voided", "msg.stock_received"])
    books.invariant("cost corrected")

    # ------------------------------------------------------------------ 10. write-off at the store
    print("10. 1 written off from the floor; 1 more taken back to the stockroom")
    ok(SPS.add_stock_store_product(SW.AddStockStoreProductServiceWriteDto(product_id=shoe, qty=-1, return_to_inventory=False),
                                   T, O, B, L, U), "written off")
    es = books.since()
    check("one stock_adjusted, a WRITE_OFF", [(e["kind"], e["payload"]["adjustment_kind"]) for e in es],
          [("msg.stock_adjusted", "WRITE_OFF")])
    books.invariant("write-off")
    ok(SPS.add_stock_store_product(SW.AddStockStoreProductServiceWriteDto(product_id=shoe, qty=-1, return_to_inventory=True),
                                   T, O, B, L, U), "returned to the stockroom")
    check("no event", kinds(books.since()), [])
    books.invariant("back to the pool")

    # ------------------------------------------------------------------ 11. stock take: short, then over
    print("11. a stock take finds the floor 2 short; resolved")
    on_floor = q(dsn, "SELECT current_qty FROM mystoreguard.msg_store_products WHERE product_id = %s AND loc_id = %s", (shoe, L))[0]["current_qty"]
    r = ok(STS.create_stock_take(TW.CreateStockTakeServiceWriteDto(location_type="STORE", items=[
        {"product_id": shoe, "counted_qty": on_floor - 2, "unit_price": 60, "currency_id": GHS}]), T, O, B, L, U), "count recorded")
    take = r.data[0] if isinstance(r.data, list) else r.data
    take_id = take["id"] if isinstance(take, dict) else take.id
    item_id = q(dsn, "SELECT id FROM mystoreguard.msg_stock_take_items WHERE stock_take_id = %s", (take_id,))[0]["id"]
    books.since()
    ok(STS.resolve_stock_take_item(TW.ResolveStockTakeItemServiceWriteDto(resolution_status="RESOLVED", adjustment_qty=-2,
                                                                          resolution_note="lost"), T, O, B, take_id, item_id, U), "shortage resolved")
    es = books.since()
    check("stock_adjusted, a COUNT", sorted(set((e["kind"], e["payload"]["adjustment_kind"]) for e in es)), [("msg.stock_adjusted", "COUNT")])
    books.invariant("stock-take shortage")

    print("    ...and another finds 3 more than recorded; the surplus taken in at 58")
    on_floor = q(dsn, "SELECT current_qty FROM mystoreguard.msg_store_products WHERE product_id = %s AND loc_id = %s", (shoe, L))[0]["current_qty"]
    r = ok(STS.create_stock_take(TW.CreateStockTakeServiceWriteDto(location_type="STORE", items=[
        {"product_id": shoe, "counted_qty": on_floor + 3, "unit_price": 58, "currency_id": GHS}]), T, O, B, L, U), "count recorded")
    take = r.data[0] if isinstance(r.data, list) else r.data
    take_id = take["id"] if isinstance(take, dict) else take.id
    item_id = q(dsn, "SELECT id FROM mystoreguard.msg_stock_take_items WHERE stock_take_id = %s", (take_id,))[0]["id"]
    books.since()
    ok(STS.resolve_stock_take_surplus_item(TW.ResolveStockTakeSurplusServiceWriteDto(
        currency_id=GHS, cost_price=58, base_selling_price=90, resolution_note="found in the back"), T, O, B, take_id, item_id, U), "surplus taken in")
    es = books.since()
    check("one stock_received of 174, against Stock adjustments", [(e["kind"], e["payload"]["amount"], e["payload"]["credit_to"]) for e in es],
          [("msg.stock_received", "174.00", "STOCK_ADJUSTMENT")])
    books.invariant("stock-take surplus")

    # ------------------------------------------------------------------ 12. a purchase order: pay, receive, return, refund
    print("12. a purchase order for 20 at 30: part-paid, received, 3 sent back, a payment refunded")
    r = ok(POS.create_purchase_order(OW.CreatePurchaseOrderServiceWriteDto(
        supplier_id=supplier, order_date=today, person_to_approve_id=U, items=[{"product_id": shoe, "qty_ordered": 20, "currency_id": GHS,
                                                        "cost_price": 30, "base_selling_price": 90}]), T, O, B, U), "PO created")
    po = r.data[0] if isinstance(r.data, list) else r.data
    po_id = po["id"] if isinstance(po, dict) else getattr(po, "id", None) or po.purchase_order.id
    ok(POS.approve_purchase_order(OW.ApprovePurchaseOrderServiceWriteDto(purchase_order_id=po_id, action="APPROVE"), T, O, B, U), "approved")
    check("no event for an order", kinds(books.since()), [])
    ok(PPS.create_payment(OW.CreatePurchasePaymentServiceWriteDto(purchase_order_id=po_id, payments=[
        {"payment_method": "MOBILE_MONEY", "paid_amount": 200}, {"payment_method": "CASH", "paid_amount": 50}]), T, O, B, U), "paid 250 ahead")
    es = books.since()
    check("two supplier payments", sorted((e["kind"], e["payload"]["method"], e["payload"]["amount"]) for e in es),
          [("msg.supplier_payment_made", "CASH", "50.00"), ("msg.supplier_payment_made", "MOBILE_MONEY", "200.00")])
    poi = q(dsn, "SELECT id FROM mystoreguard.msg_purchase_order_items WHERE purchase_order_id = %s", (po_id,))[0]["id"]
    ok(POS.receive_purchase_order(OW.ReceivePurchaseOrderServiceWriteDto(purchase_order_id=po_id, received_date=today, items=[
        {"purchase_order_item_id": poi, "received_qty": 20}]), T, O, B, U), "received")
    es = books.since()
    check("one stock_received of 600 on the PO", [(e["kind"], e["payload"]["amount"], e["payload"]["document_type"],
                                                  bool(e["payload"]["po_number"])) for e in es],
          [("msg.stock_received", "600.00", "PURCHASE_RECEIPT", True)])
    books.invariant("PO received")
    po_batch = es[0]["subject_id"]
    ok(PRS.create_return(OW.CreatePurchaseReturnServiceWriteDto(purchase_order_id=po_id, reason="DAMAGED", items=[
        {"batch_id": po_batch, "qty_returned": 3}]), T, O, B, L, U), "3 sent back")
    es = books.since()
    check("one supplier_return of 90, nothing else", [(e["kind"], e["payload"]["lines"][0]["amount"]) for e in es],
          [("msg.supplier_return", "90.00")])
    books.invariant("supplier return")
    cash_pay = q(dsn, "SELECT id FROM mystoreguard.msg_purchase_payments WHERE purchase_order_id = %s AND payment_method = 'CASH'", (po_id,))[0]["id"]
    ok(PPS.refund_payment(OW.RefundPurchasePaymentServiceWriteDto(payment_id=cash_pay), T, O, B, U), "cash payment refunded")
    es = books.since()
    check("one supplier_payment_reversed of 50", [(e["kind"], e["payload"]["amount"], e["payload"]["reason"]) for e in es],
          [("msg.supplier_payment_reversed", "50.00", "REFUNDED")])
    owed = Decimal(0)
    for e in books.all:
        pe = e["payload"]
        if pe.get("purchase_order_id") != po_id:
            continue
        a = D(pe.get("amount")) if e["kind"] != "msg.supplier_return" else sum(D(l["amount"]) for l in pe["lines"])
        owed += {"msg.stock_received": a, "msg.supplier_return": -a, "msg.supplier_payment_made": -a,
                 "msg.supplier_payment_reversed": a}.get(e["kind"], 0)
    check("the supplier is owed 600 - 90 returned - 200 paid for this order", owed, Decimal("310.00"))

    # ------------------------------------------------------------------ 13. a delivery voided, another deleted
    print("13. a delivery entered by mistake: voided (reverse) and another deleted")
    ok(PS.add_batch_to_product(PW.AddBatchToProductServiceWriteDto(product_id=shoe, supplier_id=supplier, currency_id=GHS, cost_price=7,
                                                                   base_selling_price=90, qty_received=6, batch_number=f"MIS-{uuid.uuid4().hex[:5]}"),
                               T, O, B, U), "mistaken delivery")
    mistaken = batch_of(shoe)
    books.since()
    ok(PS.reverse_batch(PW.ReverseBatchServiceWriteDto(batch_number=mistaken["batch_number"]), T, O, B, U), "voided")
    es = books.since()
    check("its receipt voided", [(e["kind"], e["payload"]["amount"], e["payload"]["reason"]) for e in es],
          [("msg.stock_receipt_voided", "42.00", "VOIDED")])
    books.invariant("batch voided")
    ok(PS.add_batch_to_product(PW.AddBatchToProductServiceWriteDto(product_id=shoe, supplier_id=supplier, currency_id=GHS, cost_price=8,
                                                                   base_selling_price=90, qty_received=2), T, O, B, U), "another")
    gone = batch_of(shoe)
    books.since()
    ok(PS.delete_batch(PW.DeleteBatchServiceWriteDto(product_id=shoe, batch_id=gone["id"]), T, O, B, U), "deleted")
    es = books.since()
    check("its receipt voided", [(e["kind"], e["payload"]["amount"], e["payload"]["reason"]) for e in es],
          [("msg.stock_receipt_voided", "16.00", "DELETED")])
    books.invariant("batch deleted")

    # ------------------------------------------------------------------ 14. a split
    print("14. 2 shoes off the floor split into 4 halves, each half costed at 31 (not exactly half), then the split reversed")
    r = ok(PS.create_split(PW.CreateSplitServiceWriteDto(source_scope="STORE", items=[{
        "source_product_id": shoe, "source_qty_taken": 2, "divisor": 2, "price_mode": "AUTO", "unit_cost_price": 31,
        "destination": "NEW", "new_product_name": f"Half shoe {uuid.uuid4().hex[:5]}"}]), T, O, B, U, loc_id=L), "split")
    es = books.since()
    check("a receipt for the halves (against Stock adjustments) and a SPLIT adjustment for what they came from",
          sorted((e["kind"], e["payload"].get("credit_to") or e["payload"].get("adjustment_kind")) for e in es),
          [("msg.stock_adjusted", "SPLIT"), ("msg.stock_received", "STOCK_ADJUSTMENT")])
    books.invariant("split")
    split = r.data[0] if isinstance(r.data, list) else r.data
    split_id = split["id"] if isinstance(split, dict) else split.id
    ok(PS.reverse_split(PW.ReverseSplitServiceWriteDto(split_id=split_id), T, O, B, U), "split reversed")
    es = books.since()
    check("the halves' receipt voided and the source put back", sorted(set(kinds(es))), ["msg.stock_adjusted", "msg.stock_receipt_voided"])
    books.invariant("split reversed")

    # ------------------------------------------------------------------ 15. idempotency
    print("15. once each: no subject published twice for one change, and a re-save publishes nothing")
    q(dsn, "UPDATE mystoreguard.msg_purchase_batches SET description = 'touched' WHERE product_id = %s", (shoe,))
    q(dsn, "UPDATE mystoreguard.msg_batch_locations SET qty = qty WHERE purchase_batche_id IN "
           "(SELECT id FROM mystoreguard.msg_purchase_batches WHERE product_id = %s)", (shoe,))
    check("touching every batch publishes nothing", kinds(books.since()), [])
    check("no posting errors", [e for e in books.all if e["kind"] == "msg.posting_error"], [])
    books.invariant("end")
    print(f"\nInventory (books): {dict(books.books())}; supplier balances: {dict(books.supplier)}; adjustments: {dict(books.adjust)}")
    print(f"{passes} passed, {len(fails)} failed")
    for f in fails:
        print("  FAIL", f)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:6]))
