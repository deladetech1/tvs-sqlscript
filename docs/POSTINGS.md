# Postings: other apps into the books

Roadmap Phase 1, step 1: **MyStoreGuard's sales post themselves into the business's Accounting books.**
Later steps add Loandrift, ZelosHR payroll, Expenses, Invoicing (the invoice of record) and Projects the same way.

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
| Accounting EF migration `20261019143911_AppPostings` | `acc_posting_inbox`, `acc_posting_accounts`, unique `ux_acc_journal_entries_event` |
| tvs-accounting-bk `app/src/Ledger/Postings/` | `PostingsWorker` (hosted service), `PostingRun` (ingest + post), `MsgPostingRules`, `PostingRoles`, `PostingAccounts` |
| tvs-accounting-bk `Entities/postings/` | `GET/PUT /api/v1/posting-accounts`, `GET /api/v1/postings` (+ `/statistics`, `/{id}`, `POST /{id}/retry`) |
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
| `msg.sale_voided` | a released sale cancelled, deleted, or its figures changed | `revision` voided, `reason` (CANCELLED, DELETED, CHANGED), `restocked`, the `figures` posted |
| `msg.payment_received` | a payment not part of its sale's event | method, amount, penalty part, `applied` = DEPOSIT (goods not released) or RECEIVABLE |
| `msg.payment_reversed` | a published payment refunded, deleted, reduced, or a gift card / loyalty tender put back by cancel | as received, with `reason` |
| `msg.return_processed` | a return reaches COMPLETED | lines, `taxes`, net, tax, restocking_fee, `restock_costs`, `refund` {cash, cash_method, store_credit, trade_in, plan_settled, plan_written_off, owed_to_customer, against_balance} |
| `msg.gift_card_issued` | a gift card created | amount, `issued_as` SOLD (has a PURCHASE transaction) or REWARD (customer-segment reward) |
| `msg.plan_refund_paid` | an instalment plan's refund marked handed back | amount, `applied` |
| `msg.posting_error` | the trigger could not describe a document | document_type, document_id, error |

How figures are worked out:

- `line_total` is gross (tax included, after pricing rules and the promo share). Tax per line is
  `line_total × taxes_applied[].amount / final_price`, because MyStoreGuard stores tax **per unit** (`tax_amount` and
  `taxes_applied` come from `verify_price` on the unit price). Net = gross − taxes. Found here: MyStoreGuard's own
  `total_tax_amount` and reports therefore understate tax for quantities above one.
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
| `cancel_sale` | status CANCELLED, stock back, gift card / loyalty put back | sale_voided (restocked), payment_reversed for the gift card / loyalty tender — tested |
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
stock received from suppliers and stock adjustments (purchases are a later step), MSG expenses, loyalty points earned
(no liability is booked for unredeemed points), a return's `exchange_difference_amount` (MyStoreGuard never settles it).

**Starts from now.** The first run records every existing sale, payment, return and gift card as already published
(the `BASELINE` marker); history belongs in the books' opening balances. Deposits held on unreleased sales at that
moment should be in the opening balance of Customer deposits (2420), and instalment balances of released sales in
Customer instalment balances (1120).

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
| sale_voided | the revenue side reversed (SALES_REVENUE, taxes, FINANCE_INCOME); INVENTORY if restocked | CUSTOMER_RECEIVABLE (the whole amount; payments stay where they are and are reversed by their own events); COST_OF_SALES if restocked |
| payment_received | method role | CUSTOMER_DEPOSITS or CUSTOMER_RECEIVABLE; PENALTY_INCOME (penalty part) |
| payment_reversed | the reverse | |
| return_processed | SALES_RETURNS (net); each tax; FINANCE_INCOME (plan written off); INVENTORY (restocked cost) | RESTOCKING_FEES; refund method role (cash); STORE_CREDIT_LIABILITY; OTHER_PAYMENTS (trade-in); CUSTOMER_RECEIVABLE (plan settled + owed + against balance + written off); COST_OF_SALES (restocked cost) |
| gift_card_issued | CASH (sold) or LOYALTY_REWARDS (reward) | GIFT_CARD_LIABILITY |
| plan_refund_paid | CUSTOMER_DEPOSITS or CUSTOMER_RECEIVABLE | CASH |

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

(The owner's "5000 cost of sales" is the Cost of Sales *group* in the starter chart; 5010 is its posting account.
Codes avoid the demo chart's other meanings: 2200 accrued expenses, 2300 a bank loan, 4020 service revenue.)

A standard account the chart lacks is **created** under its group (1000, 2000, 4000, 5000, 6000). A posting FAILS, with
"Account 2400 is Accrued Expenses (liability), not gift cards outstanding. Map Gift cards outstanding in Settings →
Posting accounts", only when the code belongs to a group, a control, an inactive account or one of another type, or
the group itself is missing. Customer balances use their own account (1120), never the Accounts Receivable control
(1100), so the invoice sub-ledger stays whole.

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
