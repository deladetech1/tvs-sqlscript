# Events (`core_platform.cp_events`)

What happened to the business's shared records, written once in the transaction that made the change, and read by any
app from where it last stopped. Created by `migrations/shared/20261019-33-coreplatform-events.sql`.

## Kinds

| Kind | Written by | Payload |
|---|---|---|
| `party.created` / `party.updated` / `party.deleted` | trigger on `cp_parties` | created: name and roles; updated: only the columns that changed |
| `party.merged` | `cp_party_merge` | `{kept, dropped, moved, by}`. Repoint anything you keep for `dropped` to `kept`. |
| `product.created` / `product.updated` / `product.deleted` / `product.merged` | trigger on `cp_products`, `cp_product_merge` | the same shapes |
| anything an app publishes | `core_platform.cp_event_publish(tenant, bus, app, kind, subject, payload)` | the app's own; kind is `noun.verb` |

An update that changes nothing records nothing. A merge records `merged`, not `deleted`.

## Reading

```sql
SELECT * FROM core_platform.cp_events_after('my-reader', 500, ARRAY['party.merged']);  -- oldest first
SELECT core_platform.cp_event_ack('my-reader', <last id handled>);                       -- never moves back
```

In Go: `internal/platform/events` (`Publish`, `Read`, `Ack`) in shared-apps. Python apps call the same SQL functions.

Handle each event idempotently, and ack after handling. A crash between handling and acking hands you the same event
again.

**Why reading is safe:** a row's id is handed out at insert, but the row is visible only at commit. A reader going by
"id greater than the last" could pass over an event that committed late. `cp_events_after` returns only events written
by transactions older than every transaction still running (`txid < pg_snapshot_xmin`), so nothing is skipped.

**The cost:** that "still running" is server-wide, every database on the server included. A transaction left open
anywhere (a stuck job, an open psql session) holds every reader back until it ends. Events are delayed, never lost.
Keep transactions short. If readers lag, look in `pg_stat_activity` for an old `xact_start`.

The triggers fire even under `session_replication_role = replica`, so seeds and data fixes are recorded too. Events are
kept 90 days (`tenant_id` + `cdatetime`, purged with the activity logs).
