# Manufacturing R1: DB slice progress

Branch `feature/mfg-r1` (from `feature/mfg-r0`). Contract: tvs-shared-apps-bk `docs/mfg/contracts/R1.md`.

## Done

| File | State |
|---|---|
| `20261029-40-mfg-shared-helpers.sql` | done: `mfg_purge_allowed`, `mfg_refuse_change`, `mfg_freeze_released`, `mfg_ensure_partitions`, settings, number series, idempotency keys, custom fields |
| `20261029-41-mfg-plant-model.sql` | done: plants, areas, lines, line work centers, work centers, resources, calendars, shifts, calendar exceptions, reason codes |
| `20261029-42-mfg-engineering.sql` | done: item settings, UoM conversions, item revisions, BOMs, BOM lines, routings, operations, operation links, work instructions, steps, checkpoints, documents, document links; freeze triggers |
| `20261029-43-mfg-production.sql` | done: orders (with the readiness read model), components, operations, confirmations and downtime events (monthly partitions), downtime current, genealogy links (partitioned), floor requests, order timeline |
| `20261029-44/45/46-*-values.sql` | done: every CHECK list |
| `20261029-47-mfg-references.sql` | done: product and party columns registered, asserted |

Verified (2026-10-29): the real runner, all modules, on a fresh `tvsdb_r1` (port 55471), then a
re-run, then a third run after inserting a plant, BOM, routing, instruction, order, confirmations
(two partitions), downtime, genealogy, floor request and timeline rows: all green.
`test_role_isolation.py` and `test_migrations_survive_use.py` pass. `mfg-e2e-kit/build.sh` with
`MIG` = this worktree builds `mfg_tmpl`. Append-only and freeze triggers proven in a rolled-back
transaction.

## Deviations (closest to 03 where the documents disagree)

1. **Reason codes** are `mfg_reason_codes` (kind `downtime | scrap | rework`, code, name,
   `loss_category`), not 03's `mfg_loss_reasons`: the contract and 05 call them reason codes and
   they hold scrap and rework reasons too. Loss categories are the union of 02 and 05:
   `breakdown, setup, waiting, material_shortage, minor_stop, speed, quality, rework, planned`.
2. **Genealogy links are partitioned too** (03 §6), not only the two tables A10 names.
3. **The readiness read model** is the `ready_*`, `readiness_evidence`, `readiness_at` columns on
   orders and order operations (03 §3.4, §7), not a separate table. Values add `unknown` (05 §3.7).
4. **Checkpoints** are a table (`mfg_instruction_checkpoints`) instead of 03's `checkpoint jsonb`
   on steps, as the contract lists them. Key unique per instruction.
5. **Documents** keep 03's owner (`entity_type`, `entity_id` NOT NULL); `mfg_document_links`
   attaches a document to further entities.
6. **`mfg_plants.loc_id` is nullable**: 05 makes `location_id` optional (03 had NOT NULL).
7. **Deleting protected rows.** `mfg_refuse_change` refuses UPDATE always and DELETE unless the
   business no longer has Manufacturing (`core_platform.cp_business_apps` holds no `app-mfg` row),
   which is when the unsubscribe purge (`cp_purge_app_data`, 20261028-60/-61) deletes the schema's
   rows. Without that exemption the purge would fail. The freeze trigger applies the same rule to
   DELETE of frozen headers and their children. With no `cp_business_apps` table at all, nothing
   may be deleted.
8. **What a frozen row still accepts:** status `released → superseded | obsolete` and
   `superseded → obsolete`, `effective_to`, `archived_at`, `version`, `updated_at`, `updated_by`;
   and a product or party merge that changes only `product_id`, `component_id` or
   `subcontract_party_id` (cp_product_merge / cp_party_merge UPDATE every registered column).
9. **Not built in R1** (deferred by the contract or not in its file list): `mfg_approved_sources`,
   `mfg_config_options` (A4), `mfg_shopfloor_sessions` (A12), `mfg_resource_rates` (a column
   `mfg_resources.ideal_cycle_sec` instead), the `src_scm_*` views (A1: R1 reads no SCM document).
10. **`mfg_order_timeline`** is append-only (a log).
11. **Idempotency table** uses 03's columns (`request_hash`, `response`), not 05 §1.6's
    (`body_hash`, `reply`).
12. **Effectivity overlap** invariant treats `effective_to` as exclusive, as 03 §5's where-used
    query does.
13. `mfg_production_orders.priority` defaults to 50 (03); 05 uses 1–5 default 3. The API should
    always write it.
14. The helper tables' lists (costing method, custom field type) live in `-46`;
    `mfg_number_series.kind` has no CHECK (the API owns the kinds).
15. R0's `mfg_audit_logs` and its UPDATE-only trigger are left as R0 made them (A6).
