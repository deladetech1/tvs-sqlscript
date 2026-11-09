-- Manufacturing: webhooks (design: docs/mfg/04-event-model.md §6; 05-api-contracts.md §1.11;
-- contract R4a.md E13-E17, E24 (4), (5), (8)).
--
--   mfg_webhook_subscriptions  an HTTPS endpoint of the business: name, url, description, kinds
--                              (exact event kinds, or {*}), plant_ids (empty = all; events without a
--                              plant always pass); the signing secret AES-256-GCM encrypted
--                              (secret_enc; MFG_WEBHOOK_KEY) and, for 24 h after a rotation, the old
--                              one beside it; active | paused | archived, paused_reason (e.g.
--                              "failing for 24 h"), failing_since. At most 20 not archived per
--                              business (the API)
--   mfg_webhook_deliveries     one event to one subscription: the body as signed (the 04 §1.3
--                              envelope), pending | delivered | failed | dead, attempts,
--                              next_attempt_at, first_attempt_at (retries stop 72 h after it),
--                              last_status, last_error, delivered_at; replay_of (the delivery it
--                              re-sends), rule_run_id (a rule's webhook step queued it), test (a
--                              test delivery). A first delivery is unique per subscription and event
--   mfg_webhook_attempts       every attempt (append-only: UPDATE is refused by mfg_refuse_change):
--                              status_code, duration_ms, error, response_excerpt (at most 512
--                              bytes). DELETE goes with its delivery (retention: delivered 30 days,
--                              failed and dead 90)
--
-- replay_of names another delivery without a foreign key, so retention may delete an original
-- before its replay. event_id is the cp_events id as text (test_<uuid> for a test delivery). The
-- CHECK lists live in 20261101-16. No product or party column. No grants. Idempotent; safe to
-- re-run.

BEGIN;

-- ==================================================================== subscriptions
CREATE TABLE IF NOT EXISTS mfg.mfg_webhook_subscriptions (
    id                      text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id               text NOT NULL,
    org_id                  text,
    bus_id                  text NOT NULL,
    name                    text NOT NULL,
    url                     text NOT NULL,
    description             text,
    kinds                   text[] NOT NULL,           -- exact kinds, or {*}
    plant_ids               text[] NOT NULL DEFAULT '{}',   -- empty = every plant
    secret_enc              text NOT NULL,             -- AES-256-GCM (nonce + ciphertext), base64
    prev_secret_enc         text,                      -- the secret before the last rotation ...
    prev_secret_expires_at  timestamptz,               -- ... still signing beside it until then (24 h)
    secret_rotated_at       timestamptz,
    status                  text NOT NULL DEFAULT 'active',
    paused_at               timestamptz,
    paused_by               text,                      -- NULL when the drain paused it
    paused_reason           text,
    failing_since           timestamptz,               -- the first failed attempt since the last success
    last_delivered_at       timestamptz,
    archived_at             timestamptz,
    archived_by             text,
    version                 integer NOT NULL DEFAULT 1,
    cdatetime               timestamptz NOT NULL DEFAULT now(),
    created_by              text,
    updated_at              timestamptz NOT NULL DEFAULT now(),
    updated_by              text
);
CREATE INDEX IF NOT EXISTS mfg_webhook_subscriptions_list_idx ON mfg.mfg_webhook_subscriptions (bus_id, status);
-- whEnqueue: does the business have an active subscription at all (asked in every publish()).
CREATE INDEX IF NOT EXISTS mfg_webhook_subscriptions_active_idx ON mfg.mfg_webhook_subscriptions (bus_id) WHERE status = 'active';
ALTER TABLE mfg.mfg_webhook_subscriptions DROP CONSTRAINT IF EXISTS mfg_webhook_subscriptions_rules_check;
ALTER TABLE mfg.mfg_webhook_subscriptions ADD CONSTRAINT mfg_webhook_subscriptions_rules_check
    CHECK (btrim(name) <> ''
           AND length(url) <= 2048 AND url ~* '^https?://'
           AND cardinality(kinds) >= 1
           AND secret_enc <> ''
           AND ((prev_secret_enc IS NULL) = (prev_secret_expires_at IS NULL)));

-- ======================================================================= deliveries
CREATE TABLE IF NOT EXISTS mfg.mfg_webhook_deliveries (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,   -- Trovesuite-Delivery-Id
    tenant_id          text NOT NULL,
    org_id             text,
    bus_id             text NOT NULL,
    subscription_id    text NOT NULL REFERENCES mfg.mfg_webhook_subscriptions (id),
    event_id           text NOT NULL,              -- the cp_events id as text; test_<uuid> for a test
    kind               text NOT NULL,
    body               jsonb NOT NULL,             -- {id, kind, v, occurred_at, recorded_at, business_id, source_app, subject_id, data[, rule][, test]}
    status             text NOT NULL DEFAULT 'pending',
    attempts           integer NOT NULL DEFAULT 0,
    next_attempt_at    timestamptz DEFAULT now(),  -- NULL once delivered or dead
    first_attempt_at   timestamptz,
    last_status        integer,                    -- the last HTTP status, NULL when none came back
    last_error         text,
    delivered_at       timestamptz,
    replay_of          text,                       -- mfg_webhook_deliveries.id it re-sends
    rule_run_id        text REFERENCES mfg.mfg_rule_runs (id),
    test               boolean NOT NULL DEFAULT false,
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    created_by         text,
    updated_at         timestamptz NOT NULL DEFAULT now()
);
-- One first delivery per subscription and event (whEnqueue is idempotent on it). Replays, tests and
-- a rule's webhook step (E16, which sends whatever the subscription's kinds) are further rows.
CREATE UNIQUE INDEX IF NOT EXISTS mfg_webhook_deliveries_event_uq
    ON mfg.mfg_webhook_deliveries (subscription_id, event_id)
    WHERE replay_of IS NULL AND NOT test AND rule_run_id IS NULL;
CREATE INDEX IF NOT EXISTS mfg_webhook_deliveries_due_idx ON mfg.mfg_webhook_deliveries (status, next_attempt_at);
CREATE INDEX IF NOT EXISTS mfg_webhook_deliveries_list_idx ON mfg.mfg_webhook_deliveries (subscription_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS mfg_webhook_deliveries_retention_idx ON mfg.mfg_webhook_deliveries (bus_id, status, cdatetime);
CREATE INDEX IF NOT EXISTS mfg_webhook_deliveries_rule_run_idx ON mfg.mfg_webhook_deliveries (rule_run_id) WHERE rule_run_id IS NOT NULL;
ALTER TABLE mfg.mfg_webhook_deliveries DROP CONSTRAINT IF EXISTS mfg_webhook_deliveries_rules_check;
ALTER TABLE mfg.mfg_webhook_deliveries ADD CONSTRAINT mfg_webhook_deliveries_rules_check
    CHECK (attempts >= 0
           AND jsonb_typeof(body) = 'object'
           AND ((status = 'delivered') = (delivered_at IS NOT NULL))
           AND replay_of IS DISTINCT FROM id
           AND (last_status IS NULL OR last_status BETWEEN 100 AND 599));

-- ========================================================================= attempts
CREATE TABLE IF NOT EXISTS mfg.mfg_webhook_attempts (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    org_id             text,
    bus_id             text NOT NULL,
    delivery_id        text NOT NULL REFERENCES mfg.mfg_webhook_deliveries (id) ON DELETE CASCADE,
    attempt            integer NOT NULL,
    at                 timestamptz NOT NULL DEFAULT now(),
    status_code        integer,                    -- NULL: no response (timeout, refused, URL_NOT_ALLOWED)
    duration_ms        integer NOT NULL DEFAULT 0,
    error              text,
    response_excerpt   text
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_webhook_attempts_attempt_uq ON mfg.mfg_webhook_attempts (delivery_id, attempt);
ALTER TABLE mfg.mfg_webhook_attempts DROP CONSTRAINT IF EXISTS mfg_webhook_attempts_rules_check;
ALTER TABLE mfg.mfg_webhook_attempts ADD CONSTRAINT mfg_webhook_attempts_rules_check
    CHECK (attempt >= 1 AND duration_ms >= 0
           AND (status_code IS NULL OR status_code BETWEEN 100 AND 599)
           AND (response_excerpt IS NULL OR octet_length(response_excerpt) <= 512));

DROP TRIGGER IF EXISTS mfg_webhook_attempts_no_update ON mfg.mfg_webhook_attempts;
CREATE TRIGGER mfg_webhook_attempts_no_update BEFORE UPDATE ON mfg.mfg_webhook_attempts
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_refuse_change();

-- ===================================================================== invariants
DO $$
DECLARE t text;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                    WHERE g.tgrelid = 'mfg.mfg_webhook_attempts'::regclass AND p.proname = 'mfg_refuse_change' AND NOT g.tgisinternal) THEN
        RAISE EXCEPTION 'mfg.mfg_webhook_attempts accepts UPDATE: its mfg_refuse_change trigger is missing';
    END IF;
    FOREACH t IN ARRAY ARRAY['mfg_webhook_deliveries_event_uq', 'mfg_webhook_attempts_attempt_uq'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'mfg' AND indexname = t) THEN
            RAISE EXCEPTION 'mfg unique index % is missing', t;
        END IF;
    END LOOP;
    -- At most 20 subscriptions not archived per business (the API refuses the 21st; noticed here).
    IF EXISTS (SELECT 1 FROM mfg.mfg_webhook_subscriptions WHERE status <> 'archived'
                GROUP BY tenant_id, bus_id HAVING count(*) > 20) THEN
        RAISE NOTICE 'some businesses have more than 20 Manufacturing webhook subscriptions';
    END IF;
END $$;

COMMIT;
