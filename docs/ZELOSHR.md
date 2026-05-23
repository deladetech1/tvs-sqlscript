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

API Trove headers (tenant from JWT `tenant_id` claim): `app-id: app-hr`, `org-id: org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a`, `bus-id: bus_5d929457b0ea7e6d55c5da25c8cfb38aeef0573658121bf5399f6f1e64d`, `loc-id: loc_c79fd9a5c53a8eaa82805e63a84da112387743c5dcdff7f7b254c02302c`, `authorization: Bearer <JWT>`.

Platform seed in `05_zeloshr_demo.sql` inserts `cp_tenants`, `cp_organizations`, `cp_businesses`, `cp_locations`, `cp_business_app_locations`, and `cp_user_locations` for the demo admin user.

Consumer repo: [ZelosHR](https://github.com/deladetech1/ZelosHR) — see `AGENTS.md` there.
