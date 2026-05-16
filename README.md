# Trovesuite Database (EF Core 10)

C# / Entity Framework Core 10 conversion of the PostgreSQL scripts under
`tvs-sqlscript/bkup/`. One project per module, deploy order honored, triggers
preserved as embedded SQL.

## Why

The legacy [`tvs-sqlscript/script_db_setup.sh`](../tvs-sqlscript/script_db_setup.sh)
runs raw `.sql` files in folder order. This solution does the same thing with
strongly-typed C# entities, EF Core Fluent API, and a single `tvs-db` CLI
that mirrors the bash script's `deploy / verify / rollback / status` flow.

## Solution layout

```
tvs-sqlscript/
├── Trovesuite.Database.sln
├── Directory.Build.props           # central package versions
└── src/
    ├── Trovesuite.Database.Common/         # shared base entities, fluent helpers, IModule
    ├── Trovesuite.Database.CorePlatform/   # module 1  - 42 entities, schema core_platform
    ├── Trovesuite.Database.LoanDrift/      # module 2  - 19 entities, schema loandrift
    ├── Trovesuite.Database.MyStoreGuard/   # module 3  - 50 entities, schema mystoreguard
    ├── Trovesuite.Database.HumanResource/  # module 4  -  1 entity,  schema human_resource
    └── Trovesuite.Database.Runner/         # CLI: tvs-db
```

Each module project contains:

- `Entities/*.cs` — POCOs.
- `Configurations/*.cs` — `IEntityTypeConfiguration<T>` Fluent API:
  composite keys, FK relationships, CHECK constraints, default values,
  comments, unique indexes.
- `{Module}DbContext.cs` — one `DbContext` per module, scoped to its PG schema.
- `{Module}Module.cs` — implements `IModule`; wires creation + post-migration seed.
- `Sql/Triggers/*.sql` — PL/pgSQL functions, triggers, views, and migrations
  that EF Core can't express in C# (e.g. `auto_assign_resource_permissions_to_admin_role`,
  the `ld_loan_details_view`, the partial unique index on `msg_product_prices`).
- `Sql/Seeds/*.sql` — `resource_types`, `permissions`, `roles`, `others` —
  copied verbatim from the bkup files. Idempotent (`ON CONFLICT DO NOTHING`).

## Deploy order

Identical to `script_db_setup.sh`:

| Order | Module           | Schema          | Triggers                                                                                |
| ----- | ---------------- | --------------- | --------------------------------------------------------------------------------------- |
| 1     | `core_platform`  | `core_platform` | 4 PL/pgSQL functions for automatic role↔permission assignment                           |
| 2     | `loandrift`      | `loandrift`     | Status-CHECK self-heal; `ld_loan_details_view`                                          |
| 3     | `mystoreguard`   | `mystoreguard`  | `COALESCE`-based partial unique index on `msg_product_prices`; PO items column patches  |
| 4     | `human_resource` | `human_resource`| — (seeds only)                                                                          |

Cross-module FKs (loandrift → core_platform.cp_users, etc.) work because all
schemas live in the same physical database.

## Quick start

```bash
# 1. Configure (any of these works):
cp .env.example .env       # then edit
# OR export DB_HOST, DB_PORT, DB_USER, PGPASSWORD, DB_NAME

# 2. Build
dotnet build

# 3. Validate the EF model without hitting the DB
dotnet run --project src/Trovesuite.Database.Runner -- localhost 5432 u p d validate

# 4. Deploy
dotnet run --project src/Trovesuite.Database.Runner -- deploy
# (interactive: pick a module, or 0 for all)

# Or with all positional args:
dotnet run --project src/Trovesuite.Database.Runner -- \
    my-host 5432 postgres '<pw>' trovesuite deploy
```

CLI actions:

- `deploy` — create schemas, apply EF model, install triggers, seed reference data.
- `verify` — connect, print PG version + `current_database()`.
- `status` — alias for `verify`.
- `rollback` — `DROP SCHEMA … CASCADE` (with `y/N` prompt). Drops in reverse
  module order so app schemas come down before `core_platform`.
- `validate` — builds every EF Core model offline; reports entity count per
  module. Useful in CI to catch Fluent API regressions.

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
- **PL/pgSQL**: anything EF Core can't express (functions, triggers, views,
  functional indexes) lives in `Sql/Triggers/*.sql` and is invoked via
  `migrationBuilder.Sql()` / `ExecuteSqlRawAsync()` from the module's `SeedAsync`.

## Adding a new table

1. Add a POCO under `Entities/`.
2. Add an `IEntityTypeConfiguration<T>` under `Configurations/`. Use the
   helpers in `Trovesuite.Database.Common.Conventions.FluentExtensions`
   (`AsTextUuidDefault`, `AsTimestampDefault`, `HasDeleteStatusCheck`,
   `HasInCheck`).
3. Register a `DbSet<T>` in the module's `DbContext`.
4. Run `dotnet run --project src/Trovesuite.Database.Runner -- … validate` to
   catch Fluent API issues offline.
5. Generate an EF migration when you're ready:
   ```bash
   dotnet ef migrations add Add<EntityName> \
       --project src/Trovesuite.Database.CorePlatform \
       --startup-project src/Trovesuite.Database.Runner
   ```

## Why no migrations are checked in yet

The runner uses `EnsureCreated()` for the first-time deploy, which mirrors how
the bash script works (run-everything-from-scratch against an empty DB). Once
you start iterating on schema in production, switch each module to
`dotnet ef migrations add Initial` and have the runner call
`Database.MigrateAsync()` instead.

## Building

- Requires .NET 10 SDK (verified with 10.0.102).
- All EF Core packages are pinned at 10.0.1 in `Directory.Build.props`.
- `EFCore.NamingConventions` provides snake-case mapping.
- The single `System.Security.Cryptography.Xml 9.0.0` warning is transitive from
  the SDK; it doesn't affect runtime.
