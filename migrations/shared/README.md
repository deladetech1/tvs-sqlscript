# Shared post-migration SQL

SQL files dropped here run on **every** target database (`dev`, `staging`,
`production`, **and every** `enterprise-*` environment) after the C#
EF Core migrations and the per-module triggers/seeds.

## When to use this folder

The C# Configurations and EF migrations are the source of truth for the
schema. Use this folder only for things EF Core's Fluent API can't express
or that need to land on every DB without a code-first migration:

- One-off data fixes that apply to all tenants.
- Schema tweaks that are easier to express in raw SQL (functional indexes,
  triggers that don't fit any one module).
- Cross-module constraints.

## Naming

`YYYYMMDD-NN-short-description.sql` — same date-prefix ordering as the
legacy `bkup/` files. Files run in lexicographic order.

## Idempotency rules

Every file in this folder **must** be idempotent — re-runnable without
errors. Use:

- `CREATE TABLE IF NOT EXISTS …`
- `CREATE OR REPLACE FUNCTION …`
- `DROP TRIGGER IF EXISTS … ; CREATE TRIGGER …`
- `INSERT … ON CONFLICT DO NOTHING`
- `ALTER TABLE … ADD COLUMN IF NOT EXISTS …`

The Runner has no record of which shared SQL files have run — it executes
every one on every deploy. If a file isn't idempotent, the second deploy
breaks.

## Example

```sql
-- 20260520-01-add-tenant-summary-view.sql
CREATE OR REPLACE VIEW core_platform.cp_tenant_summary AS
SELECT
    t.id AS tenant_id,
    COUNT(DISTINCT u.id)        AS user_count,
    COUNT(DISTINCT o.id)        AS org_count
FROM core_platform.cp_tenants t
LEFT JOIN core_platform.cp_users u           ON u.tenant_id = t.id
LEFT JOIN core_platform.cp_organizations o   ON o.tenant_id = t.id
GROUP BY t.id;
```
