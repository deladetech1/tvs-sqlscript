# Shared suppliers and customers (`core_platform.cp_parties`)

Every app keeps the people and companies a business deals with in **one** place:
`core_platform.cp_parties`, created by `migrations/shared/20261019-29-coreplatform-shared-suppliers.sql`.

## The rules

- **Per business.** Every row has `bus_id`. A pharmacy and a hardware shop of one owner have different
  suppliers; nothing is shared across businesses. Every lookup filters by `bus_id`.
- **One record per party, with roles.** `is_supplier`, `is_customer`; a party can be both.
- **Apps keep only what is theirs.** An app's extra fields go in its own table keyed by `party_id`
  (`mystoreguard.msg_supplier_profiles`, `expenses.exp_vendor_settings`).
- **Ids are kept when an app moves over**, so everything that already points at a supplier still does.
- **Merging.** `core_platform.cp_party_merge(keep, drop, by)` moves every reference listed in
  `core_platform.cp_party_references` and marks `drop` deleted. **An app that stores a party id adds its
  column to `cp_party_references`.**
- **Deleting** marks `deleted_at`; a party is never removed while something points at it.

## Who has moved

| App | Status |
|---|---|
| MyStoreGuard | `msg_suppliers` and `msg_customers` are views of `cp_parties` with INSTEAD OF triggers; its code is unchanged. Its own fields are in `msg_supplier_profiles` and `msg_customer_profiles` (location, picture). The old tables are kept as `*_legacy`. |
| Expenses | Vendors are `cp_parties` rows (`exp_vendors_legacy` kept). Billable customers are the business's customers. |
| Invoicing | `inv_customers` is a view (role customer/supplier/both). Its own fields are in `inv_customer_settings`. Its copies of MyStoreGuard customers were merged into them by the import's link (20261019-30); its "import from MyStoreGuard" now merges records entered in both apps. |
| Loandrift | Not yet. Clients are per location with identity checks and many cascading keys; they will point at a party. |
| CRM | Not yet. Contacts are people at a customer; they will link to a party rather than become one. |
| Accounting | `acc_customers` and `acc_suppliers` are views of `cp_parties` with INSTEAD OF triggers (20261019-37); its own fields are in `acc_customer_settings` / `acc_supplier_settings`. The old tables are kept as `*_legacy`. Its lists show the business's customers / suppliers from every app. Delete: refused while its invoices, bills, credit notes or payments name the party, archived when another app uses it. |

A record any app uses (`cp_party_references` with `is_extension = false`: a sale, an invoice, an order, a bill) is
never deleted: `core_platform.cp_party_in_use(id)`. MyStoreGuard's delete is refused (as its keys refused it before),
and Invoicing archives instead. Earlier migrations that alter or index these tables skip them once they are views.

Two traps:
- The EF model still describes `msg_suppliers` as a table. A future EF migration must not alter it
  (the same as `msg_taxes`).
- A write through the view under `SET session_replication_role = replica` is silently lost (Postgres
  skips a view's triggers there). Test seeds must write `cp_parties` directly.

## Accounting

Done in `migrations/shared/20261019-37` (books per business since EF `BooksPerBusiness`, the model maps the two as
views since `IdentityFromCorePlatform`):

- Old rows were matched to a party of the same business by name AND (email or phone), never name alone; the rest
  became parties with their ids kept. Documents of a matched row were pointed at the party.
- `cp_party_references`: `acc_sales_invoices.customer_id`, `acc_purchase_bills.supplier_id`,
  `acc_credit_notes.party_id`, `acc_supplier_credits.party_id`, `acc_payments.party_id` (uses), and the two settings
  tables (extensions). Those document columns have `NOT VALID DEFERRABLE` keys to `cp_parties`.
- A party entered in another app has no Accounting code until Accounting first saves it.

# Shared products (`core_platform.cp_products`)

Created by `migrations/shared/20261019-31-coreplatform-shared-products.sql`. Products follow the same rules as
parties (per business, ids kept, merge with `cp_product_merge`, references in `cp_product_references`) with one
difference: **each app lists only the products it has its own row for.** Pricing and stock are each app's, so
Invoicing does not list a shop product it has never priced, and MyStoreGuard does not list a consulting service.

- `cp_products` is what a product is: name, SKU, barcode, code, description, category, unit, goods or service. A
  kind sold separately (MyStoreGuard's "256GB") is a product of its own, with `parent_id` and `variant`.
- MyStoreGuard: `msg_products` = `msg_product_profiles` (stock, tracking, retirement, delete status) +
  `cp_products`. Its 16 child tables point at the profile with their old delete rules.
- Invoicing: `inv_items` = `inv_item_settings` (price, currency, tax, import links) + `cp_products`.
- CRM: `crm_products` = `crm_product_settings` (prices, sync links, status) + `cp_products`.
- An item brought in from MyStoreGuard (`source_id` = the product, or `product::kind`) attaches to that product
  (`cp_product_for_source`). It is never copied.
- Deleting in an app removes that app's row. The product itself goes when no app has a row for it and no document
  line names it (`cp_product_kept`).
- A rename in any app renames the product everywhere. That is the point of one record, but Invoicing's old
  "edited here, kept here" no longer separates its name from the shop's.
