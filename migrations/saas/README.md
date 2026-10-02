# `migrations/saas/`

SQL that is true of the **pooled SaaS database only** — and nothing else.

The common schema does **not** live here. It lives in `migrations/shared/`, which
every target gets: the pool, every silo, every enterprise. A silo holds the same
tables as the pool; it differs in who can reach it, not in what is in it.
Splitting the common schema per class would mean writing each table change three
times and finding out the copies had drifted when one tenant's app started
500ing.

So put something here only when it is genuinely false elsewhere. Seed data that
only makes sense for the multi-tenant pool is the honest example — demo tenants,
the system tenant's own rows, anything keyed on there being many tenants in one
database.

Applied after `shared/`, in filename order, on every deploy. Idempotent, like
everything in `shared/`.
