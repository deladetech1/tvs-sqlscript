# Postings: other apps into the books

Roadmap Phase 1, step 1: **MyStoreGuard's sales post themselves into the business's Accounting books.**
Step 2 (§5): **Loandrift's loans, repayments, write-offs and savings do the same.**
Steps 3–4 (§6, §7): **Expenses' claims, advances, supplier bills and company-card spending, and Invoicing's invoices
(the invoice of record), payments, credit notes and refunds.**
Step 5 (§8): **ZelosHR's payroll runs, the pay sent out, SSNIT and Tier 2 remittances and staff loans.**
Step 6 (§9): **Projects: costs and revenue by project.** Projects posts nothing of its own; Expenses' and Invoicing's
postings carry the project, and Accounting reports profitability per project beside Projects' time at cost.

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
| `migrations/shared/20261019-42-expenses-accounting-events.sql` | Expenses: triggers on claims, expenses, payouts, bills, advances and statement lines; `exp_acc_state`; the baseline (§6) |
| `migrations/shared/20261019-43-invoicing-accounting-events.sql` | Invoicing: triggers on documents and payments; `inv_acc_state`; the MyStoreGuard guard; the baseline (§7) |
| tvs-shared-apps-bk `internal/apps/{expenses,invoicing}/accounting_events_test.go` | every path through the real handlers on Postgres; writes `exp_events.json` / `inv_events.json` for tvs-accounting-bk |
| Accounting EF migration `20261019143911_AppPostings` | `acc_posting_inbox`, `acc_posting_accounts`, unique `ux_acc_journal_entries_event` |
| `migrations/shared/20261019-44-zeloshr-payroll-accounting-events.sql` | ZelosHR: triggers on runs, lines, payment batches, filings and staff loans; `zhr_acc_state`; the baseline (§8) |
| `migrations/shared/20261019-45-accounting-customer-balances-name.sql` | 1120 renamed "Customer Balances" where it still had the old default name |
| tvs-zeloshr-admin-bk `tests/ZelosHR.Api.Tests/Pay/PayrollAccountingEventsTests.cs` | every payroll path through ZelosHR's real services on Postgres; writes `zhr_events.json` for tvs-accounting-bk |
| `migrations/shared/20261019-46-projects-in-the-books.sql` | Expenses' and Invoicing's events carry the project; `accounting.src_prj_projects` / `src_prj_time` for the report (§9) |
| tvs-shared-apps-bk `internal/apps/{expenses,invoicing}/accounting_projects_test.go` | the project on each event, through the real handlers; writes `exp_prj_events.json` / `inv_prj_events.json` for tvs-accounting-bk |
| tvs-accounting-bk `app/src/Ledger/Postings/` | `PostingsWorker` (hosted service), `PostingRun` (ingest + post), `PostingRules` (by kind), `MsgPostingRules`, `LdPostingRules`, `ExpPostingRules`, `InvPostingRules`, `ZhrPostingRules`, `PostingRoles`, `PostingAccounts` |
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
Customer balances (1120).

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
| PENALTY_INCOME | 4130 | Late Payment Penalties | CUSTOMER_RECEIVABLE | 1120 | Customer Balances |
| RESTOCKING_FEES | 4140 | Restocking Fees | CUSTOMER_DEPOSITS | 2420 | Customer Deposits |
| COST_OF_SALES | 5010 | Cost of Goods Sold | GIFT_CARD_LIABILITY | 2400 | Gift Cards Outstanding |
| INVENTORY | 1200 | Inventory | STORE_CREDIT_LIABILITY | 2410 | Customer Store Credit |
| ROUNDING | 6900 | Rounding Differences | TAX:&lt;id&gt; | 2101 VAT, 2102 NHIL, 2103 GETFund, 2104 COVID-19, else 2100 | by the tax's name |
| STOCK_ADJUSTMENT | 5020 | Stock Adjustments | SUPPLIER_PAYABLE | 2020 | Supplier Balances |
| STOCK_WRITE_OFF | 5030 | Stock Written Off | | | |

(The owner's "5000 cost of sales" is the Cost of Sales *group* in the starter chart; 5010 is its posting account.
Codes avoid the demo chart's other meanings: 2200 accrued expenses, 2300 a bank loan, 4020 service revenue.)

**One account per tax (since EF CoreTaxCodes, 2026-10-19).** Taxes are defined only in Core Platform
(`cp_tax_rates`, 20261019-24), and an Accounting tax code is a Core tax plus Accounting's settings
(`acc_tax_codes.core_tax_rate_id`). When a tax code is linked to Core tax X and has an output account, the posting
role `TAX:X` posts to **that code's output account**, ahead of any Settings → Posting accounts mapping: an invoice
taxed in Accounting and a sale taxed with the same tax in MyStoreGuard or Invoicing land on the same payable account.
The tax code is the single source: changing `TAX:X` in Settings → Posting accounts writes the code's output account,
and a separate `acc_posting_accounts` row for the role is removed (the migration removed those of codes it linked).
A tax with no linked code keeps the mapping-or-standard-by-name rule above.

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

## 6. Expenses (20261019-42)

### Why database triggers, not the Go service

Expenses has no single choke point for money. A claim is approved by its last approver, by finance, or by itself under
the auto-approve limit; it is paid back through the payout gateway (settled later by the `expenses-payouts` job in the
function app, or by "Check payments"), by hand, through ZelosHR's payroll (marked paid when a payroll run is approved,
read back by the same job), or by netting an advance (`netAdvances` writes the payout, settles it and rolls the claim
forward in one go). Advances and bills are paid the same ways; statement lines are matched, reopened, set aside or made
into expenses. Publishing from Go would mean `events.Publish` in a dozen places, two of them in jobs, each to be
remembered by the next path. Every one of them ends in a write to `exp_claims`, `exp_expenses`, `exp_claim_payouts`,
`exp_bills`, `exp_bill_payouts`, `exp_advances` or `exp_statement_lines`, so the triggers sit there.

Same machinery as §1: constraint triggers `DEFERRABLE INITIALLY DEFERRED`, `ENABLE ALWAYS`, reading each document at
COMMIT and publishing only the difference from what `expenses.exp_acc_state` says was last published (a void of the
old figures, then the new revision). A write that fails rolls back and publishes nothing. Fail open: a describing error
publishes `exp.posting_error` and the write commits. Starts from now: everything existing at the first run is
baselined (`BASELINE`); claims owed, advances outstanding and bills unpaid that day belong in the opening balances of
2210, 1310 and 2020.

### Events

Subject = the Expenses id. Common payload: `version`, `app`, `org_id`, `currency`, `date` (business date),
`document_type`, `document_number`, `document_id`, `amount`. Spending events carry `lines`[`category_id`,
`category_name`, `category_code`, `category_kind`, `net`, `tax`], `tax`, `total`.

| Kind | When | Extra |
|---|---|---|
| `exp.claim_approved` / `exp.claim_voided` | a claim reaches approved (or paid); voided when its money changes (CHANGED), it leaves approved (UNAPPROVED) or is deleted | `claimant_name`, `title`, `company_paid` (left out, see below); in the claim's currency (`amount_base`), tax at the expense's own rate |
| `exp.claim_reimbursed` / `_reimbursement_reversed` | a claim payout reaches success or manual / is reversed | `method` GATEWAY, MANUAL, PAYROLL, ADVANCE; `reference` |
| `exp.bill_approved` / `exp.bill_voided` | a bill approved (or paid) / cancelled after approval (CANCELLED) or changed | `supplier_name`, `party_id` (cp_parties), category = the bill's, else the supplier's |
| `exp.bill_paid` / `exp.bill_payment_reversed` | a bill payout completes / is reversed | `method` |
| `exp.advance_paid` / `exp.advance_payment_reversed` | an advance's payout completes / is reversed | `method` |
| `exp.advance_returned` / `exp.advance_return_reversed` | `returned` goes up (the difference) | `method` CASH |
| `exp.company_spend` / `exp.company_spend_reversed` | a statement line of money out matched to an expense (or made into one) / unmatched, set aside | `account_kind` (BANK, CARD, MOBILE_MONEY, CASH), `account_name`, `expense_id`, in the expense's currency |
| `exp.posting_error` | the trigger could not describe a document | `error` |

### Expenses paths and what covers them

| Path | Writes | Published |
|---|---|---|
| Expense created, edited, deleted; claim drafted, submitted, sent back, cancelled | expenses, claim status | nothing — tested |
| Claim rejected | status rejected | nothing (it never posted) — tested |
| Claim approved (last step, finance, auto-approve) | status approved | claim_approved — tested (meals with VAT, mileage, per diem) |
| Expenses of an approved claim changed (not possible in the app today) | expenses | void CHANGED + new revision |
| Pay back by hand / through the gateway (job or check-payments) | claim payout success/manual | claim_reimbursed — tested (MANUAL; GATEWAY once however often checked) |
| Gateway payout failed | payout failed | nothing — tested |
| Pay back by payroll (ZelosHR one-off, marked paid by the job) | payout success | claim_reimbursed PAYROLL |
| Advance netted off a claim (`apply-advances`) | payout method advance + claim paid | claim_reimbursed ADVANCE — tested |
| Advance paid out / reversed | advance paid | advance_paid — tested |
| Advance handed back | `returned` | advance_returned — tested |
| Bill opened / approved / paid / cancelled after approval | bill, payouts | nothing / bill_approved / bill_paid / bill_voided — tested |
| Repeating bill made by the job | new open bill | nothing until approved |
| Statement line made into an expense, or matched to one | line matched | company_spend — tested (company card) |
| Statement line reopened or set aside | line open/ignored | company_spend_reversed — tested |
| Statement line matched to a claim payout, bill payout or advance | reconciliation only | nothing (the payout already posted) |
| A refused request (paying twice, ...) | rolled back | nothing — tested |

**Company-paid expenses.** An expense matched to a statement line is spending the business already paid: it posts once,
as `exp.company_spend` (Dr category / Cr the account's role), and a claim that contains it leaves it out (its
`company_paid`). Expenses pays the claimant only what is owed (tvs-shared-apps-bk 4d0d42e): every payout path pays
`owed` = reimbursable − paid, where reimbursable leaves out company-paid spending, and a claim is marked paid once its
reimbursable part is paid; a claim that is wholly company-paid is paid on approval and posts no reimbursement. So Owed to
employees nets to zero for every paid claim, company-paid lines included.

Not covered: request budgets and commitments (no money moves), billable expenses re-invoiced (Invoicing posts the
invoice; the expense already posted here), expenses in a claim currency other than the books' base convert at the books'
rate (§3), a statement line's own amount (the expense's amount is posted, which is the line's).

### Posting rules and roles

`ExpPostingRules`: source **EXPENSES** (shown as Expenses), reference = the claim / bill / advance number.

| Event | Debit | Credit |
|---|---|---|
| claim_approved | each category's role (net); EXPENSE_INPUT_TAX (tax) | EMPLOYEE_REIMBURSEMENTS (total) |
| claim_reimbursed | EMPLOYEE_REIMBURSEMENTS | the payout's role |
| bill_approved | each category's role (net); EXPENSE_INPUT_TAX | SUPPLIER_PAYABLE (shared with MyStoreGuard: one supplier, one balance) |
| bill_paid | SUPPLIER_PAYABLE | the payout's role |
| advance_paid | EMPLOYEE_ADVANCES | the payout's role |
| advance_returned | CASH | EMPLOYEE_ADVANCES |
| company_spend | each category's role (net); EXPENSE_INPUT_TAX | the account's role: CARD → COMPANY_CARD, BANK → BANK, MOBILE_MONEY → MOBILE_MONEY, CASH → CASH |
| *_voided, *_reversed | the reverse | |

Payout roles: GATEWAY → CARD (1060, the gateway's balance, as for card and online payments), MANUAL → BANK, PAYROLL →
PAYROLL_REIMBURSEMENTS (cleared when ZelosHR's payroll posts, so the bank is not counted twice), ADVANCE →
EMPLOYEE_ADVANCES.

| Role | Code | Standard account |
|---|---|---|
| EMPLOYEE_REIMBURSEMENTS | 2210 | Employee Reimbursements Payable |
| EMPLOYEE_ADVANCES | 1310 | Employee Advances |
| PAYROLL_REIMBURSEMENTS | 2220 | Reimbursements via Payroll |
| COMPANY_CARD | 2030 | Company Card Payable (may be pointed at a liability or, for a debit card, the bank asset) |
| EXPENSE_INPUT_TAX | 1400 | VAT Input Recoverable (the starter chart's) |
| OTHER_EXPENSES | 6290 | General Expenses (uncategorised) |
| `EXPENSE_CATEGORY:<id>` | see below | one per category |

**Categories → accounts.** Each category is a role of its own, `EXPENSE_CATEGORY:<category id>`. Its standard account
is the category's own **code** in Expenses (Settings → Categories → Code: the code Expenses' Xero/Sage exports already
use) when that is a chart code starting 5–9; else by the category's name, word by word: transport, fuel, taxi,
vehicle, parking, mileage → 6040 Transport & Logistics; travel, flight, airfare, hotel, accommodation, lodging, per
diem → 6250 Travel & Accommodation; meals, food, entertainment → 6260 Meals & Entertainment; software, subscriptions →
6270; training, course, conference → 6280 Training & Development; office, supplies, stationery → 6090; phone,
internet, airtime, data → 6110; utilities → 6030; marketing, advertising → 6050; professional, legal, consulting,
audit → 6080; repairs, maintenance → 6100; rent, lease → 6020; bank charges → 6060; anything else → 6290 General
Expenses. Missing accounts are created under 6000 (or 5000). **Posting never waits for a mapping**: to change one, go
to Accounting → Settings → Posting accounts → Expenses, where every category that has posted is listed by name, and
point it at any expense account; postings from then on go there (earlier ones stay where they are).

1310, 2030, 2210, 2220 and 6250–6290 are clear of the demo chart, MyStoreGuard's codes and LoanDrift's 6210–6240;
6020–6110 are the demo chart's own expense accounts with the same meaning.

Proven by tvs-shared-apps-bk `TestExpensesAccountingEvents` (the real handlers on dev-db's schema) and tvs-accounting-bk
`InvExpPostingsTests`: after every step, Owed to employees = approved claims less paid back, advances = paid out less
netted and handed back, Supplier balances = approved bills less paid, the company card, input tax and each category's
expense equal what Expenses' own tables say, and the trial balance balances.

## 7. Invoicing (20261019-43): the invoice of record

Owner decision: customers get their invoices from Invoicing, and each one posts here as a receivable. Accounting's own
invoice screen stays for accountants' manual entries.

### Why database triggers, not the Go service

Invoicing writes documents and payments from the editor (issue, correct, void), payments by hand, the customer's online
payment (settled on return, on opening the link, by "Check online payments", or by the payments job), the portal's
pay-several-at-once, autopay on a saved card (a job), credit notes (applied by hand, auto-applied when made for an
invoice, refunded), refunds (a credit note issued and paid back in one step), late fees and recurring invoices (jobs),
and bank reconciliation recording a payment from a statement line. Every one ends in a write to `inv_invoices` or
`inv_payments`; `recalcInvoice` is not on every path. Triggers on those two tables see them all, jobs included.

Same machinery as §1 and §6 (`invoicing.inv_acc_state`, deferred, `ENABLE ALWAYS`, fail open with `inv.posting_error`,
baseline: open balances that day belong in the opening balances of 1110 and 2470).

### The MyStoreGuard guard (no sale twice)

Invoicing brings MyStoreGuard's invoices in **linked** (`source_app = 'mystoreguard'`, `source_id` = MSG's invoice,
20261019-22). MyStoreGuard already posts that sale and every payment on it (§1) — including payments taken in
Invoicing, which reach MyStoreGuard through `inv_msg_payment_queue` and are posted by MSG's own `create_payment` with
its own `msg.*` event; the shop's own payments show in Invoicing as channel `mystoreguard`. So **a document with
`source_app` and `source_id` set publishes nothing from Invoicing, and neither does any payment on it**
(`invoicing.inv_acc_linked`). Tested: an MSG invoice brought in, paid 100 in Invoicing (queued for MSG) and 50 at the
shop, publishes no `inv.*` event; the end-to-end run shows MSG's 50 posted once by MyStoreGuard (Customer deposits) and
nothing from Invoicing. Any app that links documents into Invoicing in future is covered by the same rule.

### Events

Subject = the Invoicing id. Common payload: `version`, `app`, `org_id`, `currency` (the document's), `date`,
`document_type`, `document_number`, `document_id`, `customer_id`, `customer_name`, `amount`.

| Kind | When | Extra |
|---|---|---|
| `inv.invoice_issued` / `inv.invoice_voided` | an invoice issued (status open/paid); voided (VOIDED), corrected while unpaid (CHANGED: void + revision n+1) or deleted | `revision`, `subtotal` (= total − charged tax), `taxes`[tax_id, name, short_name, amount] (charged: standard, zero-rated), `tax`, `withheld`, `receivable` (= total − withheld), `total`, `late_fee_for_id` |
| `inv.credit_note_issued` / `inv.credit_note_voided` | the same for a credit note (open/applied) | `credit_for_id`, `credit_for_number` |
| `inv.payment_received` / `inv.payment_reversed` | a payment received (any method but credit) / voided or deleted | `method` (CASH, BANK_TRANSFER, MOBILE_MONEY, CARD, CHEQUE, ONLINE, OTHER), `against`, `receipt_number`, `invoice_number`, `channel` |
| `inv.credit_applied` / `inv.credit_application_reversed` | credit from a credit note used on an invoice (method credit_note) | `credit_note_number` |
| `inv.refund_paid` / `inv.refund_reversed` | money paid back (kind refund: a credit note refunded) | `method`, `against` |
| `inv.posting_error` | the trigger could not describe a document | `error` |

### Invoicing paths and what covers them

| Path | Published |
|---|---|
| Draft created / edited / deleted; quotes; purchase orders | nothing — tested (draft, quote) |
| Issue (editor, recurring job, late-fee job) | invoice_issued — tested |
| Correct an issued, unpaid invoice (money changed) | invoice_voided CHANGED + invoice_issued revision 2 — tested; words only (notes) — nothing, tested |
| Void (only without payments) | invoice_voided VOIDED — tested |
| Payment by hand, online (return / link / check / job), portal multi-pay, autopay, bank reconciliation | payment_received — tested (MoMo, cash, bank; online once however often verified) |
| A refused payment (more than owed, ...) | nothing — tested |
| Payment voided | payment_reversed — tested |
| Credit note issued for an invoice (auto-applied) / applied by hand | credit_note_issued + credit_applied — tested |
| Credit note refunded; refund on an invoice (credit note issued and paid back) | credit_note_issued + refund_paid — tested |
| MyStoreGuard invoices brought in linked, paid here or at the shop | nothing (MyStoreGuard posts them) — tested |
| A document the trigger cannot describe | inv.posting_error, the write commits — tested |

Not covered: **write-offs** — Invoicing has no write-off action today (an uncollectable balance can only be cleared with
a credit note, which reverses revenue); when one is added it should publish `inv.invoice_written_off` posting Dr Bad
debts / Cr Invoiced customer balances. Exchange differences between an invoice and its payment in a foreign currency
(each converts at the books' rate on its own date, §3). Purchase orders (no money moves; supplier bills live in
Expenses).

### Posting rules and roles

`InvPostingRules`: source **INVOICING** (shown as Invoicing), reference = the invoice / credit note / receipt number.

| Event | Debit | Credit |
|---|---|---|
| invoice_issued | INVOICE_RECEIVABLE (receivable); WITHHOLDING_TAX_RECEIVABLE (withheld) | INVOICE_REVENUE (subtotal); each TAX:&lt;tax id&gt; (TAX_PAYABLE when a tax has no id) |
| credit_note_issued | INVOICE_REVENUE; each tax | INVOICE_CUSTOMER_CREDIT; WITHHOLDING_TAX_RECEIVABLE |
| payment_received | the method's role (as §3: CASH, BANK, MOBILE_MONEY, CARD for card and online, OTHER_PAYMENTS) | INVOICE_RECEIVABLE |
| credit_applied | INVOICE_CUSTOMER_CREDIT | INVOICE_RECEIVABLE |
| refund_paid | INVOICE_CUSTOMER_CREDIT (a credit note's) or INVOICE_RECEIVABLE (an invoice's) | the method's role |
| *_voided, *_reversed | the reverse | |

| Role | Code | Standard account |
|---|---|---|
| INVOICE_RECEIVABLE | 1110 | Invoiced Customer Balances — its own, never the Accounts Receivable control (1100), which stays Accounting's own invoices' |
| INVOICE_REVENUE | 4040 | Invoiced Sales Revenue (point it at 4010 Sales Revenue to report one sales line) |
| INVOICE_CUSTOMER_CREDIT | 2470 | Customer Credit Notes |
| WITHHOLDING_TAX_RECEIVABLE | 1410 | Withholding Tax Receivable |
| TAX:&lt;id&gt; | 2101 VAT, 2102 NHIL, … else 2100 | by the tax's name, as MyStoreGuard's (listed together in Settings → Posting accounts → Taxes) |

1110, 1410, 2470 and 4040 are clear of the demo chart, MyStoreGuard's and LoanDrift's codes.

Proven by tvs-shared-apps-bk `TestInvoicingAccountingEvents` and tvs-accounting-bk `InvExpPostingsTests`: after every
step (issued, part paid, a payment voided, credit note, refund, a correction and a void, paid off, an MSG invoice),
Invoiced customer balances = Invoicing's outstanding, revenue = invoices less credit notes net of tax, VAT = Invoicing's
tax, credit left = credit notes' balance, money by method = what Invoicing received, and the trial balance balances.

## 8. ZelosHR payroll (20261019-44)

### What ZelosHR has

A full payroll, in the `zeloshr` schema (there is no separate payroll app or schema: `app-payroll` in `cp_apps` has no
code or tables behind it). `PayrollService` (tvs-zeloshr-admin-bk; the same code is deployed again in
tvs-zeloshr-employees-bk on the same database) opens a run per pay group and month, calculates every line from the pay
in force and Ghana's rule pack (`PayRulePacks.Ghana`: PAYE bands, SSNIT 5.5% employee + 13% employer, remitted as 13.5%
Tier 1 and 5% Tier 2), or takes a local provider's results (external mode); then submit → approve (never by the preparer)
→ paid. Lines (`zhr_payroll_lines`) hold earnings (basic, company components, one-offs, overtime, final settlements),
deductions (`paye`, `ssnit_employee`, company deductions `pc_*`, staff loan instalments `loan_*`, Tier 3 as a
component) and employer contributions (`ssnit_employer`, company `pc_*`). Pay goes out in batches per channel
(`zhr_payment_batches`, items paid / failed / sent again); the run is marked paid by hand or when every batch is
confirmed. Filings (`zhr_payroll_filings`) record the SSNIT and Tier 2 remittances as paid; the PAYE return is a
*return* (filed, never "paid"). Staff loans and salary advances (`zhr_employee_loans`) are repaid from pay. Expenses
pays claims back on the payslip as a one-off (§6, method PAYROLL).

### Why database triggers

Two services in two deployments write a run: calculate / upload / approve / mark paid in `PayrollService`, batches in
`PayrollExtrasService` (whose last confirmation marks the run paid in a second transaction); filings and loans have
their own services. All of them end in writes to `zhr_payroll_runs`, `zhr_payroll_lines`, `zhr_payment_batches`,
`zhr_payroll_filings` or `zhr_employee_loans`, so the triggers sit there — the same machinery as §1 and §6:
deferred constraint triggers, `ENABLE ALWAYS`, `zeloshr.zhr_acc_state` remembers what was published, only differences
are published, a rolled-back write publishes nothing, a describing error publishes `zhr.posting_error` and the write
commits. A run is synced once per transaction however many lines a recalculation rewrote. Starts from now: runs,
payments, remittances and loans existing at the first run are `BASELINE` (net pay, PAYE, SSNIT and loans outstanding
that day belong in the opening balances of 2170, 2150, 2160/2165 and 1320).

**Which books.** ZelosHR is per organisation; the books are per business. Events go to the organisation's business that
subscribes to Accounting (then ZelosHR; the oldest first), and a run stays with the books its first event went to.

### Events

Subject = the ZelosHR id. Common payload: `version`, `app`, `org_id`, `currency`, `date`, `document_type`,
`document_number`, `document_id`, `amount`.

| Kind | When | Extra |
|---|---|---|
| `zhr.payroll_approved` / `zhr.payroll_voided` | a run reaches approved (or paid) / is deleted, leaves approval (UNAPPROVED) or its lines change (CHANGED: void + revision) | `period`, `pay_date`, `pay_group`, `country`, `mode`, `employees`; `earnings`, `deductions`, `employer` [kind, code, label, amount] added up across people; `gross`, `net`, `ssnit_tier1`, `ssnit_tier2`; `amount` = gross + employer contributions |
| `zhr.salaries_paid` / `zhr.salary_payment_reversed` | net pay goes out: batch items confirmed paid, or the run marked paid (the rest) / a paid item fails afterwards | `lines` [channel BANK_TRANSFER / MOBILE_MONEY, amount], `run_paid` |
| `zhr.remittance_paid` / `zhr.remittance_reversed` | SSNIT (Tier 1) or Tier 2 recorded as paid in Filings / taken back, or its date changed (void + new) | `allocation` TIER1 / TIER2, `payee`, `period`, `reference`; amount = what the period's runs in the books owe that payee |
| `zhr.staff_loan_granted` / `zhr.staff_loan_voided` | a loan or salary advance recorded / deleted, or cancelled before any instalment reached the books | `employee_name`, `name`, `installment`, `method` BANK |
| `zhr.posting_error` | a run the trigger could not describe | `error` |

Kinds: earnings BASIC (basic salary, a provider's gross), SETTLEMENT (final settlement), OVERTIME, BONUS (bonus,
commission, incentive, 13th month by name), REIMBURSEMENT (a one-off on this run that an Expenses claim payout points
at), ALLOWANCE (anything else); deductions PAYE, SSNIT, LOAN, OTHER; employer SSNIT, OTHER. Tier 2 = 5% of basic per
person (never more than the SSNIT paid), Tier 1 the rest of employee + employer SSNIT — so the two together are every
cedi of SSNIT, and each equals ZelosHR's own Filings schedule when rates are the pack's.

Dates: a run in its own month, never after the day it was approved (the pay date, else the period's end, else the
approval day); payments, remittances and loans the day they happened.

### ZelosHR paths and what covers them

| Path | Published |
|---|---|
| Run opened, calculated, recalculated, submitted, sent back, cancelled before approval | nothing — tested |
| Approve refused (the preparer), an approval that rolls back | nothing — tested |
| Approve | payroll_approved — tested (basic, allowance, bonus, overtime one-off, Expenses claim, union dues, staff loan, employer insurance) |
| Provider results uploaded (external mode), then approved | payroll_approved with the provider's gross as BASIC and its deductions as one OTHER lump (not split into PAYE / SSNIT); not exercised by the test |
| Batches made / sent; an item fails before payment | nothing — tested |
| Batch confirmed (paid items) | salaries_paid — tested (bank, mobile money) |
| A paid item fails afterwards / is sent again and confirmed | salary_payment_reversed / salaries_paid — tested |
| Last batch confirmed → run marked paid; Mark paid by hand | the rest of net pay, salaries_paid — tested (through the last batch) |
| Filings: SSNIT / Tier 2 recorded paid, date corrected, taken back | remittance_paid / reversed + paid / reversed — tested |
| Filings: PAYE return filed; a refused record | nothing — tested |
| Staff loan recorded; cancelled after repayments; cancelled before any | staff_loan_granted / nothing / staff_loan_voided — tested |
| A run the trigger cannot describe | zhr.posting_error, the write commits — tested |

Not covered: **PAYE paid to GRA** (ZelosHR records only that the return was filed; record the payment in Accounting, Dr
2150 / Cr bank); a staff loan's payout method (ZelosHR does not record it: posted from the bank); a cancelled loan's
balance left after some instalments (stays in 1320 until written off or repaid in Accounting); Tier 3 and other
deductions paid over to their collectors (no record in ZelosHR); ZelosHR has no void of an approved run (only a data fix,
which publishes `payroll_voided`). Found and fixed on the way: `PayrollSetupRepository.LoanRepaymentsAsync` ran
`LIKE` on the jsonb `deductions_json` (Postgres 42883), so every calculation and the loan list failed once any run
had been approved (both ZelosHR backends).

### Posting rules and roles

`ZhrPostingRules`: source **HR** (shown as ZelosHR), reference = `PAY-<period>` / the remittance reference / `LOAN-…`.

| Event | Debit | Credit |
|---|---|---|
| payroll_approved | PAYROLL_SALARIES (basic, settlement, provider gross), PAYROLL_OVERTIME, PAYROLL_BONUSES, PAYROLL_ALLOWANCES; PAYROLL_REIMBURSEMENTS (claims paid on the payslip: clears what Expenses credited, §6); PAYROLL_EMPLOYER_SSNIT; PAYROLL_EMPLOYER_BENEFITS | NET_PAY_PAYABLE (net); PAYE_PAYABLE; SSNIT_PAYABLE (Tier 1); PENSION_TIER2_PAYABLE (Tier 2); STAFF_LOANS (instalments); PAYROLL_DEDUCTIONS_PAYABLE (other deductions and the company's other contributions) |
| salaries_paid | NET_PAY_PAYABLE | BANK (bank transfer), MOBILE_MONEY, CASH |
| remittance_paid | SSNIT_PAYABLE or PENSION_TIER2_PAYABLE | BANK |
| staff_loan_granted | STAFF_LOANS | BANK |
| *_voided, *_reversed | the reverse | |

| Role | Code | Standard account |
|---|---|---|
| PAYROLL_SALARIES | 6010 | Salaries & Wages (the starter chart's) |
| PAYROLL_OVERTIME | 6011 | Overtime |
| PAYROLL_BONUSES | 6012 | Bonuses & Commissions |
| PAYROLL_ALLOWANCES | 6013 | Staff Allowances |
| PAYROLL_EMPLOYER_SSNIT | 6014 | Employer Social Security |
| PAYROLL_EMPLOYER_BENEFITS | 6015 | Staff Benefits |
| NET_PAY_PAYABLE | 2170 | Net Salaries Payable (subtype PAYROLL) |
| PAYE_PAYABLE | 2150 | PAYE Payable (the demo chart's) |
| SSNIT_PAYABLE | 2160 | SSNIT Payable (the demo chart's; Tier 1) |
| PENSION_TIER2_PAYABLE | 2165 | Tier 2 Pension Payable |
| PAYROLL_DEDUCTIONS_PAYABLE | 2180 | Other Payroll Deductions Payable |
| STAFF_LOANS | 1320 | Staff Loans & Advances |

Clear of MyStoreGuard's, LoanDrift's (6120, 6210–6240), Expenses' (1310, 2030, 2210, 2220, 6250–6290) and Invoicing's
codes and of the demo chart's other meanings (2100–2120 taxes, 2200 accrued expenses, 1300 prepaid). Settings → Posting
accounts lists them under **Payroll**; point allowances at 6010 to report one pay line.

Proven by tvs-zeloshr-admin-bk `PayrollAccountingEventsTests` (the real services on a copy of dev-db with 38–44: each
step publishes exactly its events, once; refusals and rollbacks publish nothing) and tvs-accounting-bk `ZhrPostingsTests`
/ `ZhrPostingsLiveTests`: after every step, gross pay = salaries + overtime + bonuses + allowances + claims paid; PAYE
payable = ZelosHR's PAYE return; SSNIT and Tier 2 payables = ZelosHR's own Tier 1 / Tier 2 schedules less what Filings
says was remitted; Net salaries payable = net pay less what the batches and the run say was paid; Staff loans = lent less
instalments; the trial balance balances.

## 9. Projects (20261019-46): costs and revenue by project

### What of Projects is money, and what posts

| In Projects | Money? | In the books |
|---|---|---|
| Time logged (`prj_worklogs`), with bill and cost rates (`prj_rates`: person / role / everyone, project or workspace, most specific first) | billable time is what a client is charged; cost rate × hours is the internal cost of people's time | **not posted.** Projects has no "post to books" step and no approved-timesheet state: a worklog can be edited or deleted at any time, and wages are already posted, once, by ZelosHR's payroll (§8). Posting time × cost rate would count the same salaries twice (Dr project labour / Cr what?). Shown instead, read-only, in Accounting's **Project profitability** report |
| Billable time and expenses billed to a client | revenue | through **Invoicing**, the invoice of record (§7): a business with both apps puts a project's unbilled time and expenses on an Invoicing invoice (20261019-13); that invoice posts, its revenue tagged with the project |
| Projects' own invoices (`prj_invoices`, from before Invoicing was built) | revenue | **not posted**: Invoicing is the invoice of record (owner decision, §7). A business keeping books in Accounting bills projects through Invoicing; Projects' own invoice stays for businesses without Invoicing |
| Project expenses noted in Projects (`prj_expenses`) | a note of spending, with no payer, payment or supplier | **not posted** (nothing says how it was paid). Spending recorded in **Expenses** with the project (claims, bills, company card) posts there (§6), tagged with the project |
| Budgets (money / hours), fixed fees, rates | plans and prices | not posted (no money moves); the budget is shown beside the report's figures |

MyStoreGuard, LoanDrift and ZelosHR documents carry no project (no project column on sales, loans or payroll; the
suite links of 20261017-06 are cards, not charges), so only Expenses and Invoicing tag.

### The project on the events

Expenses (redefines 20261019-42's figure functions; the money is unchanged):

- `exp.claim_approved` / `_voided`: `lines` are by category **and project** — each expense's own `project_id`, else its
  claim's. A line with a project carries `project_id`, `project_key`, `project_name`; one without carries none.
- `exp.bill_approved` / `_voided`: the bill's `project_id` on its line.
- `exp.company_spend` / `_reversed`: the matched expense's project (else its claim's).
- Payouts, advances and returns carry none: they move balance-sheet money, not a project's cost.

Invoicing (redefines 20261019-43's `inv_acc_doc_figures`):

- `inv.invoice_issued` / `inv.credit_note_issued` and their voids carry `projects` [`project_id`, `project_key`,
  `project_name`, `net`] when any line bills a project (`inv_invoice_lines.source_project_id`): each project's share of
  the revenue, its lines' `net` over all lines' `net`, of the document's `subtotal` (so a whole-invoice discount is
  shared out). The rest of the subtotal is untagged. Payments carry none.

**Tags are analysis, not money.** They are never part of what counts as a change (`exp_acc_state.value->'money'`,
`inv_acc_fingerprint` leaves out `projects`): documents published before 46 stay as posted (untagged) and nothing is
posted again because of it; a project renamed, or set on a document after it posted, does not re-post it (the next
money change does). A void reverses exactly what was posted, tags included. The project's name and key come from
`projects.prj_projects`, read dynamically: a database without Projects still describes (the id alone).

### In Accounting

`ProjectDimensions`: each tagged line posts with `acc_journal_lines.cost_centre_id` = the project's **PROJECT
dimension** (`acc_dimensions`, kind PROJECT), created on first use: id `dim_prj_` + md5(tenant|business|project) (the
same project always lands on the same dimension), code = the project's key (`WEB`; `WEB-P1…` when the books already
use that code for another PROJECT dimension), name = the project's (kept up to date by later postings), description
"From Projects". Tagged lines: Expenses' category lines (net), Invoicing's revenue lines. Tax, payables, receivables
and money lines are never tagged.

**Project profitability** (Reports → Project profitability, `GET /api/v1/reports/project-profitability?from_date&to_date`,
`permission-accounting-report-get`): per PROJECT dimension (from Projects or made by hand), revenue, cost of sales and
expenses of posted lines analysed under it between the dates, and posted profit. For a business **subscribed to
Projects** (`cp_business_app_tier`, `app-projects`; fails closed), also the hours logged in the period, billable hours,
time at cost (minutes × the cost rate Projects applies, `accounting.src_prj_time`; hours with no cost rate are counted
but not costed, and said so), profit after time, margin and the project's budget. A project with time and nothing
posted is listed too. Time costed in another currency converts at the books' rate on the end date. Read-only: nothing
here posts.

Proven by tvs-shared-apps-bk `TestExpensesAccountingEventsCarryTheProject` / `TestInvoicingAccountingEventsCarryTheProject`
(real handlers on a copy of dev-db with 46) and tvs-accounting-bk `ProjectPostingsTests` (the captured events posted:
one dimension per project, lines on it, the report with and without Projects) and `ProjectPostingsLiveTests` (a claim,
a bill, a company payment and an invoice on a project written by the real code, posted by the real worker, the report
read against Projects' own tables through the views).

