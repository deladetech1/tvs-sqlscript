# How an app joins and lives on the Trovesuite platform

Every Trovesuite product (MyStoreGuard, LoanDrift, ZelosHR, CRM, Projects, Invoicing, Accounting, …) is one app
inside one ERP. Core Platform owns sign-up, login, tenants, businesses, locations, users, roles, permissions,
subscriptions, tiers, routes and navigation. An app only adds its own schema, its resource types, permissions and
roles, and the rows that register it with Core Platform. This guide is the structure to follow so a change to one
app never breaks another app's deploy.

Written 2026-10-17 after a saas-dev outage (see "Worked example" below). Evidence and file:line references:
tvs-accounting-bk `docs/platform/research-*.md`.

## 1. What the runner does on every deploy

`src/Trovesuite.Database.Runner/Program.cs`, triggered by a push to `dev` (saas-dev, `module: all`):

1. For each module in order — CorePlatform (1), LoanDrift (2), MyStoreGuard (3), HumanResource/ZelosHR (4),
   Attendance (5), Accounting (6):
   `CREATE SCHEMA IF NOT EXISTS` → EF migrations (tracked in `<schema>.__EFMigrationsHistory`) →
   `Sql/Triggers/*.sql` → `Sql/Seeds/*.sql` (ordinal by file name).
2. Then `migrations/shared/*.sql` (ordinal by file name), then the class folder (`migrations/saas` on saas-dev),
   then silo/enterprise folders when their env vars are set.

Rules that follow from this:

- **Seeds and shared files have no history table. They re-run on every deploy.** Each must be idempotent: upsert on
  the natural key, `IF NOT EXISTS`, `CREATE OR REPLACE`, `ON CONFLICT DO NOTHING` for grants.
- **Seeds always run before every shared file.** On the first deploy a seed does not see rows a shared file will
  create; on every later deploy it does. Always ask: *what does each seed do to my rows on the second run?*
- **A failing file stops the run.** Everything before it (all module seeds, earlier shared files) is already
  committed. Wrap each shared file in `BEGIN; … COMMIT;`.
- **No `{` or `}` in module seed or trigger SQL.** Seeds go through EF `ExecuteSqlRawAsync`, which treats braces as
  format placeholders ("Input string was not in a correct format", seen 2026-10-17). Shared files are sent straight
  to Npgsql and may use `'{}'`.
- Module-level manual deploys go through `.github/workflows/apply.yml` (`module:` input). Every module must be listed
  there and in the `saas`/`silos`/`enterprise` choice lists.

## 2. The pieces an app consists of

| Piece | Where | Notes |
|---|---|---|
| App row `app-<x>` | CorePlatform `Sql/Seeds/04_others.sql` (`cp_apps` upsert) | `status` `coming_soon`/`beta`/`live`, `is_active`. The seed re-asserts it every deploy. |
| Tier configs | same file, `cp_app_tier_configs` `tier-cfg-<x>-basic/advance/premium/enterprise` | needed for subscriptions and feature gating |
| **role-cp-admin exclusion** | same file, the `role-cp-admin` grant block: `AND p.id NOT LIKE 'permission-<x>-%'` | **Add it in the same commit that creates the app's permissions** (see §5) |
| Schema + audit table | shared `…-<x>-joins-the-platform.sql` (or EF module) + `cp_app_schemas` row | log retention and the log screens find audit tables through `cp_app_schemas` |
| Resource types | `rt-subscribed-app-<x>` (parent NULL) and `rt-<x>-<resource>` children | upsert on id |
| Verbs | CorePlatform `Sql/Seeds/00_actions.sql` (`cp_actions`) | `cp_permissions.action` has a FK to it; read-only verbs (`get`, `list`, `statistics`) are `viewer_default` |
| Permissions | `permission-<x>-<resource>-<verb>` | each row needs `app_prefix='<x>'`, `resource_key`, `action`, `target=''`, `scope='any'`; `(app_prefix, resource_key, action, target, scope)` is unique |
| Roles | `role-subscribed-app-<x>-admin` (holds no own-app rows; allowed by being the role) + job roles `role-<x>-<job>` on `rt-system-role` with explicit grants | `role_name` is unique per tenant across apps ("Accountant" is Invoicing's) |
| Navigation block | every app role gets `permission-app-get`, `-business-get`, `-organization-get`, `-business-app-get`, `-business-app-get-locations`, `-user-get-locations` | |
| Cross-app check map | `migrations/shared/20260929-11-roles-named-after-jobs.sql`: `WHEN r.id LIKE 'role-<x>%' THEN '<x>'` | every join commit edits this one old file |
| Reserved label, route | shared join file: `cp_reserved_labels` (never delete — set `released_at`), route row with `tenant_id NULL`, tier `POOLED` | check no tenant host already contains the label |

Owner (`role-owner`), Suite Administrator (`role-admin`), Platform Administrator (`role-cp-admin`) and each
`role-subscribed-app-<x>-admin` are **allowed by being the role**: their grant rows are deleted on every deploy
(`20260929-03/-05/-07`) and the app packages let them through by role. No role may hold another app's permission;
`20260929-11` fails the deploy if one does.

## 3. Two ways an app is built

**Shared-only app (current pattern: CRM, Projects, Invoicing).** One file
`migrations/shared/YYYYMMDD-NN-<x>-joins-the-platform.sql`, dated after the latest file, wrapped in `BEGIN/COMMIT`,
containing in order: schema and audit table, `cp_app_schemas`, new verbs, resource types, permissions with metadata,
roles, explicit grants and the navigation block, reserved label, route, then invariants (`DO $$ … RAISE EXCEPTION`)
that stay true on every re-run (never "no rows yet"). Plus the CorePlatform seed lines (app row, tiers, cp-admin
exclusion) and the `20260929-11` map line in the same commit. Later features: one shared file each.

**EF module app (MyStoreGuard, LoanDrift, ZelosHR, Attendance, Accounting).** Tables via EF migrations in
`src/Trovesuite.Database.<X>/Migrations`; RBAC in `Sql/Seeds/01_resource_types … 04_others`. Module seeds run
**while the CorePlatform auto-assign triggers are live** (the shared file `20260929-10` drops them, but the
CorePlatform module re-creates them each deploy before seeds run), so a new permission is auto-granted to roles of its
resource type and parents. Use `rt-system-role` for curated job roles, set permission metadata in the seed (derive it
from the id, as Accounting's `02_permissions.sql` does) and refresh the grant copies (`cp_role_permissions` keeps a
copy of the metadata, filled only on insert). Still add the CorePlatform seed lines and the `20260929-11` map line,
and put platform rows (`cp_app_schemas`, label, route) in a shared join file.

## 4. Verifying before you push

On a scratch Postgres, run the runner with all modules (`0`). Leave `TVS_TARGET_CLASS` unset: files in
`migrations/saas` assume saas-dev's data (for example `20261005-05` needs existing app groups) and fail on an empty
database even without your change.

1. **fresh install**, then 2. **redeploy** (and ideally a third run). Every run must end with
   "All selected modules deployed successfully". A change that only passes once will break the next deploy for
   everybody.
3. For a change to an existing app, also reproduce saas-dev: deploy the previous commit twice, then deploy yours.
4. `python3 scripts/test_migrations_survive_use.py`, `scripts/test_reserved_labels.py`,
   `scripts/test_route_migration_order.py`, `scripts/audit_role_permissions.py --app-prefix <x> --roles 'role-<x>-%'`.
5. **Join the enforcement audit.** `scripts/mark_enforced_permissions.py` writes `cp_permissions.is_enforced` from
   what each app's code checks (`scripts/_enforced_permissions.py`, `all_enforced`). Add your app there in the same
   change that adds its permissions, or every run marks them "checked by nothing". Python apps use
   `python_app(root, prefix)` (reads `perm(R.X, A.Y)`); .NET apps need a reader for their own permission check
   (`dotnet_app` for ZelosHR, `accounting_app` for Accounting's `[RequiresAccountingPermission]`, including the
   ids an endpoint's own `Legacy` list accepts). Cover the reader with a test like `scripts/test_accounting_enforced_permissions.py`.
   `check_permission_refs.py` is for Python apps only (in C# an undefined name does not compile), and
   `audit_role_permissions.py` reads Python controllers and React hooks.

```bash
docker network create tvsnet
docker run -d --name tvspg --network tvsnet -e POSTGRES_PASSWORD=p -e POSTGRES_DB=tvsdb postgres:17
printf '0\n' | docker run -i --rm --network tvsnet -v "$PWD":/src -w /src \
  -v tvs-nuget:/root/.nuget/packages mcr.microsoft.com/dotnet/sdk:10.0 \
  bash -c 'dotnet run --project src/Trovesuite.Database.Runner -- tvspg 5432 postgres p tvsdb deploy'
# run the last command again for the redeploy
```

## 5. Worked example: the 2026-10-17 saas-dev outage

`9623b0d` (Invoicing joins the platform) created 33 `permission-invoicing-*` rows in a shared file but did not add
`AND p.id NOT LIKE 'permission-invoicing-%'` to the `role-cp-admin` grant in the CorePlatform seed. Its own deploy
passed (the seed ran before the permissions existed). From the next deploy on, the seed granted all 33 to
role-cp-admin, the fill-pair trigger stamped them `app_prefix='invoicing'`, `20260929-05` (which only clears
platform-prefixed rows) left them, and `20260929-11` failed with "33 cross-app grant(s) remain" — for every app's
deploy. Fixed in `84899e8`: the missing exclusion lines (invoicing, accounting) plus a cleanup right after the grant
that removes any role-cp-admin row whose permission carries another app's prefix.

## 6. Checklist (copy into the PR)

- [ ] Verbs exist in `00_actions.sql`
- [ ] Permissions carry app_prefix/resource_key/action/target/scope; ids `permission-<x>-<res>-<verb>`
- [ ] CorePlatform `04_others.sql`: app row, tier configs, **cp-admin exclusion line**
- [ ] `20260929-11` map line for `role-<x>%`
- [ ] Roles: subscribed-app admin with no own-app rows; job roles on `rt-system-role`; names unique across apps
- [ ] Navigation block for every app role
- [ ] `cp_app_schemas`, reserved label, route (shared join file)
- [ ] Invariants hold on re-run; no braces in seeds
- [ ] Module listed in `apply.yml` and the workflow choice lists (EF modules)
- [ ] Runner deploy on scratch: fresh + redeploy (+ saas-dev reproduction for changes) all green
