# Manufacturing R2: DB slice (DB2) progress

Branch `feature/mfg-r2` (from `feature/mfg-r1`). Contract: tvs-shared-apps-bk `docs/mfg/contracts/R2.md`
(C1–C14, §3).

## Done

| File | State |
|---|---|
| `20261030-10-mfg-r2-permissions.sql` | 11 resource types, verbs `run firm convert record waive disposition place release approve implement assign resolve close` (ON CONFLICT DO NOTHING), 31 permissions (incl. C18 `inspections\|manage`), C13 grants; invariants: pairs complete, viewer read-only, admin holds no rows, operator holds only `inspections\|record` + `holds\|get` of R2, no role both creates and approves ECOs, plan features `mfg.core/planning/quality/trace/costing` exist |
| `20261030-11-mfg-planning.sql` | `mfg_demands`, `mfg_mrp_runs`, `mfg_mrp_dirty`, `mfg_item_plan_state`, `mfg_planned_orders` (+ `rule_trace`), `mfg_pegging`, `mfg_mrp_messages`; item settings gain `lead_time_days`, `safety_stock` |
| `20261030-12-mfg-quality.sql` | inspection plans + characteristics (frozen when released, `mfg_freeze_released`), inspections, results (append-only, partitioned by month of `measured_at`), holds, NCRs + lines, CAPAs + 8D steps + actions, recall runs and recall lots (append-only) |
| `20261030-13-mfg-costing.sql` | cost sets, item costs (one row per element), roll-ups, roll-up lines (append-only), order costs, order variances; `mfg.mfg_cost_set_frozen()` trigger; item settings gain `standard_cost` |
| `20261030-14-mfg-ecos.sql` | ECOs, ECO items, impacts (append-only), approvals (append-only) |
| `20261030-15-mfg-exceptions.sql` | `mfg_exceptions` (`root_key` unique per business while open/acknowledged/in_resolution), `mfg_exception_events` (append-only) |
| `20261030-16-mfg-src-views.sql` | `src_scm_open_so_lines`, `src_scm_open_po_lines`, `src_scm_open_transfer_lines`, `src_scm_receipt_lines`, `src_scm_shipment_lines`, each made only when its SCM tables exist |
| `20261030-17/18/19-*-values.sql` | planning + exceptions; quality; costing + ECO |
| `20261030-20-mfg-r2-references.sql` | product and party columns registered; invariant also catches `*product_id` names |
| `20261029-47` (R1) | edited: its extension allow-list also admits `mfg_mrp_dirty`, `mfg_item_plan_state` |
| kit `mfg-e2e-kit/build.sh` | also applies `20261030-*-mfg-*.sql` (local commit `822ddad`); `mfg_tmpl` rebuilt with R2 |

Verified (2026-10-29), real runner on a fresh `tvsdb_r2` (port 55471): run 1, run 2, then a row in every
R2 table (a released plan with its characteristic, results in two monthly partitions, a frozen
standard cost set, a converted planned order, an implemented ECO, an open and a resolved exception on
one root), then run 3: all green. `test_role_isolation.py` and `test_migrations_survive_use.py` (needs
`LC_ALL=en_US.UTF-8` or `initdb` fails) pass. Trigger proofs in rolled-back transactions: results,
roll-up lines, recall runs, ECO approvals and exception events refuse UPDATE/DELETE; a released
plan refuses UPDATE, child INSERT/UPDATE/DELETE and allows released→superseded and a product merge;
a frozen cost set refuses changes to it and its item costs and allows frozen→superseded and a product
merge; a second open exception on one root is refused, a new one after resolve is allowed; a second
active hold for the same subject and cause is refused. DELETE refusals need the business to hold
`app-mfg` in `cp_business_apps` (R1 deviation 7: otherwise the purge may delete).

## Deviations

1. **Aligned to the frontends' types (B17), at the coordinator's request.**
   - FC (`ecos.ts`, `costing.ts`): ECO status `draft | impact_review | approval | approved | implemented
     | rejected | cancelled`; urgency `low | normal | high | critical`; stock disposition `use_up |
     rework | scrap | keep`; order disposition `finish_on_old | switch_to_new | hold` (both nullable,
     defaults `use_up` / `finish_on_old`); approval decision stored `approved | rejected` (FC's input
     `approve|reject` is mapped by the API); `effective_serial`, `effective_lot` columns; cost set
     `period` text (`2026` or `2026-11`) instead of a date range; roll-up input kinds
     `receipt_cost | standard_cost | component | routing | subcontract | overhead`, plus `label` and
     `rate_kind` on roll-up lines. Cost set kinds and the 7 elements (with `energy`) already matched.
   - FP (`planning.ts`): `mfg_demands.number`, `customer_name` (party_id optional),
     `mfg_planned_orders.number` (both nullable, unique per business when set); MRP message status
     `open | closed` and a `message` column (the API's `text`); exception kinds `shortage | mrp_message
     | inspection_failed | ncr_overdue | resource_down`, root types `item | resource | lot | inspection
     | ncr | planned_order | production_order`, `owner_id`, `sla_due_at`.
   - FQ (`quality.ts`, checked while aligning): NCR source `inspection | operator | customer | supplier |
     trace`; CAPA status `open | verifying | closed`. Its other lists (points, sampling, characteristic
     types, inspection status and trigger, hold subject/source/status, NCR status, severity,
     dispositions, CAPA kinds, disciplines, action kinds) already matched; plan status keeps
     `in_review` (FQ's list is a subset).
   - FQ, the coordinator's last alignment: `mfg_capa_steps` (one row per CAPA and discipline D1–D8:
     owner, due_on, notes, status `open | done` + done_at; the API's `done` flag), `mfg_recall_runs.number`
     NOT NULL and unique per business plus `already_held`, and `mfg_recall_lots` (append-only: the
     confirmed lots, lot_number, product, stock on hand, the hold placed or `already_held`).
     `sample_pct`, CAPA `kind`, CAPA status `open | verifying | closed` and the
     `needs_engineering_change` disposition were already there.
   - **Contract C18:** `permission-mfg-inspections-manage` (inspection plans: draft, change, release),
     granted to Quality Engineer and Plant Manager; `inspections|waive` now means waiving only.
     Operators still hold only `inspections|record` (asserted).
2. **Item settings columns** `lead_time_days`, `safety_stock` (in -11) and `standard_cost` (in -13) are
   added by those files with `ADD COLUMN IF NOT EXISTS`; R1's `make_lead_time_days` stays (the make's
   fixed part; the engine adds the routing's lead time).
3. **`mfg_mrp_dirty`** is the contract's name (03 says `mfg_mrp_dirty_items`). It and
   `mfg_item_plan_state` are product **extensions** (a merge moves them, a clash drops the dropped
   product's row), so R1's `-47` allow-list was widened.
4. **Item costs are one row per element** (`element`, `this_level`, `lower_level`, `total`), as the
   contract's "per set, per element" and 02's "per level and rolled up", not 03's one-row-with-columns.
   Added `mfg_cost_rollups` (header of the reproducible inputs) which §3 does not list.
5. **Cost sets:** `open | frozen | superseded`; only a `standard` set may be frozen (CHECK); one
   `current` set and one `frozen` standard per business (unique indexes). Frozen rule is a new trigger
   function `mfg.mfg_cost_set_frozen()` (not `mfg_freeze_released`, whose statuses are revision ones).
6. **Added beyond §3:** `mfg_recall_runs` (in -12, 03's recall snapshot), `src_scm_open_transfer_lines`
   (C2 counts transfers), `mfg_eco_approvals` is 03's approvals for ECOs (FC calls them "mfg_approvals":
   storage is `mfg_eco_approvals`).
7. **Data rules are CHECKs, not deploy invariants**, so a used database never fails a deploy:
   run `running` ⇔ no `finished_at`; converted planned order names its target; in-process plan ⇔
   `operation_seq`; decided inspection ⇔ `decided_at` (waived needs `waive_reason`); hold `released` ⇔
   `released_at`; regrade line needs `regrade_product_id`; closed CAPA needs effectiveness verified;
   dismissed exception needs a reason; `mfg_item_costs.total = this_level + lower_level`.
8. **Manufacturing receipts have no table** (B26 posts ledger movements, `reference_type
   mfg_stock_receipt`) and no party, so C9's "supplier via the receipt's party" has nothing to read
   for them; inspections reference them by `receipt_type = 'mfg_stock_receipt'`, `receipt_id`,
   `receipt_line_id` (= movement id).
9. **Engineer** also gets `ecos|implement` (C13 names only create): implementing releases revisions,
   and R1 keeps engineering releases with the engineer. Plant manager gets `ecos|approve`; nobody both
   creates and approves (asserted).
10. **Supplier holds** keep the party id in `subject_id` (not registered for merges).
11. **SCM views** read SCM column types; a later SCM migration that changes a column a view uses must
    drop the view first (-16 re-creates it on the next run).

## Names the backend must know (storage → 05 / frontend API)

| Storage | API |
|---|---|
| `mfg_demands.due_on` | `due_date` |
| `mfg_planned_orders.due_on`, `release_on` | `due_on`, `release_on` (FP uses these names); purchase suggestions `need_by`, `order_by` |
| `mfg_item_plan_state.last_netted_at` | `planned_at`; `mfg_mrp_dirty.first_marked_at` → `dirty_since` |
| `mfg_mrp_messages.current_on`, `suggested_on`, `message` | `current_date`, `suggested_date`, `text` |
| `mfg_exceptions.root_type`, `root_id` | `root_cause_type`, `root_cause_id` |
| `mfg_exceptions.owner_id` | `owner_id` (+ `owner_name` joined) |
| `mfg_inspection_characteristics.lower_limit`, `upper_limit` | FQ's `lower`, `upper` |
| `mfg_inspection_characteristics.max_defects` (count) | FQ's `upper` for a `count` characteristic |
| `mfg_holds.release_decision` | the release `decision` |
| `mfg_capas.effectiveness_note` | FQ's `verification_note` |
| `mfg_capa_steps.status = 'done'` | the step's `done` (and `done_at`) |
| `mfg_ecos.effective_on` | `effective_on` (FC) |
| `mfg_eco_approvals.decision` `approved\|rejected` | input `approve\|reject` |
| `mfg_eco_items.object_type` `item_revision` | FC's released revision kind `item` |
| `mfg_cost_rollup_lines.input_type`, `input_id` | `kind`, `source_id` |
| `mfg_cost_sets.period` | `period` |
| `mfg_planned_orders.converted_to_type` | `production_order \| scm_requisition \| scm_transfer` |
| `mfg_inspection_results.result` | `pass \| fail` (judged by the API) |

Number series kinds (no CHECK): `demand` (DM-), `planned_order` (PLN-), `inspection` (QI-), `ncr` (NCR-),
`capa` (CAPA-), `eco` (ECO-), `recall` (RC-).

Net-change queue: mark with `INSERT ... ON CONFLICT (bus_id, plant_id, product_id) DO UPDATE SET reasons
= mfg_mrp_dirty.reasons || EXCLUDED.reasons, last_marked_at = now()` in the writer's transaction; claim
with `DELETE ... RETURNING` (FOR UPDATE SKIP LOCKED, lowest `low_level_code` first). Partitioned
results: PK `(id, measured_at)`; idempotency key is the duplicate guard.

## What the other side must change

- BP/BQ/BC: never DELETE frozen/append-only rows in tests (B16); write characteristics before
  releasing a plan, item costs before freezing a set.
- BP: `exceptionsRefresh` must resolve (status `resolved`, `resolved_at`) before re-opening a root.
- FQ: `lower`/`upper` map to `lower_limit`/`upper_limit` (and `upper` of a count to `max_defects`).
