-- Help Desk R7: shared rate limit counters.
--
--   hd_rate_windows  one row per limiter bucket per fixed window: the public status subscribe, chat,
--                    CSAT, customer portal sign-in and inbound mail limiters, and the API token
--                    limiter, counted here so every replica enforces one limit instead of each
--                    allowing its own. A request is one
--                    INSERT ... ON CONFLICT (bucket, window_start) DO UPDATE SET count = count + 1
--                    RETURNING count. The app falls back to its in-memory limiter when this table
--                    cannot be reached in 200 ms.
--
-- bucket is "<limiter>:<sha256 hex of the key>": no address, email or token is stored. Rows older
-- than an hour are swept by the app (on a sample of calls). No tenant_id or bus_id: the counters
-- are not business data, so the per-schema purge on unsubscribe skips this table. No grants.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R7.md §2. Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS helpdesk.hd_rate_windows (
    bucket        text NOT NULL CONSTRAINT hd_rate_windows_bucket_check CHECK (length(bucket) BETWEEN 1 AND 200),
    window_start  timestamptz NOT NULL,
    count         int NOT NULL DEFAULT 1 CONSTRAINT hd_rate_windows_count_check CHECK (count >= 0),
    PRIMARY KEY (bucket, window_start)
);
-- The sweep deletes by age across every bucket.
CREATE INDEX IF NOT EXISTS hd_rate_windows_window_start_idx ON helpdesk.hd_rate_windows (window_start);

COMMIT;
