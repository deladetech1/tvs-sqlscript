# Enterprise-specific post-migration SQL

Per-enterprise customizations that apply on top of `migrations/shared/`.
One subfolder per customer:

```
migrations/enterprise/
├── client1/
│   ├── 20260520-01-acme-custom-roles.sql
│   └── 20260601-02-acme-vat-tax-rule.sql
├── client2/
│   └── ...
└── README.md      ← this file
```

## How the Runner picks the right folder

When deploying, the Runner reads the `TVS_ENTERPRISE` environment variable
(set by the GitHub workflow from the chosen environment name — e.g.
`enterprise-acme` → `TVS_ENTERPRISE=client1` after mapping). Files under
`migrations/enterprise/<slug>/` then run after `migrations/shared/`.

Internal targets (`dev`, `staging`, `production`) leave `TVS_ENTERPRISE`
unset — no enterprise folder is touched.

## Naming + idempotency

Same rules as `migrations/shared/`:

- File naming: `YYYYMMDD-NN-short-description.sql`, runs in lexicographic order.
- Every file **must** be idempotent (`IF NOT EXISTS`, `ON CONFLICT DO NOTHING`,
  `CREATE OR REPLACE`, …). The Runner has no per-file history table for
  these — they run on every deploy.

## When to use this vs `migrations/shared/`

- **`shared/`** — applies to *all* deployments. Use for things every enterprise
  should have.
- **`enterprise/clientN/`** — applies to only that customer. Use for
  customer-specific seed data, custom roles, bespoke tax rules, integrations,
  etc.

If a customer-specific tweak later becomes a feature for everyone, move the
SQL from `enterprise/clientN/` to `shared/`.
