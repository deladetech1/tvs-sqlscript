# Enterprise-specific post-migration SQL

Per-enterprise customizations that apply on top of `migrations/shared/`.
One subfolder per customer:

```
migrations/enterprise/
├── bidtl/
│   ├── 20260520-01-bidtl-custom-roles.sql
│   └── 20260601-02-bidtl-vat-tax-rule.sql
└── README.md      ← this file
```

## How the Runner picks the right folder

When deploying, the Runner reads the `TVS_ENTERPRISE` environment variable
(set by the GitHub workflow from the chosen scope — e.g. `scope=enterprise-bidtl`
→ `TVS_ENTERPRISE=bidtl`). Files under `migrations/enterprise/<slug>/` then
run after `migrations/shared/`.

Internal targets (scope=`saas`) leave `TVS_ENTERPRISE` unset — no enterprise
folder is touched.

## Naming + idempotency

Same rules as `migrations/shared/`:

- File naming: `YYYYMMDD-NN-short-description.sql`, runs in lexicographic order.
- Every file **must** be idempotent (`IF NOT EXISTS`, `ON CONFLICT DO NOTHING`,
  `CREATE OR REPLACE`, …). The Runner has no per-file history table for
  these — they run on every deploy.

## When to use this vs `migrations/shared/`

- **`shared/`** — applies to *all* deployments. Use for things every enterprise
  should have.
- **`enterprise/<slug>/`** — applies to only that customer. Use for
  customer-specific seed data, custom roles, bespoke tax rules, integrations,
  etc.

If a customer-specific tweak later becomes a feature for everyone, move the
SQL from `enterprise/<slug>/` to `shared/`.

## Onboarding a new enterprise

1. `mkdir migrations/enterprise/<slug>` (slug = lowercase customer id).
2. Add `- enterprise-<slug>` to `scope.options` in
   [`.github/workflows/database-dispatch.yml`](../../.github/workflows/database-dispatch.yml).
3. Create the matching GitHub Environment(s) (e.g. `enterprise-<slug>-prod`)
   with a `DATABASE_URL` secret. See the workflow header for the full runbook.
