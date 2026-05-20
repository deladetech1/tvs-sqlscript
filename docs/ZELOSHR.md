# ZelosHR database module

ZelosHR application tables live in the **`zeloshr`** schema, deployed as part of **`Trovesuite.Database.HumanResource`** (module 4).

## Migrations

| Migration | Purpose |
|-----------|---------|
| `20260516195150_Initial` | `human_resource.hr_employees` (platform membership) |
| `20260520095923_ZelosHrAppTables` | All `zeloshr.zhr_*` tables |

## Seeds (`Sql/Seeds/`)

| File | When applied |
|------|----------------|
| `01_resource_types.sql` | Every deploy |
| `02_permissions.sql` | Every deploy |
| `03_roles.sql` | Every deploy |
| `05_zeloshr_demo.sql` | Only when `TVS_SEED_ZELOSHR_DEMO=1` or `true` |

## Deploy for ZelosHR development

```bash
dotnet build
dotnet run --project src/Trovesuite.Database.Runner -- localhost 5431 user password zeloshrdb deploy
TVS_SEED_ZELOSHR_DEMO=1 dotnet run --project src/Trovesuite.Database.Runner -- localhost 5431 user password zeloshrdb deploy
```

API headers: `X-Tenant-Id: demo-tenant`, `X-Org-Id: demo-org`.

Consumer repo: [ZelosHR](https://github.com/deladetech1/ZelosHR) — see `AGENTS.md` there.
