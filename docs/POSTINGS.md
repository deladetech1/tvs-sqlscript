# Postings: other apps into the books

Roadmap Phase 1, step 1: **MyStoreGuard's sales post themselves into the business's Accounting books.**
Step 2 (§5): **Loandrift's loans, repayments, write-offs and savings do the same.**
Later steps add ZelosHR payroll, Expenses, Invoicing (the invoice of record) and Projects the same way.

Owner decisions this follows (2026-10-19):

- Apps post straight away to the standard chart codes. A business can point any posting role at another account
  later (Accounting → Settings → Posting accounts). Posting never waits for a mapping step.
- Everything is per business (`bus_id`). Accounting posts only for a business subscribed to Accounting
  (`core_platform.cp_business_app_tier`, app `app-accounting`).

## The pieces

```
MyStoreGuard writes a sale ──(same transaction)──▶ core_platform.cp_events  (msg.*)
                                                        │
Accounting API, background service (every 30 s, once per database: pooled + each silo)
   1. ingest: cp_events_after('accounting', 500, kinds) ──▶ accounting.acc_posting_inbox (one row per event), ack
   2. post:   PENDING rows ──▶ one journal each (source STORE_MANAGEMENT, source document evt:<event id>)
```

| Where | What |
|---|---|
| `migrations/shared/20261019-38-mystoreguard-accounting-events.sql` | the publishing triggers, their state tables, the baseline |
| `migrations/shared/20261019-39-mystoreguard-stock-accounting-events.sql` | stock: receipts, adjustments, supplier payments and returns (§1b) |
| `migrations/shared/20261019-40-mystoreguard-cancel-takes-back-store-credit-change.sql` | `msg.sale_voided.store_credit_change_reversed` |
| `scripts/test_msg_stock_accounting_events.py` | every stock path through MyStoreGuard's real code, Inventory = shelves after each step |
| `migrations/shared/20261019-41-loandrift-accounting-events.sql` | Loandrift: the trigger on its ledger, `ld_acc_entry_state`, the baseline (§5) |
| `scripts/test_ld_accounting_events.py` | every Loandrift path through its real code; writes the captured events to tvs-accounting-bk's `ld_events.json` |
| Accounting EF migration `20261019143911_AppPostings` | `acc_posting_inbox`, `acc_posting_accounts`, unique `ux_acc_journal_entries_event` |
| tvs-accounting-bk `app/src/Ledger/Postings/` | `PostingsWorker` (hosted service), `PostingRun` (ingest + post), `PostingRules` (by kind), `MsgPostingRules`, `LdPostingRules`, `PostingRoles`, `PostingAccounts` |
| tvs-accounting-bk `Entities/postings/` | `GET /api/v1/posting-accounts/list`, `PUT /api/v1/posting-accounts/update`; `GET /api/v1/postings/list`, `GET /api/v1/postings/statistics`, `GET /api/v1/postings/get?posting_id=…`, `POST /api/v1/postings/retry` (body `{"posting_id": …}`) |
| tvs-accounting-ft | Settings → Posting accounts; Integrations → From other apps; dashboard "Needs attention" |

## 1. MyStoreGuard publishes

### Why database triggers, not a service-layer choke point

MyStoreGuard has no single path a sale goes through. `create_sale` alone is 2,250 lines and is reached from the till,
the storefront checkout, auctions, invoice payment and fulfilment, and returns' exchange-to-sale. Payments are written
by `create_payment`, instalment `take_payment` and `settle_plan`, the online-payment sweep, `SaleOnlinePaymentService`
and invoices; sales are cancelled, deleted, edited and released by four more. A Python choke point would have to be
remembered by every path written from now on. Triggers fire for every path, including Azure Functions and ones not yet
written.

They are **constraint triggers, `DEFERRABLE INITIALLY DEFERRED`**: they run at COMMIT. A sale is written header first,
then items and payments, then its status, stock and cost are settled — a row trigger firing at once would see half a
sale. At COMMIT the trigger reads the sale as it finally stands, compares it with what was last published
(`msg_acc_sale_state`, `msg_acc_payment_state`, `msg_acc_document_state`) and publishes only the difference, with
`core_platform.cp_event_publish` in the same transaction. **A sale that fails rolls back and publishes nothing; a
published event always has its sale.**

**Fail open, loudly.** If describing a document raises, the business change still commits and a `msg.posting_error`
event names the document and the error; Accounting lists it as FAILED. A bug in the books must never stop a till, and
must never hide either.

Triggers are `ENABLE ALWAYS`, so seeds and data fixes under `session_replication_role = replica` are recorded too.

### When revenue is recognised

When the goods leave: `msg_sales.fulfillment_status = 'FULFILLED'` and not CANCELLED (MyStoreGuard's own authoritative
answer to "have the goods gone", written in the same transaction as the stock movement). An INSTANT sale is fulfilled
only when fully paid; an instalment sale when its policy releases the goods (deposit, approval, full payment, or a
manager's release). **Money taken before the goods leave is a customer deposit**; on release it is applied to the sale.

### Events

Subject = the MyStoreGuard id. Every payload carries `version`, `app`, `org_id`, `currency` (the tenant's default
currency code), `date` (the business date, tenant time zone), `document_type`, `document_number`, `document_id`.
**Amounts are strings with two decimals.** Payloads are self-contained: Accounting never reads MyStoreGuard tables.

| Kind | When | Payload (besides the common fields) |
|---|---|---|
| `msg.sale_completed` | goods released (again, after a change) | `revision`; `figures` {gross, net, tax, `taxes`[tax_id, name, short_name, amount], promo_discount, finance_charge, settlement_discount, `costs`[currency, amount], cost_missing_lines, `lines`[…]}; `payments`[payment_id, method, amount, penalty, gift_card_id] taken with it; `deposits_applied`; `store_credit_change_issued`; `change_given`; `receivable` (what the customer still owes; negative = in credit) |
| `msg.sale_voided` | a released sale cancelled, deleted, or its figures changed | `revision` voided, `reason` (CANCELLED, DELETED, CHANGED), `restocked`, the `figures` posted, `store_credit_change_reversed` (change kept as store credit that cancel_sale took back; 20261019-40) |
| `msg.payment_received` | a payment not part of its sale's event | method, amount, penalty part, `applied` = DEPOSIT (goods not released) or RECEIVABLE |
| `msg.payment_reversed` | a published payment refunded, deleted, reduced, or a gift card / loyalty tender put back by cancel | as received, with `reason` |
| `msg.return_processed` | a return reaches COMPLETED | lines, `taxes`, net, tax, restocking_fee, `restock_costs`, `refund` {cash, cash_method, store_credit, trade_in, plan_settled, plan_written_off, owed_to_customer, against_balance} |
| `msg.gift_card_issued` | a gift card created | amount, `issued_as` SOLD (has a PURCHASE transaction) or REWARD (customer-segment reward) |
| `msg.plan_refund_paid` | an instalment plan's refund marked handed back | amount, `applied` |
| `msg.posting_error` | the trigger could not describe a document | document_type, document_id, error |

How figures are worked out:

- `line_total` is gross (tax included, after pricing rules and the promo share). Tax per line is
  `line_total × taxes_applied[].amount / final_price`, because `taxes_applied[].amount` is the tax on **one unit**
  (from `verify_price` on the unit price). Net = gross − taxes. The line's own `tax_amount` is per unit × quantity
  since tvs-mystoreguard-bk 71ae82c (it used to be one unit's, which understated MyStoreGuard's reports); the triggers
  never read it.
- `promo_discount` is already inside the line totals; Accounting grosses revenue up by it and debits Sales discounts.
- Cost is `msg_sales_items.line_cost`: the batches actually deducted, frozen at deduction (`_line_cost`), per cost
  currency. Lines without a cost are counted in `cost_missing_lines` and post no cost.
- A change to a released sale (edited lines, an early-settlement discount) publishes a void of the old figures and a
  new revision. Only amounts that post count as a change (`msg_acc_fingerprint`), never names.
- A sale released in the transaction that created it is dated its `sale_date` (which may be backdated); a sale released
  later is dated the day it was released.

### MyStoreGuard paths and what covers them

| Path | Writes | Covered by |
|---|---|---|
| POS `create_sale` (cash, card, MoMo, bank, cheque, crypto, others, split tender) | sale, items, payments | sale_completed (payments folded in) — tested |
| Part-paid INSTANT sale (layaway), later `create_payment` | payments, release | payment_received DEPOSIT, then sale_completed with deposits_applied — tested |
| A sale that fails | rolled back | nothing published — tested |
| `refund_payment` (POS) | payment REFUNDED + deleted_at | payment_reversed — tested |
| `cancel_sale` (since 71ae82c: every tender refunded, change kept as store credit taken back) | status CANCELLED, stock back, every payment REFUNDED, gift card / store credit / loyalty put back, an ADJUST store-credit row for the change | sale_voided (restocked, `store_credit_change_reversed`), payment_reversed for every tender — tested |
| `delete_sale` (hard delete) | items, payments, sale deleted, no restock | sale_voided (restocked false) + payment_reversed — tested |
| Gift card `create_gift_card` | card + PURCHASE transaction | gift_card_issued SOLD — tested |
| Gift card redeemed at the till | GIFT_CARD payment | inside sale_completed (method GIFT_CARD) — tested |
| Customer-segment reward cards (app + func) | card, no transaction | gift_card_issued REWARD |
| Store credit / loyalty redeemed at the till | STORE_CREDIT / LOYALTY_POINTS payment | inside sale_completed |
| Over-payment to store credit (`overpay_to_store_credit`) | `store_credit_change_issued` | sale_completed `store_credit_change_issued` |
| Returns `create_return` / `approve_return` / `reject_return` | return rows | nothing until processed — tested |
| Returns `process_return` (cash / original method / store credit, restock or write-off, plan settlement) | return COMPLETED | return_processed — tested (cash, restock) |
| `exchange_to_sale` | return processed + new sale paid by an OTHERS trade-in | return_processed `trade_in` + the new sale's OTHERS payment, which cancel through Other payments clearing |
| Instalment `create_sale` (INSTALLMENT, plan, deposit) | sale, plan, payments, release per policy | sale_completed with finance_charge and receivable, or payment_received DEPOSIT — tested |
| `take_payment` (till, storefront, online sweep) | payment, allocations incl. PENALTY | payment_received with its `penalty` part — tested |
| `settle_plan` (early settlement) | payment, SETTLEMENT_DISCOUNT allocation | sale_voided + sale_completed revision (settlement_discount, payment folded in) — tested |
| `refund_payment` (plan) | payment REFUNDED (deleted_at null) | payment_reversed |
| `decide` REJECTED, `close_refund` | refund_status RETURNED | plan_refund_paid (DEPOSIT) |
| `cancel_plan` | sale CANCELLED, restock per policy | sale_voided |
| `release_goods`, approval (`decide` APPROVED) | fulfillment FULFILLED | sale_completed |
| Online payments (`SaleOnlinePaymentService.record`, sweep) | payment | payment_received / folded |
| MSG invoices: paid with stock → `create_sale`; no stock → `msg_invoice_payments`; `fulfil_invoice` | payments, sales | payment_received DEPOSIT (document INVOICE); at fulfilment payment_reversed (MOVED_TO_SALE) + the new sale |
| `update_sale` (lines or payments) | items rewritten, payments | revision (void + sale_completed) or payment events |
| Azure func: overdue / default / complete / `sync_sale_statuses` | statuses only | nothing to post (no money moves) |
| Azure func: `capture_penalties` | penalties accrued | not posted (penalties post when paid) |

Not covered (left for later, listed in the report): gift card expiry/cancellation (breakage), affiliate commissions,
MSG expenses, loyalty points earned (no liability is booked for unredeemed points), a return's
`exchange_difference_amount` (MyStoreGuard never settles it). Stock is §1b.

**Starts from now.** The first run records every existing sale, payment, return and gift card as already published
(the `BASELINE` marker); history belongs in the books' opening balances. Deposits held on unreleased sales at that
moment should be in the opening balance of Customer deposits (2420), and instalment balances of released sales in
Customer instalment balances (1120).

## 1b. MyStoreGuard's stock (20261019-39)

A live dev test showed Inventory at −60: sales credited it (cost of goods sold) and nothing debited it. Migration
`20261019-39-mystoreguard-stock-accounting-events.sql` publishes everything else that changes what stock is worth, with
the same machinery as §1: deferred constraint triggers at COMMIT, state tables (`msg_acc_batch_state`, and
`msg_acc_document_state` kinds `SUPPLIER_PAYMENT`, `SUPPLIER_RETURN`), fail open with `msg.posting_error`, a stock-in
that fails publishes nothing, existing rows baselined (`BASELINE_STOCK`; stock on hand belongs in the opening balance
of Inventory 1200).

### The model: the books hold what the shelves hold, batch by batch

MyStoreGuard has some twenty paths that move stock, with partly free-text movement reasons, so the triggers do not
follow paths. Every batch touched in a transaction is **reconciled** at commit:

- **on hand** = `msg_purchase_batches.qty_remaining` (the unallocated pool; 0 once DELETED) + Σ `msg_batch_locations.qty`
- **receipt** = `qty_received × cost_price` in the batch's currency, while it is neither VOID nor DELETED
- the receipt is published when it first exists and **restated** (void + new revision) when its quantity, cost or
  currency changes, or the batch is voided or deleted;
- whatever change in on-hand value nothing else explains is a `msg.stock_adjusted`:
  `(q1 − r1 − S − R − X)·c1 − (q0 − r0)·c0` (q on hand, r receipt quantity, c unit cost; S quantity moved by sale-family
  movements — `SALE*`, `RETURN`, `INVOICE*`, `WRITE_OFF_*` of a customer return, plan cancel — whose own events post the
  cost; R `RETURN_TO_SUPPLIER`, posted by `msg.supplier_return`; X `EXCHANGE`, posted here to cost of sales).
  S, R and X come from `msg_product_movements` rows inserted **in the same transaction** (an ordinary row trigger keeps
  transaction-local settings; a rolled-back savepoint takes them with it).

So transfers and allocations (rows of one batch) post nothing, a cost edit revalues what is on hand and puts the cost
difference of goods already gone to Stock adjustments, and a path nobody listed still leaves Inventory equal to the
shelves. Proven by `scripts/test_msg_stock_accounting_events.py`: after every step, Inventory as the events post it
equals Σ on hand × cost, per currency.

### Events

| Kind | Subject | Payload (besides the common fields) |
|---|---|---|
| `msg.stock_received` | batch | `revision`, `quantity`, `unit_cost`, `amount`, `currency` (the delivery's), `credit_to` SUPPLIER / STOCK_ADJUSTMENT, `batch_type`, `supplier_id/_name`, `purchase_order_id`, `po_number`, `product_*`; document PURCHASE_RECEIPT (receipt number) or DELIVERY (batch number) |
| `msg.stock_receipt_voided` | batch | the published receipt, `reason` CHANGED / VOIDED / DELETED |
| `msg.stock_adjusted` | batch | `adjustment_kind`, `lines`[kind WRITE_OFF / COUNT / SPLIT / ADJUSTMENT / EXCHANGE, quantity, unit_cost, `amount` signed (negative = stock gone), currency] |
| `msg.supplier_payment_made` / `_reversed` | purchase payment | `method`, `amount`, `currency` (the PO items' one currency, else the default), PO and supplier; reversed with `reason` REFUNDED / DELETED / CHANGED |
| `msg.supplier_return` | purchase return | `lines`[batch, quantity, unit_cost, amount = `line_total` at the batch's cost, currency], PO and supplier |

`credit_to` is SUPPLIER for a delivery (batch_type PURCHASE, or a supplier or delivery ref named), else
STOCK_ADJUSTMENT (a split's output, a stock-take surplus): MyStoreGuard records **no payment on a delivery outside a
purchase order**, so every delivery is owed to the supplier until Accounting records the payment (or a PO payment
arrives). PO payments made before the goods arrive debit Supplier balances ahead of the receipt (a supplier advance).
MyStoreGuard's own "owed" figure is ordered qty × ordered cost; the books' is received value − returns − payments.

### Paths and what covers them

| Path | Batch type / effect | Published |
|---|---|---|
| Product create with stock (`create_product`, CSV) | OPENING_STOCK, pool | stock_received — tested |
| Add stock (`add_batch_to_product`) | OPENING_STOCK, pool | stock_received (USD tested) |
| Store / warehouse Add stock with a new delivery (`create_adjustment_batch`) | ADJUSTMENT, placed | stock_received — tested |
| PO receive (`receive_purchase_order`) | PURCHASE, pool (destination allocation is a move) | stock_received (document the receipt, PO number) — tested |
| Delivery corrected (`adjust_batch_quantity`) | qty_received ± | void + revision — tested |
| Cost / currency edited (`update_batch`, `update_batch_prices`) | cost_price | void + revision, stock_adjusted for goods already gone — tested |
| Allocation pool → shelf, transfers store ↔ warehouse, move batch to another product | rows of one batch | nothing — tested (allocation, return to pool) |
| Write-off (`add-stock` −n, `return_to_inventory=false`), store `reverse_batch` | shelf − | stock_adjusted WRITE_OFF — tested |
| Stock take shortage resolved / reversed | shelf ∓ | stock_adjusted COUNT — tested |
| Stock take surplus resolved / reversed | OPENING_STOCK batch / DELETED | stock_received (STOCK_ADJUSTMENT) / void — tested |
| Split / reverse split | SPLIT_OUT + ADJUSTMENT batch / VOID | stock_adjusted SPLIT + stock_received (STOCK_ADJUSTMENT), reversed — tested |
| Batch voided (`reverse_batch`) or deleted (`delete_batch`) | VOID / row gone | stock_receipt_voided — tested |
| Exchange replacement handed out (no new sale) | shelf − | stock_adjusted EXCHANGE (cost of sales) |
| Supplier payment / refund | `msg_purchase_payments` | supplier_payment_made / _reversed — tested |
| Purchase return (`create_return`, pool only) | qty_remaining − | supplier_return — tested |
| Sales, cancels, customer returns, invoices, plan cancels | sale family | their own §1 events only — tested (sale, cancel, return, resale) |

Not covered: a purchase receipt deleted (`delete_purchase_receipt` deletes only the header; the batch and its receipt
stand), PO line tax/discount (MyStoreGuard records but never charges them), a sale-family movement without a
`batch_id` (none found; it would count as an adjustment). One journal per batch per transaction; a stock take of 20
lines makes up to 20 journals.

### Currency

A delivery costed in USD posts in USD and converts at the books' rate on the event's date (`acc_exchange_rates`),
keeping the foreign amount on the line; MyStoreGuard keeps no rate per delivery (`cp_currencies.exchange_rate` is
today's, not the delivery's). Cost of sales converts at the sale date's rate, so Inventory in base currency can drift
from receipt-date value by the rate change; revalue it in Currency revaluation if it matters.

## 2. Accounting consumes

`PostingsWorker` (a `BackgroundService` in the Accounting API; the function app has no deployment) runs every
`Accounting:Postings:IntervalSeconds` (30) when `Accounting:Postings:Enabled` (on). Each cycle runs once per
**database** through the package's `DatabaseFanout` (pooled database and each silo), never per tenant.

**Ingest.** `cp_events_after('accounting', 500, ARRAY['msg.sale_completed', …])` → `acc_posting_inbox` (`event_id`
unique, `ON CONFLICT DO NOTHING`) → `cp_event_ack`, in one transaction. A crash between storing and acking hands the
same events back and stores nothing new.

**Post.** For each business with PENDING rows (or FAILED rows due a retry):

| Business | Rows |
|---|---|
| no Accounting subscription (`cp_business_app_tier`) | SKIPPED: "This business does not subscribe to Accounting." (Retry posts it once it subscribes.) |
| books not set up | stay PENDING ("Waiting for the books to be set up"); posted once they are — the backfill |
| dated before the books' first fiscal period | SKIPPED: "Dated before these books begin; it belongs in the opening balances." |
| otherwise | one transaction per row, under the books' write lock: build, check, save the journal, mark POSTED |

**One journal per event**, three times over: the inbox row is locked `FOR UPDATE` and must still be PENDING/FAILED;
the journal's `source_document_id` is `evt:<event id>` under the unique index `ux_acc_journal_entries_event`; the inbox's
`journal_id` is unique. Retries and restarts post nothing twice.

**Failures** are FAILED with a sentence saying what to do, `attempts` counted, and retried automatically every 15
minutes (and at once from the "From other apps" page). **A locked or closed period is never posted into, and the
posting is not moved to another period:** the reason says "March 2026 is locked. Reopen it in Fiscal periods; this
posts by itself." Moving it would put a sale in a month it did not happen in and change a period someone signed off.
A missing exchange rate fails the same way ("Add a USD rate on or before 2026-10-19 in Exchange rates").

`msg.posting_error` rows are FAILED with MyStoreGuard's error; retrying them cannot help until MyStoreGuard publishes
the document again (fix the cause, then touch the document).

## 3. Posting rules

Journals: `source_type = STORE_MANAGEMENT` (shown as MyStoreGuard), `reference`/`source_reference` = the MyStoreGuard
document number (SAL-…, RET-…), `source_document_id = evt:<event id>`, dated the event's business date, numbered in
the books' journal series, POSTED, balanced to the cent (any residual cent to the ROUNDING role). They cannot be
reversed by hand (they belong to a document); MyStoreGuard reverses them by voiding.

| Event | Debit | Credit |
|---|---|---|
| sale_completed | each payment's method role; CUSTOMER_DEPOSITS (deposits applied); CUSTOMER_RECEIVABLE (receivable, if owed); SALES_DISCOUNT (promo); FINANCE_INCOME / SALES_DISCOUNT (settlement discount); COST_OF_SALES (cost) | SALES_REVENUE (net + promo); each TAX:&lt;tax id&gt;; FINANCE_INCOME (charge); PENALTY_INCOME (penalty parts); STORE_CREDIT_LIABILITY (change to store credit); CASH (change given); CUSTOMER_RECEIVABLE (if in credit); INVENTORY (cost) |
| sale_voided | the revenue side reversed (SALES_REVENUE, taxes, FINANCE_INCOME); INVENTORY if restocked; STORE_CREDIT_LIABILITY (store credit change taken back) | CUSTOMER_RECEIVABLE (the whole amount, and the change taken back; payments stay where they are and are reversed by their own events); COST_OF_SALES if restocked |
| payment_received | method role | CUSTOMER_DEPOSITS or CUSTOMER_RECEIVABLE; PENALTY_INCOME (penalty part) |
| payment_reversed | the reverse | |
| return_processed | SALES_RETURNS (net); each tax; FINANCE_INCOME (plan written off); INVENTORY (restocked cost) | RESTOCKING_FEES; refund method role (cash); STORE_CREDIT_LIABILITY; OTHER_PAYMENTS (trade-in); CUSTOMER_RECEIVABLE (plan settled + owed + against balance + written off); COST_OF_SALES (restocked cost) |
| gift_card_issued | CASH (sold) or LOYALTY_REWARDS (reward) | GIFT_CARD_LIABILITY |
| plan_refund_paid | CUSTOMER_DEPOSITS or CUSTOMER_RECEIVABLE | CASH |
| stock_received | INVENTORY | SUPPLIER_PAYABLE, or STOCK_ADJUSTMENT (credit_to) — in the delivery's currency |
| stock_receipt_voided | the reverse | |
| stock_adjusted (per line, signed) | INVENTORY (gain) / STOCK_WRITE_OFF, STOCK_ADJUSTMENT or COST_OF_SALES (loss) | the other side |
| supplier_payment_made | SUPPLIER_PAYABLE | method role |
| supplier_payment_reversed | method role | SUPPLIER_PAYABLE |
| supplier_return | SUPPLIER_PAYABLE | INVENTORY |

Payment methods → roles: CASH → CASH; BANK_TRANSFER, CHEQUE → BANK; MOBILE_MONEY → MOBILE_MONEY; CARD → CARD;
GIFT_CARD → GIFT_CARD_LIABILITY; STORE_CREDIT → STORE_CREDIT_LIABILITY; LOYALTY_POINTS → LOYALTY_REWARDS; BITCOIN,
OTHERS → OTHER_PAYMENTS.

### Posting accounts (`acc_posting_accounts`)

A row (`bus_id`, `role`, `account_id`) is the business's own choice. Without one the role posts to its standard code
in that business's chart, found by CODE (ids are generated per business):

| Role | Code | Standard account | Role | Code | Standard account |
|---|---|---|---|---|---|
| SALES_REVENUE | 4010 | Sales Revenue | CASH | 1010 | Cash on Hand |
| SALES_RETURNS | 4015 | Sales Returns | BANK | 1020 | Bank |
| SALES_DISCOUNT | 4030 | Sales Discounts | MOBILE_MONEY | 1040 | Mobile Money Clearing |
| LOYALTY_REWARDS | 4035 | Loyalty Rewards Redeemed | CARD | 1060 | Card Settlements Clearing |
| FINANCE_INCOME | 4120 | Instalment Finance Charges | OTHER_PAYMENTS | 1070 | Other Payments Clearing |
| PENALTY_INCOME | 4130 | Late Payment Penalties | CUSTOMER_RECEIVABLE | 1120 | Customer Instalment Balances |
| RESTOCKING_FEES | 4140 | Restocking Fees | CUSTOMER_DEPOSITS | 2420 | Customer Deposits |
| COST_OF_SALES | 5010 | Cost of Goods Sold | GIFT_CARD_LIABILITY | 2400 | Gift Cards Outstanding |
| INVENTORY | 1200 | Inventory | STORE_CREDIT_LIABILITY | 2410 | Customer Store Credit |
| ROUNDING | 6900 | Rounding Differences | TAX:&lt;id&gt; | 2101 VAT, 2102 NHIL, 2103 GETFund, 2104 COVID-19, else 2100 | by the tax's name |
| STOCK_ADJUSTMENT | 5020 | Stock Adjustments | SUPPLIER_PAYABLE | 2020 | Supplier Balances |
| STOCK_WRITE_OFF | 5030 | Stock Written Off | | | |

(The owner's "5000 cost of sales" is the Cost of Sales *group* in the starter chart; 5010 is its posting account.
Codes avoid the demo chart's other meanings: 2200 accrued expenses, 2300 a bank loan, 4020 service revenue.)

A standard account the chart lacks is **created** under its group (1000, 2000, 4000, 5000, 6000). A posting FAILS, with
"Account 2400 is Accrued Expenses (liability), not gift cards outstanding. Map Gift cards outstanding in Settings →
Posting accounts", only when the code belongs to a group, a control, an inactive account or one of another type, or
the group itself is missing. Customer balances use their own account (1120), never the Accounts Receivable control
(1100), and supplier balances theirs (2020), never the Accounts Payable control (2010), so the invoice and bill
sub-ledgers stay whole.

**What a role may point at.** Settings offers, and `PUT /posting-accounts/update` accepts (else a 400 saying why), only
an account of the role's type (`account_types` on each row: revenue roles REVENUE, liabilities LIABILITY, stock and
receivables ASSET, cost and stock-loss roles EXPENSE; Rounding EXPENSE or REVENUE). Money roles (`cash_only`: cash,
bank, mobile money, card, other) take only a cash or bank account: an asset of subtype CASH or BANK, or one registered
in Banking. A choice that stops fitting (the account re-typed) shows as the row's problem and fails postings readably.

**Dashboard "Cash & bank"** is the ledger balance, as at the business's today, of every such cash or bank account
(`Ledger/CashAccounts.cs`), not only the accounts registered in Banking; the cash chart and cash flow use the same set.

### Several currencies

`currency` is the sale's (the tenant's default in Core Platform). When it differs from the books' base currency each
line is converted at the latest rate on or before the date (`acc_exchange_rates`, base per unit), keeps the foreign
amount (`currency`, `amount_fc`), and the cents conversion leaves go to ROUNDING. Cost lines convert from their own
cost currency (a phone bought in USD and sold in GHS).

## 4. Reports

Posted MyStoreGuard journals are ordinary posted journals: the income statement shows revenue (4010 less 4015/4030/4035)
and cost of goods sold (5010); the balance sheet stock (1200); the tax summary counts the accounts MyStoreGuard's taxes
post to as output tax (alongside tax codes' output accounts). Each journal names the MyStoreGuard document number, and
the "From other apps" page links each event to its journal.

## 5. Loandrift (20261019-41)

### What is published: Loandrift's own ledger

Loandrift already states every money movement as a balanced journal of its own (`loandrift.ld_journal_entries` /
`_lines`, tvs-loandrift-bk `entities/accounting/acc_base.py`), written in the same transaction as the disbursement,
repayment, write-off, savings or investment transaction it describes. Its lines carry the split that matters, worked
out once by Loandrift. Re-deriving it from the loan tables in SQL would be a second copy of the same rules that could
disagree, so the trigger watches the ledger instead: **one event per Loandrift journal entry**, its lines by Loandrift's
standard account key (`system_key`), and Accounting maps each key to a posting role.

Same machinery as §1: a constraint trigger on `ld_journal_entries`, `DEFERRABLE INITIALLY DEFERRED` and `ENABLE
ALWAYS`, reads the entry with all its lines at COMMIT; a Loandrift write that fails rolls back and publishes nothing.
Loandrift never edits an entry (a correction is a mirror entry), so `loandrift.ld_acc_entry_state` only remembers which
entries were published (`entry_id`, `kind`, `total`). Fail open: a describing error publishes `ld.posting_error` and the
write commits. Starts from now: every entry existing at the first run is `BASELINE` (Loandrift's loan book, savings
and investments on that day belong in the opening balances of 1150, 2430 and 2440).

How Loandrift splits, and so how the books recognise:

- **Interest is recognised when paid.** Loandrift does not accrue interest (`acc_base.write_off_lines`: "Interest is
  not in the ledger until it is paid"). Loans are priced flat, so the loan part of each payment splits pro rata
  between principal and interest (`split_loan_portion`), interest rounded to the cent and principal taking the rest.
- **Penalties are recognised when paid**, and allocated first: `ld_penalties` (charged by the nightly
  `apply_loan_penalties`) post nothing; a payment clears them oldest first and its penalty part is penalty income.
  Waivers of unpaid penalties likewise post nothing.
- **Charges** taken at disbursement (processing fee, insurance, other) are income that day, as a separate entry.
- **Write-off** takes the principal the ledger still holds for the loan: Dr the allowance (up to what provisioning set
  aside), Dr Loans written off for the rest, Cr Loans receivable. Interest never recognised is not written off.
- **Overpayment** is the client's credit (a liability), refunded later; a refinance/top-up settles the old loan
  through Refinance clearing, which the new loan's disbursement nets to zero.

### Events

Subject = the Loandrift journal entry id. Payload: `version`, `app`, `org_id`, `loc_id`, `location_name`, `currency`
(the entry's, else the loan's, else the tenant default), `date` (`original_date` when Loandrift moved an entry out of
its own closed period, else `entry_date`), `document_type` (LOAN, REPAYMENT, WRITE_OFF, SAVINGS, INVESTMENT, ...),
`document_number` (a repayment's receipt number `RCP-xxxxxxxx`; savings/investment account number; else the loan
number; else the entry number), `document_id` (the source record), `entry_id`, `entry_number`, `source_type`,
`reversal`, `reverses_entry_id`/`_number`, `loan_id`, `loan_number`, `client_id`, **`party_id`** (the shared party,
`ld_clients.party_id`), `customer_name`, `amount` (the entry's total) and `lines`[`account_key`, `account_code`,
`account_name`, `account_type`, `debit`, `credit`, `description`]. Amounts are strings with two decimals.

| Loandrift source | Kind (reversal) |
|---|---|
| LOAN_DISBURSEMENT | `ld.loan_disbursed` (`ld.loan_disbursement_reversed`) |
| EXPENSE `charges-<loan>` | `ld.loan_charges_collected` (`ld.loan_charges_reversed`) |
| REPAYMENT | `ld.repayment_received` (`ld.repayment_reversed`) |
| WRITE_OFF / WRITE_OFF_RECOVERY | `ld.loan_written_off` (`ld.write_off_reversed`) / `ld.write_off_recovered` (`ld.write_off_recovery_reversed`) |
| PROVISION | `ld.loan_loss_provision` (`_reversed`) |
| SAVINGS_DEPOSIT / _WITHDRAWAL / _INTEREST | `ld.savings_deposit` / `ld.savings_withdrawal` / `ld.savings_interest` (`_reversed`) |
| INVESTMENT / INVESTMENT_RETURN | `ld.investment_received` / `ld.investment_paid_out` (`_reversed`) |
| CLIENT_CREDIT (refund) | `ld.client_credit_refunded` (`ld.client_credit_refund_reversed`) |
| EXPENSE (Loandrift expenses) | `ld.expense_paid` (`ld.expense_reversed`) |
| PENALTY / PENALTY_WAIVER | `ld.penalty_charged` / `ld.penalty_waived` (Loandrift posts neither today) |
| MANUAL, OPENING_BALANCE, YEAR_END_CLOSE, ASSET_ACQUISITION, ASSET_DISPOSAL, DEPRECIATION | **not published**: Loandrift's own bookkeeping; the business keeps these in Accounting, and copying them would count them twice |

### Loandrift paths and what covers them

| Path | Loandrift journal | Covered |
|---|---|---|
| `disburse_loan` (cash, bank, MoMo, ...) | LOAN_DISBURSEMENT + charges | yes — tested (MoMo, with a 500 processing fee) |
| A disbursement that fails after its journal is written | rolled back | nothing published — tested |
| `create_repayment` (counter, online gateway, auto-repayment from savings via `rp_auto`) | REPAYMENT (penalty, interest, principal, overpaid) | yes — tested (cash, with a penalty outstanding; bank) |
| `RepaymentActions.reverse` | mirror of the REPAYMENT entry | yes — tested |
| Restructure / refinance / top-up (`LoanReplacement`) | REPAYMENT by REFINANCE + disbursement with `settled` | yes (refinance clearing) |
| `WriteOffs.decide` (approve), `reverse`, `recover` | WRITE_OFF, its mirror, WRITE_OFF_RECOVERY | yes — tested (write-off, recovery) |
| Provisioning run (`AccountingControls`) | PROVISION | yes |
| Savings `deposit` / `withdraw` / `credit_interest` | SAVINGS_* | yes — tested (deposit by MoMo, withdrawal in cash) |
| Investments funding / periodic payout / completion | INVESTMENT, INVESTMENT_RETURN | yes |
| Client credit refund (`RepaymentActions.refund`) | CLIENT_CREDIT | yes |
| Loandrift expenses (`expenses_service`) | EXPENSE | yes |
| Penalties charged (nightly func) / waived | none | not posted: recognised when paid (above) |
| `update_repayment` (edits `paid_amount`) / `permanent_delete_repayment` | **none** — Loandrift's ledger is not corrected either | **not covered** (a Loandrift gap: its own books drift too; fix by routing edits through reverse + re-record) |
| Manual journals, opening balances, year-end, fixed assets and depreciation in Loandrift | MANUAL, ... | not published by design |

Proven by `scripts/test_ld_accounting_events.py` (Loandrift's real service code on a copy of dev-db with 38–41,
committing): after every step the events are exactly the expected kinds, once each, each one's lines equal the
Loandrift journal it names, and the published lines give Loans receivable = Loandrift's outstanding principal
(computed independently as approved − the principal part of every live repayment), interest and penalties = what
Loandrift collected, fees = the loan's charges.

### Posting rules and roles

`LdPostingRules`: one journal per event, filed under source **LOANS** (shown as LoanDrift), reference = the
document number, memo "LoanDrift loan repayment RCP-… · loan LN-… · client · branch". Each line posts to its key's
role, as Loandrift wrote it; a key the books do not take from Loandrift (e.g. FIXED_ASSETS) fails the posting with what
to do. Money keys share MyStoreGuard's money roles (one till, one bank, one wallet).

| Loandrift key | Role | Code | Standard account |
|---|---|---|---|
| CASH / BANK / MOBILE_MONEY | CASH / BANK / MOBILE_MONEY | 1010 / 1020 / 1040 | (as §3) |
| LOANS_RECEIVABLE | LOANS_RECEIVABLE | 1150 | Loans Receivable (LOAN_BOOK) |
| INTEREST_RECEIVABLE | LOAN_INTEREST_RECEIVABLE | 1155 | Loan Interest Receivable |
| PENALTIES_RECEIVABLE | LOAN_PENALTIES_RECEIVABLE | 1156 | Loan Penalties Receivable |
| REFINANCE_CLEARING | LOAN_REFINANCE_CLEARING | 1157 | Loan Refinance Clearing |
| LOAN_LOSS_ALLOWANCE | LOAN_LOSS_ALLOWANCE | 1159 | Allowance for Loan Losses |
| SAVINGS_LIABILITY | CLIENT_SAVINGS | 2430 | Client Savings Deposits |
| INVESTMENT_LIABILITY | CLIENT_INVESTMENTS | 2440 | Client Investments |
| CLIENT_CREDIT | CLIENT_CREDIT | 2450 | Client Credit Balances |
| INTEREST_PAYABLE | LOAN_INTEREST_PAYABLE | 2460 | Interest Payable to Clients |
| INTEREST_INCOME | LOAN_INTEREST_INCOME | 4100 | Interest Income – Loans |
| PROCESSING_FEE_INCOME / INSURANCE_INCOME / OTHER_CHARGES_INCOME | LOAN_FEE_INCOME / LOAN_INSURANCE_INCOME / LOAN_OTHER_CHARGES_INCOME | 4110 / 4111 / 4112 | Loan Fees & Charges / Loan Insurance Income / Other Loan Charges |
| PENALTY_INCOME | LOAN_PENALTY_INCOME | 4150 | Loan Penalty Income |
| INVESTMENT_INCOME | LOAN_INVESTMENT_INCOME | 4160 | Investment Income |
| LOAN_RECOVERY_INCOME | LOAN_RECOVERY_INCOME | 4170 | Recoveries of Written-off Loans |
| INTEREST_EXPENSE | INTEREST_EXPENSE | 6120 | Interest Expense |
| LOAN_WRITE_OFF | LOAN_WRITE_OFF | 6210 | Loans Written Off |
| LOAN_LOSS_PROVISION_EXPENSE | LOAN_LOSS_PROVISION | 6220 | Loan Loss Provision |
| PENALTY_WAIVER_EXPENSE | LOAN_PENALTY_WAIVER | 6230 | Penalty Waivers |
| OPERATING_EXPENSE | LENDING_EXPENSES | 6240 | Lending Operating Expenses |

1150, 4100, 4110 and 6120 are the demo chart's own loan accounts; the others are clear of it and of MyStoreGuard's
codes (4120 is instalment finance charges, 4130 MyStoreGuard's penalties, 2400–2420 customer liabilities, 1300 prepaid
expenses). Settings → Posting accounts lists them under **Lending**.

