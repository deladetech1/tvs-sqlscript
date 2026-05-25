# Trovesuite Database (EF Core 10)

C# / Entity Framework Core 10 conversion of the PostgreSQL scripts under
`tvs-sqlscript-old/bkup/`. One project per module, deploy order honored,
PL/pgSQL triggers + seeds preserved as embedded SQL. Designed for
multi-tenant SaaS deployment: one shared schema applied to your team's DBs
(`saas`) and to each enterprise customer's own Azure Postgres
(`enterprise-<slug>`).

## Why

The legacy [`script_db_setup.sh`](../tvs-sqlscript-old/script_db_setup.sh)
runs raw `.sql` files in folder order. This solution does the same thing with
strongly-typed C# entities, EF Core Fluent API, and a single `tvs-db` CLI
that mirrors the bash script's `deploy / verify / rollback / status` flow.
On top of that, it adds first-class support for per-customer post-migration
SQL (`migrations/enterprise/<slug>/`) and a GitHub-Actions workflow for
running everything against any DB you've configured as an Environment.

## Solution layout

```
tvs-sqlscript/
├── Trovesuite.Database.sln
├── Directory.Build.props                   # central package versions
├── .github/workflows/
│   └── database-dispatch.yml               # manual workflow_dispatch entrypoint
├── src/
│   ├── Trovesuite.Database.Common/         # shared base entities, fluent helpers, IModule
│   ├── Trovesuite.Database.CorePlatform/   # module 1  - 42 entities, schema core_platform
│   ├── Trovesuite.Database.LoanDrift/      # module 2  - 19 entities, schema loandrift
│   ├── Trovesuite.Database.MyStoreGuard/   # module 3  - 50 entities, schema mystoreguard
│   └── Trovesuite.Database.Runner/         # CLI: tvs-db
└── migrations/
    ├── shared/                             # applies to every deploy (saas + every enterprise)
    └── enterprise/
        └── <slug>/                         # applies only when scope=enterprise-<slug>
```

Each module project contains:

- `Entities/*.cs` — POCOs.
- `Configurations/*.cs` — `IEntityTypeConfiguration<T>` Fluent API:
  composite keys, FK relationships, CHECK constraints, default values,
  comments, unique indexes.
- `{Module}DbContext.cs` — one `DbContext` per module, scoped to its PG schema.
- `{Module}Module.cs` — implements `IModule`; wires creation + post-migration seed.
- `Migrations/` — EF Core-generated migration files (`dotnet ef migrations add …`).
- `Sql/Triggers/*.sql` — PL/pgSQL functions, triggers, views, and migrations
  that EF Core can't express in C# (e.g. `auto_assign_resource_permissions_to_admin_role`,
  the `ld_loan_details_view`, the partial unique index on `msg_product_prices`).
- `Sql/Seeds/*.sql` — `resource_types`, `permissions`, `roles`, `others` —
  copied verbatim from the bkup files. Idempotent (`ON CONFLICT DO NOTHING`).

## Deploy order

Identical to `script_db_setup.sh`:

| Order | Module           | Schema           | Triggers / extras                                                                       |
| ----- | ---------------- | ---------------- | --------------------------------------------------------------------------------------- |
| 1     | `core_platform`  | `core_platform`  | 4 PL/pgSQL functions for automatic role↔permission assignment                           |
| 2     | `loandrift`      | `loandrift`      | Status-CHECK self-heal; `ld_loan_details_view`                                          |
| 3     | `mystoreguard`   | `mystoreguard`   | `COALESCE`-based partial unique index on `msg_product_prices`; PO items column patches  |
| 4     | `human_resource` | `human_resource` | ZelosHR `zeloshr` tables + EF RBAC seeds into `core_platform`                             |

After all four modules complete, the Runner additionally applies:

5. `migrations/shared/*.sql` — runs on every deploy.
6. `migrations/enterprise/<slug>/*.sql` — runs **only** when the
   `TVS_ENTERPRISE` env var is set (the GitHub workflow sets it from the
   `scope` input). For example, scope=`enterprise-bidtl` → applies
   `migrations/enterprise/bidtl/*.sql`.

Cross-module FKs (loandrift → core_platform.cp_users, etc.) work because all
schemas live in the same physical database.

## Multi-tenant deployment model

Two axes pick the target DB:

```
scope  ─────────►  saas                       (your team's DBs)
                   enterprise-bidtl           (a specific customer)
                   enterprise-<slug>          (… others as they onboard)

env    ─────────►  dev / stage / prod
```

GitHub Environment name = `<scope>-<environment>`:

| Scope               | dev                  | stage                  | prod                  |
| ------------------- | -------------------- | ---------------------- | --------------------- |
| `saas`              | `saas-dev`           | `saas-stage`           | `saas-prod`           |
| `enterprise-bidtl`  | `enterprise-bidtl-dev` (opt.) | `enterprise-bidtl-stage` (opt.) | `enterprise-bidtl-prod` |

Each cell that actually exists is a real GitHub Environment in
**Settings → Environments**, with:

- a **`DATABASE_URL`** secret containing the libpq URL for that DB
  (`postgresql://migrator:pw@host:5432/db?sslmode=require`),
- optional **Required reviewers** / **Wait timer** protection rules
  (typically set for `*-prod` environments).

Enterprises that only run production just don't create the dev/stage entries.

## Running it

**Local — for development against your own Postgres:**

```bash
cp .env.example .env       # then edit DB_HOST/PGPASSWORD/etc.

dotnet build

# 1) Offline model check (no DB hit)
dotnet run --project src/Trovesuite.Database.Runner -- localhost 5432 u p d validate

# 2) Connection check
dotnet run --project src/Trovesuite.Database.Runner -- localhost 5432 u p d verify

# 3) Deploy (interactive — pick a module, or 0 for all)
dotnet run --project src/Trovesuite.Database.Runner -- localhost 5432 u p d deploy

# To also run an enterprise's customizations from migrations/enterprise/<slug>/:
TVS_ENTERPRISE=bidtl  dotnet run --project src/Trovesuite.Database.Runner -- … deploy
```

**Via GitHub Actions** (Actions → "Database (EF Core dispatch)" → Run workflow):

| Input | Example |
| --- | --- |
| `scope` | `saas` or `enterprise-bidtl` |
| `environment` | `dev` / `stage` / `prod` |
| `command` | `validate` / `verify` / `deploy` / `rollback` / `migrations-*` |
| `module` | `all` (most commands) or a specific module (for `migrations-*`) |

See the comments at the top of
[`.github/workflows/database-dispatch.yml`](.github/workflows/database-dispatch.yml)
for the full onboarding runbook for new enterprises.

## CLI actions (Runner)

- `deploy` — create schemas, apply EF migrations, run triggers + seeds,
  apply `migrations/shared/*.sql` and (if `TVS_ENTERPRISE` is set)
  `migrations/enterprise/<slug>/*.sql`.
- `verify` — connect, print PG version + `current_database()`.
- `status` — alias for `verify`.
- `rollback` — `DROP SCHEMA … CASCADE` (with `y/N` prompt). Drops in reverse
  module order so app schemas come down before `core_platform`.
- `validate` — builds every EF Core model offline; reports entity count per
  module. Useful in CI to catch Fluent API regressions without a DB.

## Conventions

- **Naming**: `EFCore.NamingConventions` snake-cases all properties at the DB
  level. The C# side stays `PascalCase`. Tables are explicitly named with
  their `cp_` / `ld_` / `msg_` / `hr_` prefix via `ToTable(...)`.
- **Audit columns**: `Cdate`, `Ctime`, `Cdatetime`, `CreatedBy`, `UpdatedBy`,
  `DeletedBy` live on a `Trovesuite.Database.Common.Entities.AuditableEntity`
  base class. Tenant-scoped tables additionally inherit
  `TenantScopedEntity` (`TenantId`, `DeleteStatus`, `IsActive`, `Description`).
- **CHECK constraints**: `delete_status IN (...)`, status enums, gender, etc.
  are emitted via the `HasDeleteStatusCheck()` / `HasInCheck()` helpers in
  `Trovesuite.Database.Common.Conventions.FluentExtensions`.
- **Audit FKs**: every `created_by / updated_by / deleted_by` column gets a
  composite `(X, tenant_id) → cp_users(id, tenant_id)` FK via the
  `WithAuditUserFks()` helper. Cross-schema audit FKs from `ld_*`/`msg_*`/`hr_*`
  use `WithCrossSchemaAuditUserFks()`.
- **External entities**: CorePlatform tables referenced by other modules
  (`cp_tenants`, `cp_users`, `cp_organizations`, `cp_businesses`, …) are
  registered in non-CorePlatform DbContexts via
  [`ExternalCorePlatformEntities.Register`](src/Trovesuite.Database.CorePlatform/ExternalEntities.cs)
  with `ExcludeFromMigrations()` — EF knows about them for FK purposes but
  CorePlatform's migration still owns their DDL.
- **PL/pgSQL**: anything EF Core can't express (functions, triggers, views,
  functional indexes) lives in `src/.../Sql/Triggers/*.sql` and runs from
  the module's `SeedAsync` via `ExecuteSqlRawAsync()`.

## Adding a new table

1. Add a POCO under `Entities/`.
2. Add an `IEntityTypeConfiguration<T>` under `Configurations/`. Use the
   helpers in `Trovesuite.Database.Common.Conventions.FluentExtensions`
   (`AsTextUuidDefault`, `AsTimestampDefault`, `HasDeleteStatusCheck`,
   `HasInCheck`) and the audit/cross-schema FK helpers as needed.
3. Register a `DbSet<T>` in the module's `DbContext`.
4. Run `dotnet run --project src/Trovesuite.Database.Runner -- … validate` to
   catch Fluent API issues offline.
5. Generate a migration:
   ```bash
   dotnet ef migrations add Add<EntityName> \
       --project src/Trovesuite.Database.CorePlatform \
       --startup-project src/Trovesuite.Database.Runner \
       -o Migrations
   ```
6. Commit + push. Each target DB picks the new migration up on its next
   `deploy` — EF's `__EFMigrationsHistory` per DB tracks what's applied.

## Onboarding a new enterprise

1. Get the libpq URL(s) from the enterprise — one per DB they want managed
   (typically just production, sometimes stage + production).
2. **Repo → Settings → Environments → New environment** for each:
   - Name: `enterprise-<slug>-<env>` — e.g. `enterprise-bidtl-prod`.
   - Add environment secret: `DATABASE_URL` = the libpq URL.
   - *(Recommended for `*-prod`)* Add required reviewers.
3. Edit [`.github/workflows/database-dispatch.yml`](.github/workflows/database-dispatch.yml):
   add `- enterprise-<slug>` to `scope.options`. Commit, push.
4. *(Optional)* `mkdir migrations/enterprise/<slug>` if they need custom SQL.
5. Run the workflow with `scope=enterprise-<slug>`, `environment=prod`,
   `command=validate` (no DB writes), then `verify` (connection check),
   then `deploy`.

## Building

- Requires .NET 10 SDK (verified with 10.0.102).
- All EF Core packages pinned at 10.0.1 in `Directory.Build.props`.
- `EFCore.NamingConventions` provides snake-case mapping.
- The single `System.Security.Cryptography.Xml 9.0.0` warning is transitive from
  the SDK; it doesn't affect runtime.
