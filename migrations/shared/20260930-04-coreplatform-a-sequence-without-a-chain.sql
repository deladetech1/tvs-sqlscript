-- =====================================================================================
-- Give the security event feed an ordering that does not depend on the hash chain.
--
-- The Evidence feature is being retired, and with it chain_seq, prev_hash and row_hash.
-- chain_seq is not only evidence though: it is also the collector feed's cursor, chosen
-- because two events written in the same millisecond have no stable order by time, so a
-- watermark on occurred_at can step over one. That reason survives the feature.
--
-- So `seq` takes over: the same strict ordering, no hashing, nothing to verify.
--
-- It is backfilled to EQUAL chain_seq rather than renumbered. A collector's stored watermark
-- IS a chain_seq value, and anything already running would otherwise either re-read the whole
-- feed or skip to the end. Keeping the numbers identical makes the change invisible to it.
--
-- chain_seq was numbered per tenant, so the backfilled values repeat across tenants while the
-- new sequence is global. That is fine and deliberate: the feed only ever reads
-- `WHERE tenant_id = ? AND seq > ? ORDER BY seq`, so what it needs is that seq increases
-- within a tenant -- which holds, because the sequence restarts above the highest value any
-- tenant had. seq is a cursor, not a count, and nothing should present it as one.
--
-- This migration only ADDS. The columns it replaces are dropped in 20260930-05, which must
-- not run until the code that stopped reading them is deployed -- otherwise the running
-- release queries a column that is gone, and every read of the feed answers 500.
-- =====================================================================================

ALTER TABLE core_platform.cp_security_events
    ADD COLUMN IF NOT EXISTS seq bigint;

DO $$
DECLARE
    next_val    bigint;
    has_chain   boolean;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_class WHERE relname = 'cp_security_events_seq'
                                 AND relnamespace = 'core_platform'::regnamespace
    ) THEN
        CREATE SEQUENCE core_platform.cp_security_events_seq;
    END IF;

    -- Every migration here is re-run on every deploy, so this one runs again after
    -- 20260930-05 has dropped chain_seq. Naming a column that is gone is a hard parse
    -- error even inside a branch that would never be taken -- so the backfill is built as
    -- a string and only ever parsed while the column is still there. Without this, the
    -- FIRST deploy after the drop fails on this file, and so does every deploy after that.
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'core_platform'
           AND table_name   = 'cp_security_events'
           AND column_name  = 'chain_seq'
    ) INTO has_chain;

    IF has_chain THEN
        -- Same numbers as the chain, so existing watermarks keep their meaning.
        EXECUTE '
            UPDATE core_platform.cp_security_events
               SET seq = chain_seq
             WHERE seq IS NULL AND chain_seq IS NOT NULL';
    END IF;

    -- Anything left without a position still needs one: rows written before the chain
    -- existed, which the old feed hid outright (it required chain_seq IS NOT NULL) and so
    -- never delivered. They go after everything already numbered, oldest of them first.
    --
    -- That puts them later in the feed than events that happened after them. It is the
    -- right trade: the alternative is renumbering, which invalidates every watermark in
    -- exchange for tidiness in rows nobody has ever been sent. A collector reading these
    -- receives them once, late, rather than never -- and it has occurred_at to file them by.
    IF EXISTS (SELECT 1 FROM core_platform.cp_security_events WHERE seq IS NULL) THEN
        WITH numbered AS (
            SELECT id,
                   (SELECT COALESCE(MAX(seq), 0) FROM core_platform.cp_security_events)
                   + ROW_NUMBER() OVER (ORDER BY occurred_at, id) AS n
              FROM core_platform.cp_security_events
             WHERE seq IS NULL
        )
        UPDATE core_platform.cp_security_events e
           SET seq = numbered.n
          FROM numbered
         WHERE e.id = numbered.id;
    END IF;

    -- Raise the sequence past everything present -- but only ever raise it.
    --
    -- Security events are purged on a retention schedule, and this file runs again on every
    -- deploy. A plain RESTART WITH max(seq)+1 would therefore step the sequence BACKWARDS
    -- the first time a purge leaves the table empty or nearly so, and hand out positions it
    -- has already issued. A collector holding a watermark of 500 would then be told there is
    -- nothing after 500, for ever, while events pile up at 1, 2, 3.
    SELECT GREATEST(
               (SELECT COALESCE(MAX(seq), 0) FROM core_platform.cp_security_events),
               (SELECT COALESCE(last_value, 0) FROM core_platform.cp_security_events_seq)
           ) + 1
      INTO next_val;
    EXECUTE format('ALTER SEQUENCE core_platform.cp_security_events_seq RESTART WITH %s', next_val);
END $$;

ALTER TABLE core_platform.cp_security_events
    ALTER COLUMN seq SET DEFAULT nextval('core_platform.cp_security_events_seq');

ALTER SEQUENCE core_platform.cp_security_events_seq
    OWNED BY core_platform.cp_security_events.seq;

-- Every row has one now, and the default fills each new one.
ALTER TABLE core_platform.cp_security_events
    ALTER COLUMN seq SET NOT NULL;

-- The feed reads WHERE tenant_id = ? AND seq > ? ORDER BY seq.
CREATE INDEX IF NOT EXISTS ix_cp_security_events_tenant_seq
    ON core_platform.cp_security_events (tenant_id, seq);
