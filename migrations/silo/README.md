# `migrations/silo/`

SQL for **every silo database** — a tenant with its own database, whether that is
`SILO_SHARED` (own database on the shared server) or `SILO_DEDICATED` (own
server).

The common schema is in `migrations/shared/` and silos get all of it. Put
something here only when it is true of a silo and false of the pool: a grant that
only makes sense when one tenant owns the whole database, a constraint the pool
cannot carry because it holds many tenants, a setting that is per-database.

`migrations/silo/<host>/` is for one silo, named by its route host — for example
`migrations/silo/siloshared.dev.trovesuite.com/`. Most silos never need one, and
a missing folder is skipped rather than failed.

Deployed by `.github/workflows/schema-silos.yml`, which **discovers** the
targets from `control_plane.ctl_tenant_routes` rather than from a list here. A
silo is onboarded with an INSERT; nothing in this repo needs editing for the
schema to start reaching it.
