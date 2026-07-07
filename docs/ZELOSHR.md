# ZelosHR database module

ZelosHR application tables live in the **`zeloshr`** schema, deployed as part of **`Trovesuite.Database.HumanResource`** (module 4).

## Migrations

| Migration | Purpose |
|-----------|---------|
| `20260516195150_Initial` | `human_resource.hr_employees` (platform membership) |
| `20260520095923_ZelosHrAppTables` | All `zeloshr.zhr_*` tables |
| `20260521193953_AddEmployeeRegistration` | Registration wizard columns / related tables |
| `20260529234850_EmployeeIdAndEducationDates` | Employee ID issue/expiry dates; education `start_date` / `end_date` (replaces year columns) |
| `20260530000750_RenameCredentialIdToCredentialUrl` | Certification `credential_url` column (was `credential_id`) |

DDL is EF Core only (`dotnet ef migrations add`). Do not hand-edit generated migrations.

## Seeds (reference data only)

| Source | When applied |
|--------|----------------|
| `Sql/Seeds/01_resource_types.sql` → `04_others.sql` (RBAC resource types, permissions, roles, core-platform navigation bindings) | Every deploy via `HumanResourceModule.SeedAsync` (embedded SQL upsert into `core_platform`, same pattern as loandrift/mystoreguard). App permission→role bindings are created by the core_platform auto-assign triggers. |
| CorePlatform `Sql/Seeds/*` (apps incl. `app-zeloshr`, tiers, etc.) | Every deploy via `CorePlatformModule.SeedAsync` |

**No demo tenant / employee rows** are shipped from this repo. Production and shared environments already have `core_platform` and `zeloshr` data. For local API testing, insert matching `cp_*` context and `zhr_*` rows yourself (pgAdmin/SQL) and align ZelosHR `LocalDevelopment` / Trove headers with those ids.

## Deploy

From **ZelosHR** (Docker SDK container — no host .NET required):

```bash
./scripts/compose.sh migrate
# or build only:
./scripts/compose.sh sqlbuild
```

Host equivalent (optional):

```bash
dotnet build
dotnet run --project src/Trovesuite.Database.Runner -- localhost 5431 user password zeloshrdb deploy
```

Consumer repo: [ZelosHR](https://github.com/deladetech1/ZelosHR) — see `AGENTS.md` and `docs/LOCAL_DEV.md` there.
